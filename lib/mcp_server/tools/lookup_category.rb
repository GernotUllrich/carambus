# frozen_string_literal: true

# cc_lookup_category — live-only (no Carambus mirror for CC category detail endpoint).

module McpServer
  module Tools
    class LookupCategory < BaseTool
      tool_name "cc_lookup_category"
      description "Live lookup of a CC category by category_id or list all categories for a federation. " \
                  "No Carambus-side mirror for CC category detail — always queries CC directly."
      input_schema(
        properties: {
          category_id: {type: "integer", description: "CC category ID (omit to list all)"},
          fed_id: {type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(category_id: nil, fed_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `fed_id`") if fed_id.blank?

        client = cc_session.client_for
        if category_id.present?
          res, _doc = client.get("showCategory", {categoryId: category_id, fedId: fed_id}, {session_id: cc_session.cookie})
          action = "showCategory (category_id=#{category_id})"
        else
          res, _doc = client.get("showCategoryList", {fedId: fed_id}, {session_id: cc_session.cookie})
          action = "showCategoryList"
        end
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for #{action} (fed_id=#{fed_id}, status #{res.code})")
      end
    end
  end
end
