# Demo data only; never create known passwords in production.
if Rails.env.development?
  admin_password = ENV["DEMO_ADMIN_PASSWORD"]
  client_password = ENV["DEMO_CLIENT_PASSWORD"]

  if admin_password.present? && client_password.present?
    admin = User.find_or_initialize_by(email: "admin@example.test")
    admin.update!(password: admin_password, role: "admin", active: true, payout_rate: nil)

    client = User.find_or_initialize_by(email: "client@example.test")
    client.update!(password: client_password, role: "client", active: true, payout_rate: 90)

    brand = Brand.find_or_create_by!(name: "Demo Gift Cards")
    product = Product.find_or_create_by!(brand: brand, name: "USD 100 Gift Card") do |p|
      p.face_value = 100
      p.currency = "USD"
      p.state = "active"
    end
    ProductAccess.find_or_create_by!(client: client, product: product)
    puts "Development demo users and sample catalog are ready (credentials not printed)."
  else
    puts "No demo accounts created. Set DEMO_ADMIN_PASSWORD and DEMO_CLIENT_PASSWORD to seed development users."
  end
end
