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
end
