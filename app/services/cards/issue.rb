require "digest"
require "securerandom"

module Cards
  class Issue
    Result = Struct.new(:card, :created, keyword_init: true)

    class Refused < StandardError
      attr_reader :code, :http_status

      def initialize(code, http_status: :unprocessable_content)
        @code = code
        @http_status = http_status
        super(code.tr("_", " "))
      end
    end

    MAX_ACTIVATION_COLLISIONS = 3

    def self.call(client:, product_id:, with_pin:, idempotency_key:, request:, actor: client)
      new(client:, product_id:, with_pin:, idempotency_key:, request:, actor:).call
    end

    def initialize(client:, product_id:, with_pin:, idempotency_key:, request:, actor: client)
      @actor = actor
      @client = client
      @product_id = product_id
      @with_pin = with_pin
      @idempotency_key = idempotency_key
      @request = request
    end

    def call
      validate_and_normalize!
      collision_attempts = 0
      begin
        Card.transaction do
          # Serializes requests with the same client/key on THIS PostgreSQL database.
          # Unique DB constraints still independently enforce correctness.
          Card.connection.execute("SELECT pg_advisory_xact_lock(#{advisory_lock_id})")
          previous = Card.find_by(client_id: @client.id, idempotency_key: @idempotency_key)
          if previous
            raise Refused.new("idempotency_key_reused", http_status: :conflict) unless
              previous.request_fingerprint == @fingerprint
            return Result.new(card: previous, created: false)
          end

          product = eligible_products.find_by(id: @product_id)
          raise Refused.new("product_unavailable") unless product

          rate = BigDecimal(@client.payout_rate.to_s)
          face = BigDecimal(product.face_value.to_s)
          payout = (face * rate / 100).round(2, BigDecimal::ROUND_HALF_UP)
          card = Card.create!(
            client: @client, product: product,
            activation_number: generate_activation_number,
            pin: @with_pin ? generate_pin : nil,
            status: "issued",
            idempotency_key: @idempotency_key,
            request_fingerprint: @fingerprint,
            face_value_snapshot: face,
            currency_snapshot: product.currency,
            payout_rate_snapshot: rate,
            payout_amount_snapshot: payout,
            issued_at: Time.current
          )
          Audit::RecordEvent.call(actor: @actor, request: @request,
            action: "card.issued", record: card, after_data: card)
          Result.new(card: card, created: true)
        end
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => error
        # Retry only a true generated activation-number collision.
        collision = if error.is_a?(ActiveRecord::RecordInvalid)
          error.record.is_a?(Card) && error.record.errors.attribute_names.include?(:activation_number)
        else
          error.message.include?("index_cards_on_activation_number")
        end
        raise unless collision
        collision_attempts += 1
        raise if collision_attempts >= MAX_ACTIVATION_COLLISIONS
        retry
      end
    end

    private

    def validate_and_normalize!
      raise Refused.new("idempotency_key_required") unless
        @idempotency_key.is_a?(String) &&
        @idempotency_key.match?(/\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\z/)

      begin
        @product_id = Integer(@product_id, 10) if @product_id.is_a?(String)
        raise ArgumentError unless @product_id.is_a?(Integer) && @product_id.positive?
      rescue ArgumentError, TypeError
        raise Refused.new("invalid_product_id")
      end

      @with_pin = false if @with_pin.nil?
      raise Refused.new("invalid_with_pin") unless @with_pin == true || @with_pin == false

      @fingerprint = Digest::SHA256.hexdigest(
        JSON.generate({ product_id: @product_id, with_pin: @with_pin })
      )
    end

    def eligible_products
      Product.joins(:brand, :product_accesses)
        .where(product_accesses: { client_id: @client.id },
          state: "active", deleted_at: nil, brands: { state: "active" })
    end

    def advisory_lock_id
      Digest::SHA256.digest("#{@client.id}:#{@idempotency_key}").unpack1("q>")
    end

    def generate_activation_number
      SecureRandom.random_number(10**16).to_s.rjust(16, "0")
    end

    def generate_pin
      SecureRandom.random_number(10**6).to_s.rjust(6, "0")
    end
  end
end
