require "securerandom"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include SetCurrentRequestDetails

    identified_by :current_user, :true_user, :connection_token
    impersonates :user

    delegate :params, :session, to: :request

    DEBUG = Rails.env != "production"

    def connect
      self.current_user = find_verified_user
      set_request_details
      assign_connection_token
      request.env['connection_token'] = connection_token
      Rails.logger.info "[ActionCable] Connected: user=#{current_user.id if current_user} token=#{connection_token}"

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

    private

    def assign_connection_token
      self.connection_token = SecureRandom.uuid
      logger.add_tags "Connection #{connection_token}"
    end
  end
end
