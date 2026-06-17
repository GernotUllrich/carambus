# frozen_string_literal: true

# Phase 43 (Path-B-Spike) — Chat-Brücke zu carambus_app.
#
# Baut einen vorverbindenden App-Deep-Link für die externe Turnier-App
# (`carambus_app`). Die App ist autark (generiert ihr eigenes Turnier, nimmt von
# Carambus nur die Teilnehmerliste über den external_tournament/seeding-Endpoint).
# Der Link füllt die App-Verbindung vor — der Turnierleiter muss dann nur noch das
# Service-Account-Passwort eingeben (D-43-7: Passwort NIE im Link).
#
# Form: "<app_base>?cb_region=<REGION>&cb_tournament_cc_id=<ccid>[&cb_base_url=<api>]"
#
# DEV-43-C (Live-Test 2026-06-16): Same-Origin-Default. Wird die App unter /app/
# vom selben Local-Server ausgeliefert wie Chat/API (User-Setup), genügt ein
# RELATIVER Link "/app/?…" — der Browser löst ihn gegen den Chat-Origin (= Local-
# Server) auf, und die App leitet ihre API-base_url aus window.location.origin ab.
# Damit ist KEINE LAN-IP-Konfiguration nötig. Nur wenn die App cross-origin läuft
# (z.B. eigener Port 8123), setzt der Deploy explizit:
#   - tournament_app_url        — absolute App-URL (überschreibt den /app/-Default)
#   - external_app_api_base_url — absolute LAN-URL dieses Servers (→ cb_base_url)
class TournamentPreparation::AppLinkBuilder
  APP_BASE_DEFAULT = "/app/" # relativ, Same-Origin (DEV-43-C)

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

    # cb_tournament_id = globaler DB-PK (eindeutig); die App löst damit deterministisch
    # auf und umgeht die region-scoped cc_id-Ambiguität (HANDOFF tournament-id-ambiguity).
    # cb_tournament_cc_id bleibt als Fallback/Anzeige erhalten.
    query = {cb_region: region, cb_tournament_id: @tournament.id, cb_tournament_cc_id: cc_id}
    # cb_base_url nur im cross-origin-Fall (explizit konfiguriert). Fehlt es, leitet
    # die App ihre API-Basis aus window.location.origin ab (Same-Origin).
    api = explicit_api_base
    query[:cb_base_url] = api if api

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
    Carambus.config.try(:tournament_app_url).presence || APP_BASE_DEFAULT
  end

  # nil bei Same-Origin (Default) — dann KEIN cb_base_url im Link. Nur ein explizit
  # gesetzter external_app_api_base_url (cross-origin Deploy) erzeugt cb_base_url.
  def explicit_api_base
    Carambus.config.try(:external_app_api_base_url).presence
  end
end
