require "rails_helper"

RSpec.describe "API exception responses", type: :request do
  around do |example|
    original = ENV["WOGI_SHOW_EXCEPTION_DETAILS"]
    example.run
  ensure
    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = original
  end

  it "returns a friendly JSON 404 with no Rails exception disclosure by default" do
    ENV.delete("WOGI_SHOW_EXCEPTION_DETAILS")
    get "/api/v1/client/catalog7", headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:not_found)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body.dig("error", "code")).to eq("route_not_found")
    expect(response.parsed_body.dig("error", "message")).to include("Check the request path")
    expect(response.parsed_body.dig("error", "details")).to be_nil
    expect(response.body).not_to include("Framework Trace", "ActionController::RoutingError", "actionpack (")
    expect(response.headers.fetch("Cache-Control")).to include("no-store")
  end

  it "returns opt-in, bounded, sanitized technical details in development/test only" do
    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = "true"
    get "/api/v1/client/catalog7", headers: { "Accept" => "application/json" }
    expect(response).to have_http_status(:not_found)
    detail = response.parsed_body.dig("error", "details")
    expect(detail).to include("exception_class" => "ActionController::RoutingError")
    expect(detail.fetch("exception_message")).to include("catalog7")
    expect(detail.fetch("backtrace")).to be_an(Array)
    expect(detail.fetch("backtrace").size).to be <= 15
    expect(response.parsed_body.dig("error", "message")).to include("Check the request path")
  end

  it "maps other failures to generic HTTP 500, masking sensitive values even with debug enabled" do
    app = Wogi::ApiExceptionsApp.new
    error = RuntimeError.new("Bearer token1234 password=veryprivate pin=345678")
    error.set_backtrace([ "service.rb:33:in `call'", "another.rb:17:in `perform'" ])
    env = Rack::MockRequest.env_for("http://example.org/api/v1/client/catalog", "HTTP_X_REQUEST_ID" => "req-001")
    env["action_dispatch.exception"] = error

    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = "false"
    status, headers, body = app.call(env)
    parsed = JSON.parse(body.join)
    expect(status).to eq(500)
    expect(headers.fetch("content-type")).to include("application/json")
    expect(parsed.dig("error", "code")).to eq("internal_error")
    expect(parsed.dig("error", "details")).to be_nil

    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = "true"
    _, _, detailed_body = app.call(env)
    json = detailed_body.join
    expect(json).to include("RuntimeError", "Bearer [FILTERED]")
    expect(json).not_to include("token1234", "veryprivate", "345678")
    expect(JSON.parse(json).dig("error", "details", "backtrace").size).to eq(2)
  end

  it "keeps diagnostics disabled in production even if the environment variable is set" do
    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = "true"
    allow(Rails.env).to receive(:production?).and_return(true)
    error = RuntimeError.new("confidential exception information")
    env = Rack::MockRequest.env_for("http://example.org/api/v1/failure")
    env["action_dispatch.exception"] = error
    _, _, body = Wogi::ApiExceptionsApp.new.call(env)
    expect(body.join).not_to include("confidential", "details")
  end

  it "distinguishes missing records from mistyped API paths" do
    ENV.delete("WOGI_SHOW_EXCEPTION_DETAILS")
    admin = User.create!(email: "api-error-admin@example.test", password: "correct-password", role: :admin)
    get "/api/v1/admin/brands/99999999",
      headers: { "Authorization" => "Bearer #{Auth::TokenEncoder.call(admin)}" }
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    expect(response.parsed_body.dig("error", "message")).to eq("Resource not found.")
    expect(response.parsed_body.dig("error", "details")).to be_nil
  end

  it "preserves normal auth errors and non-API public error handling" do
    ENV["WOGI_SHOW_EXCEPTION_DETAILS"] = "true"
    get "/api/v1/client/catalog"
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body.dig("error", "code")).to eq("unauthorized")
    expect(response.parsed_body.dig("error", "details")).to be_nil
  end
end
