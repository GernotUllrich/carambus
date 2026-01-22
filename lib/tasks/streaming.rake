# frozen_string_literal: true

namespace :streaming do
  desc "Setup streaming infrastructure on Raspberry Pi"
  task :setup, [:raspi_ip] => :environment do |t, args|
    require 'net/ssh'
    
    raspi_ip = args[:raspi_ip]
    abort "Usage: rake streaming:setup[RASPI_IP]" if raspi_ip.blank?
    
    puts "🚀 Setting up streaming on Raspberry Pi: #{raspi_ip}"
    puts "=" * 60
    
    ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
    ssh_port = ENV['RASPI_SSH_PORT']&.to_i || 22
    ssh_password = ENV['RASPI_SSH_PASSWORD']
    ssh_keys = ENV['RASPI_SSH_KEYS'] # Can be comma-separated list of key paths
    
    # Build SSH options
    ssh_options = {
      port: ssh_port,
      timeout: 10,
      verify_host_key: :never,
      non_interactive: true
    }
    
    # Add authentication method: password or keys
    if ssh_password.present?
      ssh_options[:password] = ssh_password
      puts "  → Using password authentication"
    elsif ssh_keys.present?
      key_paths = ssh_keys.split(',').map(&:strip).map { |k| File.expand_path(k) }
      ssh_options[:keys] = key_paths
      ssh_options[:keys_only] = true
      puts "  → Using key-based authentication (#{key_paths.join(', ')})"
    else
      # Try default SSH keys
      ssh_options[:keys_only] = false
      puts "  → Using default SSH key authentication"
    end
    
    puts "  → Connecting to #{ssh_user}@#{raspi_ip}:#{ssh_port}"
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
        puts "\n📦 Installing dependencies..."
        
        # Update package list
        puts "  → Updating package list..."
        ssh.exec!("sudo apt-get update -qq")
        
        # Install required packages
        # Note: chromium-browser was renamed to chromium in newer Raspberry Pi OS
        # netcat (nc) is used for the simple HTTP trigger endpoint
        packages = %w[ffmpeg xvfb v4l-utils imagemagick chromium netcat-openbsd curl]
        puts "  → Installing: #{packages.join(', ')}"
        ssh.exec!("sudo apt-get install -y #{packages.join(' ')}")
        
        puts "\n📁 Creating directories..."
        ssh.exec!("sudo mkdir -p /etc/carambus")
        ssh.exec!("sudo mkdir -p /var/log/carambus")
        ssh.exec!("sudo mkdir -p /usr/local/bin")
        ssh.exec!("sudo chown -R #{ssh_user}:#{ssh_user} /var/log/carambus")
        
        puts "\n📄 Uploading streaming script..."
        script_content = File.read(Rails.root.join('bin', 'carambus-stream.sh'))
        upload_file_via_ssh(ssh, script_content, '/tmp/carambus-stream.sh')
        ssh.exec!("sudo mv /tmp/carambus-stream.sh /usr/local/bin/carambus-stream.sh")
        ssh.exec!("sudo chmod +x /usr/local/bin/carambus-stream.sh")
        
        puts "\n📄 Uploading overlay updater script..."
        updater_content = File.read(Rails.root.join('bin', 'carambus-overlay-updater.sh'))
        upload_file_via_ssh(ssh, updater_content, '/tmp/carambus-overlay-updater.sh')
        ssh.exec!("sudo mv /tmp/carambus-overlay-updater.sh /usr/local/bin/carambus-overlay-updater.sh")
        ssh.exec!("sudo chmod +x /usr/local/bin/carambus-overlay-updater.sh")
        
        puts "\n⚙️  Installing systemd services..."
        service_content = File.read(Rails.root.join('bin', 'carambus-stream.service'))
        upload_file_via_ssh(ssh, service_content, '/tmp/carambus-stream@.service')
        ssh.exec!("sudo mv /tmp/carambus-stream@.service /etc/systemd/system/")
        
        updater_service_content = File.read(Rails.root.join('bin', 'carambus-overlay-updater.service'))
        upload_file_via_ssh(ssh, updater_service_content, '/tmp/carambus-overlay-updater@.service')
        ssh.exec!("sudo mv /tmp/carambus-overlay-updater@.service /etc/systemd/system/")
        
        ssh.exec!("sudo systemctl daemon-reload")
        
        puts "\n🔍 Checking camera..."
        camera_info = ssh.exec!("ls -l /dev/video* 2>/dev/null || echo 'No camera found'")
        puts camera_info
        
        puts "\n✅ Setup complete!"
        puts "=" * 60
        puts "\nNext steps:"
        puts "1. Configure stream settings in the admin interface"
        puts "2. Deploy configuration: rake streaming:deploy[TABLE_ID]"
        puts "3. Start stream via admin interface or:"
        ssh_port_flag = ssh_port != 22 ? "-p #{ssh_port} " : ""
        puts "   ssh #{ssh_port_flag}#{ssh_user}@#{raspi_ip} 'sudo systemctl start carambus-stream@1.service'"
      end
    rescue Net::SSH::AuthenticationFailed => e
      abort "❌ SSH authentication failed. Check credentials or SSH keys.\n   Error: #{e.message}"
    rescue Errno::EHOSTUNREACH
      abort "❌ Host unreachable: #{raspi_ip}"
    rescue Errno::ECONNREFUSED
      abort "❌ Connection refused: #{raspi_ip}:#{ssh_port}. Check if SSH is running on port #{ssh_port}."
    rescue => e
      abort "❌ Error: #{e.message}\n   #{e.class}"
    end
  end
  
  desc "Deploy stream configuration to Raspberry Pi"
  task :deploy, [:table_id] => :environment do |t, args|
    table_id = args[:table_id]
    abort "Usage: rake streaming:deploy[TABLE_ID]" if table_id.blank?
    
    table = Table.find(table_id)
    config = table.stream_configuration
    
    abort "No stream configuration found for table #{table_id}" if config.nil?
    
    puts "🚀 Deploying stream configuration for #{table.name}"
    puts "=" * 60
    puts "Table: #{table.name}"
    puts "Location: #{config.location.name}"
    puts "Raspi IP: #{config.raspi_ip}"
    puts "=" * 60
    
    # Deploy configuration
    deploy_stream_config(config)
    
    puts "\n✅ Configuration deployed!"
    puts "\nYou can now start the stream:"
    puts "  • Via admin interface"
    ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
    ssh_port = config.raspi_ssh_port || 22
    ssh_port_flag = ssh_port != 22 ? "-p #{ssh_port} " : ""
    puts "  • Or: ssh #{ssh_port_flag}#{ssh_user}@#{config.raspi_ip} 'sudo systemctl start carambus-stream@#{table.number}.service'"
  end
  
  desc "Deploy all stream configurations"
  task :deploy_all => :environment do
    configs = StreamConfiguration.all
    
    puts "🚀 Deploying #{configs.count} stream configuration(s)"
    puts "=" * 60
    
    configs.each do |config|
      puts "\n📤 Deploying: #{config.table.name} at #{config.location.name}"
      begin
        deploy_stream_config(config)
        puts "  ✅ Success"
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end
    end
    
    puts "\n" + "=" * 60
    puts "✅ Deployment complete!"
  end
  
  desc "Check status of all streams"
  task :status => :environment do
    configs = StreamConfiguration.includes(:table, :location).order('locations.name, tables.name')
    
    puts "📊 Stream Status Report"
    puts "=" * 80
    puts sprintf("%-30s %-15s %-15s %-15s", "Table", "Location", "Raspi IP", "Status")
    puts "-" * 80
    
    configs.each do |config|
      table_name = "#{config.table.name}".truncate(28)
      location_name = config.location.name.truncate(13)
      ip = config.raspi_ip || "N/A"
      status = config.status
      
      status_icon = case status
        when 'active' then '🟢'
        when 'starting' then '🟡'
        when 'error' then '🔴'
        else '⚪'
      end
      
      puts sprintf("%-30s %-15s %-15s %s %-13s", 
        table_name, location_name, ip, status_icon, status)
      
      if config.error_message.present?
        puts "  └─ Error: #{config.error_message.truncate(65)}"
      end
      
      if config.active? && config.last_started_at
        uptime = (Time.current - config.last_started_at).to_i
        hours = uptime / 3600
        minutes = (uptime % 3600) / 60
        puts "  └─ Uptime: #{hours}h #{minutes}m"
      end
    end
    
    puts "=" * 80
    puts "\nSummary:"
    puts "  Active:   #{configs.active.count}"
    puts "  Inactive: #{configs.inactive.count}"
    puts "  Errors:   #{configs.with_errors.count}"
    puts "  Total:    #{configs.count}"
  end
  
  desc "Test streaming setup on Raspberry Pi"
  task :test, [:raspi_ip] => :environment do |t, args|
    require 'net/ssh'
    
    raspi_ip = args[:raspi_ip]
    abort "Usage: rake streaming:test[RASPI_IP]" if raspi_ip.blank?
    
    puts "🧪 Testing streaming setup on: #{raspi_ip}"
    puts "=" * 60
    
    # Use helper to get SSH options
    ssh_options = build_ssh_options(raspi_ip)
    ssh_user = ssh_options.delete(:user)
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
        tests = {
          "FFmpeg installed" => "which ffmpeg",
          "Xvfb installed" => "which Xvfb",
          "Chromium installed" => "which chromium-browser || which chromium",
          "v4l-utils installed" => "which v4l2-ctl",
          "Camera detected" => "ls /dev/video0",
          "Config directory exists" => "test -d /etc/carambus && echo 'yes' || echo 'no'",
          "Log directory exists" => "test -d /var/log/carambus && echo 'yes' || echo 'no'",
          "Streaming script exists" => "test -f /usr/local/bin/carambus-stream.sh && echo 'yes' || echo 'no'",
          "Systemd service exists" => "test -f /etc/systemd/system/carambus-stream@.service && echo 'yes' || echo 'no'",
          "Network to YouTube" => "ping -c 1 a.rtmp.youtube.com > /dev/null 2>&1 && echo 'yes' || echo 'no'"
        }
        
        results = {}
        tests.each do |name, command|
          output = ssh.exec!(command).to_s.strip
          success = !output.empty? && output != 'no' && !output.include?('not found')
          results[name] = success
          
          icon = success ? "✅" : "❌"
          puts "#{icon} #{name}"
          puts "   └─ #{output}" if output.present? && output.length < 100
        end
        
        puts "\n" + "=" * 60
        passed = results.values.count(true)
        total = results.size
        puts "Result: #{passed}/#{total} tests passed"
        
        if passed == total
          puts "\n🎉 All tests passed! System is ready for streaming."
        else
          puts "\n⚠️  Some tests failed. Run 'rake streaming:setup[#{raspi_ip}]' to fix."
        end
      end
    rescue => e
      abort "❌ Error: #{e.message}"
    end
  end
  
  desc "Calibrate camera settings (find optimal focus/exposure values)"
  task :camera_calibrate, [:table_id] => :environment do |t, args|
    require 'net/ssh'
    
    table_id = args[:table_id]
    abort "Usage: rake streaming:camera_calibrate[TABLE_ID]" if table_id.blank?
    
    table = Table.find(table_id)
    config = table.stream_configuration
    
    abort "No stream configuration found for table #{table_id}" if config.nil?
    abort "No Raspberry Pi IP configured" if config.raspi_ip.blank?
    
    raspi_ip = config.raspi_ip
    camera_device = config.camera_device || '/dev/video0'
    
    puts "📷 Camera Calibration Tool"
    puts "=" * 60
    puts "Table: #{table.name}"
    puts "Location: #{config.location.name}"
    puts "Raspi IP: #{raspi_ip}"
    puts "Camera: #{camera_device}"
    puts "=" * 60
    
    ssh_options = build_ssh_options(raspi_ip)
    ssh_user = ssh_options[:user]
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
        puts "\n🔍 Reading current camera settings..."
        
        # Get all available controls
        controls_output = ssh.exec!("v4l2-ctl --device=#{camera_device} --list-ctrls 2>/dev/null")
        
        if controls_output.empty?
          abort "❌ Cannot access camera at #{camera_device}. Check if camera is connected and accessible."
        end
        
        # Parse controls
        controls = {}
        controls_output.each_line do |line|
          if line =~ /^\s*(\w+)\s+0x[0-9a-f]+\s+\((\w+)\)\s*:\s*min=(-?\d+)\s+max=(-?\d+)\s+step=(-?\d+)\s+default=(-?\d+)\s+value=(-?\d+)/
            name = $1
            type = $2
            min = $3.to_i
            max = $4.to_i
            step = $5.to_i
            default = $6.to_i
            value = $7.to_i
            
            controls[name] = {
              type: type,
              min: min,
              max: max,
              step: step,
              default: default,
              value: value
            }
          elsif line =~ /^\s*(\w+)\s+0x[0-9a-f]+\s+\((\w+)\)\s*:\s*min=(-?\d+)\s+max=(-?\d+)\s+step=(-?\d+)\s+default=(-?\d+)\s+value=(-?\d+)\s+flags=(\w+)/
            name = $1
            type = $2
            min = $3.to_i
            max = $4.to_i
            step = $5.to_i
            default = $6.to_i
            value = $7.to_i
            flags = $8
            
            controls[name] = {
              type: type,
              min: min,
              max: max,
              step: step,
              default: default,
              value: value,
              flags: flags
            }
          elsif line =~ /^\s*(\w+)\s+0x[0-9a-f]+\s+\((\w+)\)\s*:\s*min=(-?\d+)\s+max=(-?\d+)\s+step=(-?\d+)\s+default=(-?\d+)\s+value=(-?\d+)\s+\(([^)]+)\)/
            name = $1
            type = $2
            min = $3.to_i
            max = $4.to_i
            step = $5.to_i
            default = $6.to_i
            value = $7.to_i
            menu_text = $8
            
            controls[name] = {
              type: type,
              min: min,
              max: max,
              step: step,
              default: default,
              value: value,
              menu_text: menu_text
            }
          end
        end
        
        # Display current settings
        puts "\n📊 Current Camera Settings:"
        puts "-" * 60
        
        # Focus settings
        if controls['focus_automatic_continuous']
          focus_auto = controls['focus_automatic_continuous'][:value]
          puts "  Auto-Focus:        #{focus_auto == 1 ? 'ON (automatic)' : 'OFF (manual)'}"
          if controls['focus_absolute']
            focus_val = controls['focus_absolute'][:value]
            focus_max = controls['focus_absolute'][:max]
            puts "  Focus Value:       #{focus_val} / #{focus_max} (step: #{controls['focus_absolute'][:step]})"
          end
        elsif controls['focus_auto']
          focus_auto = controls['focus_auto'][:value]
          puts "  Auto-Focus:        #{focus_auto == 1 ? 'ON (automatic)' : 'OFF (manual)'}"
          if controls['focus_absolute']
            focus_val = controls['focus_absolute'][:value]
            focus_max = controls['focus_absolute'][:max]
            puts "  Focus Value:       #{focus_val} / #{focus_max}"
          end
        end
        
        # Exposure settings
        if controls['auto_exposure']
          exp_auto = controls['auto_exposure'][:value]
          exp_text = controls['auto_exposure'][:menu_text] || exp_auto.to_s
          puts "  Auto-Exposure:     #{exp_text}"
          if controls['exposure_time_absolute']
            exp_val = controls['exposure_time_absolute'][:value]
            exp_max = controls['exposure_time_absolute'][:max]
            puts "  Exposure Value:    #{exp_val} / #{exp_max} (default: #{controls['exposure_time_absolute'][:default]})"
          end
        elsif controls['exposure_auto']
          exp_auto = controls['exposure_auto'][:value]
          puts "  Auto-Exposure:     #{exp_auto == 3 ? 'ON (automatic)' : 'OFF (manual)'}"
          if controls['exposure_absolute']
            exp_val = controls['exposure_absolute'][:value]
            puts "  Exposure Value:    #{exp_val}"
          end
        end
        
        # Other settings
        if controls['brightness']
          puts "  Brightness:        #{controls['brightness'][:value]} / #{controls['brightness'][:max]} (default: #{controls['brightness'][:default]})"
        end
        if controls['contrast']
          puts "  Contrast:          #{controls['contrast'][:value]} / #{controls['contrast'][:max]} (default: #{controls['contrast'][:default]})"
        end
        if controls['saturation']
          puts "  Saturation:        #{controls['saturation'][:value]} / #{controls['saturation'][:max]} (default: #{controls['saturation'][:default]})"
        end
        
        puts "\n💡 Calibration Guide:"
        puts "-" * 60
        puts "1. Start with AUTO mode to see what the camera chooses"
        puts "2. Switch to MANUAL mode and use the current values as starting point"
        puts "3. Adjust values while watching the stream in OBS or via preview"
        puts "4. Find values that work well for your lighting conditions"
        puts "5. Save the values to the database when satisfied"
        puts ""
        puts "📝 Available Commands:"
        puts "  • Set auto-focus OFF:     v4l2-ctl --set-ctrl=focus_automatic_continuous=0"
        puts "  • Set auto-exposure OFF:  v4l2-ctl --set-ctrl=auto_exposure=1"
        puts "  • Set focus value:        v4l2-ctl --set-ctrl=focus_absolute=VALUE"
        puts "  • Set exposure value:     v4l2-ctl --set-ctrl=exposure_time_absolute=VALUE"
        puts "  • Set brightness:         v4l2-ctl --set-ctrl=brightness=VALUE"
        puts "  • Set contrast:          v4l2-ctl --set-ctrl=contrast=VALUE"
        puts "  • Set saturation:         v4l2-ctl --set-ctrl=saturation=VALUE"
        puts "  • Read current values:     v4l2-ctl --get-ctrl=CONTROL_NAME"
        puts ""
        puts "🔧 Interactive Mode:"
        puts "  You can now SSH to the Raspberry Pi and adjust values manually:"
        puts "    ssh #{ssh_user}@#{raspi_ip}"
        puts "    v4l2-ctl --device=#{camera_device} --set-ctrl=..."
        puts ""
        puts "  Or use this tool to set values directly:"
        puts "    rake streaming:camera_set[TABLE_ID,CONTROL,VALUE]"
        puts ""
        
        # Show current database values
        puts "💾 Current Database Values:"
        puts "-" * 60
        puts "  Focus Auto:         #{config.focus_auto || 0} (0=manual, 1=auto)"
        puts "  Exposure Auto:      #{config.exposure_auto || 1} (1=manual, 3=auto)"
        puts "  Focus Absolute:    #{config.focus_absolute || '(not set)'}"
        puts "  Exposure Absolute: #{config.exposure_absolute || '(not set)'}"
        puts "  Brightness:         #{config.brightness || '(not set)'}"
        puts "  Contrast:           #{config.contrast || '(not set)'}"
        puts "  Saturation:         #{config.saturation || '(not set)'}"
        puts ""
        puts "✅ To save current camera values to database:"
        puts "    rake streaming:camera_save[#{table_id}]"
      end
    rescue Net::SSH::AuthenticationFailed => e
      abort "❌ SSH authentication failed: #{e.message}"
    rescue => e
      abort "❌ Error: #{e.message}"
    end
  end
  
  desc "Set a camera control value on Raspberry Pi"
  task :camera_set, [:table_id, :control, :value] => :environment do |t, args|
    require 'net/ssh'
    
    table_id = args[:table_id]
    control = args[:control]
    value = args[:value]
    
    abort "Usage: rake streaming:camera_set[TABLE_ID,CONTROL,VALUE]" if [table_id, control, value].any?(&:blank?)
    
    table = Table.find(table_id)
    config = table.stream_configuration
    
    abort "No stream configuration found for table #{table_id}" if config.nil?
    abort "No Raspberry Pi IP configured" if config.raspi_ip.blank?
    
    raspi_ip = config.raspi_ip
    camera_device = config.camera_device || '/dev/video0'
    
    ssh_options = build_ssh_options(raspi_ip)
    ssh_user = ssh_options[:user]
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
        puts "🔧 Setting #{control} = #{value} on #{camera_device}..."
        
        result = ssh.exec!("v4l2-ctl --device=#{camera_device} --set-ctrl=#{control}=#{value} 2>&1")
        
        if result.empty? || result.include?('error')
          puts "❌ Failed to set value"
          puts result if result.present?
        else
          puts "✅ Value set successfully"
          
          # Read back to confirm
          current = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=#{control} 2>/dev/null")
          puts "   Current value: #{current.strip}" if current.present?
        end
      end
    rescue => e
      abort "❌ Error: #{e.message}"
    end
  end
  
  desc "Save current camera values from Raspberry Pi to database"
  task :camera_save, [:table_id] => :environment do |t, args|
    require 'net/ssh'
    
    table_id = args[:table_id]
    abort "Usage: rake streaming:camera_save[TABLE_ID]" if table_id.blank?
    
    table = Table.find(table_id)
    config = table.stream_configuration
    
    abort "No stream configuration found for table #{table_id}" if config.nil?
    abort "No Raspberry Pi IP configured" if config.raspi_ip.blank?
    
    raspi_ip = config.raspi_ip
    camera_device = config.camera_device || '/dev/video0'
    
    ssh_options = build_ssh_options(raspi_ip)
    ssh_user = ssh_options[:user]
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
        puts "💾 Reading current camera values from Raspberry Pi..."
        
        # Read all relevant values
        values = {}
        
        # Focus
        if ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=focus_automatic_continuous 2>/dev/null").present?
          focus_auto = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=focus_automatic_continuous 2>/dev/null").strip
          values[:focus_auto] = focus_auto.split('=').last.to_i
          
          if ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=focus_absolute 2>/dev/null").present?
            focus_abs = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=focus_absolute 2>/dev/null").strip
            values[:focus_absolute] = focus_abs.split('=').last.to_i if focus_abs.include?('=')
          end
        end
        
        # Exposure
        if ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=auto_exposure 2>/dev/null").present?
          exp_auto = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=auto_exposure 2>/dev/null").strip
          exp_val = exp_auto.split('=').last.to_i
          # Convert: 1=manual, 3=auto -> store as 1=manual, 3=auto
          values[:exposure_auto] = exp_val
          
          if ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=exposure_time_absolute 2>/dev/null").present?
            exp_abs = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=exposure_time_absolute 2>/dev/null").strip
            values[:exposure_absolute] = exp_abs.split('=').last.to_i if exp_abs.include?('=')
          end
        end
        
        # Brightness, Contrast, Saturation
        ['brightness', 'contrast', 'saturation'].each do |ctrl|
          if ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=#{ctrl} 2>/dev/null").present?
            val = ssh.exec!("v4l2-ctl --device=#{camera_device} --get-ctrl=#{ctrl} 2>/dev/null").strip
            values[ctrl.to_sym] = val.split('=').last.to_i if val.include?('=')
          end
        end
        
        # Update database
        puts "\n📝 Saving values to database..."
        puts "-" * 60
        
        values.each do |key, value|
          if config.respond_to?("#{key}=")
            config.send("#{key}=", value)
            puts "  #{key}: #{value}"
          end
        end
        
        if config.save
          puts "\n✅ Values saved successfully!"
          puts "\nNext steps:"
          puts "  1. Deploy configuration: rake streaming:deploy[#{table_id}]"
          puts "  2. Restart stream to apply new settings"
        else
          puts "\n❌ Failed to save: #{config.errors.full_messages.join(', ')}"
        end
      end
    rescue => e
      abort "❌ Error: #{e.message}"
    end
  end
  
  desc "Show streaming documentation"
  task :help do
    puts <<~HELP
      
      🎬 Carambus YouTube Streaming - Available Tasks
      ================================================
      
      Setup & Deployment:
        rake streaming:setup[RASPI_IP]           Setup streaming on new Raspberry Pi
        rake streaming:deploy[TABLE_ID]          Deploy config to specific table
        rake streaming:deploy_all                Deploy all configurations
      
      Monitoring:
        rake streaming:status                    Show status of all streams
        rake streaming:test[RASPI_IP]           Test streaming setup on Raspi
      
      Camera Calibration:
        rake streaming:camera_calibrate[TABLE_ID] Show current camera settings and calibration guide
        rake streaming:camera_set[TABLE_ID,CONTROL,VALUE] Set a camera control value
        rake streaming:camera_save[TABLE_ID]     Save current camera values to database
      
      Environment Variables:
        RASPI_SSH_USER      SSH username (default: pi)
        RASPI_SSH_PORT      SSH port (default: 22)
        RASPI_SSH_PASSWORD  SSH password (for password authentication)
        RASPI_SSH_KEYS      SSH key paths, comma-separated (for key-based auth)
                            If neither password nor keys specified, uses default SSH keys
      
      Examples:
        # Setup with password authentication (standard)
        RASPI_SSH_PASSWORD=raspberry rake streaming:setup[192.168.1.100]
        
        # Setup with key-based authentication on custom port (development)
        RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 rake streaming:setup[192.168.1.50]
        
        # Setup with explicit SSH key
        RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 RASPI_SSH_KEYS=~/.ssh/id_rsa rake streaming:setup[192.168.1.50]
        
        # Deploy configuration for table 1
        rake streaming:deploy[1]
        
        # Check status of all streams
        rake streaming:status
        
        # Test setup with custom port
        RASPI_SSH_USER=www-data RASPI_SSH_PORT=8910 rake streaming:test[192.168.1.50]
      
      Development Setup:
        For testing with a single Raspberry Pi in development:
        - Use www-data user with SSH key authentication
        - Use custom port (e.g., 8910) to avoid conflicts
        - Desktop still runs under pi user account
      
      For more information, see: docs/administrators/streaming-setup.md
      
    HELP
  end
end

# Helper method to build SSH options from environment variables
def build_ssh_options(raspi_ip = nil)
  ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
  ssh_port = ENV['RASPI_SSH_PORT']&.to_i || 22
  ssh_password = ENV['RASPI_SSH_PASSWORD']
  ssh_keys = ENV['RASPI_SSH_KEYS']
  
  ssh_options = {
    user: ssh_user,
    port: ssh_port,
    timeout: 10,
    verify_host_key: :never,
    non_interactive: true
  }
  
  # Add authentication method: password or keys
  if ssh_password.present?
    ssh_options[:password] = ssh_password
  elsif ssh_keys.present?
    key_paths = ssh_keys.split(',').map(&:strip).map { |k| File.expand_path(k) }
    ssh_options[:keys] = key_paths
    ssh_options[:keys_only] = true
  else
    # Try default SSH keys (~/.ssh/id_rsa, id_ed25519, etc.)
    ssh_options[:keys_only] = false
  end
  
  ssh_options
end

# Helper method to deploy config directly
def deploy_stream_config(config)
  require 'net/ssh'
  
  raspi_ip = config.raspi_ip
  raspi_port = config.raspi_ssh_port || 22
  table_number = config.table.number
  
  # Extract base URL and table_id for overlay receiver
  overlay_url = config.scoreboard_overlay_url
  if overlay_url.present? && overlay_url.match?(/table_id=(\d+)/)
    table_id = overlay_url[/table_id=(\d+)/, 1]
    overlay_url_base = overlay_url.sub(/\/locations\/.*/, '')
  else
    table_id = config.table.id
    overlay_url_base = overlay_url.present? ? overlay_url.sub(/\/locations\/.*/, '') : 'http://localhost:3000'
  end
  
  config_content = <<~CONFIG
    # Carambus Stream Configuration for Table #{table_number}
    # Generated: #{Time.current}
    
    # Stream Destination
    STREAM_DESTINATION=#{config.stream_destination}
    RTMP_URL=#{config.rtmp_url}
    
    # Legacy YouTube key (for backward compatibility)
    YOUTUBE_KEY=#{config.youtube_stream_key}
    
    # Camera Settings
    CAMERA_DEVICE=#{config.camera_device}
    CAMERA_WIDTH=#{config.camera_width}
    CAMERA_HEIGHT=#{config.camera_height}
    CAMERA_FPS=#{config.camera_fps}
    
    # Overlay Settings
    OVERLAY_ENABLED=#{config.overlay_enabled ? 'true' : 'false'}
    OVERLAY_URL=#{config.scoreboard_overlay_url}
    OVERLAY_URL_BASE=#{overlay_url_base}
    OVERLAY_POSITION=#{config.overlay_position}
    OVERLAY_HEIGHT=#{config.overlay_height}
    
    # Quality Settings
    VIDEO_BITRATE=#{config.video_bitrate}
    AUDIO_BITRATE=#{config.audio_bitrate}
    
    # Perspective Correction (Trapezkorrektur)
    PERSPECTIVE_ENABLED=#{config.perspective_enabled ? 'true' : 'false'}
    PERSPECTIVE_COORDS=#{config.perspective_coords || '0:0:W:0:W:H:0:H'}
    
    # Camera Manual Settings (for constant focus/exposure)
    FOCUS_AUTO=#{config.focus_auto || 0}
    EXPOSURE_AUTO=#{config.exposure_auto || 1}
    FOCUS_ABSOLUTE=#{config.focus_absolute || ''}
    EXPOSURE_ABSOLUTE=#{config.exposure_absolute || ''}
    BRIGHTNESS=#{config.brightness || ''}
    CONTRAST=#{config.contrast || ''}
    SATURATION=#{config.saturation || ''}
    
    # Metadata
    TABLE_NUMBER=#{table_number}
    TABLE_ID=#{table_id}
    LOCATION_MD5=#{config.location.md5}
    SERVER_URL=#{overlay_url_base}
    LOCATION_NAME="#{config.location.name}"
    GENERATED_AT="#{Time.current}"
  CONFIG
  
  temp_file = "/tmp/stream-table-#{table_number}.conf"
  target_file = "/etc/carambus/stream-table-#{table_number}.conf"
  
  # Build SSH options, overriding port from config
  ssh_options = build_ssh_options(raspi_ip)
  ssh_options[:port] = raspi_port
  ssh_user = ssh_options.delete(:user)
  
  Net::SSH.start(raspi_ip, ssh_user, ssh_options) do |ssh|
    upload_file_via_ssh(ssh, config_content, temp_file)
    ssh.exec!("sudo mv #{temp_file} #{target_file}")
    ssh.exec!("sudo chmod 644 #{target_file}")
  end
end

# Helper method to upload file content via SSH
def upload_file_via_ssh(ssh, content, remote_path)
  # Escape single quotes in content and use base64 encoding for binary-safe transfer
  require 'base64'
  encoded = Base64.strict_encode64(content)
  
  # Split into chunks if content is large (to avoid command line length limits)
  chunk_size = 50000
  if encoded.length > chunk_size
    # For large files, write in chunks
    ssh.exec!("rm -f #{remote_path}")
    encoded.scan(/.{1,#{chunk_size}}/).each do |chunk|
      ssh.exec!("echo '#{chunk}' | base64 -d >> #{remote_path}")
    end
  else
    # For small files, write in one go
    ssh.exec!("echo '#{encoded}' | base64 -d > #{remote_path}")
  end
end

