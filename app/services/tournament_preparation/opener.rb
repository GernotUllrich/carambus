# frozen_string_literal: true

# Phase 42 (Re-Plan-Spike, 2026-06-16) — `cc_prepare_tournament`.
#
# Dünner Wrapper um den OFFIZIELLEN Sync-Pfad
#   Version.update_from_carambus_api(update_tournament_from_cc: tournament.id)
# (siehe app/models/version.rb:231 — opts-Variante triggert auf Authority ein
# objekt-gezieltes Re-Scrape und appliziert die Versions-Records lokal in einer
# Transaktion; synchron, sofort-Antwort). KEIN direkter CC-Touch hier.
# [[project_version_update_object_scoped_rescrape]]
#
# Aufruf: `TournamentPreparation::Opener.call(tournament:)` → Hash
#
# Return-Schlüssel:
#   :ok                 — Boolean
#   :tournament_name    — String (oder nil bei Frühabbruch)
#   :status             — Hash mit aktuellem DB-Stand nach dem Sync
#   :preparation_url    — absolute Carambus-Web-URL auf finalize_modus
#   :reason             — Symbol bei !ok (:tournament_invalid /
#                         :no_authority_configured / :sync_failed)
#   :error              — String bei :sync_failed (rescue-Message)
#
# Hinweis: Bei :sync_failed wird die preparation_url trotzdem mitgegeben —
# der Sportwart kann manuell weitermachen (AC-3).
class TournamentPreparation::Opener
  def self.call(tournament:)
    new(tournament: tournament).call
  end

  def initialize(tournament:)
    @tournament = tournament
  end

  def call
    return result(reason: :tournament_invalid) if @tournament.nil? || @tournament.tournament_cc.nil?

    if Carambus.config.carambus_api_url.blank?
      return result(
        reason: :no_authority_configured,
        tournament_name: @tournament.title,
        preparation_url: build_preparation_url
      )
    end

    begin
      Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id)
    rescue => e
      Rails.logger.warn "[TournamentPreparation::Opener] sync failed: #{e.class}: #{e.message}"
      return result(
        reason: :sync_failed,
        tournament_name: @tournament.title,
        preparation_url: build_preparation_url,
        error: e.message
      )
    end

    @tournament.reload

    result(
      ok: true,
      tournament_name: @tournament.title,
      status: build_status,
      preparation_url: build_preparation_url
    )
  end

  private

  def build_status
    {
      tournament_cc_status: @tournament.tournament_cc&.status,
      tournament_state: @tournament.state,
      plan_chosen: @tournament.tournament_plan.present?,
      seedings_count: @tournament.seedings.count,
      games_count: @tournament.games.count
    }
  end

  # DEV-42-NEU-B (Live-Test 2026-06-16): Einstiegspunkt ist die Turnier-Show-Seite
  # (tournament_path = der Vorbereitungs-Wizard), NICHT finalize_modus. Dort
  # finalisiert der Sportwart zuerst die Setzliste (aus Einladung ODER durch Edit
  # der Teilnehmerliste, Wizard-Schritte 2/3) — erst danach folgen Modus
  # (finalize_modus) und TurnierMonitor-Start.
  def build_preparation_url
    Rails.application.routes.url_helpers.tournament_url(
      @tournament, host: web_host
    )
  rescue => e
    Rails.logger.warn "[TournamentPreparation::Opener] URL build failed: #{e.class}: #{e.message}"
    nil
  end

  def web_host
    Carambus.config.try(:carambus_domain).presence ||
      Rails.application.config.action_mailer&.default_url_options&.[](:host).presence ||
      "localhost:3007"
  end

  def result(**attrs)
    {
      ok: false,
      tournament_name: nil,
      status: nil,
      preparation_url: nil,
      reason: nil,
      error: nil
    }.merge(attrs)
  end
end
