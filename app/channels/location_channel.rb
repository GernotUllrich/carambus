class LocationChannel < ApplicationCable::Channel
  def subscribed
    stream_from "location-stream"
    Rails.logger.info "LocationChannel subscribed"
  end

  def unsubscribed
    Rails.logger.info "LocationChannel unsubscribed"
    # Any cleanup needed when channel is unsubscribed
  end
end
