# frozen_string_literal: true

# Plan 36-03: Gegenstueck zu EntryListSyncJob (29-06 ①), nur fuer SPIELE — stoesst die Authority an,
# die Ergebniszeilen des Region Servers frisch einzulesen (get_updates?import_game_results=…), und
# holt die entstandenen globalen Versionen zurueck.
#
# WARUM ES IHN BRAUCHTE (live aufgefallen 2026-07-29): Der Authority-Empfang existiert seit Plan
# 32-10 (versions_controller.rb:112), aber NIEMAND rief ihn. `import_game_results` wurde
# ausschliesslich vom Rake-Task `region_server:import_game_results` gesendet — es gab weder einen
# Job noch einen Cron-Eintrag. Erfasste oder gepushte Spiele blieben deshalb auf dem Region Server
# liegen, bis jemand von Hand nachhalf. Exakt dieselbe Luecke, die Plan 36-02 fuer die MELDUNGEN
# geschlossen hat.
#
# BEWUSST EIN EIGENER JOB statt einer gemeinsamen Basisklasse mit EntryListSyncJob: die beiden
# unterscheiden sich nur im Parameternamen, teilen aber sonst nichts fachlich — Meldungen und
# Ergebnisse sind getrennte Betriebswege mit eigenem Lebenszyklus. Eine Basisklasse haette sie
# gekoppelt, ohne mehr zu sparen als ein Dutzend Zeilen.
#
# FEHLERTOLERANT wie das Vorbild: der lokale Stand fuehrt. Erreicht der Job die Authority nicht,
# wird protokolliert — NICHT zurueckgerollt. Das erfasste Spiel bleibt gueltig, der naechste
# Anstoss (oder ein Rake-Lauf) holt es nach. Deshalb im Hintergrund: die Ergebniserfassung darf
# nicht am Netz-Roundtrip haengen.
class GameResultSyncJob < ApplicationJob
  queue_as :default

  # Turnier/Region zwischenzeitlich weg → kein Retry.
  discard_on ActiveRecord::RecordNotFound

  # Transiente Netzfehler → begrenzt wiederholen; danach loggen (lokaler Stand fuehrt).
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
    wait: 10.seconds, attempts: 3 do |_job, error|
    Rails.logger.warn(
      "[GameResultSyncJob] Authority nach Retries unerreichbar (lokaler Stand bleibt führend): " \
      "#{error.class}: #{error.message}"
    )
  end

  # Dieselben Guards wie EntryListSyncJob: nur auf einem LOKALEN Server (die Authority stoesst sich
  # nicht selbst an), nur fuer ein FREIGEGEBENES Turnier mit Region UND Saison.
  def self.enqueue_for(tournament:)
    return unless ApplicationRecord.local_server?
    return if tournament.nil? || tournament.draft?
    return if tournament.region_id.blank? || tournament.season_id.blank?

    perform_later(region_id: tournament.region_id, season_id: tournament.season_id)
  end

  def perform(region_id:, season_id:)
    Version.update_from_carambus_api(
      import_game_results: region_id, season_id: season_id, region_id: region_id
    )
    Rails.logger.info(
      "[GameResultSyncJob] Authority-Ingest angestoßen region=#{region_id} season=#{season_id}"
    )
  end
end
