module Api
  module V1
    module Admin
      class BaseController < Api::V1::BaseController
        before_action :require_admin!

        private

        def require_admin!
          forbidden unless current_user.admin?
        end

        def audit_change(action, record, before_data: nil, after_data: nil)
          Audit::RecordEvent.call(actor: current_user, request: request, action: action,
            record: record, before_data: before_data, after_data: after_data)
        end
      end
    end
  end
end
