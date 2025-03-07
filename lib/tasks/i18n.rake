namespace :i18n do
  desc "Überprüft alle Übersetzungsdateien auf Fehler"
  task check: :environment do
    I18n.backend.load_translations
    puts "Verfügbare Sprachen: #{I18n.available_locales.inspect}"
    
    I18n.available_locales.each do |locale|
      puts "Übersetzungen für #{locale}:"
      puts I18n.backend.translations[locale].inspect
    end
  end

  desc "Translate and publish all pages to English"
  task translate_pages: :environment do
    success_count = 0
    failure_count = 0
    
    Page.published.find_each do |page|
      print "Translating page #{page.id}: #{page.title}... "
      
      if page.publish_with_translation
        puts "✓ Success"
        success_count += 1
      else
        puts "✗ Failed"
        failure_count += 1
      end
      
      # Add a small delay to avoid API rate limits
      sleep 1
    end
    
    puts "\nTranslation completed: #{success_count} successful, #{failure_count} failed"
  end
  
  desc "Translate and publish a specific page"
  task :translate_page, [:id] => :environment do |t, args|
    page = Page.find(args[:id])
    puts "Translating page: #{page.title}"
    
    if page.publish_with_translation
      puts "✓ Translation successful"
    else
      puts "✗ Translation failed"
    end
  end
end 