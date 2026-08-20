class CreateStudentNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :student_notes do |t|
      t.references :student, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.date :occurred_on, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :student_notes, [:student_id, :occurred_on]
  end
end
