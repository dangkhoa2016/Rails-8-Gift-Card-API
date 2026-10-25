require "rails_helper"

RSpec.describe "WOGI business acceptance workflow", type: :request do
  it "executes Admin setup, scoped Client issue/retry/cancel, reports and audit end to end" do
    admin = User.create!(email: "acceptance-admin@example.test",
      password: "admin-test-password", role: :admin)
    admin_headers = { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" }

    post "/api/v1/admin/brands", headers: admin_headers,
      params: { name: "WOGI Acceptance Brand", custom_fields: { region: "EU" } }, as: :json
    expect(response).to have_http_status(:created)
    brand_id = response.parsed_body.dig("data", "id")

    post "/api/v1/admin/brands/#{brand_id}/products", headers: admin_headers,
      params: { name: "Acceptance Gift", face_value: "100.00", currency: "USD" }, as: :json
    expect(response).to have_http_status(:created)
    product_id = response.parsed_body.dig("data", "id")

    post "/api/v1/admin/clients", headers: admin_headers,
      params: { email: "acceptance-client@example.test",
        password: "client-test-password", payout_rate: "87.5000" }, as: :json
    expect(response).to have_http_status(:created)
    client_id = response.parsed_body.dig("data", "id")

    post "/api/v1/admin/clients/#{client_id}/product_accesses", headers: admin_headers,
      params: { product_id: product_id }, as: :json
    expect(response).to have_http_status(:created)

    post "/api/v1/auth/login",
      params: { email: "ACCEPTANCE-CLIENT@example.test", password: "client-test-password" }, as: :json
    expect(response).to have_http_status(:ok)
    client_headers = { "Authorization" => "Bearer #{response.parsed_body.dig('data', 'access_token')}" }

    get "/api/v1/client/catalog", headers: client_headers,
      params: { q: "acceptance", brand_id: brand_id, currency: "usd" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ product_id ])

    key_header = client_headers.merge("Idempotency-Key" => "acceptance-workflow-001")
    issue_params = { product_id: product_id, with_pin: true }
    post "/api/v1/client/cards", headers: key_header, params: issue_params, as: :json
    expect(response).to have_http_status(:created)
    issued = response.parsed_body.fetch("data")
    card_id = issued.fetch("id")
    expect(issued.fetch("pin")).to match(/\A\d{6}\z/)
    expect(BigDecimal(issued.fetch("payout_amount_snapshot").to_s)).to eq(BigDecimal("87.50"))

    post "/api/v1/client/cards", headers: key_header, params: issue_params, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "id")).to eq(card_id)

    post "/api/v1/client/cards", headers: key_header,
      params: { product_id: product_id, with_pin: false }, as: :json
    expect(response).to have_http_status(:conflict)

    patch "/api/v1/admin/clients/#{client_id}", headers: admin_headers,
      params: { payout_rate: "50.0000" }, as: :json
    expect(response).to have_http_status(:ok)
    patch "/api/v1/admin/products/#{product_id}", headers: admin_headers,
      params: { face_value: "200.00", state: "inactive" }, as: :json
    expect(response).to have_http_status(:ok)

    post "/api/v1/client/cards/#{card_id}/cancel", headers: client_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "status")).to eq("cancelled")
    post "/api/v1/client/cards/#{card_id}/cancel", headers: client_headers
    expect(response).to have_http_status(:conflict)

    get "/api/v1/client/cards/#{card_id}", headers: client_headers
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(issued.fetch("pin"), "pin")

    from = Time.current.utc.to_date.iso8601
    to = (Time.current.utc.to_date + 1).iso8601
    get "/api/v1/admin/reports/by_brand", headers: admin_headers,
      params: { from: from, to: to, brand_id: brand_id }
    expect(response).to have_http_status(:ok)
    row = response.parsed_body.fetch("data").sole
    expect(row.fetch("issued_count")).to eq(1)
    expect(row.fetch("cancelled_count")).to eq(1)
    expect(BigDecimal(row.fetch("net_payout_activity").to_s)).to eq(0)

    get "/api/v1/client/reports/spending", headers: client_headers,
      params: { from: from, to: to }
    expect(response).to have_http_status(:ok)
    own_row = response.parsed_body.fetch("data").sole
    expect(BigDecimal(own_row.fetch("issued_payout").to_s)).to eq(BigDecimal("87.50"))
    expect(BigDecimal(own_row.fetch("cancelled_payout").to_s)).to eq(BigDecimal("87.50"))

    get "/api/v1/admin/audit_logs", headers: admin_headers,
      params: { record_type: "Card", per_page: 100 }
    expect(response).to have_http_status(:ok)
    actions = response.parsed_body.fetch("data").pluck("action")
    expect(actions).to include("card.issued", "card.cancelled", "card.issue_refused", "card.cancel_refused")
    expect(response.body).not_to include(issued.fetch("pin"), "password_digest")

    get "/api/v1/admin/brands", headers: client_headers
    expect(response).to have_http_status(:forbidden)
  end
end
