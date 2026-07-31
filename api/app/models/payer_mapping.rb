class PayerMapping < ApplicationRecord
  belongs_to :grade
  belongs_to :student, optional: true

  validates :payer_text, presence: true, uniqueness: { scope: :grade_id, case_sensitive: false }
  validate :student_or_event

  before_validation :normalize_payer_text

  # Look up a mapping for a raw bank description within a grade.
  def self.match(grade_id, payer_text)
    where(grade_id: grade_id).where("LOWER(payer_text) = ?", payer_text.to_s.strip.downcase).first
  end

  private

  def normalize_payer_text
    self.payer_text = payer_text.to_s.strip if payer_text.present?
  end

  def student_or_event
    if maps_to_event? && student_id.present?
      errors.add(:base, "mapping cannot point to both a student and an event")
    elsif !maps_to_event? && student_id.blank?
      errors.add(:base, "mapping must point to a student or be marked as an event")
    end
  end
end
