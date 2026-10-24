class Product < ApplicationRecord
  belongs_to :brand
  has_many :cards, dependent: :restrict_with_error
  has_many :product_accesses, dependent: :restrict_with_error
  enum :state, { active: "active", inactive: "inactive" }, validate: true

  validates :name, presence: true
  validates :currency, format: { with: /\A[A-Z]{3}\z/ }
  validates :face_value, numericality: { greater_than: 0 }
  validate :valid_custom_fields
  validate :deleted_products_are_inactive

  scope :not_deleted, -> { where(deleted_at: nil) }

  private

  def valid_custom_fields
    errors.add(:custom_fields, "must be a JSON object with at most five keys") unless custom_fields.is_a?(Hash) && custom_fields.size <= 5
  end

  def deleted_products_are_inactive
    errors.add(:state, "must be inactive after deletion") if deleted_at.present? && !inactive?
  end
end
