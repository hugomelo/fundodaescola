class TripCostEntry < ApplicationRecord
  belongs_to :trip

  validates :year, presence: true, numericality: { only_integer: true },
                   uniqueness: { scope: :trip_id }
  validates :amount_cents, numericality: { only_integer: true }
end
