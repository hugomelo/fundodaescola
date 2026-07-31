class CreateStudents < ActiveRecord::Migration[8.1]
  def change
    create_table :students do |t|
      t.references :grade, null: false, foreign_key: true
      t.string :full_name, null: false
      t.string :display_name
      t.date :enrolled_from
      t.date :enrolled_until
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
