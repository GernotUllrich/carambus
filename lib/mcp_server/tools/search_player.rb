# frozen_string_literal: true

# cc_search_player — DB-First-Refactor mit Disambiguation-Output (Plan 10-06 Task 2 / D-10-04-J).
#
# Vorher (live-only): thin live-CC-wrapper via suche-Action.
# Jetzt (DB-First): Player.where("firstname ILIKE ? OR lastname ILIKE ? OR ...") mit
# Disambiguation-Output-Pattern (analog cc_lookup_club aus Plan 10-05 Task 3 + cc_list_players_by_name
# aus Plan 05-02). Live-CC-Fallback via force_refresh:true.

module McpServer
  module Tools
    class SearchPlayer < BaseTool
      tool_name "cc_search_player"
      description "Player-Lookup (DB-first) via Name-Substring-Search auf Player.firstname/lastname. " \
                  "Wann nutzen? — Wenn Sportwart fragt 'gibt es Spieler XYZ?' oder du brauchst eine " \
                  "player_cc_id für ein Register-/Assign-Tool. Was tippt der User typisch? — 'lookup " \
                  "Spieler Nachtmann', 'wer ist Hans Schröder?', 'finde player Mustermann'. " \
                  "Suche per default in der Default-Region (CC_REGION/Setting 'context'); optional " \
                  "`region_shortname` für Cross-Region-Lookup. Optional `club_cc_id`-Filter scopen " \
                  "auf einen Verein. Output mit Disambiguation: 0 Treffer → Error mit attempted-Details; " \
                  "1 Treffer → top-level cc_id + candidates-Array; ≥2 Treffer → cc_id:null + candidates " \
                  "+ warning (Claude fragt User rück). force_refresh:true triggert Live-CC-Fallback."
      input_schema(
        properties: {
          query: {type: "string", description: "Player-Name Substring-Suche (case-insensitive ILIKE auf firstname/lastname/lastname+firstname); minimum 2 Zeichen"},
          region_shortname: {type: "string", description: "Optionaler Region-Filter (z.B. 'NBV'). Default: CC_REGION/Setting 'context'/'NBV'."},
          club_cc_id: {type: "integer", description: "Optionaler Club-Filter (Player.club_id → Club.cc_id Cross-Reference)"},
          force_refresh: {type: "boolean", default: false, description: "Live-CC-Fallback wenn DB nichts findet"},
          fed_id: {type: "integer", description: "Deprecated — Backwards-Compat; region_shortname bevorzugt"}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(query: nil, region_shortname: nil, club_cc_id: nil, force_refresh: false, fed_id: nil, server_context: nil)
        return error("Missing required parameter: `query`") if query.blank?
        return error("Query too short: must be at least 2 characters") if query.to_s.strip.length < 2

        region = resolve_region(region_shortname)
        escaped = ActiveRecord::Base.sanitize_sql_like(query.to_s.strip)

        scope = Player.all
        if region
          scope = scope.joins(:player_rankings).where(player_rankings: {region_id: region.id}).distinct
        end
        if club_cc_id.present?
          club = Club.find_by(cc_id: club_cc_id)
          scope = scope.where(club_id: club.id) if club
        end

        # Search auf firstname OR lastname OR "lastname, firstname" (composite display-name)
        matches = scope.where(
          "firstname ILIKE ? OR lastname ILIKE ? OR (lastname || ', ' || firstname) ILIKE ?",
          "%#{escaped}%", "%#{escaped}%", "%#{escaped}%"
        ).order(:lastname, :firstname).limit(50)

        candidates = matches.map { |p|
          {
            cc_id: p.cc_id,
            name: "#{p.lastname}, #{p.firstname}".strip.sub(/\A, /, ""),
            firstname: p.firstname,
            lastname: p.lastname,
            club_cc_id: p.club&.cc_id,
            club_name: p.club&.name
          }
        }

        # Live-CC-Fallback bei force_refresh:true UND 0 DB-Treffern
        if candidates.empty? && force_refresh
          fed_id ||= default_fed_id
          client = cc_session.client_for
          params = {suche: query}
          params[:fedId] = fed_id if fed_id.present?
          live_res, _live_doc = client.get("suche", params, {session_id: cc_session.cookie})
          if live_res&.code == "200"
            return text(JSON.generate(
              cc_id: nil,
              candidates: [],
              meta: {count: 0, region: region&.shortname, query: query, fallback: "live-CC", live_response: "HTTP #{live_res.code}"},
              warning: "DB-Search lieferte 0 Treffer; Live-CC-Fallback (suche-Action) wurde aufgerufen aber kein Parsing implementiert — Sportwart manuell in CC-UI nachschauen."
            ))
          end
        end

        if candidates.empty?
          return error(
            "Keine Spieler in Region '#{region&.shortname || "default"}' passen zu '#{query}'. " \
            "Versuche: (a) kürzeren Suchbegriff oder Vor-/Nachname-Variante, " \
            "(b) region_shortname-Override für Cross-Region, " \
            "(c) force_refresh:true für Live-CC-Lookup, " \
            "(d) club_cc_id-Filter entfernen falls gesetzt."
          )
        end

        body = {
          cc_id: (candidates.length == 1) ? candidates.first[:cc_id] : nil,
          candidates: candidates,
          meta: {
            count: candidates.length,
            region: region&.shortname,
            query: query,
            club_cc_id: club_cc_id
          }
        }
        body[:warning] = "#{candidates.length} Treffer gefunden — bitte Sportwart-Rückfrage: welcher Spieler?" if candidates.length > 1
        text(JSON.generate(body))
      end

      # Region-Resolver (analog cc_lookup_club).
      def self.resolve_region(override = nil)
        shortname = if override.present?
          override.to_s.upcase
        elsif ENV["CC_REGION"].present?
          ENV["CC_REGION"].upcase
        else
          context = (defined?(Setting) ? Setting.key_get_value("context") : nil).presence
          (context || "NBV").upcase
        end
        Region.find_by(shortname: shortname)
      rescue => e
        Rails.logger.warn "[cc_search_player.resolve_region] #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
