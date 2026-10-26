module Api
  module V1
    module Admin
      class ReportsController < BaseController
        rescue_from Reports::DateRange::Invalid, with: :invalid_report_filter
        rescue_from Reports::CardDrilldown::Invalid, with: :invalid_drilldown

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

        def cards
          group = params[:group_by]
          unless %w[brand client].include?(group)
            return invalid_drilldown(Reports::CardDrilldown::Invalid.new("group_by must be brand or client."))
          end
          brand_id = Reports::DateRange.positive_id(params[:brand_id])
          client_id = Reports::DateRange.positive_id(params[:client_id])
          if (group == "brand" && (brand_id.nil? || client_id)) ||
              (group == "client" && (client_id.nil? || brand_id))
            return invalid_drilldown(Reports::CardDrilldown::Invalid.new("Provide only the selected group ID."))
          end
          render json: Reports::CardDrilldown.new(scope: Card.all, date_range: date_range,
            event: params[:event], currency: params[:currency],
            brand_id: brand_id, client_id: client_id).call(
              page: [ params.fetch(:page, 1).to_i, 1 ].max,
              per_page: params.fetch(:per_page, 25).to_i.clamp(1, 100))
        end

        private

        def invalid_drilldown(error)
          render json: { error: { code: "invalid_filter", message: error.message } },
            status: :unprocessable_content
        end

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
