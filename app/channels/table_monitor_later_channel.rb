class TableMonitorLaterChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream-later"
    Rails.logger.info "TableMonitorLaterChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "TableMonitorLaterChannel unsubscribed"
  end
end
