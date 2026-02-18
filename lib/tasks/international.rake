# frozen_string_literal: true

namespace :international do
  desc 'Find YouTube channel ID from handle or username'
  task :find_channel_id, [:handle] => :environment do |_t, args|
    handle = args[:handle]
    
    if handle.blank?
      puts "Usage: rails international:find_channel_id[@handle]"
      puts "Example: rails international:find_channel_id[kozoom]"
      next
    end
    
    scraper = YoutubeScraper.new
    
    # Try search API to find channel
    puts "Searching for channel: #{handle}..."
    
    begin
      response = scraper.youtube.list_searches(
        'snippet',
        q: handle,
        type: 'channel',
        max_results: 5
      )
      
      if response.items.any?
        puts "\nFound #{response.items.size} channels:"
        response.items.each_with_index do |item, idx|
          puts "\n#{idx + 1}. #{item.snippet.title}"
          puts "   Channel ID: #{item.snippet.channel_id}"
          puts "   Description: #{item.snippet.description&.truncate(100)}"
        end
      else
        puts "No channels found for: #{handle}"
      end
    rescue => e
      puts "Error: #{e.message}"
    end
  end
  
  desc 'Test YouTube API access'
  task test_api: :environment do
    scraper = YoutubeScraper.new
    
    puts "\n=== Testing YouTube API Access ===\n"
    if scraper.test_api_access
      puts "\n✅ YouTube API is working correctly!"
    else
      puts "\n❌ YouTube API test failed - check logs above"
    end
  end
  
  desc 'Test scraping a specific channel'
  task :test_channel, [:channel_id, :days_back] => :environment do |_t, args|
    channel_id = args[:channel_id]
    days_back = (args[:days_back] || 3).to_i
    
    if channel_id.blank?
      puts "Usage: rails international:test_channel[CHANNEL_ID,days_back]"
      puts "Example: rails international:test_channel[UCOwcct1FjXWzlvmQxaR4Y8Q,7]"
      next
    end
    
    puts "Testing channel: #{channel_id}"
    puts "Days back: #{days_back}"
    puts ""
    
    scraper = YoutubeScraper.new
    count = scraper.scrape_channel(channel_id, days_back: days_back)
    
    puts "\n✅ Scraped #{count} videos"
    
    if count > 0
      puts "\nLatest videos:"
      InternationalVideo.where('created_at > ?', 1.minute.ago).limit(5).each do |video|
        puts "  - #{video.title}"
        puts "    Published: #{video.published_at}"
        puts "    Duration: #{video.duration_formatted}"
      end
    end
  end
  
  desc 'Scrape all known YouTube channels'
  task :scrape_all, [:days_back] => :environment do |_t, args|
    days_back = (args[:days_back] || 7).to_i
    
    puts "Scraping all known channels (#{days_back} days back)..."
    ScrapeYoutubeJob.perform_now(days_back: days_back)
  end
  
  desc 'Show statistics'
  task stats: :environment do
    puts "\n=== International Extension Statistics ===\n"
    puts "Sources: #{InternationalSource.count}"
    puts "Tournaments: #{InternationalTournament.count}"
    puts "Videos: #{InternationalVideo.count}"
    puts "  - Processed: #{InternationalVideo.processed.count}"
    puts "  - Unprocessed: #{InternationalVideo.unprocessed.count}"
    puts "Results: #{InternationalResult.count}"
    puts "Participations: #{InternationalParticipation.count}"
    puts ""
    
    if InternationalVideo.any?
      puts "Latest 5 videos:"
      InternationalVideo.recent.limit(5).each do |video|
        puts "  - #{video.title[0..70]}..."
        puts "    #{video.international_source.name} | #{video.published_at&.strftime('%Y-%m-%d')}"
      end
    end
  end

  desc 'Discover tournaments from existing videos'
  task discover_tournaments: :environment do
    puts "\n=== Tournament Discovery ==="
    service = TournamentDiscoveryService.new
    result = service.discover_from_videos
    
    puts "\nDiscovered Tournaments:"
    result[:tournaments].each do |tournament|
      puts "  #{tournament.name}"
      puts "    Type: #{tournament.tournament_type}"
      puts "    Discipline: #{tournament.discipline&.name}"
      puts "    Dates: #{tournament.start_date&.strftime('%Y-%m-%d')} - #{tournament.end_date&.strftime('%Y-%m-%d')}"
      puts "    Videos: #{tournament.international_videos.count}"
      puts ""
    end
    
    puts "Summary:"
    puts "  Tournaments created/updated: #{result[:tournaments].size}"
    puts "  Videos assigned: #{result[:videos_assigned]}"
  end

  desc 'Translate video titles to English'
  task :translate_videos, [:limit] => :environment do |_t, args|
    limit = (args[:limit] || 100).to_i
    
    puts "\n=== Video Translation ==="
    puts "Translating up to #{limit} videos..."
    
    service = VideoTranslationService.new
    
    unless service.translator
      puts "ERROR: Google Translate API not configured!"
      puts "Please add your API key to Rails credentials:"
      puts "  rails credentials:edit"
      puts "  google:"
      puts "    translate_api_key: YOUR_KEY_HERE"
      next
    end
    
    # Get untranslated videos (prioritize non-English)
    videos = InternationalVideo.where("metadata->>'translated_title' IS NULL")
                               .order(published_at: :desc)
                               .limit(limit)
    
    if videos.empty?
      puts "No videos to translate!"
      next
    end
    
    puts "Found #{videos.size} videos to translate"
    
    count = service.translate_batch(videos, target_language: 'en')
    
    puts "\nTranslation complete!"
    puts "  Videos translated: #{count}"
    puts "  Failed: #{videos.size - count}"
    
    # Show sample translations
    puts "\nSample translations:"
    InternationalVideo.where("metadata->>'translated_title' IS NOT NULL")
                     .order(updated_at: :desc)
                     .limit(5)
                     .each do |v|
      puts "  Original: #{v.title[0..60]}"
      puts "  Translated: #{v.metadata['translated_title'][0..60]}"
      puts ""
    end
  end

  desc 'Process all unprocessed videos (metadata extraction)'
  task process_all_videos: :environment do
    puts "\n=== Processing All Unprocessed Videos ==="
    
    total_unprocessed = InternationalVideo.unprocessed.count
    puts "Unprocessed videos: #{total_unprocessed}"
    
    if total_unprocessed.zero?
      puts "All videos already processed!"
      next
    end
    
    processed_total = 0
    batch_size = 50
    
    while InternationalVideo.unprocessed.any?
      puts "\nProcessing batch #{(processed_total / batch_size) + 1}..."
      ProcessUnprocessedVideosJob.perform_now
      
      processed_total += batch_size
      remaining = InternationalVideo.unprocessed.count
      
      puts "  Processed: #{processed_total}"
      puts "  Remaining: #{remaining}"
      
      break if remaining.zero?
    end
    
    puts "\n✅ All videos processed!"
    puts "Total processed: #{processed_total}"
  end

  desc 'Daily automated scrape (run via cron)'
  task daily_scrape: :environment do
    puts "\n=== Daily International Scrape ==="
    result = DailyInternationalScrapeJob.perform_now(days_back: 3)
    
    puts "\nResults:"
    puts "  Videos scraped: #{result[:scraped]}"
    puts "  Videos processed: #{result[:processed]}"
    puts "  Tournaments discovered: #{result[:tournaments]}"
    puts "  Titles translated: #{result[:translated]}"
    
    puts "\n✅ Daily scrape complete!"
  end

  desc 'Scrape official UMB tournament data'
  task scrape_umb: :environment do
    puts "\n=== UMB Tournament Scraper ==="
    puts "Fetching official tournament data from UMB..."
    
    scraper = UmbScraper.new
    count = scraper.scrape_future_tournaments
    
    if count > 0
      puts "\n✅ Success!"
      puts "  Tournaments scraped: #{count}"
      
      puts "\nOfficial UMB Tournaments:"
      InternationalTournament.joins(:international_source)
                            .where(international_sources: { source_type: 'umb' })
                            .order(start_date: :asc)
                            .each do |t|
        puts "  #{t.name}"
        puts "    Date: #{t.date_range}"
        puts "    Location: #{t.location || 'TBA'}"
        puts "    Discipline: #{t.discipline.name}"
        puts ""
      end
    else
      puts "\n⚠️ No tournaments found or scraping failed"
      puts "Check logs for details"
    end
  end

  desc 'Full pipeline: scrape → process → discover tournaments → translate'
  task :full_pipeline, [:days_back] => :environment do |_t, args|
    days_back = (args[:days_back] || 7).to_i
    
    puts "\n" + "=" * 80
    puts "INTERNATIONAL CONTENT PIPELINE"
    puts "=" * 80
    
    # Step 1: Scrape
    puts "\n[1/4] Scraping videos (#{days_back} days back)..."
    scraped = ScrapeYoutubeJob.perform_now(days_back: days_back)
    puts "  Scraped: #{scraped} videos"
    
    # Step 2: Process metadata
    puts "\n[2/4] Processing video metadata..."
    unprocessed = InternationalVideo.unprocessed.count
    puts "  Unprocessed: #{unprocessed}"
    
    processed_count = 0
    while InternationalVideo.unprocessed.any? && processed_count < 500
      ProcessUnprocessedVideosJob.perform_now
      processed_count += 50
    end
    puts "  Processed: #{processed_count}"
    
    # Step 3: Discover tournaments
    puts "\n[3/4] Discovering tournaments..."
    service = TournamentDiscoveryService.new
    result = service.discover_from_videos
    puts "  Tournaments: #{result[:tournaments].size}"
    puts "  Videos assigned: #{result[:videos_assigned]}"
    
    # Step 4: Translate (sample)
    puts "\n[4/4] Translating titles (first 50)..."
    translate_service = VideoTranslationService.new
    if translate_service.translator
      videos_to_translate = InternationalVideo.where("metadata->>'translated_title' IS NULL")
                                             .where.not("metadata->>'players' IS NULL")
                                             .limit(50)
      translated = translate_service.translate_batch(videos_to_translate)
      puts "  Translated: #{translated}"
    else
      puts "  Translation API not configured, skipping"
    end
    
    # Final stats
    puts "\n" + "=" * 80
    puts "PIPELINE COMPLETE"
    puts "=" * 80
    puts "Total videos: #{InternationalVideo.count}"
    puts "Total tournaments: #{InternationalTournament.count}"
    puts "Processed videos: #{InternationalVideo.processed.count}"
    puts "Videos with players: #{InternationalVideo.where("metadata->>'players' IS NOT NULL").count}"
  end
end
