# Patch for prepare_scenario_for_deployment to add local data preservation
# This file contains the modified function with local data handling

def prepare_scenario_for_deployment_with_local_data(scenario_name)
  puts "Preparing scenario #{scenario_name} for deployment..."
  puts "This includes production config generation, database setup, file transfers to server, and server preparation."
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

  # Step 0: Check compatibility and handle local data
  puts "\n🔍 Step 0: Checking compatibility and local data..."
  compatibility_result = check_scenario_compatibility(scenario_name)
  
  if !compatibility_result[:compatible] && compatibility_result[:has_local_data]
    puts "⚠️  WARNING: Local data will be lost during deployment!"
    puts "   Found #{compatibility_result[:local_data_count]} local records"
    
    # Ask user for confirmation
    puts "\nOptions:"
    puts "  1. Backup local data and proceed (RECOMMENDED)"
    puts "  2. Proceed without backup (DATA WILL BE LOST)"
    puts "  3. Cancel deployment"
    puts "\nEnter your choice (1-3):"
    
    choice = STDIN.gets.chomp.to_i
    
    case choice
    when 1
      puts "📋 Backing up local data..."
      backup_file = backup_local_data_from_production(scenario_name)
      if backup_file
        puts "✅ Local data backed up successfully"
        # Store backup file path for later use
        @local_data_backup = backup_file
      else
        puts "❌ Failed to backup local data"
        return false
      end
    when 2
      puts "⚠️  Proceeding without backup - local data will be LOST!"
      puts "Are you sure? This will permanently delete local data! (type 'yes' to continue):"
      confirmation = STDIN.gets.chomp
      unless confirmation.downcase == 'yes'
        puts "Deployment cancelled"
        return false
      end
    when 3
      puts "Deployment cancelled"
      return false
    else
      puts "Invalid choice - deployment cancelled"
      return false
    end
  end

  # Continue with existing prepare_deploy steps...
  # (rest of the function remains the same)
  
  # Step 1: Generate production configuration files
  puts "\n📋 Step 1: Generating production configuration files..."
  unless generate_configuration_files(scenario_name, 'production')
    puts "❌ Failed to generate production configuration files"
    return false
  end

  # ... rest of the function would be the same as the original
  # This is just a template showing where to add the compatibility check
end
