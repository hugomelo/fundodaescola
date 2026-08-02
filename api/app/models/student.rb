class Student < ApplicationRecord
  belongs_to :grade

  has_many :monthly_pledges, dependent: :destroy
  has_many :payments, dependent: :nullify
  has_many :payer_mappings, dependent: :nullify
  has_many :student_accesses, dependent: :destroy
  has_many :users, through: :student_accesses

  validates :full_name, presence: true

  scope :active, -> { where(active: true) }

  before_validation :default_display_name

  # Total actually contributed by this student (their contribution payments, signed).
  def contributed_cents
    payments.where(kind: :student_contribution).sum(:amount_cents)
  end

  # Pledges are effective-from markers: a pledge set for a month stays in effect
  # until the next pledge. This returns the amount (and status) in effect for the
  # given month, or nil if no pledge has started yet.
  #   entries: pass a preloaded, month-ascending array to avoid repeated queries.
  def effective_pledge(month, entries = nil)
    month = month.to_date.beginning_of_month
    entries ||= monthly_pledges.order(:month).to_a
    current = nil
    entries.each do |e|
      break if e.month.beginning_of_month > month

      current = e
    end
    return nil unless current

    [current.pledged? ? current.amount_cents : 0, current.status]
  end

  # Sum of the *effective* pledged amount for each enrolled month from the first
  # pledge through `up_to` (carrying each pledge forward until the next one).
  def expected_cents(up_to: Date.current.beginning_of_month)
    entries = monthly_pledges.order(:month).to_a
    return 0 if entries.empty?

    start = entries.first.month.beginning_of_month
    last = up_to.to_date.beginning_of_month
    last = enrolled_until.beginning_of_month if enrolled_until && enrolled_until.beginning_of_month < last
    return 0 if last < start

    total = 0
    idx = 0
    amount = 0
    month = start
    while month <= last
      while idx < entries.size && entries[idx].month.beginning_of_month <= month
        e = entries[idx]
        amount = e.pledged? ? e.amount_cents : 0
        idx += 1
      end
      total += amount
      month = month.next_month
    end
    total
  end

  # Positive => ahead of pledge, negative => behind.
  def balance_cents(up_to: Date.current.beginning_of_month)
    contributed_cents - expected_cents(up_to: up_to)
  end

  private

  def default_display_name
    self.display_name = full_name.to_s.strip.split(/\s+/).first if display_name.blank? && full_name.present?
  end
end
