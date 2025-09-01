# frozen_string_literal: true

namespace :mode do
  desc "Switch to LOCAL mode (empty carambus_api_url, local database)"
  task  :local, [:season_name, :application_name, :context, :api_url, :basename, :database, :domain, :location_id, :club_id, :host, :port, :branch] => :environment do |task, args|
    season_name = args.season_name || "2025/2026"
    application_name = args.application_name || 'carambus'
    context = args.context || 'NBV'
    api_url = args.api_url || 'https://newapi.carambus.de/'
    basename = args.basename || 'carambus'
    database = args.database || 'carambus_production'
    domain = args.domain || 'carambus.de'
    location_id = args.location_id || '1'
    club_id = args.club_id || '357'
    rails_env = args.rails_env || 'production'
    host = args.host || 'new.carambus.de'
    port = args.port || '3000'
    branch = args.branch || 'master'
    puts "Switching to LOCAL mode..."

    # Update carambus.yml
    update_carambus_yml(season_name=season_name, carambus_api_url=api_url, basename=basename, carambus_domain=domain, location_id=location_id, application_name=application_name, context=context, club_id=club_id)

    # Update database.yml
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Manage log files for LOCAL mode
    manage_log_files("local")

    puts "Switched to LOCAL mode successfully"
    puts "Current mode: LOCAL (carambus_api_url is set, local database)"
  end

  desc "Switch to API mode (set carambus_api_url, API database)"
  task api: :environment do
    puts "Switching to API mode..."

    # Update carambus.yml
    update_carambus_yml(carambus_api_url="", basename="carambus_api", carambus_domain="api.carambus.de", location_id="", application_name="carambus", context="", club_id="")

    # Generate YAML with proper anchor syntax for API mode
    update_database_yml("carambus_api_development")

    # Update deploy.rb for API mode
    update_deploy_rb("carambus_api")

    # Manage log files for API mode
    manage_log_files("api")

    puts "Switched to API mode successfully"
    puts "Current mode: API (carambus_api_url is empty, API database)"
  end

  desc "Show current mode and configuration"
  task status: :environment do
    puts "Current Configuration:"

    # Read carambus.yml
    if File.exist?(Rails.root.join('config', 'carambus.yml'))
      carambus_config = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
      api_url = carambus_config.dig('development', 'carambus_api_url')
      context = carambus_config.dig('development', 'context')
      puts "  API URL: #{api_url || 'empty'}"
      puts "  Context: #{context}"
    end

    # Read database.yml
    if File.exist?(Rails.root.join('config', 'database.yml'))
      database_config = YAML.load_file(Rails.root.join('config', 'database.yml'))
      database = database_config.dig('development', 'database')
      puts "  Database: #{database}"
    end

    # Read deploy.rb basename
    if File.exist?(Rails.root.join('config', 'deploy.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy.rb'))
      if deploy_content.match(/set :basename, "([^"]+)"/)
        basename = $1
        puts "  Deploy Basename: #{basename}"
      end
    end

    # Check log file status
    development_log = Rails.root.join('log', 'development.log')
    if File.symlink?(development_log)
      log_target = File.readlink(development_log)
      log_file = File.basename(log_target)
      puts "  Log File: #{log_file}"
    else
      puts "  Log File: direct file (not linked)"
    end

    # Determine mode
    if api_url.nil? || api_url.empty?
      puts "Current Mode: API"
    else
      puts "Current Mode: LOCAL"
    end
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

  private

  def update_deploy_rb(basename)
    deploy_file = Rails.root.join('config', 'deploy.rb')

    if File.exist?("#{deploy_file}.erb")
      content = File.read("#{deploy_file}.erb")
      updated_content = content.gsub(
        /<%= basename %>/,
        basename
      )

      File.write(deploy_file, updated_content)
      puts "✓ Updated deploy.rb basename to: #{basename}"
    else
      puts "⚠️  deploy.rb.erb not found, skipping basename update"
    end
  end

  def update_deploy_environment_rb(rails_env, host, port, branch)
    deploy_environment_file = Rails.root.join('config', 'deploy', "#{rails_env}.rb")

    if File.exist?("#{deploy_environment_file}.erb")
      content = File.read("#{deploy_environment_file}.erb")
      updated_content = content.gsub(
        /<%= host %>/,
        host
      ).gsub(
        /<%= port %>/,
        port
      ).gsub(
        /<%= branch %>/,
        branch
      )

      File.write(deploy_environment_file, updated_content)
      puts "✓ Updated deploy/#{rails_env}.rb \nhost to: #{host} \nport to: #{port} \nbranch to: #{branch} "

    else
      puts "⚠️  deploy.rb.erb not found, skipping basename update"
    end
  end

  def update_database_yml(database)
    database_yml_file = Rails.root.join('config', 'database.yml')

    if File.exist?("#{database_yml_file}.erb")
      content = File.read("#{database_yml_file}.erb")
      updated_content = content.gsub(
        /<%= database %>/,
        database
      )

      File.write(database_yml_file, updated_content)
      puts "✓ Updated database_yml.rb basename to: #{database}"
    else
      puts "⚠️  database_yml.rb.erb not found, skipping basename update"
    end
  end

  def update_carambus_yml(season_name, carambus_api_url, basename, carambus_domain, location_id, application_name, context, club_id)
    carambus_yml_file = Rails.root.join('config', 'carambus.yml')

    if File.exist?("#{carambus_yml_file}.erb")
      content = File.read("#{carambus_yml_file}.erb")
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
      puts "✓ Updated carambus_yml basename to: \n#{updated_content}"
    else
      puts "⚠️  deploy.rb.erb not found, skipping basename update"
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
end
