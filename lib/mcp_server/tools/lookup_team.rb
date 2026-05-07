# frozen_string_literal: true
# cc_lookup_team — live-only (no Carambus mirror for CC teams).

module McpServer
  module Tools
    class LookupTeam < BaseTool
      tool_name "cc_lookup_team"
      description "Live lookup of a ClubCloud team by team_id. " \
                  "No Carambus-side mirror exists for CC teams — always queries CC directly."
      input_schema(
        properties: {
          team_id: { type: "integer", description: "CC team ID" },
          fed_id:  { type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides." }
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(team_id: nil, fed_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `team_id`") if team_id.blank?
        return error("Missing required parameter: `fed_id`") if fed_id.blank?

        client = cc_session.client_for
        res, _doc = client.get("showTeam", { teamId: team_id, fedId: fed_id }, { session_id: cc_session.cookie })
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showTeam (team_id=#{team_id}, fed_id=#{fed_id}, status #{res.code})")
      end
    end
  end
end
