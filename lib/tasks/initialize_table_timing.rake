namespace :tables do
  desc "Initialize scoreboard timing configuration for all tables"
  task initialize_timing: :environment do
    puts "Initializing scoreboard timing configuration for tables..."
    puts "=" * 80
    
    initialized_count = 0
    skipped_count = 0
    
    Table.find_each do |table|
      # Skip if already configured
      if table.data&.dig('scoreboard_timing').present?
        puts "  ⏭️  Table #{table.id} (#{table.name}): Already configured, skipping"
        skipped_count += 1
        next
      end
      
      # Determine hardware type based on various criteria
      hardware_type = determine_hardware_type(table)
      
      # Set timing preset
      table.set_timing_preset(hardware_type)
      
      puts "  ✅ Table #{table.id} (#{table.name}): #{hardware_type} " \
           "(delay: #{table.timing_validation_delay}ms, failsafe: #{table.timing_lock_failsafe}ms)"
      initialized_count += 1
    end
    
    puts "=" * 80
    puts "Initialization complete!"
    puts "  Initialized: #{initialized_count} tables"
    puts "  Skipped: #{skipped_count} tables (already configured)"
    puts ""
    puts "To reconfigure a specific table:"
    puts "  Table.find(ID).set_timing_preset('pi3'|'pi4'|'desktop')"
  end
  
  desc "Show current timing configuration for all tables"
  task show_timing: :environment do
    puts "Current Scoreboard Timing Configuration"
    puts "=" * 100
    printf "%-5s %-30s %-15s %-20s %-20s\n", "ID", "Name", "Hardware", "Delay (ms)", "Failsafe (ms)"
    puts "-" * 100
    
    Table.find_each do |table|
      hardware = table.hardware_type || 'not set'
      delay = table.timing_validation_delay
      failsafe = table.timing_lock_failsafe
      
      printf "%-5s %-30s %-15s %-20s %-20s\n",
             table.id,
             table.name.to_s[0..29],
             hardware,
             delay,
             failsafe
    end
    
    puts "=" * 100
  end
  
  desc "Reset timing configuration for all tables"
  task reset_timing: :environment do
    print "This will reset timing configuration for ALL tables. Continue? (y/N): "
    response = STDIN.gets.chomp
    
    unless response.downcase == 'y'
      puts "Aborted."
      exit
    end
    
    puts "Resetting timing configuration..."
    
    Table.find_each do |table|
      if table.data&.dig('scoreboard_timing').present?
        table.data.delete('scoreboard_timing')
        table.hardware_type = nil
        table.save
        puts "  ✅ Table #{table.id} (#{table.name}): Reset"
      end
    end
    
    puts "Reset complete. Run 'rake tables:initialize_timing' to reinitialize."
  end
  
  private
  
  def determine_hardware_type(table)
    # Priority 1: Explicit hardware type already set
    return table.hardware_type if table.hardware_type.present?
    
    # Priority 2: Name-based detection
    case table.name
    when /Phat|5101|Pi\s*3/i
      return 'pi3'
    when /BCW|API|4/i
      return 'pi4'
    when /Desktop|Dev|PC/i
      return 'desktop'
    end
    
    # Priority 3: IP-based detection
    if table.ip_address.present?
      case table.ip_address
      when /^192\.168\.178\.107$/  # Known Pi 3
        return 'pi3'
      when /^192\.168\.178\.100$/  # Development machine
        return 'desktop'
      when /^192\.168\.178\.1[0-4][0-9]$/  # IP range 100-149 = desktops
        return 'desktop'
      when /^192\.168\.178\.1[5-9][0-9]$/  # IP range 150-199 = Pis
        # Default Pis to Pi 3 (safer)
        return 'pi3'
      end
    end
    
    # Priority 4: Location-based detection
    if table.location.present?
      case table.location.name
      when /Phat|3/i
        return 'pi3'
      when /BCW|4/i
        return 'pi4'
      end
    end
    
    # Default: Pi 3 (safest, slowest settings)
    'pi3'
  end
end

