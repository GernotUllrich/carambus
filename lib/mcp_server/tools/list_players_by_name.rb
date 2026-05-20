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
      description "Wann nutzen? Wenn der User einen Spielernamen aus einer E-Mail sucht und den Verein nicht weiß. DB-first, regions-eindeutig. " \
                  "Was tippt der User typisch? 'Wer ist Hans Müller?', 'Schröder Spieler', 'finde Spieler mit Namen Schmidt'. " \
                  "DB-first Spieler-Suche per Namens-Fragment in der Default-Region (CC_REGION). " \
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

        # Plan 14-02.2 / B-3 + D-14-02-G: shortname-Override-Logik entfernt; strict
        # via effective_cc_region(server_context). Parameter im Schema bleibt (Removal in 14-02.4).
        if shortname.present? && shortname.to_s.upcase != effective_cc_region(server_context).to_s
          Rails.logger.warn "[cc_list_players_by_name] shortname-Override '#{shortname}' ignoriert; nutze User#cc_region='#{effective_cc_region(server_context)}'"
        end
        region_name = effective_cc_region(server_context)
        if region_name.blank?
          return scenario_config_missing_error
        end
        region = Region.find_by(shortname: region_name)
        return error("Region '#{region_name}' nicht in DB gefunden. Profile-Region prüfen.") if region.nil?

        club_obj = nil
        if club_cc_id.present?
          club_obj = Club.find_by(cc_id: club_cc_id.to_i)
          return error("Club not found for cc_id=#{club_cc_id}") if club_obj.nil?
        end

        # Plan 14-02.2 / Befund E-1: Token-Search statt naive Substring-ILIKE.
        tokens = tokenize_search_query(name)
        title_prefix = detect_title_prefix(name)

        rel = Player
          .joins(:player_rankings)
          .where(player_rankings: {region_id: region.id})
          .distinct

        rel = apply_token_search_filter(rel, tokens, %w[players.fl_name players.firstname players.lastname])

        if club_obj
          rel = rel.joins(:season_participations).where(season_participations: {club_id: club_obj.id}).distinct
        end

        ordered = rel.order(:lastname, :firstname).limit(MAX_RESULTS)
        match_count = rel.count

        # Plan 14-02.2 / E-2: cc_id als Primary; dbu_nr informativ-optional.
        players = ordered.map { |p|
          {
            cc_id: p.cc_id,
            fl_name: p.fl_name,
            firstname: p.firstname,
            lastname: p.lastname,
            dbu_nr: p.dbu_nr,
            ba_id: p.ba_id,
            id: p.id # Carambus Rails-id (für Power-User-Shortcuts wie check_player_discipline_experience)
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
            tokens: tokens,
            title_prefix_detected: title_prefix,
            club_cc_id: club_cc_id
          }.compact
        ))
      end
    end
  end
end
