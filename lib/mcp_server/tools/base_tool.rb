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
        MCP::Tool::Response.new([{type: "text", text: message}], error: true)
      end

      # Construct a text response.
      def self.text(message)
        MCP::Tool::Response.new([{type: "text", text: message}])
      end

      # Manually validate that all required keys in the schema are present.
      # Returns nil on success, error response on failure.
      def self.validate_required!(args, required_keys)
        missing = required_keys.reject { |k| args[k.to_sym] || args[k.to_s] }
        return nil if missing.empty?
        error("Missing required parameter(s): #{missing.join(", ")}")
      end

      # Returns true if CARAMBUS_MCP_MOCK is set; tools should branch their CC-call paths.
      def self.mock_mode?
        ENV["CARAMBUS_MCP_MOCK"] == "1"
      end

      # Lazy CC-client accessor — Tools delegate to McpServer::CcSession (Plan 01 Task 2).
      def self.cc_session
        McpServer::CcSession
      end

      # Plan 10-05 Task 4 (Befund #8 D-10-03-5): Pre-Read-Verify-Status-Helper für Write-Tools.
      # Sportwart kann manuell eingegebene cc_id (meldeliste_cc_id, player_cc_id) nicht
      # selbständig verifizieren. Vorhandenes Pattern `read_back_match` zeigt nach-Schreib-Status,
      # NICHT vor-Schreib-Resolution. Helper gibt strukturierten Status zurück (verified/source/warning).
      #
      # source-Werte:
      #   "DB-resolver"      — cc_id aus DB-Beziehung resolved (z.B. TournamentCc.registration_list_cc)
      #   "live-CC-fallback" — cc_id via Pre-Read-CC-Call verifiziert (read-only, vor Mutation)
      #   "override-param"   — User-Override; KEINE Pre-Read-Verifikation (Vertrauens-Lücke)
      #
      # Verwendung in Write-Tools:
      #   result.merge(format_pre_read_status(verified: true, source: "DB-resolver"))
      #   result.merge(format_pre_read_status(verified: false, source: "override-param",
      #                                       warning: "meldeliste_cc_id=#{x} als Override ohne Pre-Read-Verify"))
      def self.format_pre_read_status(verified:, source:, warning: nil)
        status = {
          pre_read_verified: verified,
          pre_read_source: source
        }
        status[:pre_read_warning] = warning if warning
        status
      end

      # Plan 10-05.1 Task 1 (D-10-04-B/G Pre-Validation-First-Pattern):
      # Konvention: Tools definieren private `_validate_*`-Methoden, jede returnt:
      #   {name: "constraint_name", ok: true/false, reason: "specific msg if !ok"}
      # `run_validations` sammelt alle Results und liefert:
      #   {all_passed: bool, results: [...], failed_constraints: ["name1", ...]}
      #
      # Validations können entweder Hashes (sofort evaluiert) ODER Lambdas
      # (lazy-evaluated für conditional Pre-Read-Calls) sein.
      def self.run_validations(validations)
        results = validations.map { |v| v.respond_to?(:call) ? v.call : v }
        failed = results.reject { |r| r[:ok] }
        {
          all_passed: failed.empty?,
          results: results,
          failed_constraints: failed.map { |r| r[:name] }
        }
      end

      # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper):
      # Auto-Resolve club_cc_id aus club_name via cc_lookup_club (DRY für 3 Write-Tools).
      # Returns [resolved_cc_id, error_message] tuple — bei error: cc_id=nil + Diagnose-String.
      def self.resolve_club_cc_id_from_name(club_cc_id:, club_name:, server_context: nil)
        return [club_cc_id, nil] if club_cc_id.present?
        return [nil, nil] if club_name.blank?  # Both nil → caller-Validation handelt das

        result = McpServer::Tools::LookupClub.call(name: club_name, server_context: server_context)
        if result.error?
          return [nil, "Club-Lookup für '#{club_name}' fehlgeschlagen: #{result.content.first[:text]}"]
        end

        body = JSON.parse(result.content.first[:text])
        if body["cc_id"].nil?
          candidates_str = body["candidates"].map { |c| "#{c["name"]} (cc_id=#{c["cc_id"]})" }.join(", ")
          return [nil, "Mehrere Vereine passen zu '#{club_name}': #{candidates_str}. Bitte präziser angeben oder club_cc_id direkt."]
        end
        [body["cc_id"], nil]
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_club_cc_id_from_name] #{e.class}: #{e.message}"
        [nil, "Club-Auto-Resolve-Exception: #{e.class.name}"]
      end

      # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper):
      # Auto-Resolve player_cc_id aus player_name via cc_search_player (DRY für 3 Write-Tools).
      def self.resolve_player_cc_id_from_name(player_cc_id:, player_name:, server_context: nil)
        return [player_cc_id, nil] if player_cc_id.present?
        return [nil, nil] if player_name.blank?

        result = McpServer::Tools::SearchPlayer.call(query: player_name, server_context: server_context)
        if result.error?
          return [nil, "Player-Lookup für '#{player_name}' fehlgeschlagen: #{result.content.first[:text]}"]
        end

        body = JSON.parse(result.content.first[:text])
        if body["cc_id"].nil?
          candidates_str = body["candidates"].map { |c| "#{c["name"]} (cc_id=#{c["cc_id"]})" }.join(", ")
          return [nil, "Mehrere Spieler passen zu '#{player_name}': #{candidates_str}. Bitte präziser angeben oder player_cc_id direkt."]
        end
        [body["cc_id"], nil]
      rescue => e
        Rails.logger.warn "[BaseTool.resolve_player_cc_id_from_name] #{e.class}: #{e.message}"
        [nil, "Player-Auto-Resolve-Exception: #{e.class.name}"]
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
      rescue => e
        Rails.logger.warn "[BaseTool.default_fed_id] Region lookup failed: #{e.class}"
        nil
      end
    end
  end
end
