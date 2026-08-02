# Builds a month-by-month breakdown (pledged vs. contributed) plus totals
# and balance for a single student.
#
# Pledges are effective-from markers: the amount set for a month carries forward
# to later months until a new pledge changes it.
class StudentSummary
  def self.call(student, up_to: Date.current.beginning_of_month)
    new(student, up_to: up_to).call
  end

  def initialize(student, up_to:)
    @student = student
    @up_to = up_to.beginning_of_month
  end

  def call
    {
      student: {
        id: @student.id,
        full_name: @student.full_name,
        display_name: @student.display_name,
        grade_id: @student.grade_id,
        enrolled_from: @student.enrolled_from,
        enrolled_until: @student.enrolled_until
      },
      months: month_rows,
      totals: {
        contributed_cents: @student.contributed_cents,
        expected_cents: @student.expected_cents(up_to: @up_to),
        balance_cents: @student.balance_cents(up_to: @up_to),
        currency: @student.grade.currency
      }
    }
  end

  private

  def pledge_entries
    @pledge_entries ||= @student.monthly_pledges.order(:month).to_a
  end

  def month_rows
    months.map do |m|
      eff = @student.effective_pledge(m, pledge_entries) # [amount, status] or nil
      {
        month: m,
        pledged_cents: eff&.first,
        contributed_cents: contributed_by_month[m] || 0,
        status: eff&.last
      }
    end
  end

  def months
    starts = [pledge_entries.first&.month, contributed_by_month.keys.min, @student.enrolled_from]
             .compact.map { |d| d.to_date.beginning_of_month }
    return [] if starts.empty?

    start = starts.min
    last = @up_to
    if @student.enrolled_until && @student.enrolled_until.beginning_of_month < last
      last = @student.enrolled_until.beginning_of_month
    end
    return [] if last < start

    result = []
    m = start
    while m <= last
      result << m
      m = m.next_month
    end
    result
  end

  def contributed_by_month
    @contributed_by_month ||= @student.payments
      .where(kind: :student_contribution)
      .group("date_trunc('month', paid_on)").sum(:amount_cents)
      .transform_keys { |k| k.to_date.beginning_of_month }
  end
end
