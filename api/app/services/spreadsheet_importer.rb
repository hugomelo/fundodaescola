require "csv"
require "digest"

# Imports the legacy Google Spreadsheet (two tabs) into the database.
#
# Strategy:
#   * The "payments" tab is clean and authoritative for the student roster
#     (the `Mapeamento` column holds the canonical full name) and for every
#     contribution / event transaction.
#   * The "students" tab is parsed only for the monthly *pledges* (Prometido)
#     and to infer enrollment start/end. Its names are fuzzy-matched onto the
#     roster built from the payments tab.
#
# Idempotent: re-running updates in place (keyed by external_ref / name / month).
class SpreadsheetImporter
  MONTHS = {
    "jan" => 1, "fev" => 2, "mar" => 3, "abr" => 4, "mai" => 5, "jun" => 6,
    "jul" => 7, "ago" => 8, "set" => 9, "out" => 10, "nov" => 11, "dez" => 12
  }.freeze

  BLOCK_OFFSETS = [0, 4, 8, 12, 16, 20].freeze
  EVENT_TOKENS = %w[evento].freeze

  attr_reader :grade, :report

  def initialize(grade:, payments_csv:, students_csv:)
    @grade = grade
    @payments_csv = payments_csv
    @students_csv = students_csv
    @roster = {} # normalized_name => Student
    @report = Hash.new(0)
    @unmatched_blocks = []
  end

  def self.run(grade:, payments_csv:, students_csv:)
    new(grade: grade, payments_csv: payments_csv, students_csv: students_csv).run
  end

  # Rebuild default payer mappings from existing payments and retro-apply them
  # to payments that are still unidentified (student_contribution with no student
  # and no explicit mapping). Never overrides a payment already tagged manually.
  def self.rebuild_mappings(grade:)
    importer = new(grade: grade, payments_csv: nil, students_csv: nil)
    applied = 0
    ActiveRecord::Base.transaction do
      importer.send(:build_payer_mappings)
      grade.payer_mappings.find_each do |m|
        scope = grade.payments
                     .where("LOWER(description) = ?", m.payer_text.downcase)
                     .where(payer_mapping_id: nil, student_id: nil, kind: Payment.kinds[:student_contribution])
        if m.maps_to_event?
          applied += scope.update_all(kind: Payment.kinds[:event], payer_mapping_id: m.id)
        else
          applied += scope.update_all(student_id: m.student_id, payer_mapping_id: m.id)
        end
      end
    end
    { mappings: grade.payer_mappings.count, applied: applied }
  end

  def run
    ActiveRecord::Base.transaction do
      import_payments
      import_pledges
      build_payer_mappings
    end
    log_report
    self
  end

  # ---------------------------------------------------------------------------
  # Payments tab
  # ---------------------------------------------------------------------------
  def import_payments
    rows = CSV.read(@payments_csv, liberal_parsing: true)
    rows.each do |row|
      raw_date = row[0].to_s.strip
      next unless raw_date =~ %r{\A\d{2}/\d{2}/\d{2,4}\z}

      date   = parse_date(raw_date)
      time   = row[1].to_s.strip
      desc   = row[2].to_s.strip
      cents  = parse_money(row[3])
      target = row[4].to_s.strip
      next if date.nil? || cents.nil? || desc.empty?

      external_ref = Digest::MD5.hexdigest([raw_date, time, desc, row[3]].join("|"))

      if event?(target)
        student = nil
        kind = :event
      else
        student = find_or_create_student(target)
        kind = :student_contribution
      end

      payment = grade.payments.find_or_initialize_by(external_ref: external_ref)
      payment.assign_attributes(
        paid_on: date, paid_time: time, description: desc,
        amount_cents: cents, kind: kind, student: student
      )
      payment.save!
      @report[:payments] += 1
    end
  end

  # ---------------------------------------------------------------------------
  # Students tab -> pledges + enrollment
  # ---------------------------------------------------------------------------
  def import_pledges
    rows = CSV.read(@students_csv, liberal_parsing: true).map { |r| r || [] }

    rows.each_with_index do |row, i|
      BLOCK_OFFSETS.each do |off|
        next unless row[off].to_s.strip == "Mês" && row[off + 1].to_s.strip.downcase.start_with?("aportado")

        name = rows[i - 1] && rows[i - 1][off].to_s.strip
        next if name.blank? || name.casecmp("nome").zero?

        parse_block(name, rows, i + 1, off)
      end
    end
  end

  def parse_block(name, rows, start_index, off)
    student = match_student(name)
    unless student
      @unmatched_blocks << name
      student = find_or_create_student(name)
    end

    data_months = []
    j = start_index
    while (cell = rows[j] && rows[j][off].to_s.strip) && month_label?(cell)
      month = parse_month_label(cell)
      aportado = rows[j][off + 1]
      prometido = rows[j][off + 2]

      pledge_cents = parse_money(prometido)
      has_any = present_value?(aportado) || present_value?(prometido)
      data_months << month if has_any && month

      if month && pledge_cents
        pledge = student.monthly_pledges.find_or_initialize_by(month: month.beginning_of_month)
        pledge.assign_attributes(amount_cents: pledge_cents, status: :pledged)
        pledge.save!
        @report[:pledges] += 1
      end
      j += 1
    end

    apply_enrollment(student, data_months)
  end

  def apply_enrollment(student, data_months)
    return if data_months.empty?

    data_months.sort!
    student.enrolled_from ||= data_months.first
    # If the student's last month with data is before the global latest month,
    # assume they left; otherwise still enrolled.
    latest = MonthlyPledge.maximum(:month) || data_months.last
    student.enrolled_until = data_months.last < latest ? data_months.last : nil
    student.save!
  end

  # ---------------------------------------------------------------------------
  # Payer mappings (only unambiguous descricao -> target)
  # ---------------------------------------------------------------------------
  # Build a default PayerMapping per payer description.
  #
  # A payer usually contributes for a single student, but may also make the
  # occasional "Evento" donation. So we map by the payer's *dominant student*:
  #   * exactly one distinct student across their non-event payments -> that student
  #     (occasional event donations are the exception, re-tagged manually);
  #   * only ever events (no student)                                 -> event;
  #   * two or more distinct students (ambiguous)                     -> skip.
  def build_payer_mappings
    students_by_desc = Hash.new { |h, k| h[k] = Set.new }
    event_by_desc = Hash.new(false)

    grade.payments.find_each do |p|
      key = p.description.downcase
      if p.event?
        event_by_desc[key] = true
      elsif p.student_id
        students_by_desc[key] << p.student_id
      end
    end

    grade.payments.find_each do |p|
      key = p.description.downcase
      student_ids = students_by_desc[key]

      if student_ids.size == 1
        target = { maps_to_event: false, student_id: student_ids.first }
      elsif student_ids.empty? && event_by_desc[key]
        target = { maps_to_event: true, student_id: nil }
      else
        next # ambiguous (multiple students) or nothing to map
      end

      mapping = grade.payer_mappings.find_or_initialize_by(payer_text: p.description)
      mapping.assign_attributes(target)
      mapping.save! if mapping.changed? || mapping.new_record?
      @report[:payer_mappings] += 1 if mapping.previously_new_record?
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------
  def find_or_create_student(full_name)
    key = normalize(full_name)
    return @roster[key] if @roster.key?(key)

    student = grade.students.where("LOWER(full_name) = ?", full_name.downcase.strip).first
    student ||= grade.students.create!(full_name: full_name.strip)
    @report[:students] += 1 if student.previously_new_record?
    index_student(student)
    student
  end

  def index_student(student)
    @roster[normalize(student.full_name)] = student
  end

  # Load current roster (built from payments) for fuzzy matching.
  def roster_students
    if @roster.empty?
      grade.students.find_each { |s| @roster[normalize(s.full_name)] = s }
    end
    @roster
  end

  # Fuzzy-match a pledge-sheet name onto the payments-derived roster by token overlap.
  def match_student(name)
    target_tokens = tokens(name)
    return nil if target_tokens.empty?

    best = nil
    best_score = 0
    roster_students.each_value do |student|
      st = tokens(student.full_name)
      next unless st.first == target_tokens.first # first name must match

      score = (st & target_tokens).size
      if score > best_score
        best = student
        best_score = score
      elsif score == best_score && score.positive?
        best = nil # ambiguous tie -> unmatched
      end
    end
    best
  end

  def tokens(name)
    normalize(name).split(" ").reject { |t| t.length <= 1 || %w[de da do dos das e].include?(t) }
  end

  def normalize(str)
    str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip.gsub(/\s+/, " ")
  end

  def event?(target)
    EVENT_TOKENS.include?(normalize(target))
  end

  def present_value?(cell)
    v = cell.to_s.strip
    return false if v.empty?

    !%w[n/a na ?].include?(v.downcase)
  end

  def month_label?(cell)
    cell.to_s.strip =~ %r{\A[a-zç]{3}\.?/\d{2}\z}i
  end

  def parse_month_label(cell)
    m = cell.to_s.strip.downcase
    abbr = m[0, 3]
    year = m[-2, 2].to_i + 2000
    mon = MONTHS[abbr]
    mon ? Date.new(year, mon, 1) : nil
  end

  def parse_date(raw)
    d, m, y = raw.split("/")
    y = y.length == 2 ? (2000 + y.to_i) : y.to_i
    Date.new(y, m.to_i, d.to_i)
  rescue ArgumentError
    nil
  end

  # "R$ 1.735,80" / "-R$195,30" / "R$ 0,00" -> integer cents (signed). nil if not money.
  def parse_money(cell)
    v = cell.to_s.strip
    return nil if v.empty?

    neg = v.include?("-")
    digits = v.gsub(/[^\d,\.]/, "")
    return nil if digits.empty?

    digits = digits.tr(".", "").tr(",", ".") # thousands "." out, decimal "," -> "."
    return nil unless digits =~ /\A\d+(\.\d+)?\z/

    cents = (digits.to_f * 100).round
    neg ? -cents : cents
  end

  def log_report
    Rails.logger.info("[SpreadsheetImporter] #{@report.inspect}")
    puts "Imported: #{@report.inspect}"
    if @unmatched_blocks.any?
      puts "Unmatched pledge blocks (created as new students): #{@unmatched_blocks.join(", ")}"
    end
  end
end
