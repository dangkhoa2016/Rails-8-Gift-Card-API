require "rails_helper"

RSpec.describe "Human-readable associations for optional reviewer UI", type: :request do
  let!(:admin) { User.create!(email: "labels-admin@example.test", password: "safe-password", role: :admin) }
  let!(:client) { User.create!(email: "labels-client@example.test", password: "safe-password", role: :client, payout_rate: 90) }
  let!(:other_client) { User.create!(email: "labels-other@example.test", password: "safe-password", role: :client, payout_rate: 70) }
  let!(:brand) { Brand.create!(name: "Friendly Coffee") }
  let!(:product) do
    Product.create!(brand: brand, name: "Latte voucher", face_value: 25, currency: "USD")
  end
  let(:admin_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" } }
  let(:client_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}" } }

  before { ProductAccess.create!(client: client, product: product) }

  it "lists brand labels in the authorized client catalog only" do
    get "/api/v1/client/catalog", headers: client_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").sole).to include(
      "name" => "Latte voucher", "brand_name" => "Friendly Coffee"
    )
    get "/api/v1/client/catalog",
      headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other_client)}" }
    expect(response.parsed_body.fetch("data")).to eq([])
  end

  it "includes readable product, brand and client labels in Admin grants" do
    get "/api/v1/admin/clients/#{client.id}/product_accesses", headers: admin_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").sole).to include(
      "product_name" => "Latte voucher", "brand_name" => "Friendly Coffee",
      "client_email" => "labels-client@example.test", "product_currency" => "USD"
    )
    get "/api/v1/admin/clients/#{client.id}/product_accesses", headers: client_headers
    expect(response).to have_http_status(:forbidden)
  end

  it "shows the product and brand for issued and cancelled cards, without exposing PIN" do
    post "/api/v1/client/cards", headers: client_headers.merge("Idempotency-Key" => "labels-issue"),
      params: { product_id: product.id, with_pin: true }, as: :json
    expect(response).to have_http_status(:created)
    card_id = response.parsed_body.dig("data", "id")
    secret_pin = response.parsed_body.dig("data", "pin")

    get "/api/v1/client/cards", headers: client_headers
    expect(response).to have_http_status(:ok)
    row = response.parsed_body.fetch("data").sole
    expect(row).to include("product_name" => "Latte voucher", "brand_name" => "Friendly Coffee")
    expect(row).not_to have_key("pin")
    expect(response.body).not_to include(secret_pin)

    patch "/api/v1/admin/products/#{product.id}", headers: admin_headers,
      params: { name: "Renamed after sale", state: "inactive" }, as: :json
    post "/api/v1/client/cards/#{card_id}/cancel", headers: client_headers
    expect(response).to have_http_status(:ok)
    get "/api/v1/client/cards/#{card_id}", headers: client_headers
    expect(response.parsed_body.fetch("data")).to include(
      "status" => "cancelled", "product_name" => "Renamed after sale"
    )
    expect(response.body).not_to include(secret_pin)
  end

  it "provides Admin actor email while preserving audit redaction and role restrictions" do
    post "/api/v1/admin/brands", headers: admin_headers, params: { name: "Another brand" }, as: :json
    get "/api/v1/admin/audit_logs", headers: admin_headers
    expect(response).to have_http_status(:ok)
    event = response.parsed_body.fetch("data").find { |row| row["action"] == "brand.created" }
    expect(event).to include(
      "actor_email" => "labels-admin@example.test",
      "record_label" => "Another brand"
    )
    expect(response.body).not_to include("password_digest", "safe-password")
    get "/api/v1/admin/audit_logs", headers: client_headers
    expect(response).to have_http_status(:forbidden)
  end
end
