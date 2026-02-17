# frozen_string_literal: true

# Background job to scrape YouTube channels for carom billiard videos
# Runs daily via scheduled task
class ScrapeYoutubeJob < ApplicationJob
  queue_as :low_priority

  def perform(days_back: 7, channel_id: nil)
    Rails.logger.info "[ScrapeYoutubeJob] Starting YouTube scraping (days_back: #{days_back})"
    
    scraper = YoutubeScraper.new
    
    if channel_id.present?
      # Scrape specific channel
      count = scraper.scrape_channel(channel_id, days_back: days_back)
      Rails.logger.info "[ScrapeYoutubeJob] Scraped #{count} videos from channel #{channel_id}"
    else
      # Scrape all known channels
      count = scraper.scrape_all_known_channels(days_back: days_back)
      Rails.logger.info "[ScrapeYoutubeJob] Scraped #{count} videos from all channels"
    end
    
    # Process unprocessed videos
    ProcessUnprocessedVideosJob.perform_later
    
    count
  rescue StandardError => e
    Rails.logger.error "[ScrapeYoutubeJob] Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
