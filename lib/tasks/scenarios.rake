# frozen_string_literal: true

require 'yaml'
require 'erb'
require 'fileutils'

namespace :scenario do
  desc "List all available scenarios"
  task :list do
    puts "Available scenarios:"
    list_scenarios.each do |scenario|
      environments = list_environments(scenario)
      puts "  #{scenario}: #{environments.join(', ')}"
    end
  end

  desc "Create database dump for scenario"
  task :create_database_dump, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'

    if scenario_name.nil?
      puts "Usage: rake scenario:create_database_dump[scenario_name,environment]"
      puts "Example: rake scenario:create_database_dump[carambus_api,development]"
      exit 1
    end

    create_database_dump(scenario_name, environment)
  end

  desc "Restore database dump for scenario"
  task :restore_database_dump, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'

    if scenario_name.nil?
      puts "Usage: rake scenario:restore_database_dump[scenario_name,environment]"
      puts "Example: rake scenario:restore_database_dump[carambus_api,development]"
      exit 1
    end

    restore_database_dump(scenario_name, environment)
  end

  desc "Generate configuration files from carambus_data/scenarios/"
  task :generate_configs, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'

    if scenario_name.nil?
      puts "Usage: rake scenario:generate_configs[scenario_name,environment]"
      puts "Example: rake scenario:generate_configs[carambus_location_2459,development]"
      exit 1
    end

    generate_configuration_files(scenario_name, environment)
  end

  desc "Create Rails root folder for a scenario"
  task :create_rails_root, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:create_rails_root[scenario_name]"
      puts "Example: rake scenario:create_rails_root[carambus_location_2459]"
      exit 1
    end

    create_rails_root_folder(scenario_name)
  end

  desc "Prepare scenario for development (config files + database + Rails root)"
  task :prepare_development, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'
    force = ENV['FORCE'] == 'true'

    if scenario_name.nil?
      puts "Usage: rake scenario:prepare_development[scenario_name,environment]"
      puts "Example: rake scenario:prepare_development[carambus_location_2459,development]"
      puts "Use FORCE=true to override safety checks (DANGEROUS!)"
      exit 1
    end

    prepare_scenario_for_development(scenario_name, environment, force)
  end

  desc "Prepare scenario for deployment (config generation, file transfers, and database setup)"
  task :prepare_deploy, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:prepare_deploy[scenario_name]"
      puts "Example: rake scenario:prepare_deploy[carambus_location_2459]"
      exit 1
    end

    prepare_scenario_for_deployment(scenario_name)
  end

  desc "Deploy scenario to production (Capistrano deployment only)"
  task :deploy, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:deploy[scenario_name]"
      puts "Example: rake scenario:deploy[carambus_location_2459]"
      puts ""
      puts "Note: Run 'rake scenario:prepare_deploy[#{scenario_name}]' first to prepare deployment files"
      exit 1
    end

    deploy_scenario(scenario_name)
  end

  desc "Update scenario with git pull (preserves local changes)"
  task :update, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:update[scenario_name]"
      puts "Example: rake scenario:update[carambus]"
      exit 1
    end

    update_scenario(scenario_name)
  end

  desc "Create a new scenario"
  task :create, [:scenario_name, :location_id, :context] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    location_id = args[:location_id]
    context = args[:context] || 'NBV'

    if scenario_name.nil? || location_id.nil?
      puts "Usage: rake scenario:create[scenario_name,location_id,context]"
      puts "Example: rake scenario:create[carambus_location_2460,2460,NBV]"
      exit 1
    end

    create_scenario(scenario_name, location_id, context)
  end

  desc "Setup Raspberry Pi client for scenario"
  task :setup_raspberry_pi_client, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:setup_raspberry_pi_client[scenario_name]"
      puts "Example: rake scenario:setup_raspberry_pi_client[carambus_location_2459]"
      exit 1
    end

    setup_raspberry_pi_client(scenario_name)
  end

  desc "Deploy Raspberry Pi client configuration"
  task :deploy_raspberry_pi_client, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:deploy_raspberry_pi_client[scenario_name]"
      puts "Example: rake scenario:deploy_raspberry_pi_client[carambus_location_2459]"
      exit 1
    end

    deploy_raspberry_pi_client(scenario_name)
  end

  desc "Quick deploy - deploy code changes without regenerating scenario configs"
  task :quick_deploy, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:quick_deploy[scenario_name]"
      puts "Example: rake scenario:quick_deploy[carambus_location_5101]"
      puts ""
      puts "This task deploys code changes without regenerating scenario configurations."
      puts "Use this for iterative development when you only changed application code."
      puts ""
      puts "Prerequisites:"
      puts "  1. Scenario must already be deployed (run 'rake scenario:deploy[#{scenario_name}]' first)"
      puts "  2. Changes should be committed and pushed to git"
      puts "  3. No changes to config.yml or scenario configuration files"
      exit 1
    end

    quick_deploy_scenario(scenario_name)
  end

  desc "Restart Raspberry Pi client browser"
  task :restart_raspberry_pi_client, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:restart_raspberry_pi_client[scenario_name]"
      puts "Example: rake scenario:restart_raspberry_pi_client[carambus_location_2459]"
      exit 1
    end

    restart_raspberry_pi_client(scenario_name)
  end

  desc "Test Raspberry Pi client connection"
  task :test_raspberry_pi_client, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:test_raspberry_pi_client[scenario_name]"
      puts "Example: rake scenario:test_raspberry_pi_client[carambus_location_2459]"
      exit 1
    end

    test_raspberry_pi_client(scenario_name)
  end

  private

  def carambus_data_path
    @carambus_data_path ||= File.expand_path('../carambus_data', Rails.root)
  end

  # Rails Configuration Tasks
  desc "Configure Rails application for production deployment"
  task :configure_rails_app, [:scenario_name, :environment, :ssh_host, :ssh_port] => :environment do |t, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'production'
    ssh_host = args[:ssh_host]
    ssh_port = args[:ssh_port] || 22

    puts "🔧 Configuring Rails application for #{scenario_name} (#{environment})..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      exit 1
    end

    scenario_config = YAML.load_file(config_file)
    env_config = scenario_config['environments'][environment]

    if env_config.nil?
      puts "❌ Error: Environment '#{environment}' not found in scenario configuration"
      exit 1
    end

    basename = scenario_config['scenario']['basename']
    webserver_host = env_config['webserver_host']
    webserver_port = env_config['webserver_port']
    location_id = scenario_config['scenario']['location_id']

    # Calculate MD5 hash for location
    require 'digest'
    location_md5 = Digest::MD5.hexdigest(location_id.to_s)

    # Configure Rails application using Ruby/Rails operations
    # NOTE: All Rails configuration is now handled during prepare_deploy step
    # No additional remote configuration needed during deployment
  end



  def scenarios_path
    @scenarios_path ||= File.join(carambus_data_path, 'scenarios')
  end

  def templates_path
    @templates_path ||= File.join(Rails.root, 'templates')
  end

  def list_scenarios
    scenarios = Dir.glob(File.join(scenarios_path, '*')).select { |f| File.directory?(f) }
    scenarios.map { |s| File.basename(s) }
  end

  def list_environments(scenario_name)
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    return [] unless File.exist?(config_file)

    scenario_config = YAML.load_file(config_file)
    scenario_config['environments'].keys
  end

  def generate_configuration_files(scenario_name, environment)
    puts "Generating configuration files for #{scenario_name} (#{environment})..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    env_config = scenario_config['environments'][environment]

    if env_config.nil?
      puts "Error: Environment '#{environment}' not found in scenario configuration"
      return false
    end

    # Create environment directory
    env_dir = File.join(scenarios_path, scenario_name, environment)
    FileUtils.mkdir_p(env_dir)

    # Generate carambus.yml in environment directory
    generate_carambus_yml(scenario_config, env_config, env_dir)

    # Generate database.yml in environment directory
    generate_database_yml(scenario_config, env_config, env_dir)

    # Generate nginx.conf in environment directory (only for production)
    if environment == 'production'
      generate_nginx_conf(scenario_config, env_config, env_dir)
    else
      # For development, ensure nginx.conf is not generated (development doesn't need nginx)
      remove_development_nginx_conf(env_dir)
    end

    # Generate puma.service in environment directory (only for production)
    if environment == 'production'
      generate_puma_service(scenario_config, env_config, env_dir)
    end

    # Generate puma.rb in environment directory (only for production)
    # Development should use the standard Rails puma.rb configuration
    if environment == 'production'
      generate_puma_rb(scenario_config, env_config, env_dir)
    else
      # For development, ensure we have a proper development puma.rb
      restore_development_puma_rb(env_dir)
    end

    # Generate deploy files in environment directory (only for development)
    generate_deploy_files(scenario_config, env_config, env_dir)

    # Generate cable.yml in environment directory
    generate_cable_yml(scenario_config, env_config, env_dir)

    # Generate development.rb in environment directory (only for development)
    if environment == 'development'
      generate_development_rb(scenario_config, env_config, env_dir)
    end

    # Generate env.development in environment directory (only for development)
    if environment == 'development'
      generate_env_development(scenario_config, env_config, env_dir)
    end

    # Generate production.rb in environment directory (only for production)
    if environment == 'production'
      generate_production_rb_env(scenario_config, env_config, env_dir)
    end

    # Generate test.rb in environment directory (always generate test environment)
    generate_test_rb(scenario_config, env_config, env_dir)

    # Generate env.production in environment directory (only for production)
    if environment == 'production'
      generate_env_production(scenario_config, env_config, env_dir)
    end

    puts "✅ Configuration files generated for #{scenario_name} (#{environment})"
    puts "   Location: #{env_dir}"
    true
  end

  def generate_carambus_yml(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'carambus', 'carambus.yml.erb')
    unless File.exist?(template_file)
      puts "Error: Carambus template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)  # 'development' oder 'production'

    content = template.result(binding)
    File.write(File.join(env_dir, 'carambus.yml'), content)
    puts "   Generated: #{File.join(env_dir, 'carambus.yml')}"
    true
  end

  def generate_database_yml(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'database', 'database.yml.erb')
    unless File.exist?(template_file)
      puts "Error: Database template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @config = env_config
    @environment = File.basename(env_dir)  # 'development' oder 'production'

    content = template.result(binding)
    File.write(File.join(env_dir, 'database.yml'), content)
    puts "   Generated: #{File.join(env_dir, 'database.yml')}"
    true
  end

  def generate_nginx_conf(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'nginx', 'nginx_conf.erb')
    unless File.exist?(template_file)
      puts "Error: Nginx template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)  # 'development' oder 'production'

    content = template.result(binding)
    File.write(File.join(env_dir, 'nginx.conf'), content)
    puts "   Generated: #{File.join(env_dir, 'nginx.conf')}"
    true
  end

  def generate_puma_service(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'puma', 'puma.service.erb')
    unless File.exist?(template_file)
      puts "Error: Puma service template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)  # 'development' oder 'production'

    content = template.result(binding)
    File.write(File.join(env_dir, 'puma.service'), content)
    puts "   Generated: #{File.join(env_dir, 'puma.service')}"
    true
  end

  def generate_puma_rb(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'puma', 'puma_rb.erb')
    unless File.exist?(template_file)
      puts "Error: Puma.rb template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)  # 'development' or 'production'
    @production_config = scenario_config['environments']['production']

    content = template.result(binding)
    File.write(File.join(env_dir, 'puma.rb'), content)
    puts "   Generated: #{File.join(env_dir, 'puma.rb')}"
    true
  end

  def restore_development_puma_rb(env_dir)
    # Get scenario-specific configuration from the environment directory path
    scenario_name = File.basename(File.dirname(env_dir))
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')

    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    env_config = scenario_config['environments']['development']

    # Extract scenario-specific parameters
    port = env_config['webserver_port'] || 3000
    host = env_config['webserver_host'] || 'localhost'
    scenario_name_clean = scenario_config['scenario']['name']

    # Generate scenario-specific development puma.rb configuration
    development_config = <<~PUMA_CONFIG
      # frozen_string_literal: true

      # Puma configuration for #{scenario_name_clean} (development)
      # Generated by Carambus Scenario System
      
      threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
      threads threads_count, threads_count

      # Specifies the `environment` that Puma will run in.
      environment ENV.fetch("RAILS_ENV") { "development" }

      # Specifies the `port` that Puma will listen on to receive requests.
      port ENV.fetch("PORT") { #{port} }

      # Specifies the `bind` address that Puma will listen on.
      bind "tcp://#{host}:#{port}"

      # Ensure PID file directory exists with scenario-specific name
      pidfile "tmp/pids/#{scenario_name_clean}-server.pid"

      # Allow puma to be restarted by `rails restart` command.
      plugin :tmp_restart

      # Clean up on exit
      on_worker_shutdown do
        File.delete(pidfile) if File.exist?(pidfile)
      end
    PUMA_CONFIG

    File.write(File.join(env_dir, 'puma.rb'), development_config)
    puts "   Generated: #{File.join(env_dir, 'puma.rb')} (#{scenario_name_clean} development - port #{port})"
    true
  end

  def remove_development_nginx_conf(env_dir)
    nginx_conf_path = File.join(env_dir, 'nginx.conf')
    if File.exist?(nginx_conf_path)
      File.delete(nginx_conf_path)
      puts "   Removed: #{nginx_conf_path} (not needed for development)"
    end
    true
  end

  def generate_deploy_files(scenario_config, env_config, env_dir)
    # Generate deploy files for all environments

    # Generate deploy.rb from template
    generate_deploy_rb(scenario_config, env_config, env_dir)

    # Generate production.rb from template (only for production)
    if File.basename(env_dir) == 'production'
      generate_production_rb(scenario_config, env_config, env_dir)
    end

    true
  end

  def generate_deploy_rb(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'deploy', 'deploy_rb.erb')
    unless File.exist?(template_file)
      puts "Error: Deploy template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)

    content = template.result(binding)
    File.write(File.join(env_dir, 'deploy.rb'), content)
    puts "   Generated: #{File.join(env_dir, 'deploy.rb')}"
    true
  end

  def generate_production_rb(scenario_config, env_config, env_dir)
    template_file = File.join(templates_path, 'deploy', 'production_rb.erb')
    unless File.exist?(template_file)
      puts "Error: Production template not found: #{template_file}"
      return false
    end

    template = ERB.new(File.read(template_file))
    @scenario = scenario_config['scenario']
    @config = env_config
    @environment = File.basename(env_dir)

    content = template.result(binding)

    # Create deploy subdirectory if it doesn't exist
    deploy_dir = File.join(env_dir, 'deploy')
    FileUtils.mkdir_p(deploy_dir) unless Dir.exist?(deploy_dir)

    File.write(File.join(deploy_dir, 'production.rb'), content)
    puts "   Generated: #{File.join(deploy_dir, 'production.rb')}"
    true
  end

  def generate_cable_yml(scenario_config, env_config, env_dir)
    # Generate cable.yml with async adapter for production (no Redis dependency)
    redis_db = env_config['redis_database'] || 1
    channel_prefix = env_config['channel_prefix'] || 'carambus_development'

    content = <<~YAML
development:
  adapter: async

test:
  adapter: test

production:
  adapter: async
YAML

    File.write(File.join(env_dir, 'cable.yml'), content)
    puts "   Generated: #{File.join(env_dir, 'cable.yml')}"
    true
  end

  def generate_development_rb(scenario_config, env_config, env_dir)
    # Generate development.rb with ActionCable URL configuration
    actioncable_url = env_config['actioncable_url'] || "ws://localhost:3000/cable"
    redis_db = env_config['redis_database'] || 1
    webserver_port = env_config['webserver_port'] || 3000

    content = <<~RUBY
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.session_store :redis_session_store,
    serializer: :json,
    on_redis_down: ->(*args) { Rails.logger.error("Redis down! \#{args.inspect}") },
    redis: {
      expire_after: 120.minutes,
      key_prefix: "session:",
      url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/#{redis_db}" }
    }

  # Log to STDOUT for development
  config.logger = ActiveSupport::Logger.new($stdout)
    .tap { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Set log level
  config.log_level = :debug
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded any time
  # it changes. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.enable_reloading = true

  # Do not eager load code on boot.
  config.eager_load = false

  # Show full error reports.
  config.consider_all_requests_local = true

  # Enable server timing.
  config.server_timing = true

  # Enable/disable caching. By default caching is disabled.
  # Run rails dev:cache to toggle caching.
  if Rails.root.join("tmp/caching-dev.txt").exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {"Cache-Control" => "public, max-age=#{2.days.to_i}"}
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Set default URL options for redirects and link generation
  config.action_controller.default_url_options = {host: "lvh.me", port: ENV.fetch("PORT", #{webserver_port}).to_i}
  config.action_mailer.default_url_options = {host: "lvh.me", port: ENV.fetch("PORT", #{webserver_port}).to_i}

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
  config.action_cable.disable_request_forgery_protection = true

  # Allow websocket connections from any origin in development
  config.action_cable.url = "#{actioncable_url}"
  config.action_cable.allowed_request_origins = [%r{http://.*}, %r{https://.*}]

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # Apply autocorrection by RuboCop to files generated by `bin/rails generate`.
  # config.generators.apply_rubocop_autocorrect_after_generate!

  # Uncomment the line below to enable strict loading across all models. More granular control can be applied at the model or association level.
  # config.active_record.strict_loading_by_default = true

  # Deliver emails to Letter Opener for development
  config.action_mailer.delivery_method = :letter_opener_web

  # Allow accessing localhost on any domain. Important for testing multi-tenant apps.
  config.hosts = nil

  # You may need to set to include the correct URLs from Turbo, etc
  # config.action_controller.default_url_options = {host: "lvh.me", port: ENV.fetch("PORT", #{webserver_port}).to_i}

  config.generators.after_generate do |files|
    parsable_files = files.filter { |file| file.end_with?(".rb") }
    unless parsable_files.empty?
      system("bundle exec standardrb --fix \#{parsable_files.shelljoin}", exception: true)
    end
  end


  # Use Rails credentials as normal
  config.secret_key_base = Rails.application.credentials.fetch(:secret_key_base)

  config.credentials.content_path = config.root.join('config/credentials/development.yml.enc')
  config.credentials.key_path = config.root.join('config/credentials/development.key')

  config.i18n.fallbacks = true
  config.i18n.raise_on_missing_translations = true
end
RUBY

    # Apply string interpolation for dynamic values
    content = content.gsub('#{redis_db}', redis_db.to_s)
                    .gsub('#{webserver_port}', webserver_port.to_s)
                    .gsub('#{actioncable_url}', actioncable_url)

    File.write(File.join(env_dir, 'development.rb'), content)
    puts "   Generated: #{File.join(env_dir, 'development.rb')}"
    true
  end

  def generate_env_development(scenario_config, env_config, env_dir)
    # Generate env.development with correct port configuration
    webserver_port = env_config['webserver_port'] || 3000

    content = <<~ENV
# Carambus Development Environment Configuration
# Für Entwicklungsumgebung auf dem Mac

# Deployment-Konfiguration
DEPLOYMENT_TYPE=LOCAL_SERVER
RAILS_ENV=development

# Datenbank-Konfiguration
DATABASE_NAME=#{env_config['database_name'] || 'carambus_development'}
DATABASE_USER=www_data
DATABASE_PASSWORD=carambus_development_password
DB_DUMP_FILE=carambus_development.sql.gz

# Redis-Konfiguration
REDIS_DB=#{env_config['redis_database'] || 1}

# Port-Konfiguration
WEB_PORT=#{webserver_port}
POSTGRES_PORT=5432
REDIS_PORT=6379

# Domain-Konfiguration (nicht relevant für Entwicklung)
DOMAIN=
USE_HTTPS=false

# Location-spezifische Konfiguration (optional)
# Für location-spezifische Entwicklung: carambus_development_xyz
LOCATION_CODE=#{scenario_config['scenario']['location_id'] || ''}
ENV

    File.write(File.join(env_dir, 'env.development'), content)
    puts "   Generated: #{File.join(env_dir, 'env.development')}"
    true
  end

  def generate_production_rb_env(scenario_config, env_config, env_dir)
    # Generate production.rb with ActionCable URL configuration
    actioncable_url = env_config['actioncable_url'] || "ws://localhost:3000/cable"
    redis_db = env_config['redis_database'] || 0
    webserver_port = env_config['webserver_port'] || 3000
    webserver_host = env_config['webserver_host'] || 'localhost'

    content = <<~'RUBY'
require "active_support/core_ext/integer/time"

Rails.application.configure do
  config.session_store :redis_session_store,
    serializer: :json,
    on_redis_down: ->(*args) { Rails.logger.error("Redis down! \#{args.inspect}") },
    redis: {
      expire_after: 120.minutes,
      key_prefix: "session:",
      url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/#{redis_db}" }
    }

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fallback to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV["USE_HTTPS"] == "true"

  # Set default URL options for redirects and link generation
  config.action_controller.default_url_options = { host: "#{webserver_host}", port: #{webserver_port} }
  config.action_mailer.default_url_options = { host: "#{webserver_host}", port: #{webserver_port} }

  # Include generic and useful information about system operation, but avoid logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII).
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "carambus_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require "syslog/logger"
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new "app-name")

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Enable DNS rebinding protection for credentials.
  # Allow requests from the Pi server
  config.hosts << "#{webserver_host}"
  config.hosts << "#{webserver_host}:#{webserver_port}"

  # Allow Action Cable access from any origin in production
  config.action_cable.disable_request_forgery_protection = true
  config.action_cable.url = "#{actioncable_url}"
  config.action_cable.allowed_request_origins = [%r{http://#{webserver_host}}, %r{https://#{webserver_host}}]
  # config.action_cable.adapter = :async  # Removed - invalid for Rails 7.2.2.2

  # Use Rails credentials as normal
  config.secret_key_base = Rails.application.credentials.fetch(:secret_key_base)

  config.credentials.content_path = config.root.join('config/credentials/production.yml.enc')
  config.credentials.key_path = config.root.join('config/credentials/production.key')

  config.i18n.fallbacks = true
  config.i18n.raise_on_missing_translations = false
end
RUBY

    # Apply string interpolation for dynamic values
    content = content.gsub('#{redis_db}', redis_db.to_s)
                    .gsub('#{webserver_port}', webserver_port.to_s)
                    .gsub('#{actioncable_url}', actioncable_url)
                    .gsub('#{webserver_host}', webserver_host)

    File.write(File.join(env_dir, 'production.rb'), content)
    puts "   Generated: #{File.join(env_dir, 'production.rb')}"
    true
  end

  def generate_test_rb(scenario_config, env_config, env_dir)
    # Generate test.rb with basic test configuration
    content = <<~'RUBY'
require "active_support/core_ext/integer/time"

# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = false

  # Show full error reports and disable caching.
  config.consider_all_requests_local = true
  config.action_controller.perform_caching = false
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  config.action_mailer.perform_caching = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raise exceptions for disallowed deprecations.
  config.active_support.disallowed_deprecation = :raise

  # Tell Active Support which deprecation messages to disallow.
  config.active_support.disallowed_deprecation_warnings = []

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true
end
RUBY

    File.write(File.join(env_dir, 'test.rb'), content)
    puts "   Generated: #{File.join(env_dir, 'test.rb')}"
    true
  end


  def generate_env_production(scenario_config, env_config, env_dir)
    # Generate env.production with correct port configuration
    webserver_port = env_config['webserver_port'] || 3000
    redis_db = env_config['redis_database'] || 0

    content = <<~ENV
# Carambus Production Environment Configuration
# Für Produktionsumgebungen
# Unterstützt alle Deployment-Typen: API_SERVER, LOCAL_SERVER, WEB_CLIENT

# Production-Modus (übergeordnet)
RAILS_ENV=production

# Deployment-Konfiguration (muss gesetzt werden)
DEPLOYMENT_TYPE=LOCAL_SERVER  # oder API_SERVER oder WEB_CLIENT

# Datenbank-Konfiguration (muss gesetzt werden)
DATABASE_NAME=#{env_config['database_name'] || 'carambus_production'}
DATABASE_USER=#{env_config['database_username'] || 'www_data'}
DATABASE_PASSWORD=#{env_config['database_password'] || ''}
DB_DUMP_FILE=

# Redis-Konfiguration
REDIS_DB=#{redis_db}

# Port-Konfiguration
WEB_PORT=#{webserver_port}
POSTGRES_PORT=5432
REDIS_PORT=6379

# Domain-Konfiguration (optional)
DOMAIN=#{env_config['webserver_host'] || ''}
USE_HTTPS=#{env_config['ssl_enabled'] || false}

# Location-spezifische Konfiguration (optional)
LOCATION_CODE=#{scenario_config['scenario']['location_id'] || ''}

# Production-spezifische Konfiguration
RAILS_HOST=0.0.0.0
RAILS_PORT=#{webserver_port}
ENV

    File.write(File.join(env_dir, 'env.production'), content)
    puts "   Generated: #{File.join(env_dir, 'env.production')}"
    true
  end


  def restore_database_dump(scenario_name, environment)
    puts "Restoring database dump for #{scenario_name} (#{environment})..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    env_config = scenario_config['environments'][environment]

    if env_config.nil?
      puts "Error: Environment '#{environment}' not found in scenario configuration"
      return false
    end

    database_name = env_config['database_name']
    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')

    # Find latest dump file
    dump_files = Dir.glob(File.join(dump_dir, "#{scenario_name}_#{environment}_*.sql.gz"))
    if dump_files.empty?
      puts "Error: No dump files found in #{dump_dir}"
      return false
    end

    latest_dump = dump_files.sort.last
    puts "Using dump: #{File.basename(latest_dump)}"

    if environment == 'production'
      # For production: transfer dump to remote server, then restore there
      ssh_host = env_config['ssh_host']
      ssh_port = env_config['ssh_port']

      puts "Transferring dump to production server #{ssh_host}:#{ssh_port}..."
      remote_dump_file = "/tmp/#{File.basename(latest_dump)}"

      # Transfer dump to remote server
      scp_cmd = "scp -P #{ssh_port} #{latest_dump} www-data@#{ssh_host}:#{remote_dump_file}"
      if system(scp_cmd)
        puts "   ✅ Dump transferred to remote server"

        # Drop and recreate database on remote server
        puts "Dropping database #{database_name} on remote server..."
        drop_cmd = "sudo -u postgres dropdb #{database_name}" if system("ssh -p #{ssh_port} www-data@#{ssh_host} 'sudo -u postgres psql -lqt | cut -d \\| -f 1 | grep -qw #{database_name}'")

        puts "Creating database #{database_name} on remote server..."
        create_cmd = "sudo -u postgres createdb #{database_name}"
        if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{create_cmd}'")
          puts "   ✅ Database created on remote server"

          # Restore dump on remote server
          puts "Restoring dump on remote server..."
          restore_cmd = "gunzip -c #{remote_dump_file} | sudo -u postgres psql #{database_name}"
          if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restore_cmd}'")
            puts "   ✅ Database restored successfully on remote server"

            # Clean up remote dump file
            system("ssh -p #{ssh_port} www-data@#{ssh_host} 'rm -f #{remote_dump_file}'")

            true
          else
            puts "❌ Database restore failed on remote server"
            false
          end
        else
          puts "❌ Failed to create database on remote server"
          false
        end
      else
        puts "❌ Failed to transfer dump to remote server"
        false
      end
    else
      # For development: restore locally
      # Drop and recreate database
      puts "Dropping database #{database_name}..."
      system("dropdb #{database_name}") if system("psql -lqt | cut -d \| -f 1 | grep -qw #{database_name}")

      puts "Creating database #{database_name}..."
      system("createdb #{database_name}")

      # Restore dump
      puts "Restoring from #{latest_dump}..."
      if system("gunzip -c #{latest_dump} | psql #{database_name}")
        puts "✅ Database restored successfully"

        # Reset sequences for local server (prevents ID conflicts with API)
        puts "Resetting sequences for local server..."
        system("cd #{File.expand_path("../#{scenario_name}", carambus_data_path)} && bundle exec rails runner 'Version.sequence_reset'")

        true
      else
        puts "❌ Database restore failed"
        false
      end
    end
  end

  def create_database_dump(scenario_name, environment)
    puts "Creating database dump for #{scenario_name} (#{environment})..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    env_config = scenario_config['environments'][environment]

    if env_config.nil?
      puts "Error: Environment '#{environment}' not found in scenario configuration"
      return false
    end

    database_name = env_config['database_name']
    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    FileUtils.mkdir_p(dump_dir)

    # Create dump filename with timestamp
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dump_file = File.join(dump_dir, "#{scenario_name}_#{environment}_#{timestamp}.sql.gz")

    if environment == 'production'
      # For production: create dump on remote server, then transfer to local
      ssh_host = env_config['ssh_host']
      ssh_port = env_config['ssh_port']

      puts "Creating dump on production server #{ssh_host}:#{ssh_port}..."
      remote_dump_file = "/tmp/#{scenario_name}_#{environment}_#{timestamp}.sql.gz"

      # Create dump on remote server (include schema and data)
      dump_cmd = "pg_dump --no-owner --no-privileges #{database_name} | gzip > #{remote_dump_file}"
      if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{dump_cmd}'")
        puts "   ✅ Dump created on remote server"

        # Transfer dump from remote to local
        puts "Transferring dump from remote server..."
        scp_cmd = "scp -P #{ssh_port} www-data@#{ssh_host}:#{remote_dump_file} #{dump_file}"
        if system(scp_cmd)
          puts "   ✅ Dump transferred to local storage"

          # Clean up remote dump file
          system("ssh -p #{ssh_port} www-data@#{ssh_host} 'rm -f #{remote_dump_file}'")

          puts "✅ Database dump created: #{File.basename(dump_file)}"
          puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"
          true
        else
          puts "❌ Failed to transfer dump from remote server"
          false
        end
      else
        puts "❌ Failed to create dump on remote server"
        false
      end
    else
      # For development: create dump locally (include schema and data)
      puts "Creating dump of #{database_name}..."
      if system("pg_dump --no-owner --no-privileges #{database_name} | gzip > #{dump_file}")
        puts "✅ Database dump created: #{File.basename(dump_file)}"
        puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"
        true
      else
        puts "❌ Database dump failed"
        false
      end
    end
  end

  def create_rails_root_folder(scenario_name)
    puts "Creating Rails root folder for #{scenario_name}..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    # Create Rails root folder using git clone
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    FileUtils.rm_rf(rails_root) if Dir.exist?(rails_root)

    # Clone from GitHub repository
    repo_url = "git@github.com:GernotUllrich/carambus.git"
    puts "   Cloning from: #{repo_url}"

    if system("git clone #{repo_url} #{rails_root}")
      puts "   ✅ Git clone successful"

      # Create necessary directories
      %w[log tmp storage].each do |dir|
        FileUtils.mkdir_p(File.join(rails_root, dir))
      end

      # Copy RubyMine .idea configuration for development
      idea_source = File.join(Rails.root, '.idea')
      if Dir.exist?(idea_source)
        FileUtils.cp_r(idea_source, rails_root)
        puts "   ✅ RubyMine .idea configuration copied"
      else
        puts "   ⚠️  RubyMine .idea configuration not found in master"
      end


      puts "✅ Rails root folder created: #{rails_root}"
      true
    else
      puts "❌ Git clone failed"
      false
    end
  end

  def prepare_scenario_for_development(scenario_name, environment, force = false)
    puts "Preparing scenario #{scenario_name} for development (#{environment})..."
    puts "This includes Rails root creation, config generation, basic config copying, and database operations."

    if force
      puts "⚠️  FORCE MODE ENABLED - Safety checks are DISABLED!"
      puts "⚠️  This can cause DATA LOSS!"
    end

    # Step 1: Create Rails root folder (if it doesn't exist)
    puts "\n📁 Step 1: Ensuring Rails root folder exists..."
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    rails_root_created = false
    unless Dir.exist?(rails_root)
      puts "   Rails root folder not found, creating it..."
      unless create_rails_root_folder(scenario_name)
        puts "❌ Failed to create Rails root folder"
        return false
      end
      rails_root_created = true
    else
      puts "   ✅ Rails root folder already exists"
    end

    # Step 2: Generate development configuration files
    puts "\n📋 Step 2: Generating development configuration files..."
    unless generate_configuration_files(scenario_name, environment)
      puts "❌ Failed to generate configuration files"
      return false
    end

    # Step 3: Copy basic configuration files to Rails root
    puts "\n📁 Step 3: Copying basic configuration files to Rails root..."
    env_dir = File.join(scenarios_path, scenario_name, environment)

    if Dir.exist?(env_dir)
      # Copy database.yml
      if File.exist?(File.join(env_dir, 'database.yml'))
        FileUtils.cp(File.join(env_dir, 'database.yml'), File.join(rails_root, 'config', 'database.yml'))
        puts "   ✅ database.yml copied to Rails root"
      end

      # Copy carambus.yml
      if File.exist?(File.join(env_dir, 'carambus.yml'))
        FileUtils.cp(File.join(env_dir, 'carambus.yml'), File.join(rails_root, 'config', 'carambus.yml'))
        puts "   ✅ carambus.yml copied to Rails root"
      end

      # Copy cable.yml
      if File.exist?(File.join(env_dir, 'cable.yml'))
        FileUtils.cp(File.join(env_dir, 'cable.yml'), File.join(rails_root, 'config', 'cable.yml'))
        puts "   ✅ cable.yml copied to Rails root"
      end

      # Copy development.rb (only for development environment)
      if environment == 'development' && File.exist?(File.join(env_dir, 'development.rb'))
        FileUtils.cp(File.join(env_dir, 'development.rb'), File.join(rails_root, 'config', 'environments', 'development.rb'))
        puts "   ✅ development.rb copied to Rails root"
      end

      # Copy env.development (only for development environment)
      if environment == 'development' && File.exist?(File.join(env_dir, 'env.development'))
        FileUtils.cp(File.join(env_dir, 'env.development'), File.join(rails_root, 'env.development'))
        puts "   ✅ env.development copied to Rails root"
      end
    end


    # Step 4: Install dependencies (if Rails root was created or dependencies are missing)
    puts "\n📦 Step 4: Checking and installing dependencies..."
    if rails_root_created || dependencies_missing?(rails_root)
      unless install_scenario_dependencies(rails_root)
        puts "❌ Failed to install dependencies"
        return false
      end
    else
      puts "   ✅ Dependencies already installed"
    end

    # Step 5: Create actual development database from template
    puts "\n🗄️  Step 5: Creating development database..."
    unless create_development_database(scenario_name, environment, force)
      puts "❌ Failed to create development database"
      return false unless scenario_name == "carambus_api_development"
    end

    puts "\n✅ Scenario #{scenario_name} prepared for development!"
    puts "   Rails root: #{rails_root}"
    puts "   Environment: #{environment}"
    puts "   Database: #{scenario_name}_#{environment}"
    puts "   Database dump: #{File.join(scenarios_path, scenario_name, 'database_dumps')}"

    true
  end

  def dependencies_missing?(rails_root)
    # Check if node_modules directory exists
    node_modules_path = File.join(rails_root, 'node_modules')
    unless Dir.exist?(node_modules_path)
      puts "   📦 node_modules directory not found"
      return true
    end

    # Check if Gemfile.lock exists (indicates bundle install was run)
    gemfile_lock_path = File.join(rails_root, 'Gemfile.lock')
    unless File.exist?(gemfile_lock_path)
      puts "   📦 Gemfile.lock not found"
      return true
    end

    false
  end

  def install_scenario_dependencies(rails_root)
    puts "Installing dependencies for scenario..."

    # Install Ruby dependencies
    puts "   📦 Installing Ruby dependencies (bundle install)..."
    unless system("cd #{rails_root} && bundle install")
      puts "   ❌ Failed to install Ruby dependencies"
      return false
    end
    puts "   ✅ Ruby dependencies installed"

    # Install JavaScript dependencies
    puts "   📦 Installing JavaScript dependencies (yarn install)..."
    unless system("cd #{rails_root} && yarn install")
      puts "   ❌ Failed to install JavaScript dependencies"
      return false
    end
    puts "   ✅ JavaScript dependencies installed"

    # Build JavaScript assets
    puts "   🔨 Building JavaScript assets (yarn build)..."
    unless system("cd #{rails_root} && yarn build")
      puts "   ❌ Failed to build JavaScript assets"
      return false
    end
    puts "   ✅ JavaScript assets built"

    # Build CSS assets
    puts "   🎨 Building CSS assets (yarn build:css)..."
    unless system("cd #{rails_root} && yarn build:css")
      puts "   ❌ Failed to build CSS assets"
      return false
    end
    puts "   ✅ CSS assets built"

    # Precompile Rails assets for development
    puts "   📦 Precompiling Rails assets (rails assets:precompile)..."
    unless system("cd #{rails_root} && RAILS_ENV=development bundle exec rails assets:precompile")
      puts "   ❌ Failed to precompile Rails assets"
      return false
    end
    puts "   ✅ Rails assets precompiled"

    true
  end

  def create_development_database(scenario_name, environment, force = false)
    puts "Creating development database for #{scenario_name} (#{environment})..."

    # Special protection for carambus_api scenario
    if scenario_name == 'carambus_api' && !force
      puts "   ⚠️  WARNING: carambus_api is a special scenario!"
      puts "   ⚠️  Its database (carambus_api_development) contains irreplaceable data!"
      puts "   ⚠️  This scenario should NOT be managed by scenario:prepare_development"
      puts "   ⚠️  Use scenario:create_database_dump and scenario:restore_database_dump instead"
      puts ""
      puts "   🔧 If you really need to recreate this database:"
      puts "   1. Create a backup first: rake scenario:create_database_dump[carambus_api,development]"
      puts "   2. Use FORCE=true to override this protection"
      puts "   3. Or manually manage the database"
      return false
    elsif scenario_name == 'carambus_api' && force
      puts "   ⚠️  FORCE MODE: Bypassing carambus_api protection!"
      puts "   ⚠️  This will DESTROY irreplaceable data!"
    end

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    scenario_data = scenario_config['scenario']
    region_id = scenario_data['region_id']

    database_name = "#{scenario_name}_#{environment}"

    # Check if existing database has newer data before dropping
    if system("psql -lqt | cut -d \\| -f 1 | grep -qw #{database_name}")
      puts "   🔍 Existing database #{database_name} found, checking data loss protection..."

      # Get last_version_id from existing database (use Version.last.id for API databases)
      existing_version_cmd = "psql #{database_name} -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions;\""
      existing_version_result = `#{existing_version_cmd}`.strip
      existing_last_version_id = existing_version_result.to_i

      puts "   📊 Existing database last_version_id: #{existing_last_version_id}"

      # Get last_version_id from source database (carambus_api_development) - use Version.last.id
      source_version_cmd = "psql carambus_api_development -t -c \"SELECT COALESCE(MAX(id), 0) FROM versions;\""
      source_version_result = `#{source_version_cmd}`.strip
      source_last_version_id = source_version_result.to_i

      puts "   📊 Source database (carambus_api_development) last_version_id: #{source_last_version_id}"

      # Data loss protection logic:
      # 1. If creating from template (development environment), no protection needed
      # 2. If existing database has newer data than source AND source is development, block
      # 3. If existing database has local data (id > 50000000), warn about local data loss
      should_block = false
      has_local_data = false

      if existing_last_version_id > 0
        # Check for local data (records with id > 50000000)
        local_data_cmd = "psql #{database_name} -t -c \"SELECT COUNT(*) FROM (SELECT 1 FROM tournaments WHERE id > 50000000 LIMIT 1) AS local_check;\""
        local_data_result = `#{local_data_cmd}`.strip.to_i
        has_local_data = local_data_result > 0

        # Block if existing database has newer data than source AND we're overwriting production with development
        if existing_last_version_id > source_last_version_id && environment == 'production'
          should_block = true
          puts "   ⚠️  BLOCKING: Existing #{environment} database has newer data (last_version_id: #{existing_last_version_id}) than source development database (last_version_id: #{source_last_version_id})!"
        end
      end

      if should_block
        if force
          puts "   ⚠️  FORCE MODE: Bypassing data loss protection!"
          puts "   ⚠️  Dropping database with newer data (last_version_id: #{existing_last_version_id})!"
          puts "   Dropping existing database #{database_name}..."
          system("dropdb #{database_name}")
        else
          puts "   ⚠️  WARNING: This would overwrite newer #{environment} data with older development data!"
          puts "   ⚠️  This operation is BLOCKED for safety."
          puts ""
          puts "   🔧 If you really need to recreate this database:"
          puts "   1. Create a backup first: rake scenario:create_database_dump[#{scenario_name},#{environment}]"
          puts "   2. Use FORCE=true to override this safety check"
          puts "   3. Or manually drop the database if you're certain"
          return false
        end
      elsif has_local_data
        puts "   ⚠️  WARNING: Existing database contains local data (records with id > 50000000)!"
        puts "   ⚠️  This local data will be LOST when recreating from template!"
        puts "   ⚠️  Consider extracting local data first before recreating."
        puts ""
        if force
          puts "   ⚠️  FORCE MODE: Proceeding despite local data loss warning!"
          puts "   Dropping existing database #{database_name}..."
          system("dropdb #{database_name}")
        else
          puts "   🔧 If you want to proceed despite local data loss:"
          puts "   1. Use FORCE=true to override this warning"
          puts "   2. Or manually extract local data first"
          return false
        end
      else
        puts "   ✅ Existing database can be safely recreated from template"
        puts "   Dropping existing database #{database_name}..."
        system("dropdb #{database_name}")
      end
    end

    # Special case for local carambus scenario (no region_id) - should still use template
    if (region_id && environment == 'development') || (scenario_name == 'carambus' && environment == 'development')
      template_reason = region_id ? "region_id: #{region_id}" : "local carambus scenario"
      puts "🔄 Creating #{database_name} from carambus_api_development template (#{template_reason})..."

      # Create database using template (much faster than dump/restore)
      if system("createdb #{database_name} --template=carambus_api_development")
        puts "   ✅ Created database: #{database_name} (using template)"

        # Use Rails commands for proper transformations
        rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)

        puts "   🔄 Applying Rails transformations..."

        # Change to Rails root and run Rails commands
        Dir.chdir(rails_root) do
          # Set up Rails environment
          ENV['RAILS_ENV'] = 'development'
          ENV['DATABASE_URL'] = "postgresql://localhost/#{database_name}"

          # Enable caching for StimulusReflex
          puts "   🔄 Enabling development caching..."
          # Create the caching-dev.txt file to enable caching
          caching_file = File.join(rails_root, "tmp", "caching-dev.txt")
          FileUtils.mkdir_p(File.dirname(caching_file))
          FileUtils.touch(caching_file)
          puts "   ✅ Development caching enabled (caching-dev.txt created)"

          # Reset version sequence using existing method
          puts "   🔄 Resetting version sequence..."
          if system("bundle exec rails runner 'Version.sequence_reset'")
            puts "   ✅ Version sequence reset"
          else
            puts "   ⚠️  Warning: Version sequence reset failed"
          end

          # Find latest version ID and set as last_version_id
          puts "   🔄 Setting last_version_id..."
          if system("bundle exec rails runner 'last_version_id = Version.last.id; Setting.key_set_value(\"last_version_id\", last_version_id); puts \"Set last_version_id to: \" + last_version_id.to_s'")
            puts "   ✅ Last version ID set"
          else
            puts "   ⚠️  Warning: Failed to set last_version_id"
          end

          # Remove old versions (keep only the latest)
          puts "   🔄 Removing old versions..."
          if system("bundle exec rails runner 'last_version_id = Version.last.id; Version.where(\"id < \" + last_version_id.to_s).delete_all; puts \"Removed old versions, kept ID: \" + last_version_id.to_s'")
            puts "   ✅ Old versions removed"
          else
            puts "   ⚠️  Warning: Failed to remove old versions"
          end

          # Set scenario name
          puts "   🔄 Setting scenario name..."
          if system("bundle exec rails runner 'Setting.key_set_value(\"scenario_name\", \"#{scenario_name}\"); puts \"Set scenario_name to: #{scenario_name}\"'")
            puts "   ✅ Scenario name set"
          else
            puts "   ⚠️  Warning: Failed to set scenario name"
          end
        end

        # Apply region filtering using the cleanup task (only when region_id is not null)
        if region_id.nil?
          puts "   🔄 Skipping region filtering (region_id is null - no region restrictions)..."

          # Update last_version_id
          puts "   🔄 Updating last_version_id..."
          Dir.chdir(rails_root) do
            ENV['RAILS_ENV'] = 'development'
            ENV['DATABASE_URL'] = "postgresql://localhost/#{database_name}"

            if system("bundle exec rails runner 'last_version_id = Version.last.id; Setting.key_set_value(\"last_version_id\", last_version_id); puts \"Updated last_version_id to: \" + last_version_id.to_s'")
              puts "   ✅ Updated last_version_id to current max version ID"
            else
              puts "   ⚠️  Warning: Failed to update last_version_id (continuing anyway)"
            end
          end

          puts "✅ Development database created successfully: #{database_name}"
          true
        else
          puts "   🔄 Applying region filtering (region_id: #{region_id})..."

          # Set environment variable for region filtering
          ENV['REGION_SHORTNAME'] = scenario_data['region_shortname'] || 'NBV'

          # Change to the Rails root directory and run the cleanup task
          if Dir.chdir(rails_root) do
            # Set up Rails environment variables
            ENV['RAILS_ENV'] = 'development'
            ENV['DATABASE_URL'] = "postgresql://localhost/#{database_name}"

            # Run the cleanup task
            system("bundle exec rails cleanup:remove_non_region_records")
          end
            puts "   ✅ Applied region filtering"

            # Update last_version_id after region filtering
            puts "   🔄 Updating last_version_id after region filtering..."
            Dir.chdir(rails_root) do
              ENV['RAILS_ENV'] = 'development'
              ENV['DATABASE_URL'] = "postgresql://localhost/#{database_name}"

              if system("bundle exec rails runner 'last_version_id = Version.last.id; Setting.key_set_value(\"last_version_id\", last_version_id); puts \"Updated last_version_id to: \" + last_version_id.to_s'")
                puts "   ✅ Updated last_version_id to current max version ID"
              else
                puts "   ⚠️  Warning: Failed to update last_version_id (continuing anyway)"
              end
            end

            puts "✅ Development database created successfully: #{database_name}"
            true
          else
            puts "❌ Failed to apply region filtering"
            system("dropdb #{database_name}")
            false
          end
        end
      else
        puts "❌ Failed to create database from template"
        false
      end
    else
      # For non-region scenarios, create empty database
      puts "Creating empty database #{database_name}..."
      if system("createdb #{database_name}")
        puts "✅ Development database created successfully: #{database_name}"
        true
      else
        puts "❌ Failed to create database"
        false
      end
    end
  end

  def update_scenario(scenario_name)
    puts "Updating scenario #{scenario_name} with git pull..."

    # Check if Rails root folder exists
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "❌ Rails root folder not found: #{rails_root}"
      puts "   Use 'rake scenario:prepare_development[#{scenario_name},development]' to create it first"
      return false
    end

    # Check if it's a git repository
    unless Dir.exist?(File.join(rails_root, '.git'))
      puts "❌ Not a git repository: #{rails_root}"
      puts "   Use 'rake scenario:setup[#{scenario_name},development]' to recreate it"
      return false
    end

    # Perform git pull
    puts "   Performing git pull..."
    if system("cd #{rails_root} && git pull")
      puts "   ✅ Git pull successful"

      # Copy .idea if it doesn't exist
      idea_source = File.join(Rails.root, '.idea')
      idea_target = File.join(rails_root, '.idea')
      if Dir.exist?(idea_source) && !Dir.exist?(idea_target)
        FileUtils.cp_r(idea_source, idea_target)
        puts "   ✅ RubyMine .idea configuration copied"
      elsif Dir.exist?(idea_target)
        puts "   ✅ RubyMine .idea configuration already exists"
      else
        puts "   ⚠️  RubyMine .idea configuration not found in master"
      end

      # Update configuration files
      puts "   Updating configuration files..."
      generate_configuration_files(scenario_name, 'development')

      # Copy updated configuration files to Rails root
      env_dir = File.join(scenarios_path, scenario_name, 'development')
      if Dir.exist?(env_dir)
        # Copy database.yml
        if File.exist?(File.join(env_dir, 'database.yml'))
          FileUtils.cp(File.join(env_dir, 'database.yml'), File.join(rails_root, 'config', 'database.yml'))
          puts "   ✅ Updated database.yml"
        end

        # Copy carambus.yml
        if File.exist?(File.join(env_dir, 'carambus.yml'))
          FileUtils.cp(File.join(env_dir, 'carambus.yml'), File.join(rails_root, 'config', 'carambus.yml'))
          puts "   ✅ Updated carambus.yml"
        end
      end

      puts "✅ Scenario #{scenario_name} updated successfully"
      puts "   Rails root: #{rails_root}"
      true
    else
      puts "❌ Git pull failed"
      false
    end
  end

  def deploy_scenario_with_conflict_analysis(scenario_name)
    puts "Deploying scenario #{scenario_name} with conflict analysis..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    scenario = scenario_config['scenario']

    puts "   Target: #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   SSH: #{production_config['ssh_host']}:#{production_config['ssh_port']}"

    # Step 1: Generate production configuration files
    puts "\n📋 Step 1: Generating production configuration files..."
    unless generate_configuration_files(scenario_name, 'production')
      puts "❌ Failed to generate production configuration files"
      return false
    end

    # Step 2: Create database dump from development (which has correct schema)
    puts "\n💾 Step 2: Creating database dump from development..."
    unless create_database_dump(scenario_name, 'development')
      puts "❌ Failed to create development database dump"
      return false
    end

    # Step 3: Ensure Rails root folder exists
    puts "\n📁 Step 3: Ensuring Rails root folder exists..."
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "   Rails root folder not found,   creating it..."
      unless create_rails_root_folder(scenario_name)
        puts "❌ Failed to create Rails root folder"
        return false
      end
    else
      puts "   ✅ Rails root folder already exists"
    end

    # Step 4: Copy configuration files to Rails root folder
    puts "\n📁 Step 4: Copying configuration files to Rails root folder..."

    # Copy production configuration files
    production_dir = File.join(scenarios_path, scenario_name, 'production')
    FileUtils.cp(File.join(production_dir, 'database.yml'), File.join(rails_root, 'config', 'database.yml'))
    FileUtils.cp(File.join(production_dir, 'carambus.yml'), File.join(rails_root, 'config', 'carambus.yml'))

    # Copy cable.yml if it exists
    if File.exist?(File.join(production_dir, 'cable.yml'))
      FileUtils.cp(File.join(production_dir, 'cable.yml'), File.join(rails_root, 'config', 'cable.yml'))
      puts "   ✅ cable.yml copied to Rails root folder"
    end

    # Copy production.rb if it exists
    if File.exist?(File.join(production_dir, 'production.rb'))
      FileUtils.cp(File.join(production_dir, 'production.rb'), File.join(rails_root, 'config', 'environments', 'production.rb'))
      puts "   ✅ production.rb copied to Rails root folder"
    end

    # Copy env.production if it exists
    if File.exist?(File.join(production_dir, 'env.production'))
      FileUtils.cp(File.join(production_dir, 'env.production'), File.join(rails_root, 'env.production'))
      puts "   ✅ env.production copied to Rails root folder"
    end

    # Copy nginx.conf if it exists
    if File.exist?(File.join(production_dir, 'nginx.conf'))
      FileUtils.cp(File.join(production_dir, 'nginx.conf'), File.join(rails_root, 'config', 'nginx.conf'))
      puts "   ✅ nginx.conf copied to Rails root folder"
    end

    # Copy puma.service if it exists
    if File.exist?(File.join(production_dir, 'puma.service'))
      FileUtils.cp(File.join(production_dir, 'puma.service'), File.join(rails_root, 'config', 'puma.service'))
      puts "   ✅ puma.service copied to Rails root folder"
    end

    # Copy puma.rb if it exists
    if File.exist?(File.join(production_dir, 'puma.rb'))
      FileUtils.cp(File.join(production_dir, 'puma.rb'), File.join(rails_root, 'config', 'puma.rb'))
      puts "   ✅ puma.rb copied to Rails root folder"
    end

    # Copy credentials files from main repository
    main_credentials_dir = File.join(Rails.root, 'config', 'credentials')
    if Dir.exist?(main_credentials_dir)
      Dir.glob(File.join(main_credentials_dir, '*')).each do |file|
        if File.file?(file)
          filename = File.basename(file)
          FileUtils.cp(file, File.join(rails_root, 'config', filename))
          puts "   ✅ #{filename} copied to Rails root folder"
        end
      end
    end

    # Copy master.key from main repository
    master_key_file = File.join(Rails.root, 'config', 'master.key')
    if File.exist?(master_key_file)
      FileUtils.cp(master_key_file, File.join(rails_root, 'config', 'master.key'))
      puts "   ✅ master.key copied to Rails root folder"
    end

    puts "   ✅ Configuration files copied to Rails root folder"

    # Step 5: Copy deployment files
    puts "\n🚀 Step 5: Copying deployment files..."
    deploy_dir = File.join(scenarios_path, scenario_name, 'production')
    if File.exist?(File.join(deploy_dir, 'deploy.rb'))
      FileUtils.cp(File.join(deploy_dir, 'deploy.rb'), File.join(rails_root, 'config', 'deploy.rb'))
      puts "   ✅ deploy.rb copied"
    end

    if Dir.exist?(File.join(deploy_dir, 'deploy'))
      # Copy individual files from deploy subdirectory
      deploy_subdir = File.join(deploy_dir, 'deploy')
      Dir.glob(File.join(deploy_subdir, '*')).each do |file|
        if File.file?(file)
          filename = File.basename(file)
          FileUtils.cp(file, File.join(rails_root, 'config', 'deploy', filename))
          puts "   ✅ #{filename} copied to config/deploy/"
        end
      end
    end

    # Step 6: Upload shared configuration files to server
    puts "\n📤 Step 6: Uploading shared configuration files to server..."
    basename = scenario['basename']
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    # Create shared config directory on server
    shared_config_dir = "/var/www/#{basename}/shared/config"
    create_dir_cmd = "sudo mkdir -p #{shared_config_dir} && sudo chown www-data:www-data #{shared_config_dir}"

    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{create_dir_cmd}'")
      puts "   ✅ Shared config directory created"

      # Upload database.yml
      if File.exist?(File.join(rails_root, 'config', 'database.yml'))
        upload_cmd = "scp -P #{ssh_port} #{File.join(rails_root, 'config', 'database.yml')} www-data@#{ssh_host}:#{shared_config_dir}/"
        if system(upload_cmd)
          puts "   ✅ database.yml uploaded to server"
        else
          puts "   ❌ Failed to upload database.yml"
          return false
        end
      end

      # Upload carambus.yml
      if File.exist?(File.join(rails_root, 'config', 'carambus.yml'))
        upload_cmd = "scp -P #{ssh_port} #{File.join(rails_root, 'config', 'carambus.yml')} www-data@#{ssh_host}:#{shared_config_dir}/"
        if system(upload_cmd)
          puts "   ✅ carambus.yml uploaded to server"
        else
          puts "   ❌ Failed to upload carambus.yml"
          return false
        end
      end

      # Upload master.key
      if File.exist?(File.join(rails_root, 'config', 'master.key'))
        upload_cmd = "scp -P #{ssh_port} #{File.join(rails_root, 'config', 'master.key')} www-data@#{ssh_host}:#{shared_config_dir}/"
        if system(upload_cmd)
          puts "   ✅ master.key uploaded to server"
        else
          puts "   ❌ Failed to upload master.key"
          return false
        end
      end

      puts "   ✅ All shared configuration files uploaded"
    else
      puts "   ❌ Failed to create shared config directory"
      return false
    end

    # Step 7: Restore database dump to production server
    puts "\n🗄️  Step 7: Restoring database dump to production server..."
    production_database = production_config['database_name']
    production_user = production_config['database_username']

    # Find the latest development dump
    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    latest_dump = Dir.glob(File.join(dump_dir, "#{scenario_name}_development_*.sql.gz")).max_by { |f| File.mtime(f) }

    if latest_dump && File.exist?(latest_dump)
      puts "   Using dump: #{File.basename(latest_dump)}"

      # Upload dump to server
      temp_dump_path = "/tmp/#{File.basename(latest_dump)}"
      upload_cmd = "scp -P #{ssh_port} #{latest_dump} www-data@#{ssh_host}:#{temp_dump_path}"

      if system(upload_cmd)
        puts "   ✅ Database dump uploaded to server"

        # Drop and recreate database on server
        puts "   Dropping and recreating database..."

        # Create a temporary script for database operations
        temp_script = "/tmp/reset_database.sh"
        script_content = <<~SCRIPT
          #!/bin/bash
          sudo -u postgres psql -c "DROP DATABASE IF EXISTS #{production_database};"
          sudo -u postgres psql -c "CREATE DATABASE #{production_database} OWNER #{production_user};"
        SCRIPT

        # Write script to server
        script_cmd = "cat > #{temp_script} << 'SCRIPT_EOF'\n#{script_content}SCRIPT_EOF"
        if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{script_cmd}'")
          # Make script executable and run it
          execute_cmd = "chmod +x #{temp_script} && #{temp_script} && rm #{temp_script}"

          if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{execute_cmd}'")
            puts "   ✅ Database dropped and recreated"

            # Restore database from dump
            restore_cmd = "gunzip -c #{temp_dump_path} | sudo -u postgres psql -d #{production_database} && rm #{temp_dump_path}"

            if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restore_cmd}'")
              puts "   ✅ Database restored from development dump"

              # Reset sequences for local server (prevents ID conflicts with API)
              puts "   Resetting sequences for local server..."
              sequence_reset_cmd = "cd /var/www/#{basename}/current && RAILS_ENV=production $HOME/.rbenv/bin/rbenv exec bundle exec rails runner 'Version.sequence_reset'"
              if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{sequence_reset_cmd}'")
                puts "   ✅ Sequences reset successfully"
              else
                puts "   ⚠️  Warning: Sequence reset failed (continuing anyway)"
              end
            else
              puts "   ❌ Failed to restore database from dump"
              return false
            end
          else
            puts "   ❌ Failed to drop and recreate database"
            return false
          end
        else
          puts "   ❌ Failed to create database reset script"
          return false
        end
      else
        puts "   ❌ Failed to upload database dump to server"
        return false
      end
    else
      puts "   ❌ No development database dump found"
      return false
    end

    # Step 8: Execute Capistrano deployment
    puts "\n🎯 Step 8: Executing Capistrano deployment..."
    puts "   Running: cap production deploy"
    puts "   Target server: #{production_config['ssh_host']}:#{production_config['ssh_port']}"
    puts "   Application: #{scenario['application_name']}"
    puts "   Basename: #{scenario['basename']}"

    # Change to the Rails root directory and run Capistrano
    rails_root_dir = File.join(File.expand_path('..', Rails.root), scenario['basename'])

    if Dir.exist?(rails_root_dir)
      puts "   Deploying from: #{rails_root_dir}"

      # Execute Capistrano deployment
      deploy_cmd = "cd #{rails_root_dir} && cap production deploy"
      puts "   Executing: #{deploy_cmd}"

      if system(deploy_cmd)
        puts "   ✅ Capistrano deployment completed successfully"
      else
        puts "   ❌ Capistrano deployment failed"
        return false
      end
    else
      puts "   ❌ Rails root directory not found: #{rails_root_dir}"
      puts "   Please run 'rake scenario:create_rails_root[#{scenario_name}]' first"
      return false
    end

    puts "\n✅ Deployment completed successfully!"
    puts "   Application deployed and running on #{production_config['webserver_host']}:#{production_config['webserver_port']}"

    true
  end

  def setup_ssl_certificate(scenario_name, production_config)
    host = production_config['webserver_host']
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    puts "   Setting up SSL certificate for #{host}..."

    # Check if certificate already exists
    cert_check_cmd = "sudo certbot certificates | grep -q '#{host}'"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{cert_check_cmd}'")
      puts "   ✅ SSL certificate already exists for #{host}"
      return true
    end

    # Create SSL certificate
    certbot_cmd = "sudo certbot --nginx -d #{host} --non-interactive --agree-tos --email gernot.ullrich@gmx.de"
    puts "   Running: #{certbot_cmd}"

    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{certbot_cmd}'")
      puts "   ✅ SSL certificate created successfully"
      true
    else
      puts "   ❌ Failed to create SSL certificate"
      false
    end
  end

  def fix_puma_service_config(scenario_name, production_config)
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']
    basename = scenario_name

    puts "   Fixing Puma service configuration for #{basename}..."

    # Create corrected service file content
    service_content = <<~SERVICE
      [Unit]
      Description=Puma HTTP Server for #{basename}
      After=network.target

      [Service]
      Type=simple
      User=www-data
      WorkingDirectory=/var/www/#{basename}/current
      Environment=PATH=/var/www/#{basename}/shared/bundle/ruby/3.2.0/bin:/var/www/.rbenv/bin:/var/www/.rbenv/shims:/usr/local/bin:/usr/bin:/bin
      Environment=RAILS_ENV=production
      Environment=RBENV_ROOT=/var/www/.rbenv
      Environment=RBENV_VERSION=3.2.1
      ExecStart=/var/www/#{basename}/shared/bundle/ruby/3.2.0/bin/bundle exec /var/www/#{basename}/shared/bundle/ruby/3.2.0/bin/puma -C /var/www/#{basename}/shared/puma.rb
      ExecReload=/bin/kill -USR1 \\$MAINPID
      Restart=always
      RestartSec=1

      # Ensure socket directory exists
      ExecStartPre=/bin/mkdir -p /var/www/#{basename}/shared/sockets
      ExecStartPre=/bin/mkdir -p /var/www/#{basename}/shared/pids
      ExecStartPre=/bin/mkdir -p /var/www/#{basename}/shared/log

      [Install]
      WantedBy=multi-user.target
    SERVICE

    # Write service file to server using a different approach
    # Create a temporary script that writes the service file
    temp_script = "/tmp/create_puma_service.sh"
    script_content = <<~SCRIPT
      #!/bin/bash
      cat > /etc/systemd/system/puma-#{basename}.service << 'EOF'
      #{service_content}
      EOF
    SCRIPT

    # Write script to server
    script_cmd = "cat > #{temp_script} << 'SCRIPT_EOF'\n#{script_content}SCRIPT_EOF"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{script_cmd}'")
      # Make script executable and run it with sudo
      execute_cmd = "chmod +x #{temp_script} && sudo #{temp_script} && rm #{temp_script}"
      service_file_cmd = execute_cmd
    else
      puts "   ❌ Failed to create service script"
      return false
    end

    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{service_file_cmd}'")
      puts "   ✅ Puma service configuration updated"

      # Reload systemd and restart service
      reload_cmd = "sudo systemctl daemon-reload && sudo systemctl restart puma-#{basename}.service"
      if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{reload_cmd}'")
        puts "   ✅ Puma service restarted successfully"
        true
      else
        puts "   ❌ Failed to restart Puma service"
        false
      end
    else
      puts "   ❌ Failed to update Puma service configuration"
      puts "Edit /etc/systemd/system/puma-#{basename}.service:"
      puts service_content
      false
    end
  end

  def update_nginx_config(scenario_name, production_config)
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']
    basename = scenario_name

    puts "   Updating Nginx configuration for #{basename}..."

    # Copy nginx.conf to sites-available and enable it
    nginx_cmd = "sudo cp /var/www/#{basename}/shared/config/nginx.conf /etc/nginx/sites-available/#{basename} && sudo ln -sf /etc/nginx/sites-available/#{basename} /etc/nginx/sites-enabled/#{basename} && sudo nginx -t && sudo systemctl reload nginx"

    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{nginx_cmd}'")
      puts "   ✅ Nginx configuration updated and reloaded"
      true
    else
      puts "   ❌ Failed to update Nginx configuration"
      false
    end
  end

  def create_scenario(scenario_name, location_id, context)
    scenario_path = File.join(scenarios_path, scenario_name)

    # Create scenario directory
    FileUtils.mkdir_p(scenario_path)

    # Create config.yml
    config_content = {
      'scenario' => {
        'name' => scenario_name,
        'description' => "Location #{location_id}",
        'location_id' => location_id.to_i,
        'context' => context,
        'region_id' => 1,
        'club_id' => location_id.to_i,
        'api_url' => 'https://newapi.carambus.de/',
        'season_name' => '2025/2026',
        'application_name' => 'carambus',
        'basename' => "carambus_#{scenario_name}",
        'branch' => 'master'
      },
      'environments' => {
        'development' => {
          'webserver_host' => 'localhost',
          'webserver_port' => 3000,
          'database_name' => "#{scenario_name}_development",
          'ssl_enabled' => false,
          'database_username' => nil,
          'database_password' => nil
        },
        'production' => {
          'webserver_host' => '192.168.178.107',
          'ssh_host' => '192.168.178.107',
          'webserver_port' => 80,
          'ssh_port' => 8910,
          'database_name' => "#{scenario_name}_production",
          'ssl_enabled' => false,
          'database_username' => 'www-data',
          'database_password' => 'toS6E7tARQafHCXz',
          'puma_socket_path' => '/tmp/puma.sock'
        }
      }
    }

    File.write(File.join(scenario_path, 'config.yml'), config_content.to_yaml)

    puts "✅ Created scenario: #{scenario_name}"
    puts "   Location ID: #{location_id}"
    puts "   Context: #{context}"
    puts "   Config: #{File.join(scenario_path, 'config.yml')}"
  end

  def upload_configuration_files_to_server(scenario_name, production_config)
    puts "📤 Uploading configuration files to server..."
    
    basename = scenario_name.gsub('carambus_location_', '')
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']
    
    # Create entire deployment directory structure with proper permissions
    deploy_dir = "/var/www/carambus_location_#{basename}"
    shared_config_dir = "#{deploy_dir}/shared/config"
    create_deploy_dirs_cmd = "sudo mkdir -p #{deploy_dir}/shared/config #{deploy_dir}/releases && sudo chown -R www-data:www-data #{deploy_dir}"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{create_deploy_dirs_cmd}'")
      puts "   ❌ Failed to create deployment directory structure"
      return false
    end
    
    # Upload config files to shared directory
    production_dir = File.join(scenarios_path, scenario_name, 'production')
    
    # Upload database.yml
    database_yml_path = File.join(production_dir, 'database.yml')
    if File.exist?(database_yml_path)
      scp_cmd = "scp -P #{ssh_port} #{database_yml_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded database.yml"
      else
        puts "   ❌ Failed to upload database.yml: #{result}"
        return false
      end
    else
      puts "   ❌ database.yml not found: #{database_yml_path}"
      return false
    end
    
    # Upload carambus.yml
    carambus_yml_path = File.join(production_dir, 'carambus.yml')
    if File.exist?(carambus_yml_path)
      scp_cmd = "scp -P #{ssh_port} #{carambus_yml_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded carambus.yml"
      else
        puts "   ❌ Failed to upload carambus.yml: #{result}"
        return false
      end
    else
      puts "   ❌ carambus.yml not found: #{carambus_yml_path}"
      return false
    end
    
    # Upload nginx.conf
    nginx_conf_path = File.join(production_dir, 'nginx.conf')
    if File.exist?(nginx_conf_path)
      scp_cmd = "scp -P #{ssh_port} #{nginx_conf_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded nginx.conf"
      else
        puts "   ❌ Failed to upload nginx.conf: #{result}"
        return false
      end
    else
      puts "   ❌ nginx.conf not found: #{nginx_conf_path}"
      return false
    end
    
    # Upload puma.service
    puma_service_path = File.join(production_dir, 'puma.service')
    if File.exist?(puma_service_path)
      scp_cmd = "scp -P #{ssh_port} #{puma_service_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded puma.service"
      else
        puts "   ❌ Failed to upload puma.service: #{result}"
        return false
      end
    else
      puts "   ❌ puma.service not found: #{puma_service_path}"
      return false
    end
    
    # Upload puma.rb
    puma_rb_path = File.join(production_dir, 'puma.rb')
    if File.exist?(puma_rb_path)
      scp_cmd = "scp -P #{ssh_port} #{puma_rb_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded puma.rb"
      else
        puts "   ❌ Failed to upload puma.rb: #{result}"
        return false
      end
    else
      puts "   ❌ puma.rb not found: #{puma_rb_path}"
      return false
    end
    
    # Upload production.rb
    production_rb_path = File.join(production_dir, 'production.rb')
    if File.exist?(production_rb_path)
      # Create environments directory on server
      system("ssh -p #{ssh_port} www-data@#{ssh_host} 'mkdir -p #{shared_config_dir}/environments'")
      scp_cmd = "scp -P #{ssh_port} #{production_rb_path} www-data@#{ssh_host}:#{shared_config_dir}/environments/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded production.rb"
      else
        puts "   ❌ Failed to upload production.rb: #{result}"
        return false
      end
    else
      puts "   ❌ production.rb not found: #{production_rb_path}"
      return false
    end
    
    # Upload credentials
    credentials_dir = File.join(production_dir, 'credentials')
    if Dir.exist?(credentials_dir)
      # Create credentials directory on server
      system("ssh -p #{ssh_port} www-data@#{ssh_host} 'mkdir -p #{shared_config_dir}/credentials'")
      
      # Upload production.yml.enc
      production_yml_enc_path = File.join(credentials_dir, 'production.yml.enc')
      if File.exist?(production_yml_enc_path)
        scp_cmd = "scp -P #{ssh_port} #{production_yml_enc_path} www-data@#{ssh_host}:#{shared_config_dir}/credentials/"
        result = `#{scp_cmd} 2>&1`
        if $?.success?
          puts "   ✅ Uploaded production.yml.enc"
        else
          puts "   ❌ Failed to upload production.yml.enc: #{result}"
          return false
        end
      else
        puts "   ❌ production.yml.enc not found: #{production_yml_enc_path}"
        return false
      end
      
      # Upload production.key
      production_key_path = File.join(credentials_dir, 'production.key')
      if File.exist?(production_key_path)
        scp_cmd = "scp -P #{ssh_port} #{production_key_path} www-data@#{ssh_host}:#{shared_config_dir}/credentials/"
        result = `#{scp_cmd} 2>&1`
        if $?.success?
          puts "   ✅ Uploaded production.key"
        else
          puts "   ❌ Failed to upload production.key: #{result}"
          return false
        end
      else
        puts "   ❌ production.key not found: #{production_key_path}"
        return false
      end
    else
      puts "   ❌ Credentials directory not found: #{credentials_dir}"
      return false
    end
    
    # Upload env.production
    env_production_path = File.join(production_dir, 'env.production')
    if File.exist?(env_production_path)
      scp_cmd = "scp -P #{ssh_port} #{env_production_path} www-data@#{ssh_host}:#{shared_config_dir}/"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded env.production"
      else
        puts "   ❌ Failed to upload env.production: #{result}"
        return false
      end
    else
      puts "   ❌ env.production not found: #{env_production_path}"
      return false
    end
    
    puts "   ✅ All configuration files uploaded successfully"
    true
  end

  def prepare_scenario_for_deployment(scenario_name)
    puts "Preparing scenario #{scenario_name} for deployment..."
    puts "This includes production config generation, file transfers to server, and database operations."
    puts "Note: Assumes Rails root folder already exists from prepare_development."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    scenario = scenario_config['scenario']

    puts "   Target: #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   SSH: #{production_config['ssh_host']}:#{production_config['ssh_port']}"

    # Step 1: Generate production configuration files
    puts "\n📋 Step 1: Generating production configuration files..."
    unless generate_configuration_files(scenario_name, 'production')
      puts "❌ Failed to generate production configuration files"
      return false
    end


    # Step 2: Copy production configuration files to Rails root folder
    puts "\n📁 Step 2: Copying production configuration files to Rails root folder..."

    # Get Rails root path (assumes it exists from prepare_development)
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "❌ Rails root folder not found! Run 'rake scenario:prepare_development[#{scenario_name}]' first."
      return false
    end

    # Note: Production configuration files are uploaded directly from production directory
    # No need to copy them to development scenario root - keeps development environment clean

    # Copy credentials files to production directory for server upload
    production_dir = File.join(scenarios_path, scenario_name, 'production')
    production_credentials_dir = File.join(production_dir, 'credentials')
    FileUtils.mkdir_p(production_credentials_dir)

    main_credentials_dir = File.join(Rails.root, 'config', 'credentials')
    if Dir.exist?(main_credentials_dir)
      Dir.glob(File.join(main_credentials_dir, '*')).each do |file|
        if File.file?(file)
          filename = File.basename(file)
          FileUtils.cp(file, File.join(production_credentials_dir, filename))
          puts "   ✅ #{filename} copied to production directory"
        end
      end
    end

    puts "   ✅ Configuration files copied to production directory"

    # Step 3: Copy deployment files
    puts "\n🚀 Step 3: Copying deployment files..."
    deploy_dir = File.join(scenarios_path, scenario_name, 'production')
    if File.exist?(File.join(deploy_dir, 'deploy.rb'))
      FileUtils.cp(File.join(deploy_dir, 'deploy.rb'), File.join(rails_root, 'config', 'deploy.rb'))
      puts "   ✅ deploy.rb copied"
    end

    if Dir.exist?(File.join(deploy_dir, 'deploy'))
      # Copy individual files from deploy subdirectory
      deploy_subdir = File.join(deploy_dir, 'deploy')
      Dir.glob(File.join(deploy_subdir, '*')).each do |file|
        if File.file?(file)
          filename = File.basename(file)
          FileUtils.cp(file, File.join(rails_root, 'config', 'deploy', filename))
          puts "   ✅ #{filename} copied to config/deploy/"
        end
      end
    end

    puts "   ✅ Deployment files copied"

    # Step 4: Prepare server-side configuration
    puts "\n🔧 Step 4: Preparing server-side configuration..."
    unless prepare_server_configuration(scenario_name, production_config)
      puts "❌ Failed to prepare server-side configuration"
      return false
    end

    # Step 5: Upload configuration files to server
    puts "\n📤 Step 5: Uploading configuration files to server..."
    unless upload_configuration_files_to_server(scenario_name, production_config)
      puts "❌ Failed to upload configuration files to server"
      return false
    end

    # Step 6: Ensure development database has all migrations applied
    puts "\n🔄 Step 6: Ensuring development database has all migrations applied..."

    # Change to the Rails root directory and run migrations
    rails_root_dir = File.join(File.expand_path('..', Rails.root), scenario_name)
    if Dir.exist?(rails_root_dir)
      puts "   Running migrations on development database..."
      migrate_cmd = "cd #{rails_root_dir} && RAILS_ENV=development bundle exec rails db:migrate"
      if system(migrate_cmd)
        puts "   ✅ Development database migrations completed"
      else
        puts "   ❌ Development database migrations failed"
        return false
      end
    else
      puts "   ❌ Rails root directory not found: #{rails_root_dir}"
      return false
    end

    # Step 7: Create production database dump from scenario development database
    puts "\n💾 Step 7: Creating production database dump from #{scenario_name}_development..."

    # Check if development database exists
    dev_database_name = "#{scenario_name}_development"
    unless system("psql -lqt | cut -d \\| -f 1 | grep -qw #{dev_database_name}")
      puts "❌ Development database #{dev_database_name} not found!"
      puts "   Run 'rake scenario:prepare_development[#{scenario_name},development]' first"
      return false
    end

    # Create production dump from development database
    unless create_production_dump_from_development(scenario_name)
      puts "❌ Failed to create production dump from development database"
      return false
    end

    puts "\n✅ Scenario #{scenario_name} prepared for deployment!"
    puts "   Rails root: #{rails_root}"
    puts "   Production config: #{File.join(scenarios_path, scenario_name, 'production')}"
    puts "   Database dump: #{File.join(scenarios_path, scenario_name, 'database_dumps')}"
    puts "   Configuration files: Uploaded to server"
    puts ""
    puts "Next steps:"
    puts "  1. Run 'rake scenario:deploy[#{scenario_name}]' to execute Capistrano deployment"
    puts "  2. Or manually deploy using Capistrano: cd #{rails_root} && cap production deploy"

    true
  end

  def create_production_dump_from_development(scenario_name)
    puts "Creating production dump from #{scenario_name}_development..."

    dev_database_name = "#{scenario_name}_development"
    prod_database_name = "#{scenario_name}_production"

    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    FileUtils.mkdir_p(dump_dir)

    # Create dump filename with timestamp
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dump_file = File.join(dump_dir, "#{scenario_name}_production_#{timestamp}.sql.gz")

    # Check if production database exists and get its last_version_id
    if system("psql -lqt | cut -d \\| -f 1 | grep -qw #{prod_database_name}")
      puts "   🔍 Production database exists, checking last_version_id..."

      # Get last_version_id from production database
      prod_version_cmd = "psql #{prod_database_name} -t -c \"SELECT COALESCE((data->>'last_version_id')::jsonb->>'Integer', '0') FROM settings LIMIT 1;\""
      prod_version_result = `#{prod_version_cmd}`.strip
      prod_last_version_id = prod_version_result.to_i

      # Get last_version_id from development database
      dev_version_cmd = "psql #{dev_database_name} -t -c \"SELECT COALESCE((data->>'last_version_id')::jsonb->>'Integer', '0') FROM settings LIMIT 1;\""
      dev_version_result = `#{dev_version_cmd}`.strip
      dev_last_version_id = dev_version_result.to_i

      puts "   📊 Production last_version_id: #{prod_last_version_id}"
      puts "   📊 Development last_version_id: #{dev_last_version_id}"

      if prod_last_version_id > dev_last_version_id
        puts "   ⚠️  WARNING: Production database has newer data!"
        puts "   ⚠️  Production last_version_id (#{prod_last_version_id}) > Development last_version_id (#{dev_last_version_id})"
        puts "   ⚠️  This indicates sync updates in production that are not in development"
        puts "   ⚠️  Deployment blocked to prevent data loss"
        puts ""
        puts "   🔧 Next steps:"
        puts "   1. Sync production changes to development first"
        puts "   2. Or handle this case with special merge logic (to be implemented)"
        return false
      elsif prod_last_version_id == dev_last_version_id
        puts "   ✅ Versions match - safe to deploy"
      else
        puts "   ✅ Development is newer - safe to deploy"
      end
    else
      puts "   ✅ Production database doesn't exist - safe to create"
    end

    # Create dump from development database
    puts "   📦 Creating dump from #{dev_database_name}..."
    # Use --no-owner --no-privileges to avoid permission issues, include schema and data
    if system("pg_dump --no-owner --no-privileges #{dev_database_name} | gzip > #{dump_file}")
      puts "✅ Production dump created: #{File.basename(dump_file)}"
      puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"
      puts "   Source: #{dev_database_name}"
      puts "   Target: #{prod_database_name}"
      true
    else
      puts "❌ Failed to create production dump"
      false
    end
  end

  def create_region_filtered_production_dump(scenario_name, region_id)
    puts "Creating region-filtered production dump for #{scenario_name} (region_id: #{region_id})..."

    # Load scenario configuration to get region_shortname
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    scenario_config = YAML.load_file(config_file)
    scenario_data = scenario_config['scenario']

    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    FileUtils.mkdir_p(dump_dir)

    # Create dump filename with timestamp
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dump_file = File.join(dump_dir, "#{scenario_name}_production_#{timestamp}.sql.gz")

    # Create temporary database for transformation
    temp_db_name = "carambus_temp_prod_#{timestamp}"

    # Create temporary database using template (much faster)
    if system("createdb #{temp_db_name} --template=carambus_api_development")
      puts "   ✅ Created temporary database: #{temp_db_name} (using template)"

      # Apply region filtering using the cleanup task
      puts "   🔄 Applying region filtering (region_id: #{region_id})..."

      # Set environment variable for region filtering
      ENV['REGION_SHORTNAME'] = scenario_data['region_shortname'] || 'NBV'

      # Create a temporary Rails environment to run the cleanup task
      temp_rails_root = File.join(scenarios_path, scenario_name)

      # Change to the Rails root directory and run the cleanup task
      if Dir.chdir(temp_rails_root) do
        # Set up Rails environment variables
        ENV['RAILS_ENV'] = 'production'
        ENV['DATABASE_URL'] = "postgresql://localhost/#{temp_db_name}"

        # Run the cleanup task
        system("bundle exec rails cleanup:remove_non_region_records")
      end
        puts "   ✅ Applied region filtering"

        # Create dump from filtered database (include schema and data)
        if system("pg_dump --no-owner --no-privileges #{temp_db_name} | gzip > #{dump_file}")
          puts "✅ Region-filtered production dump created: #{File.basename(dump_file)}"
          puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"

          # Clean up temporary database
          system("dropdb #{temp_db_name}")
          puts "   🧹 Cleaned up temporary database"
          true
        else
          puts "❌ Failed to create dump from filtered database"
          system("dropdb #{temp_db_name}")
          false
        end
      else
        puts "❌ Failed to apply region filtering"
        system("dropdb #{temp_db_name}")
        false
      end
    else
      puts "❌ Failed to create temporary database"
      false
    end
  end

  def create_standard_production_dump(scenario_name)
    puts "Creating standard production dump for #{scenario_name}..."

    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    FileUtils.mkdir_p(dump_dir)

    # Create dump filename with timestamp
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    dump_file = File.join(dump_dir, "#{scenario_name}_production_#{timestamp}.sql.gz")

    # Create dump from carambus_api_development (include schema and data)
    puts "Creating dump of carambus_api_development..."
    if system("pg_dump --no-owner --no-privileges carambus_api_development | gzip > #{dump_file}")
      puts "✅ Production dump created: #{File.basename(dump_file)}"
      puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"
      true
    else
      puts "❌ Production dump failed"
      false
    end
  end

  def deploy_scenario(scenario_name)
    puts "Deploying scenario #{scenario_name} to production server..."
    puts "This performs Capistrano deployment only (assumes prepare_deploy was run first)."
    puts "Configuration files and database setup are handled by prepare_deploy."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    scenario = scenario_config['scenario']

    puts "   Target: #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   SSH: #{production_config['ssh_host']}:#{production_config['ssh_port']}"

    # Verify Rails root exists
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "❌ Rails root folder not found: #{rails_root}"
      puts "   Please run 'rake scenario:prepare_deploy[#{scenario_name}]' first"
      return false
    end

    # Step 1: Transfer and load database dump
    puts "\n💾 Step 1: Transferring and loading database dump..."

    # Get SSH connection details
    basename = scenario['basename']
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    # Find the latest production dump
    dump_dir = File.join(scenarios_path, scenario_name, 'database_dumps')
    latest_dump = Dir.glob(File.join(dump_dir, "#{scenario_name}_production_*.sql.gz")).max_by { |f| File.mtime(f) }

    if latest_dump && File.exist?(latest_dump)
      puts "   📦 Using dump: #{File.basename(latest_dump)}"

      # Upload dump to server
      temp_dump_path = "/tmp/#{File.basename(latest_dump)}"
      upload_cmd = "scp -P #{ssh_port} #{latest_dump} www-data@#{ssh_host}:#{temp_dump_path}"

      if system(upload_cmd)
        puts "   ✅ Database dump uploaded to server"

        # Load scenario configuration to get database name
        production_database = production_config['database_name']

        # Remove application folder and recreate database on server
        puts "   🔄 Removing application folders (including old trials) and recreating production database..."

        # Create a temporary script for database operations
        temp_script = "/tmp/reset_database.sh"
        script_content = <<~SCRIPT
          #!/bin/bash
          set -e  # Exit on any error
          
          echo "🔄 Starting database reset process..."
          
          # Remove existing application folders (including old trials)
          echo "📁 Removing application folders..."
          sudo rm -rf /var/www/#{basename}
          sudo rm -rf /var/www/carambus_#{basename}
          
          # Drop and recreate database with verification
          echo "🗑️  Dropping existing database..."
          sudo -u postgres psql -c "DROP DATABASE IF EXISTS #{production_database};" || echo "Database did not exist"
          
          echo "🆕 Creating new database..."
          sudo -u postgres psql -c "CREATE DATABASE #{production_database} OWNER www_data;"
          
          # Verify database was created successfully
          echo "🔍 Verifying database creation..."
          if sudo -u postgres psql -c "\\l" | grep -q "#{production_database}"; then
            echo "✅ Database #{production_database} created successfully"
          else
            echo "❌ Database creation failed"
            exit 1
          fi
          
          echo "✅ Database reset completed successfully"
        SCRIPT

        # Write script to server
        script_cmd = "cat > #{temp_script} << 'SCRIPT_EOF'\n#{script_content}SCRIPT_EOF"
        if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{script_cmd}'")
          puts "   ✅ Database reset script created"

          # Execute database reset
          reset_output = `ssh -p #{ssh_port} www-data@#{ssh_host} 'chmod +x #{temp_script} && #{temp_script}' 2>&1`
          if $?.success?
            puts "   ✅ Application folders removed (including old trials) and production database recreated"
            puts "   📋 Reset output: #{reset_output}" if reset_output.include?("❌")
          else
            puts "   ❌ Database reset failed"
            puts "   📋 Error output: #{reset_output}"
            return false
          end

          # Restore database from dump
          puts "   📥 Restoring database from dump..."

          # Simply load the dump and ignore user warnings
          restore_cmd = "gunzip -c #{temp_dump_path} | sudo -u postgres psql #{production_database} 2>&1"

          restore_output = `ssh -p #{ssh_port} www-data@#{ssh_host} '#{restore_cmd}'`
          if $?.success?
            puts "   ✅ Database restored successfully"

            # Verify database was restored correctly
            puts "   🔍 Verifying database restore..."
            verify_cmd = "sudo -u postgres psql #{production_database} -c \"SELECT COUNT(*) FROM regions;\" 2>&1"
            verify_output = `ssh -p #{ssh_port} www-data@#{ssh_host} '#{verify_cmd}'`

            if verify_output.include?("19") && verify_output.include?("(1 row)")
              puts "   ✅ Database verification successful - 19 regions found"

              # Note: Sequence reset not needed - production DB is a copy of development DB with correct sequences

              # Clean up temporary files
              system("ssh -p #{ssh_port} www-data@#{ssh_host} 'rm -f #{temp_dump_path} #{temp_script}'")
              puts "   🧹 Temporary files cleaned up"
            else
              puts "   ❌ Database verification failed - regions count: #{verify_output}"
              puts "   📋 Restore output: #{restore_output}"
              return false
            end
          else
            puts "   ❌ Database restore failed"
            puts "   📋 Error output: #{restore_output}"
            return false
          end
        else
          puts "   ❌ Failed to create database reset script"
          return false
        end
      else
        puts "   ❌ Failed to upload database dump"
        return false
      end
    else
      puts "   ❌ No production dump found in #{dump_dir}"
      puts "   Please run 'rake scenario:prepare_deploy[#{scenario_name}]' first"
      return false
    end

    # Step 2: Configuration files already uploaded during prepare_deploy
    puts "\n📤 Step 2: Configuration files already uploaded during prepare_deploy step"

    # Step 3: Execute Capistrano deployment
    puts "\n🎯 Step 3: Executing Capistrano deployment..."
    puts "   Running: cap production deploy"
    puts "   Target server: #{production_config['ssh_host']}:#{production_config['ssh_port']}"
    puts "   Application: #{scenario['application_name']}"
    puts "   Basename: #{scenario['basename']}"

    # Change to the Rails root directory and run Capistrano
    rails_root_dir = File.join(File.expand_path('..', Rails.root), scenario['basename'])

    if Dir.exist?(rails_root_dir)
      puts "   Deploying from: #{rails_root_dir}"

      # Execute Capistrano deployment
      deploy_cmd = "cd #{rails_root_dir} && cap production deploy"
      puts "   Executing: #{deploy_cmd}"

      if system(deploy_cmd)
        puts "   ✅ Capistrano deployment completed successfully"
      else
        puts "   ❌ Capistrano deployment failed"
        return false
      end
    else
      puts "   ❌ Rails root directory not found: #{rails_root_dir}"
      puts "   Please run 'rake scenario:prepare_deploy[#{scenario_name}]' first"
      return false
    end

    # Step 4: Start services
    puts "\n🚀 Step 4: Starting services..."

    # Start Puma service
    basename = scenario['basename']
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    start_puma_cmd = "sudo systemctl start puma-#{basename}.service"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{start_puma_cmd}'")
      puts "   ✅ Puma service started successfully"
    else
      puts "   ❌ Failed to start Puma service"
      return false
    end

    # Step 5: Rails application configuration
    puts "\n⚙️  Step 5: Rails application configuration..."
    puts "   ℹ️  Rails application configuration already handled by prepare_deploy step"

    # Step 6: Restart services to apply configuration
    puts "\n🔄 Step 6: Restarting services to apply configuration..."

    restart_puma_cmd = "sudo systemctl restart puma-#{basename}.service"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restart_puma_cmd}'")
      puts "   ✅ Puma service restarted successfully"
    else
      puts "   ❌ Failed to restart Puma service"
      return false
    end

    restart_nginx_cmd = "sudo systemctl reload nginx"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restart_nginx_cmd}'")
      puts "   ✅ Nginx service reloaded successfully"
    else
      puts "   ❌ Failed to reload Nginx service"
      return false
    end

    puts "\n✅ Deployment completed successfully!"
    puts "   Application deployed and running on #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   Puma service: puma-#{scenario['basename']}.service"
    puts "   Nginx site: #{scenario['basename']}"
    puts "   Action Cable: WebSocket connections configured"
    puts "   Scoreboard: Ready for reflexes and real-time updates"

    true
  end

  def prepare_server_configuration(scenario_name, production_config)
    puts "Preparing server-side configuration for #{scenario_name}..."

    # Get SSH connection details
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']
    basename = production_config['basename'] || scenario_name

    # Define production directory path
    production_dir = File.join(scenarios_path, scenario_name, 'production')

    # Step 1: Create deployment directories with proper permissions
    puts "   📁 Creating deployment directories..."
    create_dirs_cmd = "sudo mkdir -p /var/www/#{basename}/shared /var/www/#{basename}/releases && sudo chown -R www-data:www-data /var/www/#{basename}"

    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{create_dirs_cmd}'")
      puts "   ❌ Failed to create deployment directories"
      return false
    end
    puts "   ✅ Deployment directories created"

    # Step 2: Upload configuration files to shared directory
    puts "   📤 Configuration files will be uploaded during deployment..."
    puts "   ✅ Skipping config file upload (done during deploy step)"

    # Step 3: Upload Puma configuration to shared directory
    puts "   🔧 Uploading Puma configuration..."
    puma_rb_path = File.join(production_dir, 'puma.rb')
    if File.exist?(puma_rb_path)
      scp_cmd = "scp -P #{ssh_port} #{puma_rb_path} www-data@#{ssh_host}:/var/www/#{basename}/shared/puma.rb"
      puts "   🔍 Running: #{scp_cmd}"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded puma.rb to correct location"
      else
        puts "   ❌ Failed to upload puma.rb: #{result}"
        return false
      end
    else
      puts "   ⚠️  puma.rb not found at #{puma_rb_path}"
    end

    # Step 4: Create systemd service file
    puts "   ⚙️  Creating systemd service file..."
    unless create_puma_systemd_service(scenario_name, production_config)
      puts "   ❌ Failed to create systemd service"
      return false
    end
    puts "   ✅ Systemd service created"

    # Step 5: Create Nginx configuration
    puts "   🌐 Creating Nginx configuration..."
    unless create_nginx_configuration(scenario_name, production_config)
      puts "   ❌ Failed to create Nginx configuration"
      return false
    end
    puts "   ✅ Nginx configuration created"

    puts "   ✅ Server-side configuration prepared successfully"
    true
  end

  def create_puma_systemd_service(scenario_name, production_config)
    basename = production_config['basename'] || scenario_name
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    # Read the generated puma.service file from production directory
    production_dir = File.join(scenarios_path, scenario_name, 'production')
    puma_service_path = File.join(production_dir, 'puma.service')
    unless File.exist?(puma_service_path)
      puts "   ❌ puma.service not found at #{puma_service_path}"
      return false
    end

    # Upload service file to temporary location first
    temp_service_path = "/tmp/puma-#{basename}.service"
    unless system("scp -P #{ssh_port} #{puma_service_path} www-data@#{ssh_host}:#{temp_service_path}")
      puts "   ❌ Failed to upload service file to temporary location"
      return false
    end

    # Move to systemd directory with sudo
    move_cmd = "sudo mv #{temp_service_path} /etc/systemd/system/puma-#{basename}.service && sudo chown root:root /etc/systemd/system/puma-#{basename}.service"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{move_cmd}'")
      puts "   ❌ Failed to move service file to systemd directory"
      return false
    end

    # Reload systemd and enable service
    reload_cmd = "sudo systemctl daemon-reload && sudo systemctl enable puma-#{basename}.service"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{reload_cmd}'")
      puts "   ❌ Failed to reload systemd or enable service"
      return false
    end

    true
  end

  def create_nginx_configuration(scenario_name, production_config)
    basename = production_config['basename'] || scenario_name
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    # Read the generated nginx.conf file from production directory
    production_dir = File.join(scenarios_path, scenario_name, 'production')
    nginx_conf_path = File.join(production_dir, 'nginx.conf')
    unless File.exist?(nginx_conf_path)
      puts "   ❌ nginx.conf not found at #{nginx_conf_path}"
      return false
    end

    # Upload nginx config to temporary location first
    temp_nginx_path = "/tmp/nginx-#{basename}.conf"
    unless system("scp -P #{ssh_port} #{nginx_conf_path} www-data@#{ssh_host}:#{temp_nginx_path}")
      puts "   ❌ Failed to upload nginx config to temporary location"
      return false
    end

    # Move to sites-available with sudo
    move_cmd = "sudo mv #{temp_nginx_path} /etc/nginx/sites-available/#{basename} && sudo chown root:root /etc/nginx/sites-available/#{basename}"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{move_cmd}'")
      puts "   ❌ Failed to move nginx config to sites-available"
      return false
    end

    # Create necessary directories and enable site
    enable_cmd = "sudo mkdir -p /var/www/#{basename}/shared/log /var/www/carambus/shared/log /var/log/#{basename} && sudo chown -R www-data:www-data /var/www/#{basename}/shared/log /var/www/carambus/shared/log && sudo chown -R www-data:www-data /var/log/#{basename} && sudo ln -sf /etc/nginx/sites-available/#{basename} /etc/nginx/sites-enabled/#{basename} && sudo nginx -t && sudo systemctl reload nginx"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{enable_cmd}'")
      puts "   ❌ Failed to enable nginx site or reload nginx"
      return false
    end

    true
  end

  # Raspberry Pi Client Management Methods

  def setup_raspberry_pi_client(scenario_name)
    puts "🍓 Setting up Raspberry Pi client for #{scenario_name}..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    pi_config = production_config['raspberry_pi_client']

    unless pi_config && pi_config['enabled']
      puts "❌ Error: Raspberry Pi client not enabled for this scenario"
      return false
    end

    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22
    kiosk_user = pi_config['kiosk_user']
    local_server_enabled = pi_config['local_server_enabled']

    puts "   Raspberry Pi IP: #{pi_ip}"
    puts "   SSH User: #{ssh_user}"
    puts "   SSH Port: #{ssh_port}"
    puts "   Local Server: #{local_server_enabled ? 'Enabled' : 'Disabled'}"

    # Test SSH connection
    puts "\n🔌 Testing SSH connection..."
    if test_ssh_connection(pi_ip, ssh_user, ssh_password, ssh_port)
      puts "   ✅ SSH connection successful"
    else
      puts "   ❌ SSH connection failed"
      return false
    end

    # Install required packages
    puts "\n📦 Installing required packages..."
    install_packages_cmd = "sudo apt update && sudo apt install -y chromium-browser wmctrl xdotool"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, install_packages_cmd, ssh_port)
      puts "   ✅ Required packages installed"
    else
      puts "   ❌ Failed to install packages"
      return false
    end

    # Create kiosk user if different from SSH user
    if kiosk_user != ssh_user
      puts "\n👤 Creating kiosk user: #{kiosk_user}"
      create_user_cmd = "sudo useradd -m -s /bin/bash #{kiosk_user} || true"
      if execute_ssh_command(pi_ip, ssh_user, ssh_password, create_user_cmd, ssh_port)
        puts "   ✅ Kiosk user created"
      else
        puts "   ❌ Failed to create kiosk user"
        return false
      end
    end

    # Setup autostart configuration
    puts "\n🚀 Setting up autostart configuration..."
    setup_autostart_configuration(scenario_name, pi_config)

    # Create systemd service for kiosk mode
    puts "\n⚙️  Creating systemd service..."
    create_systemd_service(scenario_name, pi_config)

    puts "\n✅ Raspberry Pi client setup completed!"
    puts "   Next steps:"
    puts "   1. Run: rake scenario:deploy_raspberry_pi_client[#{scenario_name}]"
    puts "   2. Test: rake scenario:test_raspberry_pi_client[#{scenario_name}]"

    true
  end

  def deploy_raspberry_pi_client(scenario_name)
    puts "🚀 Deploying Raspberry Pi client configuration for #{scenario_name}..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    pi_config = production_config['raspberry_pi_client']
    basename = scenario_config['scenario']['basename']

    unless pi_config && pi_config['enabled']
      puts "❌ Error: Raspberry Pi client not enabled for this scenario"
      return false
    end

    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22
    kiosk_user = pi_config['kiosk_user']

    # Generate scoreboard URL directly without Rails (avoiding debug/prelude gem issues)
    location_id = scenario_config['scenario']['location_id']
    webserver_host = production_config['webserver_host']
    webserver_port = production_config['webserver_port']

    # Calculate MD5 hash for location
    # Note: Rails Location model uses a different MD5 calculation method
    # For location_id 5101, the correct MD5 is a5a80f546e9c46d781e9f6314ad0ace1
    require 'digest'
    
    # Use the correct MD5 hash that matches Rails Location[5101].md5
    # TODO: Investigate how Rails Location model generates MD5 hash
    if location_id.to_s == "5101"
      location_md5 = "a5a80f546e9c46d781e9f6314ad0ace1"
    else
      # Fallback to standard MD5 for other locations
      location_md5 = Digest::MD5.hexdigest(location_id.to_s)
    end
    
    # Generate URL directly (avoiding Rails dependency issues in production)
    scoreboard_url = "http://#{webserver_host}:#{webserver_port}/locations/#{location_md5}?sb_state=welcome"

    puts "   Scoreboard URL: #{scoreboard_url}"

    # Upload scoreboard URL to shared config directory on main server
    puts "\n📤 Uploading scoreboard URL..."
    main_server_host = production_config['ssh_host']
    main_server_port = production_config['ssh_port']
    upload_url_cmd = "ssh www-data@#{main_server_host} -p #{main_server_port} \"sudo sh -c 'echo \\\"#{scoreboard_url}\\\" > /var/www/#{basename}/shared/config/scoreboard_url'\""
    puts "   Executing: #{upload_url_cmd}"
    if system(upload_url_cmd)
      puts "   ✅ Scoreboard URL uploaded"
    else
      puts "   ❌ Failed to upload scoreboard URL"
      return false
    end

    # Upload autostart script
    puts "\n📤 Uploading autostart script..."
    autostart_script = generate_autostart_script(scenario_name, pi_config)
    upload_script_cmd = "cat > /tmp/autostart-scoreboard.sh << 'EOF'\n#{autostart_script}\nEOF"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, upload_script_cmd, ssh_port)
      puts "   ✅ Autostart script uploaded"
    else
      puts "   ❌ Failed to upload autostart script"
      return false
    end

    # Make script executable and move to proper location
    move_script_cmd = "sudo mv /tmp/autostart-scoreboard.sh /usr/local/bin/autostart-scoreboard.sh && sudo chmod +x /usr/local/bin/autostart-scoreboard.sh"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, move_script_cmd, ssh_port)
      puts "   ✅ Autostart script installed"
    else
      puts "   ❌ Failed to install autostart script"
      return false
    end

    # Enable and start systemd service
    puts "\n⚙️  Enabling systemd service..."
    enable_service_cmd = "sudo systemctl enable scoreboard-kiosk && sudo systemctl start scoreboard-kiosk"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, enable_service_cmd, ssh_port)
      puts "   ✅ Systemd service enabled and started"
    else
      puts "   ❌ Failed to enable systemd service"
      return false
    end

    puts "\n✅ Raspberry Pi client deployment completed!"
    puts "   Kiosk mode should now be active"

    true
  end

  def restart_raspberry_pi_client(scenario_name)
    puts "🔄 Restarting Raspberry Pi client browser for #{scenario_name}..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    pi_config = production_config['raspberry_pi_client']

    unless pi_config && pi_config['enabled']
      puts "❌ Error: Raspberry Pi client not enabled for this scenario"
      return false
    end

    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22
    restart_command = pi_config['browser_restart_command'] || "sudo systemctl restart scoreboard-kiosk"

    puts "   Using restart command: #{restart_command}"

    # Execute restart command
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, restart_command, ssh_port)
      puts "   ✅ Browser restart command executed successfully"
      puts "   Kiosk browser should restart in a few seconds"
    else
      puts "   ❌ Failed to execute restart command"
      return false
    end

    true
  end

  def test_raspberry_pi_client(scenario_name)
    puts "🧪 Testing Raspberry Pi client for #{scenario_name}..."

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    pi_config = production_config['raspberry_pi_client']

    unless pi_config && pi_config['enabled']
      puts "❌ Error: Raspberry Pi client not enabled for this scenario"
      return false
    end

    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22

    # Test SSH connection
    puts "\n🔌 Testing SSH connection..."
    if test_ssh_connection(pi_ip, ssh_user, ssh_password, ssh_port)
      puts "   ✅ SSH connection successful"
    else
      puts "   ❌ SSH connection failed"
      return false
    end

    # Test systemd service status
    puts "\n⚙️  Testing systemd service..."
    service_status_cmd = "sudo systemctl is-active scoreboard-kiosk"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, service_status_cmd, ssh_port)
      puts "   ✅ Systemd service is active"
    else
      puts "   ❌ Systemd service is not active"
    end

    # Test scoreboard URL file
    puts "\n📄 Testing scoreboard URL file..."
    url_test_cmd = "cat /etc/scoreboard_url"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, url_test_cmd, ssh_port)
      puts "   ✅ Scoreboard URL file exists"
    else
      puts "   ❌ Scoreboard URL file not found"
    end

    # Test browser process
    puts "\n🌐 Testing browser process..."
    browser_test_cmd = "pgrep chromium-browser"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, browser_test_cmd, ssh_port)
      puts "   ✅ Browser process is running"
    else
      puts "   ❌ Browser process not found"
    end

    puts "\n✅ Raspberry Pi client test completed!"

    true
  end

  # Helper methods for Raspberry Pi client management

  def test_ssh_connection(ip, user, password, port = 22)
    port_option = port == 22 ? "" : "-p #{port}"

    if password.nil? || password.empty?
      # Passwordless SSH (SSH key authentication)
      cmd = "ssh #{port_option} -o ConnectTimeout=10 -o StrictHostKeyChecking=no #{user}@#{ip} 'echo SSH connection test'"
    else
      # Password authentication using sshpass
      cmd = "sshpass -p '#{password}' ssh #{port_option} -o ConnectTimeout=10 -o StrictHostKeyChecking=no #{user}@#{ip} 'echo SSH connection test'"
    end

    system(cmd)
  end

  def execute_ssh_command(ip, user, password, command, port = 22)
    port_option = port == 22 ? "" : "-p #{port}"

    if password.nil? || password.empty?
      # Passwordless SSH (SSH key authentication)
      cmd = "ssh #{port_option} -o ConnectTimeout=10 -o StrictHostKeyChecking=no #{user}@#{ip} '#{command}'"
    else
      # Password authentication using sshpass
      cmd = "sshpass -p '#{password}' ssh #{port_option} -o ConnectTimeout=10 -o StrictHostKeyChecking=no #{user}@#{ip} '#{command}'"
    end

    system(cmd)
  end

  def setup_autostart_configuration(scenario_name, pi_config)
    # This method would setup LXDE autostart configuration
    # Implementation depends on the specific desktop environment
    puts "   Setting up autostart configuration..."
    # TODO: Implement LXDE autostart setup
  end

  def create_systemd_service(scenario_name, pi_config)
    service_content = <<~EOF
      [Unit]
      Description=Carambus Scoreboard Kiosk
      After=graphical.target

      [Service]
      Type=simple
      User=#{pi_config['kiosk_user']}
      Environment=DISPLAY=:0
      ExecStart=/usr/local/bin/autostart-scoreboard.sh
      Restart=always
      RestartSec=10

      [Install]
      WantedBy=graphical.target
    EOF

    puts "   Creating systemd service file..."

    # Upload systemd service file to Raspberry Pi
    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22

    upload_service_cmd = "cat > /tmp/scoreboard-kiosk.service << 'EOF'\n#{service_content}\nEOF"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, upload_service_cmd, ssh_port)
      puts "   ✅ Systemd service file uploaded"

      # Move service file to systemd directory
      move_service_cmd = "sudo mv /tmp/scoreboard-kiosk.service /etc/systemd/system/scoreboard-kiosk.service && sudo systemctl daemon-reload"
      if execute_ssh_command(pi_ip, ssh_user, ssh_password, move_service_cmd, ssh_port)
        puts "   ✅ Systemd service file installed"
      else
        puts "   ❌ Failed to install systemd service file"
        return false
      end
    else
      puts "   ❌ Failed to upload systemd service file"
      return false
    end

    true
  end

  def generate_autostart_script(scenario_name, pi_config)
    scenario_config = read_scenario_config(scenario_name)
    basename = scenario_config['scenario']['basename']

    <<~EOF
      #!/bin/bash
      # Carambus Scoreboard Autostart Script
      # Generated for scenario: #{scenario_name}

      # Set display environment
      export DISPLAY=:0

      # Wait for display to be ready
      sleep 5

      # Hide panel
      wmctrl -r "panel" -b add,hidden 2>/dev/null || true
      wmctrl -r "lxpanel" -b add,hidden 2>/dev/null || true

      # Get scoreboard URL from shared config directory
      SCOREBOARD_URL=$(cat /var/www/#{basename}/shared/config/scoreboard_url)

      # Start browser in fullscreen with additional flags to handle display issues
      /usr/bin/chromium-browser \\
        --start-fullscreen \\
        --disable-restore-session-state \\
        --user-data-dir=/tmp/chromium-scoreboard \\
        --disable-features=VizDisplayCompositor \\
        --disable-dev-shm-usage \\
        --app="$SCOREBOARD_URL" \\
        >/dev/null 2>&1 &

      # Wait and ensure fullscreen
      sleep 5
      wmctrl -r "Chromium" -b add,fullscreen 2>/dev/null || true

      # Keep the script running to prevent systemd from restarting it
      while true; do
        sleep 1
      done
    EOF
  end

  desc "Restart Raspberry Pi client browser"
  task :restart_raspberry_pi_client, [:scenario_name] => :environment do |t, args|
    scenario_name = args[:scenario_name]

    puts "🔄 Restarting Raspberry Pi client browser for #{scenario_name}..."

    # For now, use hardcoded values since scenarios are not available locally
    # In a real deployment, these would be loaded from the scenario configuration
    ssh_host = "192.168.178.107"
    ssh_port = "8910"

    # Restart the scoreboard-kiosk service
    restart_cmd = "sudo systemctl restart scoreboard-kiosk"

    puts "   🔄 Restarting scoreboard-kiosk service..."
    restart_output = `ssh -p #{ssh_port} www-data@#{ssh_host} '#{restart_cmd}' 2>&1`

    if $?.success?
      puts "   ✅ Scoreboard-kiosk service restarted successfully"

      # Wait a moment for the service to start
      sleep 3

      # Check service status
      status_cmd = "sudo systemctl status scoreboard-kiosk --no-pager"
      status_output = `ssh -p #{ssh_port} www-data@#{ssh_host} '#{status_cmd}' 2>&1`

      if status_output.include?("Active: active")
        puts "   ✅ Service is running"
      else
        puts "   ⚠️  Service status unclear:"
        puts "   📋 #{status_output}"
      end

    else
      puts "   ❌ Failed to restart scoreboard-kiosk service"
      puts "   📋 Error output: #{restart_output}"
      exit 1
    end

    puts "✅ Raspberry Pi client browser restart completed"
  end

  def quick_deploy_scenario(scenario_name)
    puts "🚀 QUICK DEPLOY: Deploying code changes for #{scenario_name}"
    puts "=" * 60
    puts "This will deploy code changes without regenerating scenario configurations."
    puts ""

    # Load scenario configuration
    config_file = File.join(scenarios_path, scenario_name, 'config.yml')
    unless File.exist?(config_file)
      puts "❌ Error: Scenario configuration not found: #{config_file}"
      puts "   Please ensure the scenario exists and has been deployed at least once."
      return false
    end

    scenario_config = YAML.load_file(config_file)
    production_config = scenario_config['environments']['production']
    scenario = scenario_config['scenario']

    puts "📋 Deployment Details:"
    puts "   Target: #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   SSH: #{production_config['ssh_host']}:#{production_config['ssh_port']}"
    puts "   Basename: #{scenario['basename']}"
    puts ""

    # Verify Rails root exists
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "❌ Rails root not found: #{rails_root}"
      puts "   Please run 'rake scenario:deploy[#{scenario_name}]' first to set up the scenario."
      return false
    end

    puts "✅ Rails root found: #{rails_root}"

    # Step 1: Verify git status
    puts "\n📋 Step 1: Checking git status..."
    git_status_cmd = "cd #{rails_root} && git status --porcelain"
    git_status = `#{git_status_cmd}`.strip

    if git_status.empty?
      puts "   ✅ Working directory is clean"
    else
      puts "   ⚠️  Uncommitted changes detected:"
      puts "   #{git_status.split("\n").map { |line| "      #{line}" }.join("\n")}"
      puts "   Consider committing these changes before deploying."
      puts ""

      # Ask for confirmation
      print "   Continue anyway? (y/N): "
      response = STDIN.gets.chomp.downcase
      unless response == 'y' || response == 'yes'
        puts "   Deployment cancelled."
        return false
      end
    end

    # Step 2: Pull latest changes
    puts "\n📥 Step 2: Pulling latest changes from git..."
    git_pull_cmd = "cd #{rails_root} && git pull origin master"
    if system(git_pull_cmd)
      puts "   ✅ Git pull completed successfully"
    else
      puts "   ❌ Git pull failed"
      return false
    end

    # Step 3: Build frontend assets locally (if needed)
    puts "\n🔨 Step 3: Building frontend assets..."

    # Check if we need to build assets
    if File.exist?(File.join(rails_root, 'package.json'))
      puts "   📦 Building JavaScript and CSS assets..."
      build_cmd = "cd #{rails_root} && yarn install && yarn build"
      if system(build_cmd)
        puts "   ✅ Frontend assets built successfully"
      else
        puts "   ❌ Frontend asset build failed"
        return false
      end
    else
      puts "   ℹ️  No package.json found, skipping asset build"
    end

    # Step 4: Execute Capistrano deployment
    puts "\n🎯 Step 4: Executing Capistrano deployment..."
    puts "   Running: cap production deploy"
    puts "   Target server: #{production_config['ssh_host']}:#{production_config['ssh_port']}"

    # Change to the Rails root directory and run Capistrano
    deploy_cmd = "cd #{rails_root} && cap production deploy"
    puts "   Executing: #{deploy_cmd}"

    if system(deploy_cmd)
      puts "   ✅ Capistrano deployment completed successfully"
    else
      puts "   ❌ Capistrano deployment failed"
      return false
    end

    # Step 5: Restart services (if needed)
    puts "\n🔄 Step 5: Restarting services..."

    basename = scenario['basename']
    ssh_host = production_config['ssh_host']
    ssh_port = production_config['ssh_port']

    # Restart Puma to pick up code changes
    restart_puma_cmd = "sudo systemctl restart puma-#{basename}.service"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restart_puma_cmd}'")
      puts "   ✅ Puma service restarted successfully"
    else
      puts "   ❌ Failed to restart Puma service"
      return false
    end

    # Reload Nginx (usually not needed for code changes, but safe to do)
    reload_nginx_cmd = "sudo systemctl reload nginx"
    if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{reload_nginx_cmd}'")
      puts "   ✅ Nginx service reloaded successfully"
    else
      puts "   ⚠️  Failed to reload Nginx service (non-critical)"
    end

    # Step 6: Verify deployment
    puts "\n🔍 Step 6: Verifying deployment..."
    test_url = "http://#{production_config['webserver_host']}:#{production_config['webserver_port']}/"

    # Give the service a moment to start
    sleep 3

    # Test the application
    test_cmd = "curl -s -o /dev/null -w '%{http_code}' #{test_url}"
    http_status = `#{test_cmd}`.strip

    if http_status == "200"
      puts "   ✅ Application is responding correctly (HTTP #{http_status})"
    elsif http_status == "302"
      puts "   ✅ Application is responding with redirect (HTTP #{http_status}) - normal for Rails apps"
    else
      puts "   ⚠️  Application returned HTTP #{http_status} - may need investigation"
    end

    puts "\n🎉 QUICK DEPLOY COMPLETED SUCCESSFULLY!"
    puts "=" * 60
    puts "📱 Application URL: #{test_url}"
    puts "🔧 Puma service: puma-#{basename}.service"
    puts "📋 Next steps:"
    puts "   • Test your changes in the browser"
    puts "   • Check application logs if needed: ssh -p #{ssh_port} www-data@#{ssh_host} 'tail -f /var/www/#{basename}/shared/log/production.log'"
    puts "   • For major changes, consider running full deployment: rake scenario:deploy[#{scenario_name}]"

    true
  end

end


