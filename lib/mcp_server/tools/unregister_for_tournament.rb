# frozen_string_literal: true
# cc_unregister_for_tournament — Phase 8 Plan 08-02 (Mock-Implementation).
# Entfernt Spieler aus CC-Einzelturnier-Meldeliste (symmetrische Cleanup-Closure
# zu Phase-4 cc_register_for_tournament).
#
# Architektur (aus Phase-4 SNIFF + Phase-7 5-Step-Chain-Lesson, SUBSTRATE-08.md):
# Multi-Step CC-Workflow auf Meldeliste-Pfad `/admin/myclub/meldewesen/single/`:
#   1. editMeldelisteCheck (dla=1 Initial-Landing-Mode)  — Pre-Read; resolve Listen-Eintrags-ID
#   2. cc_remove.php (a=<Listen-Eintrags-ID || player_cc_id>) — REMOVE-Action
#   3. editMeldelisteCheck (firstEntry=1 Working-Session-Mode) — Re-Render (Phase-7 Inline-Patch v1)
#   4. editMeldelisteSave (a=..., save="1")  — Commit
#   5. editMeldelisteCheck (dla=1, optional)  — Read-Back-Verify
#
# Listen-Eintrags-ID-Resolver: Phase-4 SNIFF v1 zeigte `a=10413` (Listen-Eintrags-ID, NICHT
# player_cc_id 10031). Phase-4 SNIFF v2 / SUMMARY 04-04 widerlegte das partiell („CC trackt
# via Player-cc_id"). Defensiv: Resolver via Pre-Read-HTML-Parse, FALLBACK auf player_cc_id
# wenn Resolver nil liefert. Plan 08-03 Live-Test wird zeigen welcher Pfad real funktioniert.
#
# Sicherheitsnetz (Defense-in-Depth, Phase-4-DoD, 4-Schichten):
#   1. armed-Flag-Default false (Tool-Level)
#   2. Mock-Mode-Default in Tests (Test-Level — Tests injecten Mock-Client via _client_override)
#   3. Rails-env-Check (Server-Level — armed:true in production blockiert)
#   4. Detail-Dry-Run-Echo (Network-Level — alle ID-Werte explizit ausgegeben)
#
# Pre-Validation (analog Phase-7 RemoveFromTeilnehmerliste): player MUSS in Meldeliste sein.
# Use `cc_lookup_meldeliste_for_tournament` als vorgelagerter Tool-Call wenn meldeliste_cc_id
# unbekannt (D-08-F: Tool-Chaining-Pattern).

module McpServer
  module Tools
    class UnregisterForTournament < BaseTool
      tool_name "cc_unregister_for_tournament"
      description <<~DESC
        Remove a player from a ClubCloud Einzelturnier (single-tournament) Meldeliste.
        Symmetric closure to cc_register_for_tournament (Phase 4).
        Workflow: 5-Step CC POST chain (editMeldelisteCheck dla=1 → cc_remove → editMeldelisteCheck firstEntry=1 → editMeldelisteSave → optional Read-Back).
        Pass `armed: false` (default) for a dry-run that prints exact request details without modifying CC.
        Pass `armed: true` to actually unregister — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Requires `meldeliste_cc_id` (NOT tournament_cc_id) — get it from CC-Navigation OR use cc_lookup_meldeliste_for_tournament as preceding tool call.
        Listen-Eintrags-ID is resolved internally via Pre-Read step (dla=1 mode) with fallback to player_cc_id.
        Pre-Validation: player must be in target Meldeliste; otherwise abort with error.
        NICHT verwechseln mit `cc_remove_from_teilnehmerliste` (Phase 7 — wirkt auf Teilnehmerliste-Akkreditierung, anderer Pfad).
      DESC
      input_schema(
        properties: {
          fed_id:            { type: "integer", description: "ClubCloud federation ID (e.g. 20 for NBV). Optional — resolved via region lookup; ENV CC_FED_ID overrides." },
          branch_cc_id:      { type: "integer", description: "CC admin branch ID (e.g. 8 for Kegel). NOTE: admin-cc-id from HAR/Sniff." },
          season:            { type: "string",  description: "Season name like '2025/2026'." },
          meldeliste_cc_id:  { type: "integer", description: "CC meldelisteId of the Meldeliste to remove from. REQUIRED (use cc_lookup_meldeliste_for_tournament if unknown)." },
          player_cc_id:      { type: "integer", description: "CC player ID of the player to remove (Player.cc_id). Listen-Eintrags-ID is resolved internally." },
          club_cc_id:        { type: "integer", description: "CC club ID (Club.cc_id) — required for the form payload (clubId + selectedClubId)." },
          armed:             { type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC." },
          read_back:         { type: "boolean", default: true,  description: "If true (default) and armed:true, verify player_cc_id removed via post-save Pre-Read." }
        },
        required: ["branch_cc_id", "season", "meldeliste_cc_id", "player_cc_id", "club_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id: nil, branch_cc_id: nil, season: nil, meldeliste_cc_id: nil, player_cc_id: nil,
                    club_cc_id: nil, armed: false, read_back: true, server_context: nil)
        fed_id ||= default_fed_id

        err = validate_required!(
          { branch_cc_id: branch_cc_id, season: season, meldeliste_cc_id: meldeliste_cc_id,
            player_cc_id: player_cc_id, club_cc_id: club_cc_id },
          [:branch_cc_id, :season, :meldeliste_cc_id, :player_cc_id, :club_cc_id]
        )
        return err if err

        # Schicht 3 (Server-Level): Rails-env-Check
        if armed && Rails.env.production?
          return error("Live-CC writes are blocked in Rails production env via MCP. Run from development env.")
        end

        client = cc_session.client_for

        base_payload = {
          clubId: club_cc_id, fedId: fed_id, branchId: branch_cc_id,
          disciplinId: "*", catId: "*", season: season,
          meldelisteId: meldeliste_cc_id, firstEntry: 1, rang: 1,
          selectedClubId: club_cc_id
        }

        # Step 1: showCommittedMeldeliste (Pre-Read) — Player-Liste mit Listen-Eintrags-ID parsen.
        # KAPITALBEFUND Plan 08-03 Inline-Patch v1: editMeldelisteCheck zeigt nur Meldeliste-Metadaten
        # (mschluss, stag, meldelistenName) auf /admin/einzel/meldelisten/ — KEINE Player-Liste.
        # Korrekte Quelle für Player-Liste: showCommittedMeldeliste auf /admin/myclub/meldewesen/single/showMeldeliste.php
        # (gleicher Pfad wie cc_remove + editMeldelisteSave). Phase-4-Verifikations-Endpoint reused.
        # Pre-Read ist read-only — IMMER armed:true (sonst MockClient liefert nil bei writable_action; hier read_only:true OK).
        pre_payload = base_payload.except(:firstEntry, :rang, :selectedClubId).merge(sortOrder: "player")
        pre_res, pre_doc = client.post(
          "showCommittedMeldeliste",
          pre_payload,
          { armed: true, session_id: cc_session.cookie }
        )
        if cc_session.reauth_if_needed!(pre_doc)
          pre_res, pre_doc = client.post(
            "showCommittedMeldeliste", pre_payload,
            { armed: true, session_id: cc_session.cookie }
          )
        end
        return error("Unexpected nil response from CC (Pre-Read showCommittedMeldeliste).") if pre_res.nil?
        return error("CC rejected at Pre-Read: HTTP #{pre_res&.code}") if pre_res&.code != "200"

        # Resolve Listen-Eintrags-ID; Fallback: player_cc_id (Phase-4 SUMMARY 04-04 Konvention)
        listen_eintrags_id = resolve_listen_eintrags_id(pre_doc, player_cc_id)
        in_meldeliste = !listen_eintrags_id.nil? || player_in_meldeliste?(pre_doc, player_cc_id)

        unless in_meldeliste
          return error(
            "Player #{player_cc_id} not in Meldeliste #{meldeliste_cc_id}. " \
            "Already removed or never registered. Use `cc_register_for_tournament` first if needed."
          )
        end

        effective_id = listen_eintrags_id || player_cc_id

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo
        unless armed
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would unregister player_cc_id=#{player_cc_id} from meldeliste_cc_id=#{meldeliste_cc_id} \
            (club_cc_id=#{club_cc_id}, fed_id=#{fed_id}, branch_cc_id=#{branch_cc_id}, season=#{season}).
            Resolved Listen-Eintrags-ID: #{listen_eintrags_id.inspect} (fallback player_cc_id if nil)
            Effective `a=` value: #{effective_id}
            Workflow: 3-Step (showCommittedMeldeliste Pre-Read → cc_remove → editMeldelisteSave → optional showCommittedMeldeliste Read-Back).
            Pass armed:true to actually perform this unregister.
          DRY_RUN
        end

        # Step 2: cc_remove.php (removePlayerFromMeldeliste action)
        remove_payload = base_payload.merge(a: effective_id, d: "")
        rm_res, rm_doc = client.post(
          "removePlayerFromMeldeliste",
          remove_payload,
          { armed: armed, session_id: cc_session.cookie }
        )
        return error("Unexpected nil response from CC (cc_remove, armed mode).") if rm_res.nil?
        return error("CC rejected at cc_remove: #{parse_cc_error(rm_doc)} (HTTP #{rm_res&.code})") if rm_res&.code != "200"
        rm_parsed = parse_cc_error(rm_doc)
        return error("CC rejected at cc_remove: #{rm_parsed}") if rm_parsed && rm_parsed != "(no error)"

        # Step 3 (entfallen): Re-Render-Step war Phase-7-Pattern für /admin/einzel/meisterschaft/-Pfad.
        # Meldeliste-Pfad (/admin/myclub/meldewesen/single/) folgt Phase-4-Pattern (cc_add → save direkt;
        # KEIN Re-Render). Inline-Patch v1 Plan 08-03: Re-Render-Step entfernt, da Endpoint-Familie
        # unterschiedlich (myclub-Pfad braucht keinen Re-Render zwischen Mutation und Save).

        # Step 4: editMeldelisteSave — Commit
        save_payload = base_payload.merge(a: effective_id, save: "1")
        sv_res, sv_doc = client.post(
          "saveMeldeliste",
          save_payload,
          { armed: armed, session_id: cc_session.cookie }
        )
        return error("Unexpected nil response from CC (editMeldelisteSave, armed mode).") if sv_res.nil?
        return error("CC rejected at editMeldelisteSave: #{parse_cc_error(sv_doc)} (HTTP #{sv_res&.code})") if sv_res&.code != "200"
        sv_parsed = parse_cc_error(sv_doc)
        return error("CC rejected at editMeldelisteSave: #{sv_parsed}") if sv_parsed && sv_parsed != "(no error)"

        # Step 5 (optional): Read-Back-Verify via showCommittedMeldeliste (Inline-Patch v1, gleicher Endpoint wie Pre-Read).
        read_back_match = :skipped
        if read_back
          rb_payload = base_payload.except(:firstEntry, :rang, :selectedClubId).merge(sortOrder: "player")
          rb_res, rb_doc = client.post(
            "showCommittedMeldeliste",
            rb_payload,
            { armed: true, session_id: cc_session.cookie }
          )
          if rb_res&.code == "200"
            still_present = player_in_meldeliste?(rb_doc, player_cc_id)
            read_back_match = !still_present
            unless read_back_match
              return error(
                "Read-back mismatch: player_cc_id=#{player_cc_id} still in Meldeliste after save. " \
                "Save may have failed silently — inspect CC UI manually (cleanup may be needed)."
              )
            end
          else
            return error("Read-back failed (post-save Pre-Read HTTP #{rb_res&.code}). Save may have succeeded; inspect CC manually.")
          end
        end

        text(<<~OUT.strip)
          Unregistered player_cc_id=#{player_cc_id} (effective `a=`=#{effective_id}) from meldeliste_cc_id=#{meldeliste_cc_id}.
          Steps completed: showCommittedMeldeliste (Pre-Read) → cc_remove → editMeldelisteSave#{read_back ? " → showCommittedMeldeliste (Read-Back)" : ""}.
          read_back_match: #{read_back_match}
        OUT
      rescue StandardError => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # Helper: Parse Listen-Eintrags-ID aus Pre-Read-HTML.
      # Mock-HTML5-Format: <tr data-player-cc-id="10031" data-eintrags-id="10413">
      # Real-CC-Format: noch nicht final spezifiziert (Plan 08-03 Live-Test verifiziert)
      # Hybrid-Parser-Pattern aus Phase 6/7.
      def self.resolve_listen_eintrags_id(doc, player_cc_id)
        return nil if doc.nil?
        # Variante A: Mock-HTML5 mit data-Attributen
        row = doc.css("tr[data-player-cc-id='#{player_cc_id}']").first
        if row && row["data-eintrags-id"]
          return row["data-eintrags-id"].to_i
        end
        # Variante B: Real-CC anchor/form mit hidden a=<id> + label-Match (Plan 08-03 verifiziert)
        # Defensiv: nil zurückgeben falls Pattern nicht matcht → Tool nutzt player_cc_id-Fallback
        nil
      end

      # Helper: Check ob player_cc_id in Meldeliste enthalten ist (Pre-Validation + Read-Back-Verify).
      # Mock-HTML5-Format: <td class="meldeliste-player" data-player-cc-id="10031">
      # Real-CC-Format: Label-Text-Match auf "10031" (Plan 08-03 verifiziert)
      def self.player_in_meldeliste?(doc, player_cc_id)
        return false if doc.nil?
        # Variante A: Mock-HTML5 mit data-Attribut
        return true if doc.css("[data-player-cc-id='#{player_cc_id}']").any?
        # Variante B: einfacher Substring-Match auf Player-ID-Pattern (Real-CC HTML enthält die Zahl)
        # Defensiv: nur sehr spezifischer Pattern (vermeidet False-Positives)
        doc.css("td, span").any? { |el| el.text.strip == player_cc_id.to_s }
      rescue StandardError
        false
      end

      # Liefert String der CC-seitigen Fehler, oder "(no error)" bei sauberen Responses.
      # Reuse Phase-4 RegisterForTournament.parse_cc_error wäre möglich — eigene Kopie
      # für Eigenständigkeit (analog Phase-7 RemoveFromTeilnehmerliste).
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
