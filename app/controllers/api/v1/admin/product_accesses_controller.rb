module Api
  module V1
    module Admin
      class ProductAccessesController < BaseController
        def index
          grants, meta = paginate(client.product_accesses.includes(:client, product: :brand).order(:id))
          render json: { data: grants.map { |grant| serialize(grant) }, meta: meta }
        end

        def create
          grant = ProductAccess.new(client: client, product: Product.find(params.require(:product_id)))
          ProductAccess.transaction do
            grant.save!
            audit_change("product_access.granted", grant, after_data: grant.attributes.merge("granted" => true))
          end
          render json: { data: serialize(grant) }, status: :created
        end

        def destroy
          grant = client.product_accesses.find_by!(product_id: params[:id])
          ProductAccess.transaction do
            before = grant.attributes.merge("granted" => true)
            grant.destroy!
            audit_change("product_access.revoked", grant, before_data: before,
              after_data: before.merge("granted" => false))
          end
          head :no_content
        end

        private

        def client
          User.client.find(params[:client_id])
        end

        def serialize(grant)
          grant.as_json(only: %i[id client_id product_id]).merge(
            client_email: grant.client.email,
            product_name: grant.product.name,
            brand_name: grant.product.brand.name,
            brand_id: grant.product.brand_id,
            product_currency: grant.product.currency,
            product_face_value: grant.product.face_value
          )
        end
      end
    end
  end
end
