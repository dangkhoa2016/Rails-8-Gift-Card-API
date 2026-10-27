module Api
  module V1
    module Admin
      class BrandsController < BaseController
        def index
          scope = Brand.order(:id)
          if request.query_parameters.key?("q")
            query = request.query_parameters["q"]
            unless query.is_a?(String) && query.length <= 100
              return render json: { error: { code: "invalid_filter",
                message: "Search must be a text value of up to 100 characters." } },
                status: :unprocessable_content
            end
            term = query.strip
            scope = scope.where("name ILIKE ?", "%#{Brand.sanitize_sql_like(term)}%") if term.present?
          end
          records, meta = paginate(scope)
          render json: { data: records.map { |record| serialize(record) }, meta: meta }
        end

        def show
          render json: { data: serialize(Brand.find(params[:id])) }
        end

        def create
          record = Brand.new(brand_params)
          Brand.transaction do
            record.save!
            audit_change("brand.created", record, after_data: record)
          end
          render json: { data: serialize(record) }, status: :created
        end

        def update
          record = Brand.find(params[:id])
          Brand.transaction do
            before = record.attributes
            record.update!(brand_params)
            audit_change("brand.updated", record, before_data: before, after_data: record)
          end
          render json: { data: serialize(record) }
        end

        private

        def brand_params
          params.permit(:name, :state, custom_fields: {})
        end

        def serialize(record)
          record.as_json(only: %i[id name state custom_fields])
        end
      end
    end
  end
end
