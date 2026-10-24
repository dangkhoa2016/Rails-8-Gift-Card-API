require "rails_helper"

RSpec.describe "Client card issuance and safe retries", type: :request do
  let!(:client) do
    User.create!(email: "issue-client@example.test", password: "strong-test-password",
      role: :client, payout_rate: "90.0000")
  end
  let!(:brand) { Brand.create!(name: "Gift brand") }
  let!(:product) { Product.create!(brand: brand, name: "Gift", face_value: "100.00", currency: "USD") }
  let(:headers) do
    { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}", "Idempotency-Key" => "order-001" }
  end

  before { ProductAccess.create!(client: client, product: product) }

  it "issues one card with encrypted PIN, snapshots and a safe success audit" do
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: true }, as: :json
    expect(response).to have_http_status(:created)
    data = response.parsed_body.fetch("data")
    expect(data.fetch("pin")).to match(/\A[0-9]{6}\z/)
    card = Card.find(data.fetch("id"))
    expect(card.payout_amount_snapshot).to eq(BigDecimal("90.00"))
    ciphertext = Card.connection.select_value("SELECT pin FROM cards WHERE id=#{card.id}")
    expect(ciphertext).not_to eq(data.fetch("pin"))
    expect(ciphertext).not_to be_blank
    event = AuditEvent.find_by!(action: "card.issued", record_id: card.id)
    expect(event.after_data.keys).not_to include("pin", "password", "activation_number")
  end

  it "replays the original result without another card or issue success event" do
    2.times do |index|
      post "/api/v1/client/cards", headers: headers,
        params: { product_id: product.id, with_pin: true }, as: :json
      expect(response).to have_http_status(index.zero? ? :created : :ok)
    end
    expect(Card.where(client: client).count).to eq(1)
    expect(AuditEvent.where(action: "card.issued", actor: client).count).to eq(1)
    product.update!(state: "inactive")
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: true }, as: :json
    expect(response).to have_http_status(:ok)
    expect(Card.where(client: client).count).to eq(1)
  end

  it "rejects key reuse with different payload and records a safe refusal" do
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: false }, as: :json
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: true }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig("error", "code")).to eq("idempotency_key_reused")
    expect(Card.count).to eq(1)
    expect(AuditEvent.find_by!(action: "card.issue_refused").reason_code).to eq("idempotency_key_reused")
  end

  it "denies issuance without a product grant or when brand becomes inactive" do
    ProductAccess.delete_all
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(Card.count).to eq(0)
    ProductAccess.create!(client: client, product: product)
    brand.update!(state: "inactive")
    post "/api/v1/client/cards", headers: headers.merge("Idempotency-Key" => "order-002"),
      params: { product_id: product.id }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(AuditEvent.where(action: "card.issue_refused").count).to eq(2)
  end

  it "rejects missing or invalid keys and invalid input" do
    post "/api/v1/client/cards", headers: headers.except("Idempotency-Key"),
      params: { product_id: product.id }, as: :json
    expect(response.parsed_body.dig("error", "code")).to eq("idempotency_key_required")
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: "maybe" }, as: :json
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_with_pin")
  end

  it "only lists and shows the current client's cards without exposing PIN" do
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: true }, as: :json
    card_id = response.parsed_body.dig("data", "id")
    get "/api/v1/client/cards", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('"pin"')
    get "/api/v1/client/cards/#{card_id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('"pin"')
    other = User.create!(email: "other@example.test", password: "other-password", role: :client, payout_rate: 80)
    get "/api/v1/client/cards/#{card_id}",
      headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other)}" }
    expect(response).to have_http_status(:not_found)
  end

  it "uses rate and value snapshots even after updates" do
    post "/api/v1/client/cards", headers: headers, params: { product_id: product.id }, as: :json
    card = Card.last
    client.update!(payout_rate: 70)
    product.update!(face_value: 200)
    expect(card.reload.face_value_snapshot).to eq(BigDecimal("100"))
    expect(card.payout_rate_snapshot).to eq(BigDecimal("90"))
    expect(card.payout_amount_snapshot).to eq(BigDecimal("90"))
  end
  it "allows different clients to reuse the same idempotency key independently" do
    other = User.create!(email: "different-client@example.test",
      password: "safe-test-password", role: :client, payout_rate: 80)
    ProductAccess.create!(client: other, product: product)
    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: false }, as: :json
    first_id = response.parsed_body.dig("data", "id")
    other_headers = { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other)}",
      "Idempotency-Key" => "order-001" }
    post "/api/v1/client/cards", headers: other_headers,
      params: { product_id: product.id, with_pin: false }, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("data", "id")).not_to eq(first_id)
    expect(Card.count).to eq(2)
  end
end
