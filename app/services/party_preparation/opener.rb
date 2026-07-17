# frozen_string_literal: true

# Phase 47-03 — Thin-Bridge zum Mannschaftskampf-Spieltag (PartyMonitor).
#
# Gespiegelt von TournamentPreparation::Opener: öffnet (find-or-create) den
# PartyMonitor einer Party (parties_controller#party_monitor-Logik; PartyMonitor
# trägt ApiProtector → nur auf dem Local-Server erzeugbar) und liefert eine
# absolute Carambus-Web-URL zum interaktiven Spielen + den aktuellen DB-Stand.
# KEIN ClubCloud-Touch, kein armed — idempotent (vorhandener Monitor wird
# wiederverwendet).
#
# Aufruf: `PartyPreparation::Opener.call(party:)` → Hash
#
# Return-Schlüssel:
#   :ok          — Boolean
#   :party_name  — String (oder nil bei Frühabbruch)
#   :status      — Hash {party_monitor_state, intermediate_result, seedings_a, seedings_b}
#   :web_url     — absolute Carambus-Web-URL (PartyMonitor bzw. Party-Member-Route)
#   :reason      — Symbol bei !ok (:party_invalid / :not_local_server / :open_failed)
#   :error       — String bei :open_failed (rescue-Message)
#
# Hinweis: Bei :not_local_server / :open_failed wird die web_url trotzdem
# mitgegeben (party_monitor_party_url — die Member-Route macht den find-or-create
# serverseitig beim Klick).
class PartyPreparation::Opener
  def self.call(party:)
    new(party: party).call
  end

  def initialize(party:)
    @party = party
  end

  def call
    return result(reason: :party_invalid) if @party.nil?

    unless ApplicationRecord.local_server?
      return result(
        reason: :not_local_server,
        party_name: @party.name,
        web_url: build_party_url
      )
    end

    pm = @party.party_monitor
    if pm.nil?
      begin
        pm = @party.create_party_monitor
      rescue => e
        Rails.logger.warn "[PartyPreparation::Opener] open failed: #{e.class}: #{e.message}"
        return result(
          reason: :open_failed,
          party_name: @party.name,
          web_url: build_party_url,
          error: e.message
        )
      end
    end

    result(
      ok: true,
      party_name: @party.name,
      status: build_status(pm),
      web_url: build_monitor_url(pm)
    )
  end

  private

  def build_status(pm)
    {
      party_monitor_state: pm.state,
      intermediate_result: @party.intermediate_result,
      seedings_a: @party.seedings.where(role: "team_a").count,
      seedings_b: @party.seedings.where(role: "team_b").count
    }
  end

  def build_monitor_url(pm)
    Rails.application.routes.url_helpers.party_monitor_url(pm, host: web_host)
  rescue => e
    Rails.logger.warn "[PartyPreparation::Opener] monitor URL build failed: #{e.class}: #{e.message}"
    build_party_url
  end

  def build_party_url
    Rails.application.routes.url_helpers.party_monitor_party_url(@party, host: web_host)
  rescue => e
    Rails.logger.warn "[PartyPreparation::Opener] party URL build failed: #{e.class}: #{e.message}"
    nil
  end

  # Wie TournamentPreparation::Opener#web_host.
  def web_host
    Carambus.config.try(:carambus_domain).presence ||
      Rails.application.config.action_mailer&.default_url_options&.[](:host).presence ||
      "localhost:3007"
  end

  def result(**attrs)
    {
      ok: false,
      party_name: nil,
      status: nil,
      web_url: nil,
      reason: nil,
      error: nil
    }.merge(attrs)
  end
end
