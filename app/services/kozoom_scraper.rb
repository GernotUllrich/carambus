# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class KozoomScraper
  API_BASE_URL = "https://api.kozoom.com"

  def initialize(email: nil, password: nil)
    @email = email || Rails.application.credentials.dig(:kozoom, :email)
    @password = password || Rails.application.credentials.dig(:kozoom, :password)
    @token = nil
  end

  def authenticate
    return true if @token

    unless @email.present? && @password.present?
      Rails.logger.error "[KozoomScraper] Missing credentials. Please set kozoom credentials in Rails.application.credentials."
      return false
    end

    uri = URI("#{API_BASE_URL}/auth/login")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Post.new(uri.path, { "Content-Type" => "application/json", "Accept" => "application/json" })
    request.body = { email: @email, password: @password }.to_json

    begin
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        @token = data.dig("data", "accessToken")
        Rails.logger.info "[KozoomScraper] Successfully authenticated with Kozoom API."
        true
      else
        Rails.logger.error "[KozoomScraper] Authentication failed: #{response.code} #{response.body}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "[KozoomScraper] Authentication error: #{e.message}"
      false
    end
  end

  def get_events(sport_id: 1, start_date: nil, end_date: nil)
    return [] unless authenticate

    start_date ||= 3.days.ago.strftime("%Y-%m-%d")
    end_date ||= Date.today.strftime("%Y-%m-%d")

    uri = URI("#{API_BASE_URL}/events/days?startDate=#{start_date}&endDate=#{end_date}&sportId=#{sport_id}")
    response = make_request(uri)

    return [] unless response

    events = JSON.parse(response.body)
    Rails.logger.info "[KozoomScraper] Found #{events.size} total events between #{start_date} and #{end_date}"
    events
  end

  def get_videos(event_id)
    return [] unless authenticate

    uri = URI("#{API_BASE_URL}/videos?eventId=#{event_id}&lang=en&limit=1000")
    response = make_request(uri)

    return [] unless response

    JSON.parse(response.body)
  end

  def scrape(days_back: 3)
    start_date = days_back.days.ago.strftime("%Y-%m-%d")

    # 1. Ensure source exists
    source = get_or_create_kozoom_source
    return 0 unless source

    events = get_events(start_date: start_date)
    return 0 if events.empty?

    saved_count = 0
    total_videos = 0

    events.each do |event|
      videos = get_videos(event["id"])
      total_videos += videos.size

      videos.each do |v|
        video_id = v["id"].to_s

        # Check if we already have this video
        next if Video.exists?(external_id: video_id, international_source_id: source.id)

        # The frontend video URL is usually the event URL itself
        link = "https://tv.kozoom.com/en/event/#{event['id']}"

        # Save video
        begin
          Video.create!(
            international_source_id: source.id,
            external_id: video_id,
            title: v["description"] || "Kozoom Event #{event['id']} - Video #{video_id}",
            duration: v["duration"],
            published_at: v["createdAt"],
            thumbnail_url: v["thumbnail"],
            data: v.merge({ "url" => link, "player" => "kozoom" })
          )
          saved_count += 1
        rescue StandardError => e
          Rails.logger.error "[KozoomScraper] Error saving video #{video_id}: #{e.message}"
        end
      end
    end

    Rails.logger.info "[KozoomScraper] Finished. Saved #{saved_count} new videos out of #{total_videos} total."
    saved_count
  end

  private

  def make_request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Authorization"] = "Bearer #{@token}"
    request["Accept"] = "application/json"

    begin
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        response
      else
        Rails.logger.error "[KozoomScraper] Request failed (#{uri}): #{response.code}"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "[KozoomScraper] Request error (#{uri}): #{e.message}"
      nil
    end
  end

  def get_or_create_kozoom_source
    source = InternationalSource.find_by(source_type: "kozoom")
    unless source
      source = InternationalSource.create!(
        name: "Kozoom TV",
        source_type: "kozoom",
        base_url: "https://tv.kozoom.com",
        active: true,
        metadata: {
          "channel_id" => "kozoom_tv",
          "description" => "Kozoom Billiards streaming and replays"
        }
      )
    end
    source
  end
end
