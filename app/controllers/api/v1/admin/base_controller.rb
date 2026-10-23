module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        before_action :require_admin!
        rescue_from ActiveRecord::RecordNotFound, with: :not_found
        rescue_from ActiveRecord::RecordInvalid, with: :validation_failed
        rescue_from ActiveRecord::RecordNotUnique, with: :conflict
        rescue_from ActionController::ParameterMissing, with: :invalid_parameters

        private

        def require_admin!
          forbidden unless current_user.admin?
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

        def paginate(relation)
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
          total = relation.count
          [ relation.limit(per_page).offset((page - 1) * per_page), { page: page, per_page: per_page, total: total } ]
        end

        def audit_change(action, record, before_data: nil, after_data: nil)
          Audit::RecordEvent.call(actor: current_user, request: request, action: action,
            record: record, before_data: before_data, after_data: after_data)
        end
      end
    end
  end
end
