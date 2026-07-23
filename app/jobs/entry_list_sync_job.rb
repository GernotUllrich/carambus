# frozen_string_literal: true

# Plan 29-06 (CC-loser Short-Circuit ①): stoesst nach der FREIGABE eines Turniers auf dem Region
# Server die Authority an, die Meldeliste frisch einzulesen (get_updates?import_entry_list=…), und
# holt die entstandenen globalen Versionen zurueck. So ist die Freigabe sofort wirksam, statt bis
# zum stuendlichen Cron zu warten.
#
# FEHLERTOLERANT NACH DEM ResultReporter-MUSTER: der lokale Stand (das freigegebene Turnier) bleibt
# fuehrend. Erreicht der Job die Authority nicht, wird protokolliert — NICHT zurueckgerollt. Der
# managende Local Server holt die Liste ohnehin on-demand frisch (Baustein ③), und der Cron zieht
# nach. Deshalb im Hintergrund (perform_later): die Freigabe-Aktion darf nicht am Netz-Roundtrip
# haengen.
class EntryListSyncJob < ApplicationJob
  queue_as :default

  # Turnier/Region zwischenzeitlich weg → kein Retry.
  discard_on ActiveRecord::RecordNotFound

  # Transiente Netzfehler → begrenzt wiederholen; danach loggen (lokaler Stand fuehrt).
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
    wait: 10.seconds, attempts: 3 do |_job, error|
    Rails.logger.warn(
      "[EntryListSyncJob] Authority nach Retries unerreichbar (lokaler Stand bleibt führend): " \
      "#{error.class}: #{error.message}"
    )
  end

  # Seam mit Guards: nur auf einem LOKALEN Server (die Authority stoesst sich nicht selbst an), nur
  # fuer ein FREIGEGEBENES (Nicht-Entwurf-)Turnier mit Region UND Saison.
  def self.enqueue_for(tournament:)
    return unless ApplicationRecord.local_server?
    return if tournament.nil? || tournament.draft?
    return if tournament.region_id.blank? || tournament.season_id.blank?

    perform_later(region_id: tournament.region_id, season_id: tournament.season_id)
  end

  def perform(region_id:, season_id:)
    Version.update_from_carambus_api(
      import_entry_list: region_id, season_id: season_id, region_id: region_id
    )
    Rails.logger.info(
      "[EntryListSyncJob] Authority-Ingest angestoßen region=#{region_id} season=#{season_id}"
    )
  end
end
