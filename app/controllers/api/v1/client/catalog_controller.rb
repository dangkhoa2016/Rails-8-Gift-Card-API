module Api
  module V1
    module Client
      class CatalogController < BaseController
        def index
          products = Product.joins(:brand, :product_accesses)
            .where(product_accesses: { client_id: current_user.id },
              state: "active", deleted_at: nil, brands: { state: "active" })
            .order(:id)
          render json: { data: products.map { |p|
            p.as_json(only: %i[id brand_id name face_value currency state custom_fields])
          } }
        end
      end
    end
  end
end
