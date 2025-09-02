# frozen_string_literal: true

namespace :mode do
  namespace :named do
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
      port = (params[:port] || '').presence
      branch = params[:branch] || 'master'
      puma_script = params[:puma_script] || 'manage-puma.sh'
      
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
      port = params[:port] || '3001'
      branch = params[:branch] || 'master'
      puma_script = params[:puma_script] || 'manage-puma-api.sh'
      
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
        puts "Usage: bundle exec rails 'mode:named:save[my_config]'"
        exit 1
      end

      params = parse_named_parameters_from_env
      if params.empty?
        puts "❌ No parameters provided"
        puts "Usage: bundle exec rails 'mode:named:save[my_config]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
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
        puts "Usage: bundle exec rails 'mode:named:load[my_config]'"
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
      
      puts "📋 Environment variables set. Run mode:named:local or mode:named:api to apply."
    end

    desc "List all saved configurations"
    task :list => :environment do
      list_named_configurations
    end

    desc "Show help for named parameters"
    task :help => :environment do
      show_named_parameters_help
    end

    private

    def parse_named_parameters_from_env
      params = {}
      
      # Parse from environment variables
      %i[season_name application_name context api_url basename database domain location_id club_id rails_env host port branch puma_script].each do |param|
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
      puts "  bundle exec rails 'mode:named:local' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
      puts "  bundle exec rails 'mode:named:api' MODE_BASENAME=carambus_api MODE_HOST=newapi.carambus.de"
      puts "  bundle exec rails 'mode:named:save[my_config]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production"
      puts "  bundle exec rails 'mode:named:load[my_config]'"
      puts "  bundle exec rails 'mode:named:list'"
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
      puts "  MODE_HOST            - Server hostname"
      puts "  MODE_PORT            - Server port"
      puts "  MODE_BRANCH          - Git branch"
      puts "  MODE_PUMA_SCRIPT     - Puma management script"
      puts ""
      puts "Examples:"
      puts "  bundle exec rails 'mode:named:api' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001"
      puts "  bundle exec rails 'mode:named:local' MODE_SEASON_NAME='2025/2026' MODE_CONTEXT=NBV MODE_API_URL='https://newapi.carambus.de/'"
      puts "  bundle exec rails 'mode:named:save[api_hetzner]' MODE_BASENAME=carambus_api MODE_DATABASE=carambus_api_production MODE_HOST=newapi.carambus.de MODE_PORT=3001"
      puts "  bundle exec rails 'mode:named:load[api_hetzner]'"
    end

    # Include all the necessary methods from mode.rake
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
  end
end
