require "digest"

module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: :login

      # Solid Cache is shared in production. A dedicated in-memory store keeps
      # request specs realistic despite the test environment's null cache.
      LOGIN_RATE_LIMIT_STORE = Rails.env.production? ? Rails.cache : ActiveSupport::Cache::MemoryStore.new

      rate_limit to: 60, within: 1.minute, name: "network", only: :login,
        store: LOGIN_RATE_LIMIT_STORE, by: -> { request.remote_ip },
        with: :network_rate_limited
      rate_limit to: 5, within: 15.minutes, name: "credentials", only: :login,
        store: LOGIN_RATE_LIMIT_STORE,
        by: -> { "#{request.remote_ip}:#{Digest::SHA256.hexdigest(params[:email].to_s.strip.downcase)}" },
        with: :credentials_rate_limited

      def login
        response.headers["Cache-Control"] = "no-store, private"
        email = params[:email].to_s.strip.downcase
        user = User.find_by(email: email)
        unless user&.active? && user.authenticate(params[:password].to_s)
          record_auth_event("auth.login_failed", user, "refused", "invalid_credentials")
          return render json: { error: { code: "invalid_credentials",
            message: "Invalid credentials or inactive account." } }, status: :unauthorized
        end

        access_token = Auth::TokenEncoder.call(user)
        record_auth_event("auth.login_succeeded", user, "success")
        render json: { data: { access_token: access_token, token_type: "Bearer",
          expires_in: Auth::TokenEncoder::TTL_SECONDS, user: { id: user.id, role: user.role } } }
      end

      def logout
        record_auth_event("auth.logout", current_user, "success")
        render json: { data: { logged_out: true, server_side_token_revoked: false,
          message: "Discard the token on the client. This token remains valid until expiration." } }
      end

      private

      def network_rate_limited
        rate_limit_response(60)
      end

      def credentials_rate_limited
        rate_limit_response(900)
      end

      def rate_limit_response(retry_after)
        response.headers["Retry-After"] = retry_after.to_s
        render json: { error: { code: "rate_limited",
          message: "Too many login attempts. Please try again later." } }, status: :too_many_requests
      end

      def record_auth_event(action, user, outcome, reason = nil)
        AuditEvent.create!(actor: user, action: action, record_type: "User",
          record_id: user&.id, outcome: outcome, reason_code: reason,
          ip_address: request.remote_ip, user_agent: request.user_agent)
      end
    end
  end
end
