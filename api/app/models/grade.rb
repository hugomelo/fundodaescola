class Grade < ApplicationRecord
  has_many :students, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :payer_mappings, dependent: :destroy
  has_many :investment_entries, dependent: :destroy
  has_many :events, dependent: :destroy
  has_many :trips, dependent: :destroy
  has_many :users, dependent: :nullify

  validates :name, presence: true
  validates :currency, presence: true
  validates :target_total_cents, numericality: { only_integer: true }

  # Sum of every payment (contributions + events, signed) plus investment income.
  def net_raised_cents
    payments.sum(:amount_cents) + investment_entries.sum(:amount_cents)
  end

  def student_contributions_cents
    payments.where(kind: :student_contribution).sum(:amount_cents)
  end

  def event_cents
    payments.where(kind: :event).sum(:amount_cents)
  end

  def investment_cents
    investment_entries.sum(:amount_cents)
  end

  def progress_ratio
    return 0.0 if target_total_cents.to_i.zero?

    net_raised_cents.to_f / target_total_cents
  end

  # Linear share of the total target for months elapsed from the accumulation
  # start through `up_to` (inclusive). Uses school_year_start/end when set;
  # otherwise falls back to earliest enrollment → last trip year.
  def target_to_date_cents(up_to: Date.current.beginning_of_month)
    start_m = accumulation_start_month
    end_m = accumulation_end_month
    return nil unless start_m && end_m && target_total_cents.to_i.positive?

    total_months = months_inclusive(start_m, end_m)
    return nil if total_months <= 0

    up_to = up_to.to_date.beginning_of_month
    return 0 if up_to < start_m
    return target_total_cents if up_to >= end_m

    elapsed = months_inclusive(start_m, up_to)
    (target_total_cents.to_d * elapsed / total_months).round
  end

  # Raised vs. the linear target-to-date (>1 = ahead of pace).
  def pace_ratio(up_to: Date.current.beginning_of_month)
    expected = target_to_date_cents(up_to: up_to)
    return nil if expected.nil? || expected.zero?

    net_raised_cents.to_f / expected
  end

  def accumulation_start_month
    (
      school_year_start ||
      students.where.not(enrolled_from: nil).minimum(:enrolled_from) ||
      MonthlyPledge.joins(:student).where(students: { grade_id: id }).minimum(:month)
    )&.to_date&.beginning_of_month
  end

  def accumulation_end_month
    return school_year_end.to_date.beginning_of_month if school_year_end.present?

    last_year = trips.maximum(:trip_year)
    Date.new(last_year, 12, 1) if last_year
  end

  def active_students_count
    students.active.count
  end

  # Net amount received per calendar month (payments + investment yield),
  # from the earliest transaction through `up_to` (inclusive), with zero-filled gaps.
  def monthly_received(up_to: Date.current.beginning_of_month)
    by_month = Hash.new(0)

    payments.pluck(:paid_on, :amount_cents).each do |paid_on, cents|
      by_month[paid_on.to_date.beginning_of_month] += cents
    end
    investment_entries.pluck(:month, :amount_cents).each do |month, cents|
      by_month[month.to_date.beginning_of_month] += cents
    end

    fill_monthly_series(by_month, up_to: up_to) { |month, total| { month: month.iso8601, amount_cents: total } }
  end

  # Distinct families (students) with a positive student_contribution payment each month.
  # Uses the same month span as monthly_received so the charts stay aligned.
  def monthly_contributing_families(up_to: Date.current.beginning_of_month)
    by_month = Hash.new { |h, k| h[k] = Set.new }

    payments.student_contribution
            .where.not(student_id: nil)
            .where("amount_cents > 0")
            .pluck(:paid_on, :student_id)
            .each do |paid_on, student_id|
      by_month[paid_on.to_date.beginning_of_month] << student_id
    end

    counts = by_month.transform_values(&:size)
    # Prefer the shared fund timeline (incl. investments/events) when available.
    start_m, end_m = monthly_series_bounds(up_to: up_to)
    if start_m.nil?
      return [] if counts.empty?

      start_m = counts.keys.min
      end_m = up_to.to_date.beginning_of_month
      end_m = start_m if end_m < start_m
    end

    result = []
    month = start_m
    while month <= end_m
      result << { month: month.iso8601, families: counts[month] || 0 }
      month = month.next_month
    end
    result
  end

  private

  def monthly_series_bounds(up_to:)
    earliest = [
      payments.minimum(:paid_on)&.to_date,
      investment_entries.minimum(:month)&.to_date
    ].compact.min
    return [nil, nil] unless earliest

    start_m = earliest.beginning_of_month
    end_m = up_to.to_date.beginning_of_month
    end_m = start_m if end_m < start_m
    [start_m, end_m]
  end

  def fill_monthly_series(by_month, up_to:)
    start_m, end_m = monthly_series_bounds(up_to: up_to)
    return [] unless start_m

    result = []
    month = start_m
    while month <= end_m
      result << yield(month, by_month[month] || 0)
      month = month.next_month
    end
    result
  end

  def months_inclusive(from_month, to_month)
    ((to_month.year * 12 + to_month.month) - (from_month.year * 12 + from_month.month)) + 1
  end
end


