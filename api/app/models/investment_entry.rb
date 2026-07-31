class InvestmentEntry < ApplicationRecord
  belongs_to :grade

  validates :month, presence: true, uniqueness: { scope: :grade_id }
  validates :amount_cents, numericality: { only_integer: true }

  before_validation :normalize_month

  private

  def normalize_month
    self.month = month.beginning_of_month if month.present?
  end
end
