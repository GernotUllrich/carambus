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
    # Warden ist beim WebSocket-Handshake nicht immer befuellt (in Production auf
    # api.carambus.de liefert env["warden"]&.user auch fuer eingeloggte Nutzer nil,
    # Log-Tag "[anonymous]"). Deshalb zusaetzlich die Session direkt auswerten:
    # Devise legt dort unter "warden.user.user.key" [[user_id], salt] ab.
    # ActionCable ist per `mount ActionCable.server` (routes.rb) im Router eingehaengt,
    # laeuft also durch den vollen Middleware-Stack — request.session ist verfuegbar.
    def find_verified_user
      env["warden"]&.user || user_from_session
    end

    def user_from_session
      user_id = request.session["warden.user.user.key"]&.dig(0, 0)
      User.find_by(id: user_id) if user_id
    rescue => e
      # Identitaetsermittlung darf den Verbindungsaufbau nie sprengen.
      Rails.logger.warn "[ActionCable] Session-Lookup fehlgeschlagen: #{e.class}: #{e.message}"
      nil
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
    # Nur Schluesselnamen, nie Werte (PII/Secrets).
    def session_key_names
      request.session.keys.sort.first(12)
    rescue => e
      "raised:#{e.class}"
    end

    def log_origin_probe
      origin = env["HTTP_ORIGIN"]
      host = env["HTTP_HOST"]
      proto = request.ssl? ? "https" : "http"
      same_origin = origin == "#{proto}://#{host}"

      # Auth-Diagnose (temporaer, zusammen mit der Origin-Probe): zeigt, ob Warden
      # befuellt ist und ob der Session-Fallback greift.
      warden_present = !env["warden"].nil?
      warden_user = begin
        env["warden"]&.user&.id
      rescue => e
        "raised:#{e.class}"
      end
      session_key = begin
        request.session["warden.user.user.key"]&.dig(0, 0)
      rescue => e
        "raised:#{e.class}"
      end

      # Unterscheidet "gar keine Session" von "leere Session" von "Session ohne User".
      # Nur Schluesselnamen und Praesenz protokollieren — keine Werte (PII/Secrets).
      rack_session = env["rack.session"]
      session_diag = begin
        {
          rack_session_class: rack_session.class.name,
          session_keys: session_key_names,
          cookie_key: Rails.application.config.session_options[:key],
          cookie_present: request.cookies.key?(Rails.application.config.session_options[:key].to_s)
        }
      rescue => e
        {error: "#{e.class}: #{e.message}"}
      end

      Rails.logger.info(
        "[ActionCable][origin-probe] origin=#{origin.inspect} host=#{host.inspect} " \
        "proto=#{proto} same_origin=#{same_origin} would_reject=#{!same_origin} " \
        "warden=#{warden_present} warden_user=#{warden_user.inspect} session_user=#{session_key.inspect} " \
        "diag=#{session_diag.inspect}"
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
