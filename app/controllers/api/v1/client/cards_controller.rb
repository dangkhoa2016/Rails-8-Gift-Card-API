module Api
  module V1
    module Client
      class CardsController < BaseController
        PIN_REVEAL_FAILURE_LIMIT = 5
        PIN_REVEAL_WINDOW = 15.minutes
        def index
          scope = Cards::ListQuery.new(client: current_user, filters: request.query_parameters).call
          records, meta = paginate(scope)
          render json: { data: records.map { |card| Cards::Serializer.call(card) }, meta: meta }
        end

        def show
          card = current_user.cards.includes(product: :brand).find_by(id: params[:id])
          return not_found unless card
          render json: { data: Cards::Serializer.call(card) }
        end

        def create
          # Issuance and idempotent replay may return a secret PIN.
          # Never permit an intermediary or browser to store this response.
          response.headers["Cache-Control"] = "no-store, private"
          response.headers["Pragma"] = "no-cache"
          result = Cards::Issue.call(client: current_user,
            product_id: params[:product_id], with_pin: params[:with_pin],
            idempotency_key: request.headers["Idempotency-Key"], request: request)
          data = Cards::Serializer.call(result.card).merge(pin: result.card.pin)
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
          render json: { data: Cards::Serializer.call(card) }
        rescue Cards::Cancel::Refused => error
          render json: { error: { code: error.code, message: error.message } },
            status: error.http_status
        end

        # PINs never appear in index/show. Reveal requires ownership, a fresh password,
        # audited access and a bounded number of failed re-authentication attempts.
        def reveal_pin
          response.headers["Cache-Control"] = "no-store, private"
          response.headers["Pragma"] = "no-cache"
          card = current_user.cards.find_by(id: params[:id])
          unless card
            return render json: { error: { code: "not_found", message: "Card not found." } },
              status: :not_found
          end

          unless card.read_attribute_before_type_cast(:pin).present?
            record_pin_reveal(card, "refused", "pin_unavailable")
            return render json: { error: { code: "pin_unavailable", message: "This Card has no PIN." } },
              status: :unprocessable_content
          end

          failures = AuditEvent.where(actor: current_user, action: "card.pin_reveal_refused",
            reason_code: "invalid_password").where("occurred_at >= ?", PIN_REVEAL_WINDOW.ago).count
          if failures >= PIN_REVEAL_FAILURE_LIMIT
            record_pin_reveal(card, "refused", "rate_limited")
            return render json: { error: { code: "rate_limited",
              message: "Too many incorrect password attempts. Try again later." } },
              status: :too_many_requests
          end

          password = params[:password]
          unless password.is_a?(String) && password.bytesize.between?(1, 128) && current_user.authenticate(password)
            record_pin_reveal(card, "refused", "invalid_password")
            return render json: { error: { code: "invalid_confirmation",
              message: "Password confirmation failed." } }, status: :forbidden
          end

          record_pin_reveal(card, "success")
          render json: { data: { id: card.id, pin: card.pin } }
        end

        private

        def record_pin_reveal(card, outcome, reason_code = nil)
          AuditEvent.create!(actor: current_user, action: "card.pin_reveal_#{outcome}",
            record_type: "Card", record_id: card.id, outcome: outcome,
            reason_code: reason_code, ip_address: request.remote_ip,
            user_agent: request.user_agent)
        end

        def not_found
          render json: { error: { code: "not_found", message: "Card not found." } },
            status: :not_found
        end
      end
    end
  end
end
