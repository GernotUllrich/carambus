class TableMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
