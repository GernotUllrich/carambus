class TournamentMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "tournament-monitor-stream"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
