class Card < ApplicationRecord
  encrypts :pin
  belongs_to :client, class_name: "User"
  belongs_to :product
  enum :status, { issued: "issued", cancelled: "cancelled" }, validate: true
  validates :activation_number, :idempotency_key, :request_fingerprint, presence: true
  validates :activation_number, uniqueness: true
  validates :idempotency_key, uniqueness: { scope: :client_id }
  validates :face_value_snapshot, numericality: { greater_than: 0 }
  validates :payout_rate_snapshot, numericality: { in: 0..100 }
  validates :payout_amount_snapshot, numericality: { greater_than_or_equal_to: 0 }
  validates :currency_snapshot, format: { with: /\A[A-Z]{3}\z/ }
  validate :cancellation_timestamp_matches_status

  private

  def cancellation_timestamp_matches_status
    return if (issued? && cancelled_at.nil?) || (cancelled? && cancelled_at.present?)
    errors.add(:cancelled_at, "must agree with status")
  end
end
