require "rails_helper"

RSpec.describe "Client card cancellation", type: :request do
  let!(:client) { User.create!(email: "cancel-client@example.test",
    password: "test-password", role: :client, payout_rate: 90) }
  let!(:brand) { Brand.create!(name: "Brand") }
  let!(:product) { Product.create!(brand: brand, name: "Gift", face_value: 100, currency: "USD") }
  let(:headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}" } }
  let!(:card) do
    Card.create!(client: client, product: product, activation_number: "1234567891234567",
      idempotency_key: "cancel-order", request_fingerprint: "test-fingerprint",
      face_value_snapshot: 100, currency_snapshot: "USD",
      payout_rate_snapshot: 90, payout_amount_snapshot: 90, issued_at: Time.current)
  end

  it "cancels once and keeps historical snapshots" do
    post "/api/v1/client/cards/#{card.id}/cancel", headers: headers
    expect(response).to have_http_status(:ok)
    expect(card.reload).to be_cancelled
    expect(card.cancelled_at).to be_present
    expect(card.payout_amount_snapshot).to eq(BigDecimal("90"))
    event = AuditEvent.find_by!(action: "card.cancelled", record_id: card.id)
    expect(event.before_data.fetch("status")).to eq("issued")
    expect(event.after_data.fetch("status")).to eq("cancelled")
  end

  it "rejects duplicate cancellation and records refusal" do
    2.times { post "/api/v1/client/cards/#{card.id}/cancel", headers: headers }
    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.dig("error", "code")).to eq("already_cancelled")
    expect(AuditEvent.where(action: "card.cancelled").count).to eq(1)
    expect(AuditEvent.find_by!(action: "card.cancel_refused").reason_code).to eq("already_cancelled")
  end

  it "permits cancelling after product and brand deactivate and access is revoked" do
    ProductAccess.create!(client: client, product: product)
    brand.update!(state: "inactive")
    product.update!(state: "inactive")
    ProductAccess.delete_all
    post "/api/v1/client/cards/#{card.id}/cancel", headers: headers
    expect(response).to have_http_status(:ok)
    expect(card.reload).to be_cancelled
  end

  it "returns 404 when a different client attempts to cancel another client's card" do
    other = User.create!(email: "another-client@example.test", password: "test-password",
      role: :client, payout_rate: 90)
    post "/api/v1/client/cards/#{card.id}/cancel",
      headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other)}" }
    expect(response).to have_http_status(:not_found)
    expect(card.reload).to be_issued
    expect(AuditEvent.find_by!(action: "card.cancel_refused").reason_code).to eq("card_not_found")
  end
  it "retains the card and permits cancellation after the product is soft-deleted" do
    product.update!(state: "inactive", deleted_at: Time.current)
    expect(Card.find(card.id).product_id).to eq(product.id)
    post "/api/v1/client/cards/#{card.id}/cancel", headers: headers
    expect(response).to have_http_status(:ok)
    expect(card.reload).to be_cancelled
    expect(product.reload.deleted_at).to be_present
  end
end
