require "rails_helper"

RSpec.describe "Admin management endpoints", type: :request do
  let!(:admin) { User.create!(email: "admin@example.test", password: "strong-test-password", role: :admin) }
  let(:headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" } }
  let!(:brand) { Brand.create!(name: "Existing brand") }

  it "creates, retrieves, paginates and updates brands with audit snapshots" do
    post "/api/v1/admin/brands", headers: headers,
      params: { name: "Fresh brand", custom_fields: { region: "EU" } }, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.dig("data", "id")
    patch "/api/v1/admin/brands/#{id}", headers: headers,
      params: { state: "inactive", name: "Updated brand" }, as: :json
    expect(response).to have_http_status(:ok)
    expect(Brand.find(id).state).to eq("inactive")
    get "/api/v1/admin/brands?page=2&per_page=1", headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    event = AuditEvent.find_by!(action: "brand.updated", record_id: id)
    expect(event.before_data.fetch("name")).to eq("Fresh brand")
    expect(event.after_data.fetch("name")).to eq("Updated brand")
  end

  it "rejects malformed Brand searches without raising an internal error" do
    [ { q: [ "not-a-string" ] }, { q: { nested: "value" } },
      { q: "x" * 101 } ].each do |filter|
      get "/api/v1/admin/brands", headers: headers, params: filter
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
    end

    get "/api/v1/admin/brands", headers: headers, params: { q: "existing" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ brand.id ])

    get "/api/v1/admin/brands", headers: headers, params: { q: "   " }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(1)
  end

  it "rejects more than five brand custom fields and unknown states" do
    post "/api/v1/admin/brands", headers: headers,
      params: { name: "Wrong", custom_fields: { a: 1, b: 2, c: 3, d: 4, e: 5, f: 6 } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    patch "/api/v1/admin/brands/#{brand.id}", headers: headers,
      params: { state: "maybe" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "creates and updates products; soft-deletes rather than physically deleting" do
    post "/api/v1/admin/brands/#{brand.id}/products", headers: headers,
      params: { name: "Gift", face_value: "100.00", currency: "USD" }, as: :json
    expect(response).to have_http_status(:created)
    id = response.parsed_body.dig("data", "id")
    patch "/api/v1/admin/products/#{id}", headers: headers,
      params: { face_value: "110.00" }, as: :json
    expect(response).to have_http_status(:ok)
    delete "/api/v1/admin/products/#{id}", headers: headers
    expect(response).to have_http_status(:ok)
    expect(Product.find(id)).to be_inactive
    expect(Product.find(id).deleted_at).to be_present
    expect(AuditEvent.where(record_type: "Product", record_id: id).count).to eq(3)
  end

  it "creates clients without leaking password_digest and updates payout rate" do
    post "/api/v1/admin/clients", headers: headers,
      params: { email: "client@example.test", password: "different-test-password",
        payout_rate: "90.0" }, as: :json
    expect(response).to have_http_status(:created)
    expect(response.body).not_to include("password_digest", "different-test-password")
    id = response.parsed_body.dig("data", "id")
    patch "/api/v1/admin/clients/#{id}", headers: headers, params: { payout_rate: "75.0000",
      active: false }, as: :json
    expect(response).to have_http_status(:ok)
    expect(User.find(id).payout_rate).to eq(BigDecimal("75"))
    event = AuditEvent.find_by!(action: "client.updated", record_id: id)
    expect(event.before_data.keys).not_to include("password", "password_digest")
    expect(event.after_data.keys).not_to include("password", "password_digest")
  end

  it "grants, lists and revokes client product access with audited history" do
    client = User.create!(email: "client@example.test", password: "test-password", role: :client, payout_rate: 90)
    product = Product.create!(brand: brand, name: "Gift", face_value: 100, currency: "USD")
    post "/api/v1/admin/clients/#{client.id}/product_accesses", headers: headers,
      params: { product_id: product.id }, as: :json
    expect(response).to have_http_status(:created)
    get "/api/v1/admin/clients/#{client.id}/product_accesses", headers: headers
    expect(response.parsed_body.fetch("data").size).to eq(1)
    delete "/api/v1/admin/clients/#{client.id}/product_accesses/#{product.id}", headers: headers
    expect(response).to have_http_status(:no_content)
    expect(ProductAccess.where(client: client, product: product).count).to eq(0)
    expect(AuditEvent.find_by!(action: "product_access.revoked").after_data.fetch("granted")).to eq(false)
  end

  it "does not expose admin mutation routes to client JWTs" do
    client = User.create!(email: "client@example.test", password: "test-password", role: :client, payout_rate: 90)
    post "/api/v1/admin/brands", headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}" },
      params: { name: "No permission" }, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(Brand.where(name: "No permission")).not_to exist
  end
end
