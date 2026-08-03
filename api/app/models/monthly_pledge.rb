class MonthlyPledge < ApplicationRecord
  belongs_to :student

  enum :status, { pledged: 0, not_applicable: 1 }

  validates :month, presence: true, uniqueness: { scope: :student_id }
  validates :amount_cents, numericality: { only_integer: true }

  before_validation :normalize_month
  after_save :clear_stale_enrolled_until

  scope :for_month, ->(month) { where(month: month.beginning_of_month) }

  private

  def normalize_month
    self.month = month.beginning_of_month if month.present?
  end

  # A pledge after "saída" means the student is still enrolled — clear the stale date
  # so expected_cents keeps accumulating (carry-forward) through today.
  def clear_stale_enrolled_until
    until_date = student.enrolled_until
    return if until_date.blank? || month.blank?
    return unless month > until_date.beginning_of_month

    student.update_column(:enrolled_until, nil)
  end
end
