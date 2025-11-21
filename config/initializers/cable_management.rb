# frozen_string_literal: true

# ActionCable Connection Management
# Handles force reconnect after server restart

Rails.application.config.after_initialize do
  # Skip in console or rake tasks (except in production when explicitly enabled)
  next if defined?(Rails::Console) || File.basename($PROGRAM_NAME) == 'rake'
  
  # Only run in production or if explicitly enabled
  force_reconnect = ENV['FORCE_RECONNECT_ON_BOOT'] == 'true'
  
  if Rails.env.production? || force_reconnect
    # Wait for server to be fully initialized
    Thread.new do
      # Wait 15 seconds for:
      # - All services to be ready
      # - Redis connection to be established
      # - ActionCable server to be mounted
      sleep 15
      
      begin
        Rails.logger.info "🔄 Sending force reconnect to all clients (server restarted)"
        
        # Broadcast force reconnect
        TableMonitorChannel.force_reconnect(reason: "server_restarted")
        
        Rails.logger.info "✅ Force reconnect broadcast sent successfully"
      rescue StandardError => e
        Rails.logger.error "❌ Failed to send force reconnect: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end
    end
  end
end

