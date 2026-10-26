module Api
  module V1
    module Admin
      class AuditLogsController < BaseController
        class InvalidOutcome < StandardError; end

        rescue_from Reports::DateRange::Invalid, with: :invalid_audit_filter
        rescue_from InvalidOutcome, with: :invalid_outcome_filter

        def index
          range = Reports::DateRange.new(from: params[:from], to: params[:to])
          scope = AuditEvent.includes(:actor).order(occurred_at: :desc, id: :desc)
          scope = scope.where(actor_id: Reports::DateRange.positive_id(params[:actor_id])) if params[:actor_id].present?
          scope = scope.where(action: request.query_parameters["action"]) if request.query_parameters["action"].present?
          scope = scope.where(record_type: params[:record_type]) if params[:record_type].present?
          if request.query_parameters.key?("outcome")
            outcome = request.query_parameters["outcome"]
            unless outcome.is_a?(String) && (outcome.empty? || AuditEvent.outcomes.key?(outcome))
              raise InvalidOutcome, "Outcome must be success or refused."
            end
            scope = scope.where(outcome: outcome) if outcome.present?
          end
          scope = scope.where("occurred_at >= ?", range.from_at) if range.from_at
          scope = scope.where("occurred_at < ?", range.to_at) if range.to_at
          records, meta = paginate(scope)
          events = records.to_a
          card_ids = events.filter_map { |event| event.record_id if event.record_type == "Card" }
          cards = Card.includes(product: :brand).where(id: card_ids).index_by(&:id)
          grant_product_ids = events.filter_map do |event|
            next unless event.record_type == "ProductAccess"
            (event.after_data || event.before_data || {})["product_id"]
          end
          products = Product.includes(:brand).where(id: grant_product_ids).index_by(&:id)
          render json: { data: events.map { |event| event.as_json(only: %i[
            id actor_id action record_type record_id outcome reason_code before_data
            after_data ip_address user_agent occurred_at
          ]).merge(actor_email: event.actor&.email,
            record_label: record_label(event, cards, products)) }, meta: meta }
        end

        private

        def record_label(event, cards, products)
          attributes = event.after_data || event.before_data || {}
          case event.record_type
          when "Brand", "Product"
            attributes["name"] || event.record_type
          when "User"
            attributes["email"] || event.actor&.email || "User account"
          when "Card"
            card = cards[event.record_id]
            card ? "#{card.product.name} · #{card.product.brand.name}" : "Gift card"
          when "ProductAccess"
            product = products[attributes["product_id"]]
            product ? "#{product.name} · #{product.brand.name}" : "Product access"
          else
            event.record_type
          end
        end

        def invalid_audit_filter(error)
          render json: { error: { code: "invalid_date_range", message: error.message } },
            status: :unprocessable_content
        end

        def invalid_outcome_filter(error)
          render json: { error: { code: "invalid_filter", message: error.message } },
            status: :unprocessable_content
        end
      end
    end
  end
end
