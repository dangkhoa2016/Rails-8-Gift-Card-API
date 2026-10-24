module Api
  module V1
    module Client
      class CardsController < BaseController
        def index
          scope = current_user.cards.order(id: :desc)
          scope = scope.where(status: params[:status]) if %w[issued cancelled].include?(params[:status])
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
          total = scope.count
          cards = scope.limit(per_page).offset((page - 1) * per_page)
          render json: { data: cards.map { |card| serialize(card) },
            meta: { page: page, per_page: per_page, total: total } }
        end

        def show
          card = current_user.cards.find_by(id: params[:id])
          return not_found unless card
          render json: { data: serialize(card) }
        end

        def create
          result = Cards::Issue.call(client: current_user,
            product_id: params[:product_id], with_pin: params[:with_pin],
            idempotency_key: request.headers["Idempotency-Key"], request: request)
          data = serialize(result.card).merge(pin: result.card.pin)
          render json: { data: data }, status: result.created ? :created : :ok
        rescue Cards::Issue::Refused => error
          AuditEvent.create!(actor: current_user, action: "card.issue_refused",
            record_type: "Card", outcome: "refused", reason_code: error.code,
            ip_address: request.remote_ip, user_agent: request.user_agent)
          render json: { error: { code: error.code, message: error.message } },
            status: error.http_status
        end

        def cancel
          card = Cards::Cancel.call(client: current_user, card_id: params[:id], request: request)
          render json: { data: serialize(card) }
        rescue Cards::Cancel::Refused => error
          render json: { error: { code: error.code, message: error.message } },
            status: error.http_status
        end

        private

        def not_found
          render json: { error: { code: "not_found", message: "Card not found." } },
            status: :not_found
        end

        def serialize(card)
          card.as_json(only: %i[id client_id product_id status activation_number
            face_value_snapshot currency_snapshot payout_rate_snapshot
            payout_amount_snapshot issued_at cancelled_at])
        end
      end
    end
  end
end
