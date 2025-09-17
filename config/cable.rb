# frozen_string_literal: true

# ActionCable configuration
ActionCable.server.config.disable_request_forgery_protection = true
ActionCable.server.config.allow_same_origin_as_host = true

# Configure pubsub adapter for ActionCable
Rails.application.configure do
  config.action_cable.mount_path = '/cable'
  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
  
  # Use async adapter for both development and production
  config.action_cable.adapter = :async
  
  # Set URL for production
  if Rails.env.production?
    config.action_cable.url = "ws://192.168.178.107:82/cable"
  end
end
