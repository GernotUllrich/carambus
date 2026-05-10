# frozen_string_literal: true

# cc_list_players_by_name — DB-first Spieler-Suche per Namens-Fragment region-scoped.
#
# Walking-Skeleton-Use-Case (Phase 5): Turniermanager tippt im MCP-Client
# „Melde Gernot Ullrich, Wilfried Auel, Joshua Lorkowski an" — Claude Desktop
# muss diese Namen zu Player-IDs auflösen, ohne nach Vereinen zu fragen.
#
# Region-Filter via PlayerRanking-Existenz (Player.region_id ist 88% NULL,
# PlayerRanking ist autoritativ — Phase-2-Decision). Optionaler club_cc_id
# verengt zusätzlich auf SeasonParticipation. Limit 50; bei mehr Treffern
# soll der TM mit club_cc_id einschränken.
#
# Anders als cc_search_player (live-only via CC-suche-Endpoint) ist dieses
# Tool rein DB-first — kein CC-Call. Beide koexistieren: list_players_by_name
# = strukturierte Walking-Skeleton-Suche; search_player = Live-Escape-Hatch.

module McpServer
  module Tools
    class ListPlayersByName < BaseTool
      MAX_RESULTS = 50

      tool_name "cc_list_players_by_name"
      description "DB-first Spieler-Suche per Namens-Fragment in der Default-Region (CC_REGION). " \
                  "Liefert auch ohne Vereinsangabe Treffer; optional verengt club_cc_id auf einen Verein. " \
                  "Region-Filter via PlayerRanking-Existenz (Spieler ohne Ranking in der Region tauchen nicht auf). " \
                  "Max #{MAX_RESULTS} Treffer — bei mehr Treffern club_cc_id setzen. " \
                  "Für Live-CC-Suche siehe cc_search_player."
      input_schema(
        properties: {
          name: {type: "string", description: "Namens-Fragment (min 2 Zeichen). Match auf fl_name, firstname, lastname (case-insensitive ILIKE)."},
          club_cc_id: {type: "integer", description: "Optional: ClubCloud-cc_id eines Vereins zur Verengung."},
          shortname: {type: "string", description: "Region-shortname (z.B. 'NBV'). Optional — Default via CC_REGION/Setting 'context'."}
        },
        required: ["name"]
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(name: nil, club_cc_id: nil, shortname: nil, server_context: nil)
        return error("Missing required parameter: `name`") if name.blank?
        return error("Query too short: `name` must be at least 2 characters") if name.to_s.length < 2

        region = resolve_region(shortname: shortname)
        return error("Region not found. Provide shortname, or set CC_REGION/Setting 'context'.") if region.nil?

        club_obj = nil
        if club_cc_id.present?
          club_obj = Club.find_by(cc_id: club_cc_id.to_i)
          return error("Club not found for cc_id=#{club_cc_id}") if club_obj.nil?
        end

        escaped = ActiveRecord::Base.sanitize_sql_like(name.to_s)
        like = "%#{escaped}%"

        rel = Player
          .joins(:player_rankings)
          .where(player_rankings: {region_id: region.id})
          .where(
            "players.fl_name ILIKE :q OR players.firstname ILIKE :q OR players.lastname ILIKE :q",
            q: like
          )
          .distinct

        if club_obj
          rel = rel.joins(:season_participations).where(season_participations: {club_id: club_obj.id}).distinct
        end

        ordered = rel.order(:lastname, :firstname).limit(MAX_RESULTS)
        match_count = rel.count

        players = ordered.map { |p|
          {
            id: p.id,
            fl_name: p.fl_name,
            firstname: p.firstname,
            lastname: p.lastname,
            cc_id: p.cc_id,
            ba_id: p.ba_id
          }
        }

        text(JSON.generate(
          players: players,
          meta: {
            match_count: match_count,
            returned: players.length,
            limit: MAX_RESULTS,
            region: region.shortname,
            filter_basis: club_obj ? "name+club_cc_id" : "name",
            name: name,
            club_cc_id: club_cc_id
          }
        ))
      end

      def self.resolve_region(shortname:)
        if shortname.present?
          Region.find_by(shortname: shortname.to_s.upcase)
        else
          fallback_id = default_fed_id
          fallback_id ? RegionCc.find_by(cc_id: fallback_id)&.region : nil
        end
      end
    end
  end
end
