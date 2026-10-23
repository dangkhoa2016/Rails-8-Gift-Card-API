module Api
  module V1
    module Client
      class BaseController < Api::V1::BaseController
        before_action :require_client!
        private

        def require_client!
          forbidden unless current_user.client?
        end
      end
    end
  end
end
