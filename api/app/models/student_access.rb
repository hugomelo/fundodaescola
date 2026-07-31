class StudentAccess < ApplicationRecord
  belongs_to :user
  belongs_to :student

  validates :student_id, uniqueness: { scope: :user_id }
end
