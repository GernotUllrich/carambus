# frozen_string_literal: true

# Daily scheduled job to scrape, process, and maintain international content
# Run daily via cron/whenever: rails international:daily_scrape
class DailyInternationalScrapeJob < ApplicationJob
  queue_as :low_priority

  def perform(days_back: 3)
    Rails.logger.info "[DailyInternationalScrape] Starting daily scrape (days_back: #{days_back})"
    
    # Step 1: Scrape new videos
    scraped_count = ScrapeYoutubeJob.perform_now(days_back: days_back)
    Rails.logger.info "[DailyInternationalScrape] Scraped #{scraped_count} videos"
    
    # Step 2: Process metadata for unprocessed videos (auto-tagging)
    process_count = 0
    max_to_process = 200 # Process up to 200 videos per day
    
    videos_to_process = Video.youtube.where(metadata_extracted: false).limit(max_to_process)
    videos_to_process.each do |video|
      video.auto_tag!
      process_count += 1
    end
    Rails.logger.info "[DailyInternationalScrape] Auto-tagged #{process_count} videos"
    
    # Step 3: Discover new tournaments (if service exists)
    tournament_count = 0
    if defined?(TournamentDiscoveryService)
      discovery_service = TournamentDiscoveryService.new
      discovery_result = discovery_service.discover_from_videos
      tournament_count = discovery_result[:tournaments].size
      Rails.logger.info "[DailyInternationalScrape] Discovered #{tournament_count} tournaments"
    end
    
    # Step 4: Translate new videos (limit to 100 per day to save costs)
    translated_count = 0
    if defined?(VideoTranslationService)
      translation_service = VideoTranslationService.new
      if translation_service.translator
        videos_to_translate = Video.youtube
                                   .where("data->>'translated_title' IS NULL")
                                   .order(published_at: :desc)
                                   .limit(100)
        
        if videos_to_translate.any?
          translated_count = translation_service.translate_batch(videos_to_translate, target_language: 'en')
          Rails.logger.info "[DailyInternationalScrape] Translated #{translated_count} video titles"
        end
      end
    end
    
    # Step 5: Update source statistics
    InternationalSource.active.each do |source|
      video_count = source.videos.count
      source.update(
        metadata: source.metadata.merge(
          'video_count' => video_count,
          'last_stats_update' => Time.current.iso8601
        )
      )
    end
    
    Rails.logger.info "[DailyInternationalScrape] Daily scrape complete!"
    
    {
      scraped: scraped_count,
      processed: process_count,
      tournaments: tournament_count,
      translated: translated_count
    }
  end
end
