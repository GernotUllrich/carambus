class TableMonitorLaterChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream-later"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
