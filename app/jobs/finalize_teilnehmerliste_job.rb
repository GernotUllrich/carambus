# frozen_string_literal: true

# Plan 44-03 (Phase 44): Asynchroner, wiederholbarer Push der Meldeliste-Finalisierung
# (releaseMeldeliste) in die ClubCloud, wenn der TL die Teilnehmerliste abschließt.
# Lokaler State bleibt führend (D-44-3) — bei endgültigem Fehlschlag wird protokolliert.
class FinalizeTeilnehmerlisteJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
    wait: 10.seconds, attempts: 3 do |_job, error|
    Rails.logger.warn(
      "[FinalizeTeilnehmerlisteJob] CC nach Retries unerreichbar (lokaler Stand bleibt führend): " \
      "#{error.class}: #{error.message}"
    )
  end

  # Controller-Seam: enqueued den Finalize-Push nur, wenn das Turnier CC-verknüpft ist
  # UND eine meldeliste_cc_id hat (sonst kein CC-Bezug / nichts zu finalisieren).
  def self.enqueue_for(tournament:, acting_user:)
    return unless tournament&.tournament_cc&.meldeliste_cc_id.present?

    perform_later(tournament_id: tournament.id, acting_user_id: acting_user&.id)
  end

  def perform(tournament_id:, acting_user_id:)
    tournament = Tournament.find(tournament_id)
    acting_user = User.find_by(id: acting_user_id)

    result = Tournament::CcSync::FinalizePush.call(tournament: tournament, acting_user: acting_user)

    if result[:status] == :error
      Rails.logger.warn(
        "[FinalizeTeilnehmerlisteJob] CC-Finalize fehlgeschlagen (lokaler Stand bleibt führend) " \
        "tournament=#{tournament_id}: #{result[:reason]}"
      )
    else
      Rails.logger.info("[FinalizeTeilnehmerlisteJob] #{result[:status]} tournament=#{tournament_id}")
    end
    result
  end
end
