require "rails_helper"

RSpec.describe "Authentication and role-scoped API", type: :request do
  let!(:admin) do
    User.create!(email: "admin@example.test", password: "correct-password",
      role: :admin)
  end
  let!(:client) do
    User.create!(email: "client@example.test", password: "correct-password",
      role: :client, payout_rate: 85)
  end

  def login(email:, password: "correct-password")
    post "/api/v1/auth/login", params: { email: email, password: password }, as: :json
    response.parsed_body
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{Auth::TokenEncoder.call(user)}" }
  end

  it "logs in Admin and returns one-hour signed JWT" do
    body = login(email: admin.email)
    expect(response).to have_http_status(:ok)
    token = body.dig("data", "access_token")
    claims = Auth::TokenDecoder.call(token)
    expect(claims).to include("sub" => admin.id.to_s, "role" => "admin")
    expect(claims.fetch("exp") - claims.fetch("iat")).to eq(3600)
    expect(AuditEvent.where(action: "auth.login_succeeded", actor: admin).count).to eq(1)
  end

  it "logs in Client and does not return password digests" do
    body = login(email: client.email.upcase)
    expect(response).to have_http_status(:ok)
    expect(body.dig("data", "user", "role")).to eq("client")
    expect(response.body).not_to include("password_digest", "correct-password")
  end

  it "returns the same error for a wrong password and inactive user, with safe audits" do
    login(email: client.email, password: "bad-password")
    expect(response).to have_http_status(:unauthorized)
    client.update!(active: false)
    login(email: client.email)
    expect(response).to have_http_status(:unauthorized)
    expect(AuditEvent.where(action: "auth.login_failed").count).to eq(2)
    expect(AuditEvent.pluck(:before_data, :after_data).flatten.compact.to_s).not_to include("bad-password")
  end

  it "requires a signed, nonexpired token" do
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
    get "/api/v1/client/catalog", headers: { "Authorization" => "Bearer not-a-jwt" }
    expect(response).to have_http_status(:unauthorized)
    old_token = Auth::TokenEncoder.call(client, now: 2.hours.ago)
    get "/api/v1/client/catalog", headers: { "Authorization" => "Bearer #{old_token}" }
    expect(response).to have_http_status(:unauthorized)
    valid = Auth::TokenEncoder.call(client)
    get "/api/v1/client/catalog", headers: { "Authorization" => "Bearer #{valid}tampered" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 403 for cross-role requests" do
    get "/api/v1/admin/brands", headers: headers_for(client)
    expect(response).to have_http_status(:forbidden)
    get "/api/v1/client/catalog", headers: headers_for(admin)
    expect(response).to have_http_status(:forbidden)
  end

  it "rejects a previously issued token immediately after Client deactivation" do
    token_headers = headers_for(client)
    get "/api/v1/client/catalog", headers: token_headers
    expect(response).to have_http_status(:ok)
    client.update!(active: false)
    get "/api/v1/client/catalog", headers: token_headers
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns only products granted to this active client" do
    brand = Brand.create!(name: "Available")
    product = Product.create!(brand: brand, name: "Accessible", face_value: 100, currency: "USD")
    Product.create!(brand: brand, name: "Not assigned", face_value: 50, currency: "USD")
    ProductAccess.create!(client: client, product: product)
    get "/api/v1/client/catalog", headers: headers_for(client)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |p| p.fetch("name") }).to eq([ "Accessible" ])
    brand.update!(state: :inactive)
    get "/api/v1/client/catalog", headers: headers_for(client)
    expect(response.parsed_body.fetch("data")).to eq([])
  end

  it "records logout without falsely claiming server-side token revocation" do
    post "/api/v1/auth/logout", headers: headers_for(client)
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "server_side_token_revoked")).to eq(false)
    expect(AuditEvent.where(action: "auth.logout", actor: client).count).to eq(1)
  end
end
