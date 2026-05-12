# frozen_string_literal: true

# cc_remove_from_teilnehmerliste — Phase 7 Plan 07-04 Inline-Patch (D-7-8).
# Entfernt Spieler aus der Teilnehmerliste eines Turniers (symmetrische Cleanup-Closure
# zu cc_assign_player_to_teilnehmerliste).
#
# Architektur (aus 07-02-SNIFF-OUTPUT.md): Multi-Step CC-Workflow:
#   1. editTeilnehmerlisteCheck — Pre-Read, liefert current Teilnehmerliste
#   2. removePlayer            — Single-Remove via teilnehmerId=<cc_id> (KEIN Array, anders als assignPlayer!)
#   3. editTeilnehmerlisteSave — Commit mit save="1" Sentinel
#   4. editTeilnehmerlisteCheck — optional Read-Back-Verify (player NICHT mehr im teilnehmerId-Select)
#
# Phase-7-Unterschiede zu assignPlayer:
#   - player_cc_id (Single, Integer) statt player_cc_ids (Array)
#   - Pre-Validation: player_cc_id MUSS in Teilnehmerliste sein (sonst error)
#   - Read-Back-Verify: player_cc_id NICHT mehr in Teilnehmerliste
#
# 4-Schichten-Sicherheitsnetz analog assign-Tool.

module McpServer
  module Tools
    class RemoveFromTeilnehmerliste < BaseTool
      tool_name "cc_remove_from_teilnehmerliste"
      description <<~DESC
        Entfernt einen Spieler aus der Teilnehmerliste eines Turniers (Rückzug nach Akkreditierung, Korrektur einer versehentlichen Übernahme).
        Workflow: Pre-Read (editTeilnehmerlisteCheck) → removePlayer (Single-Remove via teilnehmerId=) → editTeilnehmerlisteSave → optional Read-Back.
        Pass `armed: false` (default) for a dry-run that prints request details without modifying CC.
        Pass `armed: true` to actually remove — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Pass `tournament_cc_id` (= CC meisterschaftsId, REQUIRED) + `player_cc_id` (Single Integer, REQUIRED).
        Pre-Validation: player_cc_id MUSS in current Teilnehmerliste sein (sonst error).
        NICHT verwechseln mit `cc_unregister_for_tournament` (Phase 8 — wirkt auf Meldeliste, anderer Pfad) — dieses Tool wirkt auf Teilnehmerliste-Akkreditierung.
        Symmetrisches Cleanup-Tool zu cc_assign_player_to_teilnehmerliste (D-7-8).
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Tournament-cc_id (= CC meisterschaftsId). REQUIRED."},
          player_cc_id: {type: "integer", description: "Player-cc_id zum Entfernen. REQUIRED. Single (KEIN Array — removePlayer.php ist Single-Remove)."},
          armed: {type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC."},
          read_back: {type: "boolean", default: true, description: "If true (default) and armed:true, verify player_cc_id NOT in post-save Teilnehmerliste; raises error on mismatch."},
          fed_cc_id: {type: "integer"},
          branch_cc_id: {type: "integer"},
          season: {type: "string"},
          disciplin_id: {type: "string"},
          cat_id: {type: "string"}
        },
        required: ["tournament_cc_id", "player_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(tournament_cc_id: nil, player_cc_id: nil,
        fed_cc_id: nil, branch_cc_id: nil, season: nil,
        disciplin_id: nil, cat_id: nil,
        armed: false, read_back: true, server_context: nil)
        # L0a: Required-Validation
        err = validate_required!({tournament_cc_id: tournament_cc_id, player_cc_id: player_cc_id},
          %i[tournament_cc_id player_cc_id])
        return err if err

        # Schicht 3 (Server-Level): Rails-env-Check — armed:true in production blockiert.
        if armed && Rails.env.production?
          return error("Live-CC writes are blocked in Rails production env via MCP. Run from development env.")
        end

        # Reuse Phase-7 helpers from AssignPlayerToTeilnehmerliste (DRY — both tools share Teilnehmerliste logic)
        scope = AssignPlayerToTeilnehmerliste.resolve_scope_filters(tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)

        # Pre-Read via editTeilnehmerlisteCheck
        client = cc_session.client_for
        pre_read = AssignPlayerToTeilnehmerliste.pre_read_teilnehmerliste(client, tournament_cc_id, scope)
        return pre_read if pre_read.is_a?(MCP::Tool::Response)  # error envelope

        # Pre-Validation: player_cc_id muss in Teilnehmerliste sein
        current_ids = pre_read[:current_teilnehmer].map { |opt| opt[:cc_id] }
        unless current_ids.include?(player_cc_id)
          return error(
            "Player #{player_cc_id} not in Teilnehmerliste of tournament #{tournament_cc_id} (#{pre_read[:tournament_name]}). " \
            "Current Teilnehmerliste: #{current_ids.inspect}. " \
            "If player is in Meldeliste but not yet accreditated, use `cc_assign_player_to_teilnehmerliste` first."
          )
        end

        # Plan 10-05 Task 4 (Befund #8): Pre-Read war erfolgreich (Player ist in Teilnehmerliste verifiziert);
        # tournament_cc_id + player_cc_id sind User-Inputs → source: "override-param".
        pre_read_status = format_pre_read_status(
          verified: true,
          source: "override-param",
          warning: "tournament_cc_id=#{tournament_cc_id} + player_cc_id=#{player_cc_id} via User-Input; Pre-Read-Call hat die Existenz in Teilnehmerliste live verifiziert."
        )

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo
        unless armed
          player_label = pre_read[:current_teilnehmer].find { |opt| opt[:cc_id] == player_cc_id }&.[](:label) || "?"
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would remove player_cc_id=#{player_cc_id} (#{player_label}) from Teilnehmerliste of tournament_cc_id=#{tournament_cc_id} (#{pre_read[:tournament_name]}).
            teilnehmerliste_count_before: #{pre_read[:current_teilnehmer].size}
            teilnehmerliste_count_after:  #{pre_read[:current_teilnehmer].size - 1}
            Scope: fed_id=#{scope[:fedId]}, branch_cc_id=#{scope[:branchId]}, season=#{scope[:season]}, disciplin_id=#{scope[:disciplinId]}, cat_id=#{scope[:catId]}
            Workflow: removePlayer (Single-Remove via teilnehmerId=) → editTeilnehmerlisteSave → optional Read-Back.
            pre_read_verified: #{pre_read_status[:pre_read_verified]}
            pre_read_source: #{pre_read_status[:pre_read_source]}
            pre_read_warning: #{pre_read_status[:pre_read_warning]}
            Pass armed:true to actually perform this removal.
          DRY_RUN
        end

        # Armed=true: Multi-Step Save-Chain. Plan 07-04 Inline-Patch v2: Referer-Chaining.
        # Step 1: removePlayer (Single-Remove via teilnehmerId=).
        # Referer: kommt vom editTeilnehmerlisteCheck (Pre-Read).
        remove_payload = AssignPlayerToTeilnehmerliste.base_payload(tournament_cc_id, scope).merge(teilnehmerId: player_cc_id, referer: "/admin/einzel/meisterschaft/editTeilnehmerlisteCheck.php?")
        rm_res, rm_doc = client.post("removePlayer", remove_payload, {armed: armed, session_id: cc_session.cookie})
        if cc_session.reauth_if_needed!(rm_doc)
          rm_res, rm_doc = client.post("removePlayer", remove_payload, {armed: armed, session_id: cc_session.cookie})
        end
        return error("Unexpected nil response from CC (removePlayer, armed mode). MockClient may have rejected.") if rm_res.nil?
        return error("CC rejected at removePlayer: #{AssignPlayerToTeilnehmerliste.parse_cc_error(rm_doc)} (HTTP #{rm_res&.code})") if rm_res&.code != "200"
        rm_parsed = AssignPlayerToTeilnehmerliste.parse_cc_error(rm_doc)
        return error("CC rejected at removePlayer: #{rm_parsed}") if rm_parsed && rm_parsed != "(no error)"

        # Step 2 (Plan 07-04 Inline-Patch v2 — Risk A): Re-Render-Form-State.
        # Referer kommt vom removePlayer-Submit.
        recheck_payload = AssignPlayerToTeilnehmerliste.base_payload(tournament_cc_id, scope).merge(referer: "/admin/einzel/meisterschaft/removePlayer.php?")
        rc_res, _rc_doc = client.post("editTeilnehmerlisteCheck", recheck_payload, {armed: armed, session_id: cc_session.cookie})
        return error("Unexpected nil response from CC (editTeilnehmerlisteCheck re-render, armed mode).") if rc_res.nil?
        return error("CC rejected at editTeilnehmerlisteCheck re-render: HTTP #{rc_res&.code}") if rc_res&.code != "200"

        # Step 3: editTeilnehmerlisteSave — Commit.
        # Referer kommt vom editTeilnehmerlisteCheck (re-render).
        save_payload = AssignPlayerToTeilnehmerliste.base_payload(tournament_cc_id, scope).merge(save: "1", referer: "/admin/einzel/meisterschaft/editTeilnehmerlisteCheck.php?")
        sv_res, sv_doc = client.post("editTeilnehmerlisteSave", save_payload, {armed: armed, session_id: cc_session.cookie})
        return error("Unexpected nil response from CC (editTeilnehmerlisteSave, armed mode).") if sv_res.nil?
        return error("CC rejected at editTeilnehmerlisteSave: #{AssignPlayerToTeilnehmerliste.parse_cc_error(sv_doc)} (HTTP #{sv_res&.code})") if sv_res&.code != "200"
        sv_parsed = AssignPlayerToTeilnehmerliste.parse_cc_error(sv_doc)
        return error("CC rejected at editTeilnehmerlisteSave: #{sv_parsed}") if sv_parsed && sv_parsed != "(no error)"

        # Optional Read-Back (Schicht 4 Verify)
        read_back_match = :skipped
        if read_back
          rb = AssignPlayerToTeilnehmerliste.pre_read_teilnehmerliste(client, tournament_cc_id, scope)
          if rb.is_a?(Hash)
            actual_ids = rb[:current_teilnehmer].map { |opt| opt[:cc_id] }
            still_present = actual_ids.include?(player_cc_id)
            read_back_match = !still_present
            unless read_back_match
              return error(
                "Read-back mismatch: expected player_cc_id=#{player_cc_id} removed from Teilnehmerliste, " \
                "but still present. Save may have failed silently. Inspect CC UI manually (cleanup may be needed)."
              )
            end
          else
            return error("Read-back failed (post-save Pre-Read returned error). Save may have succeeded; inspect CC manually.")
          end
        end

        text(<<~OUT.strip)
          Removed player_cc_id=#{player_cc_id} from Teilnehmerliste of tournament_cc_id=#{tournament_cc_id} (#{pre_read[:tournament_name]}).
          teilnehmerliste_count_before: #{pre_read[:current_teilnehmer].size}
          teilnehmerliste_count_after:  #{pre_read[:current_teilnehmer].size - 1}
          Steps completed: removePlayer → editTeilnehmerlisteCheck (re-render) → editTeilnehmerlisteSave#{" → editTeilnehmerlisteCheck (read-back)" if read_back}.
          read_back_match: #{read_back_match}
          pre_read_verified: #{pre_read_status[:pre_read_verified]}
          pre_read_source: #{pre_read_status[:pre_read_source]}
          pre_read_warning: #{pre_read_status[:pre_read_warning]}
        OUT
      rescue => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end
    end
  end
end
