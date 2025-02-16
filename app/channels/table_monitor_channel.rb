class TableMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream"
    Rails.logger.info "TableMonitorChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "TableMonitorChannel unsubscribed"
  end
end
