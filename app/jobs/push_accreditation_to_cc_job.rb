# frozen_string_literal: true

# Plan 44-01 (Phase 44): Asynchroner, wiederholbarer Push einer TL-Akkreditierungs-Änderung
# in die ClubCloud. Lokaler State bleibt führend (D-44-3) — bei endgültigem Fehlschlag wird
# protokolliert, NICHT zurückgerollt.
class PushAccreditationToCcJob < ApplicationJob
  queue_as :default

  # Record gelöscht (Turnier/Spieler verschwunden) → kein Retry.
  discard_on ActiveRecord::RecordNotFound

  # Transiente CC-/Netzwerkfehler → begrenzt wiederholen; danach loggen (lokaler Stand führt).
  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError,
    wait: 10.seconds, attempts: 3 do |_job, error|
    Rails.logger.warn(
      "[PushAccreditationToCcJob] CC nach Retries unerreichbar (lokaler Stand bleibt führend): " \
      "#{error.class}: #{error.message}"
    )
  end

  # Reflex-Seam (testbar ohne StimulusReflex-Stack): enqueued den Push nur, wenn das Turnier
  # CC-verknüpft ist (sonst kein CC-Bezug). target: :accredit | :deaccredit.
  def self.enqueue_for(tournament:, player:, target:, acting_user:)
    return unless tournament&.tournament_cc

    perform_later(
      tournament_id: tournament.id,
      player_id: player.id,
      acting_user_id: acting_user&.id,
      target: target.to_s
    )
  end

  def perform(tournament_id:, player_id:, acting_user_id:, target:)
    tournament = Tournament.find(tournament_id)
    player = Player.find(player_id)
    acting_user = User.find_by(id: acting_user_id)

    result = Tournament::CcSync::AccreditationPush.call(
      tournament: tournament, player: player, target: target.to_sym, acting_user: acting_user
    )

    if result[:status] == :error
      Rails.logger.warn(
        "[PushAccreditationToCcJob] CC-Push fehlgeschlagen (lokaler Stand bleibt führend) " \
        "tournament=#{tournament_id} player=#{player_id} target=#{target}: #{result[:reason]}"
      )
    else
      Rails.logger.info(
        "[PushAccreditationToCcJob] #{result[:status]} tournament=#{tournament_id} " \
        "player=#{player_id} target=#{target}"
      )
    end
    result
  end
end
