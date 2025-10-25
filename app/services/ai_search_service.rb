# frozen_string_literal: true

# AI-powered search service for natural language queries
# Converts German natural language to Carambus filter syntax
#
# Usage:
#   result = AiSearchService.call(query: "Alle Turniere in Hamburg 2024", user: current_user)
#   # => { entity: "tournaments", filters: "Season:2024/2025 Region:HH", confidence: 95, explanation: "..." }
#
class AiSearchService < ApplicationService
  # Entity mapping: German terms to Rails resource names
  ENTITY_MAPPING = {
    'players' => {
      names: ['Spieler', 'Player', 'Teilnehmer', 'Personen'],
      path_helper: 'players_path',
      common_filters: ['Region', 'Club', 'Firstname', 'Lastname', 'Season']
    },
    'clubs' => {
      names: ['Vereine', 'Clubs', 'Verein', 'Club'],
      path_helper: 'clubs_path',
      common_filters: ['Region', 'Name']
    },
    'tournaments' => {
      names: ['Turniere', 'Turnier', 'Tournament', 'Veranstaltung', 'Veranstaltungen'],
      path_helper: 'tournaments_path',
      common_filters: ['Season', 'Region', 'Discipline', 'Date', 'Title', 'Location']
    },
    'locations' => {
      names: ['Spielorte', 'Locations', 'Spielort', 'Location', 'Orte', 'Ort'],
      path_helper: 'locations_path',
      common_filters: ['Region', 'Name', 'City']
    },
    'regions' => {
      names: ['Regionen', 'Region', 'Landesverbände', 'Landesverband'],
      path_helper: 'regions_path',
      common_filters: ['Shortname', 'Name']
    },
    'seasons' => {
      names: ['Saisons', 'Saison', 'Season', 'Spielzeit'],
      path_helper: 'seasons_path',
      common_filters: ['Name']
    },
    'season_participations' => {
      names: ['Saisonteilnahmen', 'Saisonteilnahme', 'SeasonParticipation'],
      path_helper: 'season_participations_path',
      common_filters: ['Season', 'Player', 'Club', 'Region']
    },
    'parties' => {
      names: ['Spieltage', 'Spieltag', 'Partie', 'Partien', 'Parties'],
      path_helper: 'parties_path',
      common_filters: ['Season', 'League', 'Date', 'Region']
    },
    'game_participations' => {
      names: ['Spielteilnahmen', 'Spielteilnahme', 'GameParticipation'],
      path_helper: 'game_participations_path',
      common_filters: ['Player', 'Game', 'Season']
    },
    'seedings' => {
      names: ['Setzungen', 'Setzung', 'Seeding', 'Turnierteilnahmen'],
      path_helper: 'seedings_path',
      common_filters: ['Tournament', 'Player', 'Season', 'Discipline', 'Status']
    },
    'party_games' => {
      names: ['Mannschaftsspiele', 'Mannschaftsspiel', 'PartyGame'],
      path_helper: 'party_games_path',
      common_filters: ['Party', 'Player', 'Date']
    },
    'disciplines' => {
      names: ['Disziplinen', 'Disziplin', 'Discipline'],
      path_helper: 'disciplines_path',
      common_filters: ['Name']
    }
  }.freeze

  # Region shortnames for quick reference (from database)
  REGIONS = {
    'BBV' => ['Bayerischer Billardverband', 'Bayern', 'BBV', 'BY'],
    'SBV' => ['Sächsischer Billardverband', 'Sachsen', 'SBV'],
    'BVBW' => ['Billard-Verband Baden-Württemberg', 'Baden-Württemberg', 'BVBW', 'BW'],
    'BVRP' => ['Billard Verband Rheinland-Pfalz', 'Rheinland-Pfalz', 'BVRP', 'RP'],
    'HBU' => ['Hessische Billard Union', 'Hessen', 'HBU', 'HE'],
    'BVW' => ['Billard-Verband Westfalen', 'Westfalen', 'BVW', 'WL'],
    'BVB' => ['Billard-Verband Berlin', 'Berlin', 'BVB', 'BE'],
    'BBBV' => ['Brandenburgischer Billardverband', 'Brandenburg', 'BBBV', 'BB'],
    'BLVN' => ['Billard Landesverband Niedersachsen', 'Niedersachsen', 'BLVN', 'NI'],
    'NBV' => ['Norddeutscher Billard Verband', 'Norddeutschland', 'NBV', 'Hamburg', 'HH', 'Schleswig-Holstein', 'SH'],
    'BLVSA' => ['Billard Landesverband Sachsen-Anhalt', 'Sachsen-Anhalt', 'BLVSA', 'SA'],
    'DBU' => ['Deutsche Billard-Union', 'Deutschland', 'DBU'],
    'BVS' => ['Billard-Verband-Saar', 'Saarland', 'BVS', 'SL'],
    'BLMR' => ['Billard Landesverband Mittleres Rheinland', 'Mittleres Rheinland', 'BLMR'],
    'BVNRW' => ['Billard-Verband Nordrhein-Westfalen', 'Nordrhein-Westfalen', 'BVNRW', 'NRW', 'NW'],
    'BVNR' => ['Billard-Verband Niederrhein', 'Niederrhein', 'BVNR'],
    'TBV' => ['Thüringer Billard Verband', 'Thüringen', 'TBV', 'TH']
  }.freeze

  # Common disciplines
  DISCIPLINES = [
    'Freie Partie',
    'Dreiband',
    'Einband',
    'Cadre',
    'Pool',
    'Snooker'
  ].freeze

  def initialize(options = {})
    super()
    @query = options[:query]&.strip
    @user = options[:user]
    @locale = options[:locale] || 'de'
    @client = OpenAI::Client.new
  end

  def call
    return error_response('Keine Anfrage angegeben') if @query.blank?
    return error_response('OpenAI nicht konfiguriert') unless openai_configured?

    begin
      response = @client.chat(
        parameters: {
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: system_prompt },
            { role: 'user', content: @query }
          ],
          response_format: { type: 'json_object' },
          temperature: 0.3,
          max_tokens: 500
        }
      )

      parse_ai_response(response)
    rescue StandardError => e
      Rails.logger.error "AiSearchService error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      error_response("Fehler bei der KI-Anfrage: #{e.message}")
    end
  end

  private

  def system_prompt
    @locale == 'en' ? system_prompt_en : system_prompt_de
  end

  def system_prompt_de
    <<~PROMPT
      Du bist ein intelligenter Such-Assistent für Carambus, eine deutsche Billard-Verwaltungs-App.
      
      DEINE AUFGABE:
      Wandle natürliche deutsche Suchanfragen in strukturierte Filter-Syntax um.
      
      VERFÜGBARE ENTITIES (wichtig: exakte Namen verwenden):
      #{entity_list}
      
      FILTER-SYNTAX:
      1. Freitext: Einfach Text eingeben (z.B. "Meyer", "Hamburg", "Wedel" für Namen/Städte)
      
      2. Season: "Season:2024/2025" oder "Season:2023/2024"
      
      3. Region: NUR verwenden wenn EXPLIZIT ein VERBAND oder BUNDESLAND gemeint ist!
         WICHTIG: Bei Städtenamen (Hamburg, Berlin, München, etc.) → Freitext verwenden!
         Region-Filter nur für:
         - Verbandsnamen: "aus dem NBV", "aus dem BVW", "im Verband"
         - Bundesländer: "aus Bayern", "in Hessen", "in Nordrhein-Westfalen"
         
         Verfügbare Verbände:
         #{region_mappings}
      
      4. Location: "Location:BC Wedel" "Location:Billard-Centrum Hamburg"
         Verwendung für SPIELORT-Namen bei Turnieren (NICHT für Städte oder Vereinszugehörigkeit!)
      
      5. Discipline: "Discipline:Freie Partie" "Discipline:Dreiband" "Discipline:Einband"
      
      6. Date: 
         - Relativ: "Date:>heute-2w" (vor 2 Wochen), "Date:<heute+7" (in 7 Tagen)
         - Absolut: "Date:>2025-01-01" "Date:<2025-12-31"
         - Einheiten: d=Tage, w=Wochen, m=Monate
         
      7. Status: "Status:upcoming" "Status:finished" "Status:running"
      
      8. AND-Logik: Mehrere Filter mit Leerzeichen kombinieren
      
      BEISPIELE FÜR KORREKTE ÜBERSETZUNGEN:
      
      STÄDTE UND VEREINSNAMEN (Freitext verwenden!):
      - "Clubs aus Hamburg" → entity: "clubs", filters: "Hamburg"
      - "Spieler im BC Wedel" → entity: "players", filters: "BC Wedel"
      - "Turniere in Wedel" → entity: "tournaments", filters: "Wedel"
      - "Spieler aus München" → entity: "players", filters: "München"
      - "Vereine in Dortmund" → entity: "clubs", filters: "Dortmund"
      - "Spieler vom SC Berlin" → entity: "players", filters: "SC Berlin"
      
      REGIONEN/VERBÄNDE (Region-Filter verwenden):
      - "Clubs aus dem NBV" → entity: "clubs", filters: "Region:NBV"
      - "Spieler aus Bayern" → entity: "players", filters: "Region:BBV"
      - "Alle Spieler aus Westfalen" → entity: "players", filters: "Region:BVW"
      - "Turniere im Norddeutschen Verband" → entity: "tournaments", filters: "Region:NBV"
      - "Clubs in NRW" → entity: "clubs", filters: "Region:BVNRW"
      
      TURNIERE MIT LOCATION (Location-Filter verwenden):
      - "Turniere im BC Wedel" → entity: "tournaments", filters: "Location:BC Wedel"
      - "Turniere im BC Wedel 2025" → entity: "tournaments", filters: "Location:BC Wedel Season:2025/2026"
      - "NBV Turniere im BC Wedel" → entity: "tournaments", filters: "Region:NBV Location:BC Wedel"
      - "Dreiband im Billard-Centrum Hamburg" → entity: "tournaments", filters: "Discipline:Dreiband Location:Billard-Centrum Hamburg"
      
      WEITERE BEISPIELE:
      - "Dreiband Turniere 2024" → entity: "tournaments", filters: "Discipline:Dreiband Season:2024/2025"
      - "Turniere letzte 2 Wochen" → entity: "tournaments", filters: "Date:>heute-2w"
      - "Freie Partie heute" → entity: "tournaments", filters: "Discipline:Freie Partie Date:heute"
      - "Meyer Hamburg" → entity: "players", filters: "Meyer Hamburg"
      
      ANTWORTFORMAT (IMMER als gültiges JSON):
      {
        "entity": "tournaments|players|clubs|locations|regions|seasons|season_participations|parties|game_participations|seedings|party_games|disciplines",
        "filters": "die konstruierte Filter-Syntax",
        "confidence": 0-100 (Zahl),
        "explanation": "Kurze deutsche Erklärung was gefunden wird"
      }
      
      WICHTIGE REGELN:
      - Bei mehrdeutigen Anfragen wähle die wahrscheinlichste Entity
      - STÄDTE = Freitext (Hamburg, Berlin, München, Wedel, etc.)
      - SPIELORTE BEI TURNIEREN = Location-Filter (BC Wedel, Billard-Centrum Hamburg, etc.)
      - VEREINSNAMEN BEI SPIELERN/CLUBS = Freitext (BC Wedel, SC Berlin, BV Hamburg, etc.)
      - VERBÄNDE/BUNDESLÄNDER = Region-Filter (NBV, BVW, Bayern, NRW, etc.)
      - Region-Filter nur mit VERBANDS-Kürzeln (BVW, NBV, BBV - NICHT WL, HH, BE!)
      - Bei "aus dem NBV" oder "im Verband" → Region-Filter
      - Bei "Turniere im BC Wedel" → Location-Filter (Location:BC Wedel)
      - Bei "Spieler im BC Wedel" → Freitext (BC Wedel)
      - Bei "in Hamburg", "vom SC Berlin" → Freitext
      - Bundesländer-Mapping: Bayern→BBV, Hessen→HBU, NRW→BVNRW, Westfalen→BVW
      - NIEMALS Club: Filter verwenden - nur Freitext für Vereinsnamen!
      - Seasons im Format "2024/2025" (Slash verwenden!)
      - Bei Datums-Filtern relative Ausdrücke bevorzugen
      - Confidence unter 70 wenn Anfrage unklar ist
      - Explanation auf Deutsch und nutzerfreundlich
      - Entity-Namen EXAKT wie in der Liste verwenden
      - Mehrere Filter mit Leerzeichen kombinieren
    PROMPT
  end

  def system_prompt_en
    <<~PROMPT
      You are an intelligent search assistant for Carambus, a German billard management app.
      
      YOUR TASK:
      Convert natural language search queries into structured filter syntax.
      
      AVAILABLE ENTITIES (important: use exact names):
      #{entity_list}
      
      FILTER SYNTAX:
      1. Freetext: Simply enter text (e.g. "Meyer", "Hamburg", "Wedel" for names/cities)
      
      2. Season: "Season:2024/2025" or "Season:2023/2024"
      
      3. Region: ONLY use when an ASSOCIATION or STATE is EXPLICITLY meant!
         IMPORTANT: For city names (Hamburg, Berlin, Munich, etc.) → use freetext!
         Region filter only for:
         - Association names: "from NBV", "from BVW", "in the association"
         - Federal states: "from Bavaria", "in Hesse", "in North Rhine-Westphalia"
         
         Available associations:
         #{region_mappings}
      
      4. Location: "Location:BC Wedel" "Location:Billard-Centrum Hamburg"
         Use for tournament VENUE names (NOT for cities or club membership!)
      
      5. Discipline: "Discipline:Freie Partie" "Discipline:Dreiband" "Discipline:Einband"
      
      6. Date: 
         - Relative: "Date:>heute-2w" (2 weeks ago), "Date:<heute+7" (in 7 days)
         - Absolute: "Date:>2025-01-01" "Date:<2025-12-31"
         - Units: d=days, w=weeks, m=months
         
      7. Status: "Status:upcoming" "Status:finished" "Status:running"
      
      8. AND logic: Combine multiple filters with spaces
      
      EXAMPLES FOR CORRECT TRANSLATIONS:
      
      CITIES AND CLUB NAMES (use freetext!):
      - "Clubs from Hamburg" → entity: "clubs", filters: "Hamburg"
      - "Players at BC Wedel" → entity: "players", filters: "BC Wedel"
      - "Tournaments in Wedel" → entity: "tournaments", filters: "Wedel"
      - "Players from Munich" → entity: "players", filters: "München"
      - "Clubs in Dortmund" → entity: "clubs", filters: "Dortmund"
      - "Players from SC Berlin" → entity: "players", filters: "SC Berlin"
      
      REGIONS/ASSOCIATIONS (use Region filter):
      - "Clubs from NBV" → entity: "clubs", filters: "Region:NBV"
      - "Players from Bavaria" → entity: "players", filters: "Region:BBV"
      - "All players from Westphalia" → entity: "players", filters: "Region:BVW"
      - "Tournaments in Northern German Association" → entity: "tournaments", filters: "Region:NBV"
      - "Clubs in NRW" → entity: "clubs", filters: "Region:BVNRW"
      
      TOURNAMENTS WITH LOCATION (use Location filter):
      - "Tournaments at BC Wedel" → entity: "tournaments", filters: "Location:BC Wedel"
      - "Tournaments at BC Wedel 2025" → entity: "tournaments", filters: "Location:BC Wedel Season:2025/2026"
      - "NBV tournaments at BC Wedel" → entity: "tournaments", filters: "Region:NBV Location:BC Wedel"
      - "Dreiband at Billard-Centrum Hamburg" → entity: "tournaments", filters: "Discipline:Dreiband Location:Billard-Centrum Hamburg"
      
      MORE EXAMPLES:
      - "Dreiband tournaments 2024" → entity: "tournaments", filters: "Discipline:Dreiband Season:2024/2025"
      - "Tournaments last 2 weeks" → entity: "tournaments", filters: "Date:>heute-2w"
      - "Freie Partie today" → entity: "tournaments", filters: "Discipline:Freie Partie Date:heute"
      - "Meyer Hamburg" → entity: "players", filters: "Meyer Hamburg"
      
      RESPONSE FORMAT (ALWAYS as valid JSON):
      {
        "entity": "tournaments|players|clubs|locations|regions|seasons|season_participations|parties|game_participations|seedings|party_games|disciplines",
        "filters": "the constructed filter syntax",
        "confidence": 0-100 (number),
        "explanation": "Brief English explanation of what will be found"
      }
      
      IMPORTANT RULES:
      - For ambiguous queries, choose the most likely entity
      - CITIES = Freetext (Hamburg, Berlin, Munich, Wedel, etc.)
      - TOURNAMENT VENUES = Location filter (BC Wedel, Billard-Centrum Hamburg, etc.)
      - CLUB NAMES FOR PLAYERS/CLUBS = Freetext (BC Wedel, SC Berlin, BV Hamburg, etc.)
      - ASSOCIATIONS/STATES = Region filter (NBV, BVW, Bavaria, NRW, etc.)
      - Region filter only with ASSOCIATION abbreviations (BVW, NBV, BBV - NOT WL, HH, BE!)
      - For "from NBV" or "in the association" → Region filter
      - For "tournaments at BC Wedel" → Location filter (Location:BC Wedel)
      - For "players at BC Wedel" → Freetext (BC Wedel)
      - For "in Hamburg", "from SC Berlin" → Freetext
      - State mapping: Bavaria→BBV, Hesse→HBU, NRW→BVNRW, Westphalia→BVW
      - NEVER use Club: filter - only freetext for club names!
      - Seasons in format "2024/2025" (use slash!)
      - For date filters prefer relative expressions
      - Confidence below 70 if query is unclear
      - Explanation in English and user-friendly
      - Entity names EXACTLY as in the list
      - Combine multiple filters with spaces
    PROMPT
  end

  def entity_list
    ENTITY_MAPPING.map do |key, config|
      "- #{key}: #{config[:names].join(', ')} (Filter: #{config[:common_filters].join(', ')})"
    end.join("\n")
  end

  def region_mappings
    REGIONS.map do |code, names|
      main_name = names.first
      alternatives = names[1..-1].join(', ')
      "         Region:#{code} = #{main_name} (auch: #{alternatives})"
    end.join("\n")
  end

  def parse_ai_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    return error_response('Keine Antwort erhalten') if content.blank?

    data = JSON.parse(content)
    
    # Validate response structure
    unless data['entity'].present? && ENTITY_MAPPING.key?(data['entity'])
      return error_response("Unbekannte Entity: #{data['entity']}")
    end

    {
      success: true,
      entity: data['entity'],
      filters: data['filters'] || '',
      confidence: data['confidence']&.to_i || 50,
      explanation: data['explanation'] || 'Suchergebnis',
      path: send(ENTITY_MAPPING[data['entity']][:path_helper], sSearch: data['filters'])
    }
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error: #{e.message}\nContent: #{content}"
    error_response('Ungültige JSON-Antwort von KI')
  end

  def error_response(message)
    {
      success: false,
      error: message,
      confidence: 0
    }
  end

  def openai_configured?
    Rails.application.credentials.dig(:openai, :api_key).present?
  end

  # Path helper methods (delegates to Rails routes)
  def method_missing(method_name, *args, &block)
    if method_name.to_s.end_with?('_path')
      Rails.application.routes.url_helpers.send(method_name, *args, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_name.to_s.end_with?('_path') || super
  end
end

