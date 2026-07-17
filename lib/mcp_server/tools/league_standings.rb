# frozen_string_literal: true

# cc_league_standings — DB-first Tabellenstand einer Liga (Plan 45-02).
#
# Der Pool-Sportwart fragt "wie steht die Tabelle?". Dieses Tool löst die Liga
# (region-scope-geprüft via BaseTool#resolve_league) und dispatcht disziplin-korrekt
# über den Branch (Pool/Snooker/Karambol) auf die bestehenden League#standings_table_*
# (League::StandingsCalculator). Dispatch über league.branch&.name (robuster als die
# View-Heuristik auf discipline.name, die z.B. "Dreiband" nicht als Karambol erkennt).
# public_url = echte öffentliche Spielplan-/Tabellen-Ansicht (45-01-Live-Befund).

module McpServer
  module Tools
    class LeagueStandings < BaseTool
      tool_name "cc_league_standings"
      description "Wann nutzen? Wenn der User den Tabellenstand einer Liga sehen will — 'wie steht die Pool-Bezirksliga?', 'Tabelle Liga X', Platzierungen/Punkte einer Mannschaftsliga. " \
                  "Was tippt der User typisch? 'Tabellenstand Kreisliga Pool', 'wie steht die Tabelle?'. " \
                  "Liga zuerst via cc_list_leagues finden (liefert league_id), dann hier league_id übergeben. " \
                  "Liefert den disziplin-korrekten Tabellenstand (Pool/Snooker/Karambol) aus der Carambus-DB. " \
                  "Output: Zeilen je Mannschaft (Platz, Spiele, gewonnen/unentschieden/verloren, Punkte, Differenz, Partien/Frames) + öffentlicher Liga-Link."
      input_schema(
        properties: {
          league_id: {type: "integer", description: "Carambus league_id (aus cc_list_leagues) — eindeutigster Weg."},
          cc_id: {type: "integer", description: "Optional: ClubCloud league cc_id (Alternative zu league_id)."},
          discipline: {type: "string", description: "Optional (Fallback ohne league_id): Branch-/Disziplin-Name ('Pool', 'Snooker', 'Karambol')."},
          season: {type: "string", description: "Optional (Fallback): Season-Name (z.B. '2025/2026'). Default = aktuelle Saison."},
          force_refresh: {type: "boolean", default: false, description: "Defensiver Re-Sync der Liga vor dem DB-Pfad (best effort)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(league_id: nil, cc_id: nil, discipline: nil, season: nil, force_refresh: false, server_context: nil)
        resolved = resolve_league(server_context, league_id: league_id, cc_id: cc_id, discipline: discipline, season: season)
        return resolved[:error] if resolved[:error]
        league = resolved[:league]

        if force_refresh
          begin
            league.scrape_single_league_from_cc(league_details: true)
          rescue => e
            Rails.logger.warn "[cc_league_standings] force_refresh failed: #{e.class}: #{e.message}"
          end
        end

        branch_name = league.branch&.name.to_s
        rows = case branch_name
        when "Pool" then league.standings_table_pool
        when "Snooker" then league.standings_table_snooker
        when "Karambol" then league.standings_table_karambol
        end

        meta = {
          league_id: league.id,
          cc_id: league.cc_id,
          league: league.name,
          discipline: league.discipline&.name,
          branch: branch_name.presence,
          season: league.season&.name,
          source: source_label(server_context, :db_mirror)
        }
        pub = public_league_url(league)
        meta[:public_url] = pub if pub

        if rows.nil?
          meta[:note] = "Tabellenstand wird für Branch #{branch_name.inspect} (noch) nicht berechnet (nur Pool/Snooker/Karambol). Öffentliche Ansicht nutzen."
          return text(JSON.generate(data: [], meta: meta))
        end

        data = Array(rows).map { |r| r.except(:team).merge(team_id: r[:team]&.id) }
        meta[:count] = data.length
        text(JSON.generate(data: data, meta: meta))
      end
    end
  end
end
