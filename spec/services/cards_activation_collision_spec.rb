require "rails_helper"

RSpec.describe "Activation number collision recovery" do
  it "retries only the generated activation number and persists one issue audit" do
    client = User.create!(email: "collision-client@example.test", password: "safe-password",
      role: :client, payout_rate: 90)
    brand = Brand.create!(name: "Collision brand")
    product = Product.create!(brand: brand, name: "Gift", face_value: 100, currency: "USD")
    ProductAccess.create!(client: client, product: product)
    Card.create!(client: client, product: product, activation_number: "collision-number",
      idempotency_key: "older-order", request_fingerprint: "old",
      face_value_snapshot: 100, currency_snapshot: "USD",
      payout_rate_snapshot: 90, payout_amount_snapshot: 90, issued_at: Time.current)

    request_info = Struct.new(:remote_ip, :user_agent).new("127.0.0.1", "RSpec")
    service = Cards::Issue.new(client: client, product_id: product.id, with_pin: false,
      idempotency_key: "fresh-order", request: request_info)
    allow(service).to receive(:generate_activation_number).and_return(
      "collision-number", "new-unique-number")
    result = service.call

    expect(result.created).to eq(true)
    expect(result.card.activation_number).to eq("new-unique-number")
    expect(Card.where(client: client).count).to eq(2)
    expect(AuditEvent.where(action: "card.issued", record_id: result.card.id).count).to eq(1)
  end
end
