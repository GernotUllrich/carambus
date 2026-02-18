# frozen_string_literal: true

require 'google/apis/youtube_v3'

# Service to scrape YouTube channels for carom billiard videos
# Uses YouTube Data API v3
#
# Setup:
# 1. Get API key from Google Cloud Console
# 2. Set environment variable: YOUTUBE_API_KEY
#
# Usage:
#   scraper = YoutubeScraper.new
#   scraper.scrape_channel('UCxxxxx', days_back: 30)
#   scraper.scrape_all_known_channels
class YoutubeScraper
  QUOTA_PER_VIDEO = 3 # List operation costs 1, videos.list costs 1, optional search costs 100
  QUOTA_LIMIT = 10_000 # Daily quota limit

  attr_reader :youtube, :source

  def initialize(source = nil)
    @youtube = Google::Apis::YoutubeV3::YouTubeService.new
    # Try credentials first, fallback to ENV
    @youtube.key = Rails.application.credentials.youtube_api_key || ENV['YOUTUBE_API_KEY']
    @source = source
    
    if @youtube.key.blank?
      raise 'YouTube API Key not found. Please set in credentials or YOUTUBE_API_KEY environment variable'
    end
  end

  # Test API access
  def test_api_access
    Rails.logger.info "[YoutubeScraper] Testing YouTube API access..."
    Rails.logger.info "[YoutubeScraper] API Key present: #{@youtube.key.present?}"
    Rails.logger.info "[YoutubeScraper] API Key (first 10 chars): #{@youtube.key[0..9]}..." if @youtube.key.present?
    
    # Try a simple API call
    response = youtube.list_channels('snippet', id: 'UC_x5XG1OV2P6uZZ5FSM9Ttw') # Google Developers channel
    
    if response&.items&.any?
      Rails.logger.info "[YoutubeScraper] ✅ API access successful!"
      Rails.logger.info "[YoutubeScraper] Test channel: #{response.items.first.snippet.title}"
      true
    else
      Rails.logger.error "[YoutubeScraper] ❌ API returned empty response"
      false
    end
  rescue Google::Apis::ClientError => e
    Rails.logger.error "[YoutubeScraper] ❌ YouTube API error: #{e.message}"
    Rails.logger.error "[YoutubeScraper] Status: #{e.status_code}"
    false
  rescue StandardError => e
    Rails.logger.error "[YoutubeScraper] ❌ Unexpected error: #{e.message}"
    false
  end

  # Scrape a specific channel by ID
  def scrape_channel(channel_id, days_back: 30)
    Rails.logger.info "[YoutubeScraper] Scraping channel #{channel_id} (#{days_back} days back)"
    
    # Get channel info
    channel_response = youtube.list_channels('snippet,contentDetails', id: channel_id)
    
    if channel_response.nil? || channel_response.items.nil? || channel_response.items.empty?
      Rails.logger.warn "[YoutubeScraper] No channel found for ID #{channel_id}"
      return 0
    end

    channel = channel_response.items.first
    source = find_or_create_source(channel)

    # Get uploads playlist ID
    uploads_playlist_id = channel.content_details.related_playlists.uploads
    
    # Get recent videos from uploads playlist
    videos = fetch_playlist_videos(uploads_playlist_id, days_back: days_back)
    
    Rails.logger.info "[YoutubeScraper] Found #{videos.size} total videos from channel"
    
    # Filter for carom-related videos and save
    carom_videos = videos.select { |v| carom_related?(v) }
    
    Rails.logger.info "[YoutubeScraper] Filtered to #{carom_videos.size} carom-related videos"
    
    saved_count = save_videos(carom_videos, source)
    
    source.mark_scraped!
    
    Rails.logger.info "[YoutubeScraper] Saved #{saved_count} carom videos (#{videos.size} total, #{carom_videos.size} carom-related)"
    saved_count
  rescue Google::Apis::ClientError => e
    Rails.logger.error "[YoutubeScraper] YouTube API error for channel #{channel_id}: #{e.message}"
    Rails.logger.error "[YoutubeScraper] Status: #{e.status_code}, Body: #{e.body}"
    0
  rescue StandardError => e
    Rails.logger.error "[YoutubeScraper] Unexpected error for channel #{channel_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    0
  end

  # Scrape all known YouTube channels
  def scrape_all_known_channels(days_back: 30)
    total_saved = 0
    
    InternationalSource::KNOWN_YOUTUBE_CHANNELS.each do |key, data|
      # Use channel_id directly from metadata
      channel_id = data[:channel_id]
      
      if channel_id.blank?
        Rails.logger.warn "[YoutubeScraper] No channel_id for #{key}, skipping"
        next
      end
      
      begin
        count = scrape_channel(channel_id, days_back: days_back)
        total_saved += count
      rescue StandardError => e
        Rails.logger.error "[YoutubeScraper] Error scraping channel #{key}: #{e.message}"
      end
      
      # Sleep to avoid rate limiting
      sleep 1
    end
    
    total_saved
  end

  # Search for carom billiard videos (uses more quota)
  def search_carom_videos(max_results: 50)
    Rails.logger.info "[YoutubeScraper] Searching for carom billiard videos (max: #{max_results})"
    
    search_query = '3-cushion OR carom OR dreiband'
    published_after = 30.days.ago.iso8601
    
    search_response = youtube.list_searches(
      'snippet',
      q: search_query,
      type: 'video',
      published_after: published_after,
      max_results: [max_results, 50].min,
      relevance_language: 'en',
      order: 'date'
    )
    
    video_ids = search_response.items.map(&:id).map(&:video_id).compact
    return [] if video_ids.empty?
    
    # Get full video details
    videos_response = youtube.list_videos('snippet,contentDetails,statistics', id: video_ids.join(','))
    videos = videos_response.items
    
    # Create generic source for search results
    source = InternationalSource.find_or_create_by!(
      name: 'YouTube Search',
      source_type: InternationalSource::YOUTUBE
    ) do |s|
      s.base_url = 'https://www.youtube.com'
      s.metadata = { key: 'search', priority: 3 }
    end
    
    saved_count = save_videos(videos, source)
    Rails.logger.info "[YoutubeScraper] Saved #{saved_count} videos from search"
    
    saved_count
  end

  private

  # Extract channel ID from various URL formats
  def extract_channel_id(url)
    return nil if url.blank?
    
    # Handle different YouTube URL formats
    if url.match(%r{youtube\.com/channel/([^/]+)})
      Regexp.last_match(1)
    elsif url.match(/^UC/)
      # Direct channel ID
      url
    else
      # For @username URLs, channel ID must be provided separately
      # Modern YouTube @handles don't work with for_username API
      nil
    end
  end

  # Find or create international source from channel
  def find_or_create_source(channel)
    InternationalSource.find_or_create_by!(
      name: channel.snippet.title,
      source_type: InternationalSource::YOUTUBE
    ) do |source|
      source.base_url = "https://www.youtube.com/channel/#{channel.id}"
      source.metadata = {
        channel_id: channel.id,
        description: channel.snippet.description&.truncate(500)
      }
    end
  end

  # Fetch videos from a playlist
  def fetch_playlist_videos(playlist_id, days_back: 30)
    cutoff_date = days_back.days.ago
    videos = []
    next_page_token = nil
    max_pages = (days_back / 30.0).ceil + 1 # Roughly 1 page per month
    pages_fetched = 0
    
    loop do
      response = youtube.list_playlist_items(
        'snippet,contentDetails',
        playlist_id: playlist_id,
        max_results: 50,
        page_token: next_page_token
      )
      
      pages_fetched += 1
      
      # Collect all items from this page
      page_videos = []
      response.items.each do |item|
        published_at = item.snippet.published_at
        if published_at >= cutoff_date
          page_videos << item
        end
      end
      
      videos.concat(page_videos)
      
      next_page_token = response.next_page_token
      
      # Stop if: no more pages, reached cutoff date, or fetched enough pages
      last_video_date = response.items.last&.snippet&.published_at
      break if next_page_token.nil?
      break if last_video_date && last_video_date < cutoff_date
      break if pages_fetched >= max_pages
    end
    
    Rails.logger.info "[YoutubeScraper] Fetched #{videos.size} videos from #{pages_fetched} pages (cutoff: #{cutoff_date})"
    
    # Get full video details
    return [] if videos.empty?
    
    video_ids = videos.map { |v| v.snippet.resource_id.video_id }.compact
    
    # YouTube API limits to 50 IDs per request, so batch them
    all_videos = []
    video_ids.each_slice(50) do |batch_ids|
      videos_response = youtube.list_videos('snippet,contentDetails,statistics', id: batch_ids.join(','))
      all_videos.concat(videos_response.items)
    end
    
    Rails.logger.info "[YoutubeScraper] Fetched full details for #{all_videos.size} videos"
    all_videos
  end

  # Check if video is carom-related
  def carom_related?(video)
    title = video.snippet.title || ''
    description = video.snippet.description || ''
    
    InternationalVideo.contains_carom_keywords?("#{title} #{description}")
  end

  # Save videos to database
  def save_videos(videos, source)
    saved_count = 0
    
    videos.each do |video|
      begin
        existing = InternationalVideo.find_by(external_id: video.id)
        
        if existing
          # Update statistics
          existing.update(
            view_count: video.statistics&.view_count,
            like_count: video.statistics&.like_count
          )
        else
          # Create new video
          duration_seconds = parse_duration(video.content_details.duration)
          
          international_video = InternationalVideo.create!(
            international_source: source,
            external_id: video.id,
            title: video.snippet.title,
            description: video.snippet.description,
            published_at: video.snippet.published_at,
            duration: duration_seconds,
            language: video.snippet.default_language || video.snippet.default_audio_language,
            thumbnail_url: video.snippet.thumbnails&.high&.url || video.snippet.thumbnails&.default&.url,
            view_count: video.statistics&.view_count,
            like_count: video.statistics&.like_count
          )
          
          # Auto-assign discipline if possible
          international_video.auto_assign_discipline!
          
          saved_count += 1
        end
      rescue StandardError => e
        Rails.logger.error "[YoutubeScraper] Error saving video #{video.id}: #{e.message}"
      end
    end
    
    saved_count
  end

  # Parse ISO 8601 duration to seconds
  def parse_duration(duration_string)
    return nil if duration_string.blank?
    
    # Parse PT1H2M10S format
    match = duration_string.match(/PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?/)
    return nil unless match
    
    hours = (match[1] || 0).to_i
    minutes = (match[2] || 0).to_i
    seconds = (match[3] || 0).to_i
    
    (hours * 3600) + (minutes * 60) + seconds
  end
end
