module Api
  module V1
    module Admin
      class AuditLogsController < BaseController
        rescue_from Reports::DateRange::Invalid, with: :invalid_audit_filter

        def index
          range = Reports::DateRange.new(from: params[:from], to: params[:to])
          scope = AuditEvent.order(occurred_at: :desc, id: :desc)
          scope = scope.where(actor_id: Reports::DateRange.positive_id(params[:actor_id])) if params[:actor_id].present?
          scope = scope.where(action: request.query_parameters["action"]) if request.query_parameters["action"].present?
          scope = scope.where(record_type: params[:record_type]) if params[:record_type].present?
          scope = scope.where("occurred_at >= ?", range.from_at) if range.from_at
          scope = scope.where("occurred_at < ?", range.to_at) if range.to_at
          records, meta = paginate(scope)
          render json: { data: records.map { |event| event.as_json(only: %i[
            id actor_id action record_type record_id outcome reason_code before_data
            after_data ip_address user_agent occurred_at
          ]) }, meta: meta }
        end

        private

        def invalid_audit_filter(error)
          render json: { error: { code: "invalid_date_range", message: error.message } },
            status: :unprocessable_content
        end
      end
    end
  end
end
