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

  # Scrape a specific channel by ID
  def scrape_channel(channel_id, days_back: 30)
    Rails.logger.info "[YoutubeScraper] Scraping channel #{channel_id} (#{days_back} days back)"
    
    # Get channel info
    channel_response = youtube.list_channels('snippet,contentDetails', id: channel_id)
    return [] if channel_response.items.empty?

    channel = channel_response.items.first
    source = find_or_create_source(channel)

    # Get uploads playlist ID
    uploads_playlist_id = channel.content_details.related_playlists.uploads
    
    # Get recent videos from uploads playlist
    videos = fetch_playlist_videos(uploads_playlist_id, days_back: days_back)
    
    # Filter for carom-related videos and save
    carom_videos = videos.select { |v| carom_related?(v) }
    saved_count = save_videos(carom_videos, source)
    
    source.mark_scraped!
    
    Rails.logger.info "[YoutubeScraper] Saved #{saved_count} carom videos from #{carom_videos.size} candidates"
    saved_count
  end

  # Scrape all known YouTube channels
  def scrape_all_known_channels(days_back: 30)
    total_saved = 0
    
    InternationalSource::KNOWN_YOUTUBE_CHANNELS.each do |key, data|
      # Extract channel ID from URL or use directly
      channel_id = extract_channel_id(data[:base_url])
      next if channel_id.blank?
      
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
    elsif url.match(%r{youtube\.com/@([^/]+)})
      # Handle @username format - need to resolve to channel ID
      username = Regexp.last_match(1)
      resolve_username_to_channel_id(username)
    elsif url.match(/^UC/)
      # Direct channel ID
      url
    end
  end

  # Resolve @username to channel ID
  def resolve_username_to_channel_id(username)
    response = youtube.list_channels('id', for_username: username)
    response.items.first&.id
  rescue StandardError => e
    Rails.logger.error "[YoutubeScraper] Error resolving username #{username}: #{e.message}"
    nil
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
    
    loop do
      response = youtube.list_playlist_items(
        'snippet,contentDetails',
        playlist_id: playlist_id,
        max_results: 50,
        page_token: next_page_token
      )
      
      response.items.each do |item|
        published_at = item.snippet.published_at
        break if published_at < cutoff_date
        
        videos << item
      end
      
      next_page_token = response.next_page_token
      last_video_date = videos.last&.snippet&.published_at
      break if next_page_token.nil? || (last_video_date && last_video_date < cutoff_date)
    end
    
    # Get full video details
    return [] if videos.empty?
    
    video_ids = videos.map { |v| v.snippet.resource_id.video_id }.compact
    videos_response = youtube.list_videos('snippet,contentDetails,statistics', id: video_ids.join(','))
    
    videos_response.items
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
