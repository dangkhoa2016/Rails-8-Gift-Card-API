module Reports
  # Read-only details behind the event-time financial summary. Always filter
  # before pagination; cancellation uses cancelled_at (never current status).
  class CardDrilldown
    class Invalid < StandardError; end

    def initialize(scope:, date_range:, event:, currency:, brand_id: nil, client_id: nil)
      raise Invalid, "event must be issued or cancelled." unless %w[issued cancelled].include?(event)
      raise Invalid, "currency must be a three-letter ISO code." unless
        currency.is_a?(String) && currency.match?(/\A[A-Z]{3}\z/)

      @scope = scope
      @range = date_range
      @event = event
      @currency = currency
      @brand_id = brand_id
      @client_id = client_id
    end

    def call(page:, per_page:)
      timestamp = @event == "issued" ? :issued_at : :cancelled_at
      cards = @scope.where(currency_snapshot: @currency)
      cards = cards.where(product_id: Product.where(brand_id: @brand_id)) if @brand_id
      cards = cards.where(client_id: @client_id) if @client_id
      cards = cards.where.not(cancelled_at: nil) if @event == "cancelled"
      cards = cards.where("#{timestamp} >= ?", @range.from_at) if @range.from_at
      cards = cards.where("#{timestamp} < ?", @range.to_at) if @range.to_at
      total = cards.count
      records = cards.includes(:client, product: :brand).order(timestamp => :desc, id: :desc)
        .limit(per_page).offset((page - 1) * per_page)

      { data: records.map { |card| serialize(card, timestamp) },
        meta: { page: page, per_page: per_page, total: total, event: @event,
          currency: @currency, time_basis: "event_utc_half_open" } }
    end

    private

    def serialize(card, timestamp)
      {
        id: card.id, activation_number: card.activation_number,
        product_name: card.product.name, brand_name: card.product.brand.name,
        client_id: card.client_id, client_email: card.client.email,
        currency: card.currency_snapshot, status: card.status,
        face_value: card.face_value_snapshot.to_s("F"),
        payout: card.payout_amount_snapshot.to_s("F"),
        occurred_at: card.public_send(timestamp).iso8601(6)
      }
      # Neither GET route includes PIN, encryption ciphertext or idempotency keys.
    end
  end
end
