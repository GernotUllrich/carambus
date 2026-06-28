# frozen_string_literal: true

# Phase 48-05 — Chat-Brücke zu carambus_app (Liga-Spieltag).
#
# Baut einen vorverbindenden App-Deep-Link für das carambus_app-"spieltag"-Schema. Die App ist
# autark (fährt den Spieltag über die external_tournament/party*-Endpoints, Plan 48-04) und nimmt
# von Carambus nur Daten. Der Link füllt die App-Verbindung + den Party-Kontext vor — der
# Sportwart/TL gibt dann nur noch das Service-Account-Passwort ein (D-43-7: Passwort NIE im Link).
#
# Form: "<app_base>?cb_region=<REGION>&cb_party_id=<id>&cb_party_cc_id=<ccid>[&cb_base_url=<api>]"
#
# Gespiegelt von TournamentPreparation::AppLinkBuilder (Phase 43). DEV-43-C Same-Origin-Default:
# wird die App unter /app/ vom selben Local-Server ausgeliefert, genügt ein RELATIVER Link "/app/?…"
# (Browser löst gegen den Chat-Origin auf, App leitet ihre API-base aus window.location.origin ab).
# Nur cross-origin (eigener Port) setzt der Deploy tournament_app_url + external_app_api_base_url.
class PartyPreparation::AppLinkBuilder
  APP_BASE_DEFAULT = "/app/" # relativ, Same-Origin (DEV-43-C)

  def self.call(party:, server_context: nil)
    new(party: party, server_context: server_context).call
  end

  def initialize(party:, server_context:)
    @party = party
    @server_context = server_context
  end

  def call
    return {ok: false, reason: :party_invalid} if @party.nil?

    reg = region
    return {ok: false, reason: :region_unresolved} if reg.blank?

    # cb_party_id = globaler DB-PK (eindeutig); die App löst damit deterministisch auf und umgeht
    # die region-scoped cc_id-Ambiguität. cb_party_cc_id bleibt als Fallback/Anzeige erhalten.
    query = {cb_region: reg, cb_party_id: @party.id, cb_party_cc_id: @party.cc_id}
    # cb_base_url nur im cross-origin-Fall (explizit konfiguriert). Fehlt es, leitet die App ihre
    # API-Basis aus window.location.origin ab (Same-Origin).
    api = explicit_api_base
    query[:cb_base_url] = api if api

    {ok: true, app_link: "#{app_base_with_sep}#{URI.encode_www_form(query)}"}
  rescue => e
    Rails.logger.warn "[PartyPreparation::AppLinkBuilder] #{e.class}: #{e.message}"
    {ok: false, reason: :link_build_failed, error: e.message}
  end

  private

  # Party-Region läuft über league.organizer (Region), nicht party.region_id (K-4).
  # Fallback auf den server_context (cc_region) wie beim Turnier-Builder.
  def region
    org = @party.league&.organizer
    (org.is_a?(Region) ? org.shortname : @server_context&.dig(:cc_region)).to_s.upcase
  end

  # app_base normalisiert auf genau einen Query-Trenner.
  def app_base_with_sep
    base = app_base
    base.include?("?") ? "#{base}&" : "#{base}?"
  end

  def app_base
    Carambus.config.try(:tournament_app_url).presence || APP_BASE_DEFAULT
  end

  # nil bei Same-Origin (Default) — dann KEIN cb_base_url im Link.
  def explicit_api_base
    Carambus.config.try(:external_app_api_base_url).presence
  end
end
