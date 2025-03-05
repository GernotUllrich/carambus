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
end 