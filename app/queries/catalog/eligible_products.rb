module Catalog
  # Authorised, currently available products for a single client.
  class EligibleProducts
    def self.call(client:)
      Product.joins(:brand, :product_accesses)
        .where(product_accesses: { client_id: client.id },
          state: "active", deleted_at: nil, brands: { state: "active" })
    end
  end
end
