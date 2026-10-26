module Api
  module V1
    module Client
      class CardsController < BaseController
        PIN_REVEAL_FAILURE_LIMIT = 5
        PIN_REVEAL_WINDOW = 15.minutes

        def index
          scope = current_user.cards.includes(product: :brand).order(id: :desc)
          scope = scope.where(status: params[:status]) if %w[issued cancelled].include?(params[:status])
          if request.query_parameters.key?("has_pin")
            case request.query_parameters["has_pin"]
            when "true"
              scope = scope.where.not(pin: nil)
            when "false"
              scope = scope.where(pin: nil)
            else
              return render json: { error: { code: "invalid_filter",
                message: "has_pin must be true or false." } }, status: :unprocessable_content
            end
          end
          page = [ params.fetch(:page, 1).to_i, 1 ].max
          per_page = params.fetch(:per_page, 25).to_i.clamp(1, 100)
          total = scope.count
          cards = scope.limit(per_page).offset((page - 1) * per_page)
          render json: { data: cards.map { |card| serialize(card) },
            meta: { page: page, per_page: per_page, total: total } }
        end

        def show
          card = current_user.cards.includes(product: :brand).find_by(id: params[:id])
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

        def serialize(card)
          card.as_json(only: %i[id client_id product_id status activation_number
            face_value_snapshot currency_snapshot payout_rate_snapshot
            payout_amount_snapshot issued_at cancelled_at]).merge(
              product_name: card.product.name,
              brand_name: card.product.brand.name,
              # Only expose existence; never expose or decrypt the stored PIN in GET responses.
              has_pin: card.read_attribute_before_type_cast(:pin).present?
            )
        end
      end
    end
  end
end
