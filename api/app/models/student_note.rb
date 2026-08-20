class StudentNote < ApplicationRecord
  belongs_to :student
  belongs_to :user, optional: true

  validates :body, presence: true
  validates :occurred_on, presence: true

  before_validation :default_occurred_on

  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }

  private

  def default_occurred_on
    self.occurred_on ||= Date.current
  end
end
