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
    "klots" => "Press-Ball",

    # Tafelonderdelen
    "band" => "Bande",
    "banden" => "Banden",
    "hoek" => "Ecke",
    "diamant" => "Diamant",
    "tafel" => "Tisch",
    "keu" => "Queue",
    "korteband" => "kurze Bande",
    "langeband" => "lange Bande",

    # Technieken en stoten
    "stoot" => "Stoß",
    "carambole" => "Karambolage",
    "driebanden" => "Dreiband",
    "techniek" => "Technik",
    "massé" => "Massé",
    "effect" => "Effet",
    "mee-effect" => "Laufeffet",

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
    "richting" => "Richtung",
    "kaderspel" => "Cadre-Spiel",
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
    "klots" => "frozen Balls",

    # Tafelonderdelen
    "band" => "cushion",
    "banden" => "cushions",
    "hoek" => "corner",
    "diamant" => "diamond",
    "tafel" => "table",
    "keu" => "cue",
    "korteband" => "short cushion",
    "langeband" => "long cushion",

    # Technieken
    "stoot" => "shot",
    "carambole" => "carom",
    "driebanden" => "three-cushion",
    "techniek" => "technique",
    "massé" => "masse",
    "effect" => "spin",
    "mee-effet" => "follow spin",

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

  # FR→DE Glossar
  BILLIARD_GLOSSARY_FR_DE = {
    # Billes
    "bille" => "Ball",
    "billes" => "Bälle",
    "bille de choc" => "Spielball",
    "bille d'objet" => "Objektball",
    "bille rouge" => "roter Ball",
    "bille blanche" => "weißer Ball",
    "bille jaune" => "gelber Ball",
    "billes collées" => "Press-Ball",

    # Table
    "bande" => "Bande",
    "bandes" => "Banden",
    "coin" => "Ecke",
    "diamant" => "Diamant",
    "table" => "Tisch",
    "queue" => "Queue",

    # Techniques
    "coup" => "Stoß",
    "carambolage" => "Karambolage",
    "trois bandes" => "Dreiband",
    "technique" => "Technik",
    "massé" => "Massé",
    "effet" => "Effet",
    "effet coulé" => "Laufeffet",

    # Positions
    "position" => "Position",
    "position de départ" => "Ausgangsposition",
    "position cible" => "Zielposition",
    "position américaine" => "Amerika-Position",

    # Jeu
    "point" => "Punkt",
    "points" => "Punkte",
    "score" => "Punktzahl",
    "série" => "Serie",
    "match" => "Match",
    "tournoi" => "Turnier",
    "exercice" => "Übung",
    "entraînement" => "Training",

    # Personnes
    "joueur" => "Spieler",
    "adversaire" => "Gegner",

    # Autres
    "diagramme" => "Diagramm",
    "angle" => "Winkel",
    "direction" => "Richtung"
  }

  # FR→EN Glossar
  BILLIARD_GLOSSARY_FR_EN = {
    # Billes
    "bille" => "ball",
    "billes" => "balls",
    "bille de choc" => "cue ball",
    "bille d'objet" => "object ball",
    "bille rouge" => "red ball",
    "bille blanche" => "white ball",
    "bille jaune" => "yellow ball",

    # Table
    "bande" => "cushion",
    "bandes" => "cushions",
    "coin" => "corner",
    "diamant" => "diamond",
    "table" => "table",
    "queue" => "cue",

    # Techniques
    "coup" => "shot",
    "carambolage" => "carom",
    "trois bandes" => "three-cushion",
    "technique" => "technique",
    "massé" => "masse",
    "effet" => "spin",
    "effet coulé" => "follow spin",

    # Positions
    "position" => "position",
    "position de départ" => "starting position",
    "position cible" => "target position",
    "position américaine" => "American position",

    # Jeu
    "point" => "point",
    "points" => "points",
    "score" => "score",
    "série" => "run",
    "match" => "match",
    "tournoi" => "tournament",
    "exercice" => "exercise",
    "entraînement" => "practice",

    # Personnes
    "joueur" => "player",
    "adversaire" => "opponent",

    # Autres
    "diagramme" => "diagram",
    "angle" => "angle",
    "direction" => "direction"
  }

  def initialize
    @api_key = ENV['DEEPL_API_KEY'].presence || Rails.application.credentials.fetch(:deepl_key)
    @api_key = @api_key.to_s.sub(/:fx$/, '')
  end

  # Erstellt oder aktualisiert ein Glossar
  def create_glossary(source_lang, target_lang)
    name = "billiard_#{source_lang}_#{target_lang}"
    delete_glossary_by_name(name)

    glossary_data = get_glossary_data(source_lang, target_lang)
    return nil unless glossary_data

    entries_tsv = glossary_data.map { |src, tgt| "#{src}\t#{tgt}" }.join("\n")

    uri = URI.parse("#{DEEPL_API_URL}/glossaries")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "DeepL-Auth-Key #{@api_key}"
    request["Content-Type"] = "application/x-www-form-urlencoded"

    request.set_form_data({
      "name" => name,
      "source_lang" => source_lang,
      "target_lang" => target_lang,
      "entries_format" => "tsv",
      "entries" => entries_tsv
    })

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      Rails.logger.info("✅ Billard-Glossar #{source_lang.upcase}->#{target_lang.upcase} erstellt: #{result['glossary_id']}")
      result['glossary_id']
    else
      Rails.logger.error("❌ Glossar-Erstellung fehlgeschlagen: #{response.body}")
      nil
    end
  rescue => e
    Rails.logger.error("Glossary creation error: #{e.message}")
    nil
  end

  # Gibt Glossar-Daten für Sprachpaar zurück
  def get_glossary_data(source_lang, target_lang)
    case "#{source_lang}_#{target_lang}"
    when "en_de" then BILLIARD_GLOSSARY_EN_DE
    when "nl_de" then BILLIARD_GLOSSARY_NL_DE
    when "nl_en" then BILLIARD_GLOSSARY_NL_EN
    when "fr_de" then BILLIARD_GLOSSARY_FR_DE
    when "fr_en" then BILLIARD_GLOSSARY_FR_EN
    else nil
    end
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

  # Gibt die passende Glossar-ID zurück (erstellt falls nötig)
  def get_or_create_glossary_id(source_lang, target_lang)
    name = "billiard_#{source_lang}_#{target_lang}"
    glossary_id = find_glossary_id_by_name(name)
    return glossary_id if glossary_id

    create_glossary(source_lang, target_lang)
  end
end
