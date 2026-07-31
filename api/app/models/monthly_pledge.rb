class MonthlyPledge < ApplicationRecord
  belongs_to :student

  enum :status, { pledged: 0, not_applicable: 1 }

  validates :month, presence: true, uniqueness: { scope: :student_id }
  validates :amount_cents, numericality: { only_integer: true }

  before_validation :normalize_month

  scope :for_month, ->(month) { where(month: month.beginning_of_month) }

  private

  def normalize_month
    self.month = month.beginning_of_month if month.present?
  end
end
