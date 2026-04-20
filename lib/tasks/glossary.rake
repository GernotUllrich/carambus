namespace :glossary do
  desc "Erstellt oder aktualisiert alle Billard-Glossare"
  task update: :environment do
    puts "🔄 Aktualisiere alle Billard-Glossare..."
    puts ""

    service = DeeplGlossaryService.new

    DeeplGlossaryService::SUPPORTED_PAIRS.each do |src, tgt|
      print "  #{src.upcase}→#{tgt.upcase}... "
      result = service.create_glossary(src, tgt)
      puts result ? "✅" : "❌"
    end

    puts ""
    puts "✅ Alle Glossare erfolgreich aktualisiert!"
  end

  desc "Listet alle vorhandenen Glossare auf"
  task list: :environment do
    puts "📚 Vorhandene Glossare:"
    puts ""

    service = DeeplGlossaryService.new
    glossaries = service.list_glossaries

    if glossaries.empty?
      puts "  Keine Glossare gefunden."
    else
      glossaries.each do |g|
        puts "  • #{g['name']}"
        puts "    ID: #{g['glossary_id']}"
        puts "    Sprachen: #{g['source_lang'].upcase} → #{g['target_lang'].upcase}"
        puts "    Einträge: #{g['entry_count']}"
        puts ""
      end
    end
  end

  desc "Testet die Übersetzung mit Glossaren"
  task test: :environment do
    puts "🧪 Teste Übersetzungen mit Glossaren"
    puts "=" * 60
    puts ""

    service = DeeplTranslationService.new

    tests = [
      ["EN", "DE", "The American Position is a classic carom billiard position. The cue ball and object balls are positioned in glasses along the cushion."],
      ["NL", "DE", "De Amerikaanse positie is een klassieke carambole positie. De speelbal en objectballen worden gepositioneerd in brillenstand langs de band."],
      ["FR", "DE", "La position américaine est une position classique au billard carambole. La bille joueuse et les billes d'objet sont positionnées le long de la bande."],
      ["ES", "DE", "La posición americana es una posición clásica en el billar carambole. La bola jugadora y las bolas objeto están en la banda larga."]
    ]

    tests.each_with_index do |(source, target, text), i|
      puts "Test #{i + 1}: #{source}→#{target}"
      puts "─" * 60
      puts "Original:"
      puts text
      puts ""
      puts "Übersetzung:"
      result = service.translate(text: text, source_lang: source, target_lang: target)
      puts result
      puts ""
      puts "=" * 60
      puts ""
    end
  end

  desc "Zeigt Glossar-Statistiken"
  task stats: :environment do
    puts "📊 Glossar-Statistiken"
    puts ""

    service = DeeplGlossaryService.new
    total = 0

    DeeplGlossaryService::SUPPORTED_PAIRS.each do |src, tgt|
      count = (service.get_glossary_data(src, tgt) || {}).size
      puts "  #{src.upcase}→#{tgt.upcase}: #{count} Begriffe"
      total += count
    end

    puts ""
    puts "  Gesamt: #{total} Glossar-Einträge"
  end
end
