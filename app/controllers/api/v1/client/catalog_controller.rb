module Api
  module V1
    module Client
      class CatalogController < BaseController
        def index
          products = Catalog::EligibleProducts.call(client: current_user)

          if params[:q].present?
            unless params[:q].is_a?(String) && params[:q].length <= 100
              raise Api::InvalidFilter, "Invalid catalog search or filter parameter."
            end
            term = "%#{Product.sanitize_sql_like(params[:q].strip)}%"
            products = products.where("products.name ILIKE :term OR brands.name ILIKE :term", term: term)
          end

          if params[:brand_id].present?
            unless params[:brand_id].to_s.match?(/\A[1-9][0-9]*\z/)
              raise Api::InvalidFilter, "Invalid catalog search or filter parameter."
            end
            products = products.where(brand_id: params[:brand_id].to_i)
          end

          if params[:currency].present?
            currency = params[:currency].to_s.upcase
            unless currency.match?(/\A[A-Z]{3}\z/)
              raise Api::InvalidFilter, "Invalid catalog search or filter parameter."
            end
            products = products.where(currency: currency)
          end

          records, meta = paginate(products.order(:id))
          render json: { data: records.includes(:brand).map { |product|
            product.as_json(only: %i[id brand_id name face_value currency state custom_fields])
              .merge(brand_name: product.brand.name)
          }, meta: meta }
        end
      end
    end
  end
end
