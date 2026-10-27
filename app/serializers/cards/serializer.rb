module Cards
  class Serializer
    FIELDS = %i[id client_id product_id status activation_number
      face_value_snapshot currency_snapshot payout_rate_snapshot
      payout_amount_snapshot issued_at cancelled_at].freeze

    def self.call(card)
      card.as_json(only: FIELDS).merge(
        product_name: card.product.name,
        brand_name: card.product.brand.name,
        # Never decrypt or expose PIN in ordinary card responses.
        has_pin: card.read_attribute_before_type_cast(:pin).present?
      )
    end
  end
end
