class User < ApplicationRecord
  RESET_PASSWORD_EXPIRY = 24.hours

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

  # Returns the raw token (send this in the email). Only a SHA-256 digest is stored.
  def generate_password_reset_token!
    raw = SecureRandom.urlsafe_base64(32)
    update!(
      reset_password_token: self.class.digest_reset_token(raw),
      reset_password_sent_at: Time.current
    )
    raw
  end

  def deliver_invite!
    raw = generate_password_reset_token!
    UserMailer.with(user: self, token: raw).invite.deliver_later
  end

  def clear_password_reset_token!
    update!(reset_password_token: nil, reset_password_sent_at: nil)
  end

  def password_reset_period_valid?
    reset_password_sent_at.present? && reset_password_sent_at > RESET_PASSWORD_EXPIRY.ago
  end

  def self.find_by_password_reset_token(raw)
    return nil if raw.blank?

    find_by(reset_password_token: digest_reset_token(raw))
  end

  def self.digest_reset_token(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase if email.present?
  end
end
