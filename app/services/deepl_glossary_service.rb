require 'net/http'
require 'uri'
require 'json'

class DeeplGlossaryService
  DEEPL_API_URL = "https://api.deepl.com/v2"

  # Supported language pairs, single source of truth for both this service
  # and DeeplTranslationService. Lowercase for consistency with internal keys;
  # use supported_pairs_upcase for the DeepL API which expects upper case.
  SUPPORTED_PAIRS = [
    ["en", "de"], ["nl", "de"], ["nl", "en"],
    ["fr", "de"], ["fr", "en"], ["es", "de"], ["es", "en"]
  ].freeze

  def self.supported_pairs_upcase
    SUPPORTED_PAIRS.map { |src, tgt| [src.upcase, tgt.upcase] }
  end

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
    "angle" => "Winkel",

    # Additions 2026-04-19 — Gretillat four parameters
    "quantity of ball"      => "Ballbreite",
    "height of attack"      => "Treffhöhe",
    "energy"                => "Stoßenergie",
    "force"                 => "Kraft",
    "speed"                 => "Stoßgeschwindigkeit",

    # Quantity-of-ball values (Gretillat)
    "full ball"             => "voller Ball",
    "three quarter ball"    => "Dreiviertel-Ball",
    "half ball"             => "halber Ball",
    "quarter ball"          => "Viertel-Ball",

    # Gather-shot vocabulary (Gretillat)
    "gather shot"           => "Versammlungsstoß",
    "long gather shot"      => "langer Versammlungsstoß",
    "width gather shot"     => "kurzer Versammlungsstoß",
    "gather zone"           => "Versammlungszone",
    "placement"             => "Stellungsstoß",

    # Gretillat Principles
    "principle of dominance" => "Prinzip der Dominanz",
    "margin of error"       => "Fehlertoleranz",
    "risk factor analysis"  => "Risikofaktor-Analyse",

    # Weingartner notation (confirmed)
    "compulsory shot program" => "Pflichtstoßprogramm",
    "cadre line"            => "Cadrelinie",
    "ball-width"            => "Ballbreite",

    # Cross-technique
    "bank shot"             => "Doublé"
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
    "richting" => "Richtung",
    "kaderspel" => "Cadre-Spiel",

    # Additions 2026-04-19
    "verzamelstoten"        => "Versammlungsstöße",
    "verzamelstoot"         => "Versammlungsstoß",
    "trekstoot"             => "Rückläufer",
    "masséstoot"            => "Massé-Stoß",
    "libre"                 => "Freie Partie",
    "vrij spel"             => "Freie Partie",
    "kader"                 => "Cadre",
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
    "direction" => "Richtung",

    # Additions 2026-04-19 — from Gretillat book 1 glossary (p. 3)
    "bille joueuse"         => "Spielball",
    "point de visée"        => "Anspielpunkt",
    "point de bande"        => "Bandenpunkt",
    "avec effet"            => "mit Effet",
    "sans effet"            => "ohne Effet",
    "vue de profil"         => "Seitenansicht",
    "vue de dessus"         => "Draufsicht",
    "surface de jeu"        => "Spielfläche",
    "hauteur d'attaque"     => "Treffhöhe",
    "quantité de bille"     => "Ballbreite",
    "rétro"                 => "Rückläufer",
    "coulé"                 => "Nachläufer",
    "marge d'erreur"        => "Fehlertoleranz",
    "rappel"                => "Versammlungsstoß",
    "rappel long"           => "langer Versammlungsstoß",
    "rappel en largeur"     => "kurzer Versammlungsstoß",
    "trajectoire"           => "Laufweg",
    "angle d'incidence"     => "Einfallswinkel",
    "angle de réflexion"    => "Reflexionswinkel"
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
    "direction" => "direction",

    # Additions 2026-04-19 — from Gretillat book 1 glossary (p. 3)
    "bille joueuse"         => "cue ball",
    "point de visée"        => "aiming point",
    "point de bande"        => "band point",
    "avec effet"            => "with english",
    "sans effet"            => "without english",
    "hauteur d'attaque"     => "height of attack",
    "quantité de bille"     => "quantity of ball",
    "rétro"                 => "draw",
    "coulé"                 => "follow",
    "marge d'erreur"        => "margin of error",
    "rappel"                => "gather shot",
    "rappel long"           => "long gather shot",
    "rappel en largeur"     => "width gather shot",
    "trajectoire"           => "trajectory",
    "passage de coin"       => "corner passage",
    "petite ligne"          => "small line"
  }

  # Billard-Glossar ES→DE (initial seed, 2026-04-19)
  # Source material: ACBillar blog archive (acbillar.blogspot.com), Bonacho compilation.
  # NOTE: only VERIFIED terms here. 3-cushion-specific terms (rodadas, cabañas,
  # bricol, semicorrido, valor de mesa) are HELD BACK pending 3-cushion expert review.
  BILLIARD_GLOSSARY_ES_DE = {
    # Bolas
    "bola"                  => "Ball",
    "bolas"                 => "Bälle",
    "bola jugadora"         => "Spielball",
    "bola objeto"           => "Objektball",
    "bola roja"             => "roter Ball",
    "bola blanca"           => "weißer Ball",
    "bola amarilla"         => "gelber Ball",

    # Tisch / Banden
    "banda"                 => "Bande",
    "bandas"                => "Banden",
    "banda corta"           => "kurze Bande",
    "banda larga"           => "lange Bande",
    "banda opuesta"         => "gegenüberliegende Bande",
    "diamante"              => "Diamant",
    "rombo"                 => "Raute",
    "esquina"               => "Ecke",

    # Disziplinen
    "tres bandas"           => "Dreiband",
    "billar libre"          => "Freie Partie",
    "cuadro"                => "Cadre",
    "una banda"             => "Einband",

    # Systeme (Eigennamen mostly unchanged)
    "sistema de diamantes"  => "Diamantsystem",
    "sistema diamantes"     => "Diamantsystem",
    "sistema plus"          => "Plus-System",
    "sistema 30"            => "System 30",
    "sistema clásico"       => "klassisches System",

    # Technik
    "efecto"                => "Effet",
    "efecto contrario"      => "Kontra-Effet",
    "efecto inverso"        => "Kontra-Effet",
    "masé"                  => "Massé",
    "piqué"                 => "Piqué",
    "carambole"             => "Karambolage",
    "carambola"             => "Karambolage",
    "cuarto de bola"        => "Viertelball",

    # Spielbegriffe
    "punto"                 => "Punkt",
    "puntos"                => "Punkte",
    "serie"                 => "Serie",
    "tirada"                => "Aufnahme",

    # Personen
    "jugador"               => "Spieler",
    "adversario"            => "Gegner"
  }

  # Billard-Glossar ES→EN (initial seed, 2026-04-19)
  # Source: ACBillar blog archive (bilingual es/en posts by the author).
  # English column trusted — it is the blog author's own translation.
  BILLIARD_GLOSSARY_ES_EN = {
    "bola"                  => "ball",
    "bolas"                 => "balls",
    "bola jugadora"         => "cue ball",
    "bola objeto"           => "object ball",
    "bola roja"             => "red ball",
    "bola blanca"           => "white ball",
    "bola amarilla"         => "yellow ball",

    "banda"                 => "cushion",
    "bandas"                => "cushions",
    "banda corta"           => "short rail",
    "banda larga"           => "long rail",
    "banda opuesta"         => "opposite cushion",
    "diamante"              => "diamond",
    "rombo"                 => "diamond",
    "esquina"               => "corner",

    "tres bandas"           => "three-cushion",
    "billar libre"          => "free game",
    "una banda"             => "one cushion",

    "sistema de diamantes"  => "diamond system",
    "sistema diamantes"     => "diamond system",
    "sistema plus"          => "plus system",
    "sistema 30"            => "system 30",
    "sistema tuzul"         => "tuzul system",

    "efecto"                => "english",
    "efecto contrario"      => "reverse english",
    "masé"                  => "masse",
    "piqué"                 => "piqué",
    "carambole"             => "carom",
    "cuarto de bola"        => "fourth ball",

    "salida"                => "departure",
    "ataque"                => "attack point",
    "llegada"               => "arrival",
    "bricol"                => "bricole",
    "semicorrido"           => "half topspin",

    "patrón"                => "pattern",
    "patrones"              => "patterns",
    "jugada patrón"         => "standard play",
    "rodadas"               => "round-the-table shots",
    "cabañas"               => "short boxes",
    "pluses"                => "plus shots",
    "tangentes interiores"  => "inner tangents",
    "valor de mesa"         => "table value",
    "compensaciones"        => "compensations",

    "punto"                 => "point",
    "puntos"                => "points",
    "serie"                 => "run",
    "tirada"                => "inning",

    "jugador"               => "player",
    "adversario"            => "opponent"
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
    when "es_de" then BILLIARD_GLOSSARY_ES_DE
    when "es_en" then BILLIARD_GLOSSARY_ES_EN
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

  # Per-pair wrapper methods, kept for backward compatibility with docs and
  # rake tasks that reference create_billiard_glossary_<pair>. Prefer
  # create_glossary(source_lang, target_lang) for new code.
  SUPPORTED_PAIRS.each do |src, tgt|
    define_method("create_billiard_glossary_#{src}_#{tgt}") do
      create_glossary(src, tgt)
    end
  end
end
