#!/usr/bin/env ruby
# frozen_string_literal: true

# Carambus Overlay PNG Receiver
# This script runs on the streaming Raspberry Pi and listens for PNG overlays
# broadcast via ActionCable from the server.
#
# Usage:
#   ./carambus-overlay-receiver.rb <server_url> <table_id>
#
# Example:
#   ./carambus-overlay-receiver.rb http://192.168.178.106:3000 2

require 'json'
require 'base64'
require 'websocket-client-simple'
require 'uri'
require 'net/http'

# Parse arguments
if ARGV.length < 2
  puts "Usage: #{$0} <server_url> <table_id>"
  puts "Example: #{$0} http://192.168.178.106:3000 2"
  exit 1
end

SERVER_URL = ARGV[0]
TABLE_ID = ARGV[1].to_i
OVERLAY_FILE = "/tmp/carambus-overlay-table-#{TABLE_ID}.png"

puts "🎨 Carambus Overlay Receiver"
puts "   Server: #{SERVER_URL}"
puts "   Table ID: #{TABLE_ID}"
puts "   Output: #{OVERLAY_FILE}"
puts ""

# Convert HTTP URL to WebSocket URL
ws_url = SERVER_URL.sub(/^http/, 'ws') + '/cable'

puts "🔌 Connecting to ActionCable at #{ws_url}..."

ws = WebSocket::Client::Simple.connect(ws_url)

ws.on :open do
  puts "✅ WebSocket connected"
  
  # Subscribe to table-monitor-stream channel
  subscribe_msg = {
    command: 'subscribe',
    identifier: JSON.generate({
      channel: 'TableMonitorChannel'
    })
  }.to_json
  
  ws.send(subscribe_msg)
  puts "📡 Subscribed to TableMonitorChannel"
end

ws.on :message do |msg|
  begin
    data = JSON.parse(msg.data)
    
    # Handle welcome message
    if data['type'] == 'welcome'
      puts "👋 Server welcomed connection"
      next
    end
    
    # Handle ping
    if data['type'] == 'ping'
      next
    end
    
    # Handle subscription confirmation
    if data['type'] == 'confirm_subscription'
      puts "✅ Subscription confirmed"
      next
    end
    
    # Handle CableReady messages
    if data['message']
      message = data['message']
      
      # Check for CableReady operations
      if message['cableReady'] && message['operations']
        message['operations'].each do |operation|
          # Look for dispatch_event with name 'overlay-png-update'
          if operation['operation'] == 'dispatchEvent' && operation['name'] == 'overlay-png-update'
            detail = operation['detail']
            
            # Filter by table_id
            if detail && detail['table_id'] == TABLE_ID
              puts "📥 Received PNG update for table #{TABLE_ID}"
              
              # Decode base64 PNG data
              png_data = Base64.strict_decode64(detail['png_data'])
              
              # Write to file
              File.binwrite(OVERLAY_FILE, png_data)
              
              file_size = File.size(OVERLAY_FILE)
              puts "✅ Saved PNG: #{file_size} bytes → #{OVERLAY_FILE}"
              puts "   Timestamp: #{Time.at(detail['timestamp'] / 1000.0)}"
            end
          end
        end
      end
    end
    
  rescue JSON::ParserError => e
    # Ignore non-JSON messages
  rescue => e
    puts "❌ Error processing message: #{e.message}"
    puts e.backtrace.first(3)
  end
end

ws.on :error do |e|
  puts "❌ WebSocket error: #{e.message}"
end

ws.on :close do |e|
  puts "🔌 WebSocket closed (code: #{e.code}, reason: #{e.reason})"
  puts "🔄 Reconnecting in 5 seconds..."
  sleep 5
  exec($0, *ARGV) # Restart script
end

puts "✨ Listening for PNG updates..."
puts "   Press Ctrl+C to stop"
puts ""

# Keep script running
loop do
  sleep 1
end

