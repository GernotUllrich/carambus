# All Administrate controllers inherit from this
# `Administrate::ApplicationController`, making it the ideal place to put
# authentication logic or other before_actions.
#
# If you want to add pagination or other controller-level concerns,
# you're free to overwrite the RESTful controller actions.
module Admin
  class ApplicationController < Administrate::ApplicationController
    include CableReady::Broadcaster
    include SetCurrentRequestDetails
    before_action :authenticate_admin

    def authenticate_admin
      # authenticate_user!
      # redirect_to root_path unless current_user.admin?
    end

    # Override this value to specify the number of elements to display at a time
    # on index pages. Defaults to 20.
    # def records_per_page
    #   params[:per_page] || 20
    # end

    def valid_action?(name, resource = resource_class)
      %w[index show new edit create update destroy].include?(name.to_s)
    end

    # Diese Methode wird für die Navigation verwendet
    def navigation_resources
      [
        :users,
        :settings
      ]
    end

    # Diese Methode wird für die Resource-Verwaltung verwendet
    def resources
      @_resources ||= [
        User,
        Setting
      ]
    end
  end
end
