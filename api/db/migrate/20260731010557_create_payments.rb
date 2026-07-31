class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :grade, null: false, foreign_key: true
      t.references :student, null: true, foreign_key: true
      t.references :payer_mapping, null: true, foreign_key: true
      t.date :paid_on, null: false
      t.string :paid_time
      t.string :description, null: false
      t.bigint :amount_cents, null: false, default: 0
      t.integer :kind, null: false, default: 0
      t.string :external_ref

      t.timestamps
    end

    add_index :payments, :paid_on
    add_index :payments, [:grade_id, :external_ref], unique: true, where: "external_ref IS NOT NULL"
  end
end
