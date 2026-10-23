class ProductAccess < ApplicationRecord
  belongs_to :client, class_name: "User"
  belongs_to :product
  validates :product_id, uniqueness: { scope: :client_id }
  validate :client_has_client_role

  private

  def client_has_client_role
    errors.add(:client, "must have the client role") if client && !client.client?
  end
end
