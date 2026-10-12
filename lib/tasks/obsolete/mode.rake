# frozen_string_literal: true

namespace :mode do
  desc "Switch to LOCAL mode with named parameters"
  task :local => :environment do
    params = parse_named_parameters_from_env
    
    season_name = params[:season_name] || "2025/2026"
    application_name = params[:application_name] || 'carambus'
    context = params[:context] || 'NBV'
    api_url = params[:api_url] || 'https://newapi.carambus.de/'
    location_id = params[:location_id] || '1'
    club_id = params[:club_id] || '357'
    rails_env = params[:rails_env] || 'development'
    host = params[:host] || 'carambus.de'
    port = params[:port] || '8910'  # SSH Port, not application port
    branch = params[:branch] || 'master'
    puma_script = params[:puma_script] || 'manage-puma.sh'
    
    # Auto-generate project name from location_id
    shortname = params[:shortname]
    if shortname
      # Use shortname if provided: carambus_{shortname}_{environment}
      project_name = "carambus_#{shortname}"
      basename = project_name
      database = "#{project_name}_#{rails_env}"
    else
      # Use location_id: carambus_location_{id}_{environment}
      project_name = "carambus_location_#{location_id}"
      basename = project_name
      database = "#{project_name}_#{rails_env}"
    end
    
    domain = params[:domain] || 'carambus.de'
    
    # New parameters for NGINX and Puma
    nginx_port = params[:nginx_port] || '80'  # NGINX web port
    puma_socket = params[:puma_socket] || "puma-#{rails_env}.sock"  # Puma socket name
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id, basename, rails_env)
    
    puts "🚀 Switching to LOCAL mode with named parameters..."
    puts "Parameters: #{params.inspect}"
    puts "📁 Project: #{project_name}"
    puts "🗄️  Database: #{database}"
    puts "📍 Location ID: #{location_id}"
    puts "🎯 Environment: #{rails_env}"

    # Update carambus.yml
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)

    # Update database.yml with project-specific configuration
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename, domain)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Update Puma configuration for LOCAL mode
    update_puma_configuration(puma_script, basename)

    # Update NGINX configuration
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_socket)

    # Update Puma service configuration
    update_puma_service_configuration(basename, puma_socket, rails_env)

    # Update Puma.rb configuration
    update_puma_rb_configuration(basename, rails_env)

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
    puma_socket = params[:puma_socket] || "puma-#{rails_env}.sock"  # Puma socket name
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id, basename, rails_env)
    
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
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_socket)

    # Update Puma service configuration
    update_puma_service_configuration(basename, puma_socket, rails_env)

    # Update Puma.rb configuration
    update_puma_rb_configuration(basename, rails_env)

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

  desc "Prepare database dump for deployment (development to production)"
  task :prepare_db_dump => :environment do
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    dump_file = "carambus_api_development_#{timestamp}.sql.gz"
    
    puts "🗄️  Creating database dump: #{dump_file}"
    puts "📊 Source database: carambus_api_development"
    puts "🎯 Target database: carambus_api_production (on server)"
    
    # Create database dump from development database
    system("pg_dump carambus_api_development | gzip > #{dump_file}")
    
    if $?.success?
      puts "✅ Database dump created successfully: #{dump_file}"
      puts "📁 Location: #{File.expand_path(dump_file)}"
    else
      puts "❌ Failed to create database dump"
      exit 1
    end
  end

  desc "Download database dump from production server (production to development)"
  task :download_db_dump => :environment do
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    dump_file = "carambus_api_production_#{timestamp}.sql.gz"
    
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "📥 Downloading database dump: #{dump_file}"
    puts "📊 Source database: carambus_api_production (on server)"
    puts "🎯 Target database: carambus_api_development (local)"
    
    # Create dump on server
    remote_dump_command = "cd /var/www/#{deploy_config[:basename]}/current && pg_dump -Uwww_data carambus_api_production | gzip > #{dump_file}"
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} '#{remote_dump_command}'")
    
    if $?.success?
      # Download dump from server
      system("scp -P #{deploy_config[:port]} www-data@#{deploy_config[:host]}:/var/www/#{deploy_config[:basename]}/current/#{dump_file} .")
      
      if $?.success?
        puts "✅ Database dump downloaded successfully: #{dump_file}"
        puts "📁 Location: #{File.expand_path(dump_file)}"
      else
        puts "❌ Failed to download database dump"
        exit 1
      end
    else
      puts "❌ Failed to create database dump on server"
      exit 1
    end
  end

  desc "List available database dumps"
  task :list_db_dumps => :environment do
    puts "🗄️  Available database dumps:"
    puts "-" * 40
    
    # List both development and production dumps
    dev_dumps = Dir.glob("carambus_api_development_*.sql.gz").sort.reverse
    prod_dumps = Dir.glob("carambus_api_production_*.sql.gz").sort.reverse
    
    if dev_dumps.empty? && prod_dumps.empty?
      puts "No database dumps found"
    else
      if dev_dumps.any?
        puts "\n📊 Development dumps (for upload to production):"
        dev_dumps.each do |dump|
          size = File.size(dump)
          date = File.mtime(dump).strftime('%Y-%m-%d %H:%M:%S')
          puts "  #{dump} (#{size} bytes, #{date})"
        end
      end
      
      if prod_dumps.any?
        puts "\n🎯 Production dumps (for download to development):"
        prod_dumps.each do |dump|
          size = File.size(dump)
          date = File.mtime(dump).strftime('%Y-%m-%d %H:%M:%S')
          puts "  #{dump} (#{size} bytes, #{date})"
        end
      end
    end
  end

  desc "Check version sequence numbers for safety"
  task :check_version_safety, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:check_version_safety[carambus_api_development_20250102_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    puts "🔍 Checking version sequence safety..."
    puts "Dump file: #{dump_file}"
    
    # Extract version sequence from dump
    dump_content = `gunzip -c #{dump_file}`
    
    # Find the highest version ID in the dump
    version_matches = dump_content.scan(/INSERT INTO versions.*VALUES.*\((\d+),/)
    if version_matches.any?
      dump_max_version = version_matches.flatten.map(&:to_i).max
      puts "📊 Highest version ID in dump: #{dump_max_version}"
      
      # Check current database version
      begin
        current_max_version = ActiveRecord::Base.connection.execute("SELECT MAX(id) FROM versions").first['max'].to_i
        puts "🎯 Current max version ID in database: #{current_max_version}"
        
        if dump_max_version > current_max_version
          puts "✅ SAFE: Dump has higher version numbers - safe to import"
        elsif dump_max_version == current_max_version
          puts "⚠️  WARNING: Dump has same version numbers - potential conflicts"
        else
          puts "❌ DANGER: Dump has lower version numbers - would overwrite newer data!"
          puts "   This operation is BLOCKED for safety."
          exit 1
        end
      rescue => e
        puts "⚠️  Could not check current database: #{e.message}"
        puts "   Proceeding with caution..."
      end
    else
      puts "⚠️  No versions found in dump"
      puts "   Proceeding with caution..."
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
    
    puts "🚀 Deploying templates to production server..."
    puts "Server: #{deploy_config[:host]}:#{deploy_config[:port]}"
    puts "Basename: #{deploy_config[:basename]}"
    
    # Deploy NGINX configuration
    nginx_source = Rails.root.join('config', 'nginx.conf')
    if File.exist?(nginx_source)
      nginx_target = "/etc/nginx/sites-available/#{deploy_config[:basename]}"
      deploy_file(nginx_source, nginx_target, deploy_config)
      puts "✓ NGINX config deployed to #{nginx_target}"
    end
    
    # Deploy Puma service configuration
    puma_service_source = Rails.root.join('config', 'puma.service')
    if File.exist?(puma_service_source)
      puma_target = "/etc/systemd/system/puma-#{deploy_config[:basename]}.service"
      deploy_file(puma_service_source, puma_target, deploy_config)
      puts "✓ Puma service config deployed to #{puma_target}"
    end
    
    # Deploy Puma.rb configuration
    puma_rb_source = Rails.root.join('config', 'puma.rb')
    if File.exist?(puma_rb_source)
      puma_rb_target = "/var/www/#{deploy_config[:basename]}/shared/config/puma.rb"
      deploy_file(puma_rb_source, puma_rb_target, deploy_config)
      puts "✓ Puma.rb config deployed to #{puma_rb_target}"
    end
    
    # Deploy scoreboard configuration
    scoreboard_source = Rails.root.join('config', 'scoreboard_url')
    if File.exist?(scoreboard_source)
      scoreboard_target = "/var/www/#{deploy_config[:basename]}/shared/config/scoreboard_url"
      deploy_file(scoreboard_source, scoreboard_target, deploy_config)
      puts "✓ Scoreboard config deployed to #{scoreboard_target}"
    end
    
    # Deploy database.yml
    database_source = Rails.root.join('config', 'database.yml')
    if File.exist?(database_source)
      database_target = "/var/www/#{deploy_config[:basename]}/shared/config/database.yml"
      deploy_file(database_source, database_target, deploy_config)
      puts "✓ Database config deployed to #{database_target}"
    end
    
    # Deploy carambus.yml
    carambus_source = Rails.root.join('config', 'carambus.yml')
    if File.exist?(carambus_source)
      carambus_target = "/var/www/#{deploy_config[:basename]}/shared/config/carambus.yml"
      deploy_file(carambus_source, carambus_target, deploy_config)
      puts "✓ Carambus config deployed to #{carambus_target}"
    end
    
    # Deploy credentials
    credentials_dir = Rails.root.join('config', 'credentials')
    if Dir.exist?(credentials_dir)
      # Deploy production.key
      production_key_source = credentials_dir.join('production.key')
      if File.exist?(production_key_source)
        production_key_target = "/var/www/#{deploy_config[:basename]}/shared/config/credentials/production.key"
        deploy_file(production_key_source, production_key_target, deploy_config)
        puts "✓ Production key deployed to #{production_key_target}"
      end
      
      # Deploy production.yml.enc
      production_yml_source = credentials_dir.join('production.yml.enc')
      if File.exist?(production_yml_source)
        production_yml_target = "/var/www/#{deploy_config[:basename]}/shared/config/credentials/production.yml.enc"
        deploy_file(production_yml_source, production_yml_target, deploy_config)
        puts "✓ Production credentials deployed to #{production_yml_target}"
      end
    end
    
    # Deploy production.rb environment
    production_rb_source = Rails.root.join('config', 'environments', 'production.rb')
    if File.exist?(production_rb_source)
      production_rb_target = "/var/www/#{deploy_config[:basename]}/shared/config/environments/production.rb"
      deploy_file(production_rb_source, production_rb_target, deploy_config)
      puts "✓ Production environment deployed to #{production_rb_target}"
    end
    
    # Activate NGINX configuration
    puts "🔧 Activating NGINX configuration..."
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo ln -sf /etc/nginx/sites-available/#{deploy_config[:basename]} /etc/nginx/sites-enabled/'")
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo nginx -t && sudo systemctl reload nginx'")
    puts "✓ NGINX configuration activated"
    
    puts "✅ All templates deployed successfully"
  end

  desc "Deploy database dump to production server (with safety check)"
  task :deploy_db_dump, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:deploy_db_dump[carambus_api_development_20250101_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    # Check if it's a development dump (safe to upload)
    unless dump_file.include?('carambus_api_development_')
      puts "❌ Only development dumps can be uploaded to production"
      puts "   Expected format: carambus_api_development_YYYYMMDD_HHMMSS.sql.gz"
      exit 1
    end
    
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "🚀 Deploying database dump to production server..."
    puts "Dump file: #{dump_file}"
    puts "Server: #{deploy_config[:host]}:#{deploy_config[:port]}"
    
    # Safety check: Check version sequence numbers
    puts "🔍 Performing safety check..."
    Rake::Task['mode:check_version_safety'].invoke(dump_file)
    
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
    else
      puts "❌ Failed to deploy database dump"
      exit 1
    end
  end

  desc "Restore database from dump on production server (drop and replace)"
  task :restore_db_dump, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:restore_db_dump[carambus_api_development_20250101_120000.sql.gz]'"
      exit 1
    end
    
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "🗄️  Restoring database from dump (DROP AND REPLACE)..."
    puts "Dump file: #{dump_file}"
    puts "Server: #{deploy_config[:host]}:#{deploy_config[:port]}"
    puts "Target database: #{deploy_config[:basename]}_production"
    
    # Confirm the operation
    puts "⚠️  WARNING: This will DROP and REPLACE the production database!"
    puts "   Are you sure? (type 'yes' to continue):"
    confirmation = STDIN.gets.chomp
    
    unless confirmation.downcase == 'yes'
      puts "❌ Operation cancelled"
      exit 1
    end
    
    remote_dump_file = "/var/www/#{deploy_config[:basename]}/shared/database_dumps/#{File.basename(dump_file)}"
    target_db = "#{deploy_config[:basename]}_production"
    
    # Drop and recreate database
    drop_and_restore_commands = [
      "sudo systemctl stop puma-#{deploy_config[:basename]}.service",
      "sudo -u postgres dropdb #{target_db}",
      "sudo -u postgres createdb #{target_db}",
      "sudo -u postgres psql #{target_db} -c 'ALTER DATABASE #{target_db} OWNER TO www_data;'",
      "gunzip -c #{remote_dump_file} | sudo -u postgres psql #{target_db}",
      "sudo systemctl start puma-#{deploy_config[:basename]}.service"
    ]
    
    restore_command = drop_and_restore_commands.join(" && ")
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} '#{restore_command}'")
    
    if $?.success?
      puts "✅ Database restored successfully (drop and replace)"
      puts "🔄 Puma service restarted"
    else
      puts "❌ Failed to restore database"
      exit 1
    end
  end

  desc "Restore local development database from production dump with region reduction"
  task :restore_local_db_with_region_reduction, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:restore_local_db_with_region_reduction[carambus_api_production_20250102_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    # Check if it's a production dump (safe to download)
    unless dump_file.include?('carambus_api_production_')
      puts "❌ Only production dumps can be restored to development"
      puts "   Expected format: carambus_api_production_YYYYMMDD_HHMMSS.sql.gz"
      exit 1
    end
    
    puts "🗄️  Restoring local development database with region reduction..."
    puts "Dump file: #{dump_file}"
    puts "Target database: carambus_api_development"
    
    # Confirm the operation
    puts "⚠️  WARNING: This will DROP and REPLACE your local development database!"
    puts "   The database will be reduced to region-specific data only."
    puts "   Are you sure? (type 'yes' to continue):"
    confirmation = STDIN.gets.chomp
    
    unless confirmation.downcase == 'yes'
      puts "❌ Operation cancelled"
      exit 1
    end
    
    # Step 1: Backup local changes
    puts "📋 Step 1: Backing up local changes..."
    Rake::Task['mode:backup_local_changes'].invoke
    
    # Find the backup file
    backup_files = Dir.glob("local_changes_filtered_*.sql").sort.reverse
    backup_file = backup_files.first if backup_files.any?
    
    if backup_file
      puts "📁 Local changes backup: #{backup_file}"
    else
      puts "📁 No local changes to backup"
    end
    
    # Step 2: Drop and recreate local database
    puts "📋 Step 2: Dropping and recreating database..."
    drop_and_restore_commands = [
      "dropdb carambus_api_development",
      "createdb carambus_api_development",
      "gunzip -c #{dump_file} | psql carambus_api_development"
    ]
    
    restore_command = drop_and_restore_commands.join(" && ")
    system(restore_command)
    
    if $?.success?
      puts "✅ Database restored successfully"
    else
      puts "❌ Failed to restore database"
      exit 1
    end
    
    # Step 3: Update region taggings
    puts "📋 Step 3: Updating region taggings..."
    Rake::Task['region_taggings:update_all_region_ids'].invoke
    
    # Step 4: Reduce database to region-specific data
    puts "📋 Step 4: Reducing database to region-specific data..."
    Rake::Task['cleanup:remove_non_region_records'].invoke
    
    # Step 5: Restore local changes if any
    if backup_file
      puts "📋 Step 5: Restoring local changes..."
      Rake::Task['mode:restore_local_changes'].invoke(backup_file)
    end
    
    puts "✅ Local development database restored with region reduction"
    puts "📊 Database: carambus_api_development"
    puts "🎯 Region-specific data only"
    puts "💾 Local changes: #{backup_file}" if backup_file
  end

  desc "Restore local development database from production dump (drop and replace)"
  task :restore_local_db, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:restore_local_db[carambus_api_production_20250101_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    # Check if it's a production dump (safe to download)
    unless dump_file.include?('carambus_api_production_')
      puts "❌ Only production dumps can be restored to development"
      puts "   Expected format: carambus_api_production_YYYYMMDD_HHMMSS.sql.gz"
      exit 1
    end
    
    puts "🗄️  Restoring local development database from production dump..."
    puts "Dump file: #{dump_file}"
    puts "Target database: carambus_api_development"
    
    # Confirm the operation
    puts "⚠️  WARNING: This will DROP and REPLACE your local development database!"
    puts "   Are you sure? (type 'yes' to continue):"
    confirmation = STDIN.gets.chomp
    
    unless confirmation.downcase == 'yes'
      puts "❌ Operation cancelled"
      exit 1
    end
    
    # Drop and recreate local database
    drop_and_restore_commands = [
      "dropdb carambus_api_development",
      "createdb carambus_api_development",
      "gunzip -c #{dump_file} | psql carambus_api_development"
    ]
    
    restore_command = drop_and_restore_commands.join(" && ")
    system(restore_command)
    
    if $?.success?
      puts "✅ Local development database restored successfully"
      puts "📊 Database: carambus_api_development"
    else
      puts "❌ Failed to restore local database"
      exit 1
    end
  end

  desc "Backup local changes (records with ID > 50,000,000) before database replacement"
  task :backup_local_changes => :environment do
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    backup_file = "local_changes_backup_#{timestamp}.sql"
    
    puts "💾 Backing up local changes (ID > 50,000,000)..."
    puts "Backup file: #{backup_file}"
    
    # Create backup of local changes using pg_dump with custom query
    backup_command = "pg_dump carambus_api_development --data-only --disable-triggers --no-owner --no-privileges --no-tablespaces --no-unlogged-table-data --verbose --file=#{backup_file} --table=users --table=tournaments --table=games --table=players --table=regions --table=disciplines --table=seasons --table=seedings --table=game_participations --table=versions --table=settings"
    
    system(backup_command)
    
    if $?.success?
      puts "✅ Local changes backup created: #{backup_file}"
      puts "📁 Location: #{File.expand_path(backup_file)}"
      
      # Filter to only include records with ID > 50,000,000
      puts "🔍 Filtering local changes (ID > 50,000,000)..."
      filtered_file = "local_changes_filtered_#{timestamp}.sql"
      
      # Simple filtering using grep and awk
      filter_command = "grep -E '^(\\d+)\\t' #{backup_file} | awk -F'\\t' '\$1 > 50000000' > #{filtered_file}"
      system(filter_command)
      
      if $?.success?
        puts "✅ Filtered local changes: #{filtered_file}"
        puts "📊 Only records with ID > 50,000,000 included"
        
        # Check if filtered file has content
        if File.exist?(filtered_file) && File.size(filtered_file) > 0
          puts "📈 Filtered file size: #{File.size(filtered_file)} bytes"
        else
          puts "⚠️  No local changes found (ID > 50,000,000)"
        end
      else
        puts "⚠️  Warning: Could not filter local changes"
      end
      
      # Clean up original backup
      File.delete(backup_file)
      puts "🗑️  Removed original backup file"
    else
      puts "❌ Failed to create local changes backup"
      exit 1
    end
  end

  desc "Restore local changes after database replacement"
  task :restore_local_changes, [:backup_file] => :environment do |task, args|
    backup_file = args.backup_file
    if backup_file.blank?
      puts "❌ Local changes backup file required"
      puts "Usage: bundle exec rails 'mode:restore_local_changes[local_changes_filtered_20250102_120000.sql]'"
      exit 1
    end
    
    unless File.exist?(backup_file)
      puts "❌ Local changes backup file not found: #{backup_file}"
      exit 1
    end
    
    puts "🔄 Restoring local changes after database replacement..."
    puts "Backup file: #{backup_file}"
    
    # Restore local changes
    restore_command = "psql carambus_api_development < #{backup_file}"
    system(restore_command)
    
    if $?.success?
      puts "✅ Local changes restored successfully"
      puts "📊 Records with ID > 50,000,000 restored"
    else
      puts "❌ Failed to restore local changes"
      exit 1
    end
  end

  desc "Restore local development database from production dump with local changes preservation"
  task :restore_local_db_with_preservation, [:dump_file] => :environment do |task, args|
    dump_file = args.dump_file
    if dump_file.blank?
      puts "❌ Database dump file required"
      puts "Usage: bundle exec rails 'mode:restore_local_db_with_preservation[carambus_api_production_20250102_120000.sql.gz]'"
      exit 1
    end
    
    unless File.exist?(dump_file)
      puts "❌ Database dump file not found: #{dump_file}"
      exit 1
    end
    
    # Check if it's a production dump (safe to download)
    unless dump_file.include?('carambus_api_production_')
      puts "❌ Only production dumps can be restored to development"
      puts "   Expected format: carambus_api_production_YYYYMMDD_HHMMSS.sql.gz"
      exit 1
    end
    
    puts "🗄️  Restoring local development database with local changes preservation..."
    puts "Dump file: #{dump_file}"
    puts "Target database: carambus_api_development"
    
    # Confirm the operation
    puts "⚠️  WARNING: This will DROP and REPLACE your local development database!"
    puts "   Local changes (ID > 50,000,000) will be preserved and restored."
    puts "   Are you sure? (type 'yes' to continue):"
    confirmation = STDIN.gets.chomp
    
    unless confirmation.downcase == 'yes'
      puts "❌ Operation cancelled"
      exit 1
    end
    
    # Step 1: Backup local changes
    puts "📋 Step 1: Backing up local changes..."
    Rake::Task['mode:backup_local_changes'].invoke
    
    # Find the backup file
    backup_files = Dir.glob("local_changes_filtered_*.sql").sort.reverse
    if backup_files.empty?
      puts "❌ No local changes backup found"
      exit 1
    end
    
    backup_file = backup_files.first
    puts "📁 Local changes backup: #{backup_file}"
    
    # Step 2: Drop and recreate local database
    puts "📋 Step 2: Dropping and recreating database..."
    drop_and_restore_commands = [
      "dropdb carambus_api_development",
      "createdb carambus_api_development",
      "gunzip -c #{dump_file} | psql carambus_api_development"
    ]
    
    restore_command = drop_and_restore_commands.join(" && ")
    system(restore_command)
    
    if $?.success?
      puts "✅ Database restored successfully"
    else
      puts "❌ Failed to restore database"
      exit 1
    end
    
    # Step 3: Restore local changes
    puts "📋 Step 3: Restoring local changes..."
    Rake::Task['mode:restore_local_changes'].invoke(backup_file)
    
    puts "✅ Local development database restored with local changes preserved"
    puts "📊 Database: carambus_api_development"
    puts "💾 Local changes: #{backup_file}"
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

  desc "Generate templates for deployment"
  task :generate_templates => :environment do
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "🔧 Generating templates for deployment..."
    puts "Basename: #{deploy_config[:basename]}"
    
    # Read scenario configuration to get parameters
    scenario_config = read_scenario_config(deploy_config[:basename])
    if scenario_config
      domain = scenario_config.dig('environments', 'production', 'webserver_host') || 'carambus.de'
      nginx_port = scenario_config.dig('environments', 'production', 'webserver_port') || '80'
      ssl_enabled = scenario_config.dig('environments', 'production', 'ssl_enabled') ? 'true' : 'false'
      location_id = scenario_config.dig('scenario', 'location_id') || '1'
    else
      # Fallback to local configuration
      carambus_config = read_local_deployment_config('carambus.yml')
      if carambus_config
        domain = carambus_config.dig('production', 'carambus_domain') || 'carambus.de'
        location_id = carambus_config.dig('production', 'location_id') || '1'
      else
        domain = 'carambus.de'
        location_id = '1'
      end
      nginx_port = '80'
      ssl_enabled = 'false'
    end
    
    # Default parameters
    basename = deploy_config[:basename]
    puma_socket = basename == 'carambus_api' ? "puma-production.sock" : "puma-#{deploy_config[:rails_env]}.sock"
    rails_env = deploy_config[:rails_env] || 'production'
    scoreboard_url = generate_scoreboard_url(location_id, basename, rails_env)
    
    # Generate NGINX configuration
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_socket)
    
    # Generate Puma service configuration
    update_puma_service_configuration(basename, puma_socket, rails_env)
    
    # Generate Puma.rb configuration
    update_puma_rb_configuration(basename, rails_env)

    # Generate scoreboard URL configuration
    update_scoreboard_url_configuration(scoreboard_url)
    
    puts "✅ Templates generated successfully"
    puts "📁 Generated files:"
    puts "  - config/nginx.conf"
    puts "  - config/puma.service"
    puts "  - config/puma.rb"
    puts "  - config/scoreboard_url"
  end

  desc "Complete automated deployment preparation and execution"
  task :full_deploy => :environment do
    puts "🚀 STARTING COMPLETE AUTOMATED DEPLOYMENT"
    puts "=" * 60
    
    deploy_config = get_deploy_config
    return puts "❌ No deployment configuration found" unless deploy_config
    
    puts "🎯 Target: #{deploy_config[:host]}:#{deploy_config[:port]}"
    puts "📦 Basename: #{deploy_config[:basename]}"
    puts ""
    
    # Step 1: Generate all templates
    puts "📋 Step 1: Generating templates..."
    Rake::Task['mode:generate_templates'].invoke
    
    # Step 2: Create database dump
    puts "\n🗄️  Step 2: Creating database dump..."
    Rake::Task['mode:prepare_db_dump'].invoke
    
    # Step 3: Deploy all files to server
    puts "\n📤 Step 3: Deploying all files to server..."
    
    # Deploy configuration files
    config_files = {
      'config/database.yml' => "/var/www/#{deploy_config[:basename]}/shared/config/database.yml",
      'config/carambus.yml' => "/var/www/#{deploy_config[:basename]}/shared/config/carambus.yml", 
      'config/scoreboard_url' => "/var/www/#{deploy_config[:basename]}/shared/config/scoreboard_url",
      'config/nginx.conf' => "/etc/nginx/sites-available/#{deploy_config[:basename]}",
      'config/puma.service' => "/etc/systemd/system/puma-#{deploy_config[:basename]}.service",
      'config/puma.rb' => "/var/www/#{deploy_config[:basename]}/shared/config/puma.rb",
      'bin/puma-wrapper.sh' => "/var/www/#{deploy_config[:basename]}/current/bin/puma-wrapper.sh"
    }
    
    config_files.each do |source, target|
      if File.exist?(source)
        deploy_file(source, target, deploy_config)
        # Make puma-wrapper.sh executable
        if source == 'bin/puma-wrapper.sh'
          system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo chmod +x #{target}'")
          puts "✓ Made #{target} executable"
        end
      else
        puts "⚠️  #{source} not found, skipping"
      end
    end
    
    # Deploy database dump
    dump_files = Dir.glob("#{deploy_config[:basename]}_production_*.sql.gz").sort.last
    if dump_files
      remote_dump_path = "/var/www/#{deploy_config[:basename]}/shared/database_dumps/"
      puts "📊 Deploying database dump: #{dump_files}"
      system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'mkdir -p #{remote_dump_path}'")
      system("scp -P #{deploy_config[:port]} #{dump_files} www-data@#{deploy_config[:host]}:#{remote_dump_path}")
      
      if $?.success?
        puts "✓ Database dump deployed successfully"
        
        # Step 4: Restore database
        puts "\n🔄 Step 4: Restoring database..."
        remote_dump_file = "#{remote_dump_path}#{File.basename(dump_files)}"
        restore_cmd = "gunzip -c #{remote_dump_file} | sudo -u postgres psql #{deploy_config[:basename]}_production"
        system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} '#{restore_cmd}'")
        
        if $?.success?
          puts "✓ Database restored successfully"
        else
          puts "⚠️  Database restore had warnings (this is normal for existing databases)"
        end
      else
        puts "❌ Failed to deploy database dump"
        exit 1
      end
    end
    
    # Step 5: Create missing directories and set permissions
    puts "\n📁 Step 5: Creating directories and setting permissions..."
    dirs_to_create = [
      "/var/www/#{deploy_config[:basename]}/shared/config",
      "/var/www/#{deploy_config[:basename]}/shared/config/credentials",
      "/var/www/#{deploy_config[:basename]}/shared/config/environments",
      "/var/www/#{deploy_config[:basename]}/shared/sockets",
      "/var/www/#{deploy_config[:basename]}/shared/pids",
      "/var/www/#{deploy_config[:basename]}/shared/log"
    ]
    
    dirs_to_create.each do |dir|
      system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo mkdir -p #{dir} && sudo chown -R www-data:www-data #{dir}'")
      puts "✓ Created and set permissions for #{dir}"
    end
    
    # Step 6: Deploy missing files (credentials, environments)
    puts "\n🔐 Step 6: Deploying credentials and environment files..."
    additional_files = {
      'config/credentials/production.key' => "/var/www/#{deploy_config[:basename]}/shared/config/credentials/production.key",
      'config/credentials/production.yml.enc' => "/var/www/#{deploy_config[:basename]}/shared/config/credentials/production.yml.enc",
      'config/environments/production.rb' => "/var/www/#{deploy_config[:basename]}/shared/config/environments/production.rb"
    }
    
    additional_files.each do |source, target|
      if File.exist?(source)
        deploy_file(source, target, deploy_config)
      else
        puts "⚠️  #{source} not found, skipping"
      end
    end
    
    # Step 7: Activate NGINX configuration
    puts "\n🌐 Step 7: Activating NGINX configuration..."
    nginx_source = "/etc/nginx/sites-available/#{deploy_config[:basename]}"
    nginx_target = "/etc/nginx/sites-enabled/#{deploy_config[:basename]}"
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo ln -sf #{nginx_source} #{nginx_target}'")
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo nginx -t && sudo systemctl reload nginx'")
    
    if $?.success?
      puts "✓ NGINX configuration activated and reloaded"
    else
      puts "❌ NGINX configuration failed"
      exit 1
    end
    
    # Step 8: Enable and start Puma service
    puts "\n⚡ Step 8: Configuring Puma service..."
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo systemctl daemon-reload'")
    system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo systemctl enable puma-#{deploy_config[:basename]}.service'")
    puts "✓ Puma service enabled"
    
    puts "\n✅ COMPLETE AUTOMATED DEPLOYMENT FINISHED"
    puts "=" * 60
    puts "🎉 Now you can run: bundle exec cap production deploy"
    puts ""
  end

  desc "Complete deployment preparation (templates + database dump)"
  task :prepare_deployment => :environment do
    puts "🚀 PREPARING COMPLETE DEPLOYMENT"
    puts "=" * 50
    
    # Step 1: Generate templates
    puts "\n📋 Step 1: Generating templates..."
    Rake::Task['mode:generate_templates'].invoke
    
    # Step 2: Prepare database dump
    puts "\n🗄️  Step 2: Preparing database dump..."
    Rake::Task['mode:prepare_db_dump'].invoke
    
    puts "\n✅ Deployment preparation completed!"
    puts "📁 Next steps:"
    puts "  1. Run: bundle exec rails mode:deploy_templates"
    puts "  2. Run: bundle exec rails 'mode:deploy_db_dump[carambus_api_production_YYYYMMDD_HHMMSS.sql.gz]'"
    puts "  3. Run: bundle exec rails 'mode:restore_db_dump[carambus_api_production_YYYYMMDD_HHMMSS.sql.gz]'"
    puts "  4. Run: bundle exec cap production deploy"
  end

  desc "Generate LOCAL DEVELOPMENT configurations"
  task :local_dev => :environment do
    params = parse_named_parameters_from_env
    
    # Auto-detect project name from current directory
    project_name = File.basename(Dir.pwd)
    
    season_name = params[:season_name] || "2025/2026"
    application_name = params[:application_name] || 'carambus'
    context = params[:context] || 'NBV'
    api_url = params[:api_url] || 'https://newapi.carambus.de/'
    basename = params[:basename] || project_name
    database = params[:database] || "#{project_name}_development"
    domain = params[:domain] || 'carambus.de'
    location_id = params[:location_id] || '1'
    club_id = params[:club_id] || '357'
    rails_env = params[:rails_env] || 'development'
    host = params[:host] || 'carambus.de'
    port = params[:port] || '8910'  # SSH Port, not application port
    branch = params[:branch] || 'master'
    puma_script = params[:puma_script] || 'manage-puma.sh'
    
    # New parameters for NGINX and Puma
    nginx_port = params[:nginx_port] || '80'  # NGINX web port
    puma_socket = params[:puma_socket] || "puma-#{rails_env}.sock"  # Puma socket name
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id, basename, rails_env)
    
    puts "🔧 Generating LOCAL DEVELOPMENT configurations..."
    puts "📁 Project: #{project_name}"
    puts "🗄️  Database: #{database}"

    # Update carambus.yml in config/
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)
    
    # Update database.yml in config/
    update_database_yml(database)
    
    # Update deploy.rb for LOCAL mode in config/
    update_deploy_rb(basename, domain)
    
    # Update deploy.rb for LOCAL mode in config/
    update_deploy_environment_rb(rails_env, host, port, branch)
    
    # Update Puma configuration for LOCAL mode in config/
    update_puma_configuration(puma_script, basename)
    
    # Update NGINX configuration in config/
    update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_socket)
    
    # Update Puma service configuration in config/
    update_puma_service_configuration(basename, puma_socket, rails_env)
    
    # Update Puma.rb configuration in config/
    update_puma_rb_configuration(basename, rails_env)
    
    # Update scoreboard URL configuration in config/
    update_scoreboard_url_configuration(scoreboard_url)
    
    # Manage log files for LOCAL mode
    manage_log_files("local")
    
    puts "✅ Local development configurations generated in config/"
  end

  desc "Generate DEPLOYMENT configurations"
  task :deploy_config => :environment do
    params = parse_named_parameters_from_env
    
    # Auto-detect project name from current directory
    project_name = File.basename(Dir.pwd)
    
    season_name = params[:season_name] || "2025/2026"
    application_name = params[:application_name] || 'carambus'
    context = params[:context] || 'NBV'
    api_url = params[:api_url] || 'https://newapi.carambus.de/'
    basename = params[:basename] || project_name
    database = params[:database] || "#{project_name}_development"
    domain = params[:domain] || 'carambus.de'
    location_id = params[:location_id] || '1'
    club_id = params[:club_id] || '357'
    rails_env = params[:rails_env] || 'production'
    host = params[:host] || 'carambus.de'
    port = params[:port] || '8910'  # SSH Port, not application port
    branch = params[:branch] || 'master'
    puma_script = params[:puma_script] || 'manage-puma.sh'
    
    # New parameters for NGINX and Puma
    nginx_port = params[:nginx_port] || '80'  # NGINX web port
    puma_socket = params[:puma_socket] || "puma-#{rails_env}.sock"  # Puma socket name
    ssl_enabled = params[:ssl_enabled] || 'false'  # SSL enabled
    scoreboard_url = params[:scoreboard_url] || generate_scoreboard_url(location_id, basename, rails_env)
    
    puts "🚀 Generating DEPLOYMENT configurations..."
    puts "📁 Project: #{project_name}"
    puts "🗄️  Database: #{database}"
    
    # Create carambus_data directory
    carambus_data_dir = Rails.root.join('carambus_data')
    FileUtils.mkdir_p(carambus_data_dir)
    
    # Generate configurations in carambus_data/
    update_carambus_yml_deployment(carambus_data_dir, season_name, api_url, basename, domain, location_id, application_name, context, club_id)
    update_database_yml_deployment(carambus_data_dir, database)
    update_deploy_rb_deployment(carambus_data_dir, basename, domain)
    update_deploy_environment_rb_deployment(carambus_data_dir, rails_env, host, port, branch)
    update_puma_configuration_deployment(carambus_data_dir, puma_script, basename)
    update_nginx_configuration_deployment(carambus_data_dir, basename, domain, nginx_port, ssl_enabled, puma_socket)
    update_puma_service_configuration_deployment(carambus_data_dir, basename, puma_socket, rails_env)
    update_puma_rb_configuration_deployment(carambus_data_dir, basename, rails_env)
    update_scoreboard_url_configuration_deployment(carambus_data_dir, scoreboard_url)
    
    puts "✅ Deployment configurations generated in carambus_data/"
    puts "📝 Next step: Deploy using 'bundle exec cap production deploy'"
  end

  private

  def parse_named_parameters_from_env
    params = {}
    
    # Parse from environment variables
    %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script nginx_port puma_port ssl_enabled scoreboard_url puma_socket].each do |param|
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
    puts "  MODE_PUMA_SOCKET     - Puma socket name (default: puma-{rails_env}.sock)"
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
    puts "  bundle exec rails 'mode:local' MODE_HOST=192.168.1.100 MODE_PORT=22 MODE_NGINX_PORT=3131 MODE_PUMA_SOCKET=puma-production.sock MODE_SSL_ENABLED=false"
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
    
    # Determine correct database names based on the base database name
    # If database is already a full name (e.g., carambus_api_production), 
    # extract the base name for development/test environments
    if database.include?('_production')
      base_name = database.gsub('_production', '')
      development_db = "#{base_name}_development"
      test_db = "#{base_name}_test"
      production_db = database
    else
      # If database is a base name (e.g., carambus_api), append environment
      development_db = "#{database}_development"
      test_db = "#{database}_test"
      production_db = "#{database}_production"
    end
    
    # Create a simple database.yml without ERB
    content = <<~YAML
      ---
      default: &default
        adapter: postgresql
        encoding: unicode
        pool: 5

      development:
        <<: *default
        database: #{development_db}
        host: localhost

      test:
        <<: *default
        database: #{test_db}
        host: localhost

      production:
        <<: *default
        database: #{production_db}
        username: www-data
        password: "<aus carambus_data/secrets.yml: shared.database_password>"
        host: localhost
    YAML
    
    File.write(database_yml_file, content)
    puts "✓ Created database.yml with databases: #{development_db}, #{test_db}, #{production_db}"
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

  def update_puma_rb_configuration(basename, rails_env)
    puma_rb_file = Rails.root.join('config', 'puma.rb')

    if File.exist?("#{puma_rb_file}.erb")
      template_content = File.read("#{puma_rb_file}.erb")
      
      # Use proper ERB processing instead of simple string replacement
      template = ERB.new(template_content)
      
      # Set instance variables for ERB template
      @basename = basename.to_s
      @rails_env = rails_env.to_s
      
      # Generate the content using ERB
      updated_content = template.result(binding)
      
      File.write(puma_rb_file, updated_content)
      puts "✓ Updated puma.rb with parameters"
    else
      puts "⚠️  puma.rb.erb not found, skipping puma.rb update"
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

  def read_scenario_config(basename)
    scenario_file = Rails.root.join('..', 'carambus_data', 'scenarios', basename, 'config.yml')
    if File.exist?(scenario_file)
      YAML.load(File.read(scenario_file))
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
    # Find the first non-commented server line
    host_match = production_content.match(/^server '([^']+)'/)
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
      # Use scp for file transfer, then sudo for system directories
      if target.start_with?('/etc/') || target.start_with?('/var/www/')
        # First copy to a temporary location
        temp_target = "/tmp/#{File.basename(source)}"
        system("scp -P #{deploy_config[:port]} #{source} www-data@#{deploy_config[:host]}:#{temp_target}")
        
        if $?.success?
          # Then move to final location with sudo
          system("ssh -p #{deploy_config[:port]} www-data@#{deploy_config[:host]} 'sudo mkdir -p $(dirname #{target}) && sudo mv #{temp_target} #{target}'")
        end
      else
        # Regular scp for user directories
        system("scp -P #{deploy_config[:port]} #{source} www-data@#{deploy_config[:host]}:#{target}")
      end
      
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

  def update_nginx_configuration(basename, domain, nginx_port, ssl_enabled, puma_socket)
    nginx_config_file = Rails.root.join('config', 'nginx.conf')

    if File.exist?("#{nginx_config_file}.erb")
      content = File.read("#{nginx_config_file}.erb")
      
      # Handle nil values by converting to empty string
      basename = basename.to_s
      domain = domain.to_s
      nginx_port = nginx_port.to_s
      puma_socket = puma_socket.to_s
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
        /<%= puma_socket %>/,
        puma_socket
      ).gsub(
        /<%= ssl_enabled %>/,
        ssl_enabled
      )

      # Process ERB conditionals
      if ssl_enabled == 'true'
        # Remove the conditional blocks and keep only SSL content
        updated_content = updated_content.gsub(/<% if ssl_enabled == 'true' %>\s*/, '')
        updated_content = updated_content.gsub(/<% else %>.*<% end %>/m, '')
      else
        # Remove the conditional blocks and keep only non-SSL content
        updated_content = updated_content.gsub(/<% if ssl_enabled == 'true' %>.*?<% else %>/m, '')
        updated_content = updated_content.gsub(/<% end %>/, '')
      end

      File.write(nginx_config_file, updated_content)
      puts "✓ Updated nginx.conf with parameters"
    else
      puts "⚠️  nginx.conf.erb not found, skipping nginx.conf update"
    end
  end

  def update_puma_service_configuration(basename, puma_socket, rails_env)
    puma_service_file = Rails.root.join('config', 'puma.service')

    if File.exist?("#{puma_service_file}.erb")
      content = File.read("#{puma_service_file}.erb")
      
      # Handle nil values by converting to empty string
      basename = basename.to_s
      puma_socket = puma_socket.to_s
      rails_env = rails_env.to_s
      
      updated_content = content.gsub(
        /<%= basename %>/,
        basename
      ).gsub(
        /<%= puma_socket %>/,
        puma_socket
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

  def generate_scoreboard_url(location_id, basename = nil, rails_env = nil)
    # TODO: Disallow scoreboard access on API server
    # API servers should not have scoreboard functionality
    if basename == 'carambus_api' && rails_env == 'production'
      return ''  # Empty string for API servers
    end
    
    return "https://scoreboard.carambus.de" if location_id.blank?
    "https://scoreboard.carambus.de/locations/#{Digest::MD5.hexdigest(location_id.to_s)}"
  end
end
