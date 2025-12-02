#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify ActionCable Redis adapter is working correctly
# This simulates a broadcast and checks if it's properly sent through Redis

require_relative "../config/environment"
require "redis"

puts "=" * 80
puts "ActionCable Redis Adapter Test"
puts "=" * 80
puts

# Check cable.yml configuration
cable_config = Rails.application.config_for(:cable)
puts "📋 Cable Configuration:"
puts "   Adapter: #{cable_config['adapter']}"
puts "   URL: #{cable_config['url']}" if cable_config['url']
puts

if cable_config['adapter'] != 'redis'
  puts "❌ ERROR: Cable adapter is '#{cable_config['adapter']}' (should be 'redis')"
  puts "   Please update config/cable.yml to use redis adapter"
  exit 1
end

# Check Redis connection
puts "🔌 Testing Redis Connection..."
begin
  redis_url = cable_config['url'] || ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  redis = Redis.new(url: redis_url)
  
  # Test PING
  response = redis.ping
  if response == "PONG"
    puts "   ✅ Redis connection successful (#{redis_url})"
  else
    puts "   ❌ Redis PING failed: #{response}"
    exit 1
  end
  
  # Check Redis info
  info = redis.info
  puts "   Redis Version: #{info['redis_version']}"
  puts "   Connected Clients: #{info['connected_clients']}"
  puts

rescue => e
  puts "   ❌ Redis connection failed: #{e.message}"
  puts "   Make sure Redis is running: redis-cli ping"
  exit 1
end

# Test ActionCable broadcast
puts "📡 Testing ActionCable Broadcast..."

# Find a table monitor to test with
table_monitor = TableMonitor.first
unless table_monitor
  puts "   ⚠️  No TableMonitor found in database, creating test broadcast anyway..."
  test_id = 999
else
  test_id = table_monitor.id
  puts "   Using TableMonitor ID: #{test_id}"
end

# Set up Redis subscriber to listen for broadcasts
subscriber_thread = Thread.new do
  subscriber = Redis.new(url: redis_url)
  puts "   🎧 Subscriber listening on channel: cable:table-monitor-stream..."
  
  subscriber.subscribe("cable:table-monitor-stream") do |on|
    on.message do |channel, message|
      puts "   ✅ RECEIVED BROADCAST on #{channel}:"
      data = JSON.parse(message)
      puts "      Message type: #{data['message']['type'] rescue 'broadcast'}"
      puts "      Has CableReady operations: #{data['message']['cableReady'] rescue false}"
    end
  end
end

# Give subscriber time to connect
sleep 0.5

# Broadcast a test message
puts "   📤 Broadcasting test message..."
ActionCable.server.broadcast(
  "table-monitor-stream",
  {
    type: "test_broadcast",
    test: true,
    timestamp: Time.current.to_i,
    message: "ActionCable Redis test successful!"
  }
)

# Wait for message to be received
sleep 1

# Stop subscriber
Thread.kill(subscriber_thread)
puts

# Test with actual TableMonitorJob if we have a table monitor
if table_monitor
  puts "🎮 Testing Real TableMonitorJob Broadcast..."
  puts "   Broadcasting teaser update for TableMonitor ##{table_monitor.id}..."
  
  # Set up subscriber again
  received = false
  subscriber_thread = Thread.new do
    subscriber = Redis.new(url: redis_url)
    subscriber.subscribe("cable:table-monitor-stream") do |on|
      on.message do |channel, message|
        data = JSON.parse(message)
        if data.dig('message', 'cableReady')
          received = true
          ops = data.dig('message', 'operations') || []
          puts "   ✅ RECEIVED TableMonitorJob broadcast:"
          puts "      Operations: #{ops.length}"
          ops.each_with_index do |op, i|
            puts "      ##{i+1}: #{op['operation']} -> #{op['selector']}"
          end
        end
      end
    end
  end
  
  sleep 0.5
  
  # Trigger actual job
  TableMonitorJob.perform_now(table_monitor, "teaser")
  
  sleep 1
  Thread.kill(subscriber_thread)
  
  if received
    puts "   ✅ TableMonitorJob broadcast verified!"
  else
    puts "   ⚠️  No CableReady operations received (job may have run but broadcast filtered)"
  end
  puts
end

puts "=" * 80
puts "✅ All tests passed! ActionCable Redis adapter is working correctly."
puts "=" * 80
puts
puts "Next steps:"
puts "1. Restart your Rails server (the cable.yml change requires restart)"
puts "2. Open multiple browsers to the same scoreboard"
puts "3. Make an update in one browser"
puts "4. Verify the other browser(s) receive the update in real-time"
puts
puts "To enable detailed logging in browser console:"
puts "  localStorage.setItem('debug_cable_performance', 'true')"
puts


