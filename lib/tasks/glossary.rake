namespace :glossary do
  desc "Erstellt oder aktualisiert alle Billard-Glossare"
  task update: :environment do
    puts "🔄 Aktualisiere alle Billard-Glossare..."
    puts ""
    
    service = DeeplGlossaryService.new
    
    # EN->DE
    print "  EN→DE... "
    service.create_billiard_glossary_en_de
    puts "✅"
    
    # NL->DE
    print "  NL→DE... "
    service.create_billiard_glossary_nl_de
    puts "✅"
    
    # NL->EN
    print "  NL→EN... "
    service.create_billiard_glossary_nl_en
    puts "✅"
    
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
      ["NL", "DE", "De Amerikaanse positie is een klassieke carambole positie. De speelbal en objectballen worden gepositioneerd in brillenstand langs de band."]
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
    
    en_de = DeeplGlossaryService::BILLIARD_GLOSSARY_EN_DE.size
    nl_de = DeeplGlossaryService::BILLIARD_GLOSSARY_NL_DE.size
    nl_en = DeeplGlossaryService::BILLIARD_GLOSSARY_NL_EN.size
    
    puts "  EN→DE: #{en_de} Begriffe"
    puts "  NL→DE: #{nl_de} Begriffe"
    puts "  NL→EN: #{nl_en} Begriffe"
    puts ""
    puts "  Gesamt: #{en_de + nl_de + nl_en} Glossar-Einträge"
  end
end
