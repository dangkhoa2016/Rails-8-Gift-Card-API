module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: :login

      def login
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

      def record_auth_event(action, user, outcome, reason = nil)
        AuditEvent.create!(actor: user, action: action, record_type: "User",
          record_id: user&.id, outcome: outcome, reason_code: reason,
          ip_address: request.remote_ip, user_agent: request.user_agent)
      end
    end
  end
end
