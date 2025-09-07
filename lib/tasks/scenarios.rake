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

  desc "Setup scenario with Rails root folder"
  task :setup_with_rails_root, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'

    if scenario_name.nil?
      puts "Usage: rake scenario:setup_with_rails_root[scenario_name,environment]"
      puts "Example: rake scenario:setup_with_rails_root[carambus_location_2459,development]"
      exit 1
    end

    setup_scenario_with_rails_root(scenario_name, environment)
  end

  desc "Complete scenario setup"
  task :setup, [:scenario_name, :environment] => :environment do |task, args|
    scenario_name = args[:scenario_name]
    environment = args[:environment] || 'development'
    
    if scenario_name.nil?
      puts "Usage: rake scenario:setup[scenario_name,environment]"
      puts "Example: rake scenario:setup[carambus_location_2459,development]"
      exit 1
    end
    
    setup_scenario(scenario_name, environment)
  end

  desc "Deploy scenario to production with conflict analysis"
  task :deploy, [:scenario_name] => :environment do |task, args|
    scenario_name = args[:scenario_name]

    if scenario_name.nil?
      puts "Usage: rake scenario:deploy[scenario_name]"
      puts "Example: rake scenario:deploy[carambus_location_2459]"
      exit 1
    end

    deploy_scenario_with_conflict_analysis(scenario_name)
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
      
      # Reset sequences for local server
      puts "Resetting sequences..."
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

    # Special handling for carambus scenario - generate from carambus_api_development
    if scenario_name == 'carambus' && environment == 'development'
      puts "🔄 Special transformation: Generating carambus_development from carambus_api_development..."
      
      # Create temporary database for transformation
      temp_db_name = "carambus_temp_#{timestamp}"
      
      # Create temporary database using template (much faster)
      if system("createdb #{temp_db_name} --template=carambus_api_development")
        puts "   ✅ Created temporary database: #{temp_db_name} (using template)"
        
        # Apply transformations
        transform_commands = [
            # Reset version ID sequence to start from 1
            "SELECT setval('versions_id_seq', 1, false);",
            # Reset last version ID in settings JSON data (cast to jsonb for operations)  
            "UPDATE settings SET data = jsonb_set(data::jsonb, '{last_version_id}', '{\"Integer\":\"1\"}')::text WHERE data::jsonb ? 'last_version_id';",
            # Set scenario name in settings
            "UPDATE settings SET data = jsonb_set(data::jsonb, '{scenario_name}', '{\"String\":\"carambus\"}')::text WHERE data::jsonb ? 'scenario_name';",
            # If scenario_name doesn't exist, add it
            "UPDATE settings SET data = (data::jsonb || '{\"scenario_name\":{\"String\":\"carambus\"}}')::text WHERE NOT (data::jsonb ? 'scenario_name');"
          ]
          
        transform_commands.each do |cmd|
          if system("psql #{temp_db_name} -c \"#{cmd}\"")
            puts "   ✅ Applied transformation: #{cmd}"
          else
            puts "   ⚠️  Warning: Transformation failed: #{cmd}"
          end
        end
        
        # Create dump from transformed database
        if system("pg_dump #{temp_db_name} | gzip > #{dump_file}")
          puts "✅ Transformed database dump created: #{File.basename(dump_file)}"
          puts "   Size: #{File.size(dump_file) / 1024 / 1024} MB"
          
          # Clean up temporary database
          system("dropdb #{temp_db_name}")
          puts "   🧹 Cleaned up temporary database"
          true
        else
          puts "❌ Failed to create dump from transformed database"
          system("dropdb #{temp_db_name}")
          false
        end
      else
        puts "❌ Failed to create temporary database"
        false
      end
    elsif scenario_name == 'carambus_location_5101' && environment == 'development'
      puts "🔄 Special transformation: Generating carambus_location_5101_development with region filtering..."
      
      # Create temporary database for transformation
      temp_db_name = "carambus_location_5101_temp_#{timestamp}"
      
      # Create temporary database
      if system("createdb #{temp_db_name}")
        puts "   ✅ Created temporary database: #{temp_db_name}"
        
        # Restore carambus_api_development to temporary database
        if system("pg_dump carambus_api_development | psql #{temp_db_name}")
          puts "   ✅ Restored carambus_api_development to temporary database"
          
          # Apply region filtering using the cleanup task
          puts "   🔄 Applying region filtering (region_id: 1)..."
          
          # Set environment variable for region filtering
          ENV['REGION_SHORTNAME'] = 'NBV'
          
          # Create a temporary Rails environment to run the cleanup task
          temp_rails_root = File.join(scenarios_path, scenario_name)
          
          # Change to the Rails root directory and run the cleanup task
          if Dir.chdir(temp_rails_root) do
            # Set up Rails environment variables
            ENV['RAILS_ENV'] = 'development'
            ENV['DATABASE_URL'] = "postgresql://localhost/#{temp_db_name}"
            
            # Run the cleanup task
            system("bundle exec rails cleanup:remove_non_region_records")
          end
            puts "   ✅ Applied region filtering"
            
            # Create dump from filtered database
            if system("pg_dump #{temp_db_name} | gzip > #{dump_file}")
              puts "✅ Region-filtered database dump created: #{File.basename(dump_file)}"
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
          puts "❌ Failed to restore carambus_api_development to temporary database"
          system("dropdb #{temp_db_name}")
          false
        end
      else
        puts "❌ Failed to create temporary database"
        false
      end
    else
      # Standard dump creation
      puts "Creating dump of #{database_name}..."
      if system("pg_dump #{database_name} | gzip > #{dump_file}")
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

  def setup_scenario_with_rails_root(scenario_name, environment)
    puts "Setting up scenario #{scenario_name} with Rails root folder..."

    # Step 1: Create Rails root folder
    unless create_rails_root_folder(scenario_name)
      puts "❌ Failed to create Rails root folder"
      return false
    end

    # Step 2: Restore database dump
    unless restore_database_dump(scenario_name, environment)
      puts "❌ Failed to restore database dump"
      return false
    end

    # Step 3: Copy generated configuration files
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    env_dir = File.join(scenarios_path, scenario_name, environment)

    if Dir.exist?(env_dir)
      # Copy database.yml
      if File.exist?(File.join(env_dir, 'database.yml'))
        FileUtils.cp(File.join(env_dir, 'database.yml'), File.join(rails_root, 'config', 'database.yml'))
        puts "   Copied database.yml to Rails root"
      end

      # Copy carambus.yml
      if File.exist?(File.join(env_dir, 'carambus.yml'))
        FileUtils.cp(File.join(env_dir, 'carambus.yml'), File.join(rails_root, 'config', 'carambus.yml'))
        puts "   Copied carambus.yml to Rails root"
      end
    end

    # Step 4: Reset sequences for local server
    puts "Resetting sequences..."
    system("cd #{rails_root} && bundle exec rails runner 'Version.sequence_reset'")

    puts "✅ Scenario #{scenario_name} setup completed"
    puts "   Rails root: #{rails_root}"
    puts "   Environment: #{environment}"
    true
  end

  def setup_scenario(scenario_name, environment)
    puts "Setting up scenario #{scenario_name} (#{environment})..."

    # Step 1: Generate configuration files
    unless generate_configuration_files(scenario_name, environment)
      puts "❌ Failed to generate configuration files"
      return false
    end

    # Step 2: Restore database dump
    unless restore_database_dump(scenario_name, environment)
      puts "❌ Failed to restore database dump"
      return false
    end

    # Step 3: Create Rails root folder and copy files
    unless create_rails_root_folder(scenario_name)
      puts "❌ Failed to create Rails root folder"
      return false
    end

    # Step 4: Copy generated configuration files to Rails root
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    env_dir = File.join(scenarios_path, scenario_name, environment)

    if Dir.exist?(env_dir)
      # Copy database.yml
      if File.exist?(File.join(env_dir, 'database.yml'))
        FileUtils.cp(File.join(env_dir, 'database.yml'), File.join(rails_root, 'config', 'database.yml'))
        puts "   Copied database.yml to Rails root"
      end

      # Copy carambus.yml
      if File.exist?(File.join(env_dir, 'carambus.yml'))
        FileUtils.cp(File.join(env_dir, 'carambus.yml'), File.join(rails_root, 'config', 'carambus.yml'))
        puts "   Copied carambus.yml to Rails root"
      end
    end

    puts "✅ Scenario #{scenario_name} setup completed"
    puts "   Rails root: #{rails_root}"
    puts "   Environment: #{environment}"
    true
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

    # Step 3: Copy configuration files to Rails root folder
    puts "\n📁 Step 3: Copying configuration files to Rails root folder..."
    rails_root = File.expand_path("../#{scenario_name}", carambus_data_path)
    unless Dir.exist?(rails_root)
      puts "❌ Rails root folder not found: #{rails_root}"
      puts "   Please run: rake scenario:create_rails_root[#{scenario_name}]"
      return false
    end

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

    # Step 4: Copy deployment files
    puts "\n🚀 Step 4: Copying deployment files..."
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

    # Step 5: Upload shared configuration files to server
    puts "\n📤 Step 5: Uploading shared configuration files to server..."
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

    # Step 6: Restore database dump to production server
    puts "\n🗄️  Step 6: Restoring database dump to production server..."
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
              
              # Reset sequences for local server
              puts "   Resetting sequences..."
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

    # Step 7: Execute Capistrano deployment
    puts "\n🎯 Step 7: Executing Capistrano deployment..."
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

    puts "\n✅ Deployment preparation completed successfully!"
    puts "   Next step: Run 'cap production deploy' in the Rails root folder"

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
end
