# frozen_string_literal: true

# cc_my_teams — Phase 45-03 ("meine Mannschaft").
# Read-only: liefert dem EINGELOGGTEN, verknüpften Nutzer seine Mannschafts-/Liga-
# Zugehörigkeiten (LeagueTeam via Player#seedings) + die nächste anstehende Party je
# Mannschaft. Self-scoped über server_context[:user_id] → current_player (KEIN player_id-
# Parameter). Reine DB-Reads. Registry-Stufe: BASE_READ_TOOLS.
#
# 45-02-Live-Befund: cc_my_results (game_participations) deckt nur Einzelturniere ab; die
# Mannschafts-Zugehörigkeit liegt in LeagueTeam→seedings → eigenes Tool nötig.
module McpServer
  module Tools
    class MyTeams < BaseTool
      tool_name "cc_my_teams"
      description <<~DESC
        Wann nutzen? Wenn DU (eingeloggter Nutzer) wissen willst, in welchen Mannschaften/Ligen du spielst — und wann deine nächste Liga-Begegnung ist.
        Was tippt der User typisch? "In welchen Mannschaften spiele ich?", "Meine Ligen", "Wann spielt meine Mannschaft als Nächstes?".
        Zeigt NUR DEINE Mannschaften (self-scoped, kein fremder Spieler). Voraussetzung: einmalig via cc_link_my_player verknüpfen.
        Default = aktuelle Saison; all_seasons:true zeigt alle Saisons. Je Mannschaft: Liga, Disziplin, Saison, öffentlicher Liga-Link und — falls vorhanden — die nächste anstehende Party.
        Für die einzelnen gespielten Partien nutze cc_my_party_games.
      DESC
      input_schema(
        properties: {
          all_seasons: {type: "boolean", default: false, description: "true = alle Saisons; Default false = nur aktuelle Saison."},
          season: {type: "string", description: "Optional: Season-Name (z.B. '2025/2026'). Übersteuert den Default."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(all_seasons: false, season: nil, server_context: nil)
        player, gate = current_player(server_context)
        return gate if gate

        season_obj = if all_seasons
          nil
        elsif season.present?
          effective_season(server_context, override: season)
        else
          effective_season(server_context)
        end

        teams = LeagueTeam.joins(:seedings).where(seedings: {player_id: player.id})
          .distinct.includes(league: [:discipline, :season]).to_a
        teams.select! { |t| t.league.present? }
        teams.select! { |t| t.league.season_id == season_obj.id } if season_obj

        data = teams.map do |t|
          league = t.league
          row = {
            team_id: t.id,
            team: t.name,
            league_id: league.id,
            league: league.name,
            discipline: league.discipline&.name,
            season: league.season&.name,
            next_party: next_party_for(t)
          }
          pub = public_league_url(league)
          row[:public_url] = pub if pub
          row
        end
        # Neueste Saison zuerst (falls all_seasons), dann Liganame.
        data.sort_by! { |r| [-(Season.find_by(name: r[:season])&.id || 0), r[:league].to_s] }

        text(JSON.generate(
          data: data,
          source: source_label(server_context, :db_mirror), # Quelle (D-40-1): rechte-gegated, "" für read-only
          meta: {player: player.fullname, count: data.length, season: season_obj&.name, all_seasons: all_seasons}
        ))
      rescue => e
        Rails.logger.warn "[MyTeams.call] #{e.class}: #{e.message}"
        error("Tool-Fehler: #{e.class.name} (Details im Server-Log).")
      end

      # Nächste anstehende Party (date >= heute) dieser Mannschaft (als Heim ODER Gast).
      def self.next_party_for(team)
        p = Party.where("league_team_a_id = :t OR league_team_b_id = :t", t: team.id)
          .where("date >= ?", Date.current).order(:date).first
        return nil unless p
        opp = (p.league_team_a_id == team.id) ? p.league_team_b : p.league_team_a
        {party_id: p.id, date: p.date&.iso8601, gegner: opp&.name, ort: p.location&.name}
      end
    end
  end
end
