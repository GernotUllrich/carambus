# frozen_string_literal: true

namespace :youtube do
  desc 'Test YouTube API access'
  task test: :environment do
    scraper = YoutubeScraper.new
    
    puts "\n=== Testing YouTube API Access ===\n"
    if scraper.test_api_access
      puts "\n✅ YouTube API is working correctly!"
    else
      puts "\n❌ YouTube API test failed - check logs above"
    end
  end

  desc 'Find YouTube channel ID from handle or username'
  task :find_channel, [:handle] => :environment do |_t, args|
    handle = args[:handle]
    
    if handle.blank?
      puts "Usage: rake youtube:find_channel[@username]"
      puts "Example: rake youtube:find_channel[@kozoom]"
      exit 1
    end
    
    scraper = YoutubeScraper.new
    
    begin
      # Remove @ if present
      handle = handle.gsub('@', '')
      
      # Try search
      response = scraper.youtube.list_searches(
        'snippet',
        q: handle,
        type: 'channel',
        max_results: 5
      )
      
      if response.items.any?
        puts "\nFound channels:"
        response.items.each_with_index do |item, i|
          puts "\n#{i + 1}. #{item.snippet.title}"
          puts "   Channel ID: #{item.snippet.channel_id}"
          puts "   Description: #{item.snippet.description[0..100]}..."
        end
      else
        puts "\n❌ No channels found for '#{handle}'"
      end
    rescue StandardError => e
      puts "\n❌ Error: #{e.message}"
    end
  end

  desc 'Scrape a specific YouTube channel'
  task :scrape_channel, [:channel_id, :days_back] => :environment do |_t, args|
    channel_id = args[:channel_id]
    days_back = (args[:days_back] || 30).to_i
    
    if channel_id.blank?
      puts "Usage: rake youtube:scrape_channel[CHANNEL_ID,DAYS_BACK]"
      puts "Example: rake youtube:scrape_channel[UCxxxxx,30]"
      exit 1
    end
    
    puts "\n" + "="*80
    puts "SCRAPING YOUTUBE CHANNEL"
    puts "="*80
    puts "Channel ID: #{channel_id}"
    puts "Days back: #{days_back}"
    puts "="*80 + "\n"
    
    scraper = YoutubeScraper.new
    count = scraper.scrape_channel(channel_id, days_back: days_back)
    
    puts "\n✅ Scraped #{count} new videos"
  end

  desc 'Scrape all known YouTube channels'
  task :scrape_all, [:days_back] => :environment do |_t, args|
    days_back = (args[:days_back] || 7).to_i
    
    puts "\n" + "="*80
    puts "SCRAPING ALL KNOWN YOUTUBE CHANNELS"
    puts "="*80
    puts "Days back: #{days_back}"
    puts "="*80 + "\n"
    
    ScrapeYoutubeJob.perform_now(days_back: days_back)
  end

  desc 'Search YouTube for carom videos'
  task :search, [:max_results] => :environment do |_t, args|
    max_results = (args[:max_results] || 50).to_i
    
    puts "\n" + "="*80
    puts "SEARCHING YOUTUBE FOR CAROM VIDEOS"
    puts "="*80
    puts "Max results: #{max_results}"
    puts "="*80 + "\n"
    
    scraper = YoutubeScraper.new
    count = scraper.search_carom_videos(max_results: max_results)
    
    puts "\n✅ Found and saved #{count} carom videos"
  end

  desc 'Show YouTube scraping statistics'
  task stats: :environment do
    puts "\n" + "="*80
    puts "YOUTUBE SCRAPING STATISTICS"
    puts "="*80
    
    total = Video.count
    youtube = Video.youtube.count
    
    puts "\nTotal videos:        #{total}"
    puts "YouTube videos:      #{youtube} (#{(youtube.to_f / total * 100).round(1)}%)"
    
    # By source
    puts "\nTop YouTube sources:"
    Video.youtube
         .joins(:international_source)
         .group('international_sources.name')
         .count
         .sort_by { |_, count| -count }
         .first(10)
         .each do |source, count|
           puts "  #{source.ljust(30)} #{count}"
         end
    
    # Recent
    recent = Video.youtube.where('created_at >= ?', 7.days.ago).count
    puts "\nNew videos (last 7 days): #{recent}"
    
    # Unassigned
    unassigned = Video.youtube.unassigned.count
    puts "Unassigned videos:        #{unassigned} (#{(unassigned.to_f / youtube * 100).round(1)}%)"
    
    puts "\n" + "="*80
  end

  desc 'List all known YouTube channels'
  task list_channels: :environment do
    puts "\n" + "="*80
    puts "KNOWN YOUTUBE CHANNELS"
    puts "="*80
    
    InternationalSource::KNOWN_YOUTUBE_CHANNELS.each_with_index do |(key, data), i|
      puts "\n#{i + 1}. #{data[:name]}"
      puts "   Key: #{key}"
      puts "   Channel ID: #{data[:channel_id]}"
      puts "   URL: #{data[:url]}" if data[:url]
      
      # Check if scraped
      source = InternationalSource.find_by(name: data[:name])
      if source
        videos_count = Video.where(international_source: source).count
        last_scraped = source.last_scraped_at&.strftime('%Y-%m-%d %H:%M') || 'Never'
        puts "   Status: ✅ Found (#{videos_count} videos, last scraped: #{last_scraped})"
      else
        puts "   Status: ⚠️  Not yet scraped"
      end
    end
    
    puts "\n" + "="*80
    puts "Total channels: #{InternationalSource::KNOWN_YOUTUBE_CHANNELS.size}"
    puts "="*80
  end
end
