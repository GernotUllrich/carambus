require "securerandom"

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include SetCurrentRequestDetails

    identified_by :current_user, :true_user, :connection_token
    impersonates :user

    delegate :params, :session, to: :request

    DEBUG = Rails.env != "production"

    def connect
      log_origin_probe
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
    def find_verified_user
      env["warden"]&.user
    end

    def user_signed_in?
      !!current_user
    end

    private

    # TEMPORAER (Origin-Haertung, siehe .planning/tasks/TASK-actioncable-origin-hardening.md).
    # Dry-Run: bildet die Pruefung aus ActionCable::Connection::Base#allow_request_origin?
    # fuer den ZIELZUSTAND nach (Forgery-Protection aktiv, allowed_request_origins leer,
    # allow_same_origin_as_host = true) und protokolliert nur, was dann passieren wuerde.
    # Kein Verhaltenswechsel — dient dazu, das Umlegen des Flags zu belegen statt zu raten.
    #
    # Bewusst ueber Rails.logger statt ueber den Cable-Logger: letzterer ist in Production
    # auf Logger.new(nil) gesetzt (config/initializers/action_cable.rb) und wuerde die
    # Zeilen verschlucken.
    #
    # Nach der Auswertung wieder entfernen.
    def log_origin_probe
      origin = env["HTTP_ORIGIN"]
      host = env["HTTP_HOST"]
      proto = request.ssl? ? "https" : "http"
      same_origin = origin == "#{proto}://#{host}"

      Rails.logger.info(
        "[ActionCable][origin-probe] origin=#{origin.inspect} host=#{host.inspect} " \
        "proto=#{proto} same_origin=#{same_origin} would_reject=#{!same_origin}"
      )
    rescue => e
      # Die Probe darf den Verbindungsaufbau unter keinen Umstaenden verhindern.
      Rails.logger.warn "[ActionCable][origin-probe] fehlgeschlagen: #{e.class}: #{e.message}"
    end

    def assign_connection_token
      self.connection_token = SecureRandom.uuid
      logger.add_tags "Connection #{connection_token}"
    end
  end
end
