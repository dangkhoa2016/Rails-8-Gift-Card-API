module Audit
  class RecordEvent
    ALLOWED_ATTRIBUTES = {
      "Brand" => %w[id name state custom_fields],
      "Product" => %w[id brand_id name face_value currency state custom_fields deleted_at],
      "User" => %w[id email role active payout_rate],
      "ProductAccess" => %w[id client_id product_id granted],
      "Card" => %w[id client_id product_id status face_value_snapshot
        currency_snapshot payout_rate_snapshot payout_amount_snapshot issued_at cancelled_at]
    }.freeze

    def self.call(actor:, request:, action:, record:, before_data: nil, after_data: nil,
      outcome: "success", reason_code: nil)
      kind = record.class.name
      AuditEvent.create!(
        actor: actor, action: action, record_type: kind, record_id: record.id,
        outcome: outcome, reason_code: reason_code,
        before_data: filtered(before_data, kind),
        after_data: filtered(after_data, kind),
        ip_address: request.remote_ip, user_agent: request.user_agent
      )
    end

    def self.filtered(value, record_type)
      return nil if value.nil?
      keys = ALLOWED_ATTRIBUTES.fetch(record_type, [])
      raw = value.is_a?(ActiveRecord::Base) ? value.attributes : value.to_h
      raw.stringify_keys.slice(*keys)
    end
  end
end
