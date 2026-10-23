# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_24_071500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "record_type", null: false
    t.bigint "record_id"
    t.string "outcome", null: false
    t.string "reason_code"
    t.jsonb "before_data"
    t.jsonb "after_data"
    t.string "ip_address"
    t.text "user_agent"
    t.datetime "occurred_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["occurred_at", "id"], name: "index_audit_events_on_occurred_at_and_id"
    t.index ["record_type", "record_id"], name: "index_audit_events_on_record_type_and_record_id"
    t.check_constraint "outcome::text = ANY (ARRAY['success'::character varying::text, 'refused'::character varying::text])", name: "audit_events_outcome_allowed"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "state", default: "active", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.check_constraint "jsonb_typeof(custom_fields) = 'object'::text", name: "brands_custom_fields_object"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "brands_state_allowed"
  end

  create_table "cards", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "product_id", null: false
    t.string "activation_number", null: false
    t.text "pin"
    t.string "status", default: "issued", null: false
    t.string "idempotency_key", null: false
    t.string "request_fingerprint", null: false
    t.decimal "face_value_snapshot", precision: 16, scale: 2, null: false
    t.string "currency_snapshot", limit: 3, null: false
    t.decimal "payout_rate_snapshot", precision: 7, scale: 4, null: false
    t.decimal "payout_amount_snapshot", precision: 16, scale: 2, null: false
    t.datetime "issued_at", null: false
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activation_number"], name: "index_cards_on_activation_number", unique: true
    t.index ["cancelled_at"], name: "index_cards_on_cancelled_at"
    t.index ["client_id", "idempotency_key"], name: "index_cards_unique_client_idempotency", unique: true
    t.index ["client_id", "status"], name: "index_cards_on_client_id_and_status"
    t.index ["client_id"], name: "index_cards_on_client_id"
    t.index ["issued_at"], name: "index_cards_on_issued_at"
    t.index ["product_id"], name: "index_cards_on_product_id"
    t.check_constraint "currency_snapshot::text ~ '^[A-Z]{3}$'::text", name: "cards_currency_iso_shape"
    t.check_constraint "face_value_snapshot > 0::numeric AND payout_amount_snapshot >= 0::numeric", name: "cards_amounts_nonnegative"
    t.check_constraint "payout_rate_snapshot >= 0::numeric AND payout_rate_snapshot <= 100::numeric", name: "cards_payout_rate_range"
    t.check_constraint "status::text = 'issued'::text AND cancelled_at IS NULL OR status::text = 'cancelled'::text AND cancelled_at IS NOT NULL", name: "cards_cancel_state_consistency"
    t.check_constraint "status::text = ANY (ARRAY['issued'::character varying::text, 'cancelled'::character varying::text])", name: "cards_status_allowed"
  end

  create_table "product_accesses", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "product_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "product_id"], name: "index_product_accesses_unique_grant", unique: true
    t.index ["client_id"], name: "index_product_accesses_on_client_id"
    t.index ["product_id"], name: "index_product_accesses_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "brand_id", null: false
    t.string "name", null: false
    t.decimal "face_value", precision: 16, scale: 2, null: false
    t.string "currency", limit: 3, null: false
    t.string "state", default: "active", null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["brand_id"], name: "index_products_on_brand_id"
    t.index ["deleted_at"], name: "index_products_on_deleted_at"
    t.check_constraint "currency::text ~ '^[A-Z]{3}$'::text", name: "products_currency_iso_shape"
    t.check_constraint "deleted_at IS NULL OR state::text = 'inactive'::text", name: "deleted_products_inactive"
    t.check_constraint "face_value > 0::numeric", name: "products_face_value_positive"
    t.check_constraint "jsonb_typeof(custom_fields) = 'object'::text", name: "products_custom_fields_object"
    t.check_constraint "state::text = ANY (ARRAY['active'::character varying::text, 'inactive'::character varying::text])", name: "products_state_allowed"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "role", null: false
    t.boolean "active", default: true, null: false
    t.decimal "payout_rate", precision: 7, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "payout_rate IS NULL OR payout_rate >= 0::numeric AND payout_rate <= 100::numeric", name: "users_payout_rate_range"
    t.check_constraint "role::text = 'admin'::text OR payout_rate IS NOT NULL", name: "clients_need_payout_rate"
    t.check_constraint "role::text = ANY (ARRAY['admin'::character varying::text, 'client'::character varying::text])", name: "users_role_allowed"
  end

  add_foreign_key "audit_events", "users", column: "actor_id", on_delete: :nullify
  add_foreign_key "cards", "products"
  add_foreign_key "cards", "users", column: "client_id"
  add_foreign_key "product_accesses", "products"
  add_foreign_key "product_accesses", "users", column: "client_id"
  add_foreign_key "products", "brands"
end
