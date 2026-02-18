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
end
