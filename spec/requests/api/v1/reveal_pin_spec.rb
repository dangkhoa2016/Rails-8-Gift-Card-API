require "rails_helper"

RSpec.describe "Client PIN reveal with step-up authentication", type: :request do
  let!(:client) do
    User.create!(email: "reveal-client@example.test", password: "correct-password",
      role: :client, payout_rate: 90)
  end
  let!(:other_client) do
    User.create!(email: "reveal-other@example.test", password: "other-password",
      role: :client, payout_rate: 85)
  end
  let!(:admin) { User.create!(email: "reveal-admin@example.test", password: "admin-password", role: :admin) }
  let!(:product) do
    Product.create!(brand: Brand.create!(name: "Secure card brand"),
      name: "Secure card product", face_value: 100, currency: "USD")
  end
  let(:headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(client)}" } }
  let(:other_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other_client)}" } }
  let(:admin_headers) { { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" } }

  before { ProductAccess.create!(client: client, product: product) }

  def issue(key:, with_pin:)
    post "/api/v1/client/cards", headers: headers.merge("Idempotency-Key" => key),
      params: { product_id: product.id, with_pin: with_pin }, as: :json
    expect(response).to have_http_status(:created)
    response.parsed_body.fetch("data")
  end

  def reveal(id:, password:, auth_headers: headers)
    post "/api/v1/client/cards/#{id}/reveal_pin", headers: auth_headers,
      params: { password: password }, as: :json
  end

  it "requires the correct current password and returns a no-store PIN only for its owner" do
    issued = issue(key: "revealed-pin-1", with_pin: true)
    reveal(id: issued.fetch("id"), password: "incorrect-password")
    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_confirmation")
    expect(response.body).not_to include(issued.fetch("pin"))

    reveal(id: issued.fetch("id"), password: "correct-password")
    expect(response).to have_http_status(:ok)
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(response.headers.fetch("Pragma")).to eq("no-cache")
    expect(response.parsed_body.fetch("data")).to eq(
      "id" => issued.fetch("id"), "pin" => issued.fetch("pin")
    )
    events = AuditEvent.where(actor: client, record_type: "Card", record_id: issued.fetch("id"),
      action: [ "card.pin_reveal_refused", "card.pin_reveal_success" ]).order(:id)
    expect(events.pluck(:outcome, :reason_code)).to eq([
      [ "refused", "invalid_password" ], [ "success", nil ]
    ])
    expect(events.pluck(:before_data, :after_data)).to all(eq([ nil, nil ]))
    expect(events.pluck(:before_data, :after_data).to_s).not_to include(
      issued.fetch("pin"), "correct-password", "incorrect-password"
    )
    get "/api/v1/client/cards/#{issued.fetch('id')}", headers: headers
    expect(response.parsed_body.fetch("data")).to include("has_pin" => true)
    expect(response.parsed_body.fetch("data")).not_to have_key("pin")
  end

  it "denies cross-client, admin and missing-token access" do
    issued = issue(key: "reveal-other-scope", with_pin: true)
    reveal(id: issued.fetch("id"), password: "other-password", auth_headers: other_headers)
    expect(response).to have_http_status(:not_found)
    reveal(id: issued.fetch("id"), password: "admin-password", auth_headers: admin_headers)
    expect(response).to have_http_status(:forbidden)
    reveal(id: issued.fetch("id"), password: "correct-password", auth_headers: {})
    expect(response).to have_http_status(:unauthorized)
    expect(AuditEvent.where(action: "card.pin_reveal_success").count).to eq(0)
  end

  it "does not reveal PINs of cards that have none and supports cancelled owned cards" do
    without = issue(key: "reveal-no-pin", with_pin: false)
    reveal(id: without.fetch("id"), password: "correct-password")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("pin_unavailable")

    with_pin = issue(key: "reveal-cancelled", with_pin: true)
    post "/api/v1/client/cards/#{with_pin.fetch('id')}/cancel", headers: headers
    expect(response).to have_http_status(:ok)
    reveal(id: with_pin.fetch("id"), password: "correct-password")
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "pin")).to eq(with_pin.fetch("pin"))
  end

  it "blocks the sixth failed confirmation in 15 minutes, including a correct password" do
    issued = issue(key: "reveal-rate-limit", with_pin: true)
    5.times do
      reveal(id: issued.fetch("id"), password: "wrong-password")
      expect(response).to have_http_status(:forbidden)
    end
    reveal(id: issued.fetch("id"), password: "correct-password")
    expect(response).to have_http_status(:too_many_requests)
    expect(response.parsed_body.dig("error", "code")).to eq("rate_limited")
    expect(response.body).not_to include(issued.fetch("pin"))
    expect(AuditEvent.where(action: "card.pin_reveal_refused", actor: client).count).to eq(6)
  end
end
