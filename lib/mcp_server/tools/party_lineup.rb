# frozen_string_literal: true

# cc_party_lineup — DB-first Aufstellung/Einzelpartien einer Party (Plan 45-02).
#
# Eine Party (Mannschaftskampf) besteht aus party_games (Einzelpartien). Dieses Tool
# liefert die Aufstellung: je Einzelpartie seqno, Disziplin, Spieler A/B, Ergebnis
# (party_game.data["result"] — disziplin-abhängiger Label-Hash). Auffinden über party_id
# ODER league_id + (day_seqno|date). Region-scope-geprüft via resolve_league(party.league).

module McpServer
  module Tools
    class PartyLineup < BaseTool
      tool_name "cc_party_lineup"
      description "Wann nutzen? Wenn der User die Aufstellung/Einzelpartien eines Mannschaftskampfs sehen will — 'welche Aufstellung hatte Party X?', 'Einzelpartien am Spieltag …', wer gegen wen. " \
                  "Was tippt der User typisch? 'Aufstellung Party 332981', 'Einzelspiele am 20.09.', 'wer hat gespielt?'. " \
                  "Party finden: direkt per party_id (aus cc_league_schedule) ODER league_id + day_seqno/date. " \
                  "Liefert je Einzelpartie: Reihenfolge, Disziplin, Spieler A/B und Ergebnis + öffentlichen Liga-Link."
      input_schema(
        properties: {
          party_id: {type: "integer", description: "Carambus party_id (aus cc_league_schedule) — eindeutigster Weg."},
          league_id: {type: "integer", description: "Alternativ zur party_id: Liga (aus cc_list_leagues) — mit day_seqno ODER date."},
          cc_id: {type: "integer", description: "Optional: ClubCloud league cc_id (statt league_id, mit day_seqno/date)."},
          day_seqno: {type: "integer", description: "Spieltag-Nummer (mit league_id/cc_id)."},
          date: {type: "string", description: "Datum YYYY-MM-DD (mit league_id/cc_id)."},
          discipline: {type: "string", description: "Optional (Fallback-Liga-Auflösung): Branch-/Disziplin-Name."},
          season: {type: "string", description: "Optional (Fallback): Season-Name. Default = aktuelle Saison."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(party_id: nil, league_id: nil, cc_id: nil, day_seqno: nil, date: nil, discipline: nil, season: nil, server_context: nil)
        party = nil

        if party_id.present?
          party = Party.find_by(id: party_id)
          return error("Party nicht gefunden (party_id=#{party_id}).") if party.nil?
          # Region-Scope über die Liga der Party (kein Cross-Region-Leak).
          resolved = resolve_league(server_context, league_id: party.league_id)
          return resolved[:error] if resolved[:error]
        else
          resolved = resolve_league(server_context, league_id: league_id, cc_id: cc_id, discipline: discipline, season: season)
          return resolved[:error] if resolved[:error]
          league = resolved[:league]
          rel = league.parties
          if day_seqno.present?
            rel = rel.where(day_seqno: day_seqno)
          elsif date.present?
            d = begin
              Date.parse(date.to_s)
            rescue
              nil
            end
            return error("Datum nicht lesbar: #{date.inspect} (erwartet YYYY-MM-DD).") if d.nil?
            rel = rel.where("date::date = ?", d)
          else
            return error("Bitte party_id ODER league_id + (day_seqno ODER date) angeben.")
          end
          matches = rel.to_a
          return error("Keine Party gefunden (league_id=#{league.id}, day_seqno=#{day_seqno}, date=#{date}).") if matches.empty?
          if matches.size > 1
            listing = matches.map { |p| "party_id=#{p.id} #{p.league_team_a&.name} vs #{p.league_team_b&.name} (#{p.date&.to_date})" }.join("; ")
            return text("Mehrere Parties passen (#{matches.size}). Bitte party_id angeben: #{listing}")
          end
          party = matches.first
        end

        games = party.party_games.map do |pg|
          {
            seqno: pg.seqno,
            name: pg.name,
            discipline: pg.discipline&.name,
            player_a: pg.player_a&.fullname,
            player_b: pg.player_b&.fullname,
            result: (pg.data.is_a?(Hash) ? (pg.data["result"] || pg.data[:result]) : nil)
          }
        end

        meta = {source: source_label(server_context, :db_mirror), game_count: games.length}
        pub = public_league_url(party.league)
        meta[:public_url] = pub if pub

        text(JSON.generate(
          party: {
            id: party.id,
            day_seqno: party.day_seqno,
            date: party.date&.iso8601,
            team_a: party.league_team_a&.name,
            team_b: party.league_team_b&.name,
            host: party.host_league_team&.name,
            league: party.league&.name,
            result: (party.data.is_a?(Hash) ? (party.data["result"] || party.data[:result]) : nil)
          },
          games: games,
          meta: meta
        ))
      end
    end
  end
end
