# frozen_string_literal: true

# Development environment for carambus folder (testing local_server functionality)
Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.
  
  # Code is not reloaded between requests.
  config.enable_reloading = true

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  config.action_controller.perform_caching = false
  config.action_controller.enable_fragment_cache_logging = true

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false
  config.action_mailer.perform_caching = false

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raise an error on page load if there are pending migrations.
  config.active_record.migration_error = :page_load

  # Highlight code that triggered database queries in logs.
  config.active_record.verbose_query_logs = true

  # Highlight code that enqueued background job in logs.
  config.active_job.verbose_enqueue_logs = true

  # Suppress logger output for asset requests.
  config.assets.quiet = true

  # Raises error for missing translations.
  config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  config.action_view.annotate_rendered_view_with_filenames = true

  # Uncomment if you wish to allow Action Cable access from any origin.
  # config.action_cable.disable_request_forgery_protection = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Override specific settings for carambus testing
  config.carambus_api_url = nil  # This makes local_server? return false
  
  # Additional carambus-specific settings
  config.carambus_testing_mode = true
  
  # Logging
  config.log_level = :debug
  config.log_tags = [:request_id]
  
  # Cache store
  config.cache_store = :null_store
  
  # Debug mode disables concatenation and preprocessing of assets
  config.assets.debug = true
  
  # Use an evented file watcher to asynchronously detect changes in source code
  config.file_watcher = ActiveSupport::EventedFileUpdateChecker
end 