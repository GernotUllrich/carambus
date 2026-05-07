# frozen_string_literal: true
# BaseTool — Common Helpers für alle MCP-Tool-Subklassen.
# MCP::Tool#input_schema ist deskriptiv, NICHT runtime-validation (Pitfall 6) —
# daher manuell validieren und strukturierten Error zurückgeben.
#
# SDK-API findings (verified by Task 3 SDK-API smoke probe — see Plan 01 SUMMARY):
# - `tool_name`, `description`, `input_schema`, `annotations` are class-level DSL macros
# - `MCP::Tool::Response.new(content, error: bool)` exposes `#error?` (predicate!) and `#content`
#   ACHTUNG: SDK 0.15 hat `error?` NICHT `error` — Plans 04+05 müssen `response.error?` nutzen

module McpServer
  module Tools
    class BaseTool < MCP::Tool
      # Construct an error response in the SDK-canonical shape.
      def self.error(message)
        MCP::Tool::Response.new([{ type: "text", text: message }], error: true)
      end

      # Construct a text response.
      def self.text(message)
        MCP::Tool::Response.new([{ type: "text", text: message }])
      end

      # Manually validate that all required keys in the schema are present.
      # Returns nil on success, error response on failure.
      def self.validate_required!(args, required_keys)
        missing = required_keys.reject { |k| args[k.to_sym] || args[k.to_s] }
        return nil if missing.empty?
        error("Missing required parameter(s): #{missing.join(', ')}")
      end

      # Returns true if CARAMBUS_MCP_MOCK is set; tools should branch their CC-call paths.
      def self.mock_mode?
        ENV["CARAMBUS_MCP_MOCK"] == "1"
      end

      # Lazy CC-client accessor — Tools delegate to McpServer::CcSession (Plan 01 Task 2).
      def self.cc_session
        McpServer::CcSession
      end

      # Liefert die ClubCloud federation_id als Default-Fallback für Tools.
      # Priorität:
      #   1. ENV["CC_FED_ID"] (expliziter Override — höchste Prio)
      #   2. Region-Lookup via CC_REGION-ENV oder Setting context (kanonisch)
      #   3. nil — bestehender "Missing required parameter: fed_id"-Fehler bleibt erhalten
      #
      # Defensiv: rescued StandardError, damit Mock-Smoke-Tests ohne DB nicht crashen.
      def self.default_fed_id
        return ENV["CC_FED_ID"].to_i if ENV["CC_FED_ID"].present?

        context = ENV["CC_REGION"].presence ||
                  (defined?(Setting) ? Setting.key_get_value("context").presence : nil) ||
                  "NBV"
        region = Region.find_by(shortname: context.upcase)
        region&.region_cc&.cc_id
      rescue StandardError => e
        Rails.logger.warn "[BaseTool.default_fed_id] Region lookup failed: #{e.class}"
        nil
      end
    end
  end
end
