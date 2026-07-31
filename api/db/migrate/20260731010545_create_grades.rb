class CreateGrades < ActiveRecord::Migration[8.1]
  def change
    create_table :grades do |t|
      t.string :name, null: false
      t.string :school_name
      t.date :school_year_start
      t.date :school_year_end
      t.bigint :target_total_cents, null: false, default: 0
      t.text :description
      t.string :currency, null: false, default: "BRL"

      t.timestamps
    end
  end
end
