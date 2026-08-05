require "csv"
require "securerandom"

# Bulk-imports parent users from a contacts CSV into a grade.
#
# Expected columns (header, case/accent-insensitive):
#   name, email, telefone (optional), aluno
#
# `aluno` is matched against the grade's students by normalized full/display
# name, with a token-overlap fallback (same idea as SpreadsheetImporter).
#
# Rows without email or with an unmatched student are skipped and reported.
# Existing users (by email) are updated/linked rather than duplicated.
# Optionally sends an invite email so new users can set a password.
class UsersImporter
  Result = Struct.new(
    :created, :updated, :skipped, :invited, :errors,
    keyword_init: true
  ) do
    def to_h
      {
        created: created, updated: updated, skipped: skipped,
        invited: invited, errors: errors
      }
    end
  end

  HEADER_KEYS = {
    "name" => :name, "nome" => :name,
    "email" => :email, "e-mail" => :email,
    "telefone" => :phone, "phone" => :phone, "celular" => :phone,
    "aluno" => :student, "estudante" => :student, "crianca" => :student
  }.freeze

  def initialize(grade:, csv_content:, send_invite: false)
    @grade = grade
    @csv_content = to_utf8(csv_content)
    @send_invite = send_invite
    @result = Result.new(created: 0, updated: 0, skipped: 0, invited: 0, errors: [])
    @students = grade.students.to_a
  end

  def self.run(grade:, csv_content:, send_invite: false)
    new(grade: grade, csv_content: csv_content, send_invite: send_invite).run
  end

  def run
    rows = CSV.parse(@csv_content, col_sep: detect_separator, liberal_parsing: true)
    cols = column_map(rows)
    unless cols[:name] && cols[:email] && cols[:student]
      @result.errors << "Cabeçalho inválido: esperados name, email e aluno"
      return @result
    end

    rows.each_with_index do |row, idx|
      next if row.equal?(@header_row)
      next if row.all? { |c| c.to_s.strip.empty? }

      process(row, cols, idx + 1)
    end
    @result
  end

  private

  def process(row, cols, line)
    name = cell(row, cols[:name])
    email = cell(row, cols[:email]).downcase
    phone = cols[:phone] ? cell(row, cols[:phone]) : ""
    student_name = cell(row, cols[:student])

    if email.blank?
      @result.skipped += 1
      @result.errors << "Linha #{line}: e-mail em branco (#{name.presence || 'sem nome'})"
      return
    end

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      @result.skipped += 1
      @result.errors << "Linha #{line}: e-mail inválido (#{email})"
      return
    end

    if student_name.blank?
      @result.skipped += 1
      @result.errors << "Linha #{line}: coluna aluno vazia (#{email})"
      return
    end

    student = match_student(student_name)
    unless student
      @result.skipped += 1
      @result.errors << "Linha #{line}: aluno não encontrado (#{student_name.inspect})"
      return
    end

    user = User.find_by("LOWER(email) = ?", email)
    if user
      update_existing(user, name:, phone:, student:, line:)
    else
      create_new(name:, email:, phone:, student:)
    end
  rescue ActiveRecord::RecordInvalid => e
    @result.skipped += 1
    @result.errors << "Linha #{line}: #{e.record.errors.full_messages.to_sentence}"
  end

  def create_new(name:, email:, phone:, student:)
    user = User.new(
      email: email,
      name: name.presence,
      phone: phone.presence,
      role: :parent,
      password: SecureRandom.urlsafe_base64(24)
    )
    user.save!
    user.students << student unless user.students.include?(student)
    @result.created += 1

    return unless @send_invite

    send_invite!(user)
    @result.invited += 1
  end

  def update_existing(user, name:, phone:, student:, line:)
    unless user.parent?
      @result.skipped += 1
      @result.errors << "Linha #{line}: #{user.email} já existe com papel #{user.role}"
      return
    end

    changed = false
    if name.present? && user.name.blank?
      user.name = name
      changed = true
    end
    if phone.present? && user.phone != phone
      user.phone = phone
      changed = true
    end
    user.save! if changed

    linked = false
    unless user.students.include?(student)
      user.students << student
      linked = true
    end

    if changed || linked
      @result.updated += 1
    else
      @result.skipped += 1
    end
  end

  def send_invite!(user)
    raw = user.generate_password_reset_token!
    UserMailer.with(user: user, token: raw).invite.deliver_later
  end

  def match_student(name)
    key = normalize(name)
    exact = @students.find do |s|
      normalize(s.full_name) == key || normalize(s.display_name) == key
    end
    return exact if exact

    target_tokens = tokens(name)
    return nil if target_tokens.empty?

    best = nil
    best_score = 0
    @students.each do |student|
      score = [student.full_name, student.display_name].map { |n| tokens(n) }.map { |st|
        next 0 if st.empty? || st.first != target_tokens.first
        (st & target_tokens).size
      }.max
      next if score.zero?

      if score > best_score
        best = student
        best_score = score
      elsif score == best_score
        best = nil # ambiguous tie
      end
    end
    best
  end

  def column_map(rows)
    header = rows.find { |r| r.any? { |c| HEADER_KEYS.key?(normalize(c)) } }
    return {} unless header

    @header_row = header
    map = {}
    header.each_with_index do |cell, i|
      key = HEADER_KEYS[normalize(cell)]
      map[key] = i if key && !map[key]
    end
    map
  end

  def cell(row, index)
    row[index].to_s.strip
  end

  def detect_separator
    sample = @csv_content.lines.find { |l| l.strip.present? }.to_s
    sample.count(";") > sample.count(",") ? ";" : ","
  end

  def to_utf8(content)
    str = content.to_s.dup.force_encoding("UTF-8")
    str = str.force_encoding("ISO-8859-1").encode("UTF-8") unless str.valid_encoding?
    str.sub("\uFEFF", "")
  end

  def tokens(name)
    normalize(name).split(" ").reject { |t| t.length <= 1 || %w[de da do dos das e].include?(t) }
  end

  def normalize(str)
    str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip.gsub(/\s+/, " ")
  end
end
