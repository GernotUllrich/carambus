class TableMonitorClockChannel < ApplicationCable::Channel
  def subscribed
    # Reject subscriptions on API Server (no scoreboards running)
    # Local servers are identified by having a carambus_api_url configured
    unless ApplicationRecord.local_server?
      Rails.logger.info "TableMonitorClockChannel subscription rejected (API Server - no scoreboards)"
      reject
      return
    end

    stream_from "table-monitor-clock-stream"
    Rails.logger.info "TableMonitorClockChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "TableMonitorClockChannel unsubscribed"
  end
end
