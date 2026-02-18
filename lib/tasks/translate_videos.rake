# frozen_string_literal: true

namespace :videos do
  desc 'Translate non-English video titles to English'
  task translate: :environment do
    puts "\n" + "="*80
    puts "VIDEO TRANSLATION"
    puts "="*80
    
    service = VideoTranslationService.new
    
    unless service.available?
      puts "\n❌ Google Translate API not configured!"
      puts "\nPlease set API key in credentials:"
      puts "  bin/rails credentials:edit"
      puts "\nAdd:"
      puts "  google:"
      puts "    translate_api_key: YOUR_API_KEY"
      puts "\nOr set environment variable:"
      puts "  export GOOGLE_TRANSLATE_API_KEY='YOUR_API_KEY'"
      exit 1
    end
    
    # Find videos that need translation
    videos_to_translate = Video.where(metadata_extracted: true)
                               .where("data->>'translated_title' IS NULL")
                               .where.not(language: ['en', 'en-US'])
                               .order(view_count: :desc)
    
    total = videos_to_translate.count
    puts "\nFound #{total} videos needing translation"
    
    if total.zero?
      puts "✅ All videos already translated or are in English!"
      exit 0
    end
    
    # Translate in batches
    count = service.translate_batch(videos_to_translate)
    
    puts "\n✅ Translated #{count} video titles"
    puts "="*80
  end
  
  desc 'Translate specific video by ID'
  task :translate_video, [:video_id] => :environment do |_t, args|
    video_id = args[:video_id]
    
    if video_id.blank?
      puts "Usage: rake videos:translate_video[VIDEO_ID]"
      exit 1
    end
    
    video = Video.find(video_id)
    service = VideoTranslationService.new
    
    unless service.available?
      puts "❌ Google Translate API not configured!"
      exit 1
    end
    
    puts "\nOriginal: #{video.title}"
    puts "Language: #{video.language || 'unknown'}"
    
    translated = service.translate_title(video)
    
    puts "Translated: #{translated}"
    puts "✅ Done!"
  end
  
  desc 'Show translation statistics'
  task translation_stats: :environment do
    puts "\n" + "="*80
    puts "VIDEO TRANSLATION STATISTICS"
    puts "="*80
    
    total = Video.count
    translated = Video.where("data->>'translated_title' IS NOT NULL").count
    non_english = Video.where.not(language: ['en', 'en-US']).count
    needs_translation = Video.where(metadata_extracted: true)
                             .where("data->>'translated_title' IS NULL")
                             .where.not(language: ['en', 'en-US'])
                             .count
    
    puts "\nTotal videos:              #{total}"
    puts "Already translated:        #{translated} (#{(translated.to_f / total * 100).round(1)}%)"
    puts "Non-English videos:        #{non_english}"
    puts "Need translation:          #{needs_translation}"
    
    # By language
    puts "\nVideos by language:"
    Video.group(:language)
         .count
         .sort_by { |_, count| -count }
         .first(10)
         .each do |lang, count|
           lang_name = lang || 'unknown'
           translated_count = Video.where(language: lang)
                                   .where("data->>'translated_title' IS NOT NULL")
                                   .count
           puts "  #{lang_name.ljust(15)} #{count.to_s.rjust(5)} (#{translated_count} translated)"
         end
    
    puts "\n" + "="*80
  end
  
  desc 'Test translation with sample text'
  task :test_translation, [:text] => :environment do |_t, args|
    text = args[:text] || "안녕하세요 당구"
    
    puts "\n" + "="*80
    puts "TRANSLATION TEST"
    puts "="*80
    
    service = VideoTranslationService.new
    
    unless service.available?
      puts "\n❌ Google Translate API not configured!"
      exit 1
    end
    
    puts "\nOriginal text: #{text}"
    
    # Detect language
    detection = service.detect_language(text)
    if detection
      puts "Detected language: #{detection[:language]} (confidence: #{(detection[:confidence] * 100).round(1)}%)"
    end
    
    # Translate
    begin
      translation = service.translator.translate(text, to: 'en')
      puts "Translated: #{translation.text}"
      puts "\n✅ Translation working!"
    rescue StandardError => e
      puts "\n❌ Translation failed: #{e.message}"
    end
    
    puts "="*80
  end
end
