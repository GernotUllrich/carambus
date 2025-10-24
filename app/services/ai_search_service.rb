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
      common_filters: ['Season', 'Region', 'Discipline', 'Date', 'Title']
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
      
      4. Discipline: "Discipline:Freie Partie" "Discipline:Dreiband" "Discipline:Einband"
      
      5. Date: 
         - Relativ: "Date:>heute-2w" (vor 2 Wochen), "Date:<heute+7" (in 7 Tagen)
         - Absolut: "Date:>2025-01-01" "Date:<2025-12-31"
         - Einheiten: d=Tage, w=Wochen, m=Monate
         
      6. Status: "Status:upcoming" "Status:finished" "Status:running"
      
      7. AND-Logik: Mehrere Filter mit Leerzeichen kombinieren
      
      BEISPIELE FÜR KORREKTE ÜBERSETZUNGEN:
      
      STÄDTE (Freitext verwenden!):
      - "Clubs aus Hamburg" → entity: "clubs", filters: "Hamburg"
      - "Turniere in Wedel" → entity: "tournaments", filters: "Wedel"
      - "Spieler aus München" → entity: "players", filters: "München"
      - "Vereine in Dortmund" → entity: "clubs", filters: "Dortmund"
      
      REGIONEN/VERBÄNDE (Region-Filter verwenden):
      - "Clubs aus dem NBV" → entity: "clubs", filters: "Region:NBV"
      - "Spieler aus Bayern" → entity: "players", filters: "Region:BBV"
      - "Alle Spieler aus Westfalen" → entity: "players", filters: "Region:BVW"
      - "Turniere im Norddeutschen Verband" → entity: "tournaments", filters: "Region:NBV"
      - "Clubs in NRW" → entity: "clubs", filters: "Region:BVNRW"
      
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
      - VERBÄNDE/BUNDESLÄNDER = Region-Filter (NBV, BVW, Bayern, NRW, etc.)
      - Region-Filter nur mit VERBANDS-Kürzeln (BVW, NBV, BBV - NICHT WL, HH, BE!)
      - Bei "aus dem NBV" oder "im Verband" → Region-Filter
      - Bei "in Hamburg" oder "aus Hamburg" (Stadt!) → Freitext
      - Bundesländer-Mapping: Bayern→BBV, Hessen→HBU, NRW→BVNRW, Westfalen→BVW
      - Seasons im Format "2024/2025" (Slash verwenden!)
      - Bei Datums-Filtern relative Ausdrücke bevorzugen
      - Confidence unter 70 wenn Anfrage unklar ist
      - Explanation auf Deutsch und nutzerfreundlich
      - Entity-Namen EXAKT wie in der Liste verwenden
      - Mehrere Filter mit Leerzeichen kombinieren
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

