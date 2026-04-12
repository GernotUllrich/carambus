# frozen_string_literal: true

# Background job for scraping UMB tournament archive
class ScrapeUmbArchiveJob < ApplicationJob
  queue_as :default
  
  def perform(start_id: 1, end_id: 500, batch_size: 50)
    Rails.logger.info "[ScrapeUmbArchiveJob] Starting with start_id=#{start_id}, end_id=#{end_id}, batch_size=#{batch_size}"

    scraper = UmbScraper.new
    count = scraper.scrape_tournament_archive(
      start_id: start_id,
      end_id: end_id,
      batch_size: batch_size
    )
    
    Rails.logger.info "[ScrapeUmbArchiveJob] Completed. Saved #{count} tournaments."
    count
  rescue StandardError => e
    Rails.logger.error "[ScrapeUmbArchiveJob] Failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
