class TournamentMonitorChannel < ApplicationCable::Channel
  def subscribed
    # Reject subscriptions on API Server (no tournament monitors running)
    # Local servers are identified by having a carambus_api_url configured
    unless ApplicationRecord.local_server?
      Rails.logger.info "TournamentMonitorChannel subscription rejected (API Server - no tournament monitors)"
      reject
      return
    end

    stream_from "tournament-monitor-stream"
    Rails.logger.info "TournamentMonitorChannel subscribed"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    Rails.logger.info "TournamentMonitorChannel unsubscribed"
  end
end
