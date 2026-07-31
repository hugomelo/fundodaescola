class CreateMonthlyPledges < ActiveRecord::Migration[8.1]
  def change
    create_table :monthly_pledges do |t|
      t.references :student, null: false, foreign_key: true
      t.date :month, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :monthly_pledges, [:student_id, :month], unique: true
  end
end
