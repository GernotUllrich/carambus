# frozen_string_literal: true
# cc_finalize_teilnehmerliste — D-19 proof write tool (einziges Write-Tool in Phase 40).
# Wraps PATH_MAP['releaseMeldeliste']. Honoriert armed-flag dry-run-Konvention (D-03).
# Trust-CC-and-parse-error (D-11) für Permission-Fehler.
# Retries einmal nach transparentem Reauth (Plan 01 cc_session.reauth_if_needed!).

module McpServer
  module Tools
    class FinalizeTeilnehmerliste < BaseTool
      tool_name "cc_finalize_teilnehmerliste"
      description <<~DESC
        Finalize (release) a Meldeliste in ClubCloud, locking the participant list.
        After finalization, CC accepts result uploads for this tournament.
        Requires Club-Sportwart or higher CC role; CC will reject with a permission error otherwise.
        Pass `armed: false` (default) for a dry-run that only describes what would happen.
      DESC
      input_schema(
        properties: {
          fed_id:        { type: "integer", description: "ClubCloud federation ID (e.g. 20 for BCW)" },
          branch_id:     { type: "integer", description: "CC branch (e.g. 10 for Karambol)" },
          season:        { type: "string",  description: "Season name like '2025/2026'" },
          meldeliste_id: { type: "integer", description: "CC meldelisteId of the participant list" },
          armed:         { type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation" }
        },
        required: ["fed_id", "branch_id", "season", "meldeliste_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id: nil, branch_id: nil, season: nil, meldeliste_id: nil, armed: false, server_context: nil)
        err = validate_required!(
          { fed_id: fed_id, branch_id: branch_id, season: season, meldeliste_id: meldeliste_id },
          [:fed_id, :branch_id, :season, :meldeliste_id]
        )
        return err if err

        client = cc_session.client_for
        res, doc = client.post(
          "releaseMeldeliste",
          { branchId: branch_id, fedId: fed_id, season: season, meldelisteId: meldeliste_id, release: "" },
          { armed: armed, session_id: cc_session.cookie }
        )

        # Dry-run-Pfad: armed: false → RegionCc::ClubCloudClient#post gibt [nil, nil] zurück für Write-Actions
        return text("Would finalize Meldeliste #{meldeliste_id} for branch #{branch_id}, season #{season}.") unless armed

        # Armed-Pfad: res muss vorhanden und 200 sein
        if res.nil?
          return error("Unexpected nil response from CC (armed mode). MockClient may have rejected.")
        end

        # Reauth-Retry: Plan 01's cc_session.reauth_if_needed! erkennt Login-Redirect, loggt transparent neu ein
        if cc_session.reauth_if_needed!(doc)
          # Einmaliger Retry nach Reauth
          res, doc = client.post(
            "releaseMeldeliste",
            { branchId: branch_id, fedId: fed_id, season: season, meldelisteId: meldeliste_id, release: "" },
            { armed: armed, session_id: cc_session.cookie }
          )
        end

        if res&.code != "200"
          return error("CC rejected: #{parse_cc_error(doc)} (HTTP #{res&.code})")
        end

        # Prüfe ob doc eine eingebettete Fehler-Response enthält (CC gibt manchmal 200 mit Error-Div zurück)
        parsed = parse_cc_error(doc)
        return error("CC rejected: #{parsed}") if parsed && parsed != "(no error)"

        text("Finalized Meldeliste #{meldeliste_id} for branch #{branch_id}, season #{season}.")
      rescue StandardError => e
        # Defensiv — stacktrace niemals leaken (Pitfall 6 + Threat T-40-05-04)
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # Gibt einen String zurück der den CC-seitigen Fehler beschreibt, oder "(no error)" bei sauberen Responses.
      def self.parse_cc_error(doc)
        return "(no error)" if doc.nil?
        return "Session expired (login redirect)" if doc.css("form[action*='login']").any?
        err = doc.css("div.error, .errorMessage, .alert-danger").map(&:text).map(&:strip).reject(&:empty?).first
        return err if err
        "(no error)"
      end
    end
  end
end
