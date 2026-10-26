require "rails_helper"

RSpec.describe "Financial report Card drill-down", type: :request do
  let!(:admin) { User.create!(email: "drill-admin@example.test", password: "test-password", role: :admin) }
  let!(:client) { User.create!(email: "drill-client@example.test", password: "test-password", role: :client, payout_rate: 90) }
  let!(:another) { User.create!(email: "drill-other@example.test", password: "test-password", role: :client, payout_rate: 90) }
  let!(:brand) { Brand.create!(name: "Drilldown Brand") }
  let!(:other_brand) { Brand.create!(name: "Another Drilldown Brand") }
  let!(:product) { Product.create!(brand: brand, name: "Sample USD", face_value: 100, currency: "USD") }
  let!(:other_product) { Product.create!(brand: other_brand, name: "Other USD", face_value: 50, currency: "USD") }
  let(:client_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}" } }
  let(:other_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(another)}" } }
  let(:admin_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" } }

  def make_card(owner:, item:, number:, issued_at:, cancelled_at: nil)
    Card.create!(client: owner, product: item, activation_number: "drilldown#{number}",
      idempotency_key: "drill#{number}", request_fingerprint: "fingerprint#{number}",
      status: cancelled_at ? "cancelled" : "issued",
      face_value_snapshot: item.face_value, currency_snapshot: item.currency,
      payout_rate_snapshot: 90, payout_amount_snapshot: item.face_value * 0.9,
      issued_at: issued_at, cancelled_at: cancelled_at)
  end

  let!(:card_cancelled_later) do
    make_card(owner: client, item: product, number: "001",
      issued_at: Time.utc(2026, 10, 1, 12), cancelled_at: Time.utc(2026, 11, 4, 9))
  end
  let!(:card_cancelled_in_period) do
    make_card(owner: client, item: product, number: "002",
      issued_at: Time.utc(2026, 9, 3, 12), cancelled_at: Time.utc(2026, 10, 12, 17))
  end
  let!(:card_active) do
    make_card(owner: client, item: product, number: "003",
      issued_at: Time.utc(2026, 10, 11, 10))
  end
  let!(:card_end_excluded) do
    make_card(owner: client, item: product, number: "004",
      issued_at: Time.utc(2026, 11, 1, 0))
  end
  let!(:card_different_brand) do
    make_card(owner: client, item: other_product, number: "005",
      issued_at: Time.utc(2026, 10, 15, 9))
  end
  let!(:other_client_card) do
    make_card(owner: another, item: product, number: "006",
      issued_at: Time.utc(2026, 10, 17, 9))
  end

  it "returns exactly the personal issued event Cards (including ones cancelled later)" do
    q = { currency: "USD", event: "issued", from: "2026-10-01", to: "2026-11-01" }
    get "/api/v1/client/reports/spending", headers: client_headers,
      params: { group_by: "currency", from: q[:from], to: q[:to] }
    expected = response.parsed_body.fetch("data").first.fetch("issued_count")
    get "/api/v1/client/reports/cards", headers: client_headers, params: q.merge(per_page: 2)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(expected)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq(
      [ card_different_brand.id, card_active.id ])
    expect(response.body).not_to include('"pin"', "request_fingerprint", "idempotency_key",
      other_client_card.activation_number)
    get "/api/v1/client/reports/cards", headers: client_headers,
      params: q.merge(page: 2, per_page: 2)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ card_cancelled_later.id ])
    expect(response.parsed_body.fetch("data").first.fetch("status")).to eq("cancelled")
    expect(response.parsed_body.fetch("data").first.fetch("occurred_at")).to start_with("2026-10-01")
  end

  it "matches cancelled events using cancellation time, not current status or issue time" do
    q = { currency: "USD", event: "cancelled", from: "2026-10-01", to: "2026-11-01" }
    get "/api/v1/client/reports/spending", headers: client_headers,
      params: { from: q[:from], to: q[:to] }
    expect(response.parsed_body.fetch("data").first.fetch("cancelled_count")).to eq(1)
    get "/api/v1/client/reports/cards", headers: client_headers, params: q
    expect(response.parsed_body.dig("meta", "total")).to eq(1)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ card_cancelled_in_period.id ])
  end

  it "scopes Client brand drill-down to only its own Cards and refuses forged client_id" do
    get "/api/v1/client/reports/cards", headers: client_headers,
      params: { currency: "USD", event: "issued", brand_id: brand.id,
        from: "2026-10-01", to: "2026-11-01" }
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    expect(response.parsed_body.fetch("data").pluck("id")).to match_array(
      [ card_active.id, card_cancelled_later.id ])
    expect(response.body).not_to include(other_client_card.activation_number)
    get "/api/v1/client/reports/cards", headers: other_headers,
      params: { currency: "USD", event: "issued", brand_id: brand.id }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ other_client_card.id ])
    get "/api/v1/client/reports/cards", headers: client_headers,
      params: { currency: "USD", event: "issued", client_id: another.id }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
  end

  it "allows Admin to drill down by the chosen Brand or Client (read-only)" do
    get "/api/v1/admin/reports/by_brand", headers: admin_headers,
      params: { from: "2026-10-01", to: "2026-11-01" }
    expected_brand = response.parsed_body.fetch("data").find do |r|
      r["brand_id"] == brand.id && r["currency"] == "USD"
    end.fetch("issued_count")
    get "/api/v1/admin/reports/cards", headers: admin_headers,
      params: { group_by: "brand", brand_id: brand.id, currency: "USD",
        event: "issued", from: "2026-10-01", to: "2026-11-01" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(expected_brand)
    expect(response.parsed_body.fetch("data").pluck("id")).to match_array(
      [ card_cancelled_later.id, card_active.id, other_client_card.id ])
    get "/api/v1/admin/reports/cards", headers: admin_headers,
      params: { group_by: "client", client_id: client.id, currency: "USD",
        event: "cancelled", from: "2026-10-01", to: "2026-11-01" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ card_cancelled_in_period.id ])
    get "/api/v1/admin/reports/cards", headers: client_headers,
      params: { group_by: "brand", brand_id: brand.id, currency: "USD", event: "issued" }
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects invalid event, currency, group IDs and dates without changing records" do
    initial = [ Card.count, AuditEvent.count ]
    [
      { event: "issued", currency: "usd" },
      { event: "active", currency: "USD" },
      { event: "issued", currency: "USD", brand_id: "-1" },
      { event: "issued", currency: "USD", from: "2026-11-01", to: "2026-10-01" }
    ].each do |params|
      get "/api/v1/client/reports/cards", headers: client_headers, params: params
      expect(response).to have_http_status(:unprocessable_content)
    end
    get "/api/v1/client/reports/cards?event[]=issued&currency=USD", headers: client_headers
    expect(response).to have_http_status(:unprocessable_content)
    get "/api/v1/admin/reports/cards", headers: admin_headers,
      params: { event: "issued", currency: "USD", group_by: "brand" }
    expect(response).to have_http_status(:unprocessable_content)
    get "/api/v1/admin/reports/cards", headers: admin_headers,
      params: { event: "issued", currency: "USD", group_by: "brand",
        brand_id: brand.id, client_id: client.id }
    expect(response).to have_http_status(:unprocessable_content)
    expect([ Card.count, AuditEvent.count ]).to eq(initial)
  end
end
