# frozen_string_literal: true

require 'net/ssh'

# Job to check the health of streaming services on Raspberry Pi devices
# Monitors stream status, checks for errors, and can trigger automatic restarts
class StreamHealthJob < ApplicationJob
  queue_as :default
  
  def perform(stream_config_id)
    @config = StreamConfiguration.find(stream_config_id)
    @raspi_ip = @config.raspi_ip
    @raspi_port = @config.raspi_ssh_port || 22
    @table_id = @config.table.id
    
    Rails.logger.info "[StreamHealth] Checking health for Table ID #{@table_id} (#{@config.table.name})"
    
    # Check if service is running
    service_active = check_service_active
    
    # Check if FFmpeg process is actually streaming
    ffmpeg_running = check_ffmpeg_running
    
    # Get recent logs
    recent_errors = check_for_errors
    
    # Update configuration status based on health check
    if service_active && ffmpeg_running && recent_errors.empty?
      # Stream is healthy
      if @config.error?
        Rails.logger.info "[StreamHealth] Stream recovered, marking as active"
        @config.mark_started!
      elsif !@config.active?
        Rails.logger.warn "[StreamHealth] Stream running but status is #{@config.status}"
        @config.mark_started!
      end
    elsif service_active && !ffmpeg_running
      # Service is active but FFmpeg died
      handle_ffmpeg_failure(recent_errors)
    elsif !service_active && @config.active?
      # Service stopped unexpectedly
      handle_service_failure
    end
    
    # Return health status
    {
      service_active: service_active,
      ffmpeg_running: ffmpeg_running,
      errors: recent_errors,
      uptime: get_stream_uptime
    }
  rescue StandardError => e
    Rails.logger.error "[StreamHealth] Health check failed: #{e.message}"
    @config.mark_failed!("Health check failed: #{e.message}")
    nil
  end
  
  private
  
  def check_service_active
    cmd = "sudo systemctl is-active carambus-stream@#{@table_id}.service"
    result = execute_ssh_command(cmd)
    result.success? && result.output.strip == 'active'
  end
  
  def check_ffmpeg_running
    # Check if FFmpeg process is running and streaming
    # Look for ffmpeg with the YouTube RTMP URL or device input
    cmd = "pgrep -f 'ffmpeg.*(/dev/video|rtmp://a.rtmp.youtube.com)' > /dev/null && echo 'running' || echo 'stopped'"
    result = execute_ssh_command(cmd)
    
    Rails.logger.debug "[StreamHealth] FFmpeg check: #{result.output.strip} (success: #{result.success?})"
    
    result.success? && result.output.strip == 'running'
  end
  
  def check_for_errors
    # Get last 50 lines of journal and look for errors
    cmd = "sudo journalctl -u carambus-stream@#{@table_id}.service -n 50 --no-pager | grep -i 'error\\|failed\\|fatal' || true"
    result = execute_ssh_command(cmd)
    
    return [] unless result.success?
    
    # Parse error lines
    errors = result.output.lines.map(&:strip).reject(&:empty?)
    errors.last(5)  # Return last 5 errors
  end
  
  def get_stream_uptime
    cmd = "systemctl show carambus-stream@#{@table_id}.service --property=ActiveEnterTimestamp --value"
    result = execute_ssh_command(cmd)
    
    return nil unless result.success?
    
    begin
      start_time = Time.parse(result.output.strip)
      Time.current - start_time
    rescue
      nil
    end
  end
  
  def handle_ffmpeg_failure(errors)
    error_message = "FFmpeg process died. Recent errors: #{errors.join('; ')}"
    Rails.logger.error "[StreamHealth] #{error_message}"
    
    # Check restart count
    if @config.restart_count < 5
      Rails.logger.info "[StreamHealth] Attempting automatic restart (attempt #{@config.restart_count + 1})"
      @config.increment!(:restart_count)
      @config.restart_streaming
    else
      @config.mark_failed!("Too many restart attempts: #{error_message}")
    end
  end
  
  def handle_service_failure
    Rails.logger.error "[StreamHealth] Service stopped unexpectedly"
    @config.mark_failed!("Service stopped unexpectedly")
  end
  
  def execute_ssh_command(command)
    output = ""
    exit_code = nil
    
    Net::SSH.start(@raspi_ip, ssh_user, ssh_options) do |ssh|
      # Execute command and capture exit status properly
      output = ssh.exec!(command)
      
      # Get the actual exit status from the channel
      ssh.exec!("echo $?") do |channel, stream, data|
        exit_code = data.strip.to_i if stream == :stdout
      end
    end
    
    # If we couldn't get exit code, check if output suggests success
    if exit_code.nil?
      # For systemctl is-active, "active" = success
      # For pgrep, "running" = success
      # For other commands, non-empty output without "error" = success
      exit_code = if command.include?('is-active')
                    output.strip == 'active' ? 0 : 1
                  elsif command.include?('pgrep')
                    output.strip == 'running' ? 0 : 1
                  else
                    0 # Assume success if we got output
                  end
    end
    
    OpenStruct.new(
      success?: exit_code.zero?,
      output: output || "",
      error: exit_code.zero? ? nil : output,
      exit_code: exit_code
    )
  rescue => e
    Rails.logger.error "[StreamHealth] SSH command failed: #{e.message}"
    OpenStruct.new(success?: false, error: e.message, output: "")
  end
  
  def ssh_user
    @config.raspi_ssh_user || ENV['RASPI_SSH_USER'] || 'www-data'
  end
  
  def ssh_options
    options = {
      port: @raspi_port,
      timeout: 10,
      non_interactive: true,
      verify_host_key: :never  # For local network devices
    }
    
    # Authentication: Try password from ENV, then fallback to SSH keys (same as StreamControlJob)
    if ENV['RASPI_SSH_PASSWORD'].present?
      options[:password] = ENV['RASPI_SSH_PASSWORD']
    elsif ENV['RASPI_SSH_KEYS'].present?
      key_paths = ENV['RASPI_SSH_KEYS'].split(',').map(&:strip).map { |k| File.expand_path(k) }
      options[:keys] = key_paths
      options[:keys_only] = true
    else
      # Auto-detect SSH keys from standard locations
      possible_keys = [
        File.expand_path('~/.ssh/id_rsa'),
        File.expand_path('~/.ssh/id_ed25519'),
        File.expand_path('~/.ssh/id_ecdsa'),
        File.expand_path('~/.ssh/id_dsa')
      ].select { |f| File.exist?(f) }
      
      if possible_keys.any?
        Rails.logger.info "[StreamHealth] Using SSH keys: #{possible_keys.join(', ')}"
        options[:keys] = possible_keys
        options[:keys_only] = true
      else
        # Last resort: try ssh-agent
        Rails.logger.info "[StreamHealth] No explicit keys found, trying ssh-agent"
        options[:keys_only] = false
      end
    end
    
    options
  end
end


