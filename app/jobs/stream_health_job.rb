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
    @table_number = @config.table.number
    
    Rails.logger.info "[StreamHealth] Checking health for Table #{@table_number}"
    
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
    cmd = "systemctl is-active carambus-stream@#{@table_number}.service"
    result = execute_ssh_command(cmd)
    result.success? && result.output.strip == 'active'
  end
  
  def check_ffmpeg_running
    # Check if FFmpeg process is running and streaming
    cmd = "pgrep -f 'ffmpeg.*table.*#{@table_number}' > /dev/null && echo 'running' || echo 'stopped'"
    result = execute_ssh_command(cmd)
    result.success? && result.output.strip == 'running'
  end
  
  def check_for_errors
    # Get last 50 lines of journal and look for errors
    cmd = "sudo journalctl -u carambus-stream@#{@table_number}.service -n 50 --no-pager | grep -i 'error\\|failed\\|fatal' || true"
    result = execute_ssh_command(cmd)
    
    return [] unless result.success?
    
    # Parse error lines
    errors = result.output.lines.map(&:strip).reject(&:empty?)
    errors.last(5)  # Return last 5 errors
  end
  
  def get_stream_uptime
    cmd = "systemctl show carambus-stream@#{@table_number}.service --property=ActiveEnterTimestamp --value"
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
      output = ssh.exec!(command)
      exit_code = ssh.exec!("echo $?").strip.to_i
    end
    
    OpenStruct.new(
      success?: exit_code.zero?,
      output: output || "",
      error: exit_code.zero? ? nil : output,
      exit_code: exit_code
    )
  rescue => e
    OpenStruct.new(success?: false, error: e.message)
  end
  
  def ssh_user
    ENV['RASPI_SSH_USER'] || 'pi'
  end
  
  def ssh_options
    {
      port: @raspi_port,
      password: ENV['RASPI_SSH_PASSWORD'],
      timeout: 10,
      non_interactive: true,
      verify_host_key: :never
    }
  end
end


