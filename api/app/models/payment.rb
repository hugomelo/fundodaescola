class Payment < ApplicationRecord
  belongs_to :grade
  belongs_to :student, optional: true
  belongs_to :payer_mapping, optional: true

  enum :kind, { student_contribution: 0, event: 1 }

  validates :paid_on, presence: true
  validates :description, presence: true
  validates :amount_cents, numericality: { only_integer: true }
  validate :student_only_for_contributions

  scope :contributions, -> { where(kind: :student_contribution) }
  scope :events, -> { where(kind: :event) }
  scope :in_month, ->(month) {
    where(paid_on: month.beginning_of_month..month.end_of_month)
  }

  private

  def student_only_for_contributions
    if event? && student_id.present?
      errors.add(:student, "must be blank for event payments")
    end
  end
end
