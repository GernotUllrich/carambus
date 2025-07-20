# frozen_string_literal: true

# Development environment for API mode
Rails.application.configure do
  # Inherit from development
  config = Rails.application.config_for(:development)
  config.each { |key, value| config.send("#{key}=", value) }

  # API mode specific settings
  config.carambus_api_url = "https://api.carambus.de/"
  config.carambus_testing_mode = false
  config.context = "API"
  
  # Use different port for API mode
  config.server_port = 3000
  
  # Use different database
  config.database_configuration = {
    development: {
      adapter: "postgresql",
      encoding: "unicode",
      pool: 5,
      database: "carambus_api_development",
      username: ENV.fetch("DB_USERNAME", nil),
      password: ENV.fetch("DB_PASSWORD", nil),
      host: ENV.fetch("DB_HOST", "localhost")
    }
  }
  
  # Different log file
  config.log_file = "log/development-api.log"
  
  # Different cache store
  config.cache_store = :memory_store, { size: 128.megabytes }
  
  # Different session store
  config.session_store :cookie_store, key: '_carambus_api_session'
  
  # Different asset host (if needed)
  config.asset_host = nil
  
  # Different mailer settings
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  
  # Different WebSocket settings
  config.action_cable.url = "ws://localhost:3000/cable"
  config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
  
  # Different Redis settings (if using Redis)
  config.redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/0')
  
  # Different queue adapter
  config.active_job.queue_adapter = :async
  
  # Different storage settings
  config.active_storage.service = :local
  
  # Different credentials
  config.credentials.content_path = Rails.root.join("config", "credentials", "development-api.yml.enc")
  
  # Different log level
  config.log_level = :info
  
  # Different log tags
  config.log_tags = [:request_id, :remote_ip, :mode]
  
  # Different cache control
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{1.day.to_i}"
  }
  
  # Different asset compilation
  config.assets.debug = false
  config.assets.quiet = false
  
  # Different error pages
  config.consider_all_requests_local = true
  
  # Different performance monitoring
  config.rack_mini_profiler = false if defined?(Rack::MiniProfiler)
end 