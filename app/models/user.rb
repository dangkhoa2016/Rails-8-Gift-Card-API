class User < ApplicationRecord
  has_secure_password
  enum :role, { admin: "admin", client: "client" }, validate: true
  has_many :cards, foreign_key: :client_id, dependent: :restrict_with_error
  has_many :product_accesses, foreign_key: :client_id, dependent: :restrict_with_error
  has_many :audit_events, foreign_key: :actor_id, dependent: :nullify

  before_validation :normalize_email
  validates :email, presence: true, uniqueness: { case_sensitive: false },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :payout_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :payout_rate, presence: true, if: :client?

  private

  def normalize_email
    self.email = email.strip.downcase if email.present?
  end
end
