module Cards
  class Cancel
    class Refused < StandardError
      attr_reader :code, :http_status

      def initialize(code, http_status: :conflict)
        @code = code
        @http_status = http_status
        super(code.tr("_", " "))
      end
    end

    def self.call(client:, card_id:, request:, actor: client)
      new(client:, card_id:, request:, actor:).call
    end

    def initialize(client:, card_id:, request:, actor: client)
      @actor = actor
      @client = client
      @card_id = card_id
      @request = request
    end

    def call
      card = @client.cards.find_by(id: @card_id)
      raise Refused.new("card_not_found", http_status: :not_found) unless card

      card.with_lock do
        raise Refused.new("already_cancelled") unless card.issued?
        before = card.attributes
        card.update!(status: "cancelled", cancelled_at: Time.current)
        Audit::RecordEvent.call(actor: @actor, request: @request, action: "card.cancelled",
          record: card, before_data: before, after_data: card)
      end
      card
    rescue Refused => error
      # A declined cancellation must be committed after the success transaction rolls back.
      AuditEvent.create!(actor: @actor, action: "card.cancel_refused", record_type: "Card",
        record_id: card&.id, outcome: "refused", reason_code: error.code,
        ip_address: @request.remote_ip, user_agent: @request.user_agent)
      raise
    end
  end
end
