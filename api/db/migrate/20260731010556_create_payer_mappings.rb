class CreatePayerMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :payer_mappings do |t|
      t.references :grade, null: false, foreign_key: true
      t.string :payer_text, null: false
      t.references :student, null: true, foreign_key: true
      t.boolean :maps_to_event, null: false, default: false

      t.timestamps
    end

    add_index :payer_mappings, [:grade_id, :payer_text], unique: true
  end
end
