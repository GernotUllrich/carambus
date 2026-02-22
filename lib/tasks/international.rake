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
      Video.where('created_at > ?', 1.minute.ago).limit(5).each do |video|
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

    youtube_videos = Video.youtube
    puts "Videos: #{youtube_videos.count}"
    puts "  - Tagged: #{youtube_videos.where(metadata_extracted: true).count}"
    puts "  - Untagged: #{youtube_videos.where(metadata_extracted: false).count}"

    if defined?(InternationalResult)
      puts "Results: #{InternationalResult.count}"
      puts "Participations: #{InternationalParticipation.count}"
    end
    puts ""

    if youtube_videos.any?
      puts "Latest 5 videos:"
      youtube_videos.order(published_at: :desc).limit(5).each do |video|
        puts "  - #{video.title[0..70]}..."
        puts "    #{video.international_source.name} | #{video.published_at&.strftime('%Y-%m-%d')}"
      end
    end

    puts "\nTag Statistics:"
    tag_counts = Video.youtube
                     .where.not("data->'tags' IS NULL")
                     .pluck(Arel.sql("jsonb_array_elements_text(data->'tags')"))
                     .group_by(&:itself)
                     .transform_values(&:count)
                     .sort_by { |_k, v| -v }
                     .first(10)

    tag_counts.each do |tag, count|
      puts "  #{tag}: #{count}"
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
    videos = Video.where("metadata->>'translated_title' IS NULL")
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
    Video.where("metadata->>'translated_title' IS NOT NULL")
                     .order(updated_at: :desc)
                     .limit(5)
                     .each do |v|
      puts "  Original: #{v.title[0..60]}"
      puts "  Translated: #{v.metadata['translated_title'][0..60]}"
      puts ""
    end
  end

  desc 'Process all videos (auto-tagging)'
  task process_all_videos: :environment do
    puts "\n=== Auto-Tagging All YouTube Videos ==="

    total_videos = Video.youtube.count
    puts "Total YouTube videos: #{total_videos}"

    if total_videos.zero?
      puts "No videos found!"
      next
    end

    tagged_count = 0

    Video.youtube.find_each do |video|
      video.auto_tag!
      tagged_count += 1
      print '.' if tagged_count % 50 == 0
    end

    puts "\n\n✅ All videos tagged!"
    puts "Total processed: #{tagged_count}"
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

  desc 'Clean up malformed UMB tournament entries'
  task cleanup_umb_fragments: :environment do
    puts "\n=== UMB Tournament Cleanup ==="
    puts "Finding malformed tournament entries..."

    umb_source = InternationalSource.find_by(source_type: 'umb')
    unless umb_source
      puts "No UMB source found!"
      next
    end

    # Find entries that are ONLY date fragments (not tournament names that contain dates)
    # Match patterns like: "26 -", "- 01", "05 - 11" but NOT "World Cup 3-Cushion"
    date_only = InternationalTournament.where(international_source: umb_source)
                                      .where("name ~ ?", '^-?\s*\d{1,2}\s*-\s*\d{0,2}\s*$')

    # Find entries that are just "Date", "Tournament" etc
    meta_labels = InternationalTournament.where(international_source: umb_source)
                                        .where("name IN ('Date', 'Tournament', 'Type', 'Organization', 'Place')")

    # Find entries with extremely malformed names (huge text blocks)
    huge_names = InternationalTournament.where(international_source: umb_source)
                                       .where("LENGTH(name) > 200")

    all_bad = (date_only.to_a + meta_labels.to_a + huge_names.to_a).uniq

    if all_bad.empty?
      puts "✅ No malformed entries found!"
      next
    end

    puts "\nFound #{all_bad.size} malformed entries:"
    all_bad.each do |t|
      preview = t.name.length > 80 ? "#{t.name[0..77]}..." : t.name
      puts "  - '#{preview}' (#{t.location})"
    end

    puts "\nDeleting malformed entries..."
    deleted_count = 0
    all_bad.each do |t|
      if t.destroy
        deleted_count += 1
      else
        puts "  Failed to delete: #{t.name}"
      end
    end

    puts "\n✅ Cleanup complete!"
    puts "  Deleted: #{deleted_count} entries"
    puts "  Remaining UMB tournaments: #{InternationalTournament.where(international_source: umb_source).count}"
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
    unprocessed = Video.unprocessed.count
    puts "  Unprocessed: #{unprocessed}"

    processed_count = 0
    while Video.unprocessed.any? && processed_count < 500
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
      videos_to_translate = Video.where("metadata->>'translated_title' IS NULL")
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
    puts "Total videos: #{Video.count}"
    puts "Total tournaments: #{InternationalTournament.count}"
    puts "Processed videos: #{Video.processed.count}"
    puts "Videos with players: #{Video.where("metadata->>'players' IS NOT NULL").count}"
  end

  desc 'Process all untagged videos (for cron)'
  task process_untagged_videos: :environment do
    puts "\n=== Processing Untagged Videos ==="

    untagged = Video.youtube.where(metadata_extracted: false)
    count = untagged.count

    if count.zero?
      puts "All videos already tagged!"
      next
    end

    puts "Found #{count} untagged videos"
    processed = 0

    untagged.find_each do |video|
      video.auto_tag!
      processed += 1
      print "." if processed % 10 == 0
    end

    puts "\n✅ Processed #{processed} videos"
  end

  desc 'Update video statistics and tag counts (for cron)'
  task update_statistics: :environment do
    puts "\n=== Updating Video Statistics ==="

    # Recalculate all tag counts
    puts "Recalculating tag counts..."
    Video.youtube.where(metadata_extracted: false).find_each do |video|
      video.auto_tag!
    end

    # Update source statistics
    puts "Updating source statistics..."
    InternationalSource.active.find_each do |source|
      video_count = source.videos.count
      source.update(
        metadata: source.metadata.merge(
          'video_count' => video_count,
          'last_stats_update' => Time.current.iso8601
        )
      )
      puts "  #{source.name}: #{video_count} videos"
    end

    puts "✅ Statistics updated"
  end
end
