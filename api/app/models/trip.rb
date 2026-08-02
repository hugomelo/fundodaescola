class Trip < ApplicationRecord
  belongs_to :grade

  has_many :cost_entries, class_name: "TripCostEntry", dependent: :destroy

  validates :name, presence: true
  validates :trip_year, presence: true, numericality: { only_integer: true }

  scope :ordered, -> { order(:position, :trip_year, :id) }

  # Best-known real cost for `year`, or nil if no data.
  # Uses the most recent entry whose year <= `year` as the base and inflates it
  # forward at `rate` (a real value entered for a later year overrides the
  # projection from that year on).
  def cost_cents_for(year, rate)
    entries = cost_entries.sort_by(&:year)
    return nil if entries.empty?

    base = entries.select { |e| e.year <= year }.last || entries.first
    factor = (1.0 + rate.to_f)**(year - base.year)
    (base.amount_cents * factor).round
  end

  # The projected (or real) cost per student at the year this trip happens.
  def projected_cost_cents(rate)
    cost_cents_for(trip_year, rate)
  end

  # True when an actual value was entered for the trip's own year.
  def actual_for_trip_year?
    cost_entries.exists?(year: trip_year)
  end

  def base_entry
    cost_entries.min_by(&:year)
  end
end
