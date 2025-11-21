class TableMonitorChannel < ApplicationCable::Channel
  def subscribed
    stream_from "table-monitor-stream"
    Rails.logger.info "[TableMonitorChannel] Subscribed: connection=#{connection.connection_token}"
  end

  def unsubscribed
    Rails.logger.info "[TableMonitorChannel] Unsubscribed: connection=#{connection.connection_token}"
  end

  # Client can send heartbeat to confirm it's alive
  def heartbeat(data)
    Rails.logger.debug "[TableMonitorChannel] Heartbeat from #{connection.connection_token}"
    transmit({
      type: "heartbeat_ack",
      server_time: Time.current.to_i
    })
  end

  # Server can send force reconnect to specific clients or all
  def self.force_reconnect(reason: "server_request")
    ActionCable.server.broadcast("table-monitor-stream", {
      type: "force_reconnect",
      reason: reason,
      timestamp: Time.current.to_i
    })
  end
end
