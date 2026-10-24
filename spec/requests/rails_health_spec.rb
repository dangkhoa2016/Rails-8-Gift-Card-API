require "rails_helper"

RSpec.describe "Rails health check", type: :request do
  it "returns a successful response from the API application" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end
end
