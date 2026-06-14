# frozen_string_literal: true

# cc_my_results — Phase 35-02 ("Mein Billard").
# Read-only: liefert dem EINGELOGGTEN, verknuepften Nutzer seine eigenen Spiel-Ergebnisse
# (Player#game_participations → Game#tournament). Self-scoped ueber server_context[:user_id]
# → current_player (KEIN player_id-Parameter). Reine DB-Reads.
# Registry-Stufe: BASE_READ_TOOLS (alle authentifizierten User).
module McpServer
  module Tools
    class MyResults < BaseTool
      tool_name "cc_my_results"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) deine eigenen Spiel-Ergebnisse / Spielberichte sehen willst.
        Was tippt der User typisch? "Meine Ergebnisse", "Wie lief mein letztes Spiel?", "Meine Spielberichte".
        Zeigt NUR DEINE Ergebnisse (self-scoped, kein fremder Spieler). Voraussetzung: einmalig via cc_link_my_player verknuepfen.
        Optional `limit` (Default 20). Sortierung: neueste zuerst.
      DESC
      input_schema(
        properties: {
          limit: {type: "integer", default: 20, description: "Maximale Anzahl Ergebnisse (Default 20)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(limit: 20, server_context: nil)
        player, gate = current_player(server_context)
        return gate if gate

        limit = limit.to_i
        limit = 20 if limit <= 0

        rows = player.game_participations.includes(game: :tournament).order(id: :desc).first(limit)

        data = rows.map do |gp|
          tournament = gp.game&.tournament
          row = {
            tournament: tournament&.title,
            points: gp.points,
            innings: gp.innings,
            hs: gp.hs,
            gd: gp.gd,
            result: gp.result,
            sets: gp.sets,
            role: gp.role
          }
          # Öffentlicher Turnier-Link: wenn Ergebnis-/Spielbericht-Details in der DB fehlen,
          # kann der Nutzer sie über die öffentliche CC-Ansicht einsehen (User-Direktive 2026-06-14).
          pub = tournament && public_tournament_url(tournament)
          row[:public_url] = pub if pub
          row
        end

        text(JSON.generate(
          data: data,
          meta: {player: player.fullname, count: data.length}
        ))
      rescue => e
        Rails.logger.warn "[MyResults.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
