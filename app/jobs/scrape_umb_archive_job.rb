# frozen_string_literal: true

# Background job for scraping UMB tournament archive
class ScrapeUmbArchiveJob < ApplicationJob
  queue_as :default
  
  def perform(discipline: '3-Cushion', year: nil, event_type: nil)
    Rails.logger.info "[ScrapeUmbArchiveJob] Starting with discipline=#{discipline}, year=#{year}, event_type=#{event_type}"
    
    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      discipline: discipline,
      year: year,
      event_type: event_type
    )
    
    Rails.logger.info "[ScrapeUmbArchiveJob] Completed. Saved #{count} tournaments."
    count
  rescue StandardError => e
    Rails.logger.error "[ScrapeUmbArchiveJob] Failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
