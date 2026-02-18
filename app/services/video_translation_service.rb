# frozen_string_literal: true

require 'google/cloud/translate/v2'

# Service to translate video titles and descriptions using Google Cloud Translation API
class VideoTranslationService
  attr_reader :translator

  def initialize
    @translator = setup_translator
  end

  # Translate video title to target language
  def translate_title(video, target_language: 'en')
    return video.title if video.title.blank?
    return video.metadata['translated_title'] if video.metadata['translated_title'].present?

    # Skip if already in target language (heuristic: mostly ASCII)
    return video.title if mostly_ascii?(video.title)

    begin
      translation = @translator.translate(video.title, to: target_language)
      translated_text = translation.text
      
      # Clean branding tags from translation
      translated_text = clean_branding_tags(translated_text)

      # Update video metadata with translation
      video.update(
        metadata: video.metadata.merge(
          'translated_title' => translated_text,
          'original_language' => translation.from || translation.language,
          'translated_at' => Time.current.iso8601
        )
      )

      Rails.logger.info "[VideoTranslation] Translated: #{video.title[0..50]} → #{translated_text[0..50]}"
      translated_text
    rescue StandardError => e
      Rails.logger.error "[VideoTranslation] Failed to translate video #{video.id}: #{e.message}"
      video.title # Fallback to original
    end
  end

  # Translate description (optional, costs more)
  def translate_description(video, target_language: 'en')
    return video.description if video.description.blank?
    return video.metadata['translated_description'] if video.metadata['translated_description'].present?

    # Skip if already in target language
    return video.description if mostly_ascii?(video.description)

    begin
      # Only translate first 500 characters to save costs
      truncated = video.description[0..500]
      translation = @translator.translate(truncated, to: target_language)
      translated_text = translation.text

      video.update(
        metadata: video.metadata.merge(
          'translated_description' => translated_text,
          'translated_at' => Time.current.iso8601
        )
      )

      translated_text
    rescue StandardError => e
      Rails.logger.error "[VideoTranslation] Failed to translate description for video #{video.id}: #{e.message}"
      video.description
    end
  end

  # Batch translate multiple videos
  def translate_batch(videos, target_language: 'en', include_description: false)
    translated_count = 0
    
    videos.each do |video|
      next if video.metadata['translated_title'].present? # Skip already translated
      
      translate_title(video, target_language: target_language)
      translate_description(video, target_language: target_language) if include_description
      
      translated_count += 1
      
      # Small delay to avoid rate limiting
      sleep(0.1) if translated_count % 10 == 0
    end
    
    Rails.logger.info "[VideoTranslation] Batch translation complete: #{translated_count} videos"
    translated_count
  end

  # Detect language of text
  def detect_language(text)
    return nil if text.blank?
    
    detection = @translator.detect(text)
    {
      language: detection.language,
      confidence: detection.confidence
    }
  rescue StandardError => e
    Rails.logger.error "[VideoTranslation] Language detection failed: #{e.message}"
    nil
  end

  private

  def setup_translator
    # Check for API key in credentials or environment
    api_key = Rails.application.credentials.dig(:google, :translate_api_key) || 
              ENV['GOOGLE_TRANSLATE_API_KEY']
    
    if api_key.blank?
      Rails.logger.warn "[VideoTranslation] No Google Translate API key found. Translation disabled."
      return nil
    end
    
    Google::Cloud::Translate::V2.new(key: api_key)
  rescue StandardError => e
    Rails.logger.error "[VideoTranslation] Failed to initialize translator: #{e.message}"
    nil
  end

  # Check if text is mostly ASCII (likely already English)
  def mostly_ascii?(text)
    return false if text.blank?
    
    ascii_chars = text.chars.count { |c| c.ord < 128 }
    ratio = ascii_chars.to_f / text.length
    
    # If more than 80% ASCII, consider it English
    ratio > 0.8
  end

  # Remove common branding tags from translated titles
  def clean_branding_tags(text)
    return text if text.blank?
    
    # Remove common bracketed prefixes
    cleaned = text.gsub(/^\[(?:Rewind|Replay|Playback|Rewatch|Best of|Highlights?)\s*X?\]\s*/i, '')
    
    # Remove "ft." footnotes at the end (often not important)
    cleaned = cleaned.gsub(/\s*\(ft\..*?\)\s*$/, '')
    
    # Remove excessive punctuation at the end
    cleaned = cleaned.gsub(/[!?。]+\s*$/, '')
    
    # Trim whitespace
    cleaned.strip
  end
end
