class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :grade, null: false, foreign_key: true
      t.string :name, null: false
      t.date :starts_on, null: false
      t.date :ends_on

      t.timestamps
    end

    add_index :events, [:grade_id, :starts_on]
  end
end
