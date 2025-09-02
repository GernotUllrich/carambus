# frozen_string_literal: true

namespace :mode do
  desc "Switch to LOCAL mode with named parameters"
  task :local => :environment do
    params = parse_named_parameters_from_env
    
    season_name = params[:season_name] || "2025/2026"
    application_name = params[:application_name] || 'carambus'
    context = params[:context] || 'NBV'
    api_url = params[:api_url] || 'https://newapi.carambus.de/'
    basename = params[:basename] || 'carambus'
    database = params[:database] || 'carambus_api_development'
    domain = params[:domain] || 'carambus.de'
    location_id = params[:location_id] || '1'
    club_id = params[:club_id] || '357'
    rails_env = params[:rails_env] || 'production'
    host = params[:host] || 'new.carambus.de'
    port = params[:port] || '8910'  # SSH Port, not application port
    branch = params[:branch] || 'master'
    puma_script = params[:puma_script] || 'manage-puma.sh'
    
    # New parameters for NGINX and Puma
    nginx_port = params[:nginx_port] || '80'  # NGINX web port
    puma_port = params[:puma_port] || '3000'  # Puma application port
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id)
    
    puts "🚀 Switching to LOCAL mode with named parameters..."
    puts "Parameters: #{params.inspect}"

    # Update carambus.yml
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)

    # Update database.yml
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename, domain)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Update Puma configuration for LOCAL mode
    update_puma_configuration(puma_script, basename)

    # Update NGINX configuration
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_port)

    # Update Puma service configuration
    update_puma_service_configuration(basename, puma_port, rails_env)

    # Update scoreboard URL configuration
    update_scoreboard_url_configuration(scoreboard_url)

    # Manage log files for LOCAL mode
    manage_log_files("local")

    puts "✅ Switched to LOCAL mode successfully"
    puts "Current mode: LOCAL (carambus_api_url is set, local database)"
  end

  desc "Switch to API mode with named parameters"
  task :api => :environment do
    params = parse_named_parameters_from_env
    
    season_name = params[:season_name] || "2025/2026"
    application_name = params[:application_name] || 'carambus'
    context = params[:context] || ''
    api_url = params[:api_url] || ''
    basename = params[:basename] || 'carambus_api'
    database = params[:database] || 'carambus_api_production'
    domain = params[:domain] || 'api.carambus.de'
    location_id = params[:location_id] || ''
    club_id = params[:club_id] || ''
    rails_env = params[:rails_env] || 'production'
    host = params[:host] || 'newapi.carambus.de'
    port = params[:port] || '8910'  # SSH Port, not application port
    branch = params[:branch] || 'master'
    puma_script = params[:puma_script] || 'manage-puma-api.sh'
    
    # New parameters for NGINX and Puma
    nginx_port = params[:nginx_port] || '80'  # NGINX web port
    puma_port = params[:puma_port] || '3001'  # Puma application port
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id)
    
    puts "🚀 Switching to API mode with named parameters..."
    puts "Parameters: #{params.inspect}"

    # Update carambus.yml
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)

    # Update database.yml
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename, domain)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Update Puma configuration for API mode
    update_puma_configuration(puma_script, basename)

    # Update NGINX configuration
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_port)

    # Update Puma service configuration
    update_puma_service_configuration(basename, puma_port, rails_env)

    # Update scoreboard URL configuration
    update_scoreboard_url_configuration(scoreboard_url)

    # Manage log files for LOCAL mode
    manage_log_files("api")

    puts "✅ Switched to API mode successfully"
    puts "Current mode: API (carambus_api_url is nil, local database)"
  end

  desc "Save current configuration with a name"
  task :save, [:name] => :environment do |task, args|
    name = args.name
    if name.blank?
      puts "❌ Configuration name required"
      puts "Usage: bundle exec rails 'mode:save[my_config]'"
      exit 1
    end

    params = parse_named_parameters_from_env
    if params.empty?
      puts "❌ No parameters provided"
      puts "Usage: bundle exec rails 'mode:save[my_config]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
      exit 1
    end

    save_named_configuration(name, params)
    puts "✅ Saved configuration '#{name}' with parameters:"
    puts params.inspect
  end

  desc "Load a saved configuration"
  task :load, [:name] => :environment do |task, args|
    name = args.name
    if name.blank?
      puts "❌ Configuration name required"
      puts "Usage: bundle exec rails 'mode:load[my_config]'"
      exit 1
    end

    params = load_named_configuration(name)
    if params.nil?
      puts "❌ Configuration '#{name}' not found"
      puts "Available configurations:"
      list_named_configurations
      exit 1
    end

    puts "✅ Loaded configuration '#{name}':"
    puts params.inspect
    
    # Set environment variables for the loaded configuration
    params.each do |key, value|
      ENV["MODE_#{key.to_s.upcase}"] = value.to_s
    end
    
    puts "📋 Environment variables set. Run mode:local or mode:api to apply."
  end

  desc "List all saved configurations"
  task :list => :environment do
    list_named_configurations
  end

  desc "Show help for named parameters"
  task :help => :environment do
    show_named_parameters_help
  end

  desc "Show current mode status"
  task :status, [:detailed, :source] => :environment do |task, args|
    detailed = args.detailed == 'detailed'
    source = args.source == 'production' ? :production : :local
    
    puts "\n🔍 CURRENT MODE STATUS"
    puts "=" * 60
    
    # Extract current parameters
    season_name = extract_season_name(source)
    application_name = extract_application_name(source)
    context = extract_context(source)
    api_url = extract_api_url(source)
    basename = extract_basename(source)
    database = extract_database(source)
    domain = extract_domain(source)
    location_id = extract_location_id(source)
    club_id = extract_club_id(source)
    rails_env = extract_rails_env
    host = extract_host
    port = extract_port
    branch = extract_branch
    puma_script = extract_puma_script
    
    # Display basic status
    puts "Current Configuration:"
    puts "  API URL: #{api_url || 'empty'}"
    puts "  Context: #{context || 'empty'}"
    puts "  Database: #{database || 'not configured'}"
    puts "  Deploy Basename: #{basename || 'not configured'}"
    puts "  Log File: #{File.symlink?(Rails.root.join('log', 'development.log')) ? 'linked file' : 'direct file (not linked)'}"
    puts "  Puma Script: #{puma_script || 'not configured'}"
    
    # Determine mode
    if api_url.nil? || api_url.empty?
      puts "Current Mode: API"
    else
      puts "Current Mode: LOCAL"
    end

    # Show source information
    if detailed
      if source == :production
        deploy_config = get_deploy_config
        if deploy_config
          puts "\n📡 CONFIGURATION SOURCE:"
          puts "-" * 40
          puts "Reading from production server: #{deploy_config[:host]}:#{deploy_config[:port]}"
          puts "Deploy path: /var/www/#{deploy_config[:basename]}/shared/config/"
        else
          puts "\n📡 CONFIGURATION SOURCE:"
          puts "-" * 40
          puts "Reading from local configuration files (production server not accessible)"
        end
      else
        puts "\n📡 CONFIGURATION SOURCE:"
        puts "-" * 40
        puts "Reading from local deployment configuration files"
        puts "Local path: config/carambus.yml, config/database.yml"
      end
    end

    # Show detailed parameters if requested
    if detailed
      puts "\n" + "="*60
      puts "DETAILED PARAMETER BREAKDOWN"
      puts "="*60
      
      # Read all configuration files to extract current parameters
      show_detailed_parameters(source)
    end
  end

  desc "Show local deployment configuration (pre-deployment validation)"
  task :pre_deploy_status, [:detailed] => :environment do |t, args|
    puts "\n🔍 PRE-DEPLOYMENT VALIDATION"
    puts "=" * 60
    puts "This shows the configuration that will be deployed to production"
    puts "Use this to validate your settings before deployment"
    
    # Show status with local source
    Rake::Task["mode:status"].invoke(args.detailed, "local")
  end

  desc "Verify production deployment (post-deployment validation)"
  task :post_deploy_status, [:detailed] => :environment do |t, args|
    puts "\n✅ POST-DEPLOYMENT VERIFICATION"
    puts "=" * 60
    puts "This shows the actual configuration deployed on the production server"
    puts "Use this to verify that deployment was successful"
    
    # Show status with production source
    Rake::Task["mode:status"].invoke(args.detailed, "production")
  end

  desc "Create backup of current configuration"
  task backup: :environment do
    backup_dir = Rails.root.join('tmp', 'mode_backups')
    FileUtils.mkdir_p(backup_dir)

    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_path = backup_dir.join("config_backup_#{timestamp}")
    FileUtils.mkdir_p(backup_path)

    # Backup configuration files
    files_to_backup = [
      'config/carambus.yml',
      'config/database.yml',
      'config/deploy/production.rb'
    ]

    files_to_backup.each do |file|
      source = Rails.root.join(file)
      if File.exist?(source)
        FileUtils.cp(source, backup_path)
        puts "✓ Backed up #{file}"
      end
    end

    puts "Backup created at: #{backup_path}"
  end

  desc "Prepare database dump for deployment"
  task :prepare_db_dump => :environment do
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    dump_file = "carambus_api_production_#{timestamp}.sql.gz"
    
    puts "🗄️  Creating database dump: #{dump_file}"
    
    # Create database dump
    system("pg_dump carambus_api_production | gzip > #{dump_file}")
    
    if $?.success?
      puts "✅ Database dump created successfully: #{dump_file}"
      puts "📁 Location: #{File.expand_path(dump_file)}"
    else
      puts "❌ Failed to create database dump"
      exit 1
    end
  end

  desc "List available database dumps"
  task :list_db_dumps => :environment do
    puts "🗄️  Available database dumps:"
    puts "-" * 40
    
    dumps = Dir.glob("carambus_api_production_*.sql.gz").sort.reverse
    
    if dumps.empty?
      puts "No database dumps found"
    else
      dumps.each do |dump|
        size = File.size(dump)
        date = File.mtime(dump).strftime('%Y-%m-%d %H:%M:%S')
        puts "#{dump} (#{size} bytes, #{date})"
      end
    end
  end

  desc "Copy templates to local storage"
  task :copy_templates => :environment do
    local_storage_dir = Rails.root.join('local_storage')
    FileUtils.mkdir_p(local_storage_dir)
    
    templates = {
      'nginx_configs' => ['config/nginx.conf'],
      'puma_configs' => ['config/puma.service'],
      'scoreboard_configs' => ['config/scoreboard_url']
    }
    
    templates.each do |subdir, files|
      target_dir = local_storage_dir.join(subdir)
      FileUtils.mkdir_p(target_dir)
      
      files.each do |file|
        source = Rails.root.join(file)
        if File.exist?(source)
          target = target_dir.join(File.basename(file))
          FileUtils.cp(source, target)
          puts "✓ Copied #{file} to #{target}"
        else
          puts "⚠️  Source file not found: #{file}"
        end
      end
    end
    
    puts "✅ Templates copied to local storage"
  end

  desc "Deploy templates to production server"
  task :deploy_templates => :environment do
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    local_storage_dir = Rails.root.join('local_storage')
    return puts "❌ Local storage directory not found" unless Dir.exist?(local_storage_dir)
    
    puts "🚀 Deploying templates to production server..."
    puts "Server: #{deploy_config[:host]}:#{deploy_config[:port]}"
    puts "Basename: #{deploy_config[:basename]}"
    
    # Deploy NGINX configuration
    nginx_source = local_storage_dir.join('nginx_configs', 'nginx.conf')
    if File.exist?(nginx_source)
      nginx_target = "/etc/nginx/sites-available/#{deploy_config[:basename]}"
      deploy_file(nginx_source, nginx_target, deploy_config)
      puts "✓ NGINX config deployed to #{nginx_target}"
    end
    
    # Deploy Puma service configuration
    puma_source = local_storage_dir.join('puma_configs', 'puma.service')
    if File.exist?(puma_source)
      puma_target = "/etc/systemd/system/puma-#{deploy_config[:basename]}.service"
      deploy_file(puma_source, puma_target, deploy_config)
      puts "✓ Puma service config deployed to #{puma_target}"
    end
    
    # Deploy scoreboard configuration
    scoreboard_source = local_storage_dir.join('scoreboard_configs', 'scoreboard_url')
    if File.exist?(scoreboard_source)
      scoreboard_target = "/var/www/#{deploy_config[:basename]}/shared/config/scoreboard_url"
      deploy_file(scoreboard_source, scoreboard_target, deploy_config)
      puts "✓ Scoreboard config deployed to #{scoreboard_target}"
    end
    
    puts "✅ Templates deployed successfully"
  end

  desc "Deploy database dump to production server"
  task :deploy_db_dump, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:deploy_db_dump[carambus_api_production_20250101_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "🚀 Deploying database dump to production server..."
    puts "Dump file: #{dump_file}"
    puts "Server: #{deploy_config[:host]}:#{deploy_config[:port]}"
    
    # Copy dump file to server
    remote_dump_dir = "/var/www/#{deploy_config[:basename]}/shared/database_dumps"
    remote_dump_file = "#{remote_dump_dir}/#{File.basename(dump_file)}"
    
    # Create remote directory
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'mkdir -p #{remote_dump_dir}'")
    
    # Copy file
    system("scp -P #{deploy_config[:port]} #{dump_file} www-data@#{deploy_config[:host]}:#{remote_dump_file}")
    
    if $?.success?
      puts "✅ Database dump deployed successfully"
      puts "📁 Remote location: #{remote_dump_file}"
      puts ""
      puts "To restore the database:"
      puts "ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'gunzip -c #{remote_dump_file} | psql #{deploy_config[:basename]}_production'"
    else
      puts "❌ Failed to deploy database dump"
      exit 1
    end
  end

  desc "Validate deployment configuration locally"
  task :validate_deployment => :environment do
    puts "🔍 VALIDATING DEPLOYMENT CONFIGURATION"
    puts "=" * 60
    
    # Check carambus.yml
    carambus_file = Rails.root.join('config', 'carambus.yml')
    if File.exist?(carambus_file)
      content = File.read(carambus_file)
      if content.include?('<%=')
        puts "❌ carambus.yml contains unprocessed ERB placeholders"
      else
        puts "✅ carambus.yml is properly generated"
      end
    else
      puts "❌ carambus.yml not found"
    end
    
    # Check database.yml
    database_file = Rails.root.join('config', 'database.yml')
    if File.exist?(database_file)
      content = File.read(database_file)
      if content.include?('<%=')
        puts "❌ database.yml contains unprocessed ERB placeholders"
      elsif content.include?('database: carambus_production')
        puts "✅ database.yml production section is properly configured"
      else
        puts "⚠️  database.yml production section needs to be generated"
      end
    else
      puts "❌ database.yml not found"
    end
    
    # Check deploy/production.rb
    deploy_file = Rails.root.join('config', 'deploy', 'production.rb')
    if File.exist?(deploy_file)
      content = File.read(deploy_file)
      if content.include?('<%=')
        puts "❌ deploy/production.rb contains unprocessed ERB placeholders"
      else
        puts "✅ deploy/production.rb is properly generated"
      end
    else
      puts "❌ deploy/production.rb not found"
    end
    
    puts "\n🎯 DEPLOYMENT VALIDATION COMPLETE"
  end

  private

  def parse_named_parameters_from_env
    params = {}
    
    # Parse from environment variables
    %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script nginx_port puma_port ssl_enabled scoreboard_url].each do |param|
      env_var = "MODE_#{param.to_s.upcase}"
      params[param] = ENV[env_var] if ENV[env_var]
    end
    
    # Parse from command line arguments (if provided)
    if ENV['MODE_PARAMS']
      begin
        # Parse JSON or YAML from command line
        if ENV['MODE_PARAMS'].start_with?('{') || ENV['MODE_PARAMS'].start_with?('[')
          parsed = JSON.parse(ENV['MODE_PARAMS'])
          params.merge!(parsed.symbolize_keys)
        else
          # Parse key=value format
          ENV['MODE_PARAMS'].split(',').each do |pair|
            key, value = pair.split('=', 2)
            params[key.strip.to_sym] = value.strip if key && value
          end
        end
      rescue => e
        puts "⚠️  Error parsing MODE_PARAMS: #{e.message}"
      end
    end
    
    params
  end

  def save_named_configuration(name, params)
    config_dir = Rails.root.join('config', 'named_modes')
    FileUtils.mkdir_p(config_dir)
    
    config_file = config_dir.join("#{name}.yml")
    File.write(config_file, params.to_yaml)
  end

  def load_named_configuration(name)
    config_dir = Rails.root.join('config', 'named_modes')
    config_file = config_dir.join("#{name}.yml")
    
    return nil unless File.exist?(config_file)
    
    YAML.load(File.read(config_file)).symbolize_keys
  end

  def list_named_configurations
    config_dir = Rails.root.join('config', 'named_modes')
    return puts "📋 No saved configurations found" unless Dir.exist?(config_dir)

    puts "📋 Saved configurations:"
    Dir.glob(config_dir.join('*.yml')).each do |file|
      name = File.basename(file, '.yml')
      params = YAML.load(File.read(file)).symbolize_keys
      puts "  #{name}: #{params.inspect}"
    end
  end

  def show_named_parameters_help
    puts "Carambus Named Parameters System"
    puts ""
    puts "Usage:"
    puts "  bundle exec rails 'mode:local' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
    puts "  bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de"
    puts "  bundle exec rails 'mode:save[my_config]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
    puts "  bundle exec rails 'mode:load[my_config]'"
    puts "  bundle exec rails 'mode:list'"
    puts ""
    puts "Available Parameters:"
    puts "  MODE_SEASON_NAME     - Season identifier (e.g., '2025/2026')"
    puts "  MODE_APPLICATION_NAME - Application name (e.g., 'carambus', 'carambus_api')"
    puts "  MODE_CONTEXT         - Context identifier (e.g., 'NBV', '')"
    puts "  MODE_API_URL         - API URL for LOCAL mode"
    puts "  MODE_BASENAME        - Deploy basename (e.g., 'carambus', 'carambus_api')"
    puts "  MODE_DATABASE        - Database name"
    puts "  MODE_DOMAIN          - Domain name"
    puts "  MODE_LOCATION_ID     - Location ID"
    puts "  MODE_CLUB_ID         - Club ID"
    puts "  MODE_RAILS_ENV       - Rails environment"
    puts "  MODE_HOST            - Server hostname (SSH access)"
    puts "  MODE_PORT            - Server SSH port (default: 8910)"
    puts "  MODE_BRANCH          - Git branch"
    puts "  MODE_PUMA_SCRIPT     - Puma management script"
    puts "  MODE_NGINX_PORT      - NGINX web port (default: 80)"
    puts "  MODE_PUMA_PORT       - Puma application port (default: 3000/3001)"
    puts "  MODE_SSL_ENABLED     - SSL enabled (true/false, default: false)"
    puts "  MODE_SCOREBOARD_URL  - Scoreboard URL (auto-generated from location_id)"
    puts ""
    puts "Examples:"
    puts "  bundle exec rails 'mode:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=8910"
    puts "  bundle exec rails 'mode:local' MODE_SEASON_NAME='2025/2026' MODE_CONTEXT=NBV MODE_API_URL='https://newapi.carambus.de/'"
    puts "  bundle exec rails 'mode:save[api_hetzner]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=8910"
    puts "  bundle exec rails 'mode:load[api_hetzner]'"
    puts ""
    puts "In-house Server Example:"
    puts "  bundle exec rails 'mode:local' MODE_HOST=192.168.1.100 MODE_PORT=22 MODE_NGINX_PORT=3131 MODE_PUMA_PORT=3000 MODE_SSL_ENABLED=false"
  end

  # Include all the necessary methods from the original mode.rake
  def update_deploy_rb(basename, domain = nil)
    deploy_file = Rails.root.join('config', 'deploy.rb')

    if File.exist?("#{deploy_file}.erb")
      content = File.read("#{deploy_file}.erb")
      
      # Handle nil values by converting to empty string
      basename = basename.to_s
      domain = domain.to_s
      
      updated_content = content.gsub(
        /<%= basename %>/,
        basename
      ).gsub(
        /<%= domain %>/,
        domain
      )

      File.write(deploy_file, updated_content)
      puts "✓ Updated deploy.rb basename to: #{basename}"
      puts "✓ Updated deploy.rb domain to: #{domain}" if domain.present?
    else
      puts "⚠️  deploy.rb.erb not found, skipping basename update"
    end
  end

  def update_deploy_environment_rb(rails_env, host, port, branch)
    deploy_environment_file = Rails.root.join('config', 'deploy', "#{rails_env}.rb")

    if File.exist?("#{deploy_environment_file}.erb")
      content = File.read("#{deploy_environment_file}.erb")
      
      # Handle nil values by converting to empty string
      host = host.to_s
      port = port.to_s
      branch = branch.to_s
      
      updated_content = content.gsub(
        /<%= host %>/,
        host
      ).gsub(
        /<%= port %>/,
        port
      ).gsub(
        /<%= rails_env %>/,
        rails_env
      ).gsub(
        /<%= branch %>/,
        branch
      )

      File.write(deploy_environment_file, updated_content)
      puts "✓ Updated deploy/#{rails_env}.rb \nhost to: #{host} \nport to: #{port} \nbranch to: #{branch} "

    else
      puts "⚠️  deploy/#{rails_env}.rb.erb not found, skipping environment update"
    end
  end

  def update_database_yml(database)
    database_yml_file = Rails.root.join('config', 'database.yml')

    if File.exist?("#{database_yml_file}.erb")
      content = File.read("#{database_yml_file}.erb")
      
      # Handle nil values by converting to empty string
      database = database.to_s
      
      updated_content = content.gsub(
        /<%= database %>/,
        database
      )

      File.write(database_yml_file, updated_content)
      puts "✓ Updated database.yml with database: #{database}"
    else
      puts "⚠️  database.yml.erb not found, skipping database.yml update"
    end
  end

  def update_carambus_yml(season_name, carambus_api_url, basename, carambus_domain, location_id, application_name, context, club_id)
    carambus_yml_file = Rails.root.join('config', 'carambus.yml')

    if File.exist?("#{carambus_yml_file}.erb")
      content = File.read("#{carambus_yml_file}.erb")
      
      # Handle nil values by converting to empty string
      season_name = season_name.to_s
      carambus_api_url = carambus_api_url.to_s
      basename = basename.to_s
      carambus_domain = carambus_domain.to_s
      location_id = location_id.to_s
      application_name = application_name.to_s
      context = context.to_s
      club_id = club_id.to_s
      
      updated_content = content.gsub(
        /<%= carambus_api_url %>/,
        carambus_api_url
      ).gsub(
        /<%= season_name %>/,
        season_name
      ).gsub(
        /<%= location_id %>/,
        location_id
      ).gsub(
        /<%= application_name %>/,
        application_name
      ).gsub(
        /<%= basename %>/,
        basename
      ).gsub(
        /<%= carambus_domain %>/,
        carambus_domain
      ).gsub(
        /<%= context %>/,
        context
      ).gsub(
        /<%= club_id %>/,
        club_id
      )

      File.write(carambus_yml_file, updated_content)
      puts "✓ Updated carambus_yml with parameters"
    else
      puts "⚠️  carambus.yml.erb not found, skipping carambus.yml update"
    end
  end

  def manage_log_files(mode)
    log_dir = Rails.root.join('log')
    FileUtils.mkdir_p(log_dir)

    # Backup current development.log if it exists
    development_log = log_dir.join('development.log')
    if File.exist?(development_log) && !File.symlink?(development_log)
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      backup_name = "development.log.backup_#{timestamp}"
      FileUtils.mv(development_log, log_dir.join(backup_name))
      puts "✓ Backed up current development.log"
    end

    # Remove existing symlink if it exists
    if File.symlink?(development_log)
      File.delete(development_log)
    end

    # Create symbolic link to mode-specific log file
    if mode == "local"
      target_log = log_dir.join('development-local.log')
      if !File.exist?(target_log)
        FileUtils.touch(target_log)
        puts "✓ Created development-local.log"
      end
      FileUtils.ln_sf(target_log, development_log)
      puts "✓ Linked development.log to development-local.log"
    elsif mode == "api"
      target_log = log_dir.join('development-api.log')
      if !File.exist?(target_log)
        FileUtils.touch(target_log)
        puts "✓ Created development-api.log"
      end
      FileUtils.ln_sf(target_log, development_log)
      puts "✓ Linked development.log to development-api.log"
    end
  end

  def update_puma_configuration(puma_script, basename)
    deploy_file = Rails.root.join('config', 'deploy.rb')

    if File.exist?(deploy_file)
      content = File.read(deploy_file)
      
      # Update the Puma restart task to use the specified script
      if content.include?('namespace :puma do')
        # Replace the existing Puma restart task
        updated_content = content.gsub(
          /namespace :puma do\s+desc "Restart application"\s+task :restart do\s+on roles\(:app\) do\s+.*?end\s+end\s+end/m,
          "namespace :puma do\n  desc \"Restart application\"\n  task :restart do\n    on roles(:app) do\n      # Use the specific #{puma_script} script for better control\n      # The script expects to be run from the current directory\n      within current_path do\n        execute \"./bin/#{puma_script}\"\n      end\n    end\n  end\n\n  desc \"Start application\"\n  task :start do\n    on roles(:app) do\n      execute \"sudo systemctl start puma-#{basename}.service\"\n    end\n  end\n\n  desc \"Stop application\"\n  task :stop do\n    on roles(:app) do\n      execute \"sudo systemctl stop puma-#{basename}.service\"\n    end\n  end\n\n  desc \"Status of application\"\n  task :status do\n    on roles(:app) do\n      execute \"sudo systemctl status puma-#{basename}.service\"\n    end\n  end\nend"
        )
        
        File.write(deploy_file, updated_content)
        puts "✓ Updated Puma configuration to use #{puma_script} script"
      else
        puts "⚠️  Puma namespace not found in deploy.rb, skipping Puma configuration update"
      end
    else
      puts "⚠️  deploy.rb not found, skipping Puma configuration update"
    end
  end

  def show_detailed_parameters(source = :production)
    puts "\n📋 PARAMETER DETAILS:"
    puts "-" * 40
    
    # Extract parameters from configuration files
    season_name = extract_season_name(source)
    application_name = extract_application_name(source)
    context = extract_context(source)
    api_url = extract_api_url(source)
    basename = extract_basename(source)
    database = extract_database(source)
    domain = extract_domain(source)
    location_id = extract_location_id(source)
    club_id = extract_club_id(source)
    rails_env = extract_rails_env
    host = extract_host
    port = extract_port
    branch = extract_branch
    puma_script = extract_puma_script
    
    # Display parameters in order
    puts "1.  season_name:     #{season_name || '❌ Not configured'}"
    puts "2.  application_name: #{application_name || '❌ Not configured'}"
    puts "3.  context:         #{context || '❌ Not configured'}"
    puts "4.  api_url:         #{api_url || '❌ Not configured'}"
    puts "5.  basename:        #{basename || '❌ Not configured'}"
    puts "6.  database:        #{database || '❌ Not configured'}"
    puts "7.  domain:          #{domain || '❌ Not configured'}"
    puts "8.  location_id:     #{location_id || '❌ Not configured'}"
    puts "9.  club_id:         #{club_id || '❌ Not configured'}"
    puts "10. rails_env:       #{rails_env || '❌ Not configured'}"
    puts "11. host:            #{host || '❌ Not configured'}"
    puts "12. port:            #{port || '❌ Not configured'}"
    puts "13. branch:          #{branch || '❌ Not configured'}"
    puts "14. puma_script:     #{puma_script || '❌ Not configured'}"
    
    puts "\n🔄 COMPLETE PARAMETER STRING:"
    puts "-" * 40
    param_string = [
      season_name, application_name, context, api_url, basename, 
      database, domain, location_id, club_id, rails_env, 
      host, port, branch, puma_script
    ].join(',')
    
    if param_string.include?('❌')
      puts "⚠️  Some parameters are missing or not configured"
      puts param_string
    else
      puts "✅ All parameters configured"
      puts param_string
    end
    
    puts "\n📝 USAGE:"
    puts "-" * 40
    puts "To switch to this exact configuration:"
    puts "bundle exec rails \"mode:#{api_url.nil? || api_url.empty? ? 'api' : 'local'}[#{param_string}]\""
    
    puts "\nOr save this configuration:"
    puts "./bin/mode-params.sh save my_current_config \"#{param_string}\""
  end

  def extract_season_name(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'season_name') || production_config.dig('development', 'season_name')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'season_name') || local_config.dig('development', 'season_name')
      end
    end
  end

  def extract_application_name(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'application_name') || production_config.dig('development', 'application_name')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'application_name') || local_config.dig('development', 'application_name')
      end
    end
  end

  def extract_context(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'context') || production_config.dig('development', 'context')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'context') || local_config.dig('development', 'context')
      end
    end
  end

  def extract_api_url(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'carambus_api_url') || production_config.dig('development', 'carambus_api_url')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'carambus_api_url') || local_config.dig('development', 'carambus_api_url')
      end
    end
  end

  def extract_basename(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'basename') || production_config.dig('development', 'basename')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'basename') || local_config.dig('development', 'basename')
      end
    end
  end

  def extract_database(source = :production)
    case source
    when :production
      production_config = read_production_config('database.yml')
      if production_config
        production_config.dig('production', 'database')
      end
    when :local
      local_config = read_local_deployment_config('database.yml')
      if local_config
        local_config.dig('production', 'database')
      end
    end
  end

  def extract_domain(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'carambus_domain') || production_config.dig('development', 'carambus_domain')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'carambus_domain') || local_config.dig('development', 'carambus_domain')
      end
    end
  end

  def extract_location_id(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'location_id') || production_config.dig('development', 'location_id')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'location_id') || local_config.dig('development', 'location_id')
      end
    end
  end

  def extract_club_id(source = :production)
    case source
    when :production
      production_config = read_production_config('carambus.yml')
      if production_config
        production_config.dig('production', 'club_id') || production_config.dig('development', 'club_id')
      end
    when :local
      local_config = read_local_deployment_config('carambus.yml')
      if local_config
        local_config.dig('production', 'club_id') || local_config.dig('development', 'club_id')
      end
    end
  end

  def extract_rails_env
    deploy_config = get_deploy_config
    deploy_config&.dig(:rails_env)
  end

  def extract_host
    deploy_config = get_deploy_config
    deploy_config&.dig(:host)
  end

  def extract_port
    deploy_config = get_deploy_config
    deploy_config&.dig(:port)
  end

  def extract_branch
    deploy_config = get_deploy_config
    deploy_config&.dig(:branch)
  end

  def extract_puma_script
    deploy_file = Rails.root.join('config', 'deploy.rb')
    if File.exist?(deploy_file)
      content = File.read(deploy_file)
      if content.match(/execute "\.\/bin\/([^"]+)"/)
        $1
      end
    end
  end

  def read_production_config(filename)
    deploy_config = get_deploy_config
    return nil unless deploy_config

    begin
      remote_file = "/var/www/#{deploy_config[:basename]}/shared/config/#{filename}"
      result = `ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} "cat #{remote_file}" 2>/dev/null`
      
      if $?.success? && !result.empty?
        YAML.load(result)
      else
        nil
      end
    rescue => e
      puts "⚠️  Error reading production config: #{e.message}"
      nil
    end
  end

  def read_local_deployment_config(filename)
    config_file = Rails.root.join('config', filename)
    if File.exist?(config_file)
      YAML.load(File.read(config_file))
    else
      nil
    end
  end

  def get_deploy_config
    deploy_file = Rails.root.join('config', 'deploy.rb')
    production_file = Rails.root.join('config', 'deploy', 'production.rb')
    
    return nil unless File.exist?(deploy_file) && File.exist?(production_file)
    
    # Read deploy.rb for basename
    deploy_content = File.read(deploy_file)
    basename_match = deploy_content.match(/set :basename, "([^"]+)"/)
    basename = basename_match ? basename_match[1] : nil
    
    # Read production.rb for host, port, rails_env, branch
    production_content = File.read(production_file)
    host_match = production_content.match(/server '([^']+)'/)
    port_match = production_content.match(/port: "([^"]+)"/)
    rails_env_match = production_content.match(/set :rails_env, '([^']+)'/)
    branch_match = production_content.match(/set :branch, '([^']+)'/)
    
    {
      basename: basename,
      host: host_match ? host_match[1] : nil,
      port: port_match ? port_match[1] : nil,
      rails_env: rails_env_match ? rails_env_match[1] : nil,
      branch: branch_match ? branch_match[1] : nil
    }
  end

  def deploy_file(source, target, deploy_config)
    begin
      `ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} "mkdir -p $(dirname #{target}) && cat #{source} > #{target}"`
      if $?.success?
        puts "✓ Deployed #{source} to #{target}"
      else
        puts "❌ Failed to deploy #{source} to #{target}"
        exit 1
      end
    rescue => e
      puts "❌ Error deploying #{source} to #{target}: #{e.message}"
      exit 1
    end
  end

  def update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_port)
    nginx_config_file = Rails.root.join('config', 'nginx.conf')

    if File.exist?("#{nginx_config_file}.erb")
      content = File.read("#{nginx_config_file}.erb")
      
      # Handle nil values by converting to empty string
      basename = basename.to_s
      domain = domain.to_s
      nginx_port = nginx_port.to_s
      puma_port = puma_port.to_s
      ssl_enabled = ssl_enabled.to_s
      
      updated_content = content.gsub(
        /<%= basename %>/,
        basename
      ).gsub(
        /<%= domain %>/,
        domain
      ).gsub(
        /<%= nginx_port %>/,
        nginx_port
      ).gsub(
        /<%= puma_port %>/,
        puma_port
      ).gsub(
        /<%= ssl_enabled %>/,
        ssl_enabled
      )

      File.write(nginx_config_file, updated_content)
      puts "✓ Updated nginx.conf with parameters"
    else
      puts "⚠️  nginx.conf.erb not found, skipping nginx.conf update"
    end
  end

  def update_puma_service_configuration(basename, puma_port, rails_env)
    puma_service_file = Rails.root.join('config', 'puma.service')

    if File.exist?("#{puma_service_file}.erb")
      content = File.read("#{puma_service_file}.erb")
      
      # Handle nil values by converting to empty string
      basename = basename.to_s
      puma_port = puma_port.to_s
      rails_env = rails_env.to_s
      
      updated_content = content.gsub(
        /<%= basename %>/,
        basename
      ).gsub(
        /<%= puma_port %>/,
        puma_port
      ).gsub(
        /<%= rails_env %>/,
        rails_env
      )

      File.write(puma_service_file, updated_content)
      puts "✓ Updated puma.service with parameters"
    else
      puts "⚠️  puma.service.erb not found, skipping puma.service update"
    end
  end

  def update_scoreboard_url_configuration(scoreboard_url)
    scoreboard_config_file = Rails.root.join('config', 'scoreboard_url')

    if File.exist?("#{scoreboard_config_file}.erb")
      content = File.read("#{scoreboard_config_file}.erb")
      
      # Handle nil values by converting to empty string
      scoreboard_url = scoreboard_url.to_s
      
      updated_content = content.gsub(
        /<%= scoreboard_url %>/,
        scoreboard_url
      )

      File.write(scoreboard_config_file, updated_content)
      puts "✓ Updated scoreboard_url with URL: #{scoreboard_url}"
    else
      puts "⚠️  scoreboard_url.erb not found, skipping scoreboard_url update"
    end
  end

  def generate_scoreboard_url(location_id)
    return "https://scoreboard.carambus.de" if location_id.blank?
    "https://scoreboard.carambus.de/locations/#{Digest::MD5.hexdigest(location_id.to_s)}"
  end
end
