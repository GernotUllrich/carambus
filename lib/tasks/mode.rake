# frozen_string_literal: true

namespace :mode do

  desc "Switch to LOCAL mode (empty carambus_api_url, local database)"
  # 2025/2026, carambus, NBV, https://newapi.carambus.de/, carambus, carambus_production, carambus.de, 1, 357, production, new.carambus.de, , master, manage-puma.sh
  task  :local, [:season_name, :application_name, :context, :api_url, :basename, :database, :domain, :location_id, :club_id, :rails_env, :host, :port, :branch, :puma_script] => :environment do |task, args|
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
    port = (args.port || '').presence
    branch = args.branch || 'master'
    puma_script = args.puma_script || 'manage-puma.sh'
    puts "Switching to LOCAL mode..."

    # Update carambus.yml
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)

    # Update database.yml
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Update Puma configuration for LOCAL mode
    update_puma_configuration(puma_script, basename)

    # Manage log files for LOCAL mode
    manage_log_files("local")

    puts "Switched to LOCAL mode successfully"
    puts "Current mode: LOCAL (carambus_api_url is set, local database)"
  end

  desc "Switch to API mode (empty carambus_api_url, local database)"
  task  :api, [:season_name, :application_name, :context, :api_url, :basename, :database, :domain, :location_id, :club_id, :host, :port, :branch, :puma_script] => :environment do |task, args|
    season_name = args.season_name || "2025/2026"
    application_name = args.application_name || 'carambus'
    context = args.context || ''
    api_url = args.api_url || ''
    basename = args.basename || 'carambus_api'
    database = args.database || 'carambus_api_production'
    domain = args.domain || 'api.carambus.de'
    location_id = args.location_id || ''
    club_id = args.club_id || ''
    rails_env = args.rails_env || 'production'
    host = args.host || 'newapi.carambus.de'
    port = args.port || '3001'
    branch = args.branch || 'master'
    puma_script = args.puma_script || 'manage-puma-api.sh'
    puts "Switching to API mode..."

    # Update carambus.yml
    update_carambus_yml(season_name, api_url, basename, domain, location_id, application_name, context, club_id)

    # Update database.yml
    update_database_yml(database)

    # Update deploy.rb for LOCAL mode
    update_deploy_rb(basename)

    # Update deploy.rb for LOCAL mode
    update_deploy_environment_rb(rails_env, host, port, branch)

    # Update Puma configuration for API mode
    update_puma_configuration(puma_script, basename)

    # Manage log files for LOCAL mode
    manage_log_files("api")

    puts "Switched to API mode successfully"
    puts "Current mode: API (carambus_api_url is nil, local database)"
  end

  desc "Show current mode and configuration"
  task :status, [:detailed, :source] => :environment do |task, args|
    source = args.source&.to_sym || :production
    
    puts "Current Configuration (#{source}):"

    # Extract current configuration based on source
    api_url = extract_api_url(source)
    context = extract_context(source)
    database = extract_database(source)
    basename = extract_basename(source)
    puma_script = extract_puma_script

    puts "  API URL: #{api_url || 'empty'}"
    puts "  Context: #{context}"
    puts "  Database: #{database}"
    puts "  Deploy Basename: #{basename}"
    
    # Check log file status (always local)
    development_log = Rails.root.join('log', 'development.log')
    if File.symlink?(development_log)
      log_target = File.readlink(development_log)
      log_file = File.basename(log_target)
      puts "  Log File: #{log_file}"
    else
      puts "  Log File: direct file (not linked)"
    end

    puts "  Puma Script: #{puma_script}"

    # Determine mode
    if api_url.nil? || api_url.empty?
      puts "Current Mode: API"
    else
      puts "Current Mode: LOCAL"
    end

    # Show source information
    if args.detailed
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
    if args.detailed
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
        production_config.dig('production', 'database') || production_config.dig('development', 'database')
      end
    when :local
      local_config = read_local_deployment_config('database.yml')
      if local_config
        local_config.dig('production', 'database') || local_config.dig('development', 'database')
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
    if File.exist?(Rails.root.join('config', 'deploy', 'production.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy', 'production.rb'))
      if deploy_content.match(/set :rails_env, ['"]([^'"]+)['"]/)
        $1
      end
    end
  end

  def extract_host
    if File.exist?(Rails.root.join('config', 'deploy', 'production.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy', 'production.rb'))
      if deploy_content.match(/server ['"]([^'"]+)['"]/)
        $1
      end
    end
  end

  def extract_port
    if File.exist?(Rails.root.join('config', 'deploy', 'production.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy', 'production.rb'))
      if deploy_content.match(/ssh_options: \{port: (\d+)\}/)
        $1
      elsif deploy_content.match(/ssh_options: \{port: ['"]([^'"]+)['"]\}/)
        $1
      end
    end
  end

  def extract_branch
    if File.exist?(Rails.root.join('config', 'deploy', 'production.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy', 'production.rb'))
      if deploy_content.match(/set :branch, ['"]([^'"]+)['"]/)
        $1
      end
    end
  end

  def extract_puma_script
    if File.exist?(Rails.root.join('config', 'deploy.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy.rb'))
      if deploy_content.match(/execute "\.\/bin\/([^"]+)"/)
        $1
      elsif deploy_content.match(/execute ".*\/bin\/([^"]+)"/)
        $1
      end
    end
  end

  def read_production_config(config_file)
    # Get deployment configuration to determine server details
    deploy_config = get_deploy_config
    return nil unless deploy_config

    host = deploy_config[:host]
    port = deploy_config[:port]
    basename = deploy_config[:basename]

    # Construct the path to the config file on the production server
    config_path = "/var/www/#{basename}/shared/config/#{config_file}"

    begin
      # Read the config file from the production server
      config_content = read_remote_file(host, port, config_path)
      return YAML.load(config_content) if config_content
    rescue => e
      puts "⚠️  Could not read #{config_file} from production server: #{e.message}"
    end

    nil
  end

  def read_local_deployment_config(config_file)
    # Read from local config files that will be deployed
    if File.exist?(Rails.root.join('config', config_file))
      YAML.load_file(Rails.root.join('config', config_file))
    end
  end

  def get_deploy_config
    # Read deploy.rb to get basename
    if File.exist?(Rails.root.join('config', 'deploy.rb'))
      deploy_content = File.read(Rails.root.join('config', 'deploy.rb'))
      if deploy_content.match(/set :basename, ['"]([^'"]+)['"]/)
        basename = $1
      else
        return nil
      end
    else
      return nil
    end

    # Read production.rb to get host and port
    if File.exist?(Rails.root.join('config', 'deploy', 'production.rb'))
      production_content = File.read(Rails.root.join('config', 'deploy', 'production.rb'))
      
      host = nil
      if production_content.match(/server ['"]([^'"]+)['"]/)
        host = $1
      end

      port = nil
      if production_content.match(/ssh_options: \{port: (\d+)\}/)
        port = $1.to_i
      elsif production_content.match(/ssh_options: \{port: ['"]([^'"]+)['"]\}/)
        port = $1.to_i
      end

      return { host: host, port: port, basename: basename }
    end

    nil
  end

  def read_remote_file(host, port, file_path)
    # Use SSH to read the file from the production server
    ssh_port = port || 22
    ssh_command = "ssh -p #{ssh_port} -o ConnectTimeout=5 -o BatchMode=yes www-data@#{host} 'cat #{file_path}' 2>/dev/null"
    
    result = `#{ssh_command}`
    return result if $?.success?
    
    nil
  end
end
