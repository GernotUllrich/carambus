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
    ssh_password = ENV['RASPI_SSH_PASSWORD']
    
    abort "Error: RASPI_SSH_PASSWORD environment variable not set" if ssh_password.blank?
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, password: ssh_password, timeout: 10, verify_host_key: :never) do |ssh|
        puts "\n📦 Installing dependencies..."
        
        # Update package list
        puts "  → Updating package list..."
        ssh.exec!("sudo apt-get update -qq")
        
        # Install required packages
        packages = %w[ffmpeg xvfb v4l-utils imagemagick chromium-browser]
        puts "  → Installing: #{packages.join(', ')}"
        ssh.exec!("sudo apt-get install -y #{packages.join(' ')}")
        
        puts "\n📁 Creating directories..."
        ssh.exec!("sudo mkdir -p /etc/carambus")
        ssh.exec!("sudo mkdir -p /var/log/carambus")
        ssh.exec!("sudo mkdir -p /usr/local/bin")
        ssh.exec!("sudo chown -R #{ssh_user}:#{ssh_user} /var/log/carambus")
        
        puts "\n📄 Uploading streaming script..."
        script_content = File.read(Rails.root.join('bin', 'carambus-stream.sh'))
        ssh.exec!("cat > /tmp/carambus-stream.sh", data: script_content)
        ssh.exec!("sudo mv /tmp/carambus-stream.sh /usr/local/bin/carambus-stream.sh")
        ssh.exec!("sudo chmod +x /usr/local/bin/carambus-stream.sh")
        
        puts "\n⚙️  Installing systemd service..."
        service_content = File.read(Rails.root.join('bin', 'carambus-stream.service'))
        ssh.exec!("cat > /tmp/carambus-stream@.service", data: service_content)
        ssh.exec!("sudo mv /tmp/carambus-stream@.service /etc/systemd/system/")
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
        puts "   ssh #{ssh_user}@#{raspi_ip} 'sudo systemctl start carambus-stream@1.service'"
      end
    rescue Net::SSH::AuthenticationFailed
      abort "❌ SSH authentication failed. Check RASPI_SSH_PASSWORD."
    rescue Errno::EHOSTUNREACH
      abort "❌ Host unreachable: #{raspi_ip}"
    rescue => e
      abort "❌ Error: #{e.message}"
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
    puts "  • Or: ssh pi@#{config.raspi_ip} 'sudo systemctl start carambus-stream@#{table.number}.service'"
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
    
    ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
    ssh_password = ENV['RASPI_SSH_PASSWORD']
    
    abort "Error: RASPI_SSH_PASSWORD not set" if ssh_password.blank?
    
    begin
      Net::SSH.start(raspi_ip, ssh_user, password: ssh_password, timeout: 10, verify_host_key: :never) do |ssh|
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
      
      Environment Variables:
        RASPI_SSH_USER      SSH username (default: pi)
        RASPI_SSH_PASSWORD  SSH password (required)
      
      Examples:
        # Setup new Raspberry Pi for streaming
        RASPI_SSH_PASSWORD=raspberry rake streaming:setup[192.168.1.100]
        
        # Deploy configuration for table 1
        rake streaming:deploy[1]
        
        # Check status of all streams
        rake streaming:status
        
        # Test setup
        RASPI_SSH_PASSWORD=raspberry rake streaming:test[192.168.1.100]
      
      For more information, see: docs/administrators/streaming-setup.md
      
    HELP
  end
end

# Helper method to deploy config directly
def deploy_stream_config(config)
  require 'net/ssh'
  
  raspi_ip = config.raspi_ip
  raspi_port = config.raspi_ssh_port || 22
  table_number = config.table.number
  
  config_content = <<~CONFIG
    # Carambus Stream Configuration for Table #{table_number}
    # Generated: #{Time.current}
    
    YOUTUBE_KEY=#{config.youtube_stream_key}
    CAMERA_DEVICE=#{config.camera_device}
    CAMERA_WIDTH=#{config.camera_width}
    CAMERA_HEIGHT=#{config.camera_height}
    CAMERA_FPS=#{config.camera_fps}
    
    OVERLAY_ENABLED=#{config.overlay_enabled ? 'true' : 'false'}
    OVERLAY_URL=#{config.scoreboard_overlay_url}
    OVERLAY_POSITION=#{config.overlay_position}
    OVERLAY_HEIGHT=#{config.overlay_height}
    
    VIDEO_BITRATE=#{config.video_bitrate}
    AUDIO_BITRATE=#{config.audio_bitrate}
    
    TABLE_NUMBER=#{table_number}
  CONFIG
  
  temp_file = "/tmp/stream-table-#{table_number}.conf"
  target_file = "/etc/carambus/stream-table-#{table_number}.conf"
  
  ssh_user = ENV['RASPI_SSH_USER'] || 'pi'
  ssh_password = ENV['RASPI_SSH_PASSWORD']
  
  Net::SSH.start(raspi_ip, ssh_user, password: ssh_password, port: raspi_port, timeout: 10, verify_host_key: :never) do |ssh|
    ssh.exec!("cat > #{temp_file}", data: config_content)
    ssh.exec!("sudo mv #{temp_file} #{target_file}")
    ssh.exec!("sudo chmod 644 #{target_file}")
  end
end

