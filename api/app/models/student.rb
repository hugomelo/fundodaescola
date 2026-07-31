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

  # Sum of pledged amounts for enrolled months up to and including `up_to` (default: current month).
  def expected_cents(up_to: Date.current.beginning_of_month)
    monthly_pledges
      .where(status: :pledged)
      .where("month <= ?", up_to)
      .sum(:amount_cents)
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
