# frozen_string_literal: true

namespace :scoreboard_messages do
  desc "Clean up expired scoreboard messages (auto-acknowledge and broadcast)"
  task cleanup: :environment do
    puts "🧹 Starting scoreboard message cleanup..."
    
    ScoreboardMessageCleanupJob.perform_now
    
    puts "✅ Scoreboard message cleanup completed"
  end

  desc "Show active scoreboard messages"
  task list: :environment do
    active_messages = ScoreboardMessage.active.includes(:location, :table_monitor, :sender)
    
    if active_messages.any?
      puts "\n📨 Active Scoreboard Messages:\n"
      puts "=" * 80
      
      active_messages.each do |message|
        puts "\nID: #{message.id}"
        puts "Location: #{message.location.name}"
        puts "Target: #{message.table_monitor_id.present? ? "Table #{message.table_monitor.name}" : 'ALL TABLES'}"
        puts "Message: #{message.message}"
        puts "Sender: #{message.sender.name}"
        puts "Created: #{message.created_at}"
        puts "Expires: #{message.expires_at} (in #{((message.expires_at - Time.current) / 60).round} minutes)"
        puts "-" * 80
      end
      
      puts "\nTotal: #{active_messages.count} active message(s)"
    else
      puts "✅ No active scoreboard messages"
    end
  end

  desc "Show statistics for scoreboard messages"
  task stats: :environment do
    total = ScoreboardMessage.count
    active = ScoreboardMessage.active.count
    acknowledged = ScoreboardMessage.acknowledged.count
    expired = ScoreboardMessage.expired.count
    
    puts "\n📊 Scoreboard Message Statistics:\n"
    puts "=" * 50
    puts "Total messages:       #{total}"
    puts "Active:               #{active}"
    puts "Acknowledged:         #{acknowledged}"
    puts "Expired (unacked):    #{expired}"
    puts "=" * 50
  end
end

# Add to crontab for automatic cleanup:
# */10 * * * * cd /path/to/carambus && bundle exec rake scoreboard_messages:cleanup RAILS_ENV=production >> log/scoreboard_messages.log 2>&1
