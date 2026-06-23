# frozen_string_literal: true

# cc_my_party_games — Phase 45-03 ("meine Mannschaft").
# Read-only: liefert dem EINGELOGGTEN, verknüpften Nutzer ALLE seine Liga-Einzelpartien
# (PartyGame.player_a_id|player_b_id) in EINER Antwort — quer über alle Spieltage, scopebar
# je Liga. Self-scoped über server_context[:user_id] → current_player. Reine DB-Reads.
# Registry-Stufe: BASE_READ_TOOLS.
#
# 45-02-Live-Befund: cc_party_lineup ist pro-Party; "alle meine Spiele in Mannschaft X" ging
# nur Spieltag für Spieltag → dieses Tool aggregiert sie in einer Query.
module McpServer
  module Tools
    class MyPartyGames < BaseTool
      tool_name "cc_my_party_games"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) deine eigenen Liga-Einzelpartien sehen willst — alle deine Spiele in Mannschaftskämpfen, quer über die Spieltage.
        Was tippt der User typisch? "Meine Liga-Spiele", "Alle meine Spiele für Mannschaft X", "Gegen wen habe ich in der Liga gespielt?".
        Zeigt NUR DEINE Einzelpartien (self-scoped). Voraussetzung: einmalig via cc_link_my_player verknüpfen.
        Optional `league_id` (eine Liga/Mannschaft eingrenzen — aus cc_my_teams/cc_list_leagues), `season`, `limit` (Default 50). Sortierung: neueste zuerst.
        Für Mannschafts-/Liga-Zugehörigkeit nutze cc_my_teams.
      DESC
      input_schema(
        properties: {
          league_id: {type: "integer", description: "Optional: nur Partien dieser Liga (Carambus league_id, z.B. aus cc_my_teams)."},
          season: {type: "string", description: "Optional: Season-Name (z.B. '2025/2026'). Default = aktuelle Saison (außer league_id gesetzt)."},
          limit: {type: "integer", default: 50, description: "Maximale Anzahl Partien (Default 50)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(league_id: nil, season: nil, limit: 50, server_context: nil)
        player, gate = current_player(server_context)
        return gate if gate

        limit = limit.to_i
        limit = 50 if limit <= 0

        rows = PartyGame.where("party_games.player_a_id = :id OR party_games.player_b_id = :id", id: player.id)
          .includes(:discipline, :player_a, :player_b, party: [:league, :league_team_a, :league_team_b]).to_a
        rows.select! { |pg| pg.party.present? }

        if league_id.present?
          rows.select! { |pg| pg.party.league_id == league_id.to_i }
        else
          season_obj = season.present? ? effective_season(server_context, override: season) : effective_season(server_context)
          rows.select! { |pg| pg.party.league&.season_id == season_obj.id } if season_obj
        end

        # Neueste zuerst; Partien ohne Datum ans Ende.
        dated, undated = rows.partition { |pg| pg.party.date }
        rows = (dated.sort_by { |pg| pg.party.date }.reverse + undated).first(limit)

        data = rows.map do |pg|
          party = pg.party
          opponent = (pg.player_a_id == player.id) ? pg.player_b : pg.player_a
          {
            party_id: party.id,
            league: party.league&.name,
            day_seqno: party.day_seqno,
            date: party.date&.iso8601,
            discipline: pg.discipline&.name,
            opponent: opponent&.fullname,
            result: (pg.data.is_a?(Hash) ? (pg.data["result"] || pg.data[:result]) : nil),
            home: party.league_team_a&.name,
            guest: party.league_team_b&.name
          }
        end

        text(JSON.generate(
          data: data,
          source: source_label(server_context, :db_mirror), # Quelle (D-40-1): rechte-gegated, "" für read-only
          meta: {player: player.fullname, count: data.length, league_id: league_id, season: (league_id.blank? ? season : nil)}
        ))
      rescue => e
        Rails.logger.warn "[MyPartyGames.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
