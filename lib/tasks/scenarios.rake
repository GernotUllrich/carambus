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

    if scenario_name.nil?
      puts "Usage: rake scenario:prepare_development[scenario_name,environment]"
      puts "Example: rake scenario:prepare_development[carambus_location_2459,development]"
      exit 1
    end

    prepare_scenario_for_development(scenario_name, environment)
  end

  desc "Prepare scenario for deployment (all steps except server deployment)"
  task :prepare_deploy, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:prepare_deploy[scenario_name]"
      puts "Example: rake scenario:prepare_deploy[carambus_location_2459]"
      exit 1
    end

    prepare_scenario_for_deployment(scenario_name)
  end

  desc "Deploy scenario to production (server deployment only)"
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

    # Generate nginx.conf in environment directory
    generate_nginx_conf(scenario_config, env_config, env_dir)

    # Generate puma.service in environment directory
    generate_puma_service(scenario_config, env_config, env_dir)

    # Generate puma.rb in environment directory
    generate_puma_rb(scenario_config, env_config, env_dir)

    # Generate deploy files in environment directory (only for development)
    generate_deploy_files(scenario_config, env_config, env_dir)

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

    # Standard dump creation - transformations are handled in create_development_database
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
      idea_target = File.join(rails_root, '.idea')
      if Dir.exist?(idea_source)
        FileUtils.cp_r(idea_source, idea_target)
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

  def prepare_scenario_for_development(scenario_name, environment)
    puts "Preparing scenario #{scenario_name} for development (#{environment})..."
    puts "This includes Rails root creation, config generation, basic config copying, and database operations."

    # Step 1: Create Rails root folder (if it doesn't exist)
    puts "\n📁 Step 1: Ensuring Rails root folder exists..."
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "   Rails root folder not found, creating it..."
      unless create_rails_root_folder(scenario_name)
        puts "❌ Failed to create Rails root folder"
        return false
      end
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
    end

    # Step 4: Create database dump (fresh from development)
    puts "\n💾 Step 4: Creating database dump..."
    unless create_database_dump(scenario_name, environment)
      puts "❌ Failed to create database dump"
      return false
    end

    # Step 5: Create actual development database from template
    puts "\n🗄️  Step 5: Creating development database..."
    unless create_development_database(scenario_name, environment)
      puts "❌ Failed to create development database"
      return false
    end

    puts "\n✅ Scenario #{scenario_name} prepared for development!"
    puts "   Rails root: #{rails_root}"
    puts "   Environment: #{environment}"
    puts "   Database: #{scenario_name}_#{environment}"
    puts "   Database dump: #{File.join(scenarios_path, scenario_name, 'database_dumps')}"
    
    true
  end

  def create_development_database(scenario_name, environment)
    puts "Creating development database for #{scenario_name} (#{environment})..."
    
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
    
    # Drop existing database if it exists
    if system("psql -lqt | cut -d \\| -f 1 | grep -qw #{database_name}")
      puts "   Dropping existing database #{database_name}..."
      system("dropdb #{database_name}")
    end
    
    if region_id && environment == 'development'
      puts "🔄 Creating #{database_name} from carambus_api_development template (region_id: #{region_id})..."
      
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
          if system("bundle exec rails dev:cache")
            puts "   ✅ Development caching enabled"
          else
            puts "   ⚠️  Warning: Failed to enable development caching"
          end
          
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
        
        # Apply region filtering using the cleanup task
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
      puts "   Rails root folder not found, creating it..."
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

  def prepare_scenario_for_deployment(scenario_name)
    puts "Preparing scenario #{scenario_name} for deployment..."
    puts "This includes production config generation, production config copying, and database operations."
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

    # Step 5: Ensure development database has all migrations applied
    puts "\n🔄 Step 5: Ensuring development database has all migrations applied..."
    
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

    # Step 6: Create production database dump from scenario development database
    puts "\n💾 Step 6: Creating production database dump from #{scenario_name}_development..."
    
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
    puts ""
    puts "Next steps:"
    puts "  1. Review the generated configuration files"
    puts "  2. Run 'rake scenario:deploy[#{scenario_name}]' to deploy to production server"
    puts "  3. Or manually deploy using Capistrano: cd #{rails_root} && cap production deploy"
    
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
    # Use --no-owner --no-privileges to avoid permission issues, include schema and data by default
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
        
        # Create dump from filtered database
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
    
    # Create dump from carambus_api_development
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
    puts "This performs server deployment operations only (assumes prepare_deploy was run first)."
    puts "DEBUG: Starting deploy_scenario function"

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
          # Remove existing application folders (including old trials)
          sudo rm -rf /var/www/#{basename}
          sudo rm -rf /var/www/carambus_#{basename}
          # Drop and recreate database
          sudo -u postgres psql -c "DROP DATABASE IF EXISTS #{production_database};"
          sudo -u postgres psql -c "CREATE DATABASE #{production_database} OWNER www_data;"
        SCRIPT

        # Write script to server
        script_cmd = "cat > #{temp_script} << 'SCRIPT_EOF'\n#{script_content}SCRIPT_EOF"
        if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{script_cmd}'")
          puts "   ✅ Database reset script created"
          
          # Execute database reset
          if system("ssh -p #{ssh_port} www-data@#{ssh_host} 'chmod +x #{temp_script} && #{temp_script}'")
            puts "   ✅ Application folders removed (including old trials) and production database recreated"
            
            # Restore database from dump
            puts "   📥 Restoring database from dump..."
            # Replace user references in the dump to avoid permission errors
            restore_cmd = "gunzip -c #{temp_dump_path} | sed 's/OWNER TO gullrich/OWNER TO www_data/g' | sudo -u postgres psql #{production_database}"
            
            if system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{restore_cmd}'")
              puts "   ✅ Database restored successfully"
              
              # Clean up temporary files
              system("ssh -p #{ssh_port} www-data@#{ssh_host} 'rm -f #{temp_dump_path} #{temp_script}'")
              puts "   🧹 Temporary files cleaned up"
            else
              puts "   ❌ Database restore failed"
              return false
            end
          else
            puts "   ❌ Database reset failed"
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

    # Step 2: Upload configuration files to shared directory
    puts "\n📤 Step 2: Uploading configuration files to shared directory..."
    
    # Create entire deployment directory structure with proper permissions
    deploy_dir = "/var/www/#{basename}"
    shared_config_dir = "#{deploy_dir}/shared/config"
    create_deploy_dirs_cmd = "sudo mkdir -p #{deploy_dir}/shared/config #{deploy_dir}/releases && sudo chown -R www-data:www-data #{deploy_dir}"
    unless system("ssh -p #{ssh_port} www-data@#{ssh_host} '#{create_deploy_dirs_cmd}'")
      puts "   ❌ Failed to create deployment directory structure"
      return false
    end
    
    # Upload config files to shared directory (after Capistrano creates the structure)
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

    puts "\n✅ Deployment completed successfully!"
    puts "   Application deployed and running on #{production_config['webserver_host']}:#{production_config['webserver_port']}"
    puts "   Puma service: puma-#{scenario['basename']}.service"
    puts "   Nginx site: #{scenario['basename']}"

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
      scp_cmd = "scp -P #{ssh_port} #{puma_rb_path} www-data@#{ssh_host}:/var/www/#{basename}/shared/"
      puts "   🔍 Running: #{scp_cmd}"
      result = `#{scp_cmd} 2>&1`
      if $?.success?
        puts "   ✅ Uploaded puma.rb"
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
    enable_cmd = "sudo mkdir -p /var/www/#{basename}/shared/log /var/www/carambus/shared/log && sudo chown -R www-data:www-data /var/www/#{basename}/shared/log /var/www/carambus/shared/log && sudo ln -sf /etc/nginx/sites-available/#{basename} /etc/nginx/sites-enabled/#{basename} && sudo nginx -t && sudo systemctl reload nginx"
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

    unless pi_config && pi_config['enabled']
      puts "❌ Error: Raspberry Pi client not enabled for this scenario"
      return false
    end

    pi_ip = pi_config['ip_address']
    ssh_user = pi_config['ssh_user']
    ssh_password = pi_config['ssh_password']
    ssh_port = pi_config['ssh_port'] || 22
    kiosk_user = pi_config['kiosk_user']

    # Generate scoreboard URL
    location_id = scenario_config['scenario']['location_id']
    webserver_host = production_config['webserver_host']
    webserver_port = production_config['webserver_port']
    
    # Calculate MD5 hash for location
    require 'digest'
    location_md5 = Digest::MD5.hexdigest(location_id.to_s)
    scoreboard_url = "http://#{webserver_host}:#{webserver_port}/locations/#{location_md5}?sb_state=welcome"

    puts "   Scoreboard URL: #{scoreboard_url}"

    # Upload scoreboard URL to Raspberry Pi
    puts "\n📤 Uploading scoreboard URL..."
    upload_url_cmd = "echo '#{scoreboard_url}' | sudo tee /etc/scoreboard_url"
    if execute_ssh_command(pi_ip, ssh_user, ssh_password, upload_url_cmd, ssh_port)
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

      # Get scoreboard URL
      SCOREBOARD_URL=$(cat /etc/scoreboard_url)

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
    EOF
  end

end
