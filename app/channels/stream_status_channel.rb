# frozen_string_literal: true

# ActionCable channel for real-time stream status updates
class StreamStatusChannel < ApplicationCable::Channel
  def subscribed
    stream_from "stream_status"
    
    # Send initial status for all streams
    StreamConfiguration.all.each do |config|
      transmit({
        stream_id: config.id,
        status: config.status,
        last_started_at: config.last_started_at&.iso8601,
        error_message: config.error_message
      })
    end
  end

  def unsubscribed
    stop_all_streams
  end

  # Client can request health check for specific stream
  def check_health(data)
    config = StreamConfiguration.find_by(id: data['stream_id'])
    return unless config

    # Trigger health check job
    StreamHealthJob.perform_later(config.id)
  end
end



