require 'net/http'
require 'uri'
require 'json'

class DeeplGlossaryService
  DEEPL_API_URL = "https://api.deepl.com/v2"
  
  # Billard-spezifisches Glossar EN→DE
  BILLIARD_GLOSSARY_EN_DE = {
    # Positionsbegriffe
    "American Position" => "Amerika-Position",
    "America Position" => "Amerika-Position",
    "position" => "Position",
    "starting position" => "Ausgangsposition",
    "target position" => "Zielposition",
    "glasses" => "Brillenstellung",
    "in glasses" => "in Brillenstellung",
    "glasses position" => "Brillenstellung",
    
    # Bälle und Ausrüstung
    "ball" => "Ball",
    "balls" => "Bälle",
    "cue ball" => "Spielball",
    "object ball" => "Objektball",
    "red ball" => "roter Ball",
    "white ball" => "weißer Ball",
    "yellow ball" => "gelber Ball",
    
    # Tischteile
    "cushion" => "Bande",
    "cushions" => "Banden",
    "rail" => "Bande",
    "band" => "Bande",
    "corner" => "Ecke",
    "diamond" => "Diamant",
    "table" => "Tisch",
    
    # Techniken und Stöße
    "shot" => "Stoß",
    "cannon" => "Karambolage",
    "carom" => "Karambolage",
    "three-cushion" => "Dreiband",
    "technique" => "Technik",
    "stroke" => "Stoß",
    "masse shot" => "Massé-Stoß",
    "follow shot" => "Nachläufer",
    "draw shot" => "Rückläufer",
    
    # Spielbegriffe
    "point" => "Punkt",
    "score" => "Punktzahl",
    "run" => "Serie",
    "break" => "Anstoß",
    "game" => "Spiel",
    "match" => "Match",
    
    # Sonstiges
    "player" => "Spieler",
    "opponent" => "Gegner",
    "tournament" => "Turnier",
    "practice" => "Training",
    "exercise" => "Übung",
    "diagram" => "Diagramm",
    "angle" => "Winkel"
  }
  
  # Billard-Glossar NL→DE
  BILLIARD_GLOSSARY_NL_DE = {
    # Ballen (Bälle)
    "bal" => "Ball",
    "ballen" => "Bälle",
    "speelbal" => "Spielball",
    "objectbal" => "Objektball",
    "rode bal" => "roter Ball",
    "witte bal" => "weißer Ball",
    "gele bal" => "gelber Ball",
    
    # Tafelonderdelen
    "band" => "Bande",
    "banden" => "Banden",
    "hoek" => "Ecke",
    "diamant" => "Diamant",
    "tafel" => "Tisch",
    "keu" => "Queue",
    
    # Technieken en stoten
    "stoot" => "Stoß",
    "carambole" => "Karambolage",
    "driebanden" => "Dreiband",
    "techniek" => "Technik",
    "massé" => "Massé",
    "effect" => "Effet",
    
    # Posities
    "positie" => "Position",
    "uitgangspositie" => "Ausgangsposition",
    "doelpositie" => "Zielposition",
    "Amerikaanse positie" => "Amerika-Position",
    "brillenstand" => "Brillenstellung",
    "in brillenstand" => "in Brillenstellung",
    
    # Spelbegrippen
    "punt" => "Punkt",
    "punten" => "Punkte",
    "score" => "Punktzahl",
    "serie" => "Serie",
    "wedstrijd" => "Match",
    "toernooi" => "Turnier",
    "oefening" => "Übung",
    "training" => "Training",
    
    # Personen
    "speler" => "Spieler",
    "tegenstander" => "Gegner",
    
    # Sonstiges
    "diagram" => "Diagramm",
    "hoek" => "Winkel",
    "richting" => "Richtung"
  }
  
  # Billard-Glossar NL→EN
  BILLIARD_GLOSSARY_NL_EN = {
    # Ballen
    "bal" => "ball",
    "ballen" => "balls",
    "speelbal" => "cue ball",
    "objectbal" => "object ball",
    "rode bal" => "red ball",
    "witte bal" => "white ball",
    "gele bal" => "yellow ball",
    
    # Tafelonderdelen
    "band" => "cushion",
    "banden" => "cushions",
    "hoek" => "corner",
    "diamant" => "diamond",
    "tafel" => "table",
    "keu" => "cue",
    
    # Technieken
    "stoot" => "shot",
    "carambole" => "carom",
    "driebanden" => "three-cushion",
    "techniek" => "technique",
    "massé" => "masse",
    "effect" => "spin",
    
    # Posities
    "positie" => "position",
    "uitgangspositie" => "starting position",
    "doelpositie" => "target position",
    "Amerikaanse positie" => "American position",
    "brillenstand" => "glasses position",
    "in brillenstand" => "in glasses",
    
    # Spelbegrippen
    "punt" => "point",
    "punten" => "points",
    "score" => "score",
    "serie" => "run",
    "wedstrijd" => "match",
    "toernooi" => "tournament",
    "oefening" => "exercise",
    "training" => "practice",
    
    # Personen
    "speler" => "player",
    "tegenstander" => "opponent",
    
    # Sonstiges
    "diagram" => "diagram",
    "hoek" => "angle",
    "richting" => "direction"
  }
  
  def initialize
    @api_key = ENV['DEEPL_API_KEY'].presence || Rails.application.credentials.fetch(:deepl_key)
    @api_key = @api_key.to_s.sub(/:fx$/, '')
  end
  
  # Erstellt oder aktualisiert das Billard-Glossar für EN->DE
  def create_billiard_glossary_en_de
    # Zuerst: Existierendes Glossar mit diesem Namen löschen
    delete_glossary_by_name("billiard_en_de")
    
    # Glossar-Einträge als TSV formatieren
    entries_tsv = BILLIARD_GLOSSARY_EN_DE.map { |en, de| "#{en}\t#{de}" }.join("\n")
    
    uri = URI.parse("#{DEEPL_API_URL}/glossaries")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    request["Content-Type"] = "application/x-www-form-urlencoded"
    
    request.set_form_data({
      "name" => "billiard_en_de",
      "source_lang" => "en",
      "target_lang" => "de",
      "entries_format" => "tsv",
      "entries" => entries_tsv
    })
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      Rails.logger.info("✅ Billard-Glossar EN->DE erstellt: #{result['glossary_id']}")
      result['glossary_id']
    else
      Rails.logger.error("❌ Glossar-Erstellung fehlgeschlagen: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Glossary creation error: #{e.message}")
    nil
  end
  
  # Listet alle Glossare auf
  def list_glossaries
    uri = URI.parse("#{DEEPL_API_URL}/glossaries")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)['glossaries']
    else
      []
    end
  rescue => e
    Rails.logger.error("List glossaries error: #{e.message}")
    []
  end
  
  # Findet Glossar-ID nach Namen
  def find_glossary_id_by_name(name)
    glossaries = list_glossaries
    glossary = glossaries.find { |g| g['name'] == name }
    glossary&.dig('glossary_id')
  end
  
  # Löscht ein Glossar nach Namen
  def delete_glossary_by_name(name)
    glossary_id = find_glossary_id_by_name(name)
    return unless glossary_id
    
    uri = URI.parse("#{DEEPL_API_URL}/glossaries/#{glossary_id}")
    request = Net::HTTP::Delete.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    Rails.logger.info("Deleted glossary: #{name}")
  rescue => e
    Rails.logger.error("Delete glossary error: #{e.message}")
  end
  
  # Erstellt NL->DE Glossar
  def create_billiard_glossary_nl_de
    delete_glossary_by_name("billiard_nl_de")
    
    entries_tsv = BILLIARD_GLOSSARY_NL_DE.map { |nl, de| "#{nl}\t#{de}" }.join("\n")
    
    uri = URI.parse("#{DEEPL_API_URL}/glossaries")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    request["Content-Type"] = "application/x-www-form-urlencoded"
    
    request.set_form_data({
      "name" => "billiard_nl_de",
      "source_lang" => "nl",
      "target_lang" => "de",
      "entries_format" => "tsv",
      "entries" => entries_tsv
    })
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      Rails.logger.info("✅ Billard-Glossar NL->DE erstellt: #{result['glossary_id']}")
      result['glossary_id']
    else
      Rails.logger.error("❌ Glossar-Erstellung fehlgeschlagen: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Glossary creation error: #{e.message}")
    nil
  end
  
  # Erstellt NL->EN Glossar
  def create_billiard_glossary_nl_en
    delete_glossary_by_name("billiard_nl_en")
    
    entries_tsv = BILLIARD_GLOSSARY_NL_EN.map { |nl, en| "#{nl}\t#{en}" }.join("\n")
    
    uri = URI.parse("#{DEEPL_API_URL}/glossaries")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    request["Content-Type"] = "application/x-www-form-urlencoded"
    
    request.set_form_data({
      "name" => "billiard_nl_en",
      "source_lang" => "nl",
      "target_lang" => "en",
      "entries_format" => "tsv",
      "entries" => entries_tsv
    })
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    
    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      Rails.logger.info("✅ Billard-Glossar NL->EN erstellt: #{result['glossary_id']}")
      result['glossary_id']
    else
      Rails.logger.error("❌ Glossar-Erstellung fehlgeschlagen: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Glossary creation error: #{e.message}")
    nil
  end
  
  # Gibt die passende Glossar-ID zurück (erstellt falls nötig)
  def get_or_create_glossary_id(source_lang, target_lang)
    name = "billiard_#{source_lang}_#{target_lang}"
    glossary_id = find_glossary_id_by_name(name)
    return glossary_id if glossary_id
    
    case "#{source_lang}_#{target_lang}"
    when "en_de"
      create_billiard_glossary_en_de
    when "nl_de"
      create_billiard_glossary_nl_de
    when "nl_en"
      create_billiard_glossary_nl_en
    else
      nil
    end
  end
  
  # Legacy-Methode für Rückwärtskompatibilität
  def get_or_create_billiard_glossary_id
    get_or_create_glossary_id('en', 'de')
  end
end
