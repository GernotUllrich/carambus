# frozen_string_literal: true

require 'net/http'
require 'json'
require 'time'

# Service to scrape SoopLive (formerly AfreecaTV) channels for carom billiard videos
# Uses public SoopLive API
#
# Usage:
#   scraper = SoopliveScraper.new
#   scraper.scrape_channel('afbilliards4', days_back: 30)
#   scraper.scrape_all_known_channels
class SoopliveScraper
  attr_reader :source

  def initialize(source = nil)
    @source = source
  end

  # Scrape a specific channel by ID (username)
  def scrape_channel(channel_id, days_back: 30)
    Rails.logger.info "[SoopliveScraper] Scraping channel #{channel_id} (#{days_back} days back)"
    
    # Get or create source
    source = find_or_create_source(channel_id)

    videos = fetch_channel_videos(channel_id, days_back: days_back)
    
    Rails.logger.info "[SoopliveScraper] Found #{videos.size} total videos from channel #{channel_id}"
    
    # Filter for carom-related videos
    carom_videos = videos.select { |v| carom_related?(v) }
    
    Rails.logger.info "[SoopliveScraper] Filtered to #{carom_videos.size} carom-related videos"
    
    saved_count = save_videos(carom_videos, source)
    
    source.mark_scraped!
    
    Rails.logger.info "[SoopliveScraper] Saved #{saved_count} carom videos (#{videos.size} total, #{carom_videos.size} carom-related)"
    saved_count
  rescue StandardError => e
    Rails.logger.error "[SoopliveScraper] Unexpected error for channel #{channel_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    0
  end

  # Scrape all known SoopLive channels
  def scrape_all_known_channels(days_back: 30)
    total_saved = 0
    
    InternationalSource::KNOWN_FIVESIX_CHANNELS.each do |key, data|
      channel_id = data[:channel_id] || key
      
      begin
        count = scrape_channel(channel_id, days_back: days_back)
        total_saved += count
      rescue StandardError => e
        Rails.logger.error "[SoopliveScraper] Error scraping channel #{key}: #{e.message}"
      end
      
      sleep 1 # Avoid rate limiting
    end
    
    total_saved
  end

  private

  def find_or_create_source(channel_id)
    known = InternationalSource::KNOWN_FIVESIX_CHANNELS[channel_id]
    
    InternationalSource.find_or_create_by!(
      name: known&.dig(:name) || "SoopLive Channel (#{channel_id})",
      source_type: InternationalSource::FIVESIX
    ) do |source|
      source.base_url = known&.dig(:base_url) || "https://ch.sooplive.co.kr/#{channel_id}/vods"
      source.metadata = {
        channel_id: channel_id,
        description: known&.dig(:description) || "SOOP Live / AfreecaTV Channel for #{channel_id}"
      }
    end
  end

  def fetch_channel_videos(channel_id, days_back: 30)
    cutoff_date = days_back.days.ago
    videos = []
    page = 1
    per_page = 60
    
    loop do
      url = "https://chapi.sooplive.co.kr/api/#{channel_id}/vods/all/streamer?page=#{page}&per_page=#{per_page}&orderby=reg_date"
      
      response = fetch_json(url)
      break unless response && response['data'] && response['data'].is_a?(Array)
      
      items = response['data']
      break if items.empty?
      
      # Process items and check cutoff date
      page_videos = []
      oldest_date_in_page = nil
      
      items.each do |item|
        # reg_date format: "2025-02-13 04:20:37"
        published_at = parse_date(item['reg_date'])
        
        if published_at >= cutoff_date
          page_videos << item
        end
        oldest_date_in_page = published_at if oldest_date_in_page.nil? || published_at < oldest_date_in_page
      end
      
      videos.concat(page_videos)
      
      # Stop fetching if we've reached videos older than our cutoff date
      break if oldest_date_in_page && oldest_date_in_page < cutoff_date
      
      # Safety break just in case
      break if page > 20
      
      page += 1
      sleep 0.5
    end
    
    videos
  end

  def fetch_json(url)
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['Accept'] = 'application/json, text/plain, */*'
    request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
    request['Referer'] = 'https://www.sooplive.co.kr/'
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    else
      Rails.logger.warn "[SoopliveScraper] API request failed: #{response.code} #{response.message}"
      nil
    end
  rescue StandardError => e
    Rails.logger.error "[SoopliveScraper] API request error: #{e.message}"
    nil
  end

  def parse_date(date_string)
    return Time.current if date_string.blank?
    Time.zone.parse(date_string)
  rescue ArgumentError
    Time.current
  end

  def extract_duration_seconds(item)
    ucc = item['ucc']
    return nil unless ucc && ucc['total_file_duration']
    
    duration = ucc['total_file_duration'].to_f
    return nil if duration <= 0
    
    # Assuming duration is in milliseconds based on typical values like 10017226 (~10k sec)
    if duration > 100_000
      (duration / 1000).round
    else
      duration.round
    end
  end

  def extract_thumbnail_url(item)
    ucc = item['ucc']
    return nil unless ucc && ucc['thumb']
    
    thumb = ucc['thumb']
    # Sometimes starts with //
    if thumb.start_with?('//')
      "https:#{thumb}"
    elsif thumb.start_with?('/')
      "https://videoimg.sooplive.co.kr#{thumb}"
    else
      thumb # Assume full url
    end
  end

  def carom_related?(item)
    title = item['title_name'] || ''
    
    # We might want to use title, description (contents), and hash_tags
    contents = item['contents'] || ''
    
    raw_tags = item.dig('ucc', 'hash_tags')
    tags = if raw_tags.is_a?(Array)
             raw_tags.flatten.map(&:to_s).map(&:strip)
           elsif raw_tags.is_a?(String)
             raw_tags.split(',').map(&:strip)
           else
             []
           end
    
    # Also for channel 'afbilliardsX', virtually everything is carom-related (UMB)
    # But let's check keywords to be safe, or just return true if it's the official channel
    return true if source&.metadata&.dig('channel_id')&.start_with?('afbilliards')
    
    text = [title, contents, tags.join(' ')].join(' ')
    Video.contains_carom_keywords?(text)
  end

  def save_videos(items, source)
    saved_count = 0
    
    items.each do |item|
      begin
        video_id = item['title_no'].to_s
        existing = Video.find_by(external_id: video_id)
        
        counts = item['count'] || {}
        view_count = counts['read_cnt'].to_i
        like_count = counts['up_cnt'].to_i # If available
        
        if existing
          # Update statistics
          existing.update(
            view_count: view_count,
            like_count: like_count > 0 ? like_count : existing.like_count,
            metadata_extracted: true
          )
        else
          # Create new video
          duration_seconds = extract_duration_seconds(item)
          published_at = parse_date(item['reg_date'])
          thumbnail_url = extract_thumbnail_url(item)
          
          raw_tags = item.dig('ucc', 'hash_tags')
          tags = if raw_tags.is_a?(Array)
                   raw_tags.flatten.map(&:to_s).map(&:strip)
                 elsif raw_tags.is_a?(String)
                   raw_tags.split(',').map(&:strip)
                 else
                   []
                 end
          
          new_video = Video.create!(
            international_source: source,
            external_id: video_id,
            title: item['title_name'],
            description: item['contents'] || '',
            published_at: published_at,
            duration: duration_seconds,
            language: 'ko', # Usually Korean on SoopLive, though could contain en_US stream
            thumbnail_url: thumbnail_url,
            view_count: view_count,
            like_count: like_count > 0 ? like_count : nil,
            
            # Polymorphic fields - initially unassigned
            videoable_type: nil,
            videoable_id: nil,
            
            # Metadata
            data: { 
              year: published_at&.year,
              is_live: false,
              soop_tags: tags
            },
            metadata_extracted: true
          )
          
          new_video.auto_assign_discipline!
          
          saved_count += 1
        end
      rescue StandardError => e
        Rails.logger.error "[SoopliveScraper] Error saving video #{item['title_no']}: #{e.message}"
      end
    end
    
    saved_count
  end
end
