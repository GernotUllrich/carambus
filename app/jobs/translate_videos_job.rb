# frozen_string_literal: true

# Background job to translate video titles asynchronously
class TranslateVideosJob < ApplicationJob
  queue_as :default

  def perform(video_ids: nil, target_language: 'en', include_description: false)
    Rails.logger.info "[TranslateVideosJob] Starting translation (target: #{target_language})"
    
    service = VideoTranslationService.new
    
    unless service.translator
      Rails.logger.error "[TranslateVideosJob] Translation service not available"
      return 0
    end
    
    # Get videos to translate
    videos = if video_ids.present?
               InternationalVideo.where(id: video_ids)
             else
               # Translate videos without translation
               InternationalVideo.where("metadata->>'translated_title' IS NULL")
                                .where.not("metadata->>'players' IS NULL") # Prioritize videos with player names
                                .limit(100) # Process in batches
             end
    
    count = service.translate_batch(videos, target_language: target_language, include_description: include_description)
    
    Rails.logger.info "[TranslateVideosJob] Translated #{count} videos"
    count
  end
end
