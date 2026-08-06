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
      },
      # Latest payment date known for the grade (bank extract coverage).
      bank_updated_through: @student.grade.payments.maximum(:paid_on)
    }
  end

  private

  def pledge_entries
    @pledge_entries ||= @student.monthly_pledges.order(:month).to_a
  end

  def month_rows
    months.map do |m|
      eff = @student.effective_pledge(m, pledge_entries) # [amount, status] or nil
      payments = payments_by_month[m] || []
      {
        month: m,
        pledged_cents: eff&.first,
        contributed_cents: payments.sum { |p| p[:amount_cents] },
        status: eff&.last,
        payments: payments
      }
    end
  end

  def months
    starts = [pledge_entries.first&.month, payments_by_month.keys.min, @student.enrolled_from]
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

  def payments_by_month
    @payments_by_month ||= begin
      grouped = Hash.new { |h, k| h[k] = [] }
      @student.payments
              .where(kind: :student_contribution)
              .order(:paid_on, :id)
              .pluck(:id, :paid_on, :description, :amount_cents)
              .each do |id, paid_on, description, amount_cents|
        month = paid_on.to_date.beginning_of_month
        grouped[month] << {
          id: id,
          paid_on: paid_on,
          description: description,
          amount_cents: amount_cents
        }
      end
      grouped
    end
  end
end
