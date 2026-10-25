module Api
  module V1
    module Client
      class CatalogController < BaseController
        def index
          products = Product.joins(:brand, :product_accesses)
            .where(product_accesses: { client_id: current_user.id },
              state: "active", deleted_at: nil, brands: { state: "active" })

          if params[:q].present?
            return invalid_filter unless params[:q].is_a?(String) && params[:q].length <= 100
            term = "%#{Product.sanitize_sql_like(params[:q].strip)}%"
            products = products.where("products.name ILIKE :term OR brands.name ILIKE :term", term: term)
          end

          if params[:brand_id].present?
            return invalid_filter unless params[:brand_id].to_s.match?(/\A[1-9][0-9]*\z/)
            products = products.where(brand_id: params[:brand_id].to_i)
          end

          if params[:currency].present?
            currency = params[:currency].to_s.upcase
            return invalid_filter unless currency.match?(/\A[A-Z]{3}\z/)
            products = products.where(currency: currency)
          end

          render json: { data: products.includes(:brand).order(:id).map { |p|
            p.as_json(only: %i[id brand_id name face_value currency state custom_fields])
              .merge(brand_name: p.brand.name)
          } }
        end

        private

        def invalid_filter
          render json: { error: { code: "invalid_catalog_filter",
            message: "Invalid catalog search or filter parameter." } },
            status: :unprocessable_content
        end
      end
    end
  end
end
