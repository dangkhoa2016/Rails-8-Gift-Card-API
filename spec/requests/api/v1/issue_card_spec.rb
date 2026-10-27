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

  it "prevents caching of responses containing PINs on creation and exact replay" do
    2.times do |attempt|
      post "/api/v1/client/cards", headers: headers,
        params: { product_id: product.id, with_pin: true }, as: :json
      expect(response).to have_http_status(attempt.zero? ? :created : :ok)
      expect(response.headers.fetch("Cache-Control")).to include("no-store", "private")
      expect(response.headers.fetch("Pragma")).to eq("no-cache")
      expect(response.parsed_body.dig("data", "pin")).to match(/\A[0-9]{6}\z/)
    end

    post "/api/v1/client/cards", headers: headers,
      params: { product_id: product.id, with_pin: false }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
    expect(Card.count).to eq(1)
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

  it "searches owned cards by activation, Product and Brand before pagination" do
    cafe = Brand.create!(name: "Coffee_100% Club")
    latte = Product.create!(brand: cafe, name: "Morning Latte", face_value: 25, currency: "USD")
    ProductAccess.create!(client: client, product: latte)

    issue = lambda do |key, issued_product, with_pin|
      post "/api/v1/client/cards", headers: headers.merge("Idempotency-Key" => key),
        params: { product_id: issued_product.id, with_pin: with_pin }, as: :json
      expect(response).to have_http_status(:created)
      response.parsed_body.fetch("data")
    end
    first = issue.call("card-search-1", product, false)
    second = issue.call("card-search-2", product, false)
    latte_card = issue.call("card-search-3", latte, true)
    post "/api/v1/client/cards/#{latte_card.fetch('id')}/cancel", headers: headers
    expect(response).to have_http_status(:ok)

    other = User.create!(email: "private-card@example.test", password: "private-password",
      role: :client, payout_rate: 75)
    ProductAccess.create!(client: other, product: latte)
    post "/api/v1/client/cards", headers: {
      "Authorization" => "Bearer #{Auth::TokenEncoder.call(other)}",
      "Idempotency-Key" => "other-private-card"
    }, params: { product_id: latte.id, with_pin: false }, as: :json
    expect(response).to have_http_status(:created)
    private_card = response.parsed_body.fetch("data")

    get "/api/v1/client/cards", headers: headers,
      params: { q: first.fetch("activation_number")[3, 9] }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ first.fetch("id") ])

    get "/api/v1/client/cards", headers: headers, params: { q: "lAtTe" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ latte_card.fetch("id") ])
    expect(response.body).not_to include(private_card.fetch("activation_number"))

    get "/api/v1/client/cards", headers: headers, params: { q: "coffee_100%" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ latte_card.fetch("id") ])

    # SQL LIKE wildcard characters must be literal, not match-all operators.
    get "/api/v1/client/cards", headers: headers, params: { q: "_" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ latte_card.fetch("id") ])
    get "/api/v1/client/cards", headers: headers, params: { q: "%" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ latte_card.fetch("id") ])

    get "/api/v1/client/cards", headers: headers,
      params: { q: "GIFt", per_page: 1, page: 1 }
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ second.fetch("id") ])
    get "/api/v1/client/cards", headers: headers,
      params: { q: "GIFT", per_page: 1, page: 2 }
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ first.fetch("id") ])

    get "/api/v1/client/cards", headers: headers,
      params: { q: "coffee", status: "cancelled", has_pin: "true" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ latte_card.fetch("id") ])
    expect(response.body).not_to include('"pin"', latte_card.fetch("pin"))
    get "/api/v1/client/cards", headers: headers,
      params: { q: "coffee", status: "issued" }
    expect(response.parsed_body.dig("meta", "total")).to eq(0)
  end

  it "sorts owned Cards globally before pagination using only approved columns" do
    first_brand = Brand.create!(name: "Alpha Brand")
    second_brand = Brand.create!(name: "Zeta Brand")
    apple = Product.create!(brand: first_brand, name: "apple", face_value: 25, currency: "USD")
    another_apple = Product.create!(brand: second_brand, name: "Apple",
      face_value: 40, currency: "EUR")
    [ apple, another_apple ].each { |entry| ProductAccess.create!(client: client, product: entry) }

    issue = lambda do |key, item, with_pin, activation|
      post "/api/v1/client/cards", headers: headers.merge("Idempotency-Key" => key),
        params: { product_id: item.id, with_pin: with_pin }, as: :json
      expect(response).to have_http_status(:created)
      Card.find(response.parsed_body.dig("data", "id")).tap do |card|
        card.update!(activation_number: activation)
      end
    end

    gift_pin = issue.call("sort-gift-pin", product, true, "7100000000000001")
    alpha = issue.call("sort-alpha", apple, false, "7100000000000003")
    zeta = issue.call("sort-zeta", another_apple, true, "7100000000000002")
    client.update!(payout_rate: 80)
    gift_plain = issue.call("sort-gift-plain", product, false, "7100000000000004")
    post "/api/v1/client/cards/#{zeta.id}/cancel", headers: headers
    expect(response).to have_http_status(:ok)

    cases = {
      "activation_number" => [ gift_pin, zeta, alpha, gift_plain ],
      "product" => [ alpha, zeta, gift_plain, gift_pin ],
      "face_value" => [ alpha, zeta, gift_plain, gift_pin ],
      "payout" => [ alpha, zeta, gift_plain, gift_pin ],
      "status" => [ zeta, gift_plain, alpha, gift_pin ],
      "has_pin" => [ gift_plain, alpha, zeta, gift_pin ]
    }
    # Tie-breakers stay ID DESC in both directions, rather than reversing ties.
    descending = {
      "activation_number" => [ gift_plain, alpha, zeta, gift_pin ],
      "product" => [ gift_plain, gift_pin, zeta, alpha ],
      "face_value" => [ gift_plain, gift_pin, zeta, alpha ],
      "payout" => [ gift_pin, gift_plain, zeta, alpha ],
      "status" => [ gift_plain, alpha, gift_pin, zeta ],
      "has_pin" => [ zeta, gift_pin, gift_plain, alpha ]
    }
    cases.each do |sort_by, expected|
      get "/api/v1/client/cards", headers: headers, params: { sort_by: sort_by, sort_dir: "asc" }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("meta", "total")).to eq(4)
      expect(response.parsed_body.fetch("data").pluck("id")).to eq(expected.pluck(:id)), sort_by
      expect(response.body).not_to include('"pin"')

      get "/api/v1/client/cards", headers: headers,
        params: { sort_by: sort_by, sort_dir: "desc", per_page: 2, page: 1 }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").pluck("id")).to eq(descending.fetch(sort_by).first(2).pluck(:id)),
        "#{sort_by} descending page 1"
    end

    get "/api/v1/client/cards", headers: headers
    expect(response.parsed_body.fetch("data").pluck("id")).to eq(
      [ gift_plain.id, zeta.id, alpha.id, gift_pin.id ]) # Backward-compatible default

    get "/api/v1/client/cards", headers: headers,
      params: { q: "aPpLe", sort_by: "product", sort_dir: "asc", per_page: 1, page: 1 }
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ alpha.id ])
    get "/api/v1/client/cards", headers: headers,
      params: { q: "aPpLe", sort_by: "product", sort_dir: "asc", per_page: 1, page: 2 }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ zeta.id ])

    get "/api/v1/client/cards", headers: headers,
      params: { status: "cancelled", has_pin: "true", sort_by: "activation_number", sort_dir: "asc" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ zeta.id ])

    other = User.create!(email: "other-sort@example.test", password: "other-sort-password",
      role: :client, payout_rate: 88)
    ProductAccess.create!(client: other, product: apple)
    post "/api/v1/client/cards",
      headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(other)}",
        "Idempotency-Key" => "other-sort-card" },
      params: { product_id: apple.id, with_pin: false }, as: :json
    expect(response).to have_http_status(:created)
    other_id = response.parsed_body.dig("data", "id")
    get "/api/v1/client/cards", headers: headers,
      params: { sort_by: "product", sort_dir: "asc" }
    expect(response.parsed_body.fetch("data").pluck("id")).not_to include(other_id)
    expect(response.parsed_body.dig("meta", "total")).to eq(4)
  end

  it "rejects unsupported Card sort keys and directions without interpolating SQL" do
    [
      { sort_by: "created_at;DROP TABLE cards", sort_dir: "asc" },
      { sort_by: "activation_number", sort_dir: "sideways" },
      { sort_by: "product", sort_dir: "DESC;DROP TABLE cards" },
      { sort_by: "pin", sort_dir: "asc" },
      { sort_dir: "desc" }
    ].each do |params|
      get "/api/v1/client/cards", headers: headers, params: params
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
    end
    get "/api/v1/client/cards?sort_by[]=status", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    get "/api/v1/client/cards?sort_by=status&sort_dir[]=asc", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects malformed or excessively long Card search parameters" do
    get "/api/v1/client/cards?q[]=Gift", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
    get "/api/v1/client/cards", headers: headers, params: { q: "x" * 101 }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
  end

  it "filters current client's cards by PIN presence before pagination without disclosing the PIN" do
    issue = lambda do |key, with_pin|
      post "/api/v1/client/cards", headers: headers.merge("Idempotency-Key" => key),
        params: { product_id: product.id, with_pin: with_pin }, as: :json
      expect(response).to have_http_status(:created)
      response.parsed_body.fetch("data")
    end
    with_pin = issue.call("pin-filter-with-1", true)
    without_pin = issue.call("pin-filter-without", false)
    cancelled_pin = issue.call("pin-filter-with-2", true)
    post "/api/v1/client/cards/#{cancelled_pin.fetch('id')}/cancel", headers: headers
    expect(response).to have_http_status(:ok)

    get "/api/v1/client/cards", headers: headers, params: { has_pin: "true", per_page: 1 }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(2)
    expect(response.parsed_body.fetch("data").length).to eq(1)
    expect(response.parsed_body.fetch("data").first.fetch("has_pin")).to be(true)

    get "/api/v1/client/cards", headers: headers,
      params: { has_pin: "true", status: "issued", per_page: 100 }
    expect(response.parsed_body.dig("meta", "total")).to eq(1)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ with_pin.fetch("id") ])

    get "/api/v1/client/cards", headers: headers,
      params: { has_pin: "true", status: "cancelled", per_page: 100 }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ cancelled_pin.fetch("id") ])

    get "/api/v1/client/cards", headers: headers, params: { has_pin: "false", per_page: 100 }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("meta", "total")).to eq(1)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ without_pin.fetch("id") ])
    expect(response.parsed_body.fetch("data").first.fetch("has_pin")).to be(false)

    get "/api/v1/client/cards", headers: headers, params: { per_page: 100 }
    expect(response.parsed_body.dig("meta", "total")).to eq(3)
    expect(response.parsed_body.fetch("data").pluck("has_pin")).to match_array([ true, true, false ])
    expect(response.body).not_to include('"pin"', with_pin.fetch("pin"))

    get "/api/v1/client/cards/#{with_pin.fetch('id')}", headers: headers
    expect(response.parsed_body.fetch("data")).to include("has_pin" => true)
    expect(response.body).not_to include('"pin"', with_pin.fetch("pin"))
    get "/api/v1/client/cards/#{without_pin.fetch('id')}", headers: headers
    expect(response.parsed_body.fetch("data")).to include("has_pin" => false)

    [ "yes", "1", "TRUE" ].each do |invalid|
      get "/api/v1/client/cards", headers: headers, params: { has_pin: invalid }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_filter")
    end
    get "/api/v1/client/cards?has_pin[]=true", headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end
end
