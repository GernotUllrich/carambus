# frozen_string_literal: true

# cc_league_schedule — DB-first Spielplan/Paarungen einer Liga (Plan 45-02).
#
# Wrappt League#schedule_by_rounds (gruppiert nach round_name; Liga ohne Runden → eine
# Gruppe). Je Party: Spieltag, Datum, Heim-/Gast-Mannschaft, Gastgeber, Ort, Ergebnis
# (party.data["result"], "x:y"). Region-scope-geprüft via resolve_league.

module McpServer
  module Tools
    class LeagueSchedule < BaseTool
      tool_name "cc_league_schedule"
      description "Wann nutzen? Wenn der User den Spielplan/die Paarungen einer Liga sehen will — 'wann spielt Mannschaft X?', 'Spielplan Liga Y', Termine/Ergebnisse der Spieltage. " \
                  "Was tippt der User typisch? 'Spielplan Kreisliga Pool', 'wann spielt …?', 'Paarungen'. " \
                  "Liga zuerst via cc_list_leagues finden (liefert league_id), dann hier league_id übergeben. " \
                  "Liefert die Paarungen gruppiert nach Runde mit Spieltag, Datum, Heim-/Gast-Mannschaft, Gastgeber und Ergebnis (falls gespielt) + öffentlichen Liga-Link."
      input_schema(
        properties: {
          league_id: {type: "integer", description: "Carambus league_id (aus cc_list_leagues) — eindeutigster Weg."},
          cc_id: {type: "integer", description: "Optional: ClubCloud league cc_id (Alternative zu league_id)."},
          discipline: {type: "string", description: "Optional (Fallback ohne league_id): Branch-/Disziplin-Name ('Pool', 'Snooker', 'Karambol')."},
          season: {type: "string", description: "Optional (Fallback): Season-Name (z.B. '2025/2026'). Default = aktuelle Saison."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(league_id: nil, cc_id: nil, discipline: nil, season: nil, server_context: nil)
        resolved = resolve_league(server_context, league_id: league_id, cc_id: cc_id, discipline: discipline, season: season)
        return resolved[:error] if resolved[:error]
        league = resolved[:league]

        grouped = league.schedule_by_rounds || {}
        rounds = grouped.map do |round, parties|
          {
            round: round.presence || "—",
            parties: Array(parties).map { |p| serialize_party(p) }
          }
        end
        party_count = rounds.sum { |r| r[:parties].length }

        meta = {
          league_id: league.id,
          cc_id: league.cc_id,
          league: league.name,
          season: league.season&.name,
          party_count: party_count,
          source: source_label(server_context, :db_mirror)
        }
        pub = public_league_url(league)
        meta[:public_url] = pub if pub

        text(JSON.generate(rounds: rounds, meta: meta))
      end

      def self.serialize_party(p)
        {
          party_id: p.id,
          day_seqno: p.day_seqno,
          date: p.date&.iso8601,
          team_a: p.league_team_a&.name,
          team_b: p.league_team_b&.name,
          host: p.host_league_team&.name,
          location: p.location&.name,
          result: party_result(p)
        }
      end

      def self.party_result(p)
        return nil unless p.data.is_a?(Hash)
        p.data["result"] || p.data[:result]
      end
    end
  end
end
