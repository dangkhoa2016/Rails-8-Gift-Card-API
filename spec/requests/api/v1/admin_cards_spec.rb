require "rails_helper"

RSpec.describe "Admin Client Card operations", type: :request do
  let!(:admin) do
    User.create!(email: "cards-admin@example.test", password: "admin-test-password",
      role: :admin)
  end
  let!(:client) do
    User.create!(email: "cards-owner@example.test", password: "client-test-password",
      role: :client, payout_rate: "87.5000")
  end
  let!(:other_client) do
    User.create!(email: "cards-other@example.test", password: "other-test-password",
      role: :client, payout_rate: "80.0000")
  end
  let!(:brand) { Brand.create!(name: "Admin Cards Brand") }
  let!(:product) do
    Product.create!(brand: brand, name: "Gift", face_value: "120.00", currency: "USD")
  end
  let(:issue_path) { "/api/v1/admin/clients/#{client.id}/cards" }
  let(:headers) do
    { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}",
      "Idempotency-Key" => "admin-card-001" }
  end

  before { ProductAccess.create!(client: client, product: product) }

  def issue_card(payload = { product_id: product.id, with_pin: false }, path: issue_path, auth: headers)
    post path, params: payload, headers: auth, as: :json
  end

  it "issues once under the selected Client, retains snapshots and audits the Admin" do
    issue_card
    expect(response).to have_http_status(:created)
    data = response.parsed_body.fetch("data")
    card = Card.find(data.fetch("id"))
    expect(card.client_id).to eq(client.id)
    expect(card.payout_rate_snapshot).to eq(BigDecimal("87.5"))
    expect(card.payout_amount_snapshot).to eq(BigDecimal("105.00"))
    expect(data.fetch("has_pin")).to be(false)
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(response.body).not_to include('"pin"', '"idempotency_key"', '"request_fingerprint"')
    event = AuditEvent.find_by!(action: "card.issued", record_id: card.id)
    expect(event.actor).to eq(admin)
    expect(event.after_data.fetch("client_id")).to eq(client.id)
  end

  it "returns 200 for the identical key, and 409 if the payload differs" do
    issue_card
    expect(response).to have_http_status(:created)
    card_id = response.parsed_body.dig("data", "id")
    issue_card
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "id")).to eq(card_id)
    expect(AuditEvent.where(action: "card.issued", actor: admin).count).to eq(1)
    issue_card({ product_id: product.id, with_pin: true })
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig("error", "code")).to eq("idempotency_key_reused")
    expect(AuditEvent.find_by!(action: "card.issue_refused").actor).to eq(admin)
    expect(Card.where(client: client).count).to eq(1)
  end

  it "never returns the PIN even if Admin requests a PIN-protected Card" do
    issue_card({ product_id: product.id, with_pin: true })
    expect(response).to have_http_status(:created)
    data = response.parsed_body.fetch("data")
    card = Card.find(data.fetch("id"))
    expect(card.read_attribute_before_type_cast(:pin)).to be_present
    expect(data.fetch("has_pin")).to be(true)
    expect(response.body).not_to include('"pin"', card.pin)
    issue_card({ product_id: product.id, with_pin: true })
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include('"pin"', card.pin)
  end

  it "cancels the selected Client Card once, using the Admin as audit actor" do
    issue_card
    id = response.parsed_body.dig("data", "id")
    post "#{issue_path}/#{id}/cancel", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "status")).to eq("cancelled")
    expect(Card.find(id)).to be_cancelled
    expect(AuditEvent.find_by!(action: "card.cancelled", record_id: id).actor).to eq(admin)
    post "#{issue_path}/#{id}/cancel", headers: headers
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig("error", "code")).to eq("already_cancelled")
    expect(AuditEvent.find_by!(action: "card.cancel_refused").actor).to eq(admin)
  end

  it "cannot cancel a Card that belongs to another Client" do
    issue_card
    id = response.parsed_body.dig("data", "id")
    post "/api/v1/admin/clients/#{other_client.id}/cards/#{id}/cancel", headers: headers
    expect(response).to have_http_status(:not_found)
    expect(Card.find(id)).to be_issued
  end

  it "requires a valid Admin session, never granting this route to a Client" do
    client_auth = { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}",
      "Idempotency-Key" => "wrong-role" }
    issue_card(auth: client_auth)
    expect(response).to have_http_status(:forbidden)
    expect(Card.count).to eq(0)
    post "#{issue_path}/123/cancel", headers: client_auth
    expect(response).to have_http_status(:forbidden)
    issue_card(auth: {})
    expect(response).to have_http_status(:unauthorized)
  end

  it "requires an existing active Client with access to the Product" do
    issue_card(path: "/api/v1/admin/clients/#{admin.id}/cards")
    expect(response).to have_http_status(:not_found)
    issue_card(path: "/api/v1/admin/clients/999999999/cards")
    expect(response).to have_http_status(:not_found)
    client.update!(active: false)
    issue_card
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("client_inactive")
    client.update!(active: true)
    ProductAccess.where(client: client).delete_all
    issue_card
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("product_unavailable")
    expect(Card.count).to eq(0)
  end

  it "keeps all existing Client routes and their audited identity intact" do
    client_auth = { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}",
      "Idempotency-Key" => "client-issue-own" }
    post "/api/v1/client/cards", headers: client_auth,
      params: { product_id: product.id }, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.dig("data", "id")
    expect(AuditEvent.find_by!(action: "card.issued", record_id: id).actor).to eq(client)
    post "/api/v1/client/cards/#{id}/cancel", headers: client_auth
    expect(response).to have_http_status(:ok)
    expect(AuditEvent.find_by!(action: "card.cancelled", record_id: id).actor).to eq(client)
  end
end
