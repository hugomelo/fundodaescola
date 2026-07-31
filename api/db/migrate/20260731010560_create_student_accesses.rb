class CreateStudentAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :student_accesses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: true

      t.timestamps
    end

    add_index :student_accesses, [:user_id, :student_id], unique: true
  end
end
