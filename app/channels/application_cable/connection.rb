module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include SetCurrentRequestDetails

    identified_by :current_user, :true_user
    impersonates :user

    delegate :params, :session, to: :request

    DEBUG = Rails.env != "production"

    def connect
      self.current_user = find_verified_user
      set_request_details

      logger.add_tags "ActionCable", "User #{current_user.id}"
    end

    protected

    def find_verified_user
      # Temporär für Debugging:
      User.first || reject_unauthorized_connection
    end

    def user_signed_in?
      !!current_user
    end
  end
end
