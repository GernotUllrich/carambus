# frozen_string_literal: true

module LigaManager
  # Read-only Struktur-Fetcher für einen Verband (association_id) auf der LigaManager-API.
  # Liefert normalisierte Ruby-Hashes; KEINE Persistenz/kein Mapping auf Carambus-Records
  # (das ist Phase 8 Abgleich / Phase 9 Cutover). Generisch — association_id ist Parameter,
  # TBV (=1) ist nur der erste Mandant.
  class Scraper
    def initialize(association_id:, client: Client.new)
      @association_id = association_id
      @client = client
    end

    def association
      @client.get("associations/public-show", id: @association_id)
    end

    # Saisons des Verbands (status 2/3 = aktiv/abgeschlossen). Je game_type eine Saison.
    def seasons
      Array(@client.get("seasons", "status[]" => [2, 3]))
    end

    # Game-Types (=Branches); das Feld `disciplines` ist ein JSON-String → zu Hash parsen.
    def game_types
      Array(@client.get("game-types")).map do |gt|
        gt.merge("disciplines" => parse_json_field(gt["disciplines"]))
      end
    end

    def leagues(season_id)
      Array(@client.get("leagues", season_id: season_id))
    end

    # Einzel-Liga; discip_leg1/leg2 sind JSON-Strings → zu Hash parsen.
    def league(id)
      data = @client.get("leagues/#{id}")
      league = data.is_a?(Array) ? data.first : data
      return league unless league.is_a?(Hash)

      league.merge(
        "discip_leg1" => parse_json_field(league["discip_leg1"]),
        "discip_leg2" => parse_json_field(league["discip_leg2"])
      )
    end

    # Alle Vereine des Verbands, über die Pagination vollständig eingesammelt.
    def clubs
      collect_paginated("clubs/public", association_id: @association_id)
    end

    def teams(league_id)
      Array(@client.get("teams", league_id: league_id))
    end

    # --- Tiefen-/Result-Endpunkte (Plan 07-02) -----------------------------------------

    # Begegnungen einer Liga (mit matchpoints = Encounter-Gesamtstand).
    def match_plans(league_id)
      Array(@client.get("match-plan/public", league_id: league_id))
    end

    # Tabelle einer Liga (Array der Tabellenzeilen).
    def standings(league_id)
      Array(@client.get("leagues/#{league_id}/standings"))
    end

    # Spieler-Rangliste einer Liga (Hash je Disziplin → Array von Spielerzeilen).
    def ranking(league_id)
      data = @client.get("leagues/#{league_id}/ranking")
      data.is_a?(Hash) ? data : {}
    end

    # Spieler ("members") eines Vereins.
    def members(club_id)
      Array(@client.get("members/public", club_id: club_id, per_page: 200))
    end

    # Einzel-Spielbericht (HTML) einer Begegnung → strukturierte Einzelpartien.
    def match_report(matchplan_id)
      html = @client.get_html("results/public-view-by-matchplan", matchplan_id: matchplan_id)
      MatchReportParser.new(html).parse
    end

    private

    # clubs/public liefert (nach Envelope-Unwrap) {current_page,last_page,data:[...]} — alle Seiten holen.
    def collect_paginated(path, params)
      page = 1
      rows = []
      loop do
        inner = @client.get(path, params.merge(page: page))
        inner = {} unless inner.is_a?(Hash)
        rows.concat(Array(inner["data"]))
        break if page >= (inner["last_page"] || 1).to_i

        page += 1
      end
      rows
    end

    def parse_json_field(value)
      return value if value.is_a?(Hash) || value.is_a?(Array)
      return nil if value.nil? || value.to_s.strip.empty?

      JSON.parse(value)
    rescue JSON::ParserError
      nil
    end
  end
end
