Administrate::Engine.add_stylesheet('administrate/application')
Administrate::Engine.add_javascript('administrate/application')

Rails.application.config.to_prepare do
  Administrate::ApplicationController.class_eval do
    def navigation_resources
      @navigation_resources ||= [
        :users,
        :configurations
      ]
    end
  end
end 