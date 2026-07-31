class Grade < ApplicationRecord
  has_many :students, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :payer_mappings, dependent: :destroy
  has_many :investment_entries, dependent: :destroy
  has_many :events, dependent: :destroy
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
end
