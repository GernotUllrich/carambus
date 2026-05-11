# frozen_string_literal: true

# cc_lookup_spielbericht — live-only (no Carambus mirror for CC Spielberichte raw data).

module McpServer
  module Tools
    class LookupSpielbericht < BaseTool
      tool_name "cc_lookup_spielbericht"
      description "Live lookup of a CC Spielbericht (match report) by spielbericht_id. " \
                  "No Carambus-side mirror for CC Spielberichte — always queries CC directly."
      input_schema(
        properties: {
          spielbericht_id: {type: "integer", description: "CC spielbericht ID"},
          fed_id: {type: "integer", description: "ClubCloud federation ID. Optional — resolved via region lookup (CC_REGION/Setting 'context', default 'NBV'); ENV CC_FED_ID overrides."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(spielbericht_id: nil, fed_id: nil, server_context: nil)
        fed_id ||= default_fed_id
        return error("Missing required parameter: `spielbericht_id`") if spielbericht_id.blank?
        return error("Missing required parameter: `fed_id`") if fed_id.blank?

        client = cc_session.client_for
        res, _doc = client.get("spielbericht", {spielberichtId: spielbericht_id, fedId: fed_id}, {session_id: cc_session.cookie})
        return error("CC live-lookup failed: HTTP #{res&.code}") if res&.code != "200"
        text("CC live response for spielbericht (spielbericht_id=#{spielbericht_id}, status #{res.code})")
      end
    end
  end
end
