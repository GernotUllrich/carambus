class TournamentChannel < ApplicationCable::Channel
  def subscribed
    tournament_id = params[:tournament_id]
    if tournament_id.present?
      stream_from "tournament-stream-#{tournament_id}"
      Rails.logger.info "TournamentChannel subscribed to tournament #{tournament_id}"
    else
      stream_from "tournament-stream"
      Rails.logger.info "TournamentChannel subscribed"
    end
  end

  def unsubscribed
    Rails.logger.info "TournamentChannel unsubscribed"
    # Any cleanup needed when channel is unsubscribed
  end
end
