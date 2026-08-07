require "csv"
require "digest"

# Incrementally imports a bank-statement CSV export into a grade.
#
# Handles two shapes:
#   * The real bank export: ";"-separated, with a header row
#     (Data;Hora;Descricao;Valor;Saldo) and descriptions prefixed with the
#     transaction type ("Pix recebido de <nome>", "Transferência enviada para
#     <nome>", etc.). The payer name is extracted from the description.
#   * A prepared file with an explicit `Mapeamento` column (as in the legacy
#     spreadsheet), "," or ";"-separated.
#
# Row resolution order:
#   1. Explicit `Mapeamento` cell ("Evento" => event; a student name => match).
#   2. An existing PayerMapping for the (cleaned) payer name.
#   3. Otherwise imported unmapped (student: nil) for later admin review.
class BankStatementImporter
  Result = Struct.new(:created, :updated, :unmapped, :skipped, :flagged, :ignored, keyword_init: true)

  # Leading phrases found in Brazilian bank statements, longest first.
  DESCRIPTION_PREFIXES = [
    "pix recebido de ", "pix enviado para ",
    "transferencia enviada para ", "transferencia recebida de ",
    "ted recebida de ", "ted enviada para ",
    "doc recebido de ", "doc enviado para ",
    "pagamento recebido de ", "deposito de ",
  ].freeze

  HEADER_KEYS = {
    "data" => :date, "hora" => :time,
    "descricao" => :desc, "historico" => :desc,
    "valor" => :amount, "mapeamento" => :map,
  }.freeze

  # Internal moves between the checking and the investment account. The money
  # stays part of the fund (yield is tracked separately as InvestmentEntry), so
  # these rows are ignored entirely.
  INTERNAL_TRANSFER = /investimento|aplicac|resgate|rdb|cdb|renda fixa/i

  def initialize(grade:, csv_content:)
    @grade = grade
    @csv_content = to_utf8(csv_content)
    @result = Result.new(created: 0, updated: 0, unmapped: 0, skipped: 0, flagged: 0, ignored: 0)
  end

  def self.run(grade:, csv_content:)
    new(grade: grade, csv_content: csv_content).run
  end

  def run
    @events = @grade.events.to_a
    rows = CSV.parse(@csv_content, col_sep: detect_separator, liberal_parsing: true)
    cols = column_map(rows)
    rows.each { |row| process(row, cols) }
    @result
  end

  private

  # Uploaded files arrive as ASCII-8BIT; coerce to valid UTF-8 (handling
  # Latin-1 bank exports) and strip a leading BOM.
  def to_utf8(content)
    str = content.to_s.dup.force_encoding("UTF-8")
    str = str.force_encoding("ISO-8859-1").encode("UTF-8") unless str.valid_encoding?
    str.sub("\uFEFF", "")
  end

  def detect_separator
    sample = @csv_content.lines.find { |l| l.strip.present? }.to_s
    sample.count(";") > sample.count(",") ? ";" : ","
  end

  # Build a name->index map from a header row, or fall back to positional.
  def column_map(rows)
    header = rows.find { |r| r.any? { |c| normalize(c) == "data" } && r.any? { |c| normalize(c) == "valor" } }
    if header
      @header_row = header
      map = {}
      header.each_with_index do |cell, i|
        key = HEADER_KEYS[normalize(cell)]
        map[key] = i if key && !map.key?(key)
      end
      map[:time] = nil unless map.key?(:time)
      map
    else
      { date: 0, time: 1, desc: 2, amount: 3, map: 4 }
    end
  end

  def process(row, cols)
    return if @header_row && row.equal?(@header_row)

    raw_date = row[cols[:date]].to_s.strip
    return unless raw_date =~ %r{\A\d{2}/\d{2}/\d{2,4}\z}

    date  = parse_date(raw_date)
    time  = cols[:time] ? row[cols[:time]].to_s.strip : nil
    raw_desc = row[cols[:desc]].to_s
    desc  = clean_payer(raw_desc)
    cents = parse_money(row[cols[:amount]])
    mapeamento = cols[:map] ? row[cols[:map]] : nil
    return if date.nil? || cents.nil? || desc.empty?

    # Internal transfers to/from the investment account are not fund movements.
    if raw_desc.match?(INTERNAL_TRANSFER)
      external_ref = Digest::MD5.hexdigest([raw_date, time, desc, cents].join("|"))
      @grade.payments.where(external_ref: external_ref).delete_all
      @result.ignored += 1
      return
    end

    student, kind, mapping = resolve(desc, mapeamento)
    on_event_day = @events.any? { |e| e.covers?(date) }
    student, kind = classify_by_pledge(student, kind, cents, date, on_event_day)

    unmapped = kind == :student_contribution && student.nil?
    @result.unmapped += 1 if unmapped

    # Flag for manual review when the tool cannot be confident:
    #   * classified as an event (mapping or event-day purchase heuristic),
    #   * event-day payment that was not confidently a contribution-sized transfer,
    #   * or the payer could not be identified.
    confident_contribution = contribution_meets_pledge?(student, cents, date)
    flag = unmapped || kind == :event || (on_event_day && !confident_contribution)

    external_ref = Digest::MD5.hexdigest([raw_date, time, desc, cents].join("|"))
    payment = @grade.payments.find_or_initialize_by(external_ref: external_ref)
    was_new = payment.new_record?

    payment.assign_attributes(
      paid_on: date, paid_time: time, description: desc, amount_cents: cents,
      kind: kind, student: student, payer_mapping: mapping
    )
    # Only (re)set the review flag on new rows so we never override a decision
    # the admin already made on an existing payment.
    if was_new
      payment.needs_review = flag
      @result.flagged += 1 if flag
    end

    if payment.changed?
      payment.save!
      was_new ? @result.created += 1 : @result.updated += 1
    else
      @result.skipped += 1
    end
  end

  # Returns [student, kind_symbol, payer_mapping]
  def resolve(desc, mapeamento)
    cell = mapeamento.to_s.strip
    # Only treat the mapeamento column as a mapping if it isn't a monetary value
    # (bank exports put "Saldo" there, e.g. "R$ 3.430,00").
    if cell.present? && parse_money(cell).nil?
      return [nil, :event, nil] if normalize(cell) == "evento"

      return [match_student(cell), :student_contribution, nil]
    end

    mapping = PayerMapping.match(@grade.id, desc)
    return [nil, :student_contribution, nil] unless mapping
    return [nil, :event, mapping] if mapping.maps_to_event?

    [mapping.student, :student_contribution, mapping]
  end

  # On event days (or when already tagged as event), prefer contribution when the
  # amount is at least the student's effective monthly pledge — those look like
  # the regular fund transfer, not a cake/event purchase. Smaller amounts on an
  # event day are treated as event income (and will be flagged for confirmation).
  def classify_by_pledge(student, kind, cents, date, on_event_day)
    return [student, kind] unless student && cents.positive?

    pledge_cents = pledged_cents_for(student, date)
    return [student, kind] unless pledge_cents&.positive?

    if cents >= pledge_cents
      [student, :student_contribution]
    elsif on_event_day || kind == :event
      [nil, :event]
    else
      [student, kind]
    end
  end

  def contribution_meets_pledge?(student, cents, date)
    return false unless student && cents.positive?

    pledge_cents = pledged_cents_for(student, date)
    pledge_cents&.positive? && cents >= pledge_cents
  end

  def pledged_cents_for(student, date)
    @pledge_cache ||= {}
    entries = (@pledge_cache[student.id] ||= student.monthly_pledges.order(:month).to_a)
    student.effective_pledge(date, entries)&.first
  end

  # Strip the "Pix recebido de " style prefix and any trailing "(...)" note.
  def clean_payer(raw)
    name = raw.to_s.strip
    down = normalize(name)
    DESCRIPTION_PREFIXES.each do |prefix|
      next unless down.start_with?(prefix)

      name = name[prefix.length..].to_s.strip
      break
    end
    name.sub(/\s*\([^)]*\)\s*\z/, "").strip
  end

  def match_student(name)
    @grade.students.where("LOWER(full_name) = ?", name.downcase).first ||
      @grade.students.detect { |s| normalize(s.full_name) == normalize(name) }
  end

  def normalize(str)
    str.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase.strip.gsub(/\s+/, " ")
  end

  def parse_date(raw)
    d, m, y = raw.split("/")
    y = y.length == 2 ? (2000 + y.to_i) : y.to_i
    Date.new(y, m.to_i, d.to_i)
  rescue ArgumentError
    nil
  end

  def parse_money(cell)
    v = cell.to_s.strip
    return nil if v.empty?

    neg = v.include?("-")
    digits = v.gsub(/[^\d,.]/, "").tr(".", "").tr(",", ".")
    return nil unless digits =~ /\A\d+(\.\d+)?\z/

    cents = (digits.to_f * 100).round
    neg ? -cents : cents
  end
end
