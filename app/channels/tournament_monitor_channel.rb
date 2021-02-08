class TournamentMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "tournament-monitor-stream"
    Rails.logger.info "TournamentMonitorChannel subscribed"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "TournamentMonitorChannel unsubscribed"
  end
end
