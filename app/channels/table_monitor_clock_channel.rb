class TableMonitorClockChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-clock-stream"
    Rails.logger.info "TableMonitorClockChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "TableMonitorClockChannel unsubscribed"
  end
end
