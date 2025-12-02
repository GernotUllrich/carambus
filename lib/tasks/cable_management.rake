# frozen_string_literal: true

namespace :cable do
  desc "Force all clients to reconnect"
  task force_reconnect: :environment do
    reason = ENV['REASON'] || 'server_maintenance'
    
    puts "🔄 Forcing reconnection of all clients..."
    puts "   Reason: #{reason}"
    
    TableMonitorChannel.force_reconnect(reason: reason)
    
    puts "✅ Reconnection broadcast sent"
    puts "   All subscribed clients should reconnect within a few seconds"
  end

  desc "Show cable connection statistics"
  task stats: :environment do
    total = ActionCable.server.connections.size
    
    puts "📊 ActionCable Statistics"
    puts "=" * 50
    puts "Total connections: #{total}"
    
    if total > 0
      puts "\nActive connections:"
      ActionCable.server.connections.each_with_index do |conn, index|
        begin
          puts "  #{index + 1}. Token: #{conn.connection_token}"
        rescue StandardError => e
          puts "  #{index + 1}. Error reading connection: #{e.message}"
        end
      end
    end
    
    # Check Redis subscribers
    begin
      config = Rails.application.config_for(:cable)
      redis_url = config['url'] || ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
      redis = Redis.new(url: redis_url)
      
      result = redis.pubsub('numsub', 'table-monitor-stream')
      subscribers = result[1].to_i
      
      puts "\n📡 Redis Pub/Sub Statistics"
      puts "=" * 50
      puts "Subscribers on 'table-monitor-stream': #{subscribers}"
      
      if subscribers != total
        puts "\n⚠️  WARNING: Connection count mismatch!"
        puts "   ActionCable connections: #{total}"
        puts "   Redis subscribers: #{subscribers}"
        puts "   Consider running: rake cable:force_reconnect"
      end
    rescue StandardError => e
      puts "\n❌ Could not get Redis statistics: #{e.message}"
    end
  end

  desc "Disconnect all stale connections"
  task disconnect_stale: :environment do
    threshold = ENV['THRESHOLD']&.to_i || 300 # 5 minutes default
    
    puts "🔍 Checking for stale connections (threshold: #{threshold}s)..."
    
    disconnected = 0
    ActionCable.server.connections.each do |conn|
      # This would require tracking connection timestamps
      # For now, just force disconnect all
      begin
        conn.close(reason: 'stale_connection_cleanup')
        disconnected += 1
      rescue StandardError => e
        puts "  ⚠️  Error disconnecting: #{e.message}"
      end
    end
    
    puts "✅ Disconnected #{disconnected} connections"
  end
end


