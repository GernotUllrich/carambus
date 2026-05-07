# frozen_string_literal: true
# cc_search_player — live-only (no Carambus mirror for CC player search); uses suche PATH_MAP action.

module McpServer
  module Tools
    class SearchPlayer < BaseTool
      tool_name "cc_search_player"
      description "Live search for players in ClubCloud by name query. " \
                  "No Carambus-side mirror for CC player search — always queries CC directly via the suche action. " \
                  "Requires a query of at least 2 characters."
      input_schema(
        properties: {
          query:  { type: "string",  description: "Player name search query (minimum 2 characters)" },
          fed_id: { type: "integer", description: "ClubCloud federation ID to scope the search (optional). Defaults to ENV['CC_FED_ID'] if not provided." }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(query: nil, fed_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `query`") if query.blank?
        return error("Query too short: must be at least 2 characters") if query.to_s.length < 2

        client = cc_session.client_for
        params = { suche: query }
        params[:fedId] = fed_id if fed_id.present?
        res, _doc = client.get("suche", params, { session_id: cc_session.cookie })
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live search response for '#{query}' (status #{res.code})")
      end
    end
  end
end
