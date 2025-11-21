# frozen_string_literal: true

# Channel for location-specific updates (table_scores view, teasers)
# Separate from TableMonitorChannel to avoid sending unnecessary updates
# to scoreboard views that don't need teaser updates
class LocationChannel < ApplicationCable::Channel
  def subscribed
    location_id = params[:location_id]
    stream_from "location-#{location_id}-stream"
    Rails.logger.info "[LocationChannel] Subscribed to location-#{location_id}-stream: connection=#{connection.connection_token}"
  end

  def unsubscribed
    Rails.logger.info "[LocationChannel] Unsubscribed: connection=#{connection.connection_token}"
  end

  # Client can send heartbeat to confirm it's alive
  def heartbeat(data)
    Rails.logger.debug "[LocationChannel] Heartbeat from #{connection.connection_token}"
    transmit({
      type: "heartbeat_ack",
      server_time: Time.current.to_i
    })
  end
end
