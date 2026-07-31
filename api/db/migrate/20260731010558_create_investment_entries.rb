class CreateInvestmentEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :investment_entries do |t|
      t.references :grade, null: false, foreign_key: true
      t.date :month, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.string :note

      t.timestamps
    end

    add_index :investment_entries, [:grade_id, :month], unique: true
  end
end
