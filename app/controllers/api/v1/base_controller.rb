module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!
      attr_reader :current_user

      private

      def authenticate_user!
        header = request.authorization.to_s
        match = header.match(/\ABearer ([A-Za-z0-9_.-]+)\z/)
        return unauthenticated unless match

        claims = Auth::TokenDecoder.call(match[1])
        @current_user = User.find_by(id: claims.fetch("sub"))
        unauthenticated unless current_user&.active? && current_user.role == claims["role"]
      rescue JWT::DecodeError, ArgumentError, KeyError
        unauthenticated
      end

      def unauthenticated
        render json: { error: { code: "unauthorized", message: "Invalid or expired authentication token." } },
          status: :unauthorized
      end

      def forbidden
        render json: { error: { code: "forbidden", message: "Insufficient permissions." } },
          status: :forbidden
      end
    end
  end
end
