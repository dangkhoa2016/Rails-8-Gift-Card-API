module Api
  module V1
    module Client
      class ReportsController < BaseController
        rescue_from Reports::DateRange::Invalid, with: :invalid_report_filter

        def spending
          range = Reports::DateRange.new(from: params[:from], to: params[:to])
          group_by = params[:group_by]
          unless group_by.nil? || %w[currency brand].include?(group_by)
            return render json: { error: { code: "invalid_filter",
              message: "group_by must be currency or brand." } }, status: :unprocessable_content
          end
          group = group_by == "brand" ? :brand : :personal
          data = Reports::ActivitySummary.new(group: group,
            date_range: range, client_id: current_user.id).call
          render json: { data: data,
            meta: { time_basis: "event_utc_half_open", monetary_basis: "currency_snapshot" } }
        end

        private

        def invalid_report_filter(error)
          render json: { error: { code: "invalid_date_range", message: error.message } },
            status: :unprocessable_content
        end
      end
    end
  end
end
