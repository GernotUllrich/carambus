# frozen_string_literal: true

# Daily scheduled job to scrape, process, and maintain international content
# Run daily via cron/whenever: rails international:daily_scrape
class DailyInternationalScrapeJob < ApplicationJob
  queue_as :low_priority

  def perform(days_back: 3)
    Rails.logger.info "[DailyInternationalScrape] Starting daily scrape (days_back: #{days_back})"

    # Step 1: Scrape new videos (YouTube, SoopLive, and Kozoom)
    begin
      scraped_count = ScrapeYoutubeJob.perform_now(days_back: days_back)
      Rails.logger.info "[DailyInternationalScrape] Scraped #{scraped_count} YouTube videos"
    rescue StandardError => e
      Rails.logger.error "[DailyInternationalScrape] Error scraping YouTube: #{e.message}"
      scraped_count = 0
    end

    soop_count = 0
    InternationalSource::KNOWN_FIVESIX_CHANNELS.each_key do |channel_id|
      scraper = SoopliveScraper.new
      soop_count += scraper.scrape_channel(channel_id, days_back: days_back)
    rescue StandardError => e
      Rails.logger.error "[DailyInternationalScrape] Error scraping SoopLive #{channel_id}: #{e.message}"
    end
    scraped_count += soop_count
    Rails.logger.info "[DailyInternationalScrape] Scraped #{soop_count} SoopLive videos"

    kozoom_count = 0
    begin
      email = Rails.application.credentials.dig(:kozoom, :email)
      password = Rails.application.credentials.dig(:kozoom, :password)

      if email.present? && password.present?
        kozoom_scraper = KozoomScraper.new(email: email, password: password)
        kozoom_script_days = [days_back, 7].max
        kozoom_count = kozoom_scraper.scrape(days_back: kozoom_script_days)
      else
        Rails.logger.warn "[DailyInternationalScrape] Kozoom credentials not configured in Rails.application.credentials"
      end
    rescue StandardError => e
      Rails.logger.error "[DailyInternationalScrape] Error scraping Kozoom: #{e.message}"
    end
    scraped_count += kozoom_count
    Rails.logger.info "[DailyInternationalScrape] Scraped #{kozoom_count} Kozoom videos"

    # Step 2: Process metadata for unprocessed videos (auto-tagging)
    process_count = 0
    max_to_process = 200 # Process up to 200 videos per day

    videos_to_process = Video.supported_platforms.where(metadata_extracted: false).limit(max_to_process)
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
        videos_to_translate = Video.supported_platforms
                                   .where("data->>'translated_title' IS NULL")
                                   .order(published_at: :desc)
                                   .limit(100)

        if videos_to_translate.any?
          translated_count = translation_service.translate_batch(videos_to_translate, target_language: "en")
          Rails.logger.info "[DailyInternationalScrape] Translated #{translated_count} video titles"
        end
      end
    end

    # Step 5: Update source statistics
    InternationalSource.active.each do |source|
      video_count = source.videos.count

      # Ensure metadata is a hash (handle both Hash and String cases)
      current_metadata = case source.metadata
                         when Hash
                           source.metadata
                         when String
                           begin
                             JSON.parse(source.metadata)
                           rescue StandardError
                             {}
                           end
                         else
                           {}
                         end

      source.update(
        metadata: current_metadata.merge(
          "video_count" => video_count,
          "last_stats_update" => Time.current.iso8601
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
