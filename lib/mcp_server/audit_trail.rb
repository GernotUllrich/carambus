# frozen_string_literal: true

# Plan 10-05.1 Task 1 (D-10-04-D): JSON-Lines-Audit-Trail für jeden armed:true-Call.
#
# Architektur-Pattern aus Plan 10-04 Strategischem Reframe:
# - Phase-4-Schicht-3 (Production-Block) deprecated → Tool wird selbst zum Sicherheitsnetz
#   via Pre-Validation-First-Pattern (D-10-04-B).
# - Audit-Trail-Pflicht (D-10-04-D): jeder armed:true erzeugt strukturierten Log-Eintrag
#   für Forensik + Cleanup-Routing bei Live-Datenschäden.
#
# Storage: JSON-Lines (append-only) in log/mcp-audit-trail.log.
# Defensive: rescue StandardError; Logger-Failure DARF Tool nicht crashen.
#
# 7-Feld-Schema per D-10-04-D-Spec:
#   1. zeitpunkt (ISO-8601 UTC)
#   2. operator (CC-Login-User aus Session, "unknown" falls nicht verfügbar)
#   3. tool (name+version)
#   4. payload (vollständig inkl. cc_ids)
#   5. pre_validation_results (alle Constraints + PASS/FAIL pro Constraint)
#   6. read_back_status ("match" | "mismatch" | "skipped" | nil)
#   7. result ("success" | "cc-error" | "exception" | etc.)

require "json"
require "fileutils"

module McpServer
  module AuditTrail
    def self.log_path
      Rails.root.join("log", "mcp-audit-trail.log").to_s
    end

    # Writes a single audit-trail entry: persistiert parallel zu JSON-Lines-File UND DB-Tabelle.
    # v0.3 Plan 13-05 (D-13-01-D): user_id-Param + McpAuditTrail-DB-Insert (Defense-in-Depth).
    # JSON-Lines-File bleibt SOURCE-OF-TRUTH-Fallback falls DB nicht erreichbar.
    # Returns the entry hash on success, nil on defensive failure.
    def self.write_entry(tool_name:, operator:, payload:, pre_validation_results:, read_back_status:, result:, user_id: nil)
      normalized_operator = operator.to_s.empty? ? "unknown" : operator.to_s

      entry = {
        zeitpunkt: Time.current.utc.iso8601,
        operator: normalized_operator,
        tool: tool_name.to_s,
        payload: payload,
        pre_validation_results: pre_validation_results,
        read_back_status: read_back_status,
        result: result,
        user_id: user_id
      }

      # 1. JSON-Lines-File-Write (Backwards-Compat aus Plan 10-05.1 — bleibt unverändert)
      FileUtils.mkdir_p(File.dirname(log_path))
      File.open(log_path, "a") do |f|
        f.write(JSON.generate(entry) + "\n")
      end

      # 2. DB-Insert (NEU für v0.3 Plan 13-05 / D-13-01-D Multi-User-Filtering).
      # Defensive separates rescue damit DB-Failure JSON-Lines-Erfolg nicht invalidiert.
      begin
        McpAuditTrail.create!(
          user_id: user_id,
          operator: normalized_operator,
          tool_name: tool_name.to_s,
          payload: payload,
          pre_validation_results: pre_validation_results,
          read_back_status: read_back_status,
          result: result
        )
      rescue => e
        # Defense-in-Depth: DB-Failure ≠ Tool-Crash; JSON-Lines bleibt einziger Eintrag.
        Rails.logger.warn "[McpServer::AuditTrail] DB-Insert failed (defensive — JSON-Lines bleibt): #{e.class}: #{e.message}"
      end

      entry
    rescue => e
      # Defensive: Logger-Failure darf den Tool-Call nicht zum Crash bringen.
      # Plan 10-04 D-10-04-D Architektur-Pattern: Tool > Audit-Logger in der Priorität.
      Rails.logger.warn "[McpServer::AuditTrail] write_entry failed (defensive): #{e.class}: #{e.message}"
      nil
    end
  end
end
