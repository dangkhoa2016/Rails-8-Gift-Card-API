module Api
  module V1
    module Admin
      class ProductsController < BaseController
        def index
          scope = Brand.find(params[:brand_id]).products.order(:id)
          records, meta = paginate(scope)
          render json: { data: records.map { |record| serialize(record) }, meta: meta }
        end

        def show
          render json: { data: serialize(Product.find(params[:id])) }
        end

        def create
          brand = Brand.find(params[:brand_id])
          record = brand.products.build(product_params)
          Product.transaction do
            record.save!
            audit_change("product.created", record, after_data: record)
          end
          render json: { data: serialize(record) }, status: :created
        end

        def update
          record = Product.find(params[:id])
          Product.transaction do
            before = record.attributes
            record.update!(product_params)
            audit_change("product.updated", record, before_data: before, after_data: record)
          end
          render json: { data: serialize(record) }
        end

        def destroy
          record = Product.find(params[:id])
          Product.transaction do
            before = record.attributes
            record.update!(state: "inactive", deleted_at: record.deleted_at || Time.current)
            audit_change("product.deleted", record, before_data: before, after_data: record)
          end
          render json: { data: serialize(record) }
        end

        private

        def product_params
          params.permit(:name, :face_value, :currency, :state, custom_fields: {})
        end

        def serialize(record)
          record.as_json(only: %i[id brand_id name face_value currency state custom_fields deleted_at])
        end
      end
    end
  end
end
