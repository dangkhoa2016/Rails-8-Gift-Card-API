module Api
  module V1
    module Admin
      # Explicit, Admin-only Card operations scoped to one named Client.
      # Never impersonate that Client's JWT or disclose a generated PIN.
      class CardsController < BaseController
        def create
          client = User.client.find(params[:client_id])
          unless client.active?
            return render json: { error: { code: "client_inactive",
              message: "This Client is inactive and cannot issue new Cards." } },
              status: :unprocessable_content
          end

          result = Cards::Issue.call(client: client,
            product_id: params[:product_id], with_pin: params[:with_pin],
            idempotency_key: request.headers["Idempotency-Key"], request: request,
            actor: current_user)
          response.headers["Cache-Control"] = "no-store, private"
          render json: { data: serialize(result.card) }, status: result.created ? :created : :ok
        rescue Cards::Issue::Refused => error
          AuditEvent.create!(actor: current_user, action: "card.issue_refused",
            record_type: "Card", outcome: "refused", reason_code: error.code,
            ip_address: request.remote_ip, user_agent: request.user_agent)
          render json: { error: { code: error.code, message: error.message } },
            status: error.http_status
        end

        def cancel
          client = User.client.find(params[:client_id])
          card = Cards::Cancel.call(client: client, card_id: params[:id],
            request: request, actor: current_user)
          response.headers["Cache-Control"] = "no-store, private"
          render json: { data: serialize(card) }
        rescue Cards::Cancel::Refused => error
          render json: { error: { code: error.code, message: error.message } },
            status: error.http_status
        end

        private

        def serialize(card)
          card.as_json(only: %i[id client_id product_id status activation_number
            face_value_snapshot currency_snapshot payout_rate_snapshot
            payout_amount_snapshot issued_at cancelled_at]).merge(
              product_name: card.product.name,
              brand_name: card.product.brand.name,
              has_pin: card.read_attribute_before_type_cast(:pin).present?
            )
        end
      end
    end
  end
end
