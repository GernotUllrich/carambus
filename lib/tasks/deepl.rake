namespace :deepl do
  desc "Test DeepL translation service"
  task test: :environment do
    puts "\n" + "="*60
    puts "Testing DeepL Translation Service"
    puts "="*60 + "\n"

    test_text = "Dies ist ein Test der DeepL API."
    source_lang = "DE"
    target_lang = "EN"

    puts "Original text (#{source_lang}): #{test_text}"
    puts "\nCalling DeeplTranslationService.translate..."

    begin
      front_matter, translated = DeeplTranslationService.translate(test_text, source_lang, target_lang)
      
      if translated
        puts "\n✅ SUCCESS!"
        puts "Translated text (#{target_lang}): #{translated}"
        puts "\nDeepL API is working correctly with Pro endpoint."
      else
        puts "\n❌ FAILED!"
        puts "Translation returned nil."
        puts "Check Rails logs for error details."
      end
    rescue => e
      puts "\n❌ ERROR!"
      puts "Exception: #{e.class}"
      puts "Message: #{e.message}"
      puts "\nBacktrace:"
      puts e.backtrace.first(5).join("\n")
    end

    puts "\n" + "="*60 + "\n"
  end

  desc "Test DeepL translation with custom text"
  task :test_custom, [:text, :source, :target] => :environment do |t, args|
    args.with_defaults(
      text: "Hallo Welt",
      source: "DE",
      target: "EN"
    )

    puts "\n" + "="*60
    puts "Testing DeepL Translation Service (Custom)"
    puts "="*60 + "\n"

    puts "Original text (#{args.source}): #{args.text}"
    puts "\nCalling DeeplTranslationService.translate..."

    begin
      front_matter, translated = DeeplTranslationService.translate(args.text, args.source, args.target)
      
      if translated
        puts "\n✅ SUCCESS!"
        puts "Translated text (#{args.target}): #{translated}"
      else
        puts "\n❌ FAILED!"
        puts "Translation returned nil."
      end
    rescue => e
      puts "\n❌ ERROR!"
      puts "Exception: #{e.class}"
      puts "Message: #{e.message}"
    end

    puts "\n" + "="*60 + "\n"
  end
end
