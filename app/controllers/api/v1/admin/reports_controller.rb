module Api
  module V1
    module Admin
      class ReportsController < BaseController
        rescue_from Reports::DateRange::Invalid, with: :invalid_report_filter

        def by_brand
          render json: { data: Reports::ActivitySummary.new(group: :brand,
            date_range: date_range, brand_id: Reports::DateRange.positive_id(params[:brand_id])).call,
            meta: { time_basis: "event_utc_half_open", monetary_basis: "currency_snapshot" } }
        end

        def by_client
          render json: { data: Reports::ActivitySummary.new(group: :client,
            date_range: date_range, client_id: Reports::DateRange.positive_id(params[:client_id])).call,
            meta: { time_basis: "event_utc_half_open", monetary_basis: "currency_snapshot" } }
        end

        private

        def date_range
          Reports::DateRange.new(from: params[:from], to: params[:to])
        end

        def invalid_report_filter(error)
          render json: { error: { code: "invalid_date_range", message: error.message } },
            status: :unprocessable_content
        end
      end
    end
  end
end
