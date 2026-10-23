class Brand < ApplicationRecord
  enum :state, { active: "active", inactive: "inactive" }, validate: true
  has_many :products, dependent: :restrict_with_error
  validates :name, presence: true
  validate :valid_custom_fields

  private

  def valid_custom_fields
    errors.add(:custom_fields, "must be a JSON object with at most five keys") unless custom_fields.is_a?(Hash) && custom_fields.size <= 5
  end
end
