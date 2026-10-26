# Synthetic development data for exercising pagination, filters and gift card workflows.
# Safe to rerun: stable names/keys and find_or_create_by! preserve existing records.
# Never seed demo accounts or cards in production, or print passwords/PINs.
if Rails.env.development?
  admin_password = ENV["DEMO_ADMIN_PASSWORD"]
  client_password = ENV["DEMO_CLIENT_PASSWORD"]

  if admin_password.blank? || client_password.blank?
    puts "Demo seed skipped: set DEMO_ADMIN_PASSWORD and DEMO_CLIENT_PASSWORD first."
  else
    require "securerandom"

    # All counts exceed API's default 25 items/page; major lists also exceed
    # the maximum per_page=100, so page=2 remains useful when testing manually.
    BRAND_COUNT = 120
    CLIENT_COUNT = 125
    PRODUCT_COUNT = 135
    CARD_COUNT = 160

    admin = User.find_or_initialize_by(email: "admin@example.test")
    admin.assign_attributes(role: "admin", active: true, payout_rate: nil)
    admin.password = admin_password if admin.new_record? || !admin.authenticate(admin_password)
    admin.save! if admin.new_record? || admin.changed?

    client = User.find_or_initialize_by(email: "client@example.test")
    client.assign_attributes(role: "client", active: true, payout_rate: 90)
    client.password = client_password if client.new_record? || !client.authenticate(client_password)
    client.save! if client.new_record? || client.changed?

    primary_brand = Brand.find_or_create_by!(name: "Demo Gift Cards")
    legacy_product = Product.find_or_create_by!(brand: primary_brand, name: "USD 100 Gift Card") do |p|
      p.face_value = 100
      p.currency = "USD"
      p.state = "active"
    end
    ProductAccess.find_or_create_by!(client: client, product: legacy_product)

    # Brand directory: 121+ brands, including inactive examples for Admin filters.
    brands = (1..BRAND_COUNT).map do |index|
      Brand.find_or_create_by!(name: format("Pagination Demo Brand %03d", index)) do |brand|
        brand.state = (index % 12).zero? ? "inactive" : "active"
        brand.custom_fields = { "collection" => "pagination", "region" => %w[US EU APAC][index % 3] }
      end
    end

    # One Brand intentionally owns >100 Products to test its nested API endpoint.
    # Leave some inactive Products for Admin; the Client gets >100 eligible items.
    currencies = %w[USD EUR GBP JPY VND]
    products = (1..PRODUCT_COUNT).map do |index|
      currency = currencies[(index - 1) % currencies.length]
      Product.find_or_create_by!(brand: primary_brand,
        name: format("Pagination Demo Card %03d", index)) do |product|
        product.currency = currency
        product.face_value = %w[JPY VND].include?(currency) ? 50_000 : (25 * (1 + index % 8))
        product.state = index > 130 ? "inactive" : "active"
        product.custom_fields = { "collection" => "pagination", "tier" => (index % 3) + 1 }
      end
    end

    # Give other Brands a product too, so Brand filtering is meaningful.
    secondary_products = brands.map.with_index(1) do |brand, index|
      Product.find_or_create_by!(brand: brand, name: "Standard Gift Card") do |product|
        product.currency = currencies[index % currencies.length]
        product.face_value = 50
        product.state = "active"
        product.custom_fields = { "collection" => "pagination" }
      end
    end

    # Synthetic clients are not login credentials for reviewers. Each gets an
    # unprinted random password at creation; reruns never rotate it.
    clients = (1..CLIENT_COUNT).map do |index|
      User.find_or_create_by!(email: format("pagination-client-%03d@example.test", index)) do |user|
        user.password = SecureRandom.hex(24)
        user.role = "client"
        user.active = (index % 17) != 0
        user.payout_rate = 70 + (index % 26)
      end
    end

    # >100 Grants for the main Client; a few for every other Client as well.
    eligible_products = products.select(&:active?)
    (eligible_products + secondary_products.select { |p| p.brand.active? }.first(25)).each do |product|
      ProductAccess.find_or_create_by!(client: client, product: product)
    end
    clients.each_with_index do |demo_client, index|
      4.times do |offset|
        product = eligible_products[(index * 4 + offset) % eligible_products.length]
        ProductAccess.find_or_create_by!(client: demo_client, product: product)
      end
    end

    # Use the actual issuing/cancellation services, not hand-crafted card fields:
    # snapshots, encryption, fingerprints and Audit Events stay realistic.
    seed_request = Struct.new(:remote_ip, :user_agent).new("127.0.0.1", "WOGI pagination demo seed")
    CARD_COUNT.times do |index|
      key = format("pagination-demo-card-%04d", index + 1)
      card = Card.find_by(client: client, idempotency_key: key)
      unless card
        product = eligible_products[index % eligible_products.length]
        card = Cards::Issue.call(client: client, product_id: product.id,
          with_pin: index.even?, idempotency_key: key, request: seed_request).card
      end
      Cards::Cancel.call(client: client, card_id: card.id, request: seed_request) if
        (index % 5).zero? && card.issued?
    end

    puts "Development pagination demo ready (credentials and PINs not printed):"
    puts "  Brands: #{Brand.count}; Products: #{Product.count}; Clients: #{User.client.count}"
    puts "  Product grants: #{ProductAccess.count}; Cards: #{Card.count}; Audit events: #{AuditEvent.count}"
    puts "  Main Client: #{client.email} — #{client.cards.count} cards"
    puts "Rerun bin/rails db:seed safely; existing records will not be duplicated."
  end
end
