# frozen_string_literal: true

# Background job to scrape UMB tournament data
class ScrapeUmbJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[ScrapeUmbJob] Starting UMB scraping"
    
    scraper = UmbScraper.new
    
    # Scrape future tournaments
    count = scraper.scrape_future_tournaments
    
    Rails.logger.info "[ScrapeUmbJob] UMB scraping complete: #{count} tournaments"
    count
  end
end
