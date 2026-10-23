module Api
  module V1
    module Admin
      class ClientsController < BaseController
        def index
          scope = User.client.order(:id)
          records, meta = paginate(scope)
          render json: { data: records.map { |record| serialize(record) }, meta: meta }
        end

        def show
          render json: { data: serialize(client) }
        end

        def create
          record = User.new(client_params)
          record.role = "client"
          User.transaction do
            record.save!
            audit_change("client.created", record, after_data: record)
          end
          render json: { data: serialize(record) }, status: :created
        end

        def update
          record = client
          User.transaction do
            before = record.attributes
            record.update!(client_params)
            audit_change("client.updated", record, before_data: before, after_data: record)
          end
          render json: { data: serialize(record) }
        end

        private

        def client
          User.client.find(params[:id])
        end

        def client_params
          params.permit(:email, :password, :payout_rate, :active)
        end

        def serialize(record)
          record.as_json(only: %i[id email role active payout_rate created_at])
        end
      end
    end
  end
end
