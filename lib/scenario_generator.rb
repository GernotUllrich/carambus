# frozen_string_literal: true

require 'erb'
require 'yaml'
require 'fileutils'

class ScenarioGenerator
  def initialize
    @carambus_data_path = File.expand_path('../carambus_data', Rails.root)
  end

  def list_environments(scenario_name)
    config_path = File.join(@carambus_data_path, 'scenarios', scenario_name, 'config.yml')
    return [] unless File.exist?(config_path)
    
    config = YAML.load_file(config_path)
    config['environments']&.keys || []
  end

  def list_scenarios
    scenarios_path = File.join(@carambus_data_path, 'scenarios')
    return [] unless Dir.exist?(scenarios_path)
    
    Dir.entries(scenarios_path).select do |entry|
      next if entry.start_with?('.')
      config_path = File.join(scenarios_path, entry, 'config.yml')
      File.exist?(config_path)
    end
  end

  def generate_scenario(scenario_name, environment)
    puts "Generating scenario #{scenario_name} for #{environment}..."
    
    # Load scenario configuration
    config_path = File.join(@carambus_data_path, 'scenarios', scenario_name, 'config.yml')
    unless File.exist?(config_path)
      puts "❌ Scenario config not found: #{config_path}"
      return false
    end
    
    config = YAML.load_file(config_path)
    scenario_config = config['scenario']
    env_config = config['environments'][environment]
    
    puts "Debug: scenario_config = #{scenario_config.inspect}"
    puts "Debug: env_config = #{env_config.inspect}"
    
    if env_config.nil?
      puts "❌ Environment config not found for: #{environment}"
      puts "Available environments: #{config['environments'].keys.join(', ')}"
      return false
    end
    
    # Generate Rails root folder (use shorter path to avoid Unix socket path length issues)
    rails_root = File.expand_path("../../scenarios/#{scenario_name}", @carambus_data_path)
    FileUtils.rm_rf(rails_root) if Dir.exist?(rails_root)
    FileUtils.mkdir_p(rails_root)
    
    # Copy Rails application (skip Unix sockets and git)
    source_path = Rails.root
    Dir.glob(File.join(source_path, '*')).each do |item|
      next if File.basename(item) == '.git'
      next if File.basename(item) == 'ansible'  # Skip ansible directory
      next if File.basename(item) == 'shared'   # Skip shared directory with sockets
      if File.directory?(item)
        FileUtils.cp_r(item, rails_root, preserve: true)
        # Remove .git directories from copied folders
        Dir.glob(File.join(rails_root, File.basename(item), '**/.git')).each do |git_dir|
          FileUtils.rm_rf(git_dir)
        end
      else
        FileUtils.cp(item, rails_root, preserve: true)
      end
    end
    
    # Remove unnecessary files from copy
    remove_unnecessary_files(rails_root)
    
    # Generate configuration files
    templates = config['templates'] || {
      'database_yml' => 'templates/database/database.yml.erb',
      'carambus_yml' => 'templates/carambus/carambus.yml.erb',
      'production_rb' => 'templates/environments/production.rb.erb',
      'nginx_conf' => 'templates/nginx/nginx.conf.erb'
    }
    generate_config_files(rails_root, scenario_config, env_config, templates)
    
    puts "✅ Generated scenario in: #{rails_root}"
    true
  end

  private

  def remove_unnecessary_files(rails_root)
    # Remove git history
    FileUtils.rm_rf(File.join(rails_root, '.git'))
    
    # Remove temporary files
    ['tmp', 'log', 'storage'].each do |dir|
      FileUtils.rm_rf(File.join(rails_root, dir))
      FileUtils.mkdir_p(File.join(rails_root, dir))
    end
    
    # Remove node_modules
    FileUtils.rm_rf(File.join(rails_root, 'node_modules'))
  end

  def generate_config_files(rails_root, scenario_config, env_config, templates)
    # Generate database.yml
    generate_database_yml(rails_root, scenario_config, env_config, templates['database_yml'])
    
    # Generate carambus.yml
    generate_carambus_yml(rails_root, scenario_config, env_config, templates['carambus_yml'])
    
    # Generate production.rb
    if env_config['mode'] == 'production'
      generate_production_rb(rails_root, scenario_config, env_config, templates['production_rb'])
    end
    
    # Generate nginx.conf
    generate_nginx_conf(rails_root, scenario_config, env_config, templates['nginx_conf'])
  end

  def generate_database_yml(rails_root, scenario_config, env_config, template_path)
    puts "Debug: Using database template: #{template_path}"
    puts "Debug: env_config keys: #{env_config.keys.join(', ')}"
    
    # Use default template instead of custom one
    template = default_database_template
    
    # Create binding with all necessary variables
    binding_vars = {
      env_config: env_config,
      scenario_config: scenario_config
    }
    
    erb = ERB.new(template)
    result = erb.result_with_hash(binding_vars)
    
    output_path = File.join(rails_root, 'config', 'database.yml')
    File.write(output_path, result)
    puts "   Generated: #{output_path}"
  end

  def generate_carambus_yml(rails_root, scenario_config, env_config, template_path)
    # Use default template instead of custom one
    template = default_carambus_template
    
    # Create binding with all necessary variables
    binding_vars = {
      env_config: env_config,
      scenario_config: scenario_config
    }
    
    erb = ERB.new(template)
    result = erb.result_with_hash(binding_vars)
    
    output_path = File.join(rails_root, 'config', 'carambus.yml')
    File.write(output_path, result)
    puts "   Generated: #{output_path}"
  end

  def generate_production_rb(rails_root, scenario_config, env_config, template_path)
    template = load_template(template_path)
    erb = ERB.new(template)
    result = erb.result(binding)
    
    output_path = File.join(rails_root, 'config', 'environments', 'production.rb')
    File.write(output_path, result)
    puts "   Generated: #{output_path}"
  end

  def generate_nginx_conf(rails_root, scenario_config, env_config, template_path)
    template = load_template(template_path)
    erb = ERB.new(template)
    result = erb.result(binding)
    
    output_path = File.join(rails_root, 'config', 'nginx.conf')
    File.write(output_path, result)
    puts "   Generated: #{output_path}"
  end

  def load_template(template_path)
    full_path = File.join(@carambus_data_path, template_path)
    if File.exist?(full_path)
      File.read(full_path)
    else
      puts "⚠️  Template not found: #{full_path}"
      # Return default template content
      case template_path
      when /database\.yml/
        default_database_template
      when /carambus\.yml/
        default_carambus_template
      when /production\.rb/
        default_production_template
      when /nginx\.conf/
        default_nginx_template
      else
        ""
      end
    end
  end

  def default_database_template
    <<~ERB
      default: &default
        adapter: postgresql
        encoding: unicode
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
        username: <%= env_config['database_username'] %>
        password: <%= env_config['database_password'] %>
        host: <%= ENV.fetch("DATABASE_HOST") { "localhost" } %>

      development:
        <<: *default
        database: <%= scenario_config['name'] %>_development

      test:
        <<: *default
        database: <%= scenario_config['name'] %>_test

      production:
        <<: *default
        database: <%= scenario_config['name'] %>_production
    ERB
  end

  def default_carambus_template
    <<~ERB
      default: &default
        application_name: <%= scenario_config['application_name'] %>
        location_id: <%= scenario_config['location_id'] %>
        context: <%= scenario_config['context'] %>
        region_id: <%= scenario_config['region_id'] %>
        club_id: <%= scenario_config['club_id'] %>
        api_url: <%= scenario_config['api_url'] %>
        season_name: <%= scenario_config['season_name'] %>

      development:
        <<: *default
        mode: development
        ssl_enabled: false
        server_port: 3000

      production:
        <<: *default
        mode: production
        ssl_enabled: <%= env_config['ssl_enabled'] %>
        server_port: <%= env_config['webserver_port'] %>
        ssh_host: <%= env_config['ssh_host'] %>
        ssh_port: <%= env_config['ssh_port'] %>
    ERB
  end

  def default_production_template
    <<~ERB
      Rails.application.configure do
        config.cache_classes = true
        config.eager_load = true
        config.consider_all_requests_local = false
        config.action_controller.perform_caching = true
        config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
        config.assets.compile = false
        config.active_storage.service = :local
        config.log_level = :info
        config.log_tags = [ :request_id ]
        config.i18n.fallbacks = true
        config.active_support.deprecation = :notify
        config.log_formatter = ::Logger::Formatter.new
        config.active_record.dump_schema_after_migration = false
      end
    ERB
  end

  def default_nginx_template
    <<~ERB
      server {
        listen <%= env_config['webserver_port'] %>;
        server_name <%= env_config['webserver_host'] %>;
        root /var/www/<%= scenario_config['name'] %>/current/public;
        
        location / {
          try_files $uri @rails;
        }
        
        location @rails {
          proxy_pass http://unix:/tmp/puma.sock;
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        }
      }
    ERB
  end
end
