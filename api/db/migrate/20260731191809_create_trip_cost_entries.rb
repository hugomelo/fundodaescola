class CreateTripCostEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :trip_cost_entries do |t|
      t.references :trip, null: false, foreign_key: true
      t.integer :year, null: false
      t.bigint :amount_cents, null: false, default: 0

      t.timestamps
    end

    add_index :trip_cost_entries, [:trip_id, :year], unique: true
  end
end
