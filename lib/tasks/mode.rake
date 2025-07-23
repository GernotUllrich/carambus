# frozen_string_literal: true

namespace :mode do
  desc "Switch to LOCAL mode (empty carambus_api_url, local database)"
  task local: :environment do
    puts "Switching to LOCAL mode..."

    # Update carambus.yml
    carambus_config = {
      "default" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0,
        "context" => "NBV",
        "season_name" => "2023/2024",
        "force_update" => "true",
        "no_local_protection" => "false",
        "club_id" => 357
      },
      "development" => {
        "carambus_api_url" => "https://api.carambus.de/",  # Set for local mode to fetch data from API
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "context" => "LOCAL",
        "season_name" => "2024/2025",
        "force_update" => "true",
        "no_local_protection" => "true",
        "club_id" => 357
      },
      "test" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0
      },
      "production" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0
      }
    }

    File.write(Rails.root.join('config', 'carambus.yml'), carambus_config.to_yaml)
    puts "✓ Updated carambus.yml"

    # Update database.yml
    database_config = {
      "default" => {
        "adapter" => "postgresql",
        "encoding" => "unicode",
        "pool" => "<%= ENV.fetch(\"RAILS_MAX_THREADS\") { 5 } %>"
      },
      "development" => {
        "database" => "carambus_development",
        "username" => "<%= ENV.fetch(\"DB_USERNAME\", nil) %>",
        "password" => "<%= ENV.fetch(\"DB_PASSWORD\", nil) %>",
        "host" => "<%= ENV.fetch(\"DB_HOST\", \"localhost\") %>"
      },
      "test" => {
        "database" => "carambus_test",
        "username" => "<%= ENV.fetch(\"DB_USERNAME\", nil) %>",
        "password" => "<%= ENV.fetch(\"DB_PASSWORD\", nil) %>",
        "host" => "<%= ENV.fetch(\"DB_HOST\", \"localhost\") %>"
      },
      "production" => {
        "database" => "carambus2_api_production"
      }
    }
    
    # Generate YAML with proper anchor syntax
    yaml_content = <<~YAML
      ---
      default: &default
        adapter: postgresql
        encoding: unicode
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      
      development:
        <<: *default
        database: carambus_development
        username: <%= ENV.fetch("DB_USERNAME", nil) %>
        password: <%= ENV.fetch("DB_PASSWORD", nil) %>
        host: <%= ENV.fetch("DB_HOST", "localhost") %>
      
      test:
        <<: *default
        database: carambus_test
        username: <%= ENV.fetch("DB_USERNAME", nil) %>
        password: <%= ENV.fetch("DB_PASSWORD", nil) %>
        host: <%= ENV.fetch("DB_HOST", "localhost") %>
      
      production:
        <<: *default
        database: carambus2_api_production
      YAML
    
        File.write(Rails.root.join('config', 'database.yml'), yaml_content)
    puts "✓ Updated database.yml"

    # Update deploy.rb for LOCAL mode
    update_deploy_rb("carambus")

    # Manage log files for LOCAL mode
    manage_log_files("local")

    puts "Switched to LOCAL mode successfully"
    puts "Current mode: LOCAL (carambus_api_url is set, local database)"
  end

  desc "Switch to API mode (set carambus_api_url, API database)"
  task api: :environment do
    puts "Switching to API mode..."

    # Update carambus.yml
    carambus_config = {
      "default" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0,
        "context" => "NBV",
        "season_name" => "2023/2024",
        "force_update" => "true",
        "no_local_protection" => "false",
        "club_id" => 357
      },
      "development" => {
        "carambus_api_url" => nil,  # Empty for API mode (no external API calls)
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "context" => "API",
        "season_name" => "2024/2025",
        "force_update" => "true",
        "no_local_protection" => "false",
        "club_id" => 357
      },
      "test" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0
      },
      "production" => {
        "carambus_api_url" => "https://api.carambus.de/",
        "location_id" => 1,
        "application_name" => "Carambus",
        "support_email" => "gernot.ullrich@gmx.de",
        "business_name" => "Ullrich IT Consulting",
        "business_address" => "22869 Schenefeld, Sandstückenweg 15",
        "carambus_domain" => "carambus.de",
        "queue_adapter" => "async",
        "small_table_no" => 0,
        "large_table_no" => 0,
        "pool_table_no" => 0,
        "snooker_table_no" => 0
      }
    }

        File.write(Rails.root.join('config', 'carambus.yml'), carambus_config.to_yaml)
    puts "✓ Updated carambus.yml"
    
    # Generate YAML with proper anchor syntax for API mode
    yaml_content = <<~YAML
      ---
      default: &default
        adapter: postgresql
        encoding: unicode
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
      
      development:
        <<: *default
        database: carambus_api_development
        username: <%= ENV.fetch("DB_USERNAME", nil) %>
        password: <%= ENV.fetch("DB_PASSWORD", nil) %>
        host: <%= ENV.fetch("DB_HOST", "localhost") %>
      
      test:
        <<: *default
        database: carambus_test
        username: <%= ENV.fetch("DB_USERNAME", nil) %>
        password: <%= ENV.fetch("DB_PASSWORD", nil) %>
        host: <%= ENV.fetch("DB_HOST", "localhost") %>
      
      production:
        <<: *default
        database: carambus2_api_production
      YAML
    
    File.write(Rails.root.join('config', 'database.yml'), yaml_content)
    puts "✓ Updated database.yml"

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

    if File.exist?(deploy_file)
      content = File.read(deploy_file)
      updated_content = content.gsub(
        /set :basename, File\.basename\(`pwd`\)\.strip/,
        "set :basename, \"#{basename}\""
      )

      File.write(deploy_file, updated_content)
      puts "✓ Updated deploy.rb basename to: #{basename}"
    else
      puts "⚠️  deploy.rb not found, skipping basename update"
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
