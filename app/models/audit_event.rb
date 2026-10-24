class AuditEvent < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  enum :outcome, { success: "success", refused: "refused" }, validate: true
  before_validation :set_occurred_at
  validates :action, :record_type, :occurred_at, presence: true

  private

  def set_occurred_at
    self.occurred_at ||= Time.current
  end
end
