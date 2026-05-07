# frozen_string_literal: true
# cc_lookup_serie — live-only (no Carambus mirror for CC serie detail endpoint).

module McpServer
  module Tools
    class LookupSerie < BaseTool
      tool_name "cc_lookup_serie"
      description "Live lookup of a CC tournament serie by serie_id, or list all series for a federation and season. " \
                  "No Carambus-side mirror for CC series — always queries CC directly."
      input_schema(
        properties: {
          serie_id: { type: "integer", description: "CC serie ID (omit to list all for fed_id + season)" },
          fed_id:   { type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides." },
          season:   { type: "string",  description: "Season name like '2025/2026'" }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(serie_id: nil, fed_id: nil, season: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `fed_id`") if fed_id.blank?

        client = cc_session.client_for
        if serie_id.present?
          res, _doc = client.get("showSerie", { serieId: serie_id, fedId: fed_id }, { session_id: cc_session.cookie })
          action = "showSerie (serie_id=#{serie_id})"
        else
          params = { fedId: fed_id }
          params[:season] = season if season.present?
          res, _doc = client.get("showSerienList", params, { session_id: cc_session.cookie })
          action = "showSerienList"
        end
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for #{action} (fed_id=#{fed_id}, status #{res.code})")
      end
    end
  end
end
