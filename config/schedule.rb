# frozen_string_literal: true

# Whenever schedule configuration
# Learn more: https://github.com/javan/whenever
#
# Deploy with: whenever --update-crontab
# Clear with: whenever --clear-crontab
# View cron: crontab -l

# Set environment variables
set :output, "log/cron.log"
set :environment, ENV.fetch('RAILS_ENV', 'production')

# Use absolute paths for commands
job_type :rake, "cd :path && :environment_variable=:environment bundle exec rake :task :output"

# ============================================================================
# INTERNATIONAL CONTENT SCRAPING
# ============================================================================

# Daily YouTube scraping + auto-tagging + processing
# Runs at 2:00 AM every day
# - Scrapes all 19 YouTube channels (last 3 days)
# - Auto-tags videos (players, content type, quality)
# - Discovers tournaments
# - Translates titles (if configured)
every 1.day, at: '2:00 am' do
  rake "international:daily_scrape"
end

# Daily UMB tournament data scraping
# Runs at 3:00 AM every day
# - Fetches official UMB tournament data
# - Updates tournament information
every 1.day, at: '3:00 am' do
  rake "international:scrape_umb"
end

# Weekly cleanup: Process all remaining untagged videos
# Runs every Sunday at 4:00 AM
# - Ensures no videos are left unprocessed
# - Catches any videos that were skipped during daily runs
every :sunday, at: '4:00 am' do
  runner "Video.youtube.where(metadata_extracted: false).find_each(&:auto_tag!)"
end

# ============================================================================
# REGIONAL/LOCAL SCRAPING (if enabled)
# ============================================================================

# Uncomment if you want to sync regional ClubCloud data daily
# every 1.day, at: '5:00 am' do
#   rake "scrape:optimized_daily_update"
# end

# ============================================================================
# MAINTENANCE TASKS
# ============================================================================

# Weekly: Clean up old logs (keep last 90 days)
# Runs every Sunday at 5:00 AM
every :sunday, at: '5:00 am' do
  rake "scrape:cleanup_logs[90]"
end

# Monthly: Update video statistics and tag counts
# Runs on the 1st of each month at 6:00 AM
every '0 6 1 * *' do
  runner <<-RUBY
    # Recalculate all tag counts
    Video.youtube.find_each do |video|
      video.auto_tag! unless video.metadata_extracted
    end
    
    # Update source statistics
    InternationalSource.active.find_each do |source|
      source.update(
        metadata: source.metadata.merge(
          'video_count' => source.videos.count,
          'last_stats_update' => Time.current.iso8601
        )
      )
    end
  RUBY
end

# ============================================================================
# NOTES
# ============================================================================
#
# After editing this file, deploy to cron with:
#   whenever --update-crontab --set environment=production
#
# To see what will be generated:
#   whenever
#
# To clear all whenever jobs:
#   whenever --clear-crontab
#
# View current crontab:
#   crontab -l
