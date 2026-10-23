require "rails_helper"

RSpec.describe "Gift card core schema" do
  let(:client) do
    User.create!(email: "client@example.test", password: "example-password-for-tests", role: :client, payout_rate: 90)
  end
  let(:brand) { Brand.create!(name: "Example brand") }
  let(:product) do
    Product.create!(brand: brand, name: "Gift card", face_value: "100.00", currency: "USD")
  end

  it "normalizes and validates case-insensitive user emails" do
    client
    duplicate = User.new(email: " CLIENT@EXAMPLE.TEST ", password: "example-password-for-tests",
      role: :client, payout_rate: 80)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).not_to be_empty
  end

  it "rejects nonclient product access and duplicate grants" do
    expect(ProductAccess.create!(client: client, product: product)).to be_persisted
    expect(ProductAccess.new(client: client, product: product)).not_to be_valid
    admin = User.create!(email: "admin@example.test", password: "example-password-for-tests", role: :admin)
    expect(ProductAccess.new(client: admin, product: product)).not_to be_valid
  end

  it "enforces the maximum number of custom fields" do
    expect(Brand.new(name: "Valid", custom_fields: { a: 1, b: 2, c: 3, d: 4, e: 5 })).to be_valid
    expect(Brand.new(name: "Invalid", custom_fields: { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6 })).not_to be_valid
  end

  it "creates a card with an immutable financial snapshot schema" do
    card = Card.create!(client: client, product: product,
      activation_number: "activation-for-test-001", idempotency_key: "order-001",
      request_fingerprint: "sha256-test", face_value_snapshot: "100.00",
      currency_snapshot: "USD", payout_rate_snapshot: "90.0000",
      payout_amount_snapshot: "90.00", issued_at: Time.current)
    expect(card).to be_issued
    expect(card.payout_amount_snapshot).to eq(BigDecimal("90"))
    duplicate = card.dup
    duplicate.activation_number = "another-number"
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:idempotency_key]).to be_present
  end

  it "persists safe audit event metadata" do
    event = AuditEvent.create!(actor: client, action: "auth.login_succeeded",
      record_type: "User", record_id: client.id, outcome: :success)
    expect(event.occurred_at).to be_present
    expect(event.outcome).to eq("success")
  end
end
