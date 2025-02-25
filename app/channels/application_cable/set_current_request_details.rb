module ApplicationCable
  module SetCurrentRequestDetails
    def set_request_details
      Current.user = current_user
      Current.request_id = SecureRandom.uuid
    end
  end
end 