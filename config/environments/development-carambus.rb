# frozen_string_literal: true

# Development environment for carambus folder (testing local_server functionality)
Rails.application.configure do
  # Inherit from development
  config = Rails.application.config_for(:development)
  config.each { |key, value| config.send("#{key}=", value) }

  # Override specific settings for carambus testing
  config.carambus_api_url = nil  # This makes local_server? return false
  
  # Additional carambus-specific settings
  config.carambus_testing_mode = true
  
  # Logging
  config.log_level = :debug
  config.log_tags = [:request_id]
  
  # Enable/disable caching
  config.action_controller.perform_caching = false
  config.cache_store = :null_store
  
  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caches = false
  
  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log
  
  # Raise an error on page load if there are pending migrations
  config.active_record.migration_error = :page_load
  
  # Highlight code that triggered database queries in logs
  config.active_record.verbose_query_logs = true
  
  # Debug mode disables concatenation and preprocessing of assets
  config.assets.debug = true
  
  # Suppress logger output for asset requests
  config.assets.quiet = true
  
  # Raises error for missing translations
  config.i18n.raise_on_missing_translations = true
  
  # Annotate rendered view with file names
  config.action_view.annotate_rendered_view_with_filenames = true
  
  # Use an evented file watcher to asynchronously detect changes in source code
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end 