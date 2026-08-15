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

      logger.add_tags "ActionCable", current_user ? "User #{current_user.id}" : "anonymous"
    end

    protected

    # Identitaet der Verbindung = der per Devise/Warden angemeldete User, sonst nil.
    #
    # NICHT durch User.first ersetzen (vgl. c1e473cb vom 2025-02-25): das
    # authentifiziert jede Verbindung als ersten User der Tabelle, unabhaengig von
    # Session und Login.
    #
    # Anonyme Verbindungen werden bewusst ZUGELASSEN (mit current_user = nil) statt
    # abgewiesen — analog zum HTTP-Teil, der ebenfalls keine globale
    # authenticate_user! kennt: oeffentliche Seiten nutzen Reflexes (u.a. die
    # Live-Suche in shared/_search_with_filter.html.erb) und brauchen dafuer eine
    # Cable-Verbindung. Ein reject_unauthorized_connection wuerde sie lahmlegen.
    # Die Autorisierung liegt entsprechend bei den einzelnen Reflexes/Channels
    # (vgl. current_user&.admin?-Gates in TableMonitorReflex/PartyMonitorReflex).
    #
    # Scoreboards sind hier regulaer angemeldet — LocationsController ruft
    # bypass_sign_in(User.scoreboard) auf und legt damit eine echte Session an.
    #
    # Warden ist beim Handshake verfuegbar (auf api.carambus.de per Probe belegt:
    # warden=true, warden_user=<id> fuer eingeloggte Nutzer). Ein Session-Fallback
    # ist nicht noetig — ActionCable haengt per `mount ActionCable.server`
    # (config/routes.rb) im Router und laeuft durch den vollen Middleware-Stack.
    def find_verified_user
      env["warden"]&.user
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
