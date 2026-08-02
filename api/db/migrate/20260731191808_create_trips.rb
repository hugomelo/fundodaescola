class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.references :grade, null: false, foreign_key: true
      t.string :name, null: false
      t.string :level
      t.integer :trip_year, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :trips, [:grade_id, :position]
  end
end
