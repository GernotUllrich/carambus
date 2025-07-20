# frozen_string_literal: true

# Development environment for LOCAL mode
Rails.application.configure do
  # Inherit from development
  config = Rails.application.config_for(:development)
  config.each { |key, value| config.send("#{key}=", value) }

  # LOCAL mode specific settings
  config.carambus_api_url = nil  # Empty for local mode
  config.carambus_testing_mode = true
  config.context = "LOCAL"
  
  # Use different port for LOCAL mode
  config.server_port = 3001
  
  # Use different database
  config.database_configuration = {
    development: {
      adapter: "postgresql",
      encoding: "unicode",
      pool: 5,
      database: "carambus_local_development",
      username: ENV.fetch("DB_USERNAME", nil),
      password: ENV.fetch("DB_PASSWORD", nil),
      host: ENV.fetch("DB_HOST", "localhost")
    }
  }
  
  # Different log file
  config.log_file = "log/development-local.log"
  
  # Different cache store
  config.cache_store = :memory_store, { size: 64.megabytes }
  
  # Different session store
  config.session_store :cookie_store, key: '_carambus_local_session'
  
  # Different asset host (if needed)
  config.asset_host = nil
  
  # Different mailer settings
  config.action_mailer.default_url_options = { host: 'localhost', port: 3001 }
  
  # Different WebSocket settings
  config.action_cable.url = "ws://localhost:3001/cable"
  config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
  
  # Different Redis settings (if using Redis)
  config.redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  
  # Different queue adapter
  config.active_job.queue_adapter = :async
  
  # Different storage settings
  config.active_storage.service = :local
  
  # Different credentials
  config.credentials.content_path = Rails.root.join("config", "credentials", "development-local.yml.enc")
  
  # Different log level
  config.log_level = :debug
  
  # Different log tags
  config.log_tags = [:request_id, :remote_ip, :mode]
  
  # Different cache control
  config.public_file_server.headers = {
    'Cache-Control' => "public, max-age=#{2.days.to_i}"
  }
  
  # Different asset compilation
  config.assets.debug = true
  config.assets.quiet = true
  
  # Different error pages
  config.consider_all_requests_local = true
  
  # Different performance monitoring
  config.rack_mini_profiler = true if defined?(Rack::MiniProfiler)
end 