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
      # Bewusst NACH find_verified_user: nur so laesst sich die Verbindung einem
      # Client-Typ zuordnen (Scoreboard/User/anonym). Zulaessig, weil anonyme
      # Verbindungen zugelassen werden und connect hier nie vorher abbricht.
      log_origin_probe
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

    # TEMPORAER — Messung fuer die Origin-Haertung.
    # Siehe .planning/tasks/TASK-actioncable-origin-hardening.md, Abschnitt 4a.
    #
    # Auf der Authority (api.carambus.de) wurde bereits gemessen: would_reject=true kam
    # 0-mal vor. Dort laufen aber WEDER Scoreboards NOCH OBS-Overlays — also genau die
    # Clients, die den Task riskant machen (Risiko R4: Clients ohne Origin-Header werden
    # nach der Umstellung abgewiesen, und eine Whitelist hilft dort nicht, weil sie gegen
    # HTTP_ORIGIN matcht). Diese Probe schliesst diese Luecke auf einem lokalen Server.
    #
    # Dry-Run: bildet die Pruefung aus ActionCable::Connection::Base#allow_request_origin?
    # fuer den ZIELZUSTAND nach (Forgery-Protection aktiv, allowed_request_origins leer,
    # allow_same_origin_as_host = true). KEIN Verhaltenswechsel.
    #
    # Bewusst ueber Rails.logger statt ueber den Cable-Logger: letzterer ist in Production
    # auf Logger.new(nil) gesetzt (config/initializers/action_cable.rb) und wuerde die
    # Zeilen verschlucken.
    #
    # Nach der Auswertung wieder entfernen — dieser Branch wird NICHT nach master gemergt.
    def log_origin_probe
      origin = env["HTTP_ORIGIN"]
      host = env["HTTP_HOST"]
      proto = request.ssl? ? "https" : "http"
      same_origin = origin == "#{proto}://#{host}"

      Rails.logger.info(
        "[ActionCable][origin-probe] client=#{client_kind} origin=#{origin.inspect} " \
        "host=#{host.inspect} proto=#{proto} same_origin=#{same_origin} " \
        "would_reject=#{!same_origin} ua=#{env["HTTP_USER_AGENT"].to_s[0, 120].inspect}"
      )
    rescue => e
      # Die Probe darf den Verbindungsaufbau unter keinen Umstaenden verhindern.
      Rails.logger.warn "[ActionCable][origin-probe] fehlgeschlagen: #{e.class}: #{e.message}"
    end

    # Ordnet die Verbindung einem Client-Typ zu. Das ist der Kern dieser Messung: ein
    # would_reject=true muss dem verursachenden Client zuzuordnen sein, sonst weiss man
    # hinterher nicht, ob ein Scoreboard oder nur ein Browser-Tab betroffen waere.
    def client_kind
      return "anonymous" if current_user.nil?
      (current_user.email == "scoreboard@carambus.de") ? "scoreboard" : "user"
    rescue => e
      "raised:#{e.class}"
    end

    def assign_connection_token
      self.connection_token = SecureRandom.uuid
      logger.add_tags "Connection #{connection_token}"
    end
  end
end
