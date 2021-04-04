class NumberPadChannel < ApplicationCable::Channel
  def subscribed
      stream_from "number-pad-stream"
    Rails.logger.info "NumberPadChannel subscribed"
  end

  def receive(data)
    puts data["message"]
    ActionCable.server.broadcast("test", "ActionCable is connected")
  end

  def unsubscribed
    Rails.logger.info "NumberPadChannel unsubscribed"
    # Any cleanup needed when channel is unsubscribed
  end
end
