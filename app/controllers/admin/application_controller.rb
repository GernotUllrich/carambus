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

    # Administrate erlaubt volle CRUD auf users, settings und regions — inklusive
    # Rollenvergabe. Wer hier hereinkommt, kann sich selbst zum system_admin machen.
    # Deshalb bewusst system_admin? und NICHT admin? (= club_admin || system_admin):
    # ein Vereins-Admin soll die Benutzerverwaltung der gesamten Instanz nicht oeffnen.
    #
    # Diese Methode war seit dem initial commit ein leerer Administrate-Scaffold-Stub
    # ("TODO Add authentication logic here"), spaeter in c1e473cb (2025-02-25) durch
    # auskommentierte Zeilen ersetzt — aber nie aktiv. Der gesamte Admin-Bereich war
    # damit unauthentifiziert erreichbar (verifiziert 2026-08-14 auf nbv.carambus.de:
    # GET /admin/users lieferte ohne Login die Benutzerliste samt E-Mail und Rolle).
    def authenticate_admin
      return if current_user&.system_admin?

      redirect_to root_path, alert: "System-Admin only - ask gernot.ullrich@gmx.de for permission"
    end
    
    # Override redirect_to to allow lvh.me redirects
    def redirect_to(options = {}, response_options = {})
      super(options, response_options.merge(allow_other_host: true))
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
        :settings,
        :translations,
        :training_concepts,
        :tags
      ]
    end

    # Diese Methode wird für die Resource-Verwaltung verwendet
    def resources
      @_resources ||= [
        User,
        Setting,
        TrainingConcept,
        Tag
      ]
    end
  end
end
