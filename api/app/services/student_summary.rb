# Builds a month-by-month breakdown (pledged vs. contributed) plus totals
# and balance for a single student.
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

  def month_rows
    months.map do |m|
      {
        month: m,
        pledged_cents: pledged_by_month[m],
        contributed_cents: contributed_by_month[m] || 0,
        status: status_by_month[m]
      }
    end
  end

  def months
    keys = (pledged_by_month.keys + contributed_by_month.keys)
    keys << @student.enrolled_from if @student.enrolled_from
    keys.compact!
    return [] if keys.empty?

    (keys.min..[keys.max, @up_to].min).select { |d| d.day == 1 }
  end

  def pledged_by_month
    @pledged_by_month ||= @student.monthly_pledges
      .where(status: :pledged)
      .group(:month).sum(:amount_cents)
      .transform_keys { |k| k.to_date.beginning_of_month }
  end

  def status_by_month
    @status_by_month ||= @student.monthly_pledges
      .group(:month).maximum(:status)
      .transform_keys { |k| k.to_date.beginning_of_month }
      .transform_values { |v| MonthlyPledge.statuses.key(v) }
  end

  def contributed_by_month
    @contributed_by_month ||= @student.payments
      .where(kind: :student_contribution)
      .group("date_trunc('month', paid_on)").sum(:amount_cents)
      .transform_keys { |k| k.to_date.beginning_of_month }
  end
end
