# frozen_string_literal: true

# cc_my_ranking — Phase 35-02 ("Mein Billard").
# Read-only: liefert dem EINGELOGGTEN, verknuepften Nutzer seine eigenen Ranglisten-Eintraege
# (Player#player_rankings → discipline/season). Self-scoped ueber server_context[:user_id]
# → current_player (KEIN player_id-Parameter). Reine DB-Reads.
# Registry-Stufe: BASE_READ_TOOLS (alle authentifizierten User).
module McpServer
  module Tools
    class MyRanking < BaseTool
      tool_name "cc_my_ranking"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) deine eigene Rangliste / Spielklasse sehen willst.
        Was tippt der User typisch? "Meine Rangliste", "Wo stehe ich?", "Meine Spielklasse", "Mein Generaldurchschnitt".
        Zeigt NUR DEINE Rankings (self-scoped, kein fremder Spieler). Voraussetzung: einmalig via cc_link_my_player verknuepfen.
        Optional `discipline` (Branch-/Discipline-Name, z.B. "Dreiband"), `season` (z.B. "2024/2025") und `limit` (Default 10). Sortierung: neueste Saison zuerst.
      DESC
      input_schema(
        properties: {
          discipline: {type: "string", description: "Optional: Branch-Name ('Karambol', 'Pool') oder Discipline-Name ('Dreiband') oder Discipline-ID."},
          season: {type: "string", description: "Optional: Season-Name (z.B. '2024/2025'). Default = alle Saisons."},
          limit: {type: "integer", default: 10, description: "Maximale Anzahl Ranking-Eintraege (Default 10)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(discipline: nil, season: nil, limit: 10, server_context: nil)
        player, gate = current_player(server_context)
        return gate if gate

        limit = limit.to_i
        limit = 10 if limit <= 0

        rel = player.player_rankings.includes(:discipline, :season).order(season_id: :desc)

        if discipline.present?
          discipline_ids, = resolve_discipline_or_branch(discipline)
          rel = rel.where(discipline_id: discipline_ids) if discipline_ids.present?
        end

        if season.present?
          season_obj = effective_season(server_context, override: season)
          rel = rel.where(season_id: season_obj.id) if season_obj
        end

        rows = rel.first(limit)

        data = rows.map do |pr|
          {
            discipline: pr.discipline&.name,
            season: pr.season&.name,
            rank: pr.rank,
            gd: pr.gd,
            quote: pr.quote,
            balls: pr.balls,
            innings: pr.innings,
            points: pr.points,
            player_class: player_class_name(pr.player_class_id)
          }
        end

        text(JSON.generate(
          data: data,
          meta: {player: player.fullname, count: data.length}
        ))
      rescue => e
        Rails.logger.warn "[MyRanking.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      # player_class-Assoziation ist auf PlayerRanking auskommentiert → Name best-effort.
      # PlayerClass hat nur `shortname` (kein `name`).
      def self.player_class_name(player_class_id)
        return nil if player_class_id.blank?
        PlayerClass.find_by(id: player_class_id)&.shortname
      rescue => e
        Rails.logger.warn "[MyRanking.player_class_name] #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
