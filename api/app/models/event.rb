class Event < ApplicationRecord
  belongs_to :grade

  validates :name, presence: true
  validates :starts_on, presence: true

  scope :covering, ->(date) {
    where("starts_on <= :d AND (ends_on IS NULL AND starts_on = :d OR ends_on >= :d)", d: date)
  }

  # A single-day event covers only its start date; a ranged event covers the span.
  def covers?(date)
    return starts_on == date if ends_on.nil?

    (starts_on..ends_on).cover?(date)
  end
end
