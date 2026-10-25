require "rails_helper"

RSpec.describe "Client catalog search and filtering", type: :request do
  let!(:client) do
    User.create!(email: "catalog-client@example.test", password: "test-password",
      role: :client, payout_rate: 90)
  end
  let!(:other_client) do
    User.create!(email: "other-catalog-client@example.test", password: "test-password",
      role: :client, payout_rate: 80)
  end
  let!(:coffee_brand) { Brand.create!(name: "Coffee House") }
  let!(:shop_brand) { Brand.create!(name: "Market Store") }
  let!(:coffee_usd) do
    Product.create!(brand: coffee_brand, name: "Morning Latte", face_value: 25, currency: "USD")
  end
  let!(:coffee_eur) do
    Product.create!(brand: coffee_brand, name: "Evening Latte", face_value: 20, currency: "EUR")
  end
  let!(:shop_usd) do
    Product.create!(brand: shop_brand, name: "M% Special", face_value: 50, currency: "USD")
  end
  let!(:not_assigned) do
    Product.create!(brand: coffee_brand, name: "Secret Latte", face_value: 100, currency: "USD")
  end

  def headers_for(user)
    { "Authorization" => "Bearer #{Auth::TokenEncoder.call(user)}" }
  end

  before do
    [ coffee_usd, coffee_eur, shop_usd ].each do |product|
      ProductAccess.create!(client: client, product: product)
    end
    ProductAccess.create!(client: other_client, product: not_assigned)
  end

  it "searches assigned products by product or brand name, case-insensitively" do
    get "/api/v1/client/catalog", headers: headers_for(client), params: { q: "mOrNiNg" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ coffee_usd.id ])

    get "/api/v1/client/catalog", headers: headers_for(client), params: { q: "coffee house" }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ coffee_usd.id, coffee_eur.id ])
  end

  it "supports combined brand and currency filters without leaking ungranted products" do
    get "/api/v1/client/catalog", headers: headers_for(client),
      params: { brand_id: coffee_brand.id, currency: "usd", q: "latte" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ coffee_usd.id ])

    get "/api/v1/client/catalog", headers: headers_for(other_client),
      params: { q: "latte", brand_id: coffee_brand.id }
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ not_assigned.id ])
  end

  it "treats SQL LIKE wildcard characters in the search term literally" do
    get "/api/v1/client/catalog", headers: headers_for(client), params: { q: "%" }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").pluck("id")).to eq([ shop_usd.id ])
  end

  it "rejects invalid filter values with a structured JSON error" do
    get "/api/v1/client/catalog", headers: headers_for(client), params: { brand_id: "-12" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_catalog_filter")

    get "/api/v1/client/catalog", headers: headers_for(client), params: { currency: "USDD" }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig("error", "code")).to eq("invalid_catalog_filter")
  end
end
