# Projects how much the grade needs to accumulate across all of its trips.
#
# Each trip happens in a specific year (`trip_year`). Its cost per student is the
# most recent *real* value entered (TripCostEntry) inflated at the grade's annual
# rate up to the trip's year — so a real cost entered for a later year overrides
# the projection from then on.
#
#   total_per_student = Σ trip.projected_cost(trip_year)
#   total_needed      = total_per_student × active students
#   remaining         = max(total_needed − net raised, 0)
#   suggested monthly = remaining ÷ remaining months ÷ active families
class CostPlan
  def self.call(grade)
    new(grade).call
  end

  def initialize(grade)
    @grade = grade
    @rate = grade.inflation_rate.to_f
  end

  def call
    trips = @grade.trips.ordered.includes(:cost_entries).to_a
    @years = years_span(trips)
    rows = trips.map { |t| trip_row(t) }
    total_per_student = rows.sum { |r| r[:cost_cents].to_i }
    students = @grade.active_students_count
    total_needed = total_per_student * students
    net_raised = @grade.net_raised_cents
    remaining = [total_needed - net_raised, 0].max
    months = @grade.remaining_months
    suggested_monthly = suggested_monthly_cents(remaining, months, students)

    {
      currency: @grade.currency,
      inflation_rate: @rate,
      active_students: students,
      years: @years,
      trips: rows,
      total_per_student_cents: total_per_student,
      total_needed_cents: total_needed,
      net_raised_cents: net_raised,
      remaining_cents: remaining,
      remaining_months: months,
      accumulation_end: @grade.accumulation_end_month,
      suggested_monthly_cents: suggested_monthly
    }
  end

  private

  def trip_row(trip)
    entries = trip.cost_entries.sort_by(&:year)
    {
      id: trip.id,
      name: trip.name,
      level: trip.level,
      trip_year: trip.trip_year,
      base_year: entries.first&.year,
      base_amount_cents: entries.first&.amount_cents,
      cost_cents: trip.cost_cents_for(trip.trip_year, @rate),
      is_actual: entries.any? { |e| e.year == trip.trip_year },
      entries: entries.map { |e| { id: e.id, year: e.year, amount_cents: e.amount_cents } },
      # Projected/real per-student cost for every year in the plan (for the table).
      projection: @years.index_with { |y| trip.cost_cents_for(y, @rate) }
    }
  end

  def years_span(trips)
    years = trips.flat_map { |t| t.cost_entries.map(&:year) + [t.trip_year] }.compact
    return [] if years.empty?

    (years.min..years.max).to_a
  end

  # Remaining fund need, split equally across active families and remaining months.
  def suggested_monthly_cents(remaining, months, families)
    return nil unless months&.positive? && families.positive?

    (remaining.to_d / months / families).round
  end
end
