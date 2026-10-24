require "rails_helper"

RSpec.describe "SQL activity reporting and filtered audit", type: :request do
  let!(:admin) { User.create!(email: "report-admin@example.test", password: "test-password", role: :admin) }
  let!(:client_a) { User.create!(email: "report-a@example.test", password: "test-password",
    role: :client, payout_rate: 90) }
  let!(:client_b) { User.create!(email: "report-b@example.test", password: "test-password",
    role: :client, payout_rate: 75) }
  let!(:brand_a) { Brand.create!(name: "USD brand") }
  let!(:brand_b) { Brand.create!(name: "EUR brand") }
  let!(:product_a) { Product.create!(brand: brand_a, name: "USD gift", face_value: 100, currency: "USD") }
  let!(:product_b) { Product.create!(brand: brand_b, name: "EUR gift", face_value: 80, currency: "EUR") }
  let(:admin_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" } }
  let(:client_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client_a)}" } }
  let(:at_issue) { Time.utc(2026, 10, 1, 10) }
  let(:at_cancel) { Time.utc(2026, 10, 12, 9) }

  before do
    Card.create!(client: client_a, product: product_a,
      activation_number: "reportactivation001", idempotency_key: "A1",
      request_fingerprint: "r1", status: "cancelled",
      face_value_snapshot: 100, currency_snapshot: "USD", payout_rate_snapshot: 90,
      payout_amount_snapshot: 90, issued_at: at_issue, cancelled_at: at_cancel)
    Card.create!(client: client_a, product: product_a,
      activation_number: "reportactivation002", idempotency_key: "A2",
      request_fingerprint: "r2", status: "issued",
      face_value_snapshot: 50, currency_snapshot: "USD", payout_rate_snapshot: 90,
      payout_amount_snapshot: 45, issued_at: Time.utc(2026, 10, 15, 10))
    Card.create!(client: client_b, product: product_b,
      activation_number: "reportactivation003", idempotency_key: "B1",
      request_fingerprint: "r3", status: "issued",
      face_value_snapshot: 80, currency_snapshot: "EUR", payout_rate_snapshot: 75,
      payout_amount_snapshot: 60, issued_at: Time.utc(2026, 10, 16, 10))
  end

  def numeric(value)
    BigDecimal(value.to_s)
  end

  it "returns Admin brand summaries grouped by currency with cancellation deductions" do
    get "/api/v1/admin/reports/by_brand?from=2026-10-01&to=2026-11-01", headers: admin_headers
    expect(response).to have_http_status(:ok)
    rows = response.parsed_body.fetch("data")
    expect(rows.size).to eq(2)
    usd = rows.find { |row| row.fetch("currency") == "USD" }
    eur = rows.find { |row| row.fetch("currency") == "EUR" }
    expect(usd.fetch("brand_id")).to eq(brand_a.id)
    expect(usd.fetch("issued_count")).to eq(2)
    expect(usd.fetch("cancelled_count")).to eq(1)
    expect(numeric(usd.fetch("net_spending"))).to eq(BigDecimal("50"))
    expect(numeric(usd.fetch("net_payout_activity"))).to eq(BigDecimal("45"))
    expect(eur.fetch("brand_id")).to eq(brand_b.id)
    expect(numeric(eur.fetch("net_payout_activity"))).to eq(BigDecimal("60"))
  end

  it "returns Client-grouped Admin reporting using snapshots rather than current rates" do
    client_a.update!(payout_rate: 50)
    get "/api/v1/admin/reports/by_client?client_id=#{client_a.id}&from=2026-10-01&to=2026-11-01",
      headers: admin_headers
    rows = response.parsed_body.fetch("data")
    expect(rows.size).to eq(1)
    expect(rows.first.fetch("client_id")).to eq(client_a.id)
    expect(numeric(rows.first.fetch("net_payout_activity"))).to eq(BigDecimal("45"))
  end

  it "assigns issuance and cancellation to separate half-open UTC periods" do
    get "/api/v1/client/reports/spending?from=2026-10-01&to=2026-10-10",
      headers: client_headers
    first = response.parsed_body.fetch("data").first
    expect(first.fetch("issued_count")).to eq(1)
    expect(first.fetch("cancelled_count")).to eq(0)
    expect(numeric(first.fetch("net_payout_activity"))).to eq(BigDecimal("90"))

    get "/api/v1/client/reports/spending?from=2026-10-12&to=2026-10-13",
      headers: client_headers
    second = response.parsed_body.fetch("data").first
    expect(second.fetch("issued_count")).to eq(0)
    expect(second.fetch("cancelled_count")).to eq(1)
    expect(numeric(second.fetch("net_payout_activity"))).to eq(BigDecimal("-90"))
  end

  it "does not expose another Client's currency or money when filtering personal reports" do
    get "/api/v1/client/reports/spending?client_id=#{client_b.id}&from=2026-10-01&to=2026-11-01",
      headers: client_headers
    rows = response.parsed_body.fetch("data")
    expect(rows.map { |r| r.fetch("currency") }).to eq([ "USD" ])
    expect(numeric(rows.first.fetch("net_payout_activity"))).to eq(BigDecimal("45"))
  end

  it "rejects impossible dates and reversed ranges" do
    get "/api/v1/admin/reports/by_brand?from=2026-10-40", headers: admin_headers
    expect(response).to have_http_status(:unprocessable_content)
    get "/api/v1/client/reports/spending?from=2026-11-01&to=2026-10-01",
      headers: client_headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "restricts and filters audit logs by actor/action/type/date with pagination" do
    AuditEvent.create!(actor: client_a, action: "card.issued", record_type: "Card",
      outcome: "success", occurred_at: Time.utc(2026, 10, 20, 10))
    AuditEvent.create!(actor: client_b, action: "auth.login_failed", record_type: "User",
      outcome: "refused", occurred_at: Time.utc(2026, 10, 21, 10))
    get "/api/v1/admin/audit_logs?actor_id=#{client_a.id}&action=card.issued&record_type=Card" \
      "&from=2026-10-01&to=2026-11-01&page=1&per_page=1", headers: admin_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(1)
    expect(response.parsed_body.fetch("data").first.fetch("actor_id")).to eq(client_a.id)
    get "/api/v1/admin/audit_logs", headers: client_headers
    expect(response).to have_http_status(:forbidden)
  end
end
