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
    require "digest"

    # Four-digit, random-looking labels with a fixed seed identity. A fresh
    # random number on every run would rename or duplicate the same fixtures.
    suffix = lambda do |kind, index|
      format("%04d", Digest::SHA256.hexdigest("wogi-seed-#{kind}-#{index}").first(12).to_i(16) % 10_000)
    end

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

    primary_brand_name = "Gift Card Gallery #{suffix.call("brand", "main")}"
    primary_brands = Brand.where(name: [ primary_brand_name, "Demo Gift Cards" ]).to_a
    raise "Conflicting main seed Brands" if primary_brands.size > 1
    primary_brand = primary_brands.first || Brand.create!(name: primary_brand_name)
    primary_brand.update!(name: primary_brand_name) if primary_brand.name != primary_brand_name

    legacy_product = Product.find_or_create_by!(brand: primary_brand, name: "USD 100 Gift Card") do |p|
      p.face_value = 100
      p.currency = "USD"
      p.state = "active"
    end
    ProductAccess.find_or_create_by!(client: client, product: legacy_product)

    # Distinct Brand labels have reproducible four-digit suffixes. Older seed
    # layouts are migrated in place, preserving IDs and existing Card history.
    legacy_brand_names = %w[Aurora Bluebird Cedar Evergreen Harbor Luna Maple Northstar Riverstone Sunrise Willow Meadow]
    legacy_store_types = %w[Market Books Coffee Gifts Home Outdoors Wellness Studio Travel Tech]
    brand_names = %w[Aurora Bluebird Cedar Evergreen Harbor Luna Maple Northstar Riverstone Sunrise Willow Meadow Ember Orchid Juniper Aspen Cobalt Silverline Beacon Solstice Magnolia Brookstone Goldenleaf Pinecrest]
    store_types = %w[Market Books Coffee Gifts Studio]
    raise "Unexpected demo Brand combinations" unless brand_names.product(store_types).length == BRAND_COUNT

    seeded_brands = Brand.where("custom_fields ->> 'collection' = ?", "pagination").order(:id).to_a
    raise "Incomplete seed Brand group; cannot safely assign indices" unless
      seeded_brands.empty? || seeded_brands.size == BRAND_COUNT

    brands = Brand.transaction do
      (1..BRAND_COUNT).map do |index|
        old_name = format("Pagination Demo Brand %03d", index)
        previous_name = "#{legacy_brand_names.fetch((index - 1) % legacy_brand_names.size)} " \
          "#{legacy_store_types.fetch((index - 1) / legacy_brand_names.size)}"
        stem = "#{brand_names.fetch((index - 1) % brand_names.size)} " \
          "#{store_types.fetch((index - 1) / brand_names.size)}"
        new_name = "#{stem} #{suffix.call("brand", index)}"
        brand = if seeded_brands.any?
          # Ordered fixture IDs survive manual changes to names and states.
          seeded_brands.fetch(index - 1)
        else
          matches = Brand.where(name: [ old_name, previous_name, new_name ]).to_a
          raise "Ambiguous seed Brand identity for index #{index}" if matches.size > 1
          matches.first
        end

        if brand
          raise "Reserved seed Brand identity belongs to an unrelated Brand" unless
            brand.custom_fields["collection"] == "pagination"
          raise "Brand label already used elsewhere" if
            Brand.where(name: new_name).where.not(id: brand.id).exists?
          brand.update!(name: new_name) if brand.name != new_name
          brand
        else
          Brand.create!(name: new_name,
            state: (index % 12).zero? ? "inactive" : "active",
            custom_fields: { "collection" => "pagination",
              "region" => %w[US EU APAC][index % 3] })
        end
      end
    end

    # One Brand intentionally owns >100 Products to test its nested API endpoint.
    # Leave some inactive Products for Admin; the Client gets >100 eligible items.
    currencies = %w[USD EUR GBP JPY VND]
    card_styles = [
      "Everyday", "Celebration", "Signature", "Thank You", "Weekend",
      "Premium", "Classic", "Rewards", "Special Occasion", "Seasonal",
      "Essentials", "Digital", "Appreciation", "Flexible", "Holiday"
    ]
    seeded_products = primary_brand.products
      .where("custom_fields ->> 'collection' = ?", "pagination").order(:id).to_a
    raise "Incomplete primary Product group; cannot safely assign indices" unless
      seeded_products.empty? || seeded_products.size == PRODUCT_COUNT

    products = (1..PRODUCT_COUNT).map do |index|
      currency = currencies[(index - 1) % currencies.length]
      old_name = format("Pagination Demo Card %03d", index)
      new_name = "#{card_styles.fetch((index - 1) % card_styles.size)} " \
        "#{currency} Gift Card #{suffix.call("product", index)}"
      product = if seeded_products.any?
        seeded_products.fetch(index - 1)
      else
        matches = primary_brand.products.where(name: [ old_name, new_name ]).to_a
        raise "Ambiguous seed Product identity for index #{index}" if matches.size > 1
        matches.first
      end
      if product
        raise "Reserved seed Product identity belongs to an unrelated Product" unless
          product.custom_fields["collection"] == "pagination"
        raise "Product label already used within primary Brand" if
          primary_brand.products.where(name: new_name).where.not(id: product.id).exists?
        product.update!(name: new_name) if product.name != new_name
        product
      else
        primary_brand.products.create!(name: new_name,
          currency: currency,
          face_value: %w[JPY VND].include?(currency) ? 50_000 : (25 * (1 + index % 8)),
          state: index > 130 ? "inactive" : "active",
          custom_fields: { "collection" => "pagination", "tier" => (index % 3) + 1 })
      end
    end

    # Each secondary Brand has one descriptively named Product.
    secondary_products = brands.map.with_index(1) do |brand, index|
      name = "#{card_styles.fetch((index - 1) % card_styles.size)} Gift Card"
      tagged = brand.products.where("custom_fields ->> 'collection' = ?", "pagination").to_a
      raise "Multiple seeded Products in secondary Brand #{brand.id}" if tagged.size > 1
      matches = tagged.presence || brand.products.where(name: [ "Standard Gift Card", name ]).to_a
      raise "Ambiguous secondary Product identity for Brand #{brand.id}" if matches.size > 1
      product = matches.first
      if product
        raise "Reserved secondary Product identity belongs to an unrelated Product" unless
          product.custom_fields["collection"] == "pagination"
        raise "Product label already used within secondary Brand" if
          brand.products.where(name: name).where.not(id: product.id).exists?
        product.update!(name: name) if product.name != name
        product
      else
        brand.products.create!(name: name,
          currency: currencies[index % currencies.length], face_value: 50,
          state: "active", custom_fields: { "collection" => "pagination" })
      end
    end

    # Synthetic Clients use believable, stable email aliases on the reserved
    # example.test domain. These are NOT reviewer login accounts; their
    # passwords are random and never printed. Five surnames and 25 given names
    # produce 125 unique, readable addresses without internal fixture labels.
    given_names = %w[
      olivia emma amelia sophia charlotte ava isabella mia evelyn harper
      luna camila gianna elizabeth eleanor ella abigail sofia avery scarlett
      emily aria penelope chloe layla
    ]
    family_names = %w[morgan parker brooks reed bennett]
    raise "Unexpected seeded Client name combinations" unless
      given_names.size * family_names.size == CLIENT_COUNT

    seeded_client_email = lambda do |index|
      given = given_names.fetch((index - 1) % given_names.size)
      family = family_names.fetch((index - 1) / given_names.size)
      "#{given}.#{family}@example.test"
    end
    old_client_email = ->(index) { format("pagination-client-%03d@example.test", index) }

    # On existing databases, recognize the original synthetic batch by its
    # stable IDs. Rename only the exact legacy alias for that index; preserve
    # an email that an Admin has intentionally customized in the UI.
    existing_client_batch = User.client.where.not(id: client.id).order(:id).limit(CLIENT_COUNT).to_a
    matching_fixture_emails = existing_client_batch.each_with_index.count do |user, index|
      [ old_client_email.call(index + 1), seeded_client_email.call(index + 1) ].include?(user.email)
    end
    newly_created_clients = []
    clients = if existing_client_batch.size == CLIENT_COUNT && matching_fixture_emails >= 100
      User.transaction do
        existing_client_batch.each_with_index do |user, index|
          next unless user.email == old_client_email.call(index + 1)

          replacement = seeded_client_email.call(index + 1)
          raise "Seed Client email is already assigned: #{replacement}" if
            User.where(email: replacement).where.not(id: user.id).exists?
          user.update!(email: replacement)
        end
      end
      existing_client_batch
    elsif existing_client_batch.size == CLIENT_COUNT
      raise "Cannot safely distinguish existing seeded Clients from Admin-created Clients"
    else
      (1..CLIENT_COUNT).map do |index|
        previous = old_client_email.call(index)
        replacement = seeded_client_email.call(index)
        matches = User.where(email: [ previous, replacement ]).to_a
        raise "Ambiguous seeded Client identity for index #{index}" if matches.size > 1

        if (user = matches.first)
          user.update!(email: replacement) if user.email == previous
          user
        else
          user = User.create!(email: replacement, password: SecureRandom.hex(24),
            role: "client", active: (index % 17) != 0,
            payout_rate: 70 + (index % 26))
          newly_created_clients << user
          user
        end
      end
    end

    # >100 Grants for the main Client; a few for every other Client as well.
    eligible_products = products.select(&:active?)
    # A later seed run must not silently restore Admin-revoked grants or
    # assign new ones when a Product's active state has been changed.
    unless client.product_accesses.joins(:product)
        .where("products.custom_fields ->> 'collection' = ?", "pagination").exists?
      (eligible_products + secondary_products.select { |p| p.brand.active? }.first(25)).each do |product|
        ProductAccess.find_or_create_by!(client: client, product: product)
      end
    end
    clients.each_with_index do |demo_client, index|
      next unless newly_created_clients.include?(demo_client)

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

    # Reviewable financial reports need multiple Brands sharing one currency
    # and multiple Clients issuing distinct Cards. The original 160 main-Client
    # fixtures above are NEVER reassigned, replaced, or reset.
    #
    # Each selected secondary Product is USD 50 and already granted to the
    # primary reviewer Client. Distinct Brand IDs now produce separate by_brand
    # rows, while personal spending still aggregates by original currency.
    report_brand_indexes = [ 5, 10, 15, 20, 25 ]
    report_client_products = report_brand_indexes.map { |number| secondary_products.fetch(number - 1) }
    # These Products start as active/USD on a fresh install. An Admin may
    # later deactivate a Brand/Product; existing report Cards must still
    # survive future seed runs without forcing the status back to active.

    # A stable idempotency key is reserved for every synthetic report Card.
    # Existing records are never reissued (which would duplicate audit events).
    issue_report_card = lambda do |owner, product, key, with_pin, cancelled|
      card = Card.find_by(client: owner, idempotency_key: key)
      if card
        raise "Seed key conflicts with an existing Card's Product: #{key}" unless card.product_id == product.id
      else
        card = Cards::Issue.call(client: owner, product_id: product.id,
          with_pin: with_pin, idempotency_key: key, request: seed_request).card
      end
      Cards::Cancel.call(client: owner, card_id: card.id, request: seed_request) if
        cancelled && card.issued?
      card
    end

    report_client_products.each_with_index do |product, brand_index|
      3.times do |card_index|
        issue_report_card.call(client, product,
          format("finance-demo-main-%02d-%02d", brand_index + 1, card_index + 1),
          card_index.even?, card_index == 2)
      end
    end

    # These synthetic Clients already have unique payout rates; grant just the
    # two extra Brands they need. No reviewer passwords are rotated or printed.
    clients.first(3).each_with_index do |report_client, client_index|
      assigned = [
        report_client_products.fetch(0),
        report_client_products.fetch(1),
        eligible_products.fetch(client_index * 4)
      ]
      assigned.each_with_index do |product, card_index|
        key = format("finance-demo-client-%02d-%02d", client_index + 1, card_index + 1)
        unless Card.exists?(client: report_client, idempotency_key: key)
          ProductAccess.find_or_create_by!(client: report_client, product: product)
        end
        issue_report_card.call(report_client, product, key,
          card_index.odd?, card_index == 2 && client_index.even?)
      end
    end

    puts "Development sample data ready (credentials and PINs not printed):"
    puts "  Brands: #{Brand.count}; Products: #{Product.count}; Clients: #{User.client.count}"
    puts "  Product grants: #{ProductAccess.count}; Cards: #{Card.count}; Audit events: #{AuditEvent.count}"
    puts "  Main Client: #{client.email} — #{client.cards.count} cards"
    puts "  Report demo: #{report_client_products.size} additional Brands, " \
      "#{clients.first(3).size} additional Clients; all Cards have stable keys."
    puts "Rerun bin/rails db:seed safely; existing records will not be duplicated."
  end
end
