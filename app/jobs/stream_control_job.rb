# frozen_string_literal: true

require 'net/ssh'

# Job to control streaming on remote Raspberry Pi devices
# Handles start, stop, and restart operations via SSH
class StreamControlJob < ApplicationJob
  queue_as :default
  
  # Retry with exponential backoff on network errors
  retry_on Net::SSH::Exception, wait: :exponentially_longer, attempts: 3
  retry_on Errno::EHOSTUNREACH, wait: 10.seconds, attempts: 3
  
  def perform(stream_config_id, action)
    @config = StreamConfiguration.find(stream_config_id)
    @raspi_ip = @config.raspi_ip
    @raspi_port = @config.raspi_ssh_port || 22
    @table_number = @config.table.number
    
    Rails.logger.info "[StreamControl] #{action.upcase} stream for Table #{@table_number} at #{@raspi_ip}"
    
    case action
    when 'start'
      handle_start
    when 'stop'
      handle_stop
    when 'restart'
      handle_restart
    else
      raise ArgumentError, "Unknown action: #{action}"
    end
  rescue StandardError => e
    Rails.logger.error "[StreamControl] Error #{action} stream: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @config.mark_failed!("#{action.capitalize} failed: #{e.message}")
  end
  
  private
  
  def handle_start
    # Check if stream is already running
    if stream_running?
      Rails.logger.info "[StreamControl] Stream already running, skipping start"
      @config.mark_started!
      return
    end
    
    # Ensure configuration files are up to date
    deploy_config_file
    
    # Start the systemd service
    cmd = "sudo systemctl start carambus-stream@#{@table_number}.service"
    result = execute_ssh_command(cmd)
    
    if result.success?
      # Wait a moment and verify it started
      sleep 2
      if stream_running?
        @config.mark_started!
        Rails.logger.info "[StreamControl] Stream started successfully"
      else
        error_msg = get_stream_error
        @config.mark_failed!("Stream failed to start: #{error_msg}")
      end
    else
      @config.mark_failed!("Failed to start systemd service: #{result.error}")
    end
  end
  
  def handle_stop
    cmd = "sudo systemctl stop carambus-stream@#{@table_number}.service"
    result = execute_ssh_command(cmd)
    
    if result.success?
      # Wait a moment and verify it stopped
      sleep 1
      unless stream_running?
        @config.mark_stopped!
        Rails.logger.info "[StreamControl] Stream stopped successfully"
      else
        @config.mark_failed!("Stream failed to stop")
      end
    else
      @config.mark_failed!("Failed to stop systemd service: #{result.error}")
    end
  end
  
  def handle_restart
    handle_stop
    sleep 2
    handle_start
  end
  
  # Check if the stream service is running
  def stream_running?
    cmd = "systemctl is-active carambus-stream@#{@table_number}.service"
    result = execute_ssh_command(cmd)
    result.success? && result.output.strip == 'active'
  end
  
  # Get error message from systemd journal
  def get_stream_error
    cmd = "sudo journalctl -u carambus-stream@#{@table_number}.service -n 20 --no-pager"
    result = execute_ssh_command(cmd)
    result.success? ? result.output.lines.last(5).join : "Unknown error"
  end
  
  # Deploy updated configuration file to Raspberry Pi
  def deploy_config_file
    config_content = generate_config_file
    temp_file = "/tmp/stream-table-#{@table_number}.conf"
    target_file = "/etc/carambus/stream-table-#{@table_number}.conf"
    
    # Upload file
    Net::SSH.start(@raspi_ip, ssh_user, ssh_options) do |ssh|
      # Write to temp location
      ssh.exec!("cat > #{temp_file}", data: config_content)
      # Move to final location with sudo
      ssh.exec!("sudo mv #{temp_file} #{target_file}")
      ssh.exec!("sudo chmod 644 #{target_file}")
    end
    
    Rails.logger.info "[StreamControl] Configuration file deployed"
  end
  
  # Generate configuration file content
  def generate_config_file
    <<~CONFIG
      # Carambus Stream Configuration for Table #{@table_number}
      # Generated: #{Time.current}
      
      YOUTUBE_KEY=#{@config.youtube_stream_key}
      CAMERA_DEVICE=#{@config.camera_device}
      CAMERA_WIDTH=#{@config.camera_width}
      CAMERA_HEIGHT=#{@config.camera_height}
      CAMERA_FPS=#{@config.camera_fps}
      
      OVERLAY_ENABLED=#{@config.overlay_enabled ? 'true' : 'false'}
      OVERLAY_URL=#{@config.scoreboard_overlay_url}
      OVERLAY_POSITION=#{@config.overlay_position}
      OVERLAY_HEIGHT=#{@config.overlay_height}
      
      VIDEO_BITRATE=#{@config.video_bitrate}
      AUDIO_BITRATE=#{@config.audio_bitrate}
      
      TABLE_NUMBER=#{@table_number}
    CONFIG
  end
  
  # Execute SSH command on Raspberry Pi
  def execute_ssh_command(command)
    output = ""
    exit_code = nil
    
    Net::SSH.start(@raspi_ip, ssh_user, ssh_options) do |ssh|
      output = ssh.exec!(command)
      exit_code = ssh.exec!("echo $?").strip.to_i
    end
    
    OpenStruct.new(
      success?: exit_code.zero?,
      output: output || "",
      error: exit_code.zero? ? nil : output,
      exit_code: exit_code
    )
  rescue Net::SSH::AuthenticationFailed => e
    OpenStruct.new(success?: false, error: "SSH authentication failed: #{e.message}")
  rescue Errno::EHOSTUNREACH => e
    OpenStruct.new(success?: false, error: "Host unreachable: #{e.message}")
  rescue => e
    OpenStruct.new(success?: false, error: e.message)
  end
  
  # SSH user (typically 'pi' for Raspberry Pi)
  def ssh_user
    ENV['RASPI_SSH_USER'] || 'pi'
  end
  
  # SSH connection options
  def ssh_options
    {
      port: @raspi_port,
      password: ENV['RASPI_SSH_PASSWORD'],
      timeout: 10,
      non_interactive: true,
      verify_host_key: :never  # For local network devices
    }
  end
end


