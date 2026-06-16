# frozen_string_literal: true

# Phase 43 (Path-B-Spike) — Chat-Brücke zu carambus_app.
#
# Baut einen vorverbindenden App-Deep-Link für die externe Turnier-App
# (`carambus_app`). Die App ist autark (generiert ihr eigenes Turnier, nimmt von
# Carambus nur die Teilnehmerliste über den external_tournament/seeding-Endpoint).
# Der Link füllt das App-Verbindungs-Modal vor — der Turnierleiter muss dann nur
# noch das Service-Account-Passwort eingeben (D-43-7: Passwort NIE im Link).
#
# Form: "<app_base>?cb_base_url=<server_api>&cb_region=<REGION>&cb_tournament_cc_id=<ccid>"
#
# Beide Hosts sind LAN-/Deploy-spezifisch (DEV-43-A) und kommen aus Carambus.config
# mit defensivem Fallback + Log-Warnung — die konkreten Werte setzt der Deploy, nicht
# das Repo:
#   - tournament_app_url        — Host, unter dem carambus_app ausgeliefert wird
#   - external_app_api_base_url — LAN-URL dieses Local-Servers für die App-API
class TournamentPreparation::AppLinkBuilder
  APP_BASE_FALLBACK = "http://localhost:8123/"
  API_BASE_FALLBACK = "http://localhost:3007"

  def self.call(tournament:, server_context: nil)
    new(tournament: tournament, server_context: server_context).call
  end

  def initialize(tournament:, server_context:)
    @tournament = tournament
    @server_context = server_context
  end

  def call
    return {ok: false, reason: :tournament_invalid} if @tournament.nil? || @tournament.tournament_cc.nil?

    region = (@tournament.tournament_cc.context.presence || @server_context&.dig(:cc_region)).to_s.upcase
    cc_id = @tournament.tournament_cc.cc_id

    query = {
      cb_base_url: api_base,
      cb_region: region,
      cb_tournament_cc_id: cc_id
    }
    {ok: true, app_link: "#{app_base_with_sep}#{URI.encode_www_form(query)}"}
  rescue => e
    Rails.logger.warn "[TournamentPreparation::AppLinkBuilder] #{e.class}: #{e.message}"
    {ok: false, reason: :link_build_failed, error: e.message}
  end

  private

  # app_base normalisiert auf genau einen Query-Trenner: hat die Basis schon "?",
  # hängen wir mit "&" an, sonst mit "?".
  def app_base_with_sep
    base = app_base
    base.include?("?") ? "#{base}&" : "#{base}?"
  end

  def app_base
    val = Carambus.config.try(:tournament_app_url).presence
    return val if val
    Rails.logger.warn "[AppLinkBuilder] Carambus.config.tournament_app_url nicht gesetzt — Fallback #{APP_BASE_FALLBACK}"
    APP_BASE_FALLBACK
  end

  def api_base
    val = Carambus.config.try(:external_app_api_base_url).presence
    return val if val
    domain = Carambus.config.try(:carambus_domain).presence
    if domain
      domain.start_with?("http") ? domain : "http://#{domain}"
    else
      Rails.logger.warn "[AppLinkBuilder] keine App-API-Base-URL konfiguriert — Fallback #{API_BASE_FALLBACK}"
      API_BASE_FALLBACK
    end
  end
end
