require "rails_helper"

RSpec.describe "PostgreSQL uniqueness constraints" do
  let!(:client) do
    User.create!(email: "constraints-client@example.test", password: "safe-test-password",
      role: :client, payout_rate: 90)
  end
  let!(:product) do
    brand = Brand.create!(name: "Constraints brand")
    Product.create!(brand: brand, name: "Gift", face_value: 100, currency: "USD")
  end
  let(:attributes) do
    { client: client, product: product, activation_number: "unique-activation-A",
      idempotency_key: "unique-key-A", request_fingerprint: "fingerprint",
      face_value_snapshot: 100, currency_snapshot: "USD",
      payout_rate_snapshot: 90, payout_amount_snapshot: 90,
      issued_at: Time.current }
  end

  it "rejects duplicated activation numbers even when model validations are bypassed" do
    first = Card.create!(attributes)
    duplicate = first.dup
    duplicate.idempotency_key = "unique-key-B"
    expect {
      Card.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects duplicated client/idempotency pairs at database level" do
    first = Card.create!(attributes)
    duplicate = first.dup
    duplicate.activation_number = "unique-activation-B"
    expect {
      Card.transaction(requires_new: true) { duplicate.save!(validate: false) }
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
