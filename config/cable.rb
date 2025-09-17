# frozen_string_literal: true

# ActionCable configuration
ActionCable.server.config.disable_request_forgery_protection = true
ActionCable.server.config.allow_same_origin_as_host = true

# Force ActionCable to use HTTP instead of HTTPS
if Rails.env.production?
  ActionCable.server.config.url = "ws://192.168.178.107:82/cable"
end
