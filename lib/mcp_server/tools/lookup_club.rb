# frozen_string_literal: true

# cc_lookup_club — live-only (no Carambus mirror with CC club cc_id for the club list endpoint).

module McpServer
  module Tools
    class LookupClub < BaseTool
      tool_name "cc_lookup_club"
      description "Live lookup of CC clubs by federation. " \
                  "No Carambus-side mirror with full CC club list — always queries CC directly via showClubList."
      input_schema(
        properties: {
          fed_id: {type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."},
          branch_id: {type: "integer", description: "CC branch ID to filter clubs (optional)"}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(fed_id: nil, branch_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `fed_id`") if fed_id.blank?

        client = cc_session.client_for
        params = {fedId: fed_id}
        params[:branchId] = branch_id if branch_id.present?
        res, _doc = client.get("showClubList", params, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for showClubList (fed_id=#{fed_id}, status #{res.code})")
      end
    end
  end
end
