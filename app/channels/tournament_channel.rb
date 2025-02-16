class TournamentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "tournament-stream"
    Rails.logger.info "TournamentChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "TournamentChannel unsubscribed"
    # Any cleanup needed when channel is unsubscribed
  end
end
