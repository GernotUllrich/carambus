# frozen_string_literal: true

# cc_my_tournaments — Phase 35-02 ("Mein Billard").
# Read-only: liefert dem EINGELOGGTEN, verknuepften Nutzer seine eigenen Turniere
# (Player#seedings, tournament_type:"Tournament" → tournament). Self-scoped ueber
# server_context[:user_id] → current_player (KEIN player_id-Parameter). Reine DB-Reads.
# Registry-Stufe: BASE_READ_TOOLS (alle authentifizierten User).
module McpServer
  module Tools
    class MyTournaments < BaseTool
      tool_name "cc_my_tournaments"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) deine eigenen Turniere sehen willst — woran du teilnimmst oder teilgenommen hast.
        Was tippt der User typisch? "Meine Turniere", "Wann spiele ich als Naechstes?", "Welche Turniere habe ich gespielt?".
        Zeigt NUR DEINE Turniere (self-scoped, kein fremder Spieler). Voraussetzung: einmalig via cc_link_my_player verknuepfen.
        Optional `season` (z.B. "2025/2026") und `limit` (Default 20). Sortierung: neueste zuerst.
      DESC
      input_schema(
        properties: {
          season: {type: "string", description: "Optional: Season-Name (z.B. '2025/2026'). Default = alle Saisons."},
          limit: {type: "integer", default: 20, description: "Maximale Anzahl Turniere (Default 20)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(season: nil, limit: 20, server_context: nil)
        player, gate = current_player(server_context)
        return gate if gate

        limit = limit.to_i
        limit = 20 if limit <= 0

        season_obj = season.present? ? effective_season(server_context, override: season) : nil

        seedings = player.seedings.where(tournament_type: "Tournament").includes(:tournament).to_a
        seedings.select! { |s| s.tournament.present? }
        seedings.select! { |s| s.tournament.season_id == season_obj.id } if season_obj

        # Neueste zuerst; Turniere ohne Datum ans Ende.
        dated = seedings.reject { |s| s.tournament.date.nil? }.sort_by { |s| s.tournament.date }.reverse
        undated = seedings.select { |s| s.tournament.date.nil? }
        rows = (dated + undated).first(limit)

        data = rows.map do |s|
          t = s.tournament
          row = {
            tournament_id: t.id,
            title: t.title,
            date: t.date&.iso8601,
            discipline: t.discipline&.name,
            season: t.season&.name,
            rank: s.rank,
            position: s.position,
            state: s.state
          }
          # Öffentlicher Turnier-Link (User-Direktive 2026-06-14) — für alle einsehbar.
          pub = public_tournament_url(t)
          row[:public_url] = pub if pub
          row
        end

        text(JSON.generate(
          data: data,
          source: source_label(server_context, :db_mirror), # Quelle (D-40-1): rechte-gegated, "" für read-only
          meta: {player: player.fullname, count: data.length, season: season_obj&.name}
        ))
      rescue => e
        Rails.logger.warn "[MyTournaments.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end
    end
  end
end
