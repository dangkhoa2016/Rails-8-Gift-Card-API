module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!
      rescue_from ActiveRecord::RecordNotFound, with: :not_found
      rescue_from ActiveRecord::RecordInvalid, with: :validation_failed
      rescue_from ActiveRecord::RecordNotUnique, with: :conflict
      rescue_from ActionController::ParameterMissing, with: :invalid_parameters
      rescue_from Api::InvalidFilter, with: :invalid_filter_error
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

      def not_found
        render json: { error: { code: "not_found", message: "Resource not found." } }, status: :not_found
      end

      def validation_failed(exception)
        render json: { error: { code: "validation_failed",
          message: "Record did not pass validation.",
          details: exception.record.errors.to_hash } }, status: :unprocessable_content
      end

      def conflict
        render json: { error: { code: "conflict", message: "The resource conflicts with existing data." } },
          status: :conflict
      end

      def invalid_parameters
        render json: { error: { code: "invalid_parameters", message: "Required parameters are missing." } },
          status: :unprocessable_content
      end

      def invalid_filter_error(exception)
        render json: { error: { code: "invalid_filter", message: exception.message } },
          status: :unprocessable_content
      end

      def paginate(relation)
        page = [ params.fetch(:page, 1).to_i, 1 ].max
        per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
        total = relation.count
        [ relation.limit(per_page).offset((page - 1) * per_page),
          { page: page, per_page: per_page, total: total } ]
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
