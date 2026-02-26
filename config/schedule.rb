# frozen_string_literal: true

# Whenever schedule configuration
# Learn more: https://github.com/javan/whenever
#
# Deploy with: whenever --update-crontab
# Clear with: whenever --clear-crontab
# View cron: crontab -l

# Capistrano passes variables via the `--set` option (see config/deploy.rb).
# We provide fallback defaults for local execution without Capistrano.
@environment  ||= ENV.fetch("RAILS_ENV", "production")
@path         ||= "/var/www/carambus_api/current"
@scenarioname ||= "carambus_api"
@location_id  ||= "1"

set :output, "log/cron.log"
set :environment, @environment
set :path, @path

# Use absolute paths for commands with proper rbenv
job_type :rake, "cd :path && RAILS_ENV=:environment /var/www/.rbenv/shims/bundle exec rake :task :output"
job_type :runner,
         "cd :path && RAILS_ENV=:environment /var/www/.rbenv/shims/bundle exec rails runner -e :environment ':task' :output"

# ============================================================================
# INTERNATIONAL CONTENT SCRAPING
# ============================================================================

# Daily YouTube scraping + auto-tagging + processing
# Runs at 2:00 AM every day
# - Scrapes all 19 YouTube channels (last 3 days)
# - Auto-tags videos (players, content type, quality)
# - Discovers tournaments
# - Translates titles (if configured)
every 1.day, at: "2:00 am", roles: [:app] do
  rake "international:daily_scrape"
end

# Daily UMB tournament data scraping & maintenance
# Runs at 3:00 AM every day
# - Scrapes future tournaments
# - Finds new tournament IDs
# - Auto-fixes missing organizers (ensures all have UMB as organizer)
# - Updates recent tournaments with results
every 1.day, at: "3:00 am", roles: [:app] do
  rake "umb:update"
end

# Weekly cleanup: Process all remaining untagged videos
# Runs every Sunday at 5:00 AM (after daily_update at 4am)
# - Ensures no videos are left unprocessed
# - Catches any videos that were skipped during daily runs
every :sunday, at: "5:00 am", roles: [:app] do
  rake "international:process_untagged_videos"
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
# Runs every Sunday at 6:00 AM
every :sunday, at: "6:00 am", roles: [:app] do
  rake "scrape:cleanup_logs[90]"
end

# Monthly: Update video statistics and tag counts
# Runs on the 1st of each month at 7:00 AM
every "0 7 1 * *", roles: [:app] do
  rake "international:update_statistics"
end

# ============================================================================
# LOCAL SERVER TASKS
# ============================================================================

# Every hour, or any desired interval for local sync tasks
every 1.hour, roles: [:local] do
  # Updates local data from the central API server.
  # the scenario and location are passed via Capistrano variables.
  rake "carambus:retrieve_updates[#{@location_id}]"
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
