class User < ApplicationRecord
  has_secure_password

  belongs_to :grade, optional: true

  has_many :student_accesses, dependent: :destroy
  has_many :students, through: :student_accesses

  enum :role, { super_admin: 0, grade_admin: 1, parent: 2 }

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true

  before_validation :normalize_email

  # Grades this user is allowed to see.
  def accessible_grade_ids
    case role
    when "super_admin" then Grade.pluck(:id)
    when "grade_admin" then [grade_id].compact
    when "parent" then students.distinct.pluck(:grade_id)
    else []
    end
  end

  def can_admin_grade?(a_grade_id)
    super_admin? || (grade_admin? && grade_id == a_grade_id)
  end

  def can_access_student?(a_student_id)
    return true if super_admin?
    return Student.where(id: a_student_id, grade_id: grade_id).exists? if grade_admin?

    student_accesses.where(student_id: a_student_id).exists?
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
