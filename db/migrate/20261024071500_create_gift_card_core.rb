class CreateGiftCardCore < ActiveRecord::Migration[8.1]
  def change
    enable_extension "citext" unless extension_enabled?("citext")

    create_table :users do |t|
      t.column :email, :citext, null: false
      t.string :password_digest, null: false
      t.string :role, null: false
      t.boolean :active, null: false, default: true
      t.decimal :payout_rate, precision: 7, scale: 4
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN ('admin', 'client')", name: "users_role_allowed"
    add_check_constraint :users, "payout_rate IS NULL OR payout_rate BETWEEN 0 AND 100", name: "users_payout_rate_range"
    add_check_constraint :users, "role = 'admin' OR payout_rate IS NOT NULL", name: "clients_need_payout_rate"

    create_table :brands do |t|
      t.string :name, null: false
      t.string :state, null: false, default: "active"
      t.jsonb :custom_fields, null: false, default: {}
      t.timestamps
    end
    add_check_constraint :brands, "state IN ('active', 'inactive')", name: "brands_state_allowed"
    add_check_constraint :brands, "jsonb_typeof(custom_fields) = 'object'", name: "brands_custom_fields_object"

    create_table :products do |t|
      t.references :brand, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :face_value, precision: 16, scale: 2, null: false
      t.string :currency, limit: 3, null: false
      t.string :state, null: false, default: "active"
      t.jsonb :custom_fields, null: false, default: {}
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :products, :deleted_at
    add_check_constraint :products, "face_value > 0", name: "products_face_value_positive"
    add_check_constraint :products, "currency ~ '^[A-Z]{3}$'", name: "products_currency_iso_shape"
    add_check_constraint :products, "state IN ('active', 'inactive')", name: "products_state_allowed"
    add_check_constraint :products, "jsonb_typeof(custom_fields) = 'object'", name: "products_custom_fields_object"
    add_check_constraint :products, "deleted_at IS NULL OR state = 'inactive'", name: "deleted_products_inactive"

    create_table :product_accesses do |t|
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :product, null: false, foreign_key: true
      t.timestamps
    end
    add_index :product_accesses, [ :client_id, :product_id ], unique: true,
      name: "index_product_accesses_unique_grant"

    create_table :cards do |t|
      t.references :client, null: false, foreign_key: { to_table: :users }
      t.references :product, null: false, foreign_key: true
      t.string :activation_number, null: false
      t.text :pin # Populated only by Active Record Encryption (implemented with Cards::Issue).
      t.string :status, null: false, default: "issued"
      t.string :idempotency_key, null: false
      t.string :request_fingerprint, null: false
      t.decimal :face_value_snapshot, precision: 16, scale: 2, null: false
      t.string :currency_snapshot, limit: 3, null: false
      t.decimal :payout_rate_snapshot, precision: 7, scale: 4, null: false
      t.decimal :payout_amount_snapshot, precision: 16, scale: 2, null: false
      t.datetime :issued_at, null: false
      t.datetime :cancelled_at
      t.timestamps
    end
    add_index :cards, :activation_number, unique: true
    add_index :cards, [ :client_id, :idempotency_key ], unique: true,
      name: "index_cards_unique_client_idempotency"
    add_index :cards, [ :client_id, :status ]
    add_index :cards, :issued_at
    add_index :cards, :cancelled_at
    add_check_constraint :cards, "status IN ('issued', 'cancelled')", name: "cards_status_allowed"
    add_check_constraint :cards, "(status = 'issued' AND cancelled_at IS NULL) OR (status = 'cancelled' AND cancelled_at IS NOT NULL)", name: "cards_cancel_state_consistency"
    add_check_constraint :cards, "face_value_snapshot > 0 AND payout_amount_snapshot >= 0", name: "cards_amounts_nonnegative"
    add_check_constraint :cards, "payout_rate_snapshot BETWEEN 0 AND 100", name: "cards_payout_rate_range"
    add_check_constraint :cards, "currency_snapshot ~ '^[A-Z]{3}$'", name: "cards_currency_iso_shape"

    create_table :audit_events do |t|
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :action, null: false
      t.string :record_type, null: false
      t.bigint :record_id
      t.string :outcome, null: false
      t.string :reason_code
      t.jsonb :before_data
      t.jsonb :after_data
      t.string :ip_address
      t.text :user_agent
      t.datetime :occurred_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
    end
    add_index :audit_events, :action
    add_index :audit_events, [ :record_type, :record_id ]
    add_index :audit_events, [ :occurred_at, :id ]
    add_check_constraint :audit_events, "outcome IN ('success', 'refused')", name: "audit_events_outcome_allowed"
  end
end
