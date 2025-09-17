# frozen_string_literal: true

# ActionCable configuration
ActionCable.server.config.disable_request_forgery_protection = true
ActionCable.server.config.allow_same_origin_as_host = true

# Configure logging based on environment
if Rails.env.production?
  # Disable ActionCable logging in production for performance
  ActionCable.server.config.logger = Logger.new(nil)
else
  # Enable ActionCable logging in development for debugging
  ActionCable.server.config.logger = Rails.logger
end
