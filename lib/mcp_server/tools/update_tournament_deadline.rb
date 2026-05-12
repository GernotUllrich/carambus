# frozen_string_literal: true

# cc_update_tournament_deadline — Phase 6 Plan 06-03 Mock-Implementation.
# Verschiebt den Meldeschluss einer CC-Meldeliste (registration deadline).
#
# Architektur (aus 06-02-SNIFF-OUTPUT.md): 2-Step CC-Workflow + optional Read-Back:
#   1. showMeldeliste (showMeldeliste.php)      — Pre-Read, liefert aktuelle Werte aller 9 Felder
#   2. editMeldelisteCheck   (editMeldelisteCheck.php) — Edit-Form-Render, Server-Side-Prep für Save
#   3. editMeldelisteSave    (editMeldelisteSave.php)  — actual Save mit 9-Felder-Payload
#   4. showMeldeliste  (optional, armed:true)    — Read-Back zur Verifikation des neuen Datums
#
# NBV-only-Constraint (User-Direktive 2026-05-11): Carambus existiert heute nur in NBV-Region.
# Pre-Read parst ALLE 9 Felder direkt aus showMeldeliste-HTML (NICHT aus DB-Beziehung).
# DB-first-Resolver für tournament_cc_id → meldeliste_cc_id ist Best-Effort-Optimierung,
# keine Pflicht-Quelle. v0.3 CC-only-Mode kann den Resolver vollständig weglassen.
#
# Sicherheitsnetz (Defense-in-Depth, Phase-4-Pattern wiederverwendet):
#   1. armed-Flag-Default false (Tool-Level)
#   2. Mock-Mode-Default in Tests (Test-Level — CARAMBUS_MCP_MOCK=1)
#   3. Rails-env-Check (Server-Level — armed:true in production blockiert)
#   4. Detail-Dry-Run-Echo mit allen 8 Detail-Feldern inkl. mschluss_old/mschluss_new (Network-Level)
#
# Datum-Format-Asymmetrie (06-02-SNIFF-OUTPUT.md §4):
#   - POST-Body: ISO YYYY-MM-DD (z.B. mschluss=2026-06-02)
#   - Display:   deutsch DD.MM.YYYY (z.B. <b>02.06.2026</b>)
#   Tool-API akzeptiert ISO; Read-Back-Parser konvertiert von Deutsch zu ISO für Vergleich.
#
# Button-Names (06-02-SNIFF-OUTPUT.md §3): `nbut=` und `save=` sind PHP-Form-Submit-Buttons —
# Schlüssel zwingend mit-senden (leer geht nicht wegen client.post-blank?-Filter; "1" als Sentinel).

module McpServer
  module Tools
    class UpdateTournamentDeadline < BaseTool
      tool_name "cc_update_tournament_deadline"
      description <<~DESC
        Update the Meldeschluss (registration deadline) of a ClubCloud Meldeliste.
        Workflow: Pre-Read (showMeldeliste) → 2-Step CC POST (editMeldelisteCheck → editMeldelisteSave) → optional Read-Back.
        Pass `armed: false` (default) for a dry-run that prints exact request details
        (meldeliste ID, name, old/new deadline, federation, branch, season) without modifying CC.
        Pass `armed: true` to actually update — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Pass EITHER `tournament_cc_id` (resolves via Carambus DB if available — NBV-only optimization)
        OR `meldeliste_cc_id` (direct, no DB lookup — works in CC-only mode).
        `new_deadline` must be ISO format (YYYY-MM-DD); CC display will show it as DD.MM.YYYY.
        Pre-Read parses ALL 9 fields from CC response (scope filters + meldelistenName + mschluss + stag) —
        DB is best-effort optimization. If `read_back: true` (default), tool re-reads after save and
        raises an error on mismatch (cleanup hint).
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Optional: Carambus tournament_cc.cc_id; resolves meldeliste_cc_id via tournament_cc.registration_list_cc.cc_id (Phase 5 pattern). Either this or meldeliste_cc_id required."},
          meldeliste_cc_id: {type: "integer", description: "Optional: CC meldelisteId direct (override or CC-only mode). Either this or tournament_cc_id required."},
          new_deadline: {type: "string", description: "New Meldeschluss in ISO YYYY-MM-DD format (e.g. 2026-06-09). No backwards-date restriction."},
          fed_cc_id: {type: "integer", description: "Optional: CC federation ID (z.B. 20 für NBV). Hilft Pre-Read wenn DB-Linkage fehlt — Real CC braucht vollständige 6-Felder-Scope für showMeldeliste-Response. Default: ENV CC_FED_ID oder Region-Lookup."},
          branch_cc_id: {type: "integer", description: "Optional: CC admin branch ID (z.B. 8 für Kegel admin-cc-id). NOTE: admin-cc-id aus Sniff, NICHT public-Scraping. Hilft Pre-Read; bei DB-Linkage-Fehlen erforderlich."},
          season: {type: "string", description: "Optional: Season-Name wie '2025/2026' (CC-Format mit Slash). Hilft Pre-Read; bei DB-Linkage-Fehlen erforderlich."},
          disciplin_id: {type: "string", description: "Optional: CC disciplinId (Default '*' Wildcard — alle Disziplinen)."},
          cat_id: {type: "string", description: "Optional: CC catId (Default '*' Wildcard — alle Kategorien)."},
          armed: {type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC."},
          read_back: {type: "boolean", default: true, description: "If true (default) and armed:true, verify new deadline via post-save read; raises error on mismatch."}
        },
        required: ["new_deadline"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(tournament_cc_id: nil, meldeliste_cc_id: nil, new_deadline: nil,
        fed_cc_id: nil, branch_cc_id: nil, season: nil,
        disciplin_id: nil, cat_id: nil,
        armed: false, read_back: true, server_context: nil)
        # L0a: new_deadline required
        err = validate_required!({new_deadline: new_deadline}, [:new_deadline])
        return err if err

        # L0b: OneOf check — at least one identifier must be present
        if tournament_cc_id.nil? && meldeliste_cc_id.nil?
          return error("Missing required parameter: one of tournament_cc_id or meldeliste_cc_id must be provided.")
        end

        # L0c: Date-Format check (ISO YYYY-MM-DD)
        unless new_deadline.is_a?(String) && new_deadline.match?(/\A\d{4}-\d{2}-\d{2}\z/) && begin
          Date.iso8601(new_deadline)
        rescue
          false
        end
          return error("Invalid date format: new_deadline must be ISO YYYY-MM-DD (got: #{new_deadline.inspect}).")
        end

        # Schicht 3 (Server-Level): Rails-env-Check — armed:true in production blockiert.
        if armed && Rails.env.production?
          return error("Live-CC writes are blocked in Rails production env via MCP. Run from development env.")
        end

        # DB-first-Resolver (Best-Effort, NBV-only-Optimization; CC-only-Mode überspringt das).
        # Plan 10-05 Task 4 (Befund #8): Tracking welcher Pfad meldeliste_cc_id resolved hat.
        pre_read_source = if meldeliste_cc_id.present?
          "override-param"
        else
          "DB-resolver"
        end
        meldeliste_cc_id ||= resolve_meldeliste_cc_id(tournament_cc_id)
        if meldeliste_cc_id.nil?
          return error(
            "Cannot resolve meldeliste_cc_id from tournament_cc_id=#{tournament_cc_id} via Carambus DB. " \
            "Pass meldeliste_cc_id directly (find it in CC Meldelisten-Übersicht: /admin/einzel/meldelisten/)."
          )
        end

        # Pre-Read: showMeldeliste → parse all 9 fields. Funktioniert ohne DB (CC-only-fähig).
        # Plan 06-04 inline-Patch (Phase-4-Pattern): Real-CC erwartet vollständige 6-Felder-Scope-Payload
        # für showMeldeliste, sonst antwortet es mit Edit-Form-style Page ohne hidden-Inputs.
        # User-provided scope_filters (über Tool-Schema-Params) werden in den Pre-Read-Payload gemergt.
        scope_filters = {
          fedId: fed_cc_id || default_fed_id,
          branchId: branch_cc_id,
          disciplinId: disciplin_id || "*",
          catId: cat_id || "*",
          season: season
        }.compact
        client = cc_session.client_for
        pre_read = pre_read_meldeliste(client, meldeliste_cc_id, scope_filters)
        return pre_read if pre_read.is_a?(MCP::Tool::Response)  # error envelope

        # Plan 10-05 Task 4 (Befund #8): Pre-Read-Status-Helper. Pre-Read war erfolgreich
        # (sonst Early-Return oben), source je nach DB-Resolver vs Override.
        pre_read_status = format_pre_read_status(
          verified: true,
          source: pre_read_source,
          warning: (pre_read_source == "override-param") ? "meldeliste_cc_id=#{meldeliste_cc_id} als User-Override genutzt; Pre-Read-Call hat die Existenz live verifiziert." : nil
        )

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo — alle 8 Detail-Felder + mschluss_old/new.
        unless armed
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would update Meldeschluss for meldeliste_cc_id=#{meldeliste_cc_id} (#{pre_read[:meldelistenName]}).
            mschluss_old: #{pre_read[:mschluss_old]}
            mschluss_new: #{new_deadline}
            Scope: fed_id=#{pre_read[:fedId]}, branch_cc_id=#{pre_read[:branchId]}, season=#{pre_read[:season]}, disciplin_id=#{pre_read[:disciplinId]}, cat_id=#{pre_read[:catId]}, stag=#{pre_read[:stag]} (stag unchanged).
            Workflow: 2-Step POST (editMeldelisteCheck → editMeldelisteSave) + optional Read-Back via showMeldeliste.
            pre_read_verified: #{pre_read_status[:pre_read_verified]}
            pre_read_source: #{pre_read_status[:pre_read_source]}
            pre_read_warning: #{pre_read_status[:pre_read_warning]}
            Pass armed:true to actually perform this update.
          DRY_RUN
        end

        # Armed=true: 2-Step Save-Chain. Step 1: editMeldelisteCheck (Server-Side-Prep).
        # nbut: "1" als non-blank Sentinel (CC PHP prüft typisch isset, nicht Wert; client.post .reject(&:blank?) entfernt sonst).
        check_payload = {
          fedId: pre_read[:fedId], branchId: pre_read[:branchId],
          disciplinId: pre_read[:disciplinId], catId: pre_read[:catId],
          season: pre_read[:season], meldelisteId: meldeliste_cc_id,
          nbut: "1"
        }
        check_res, check_doc = client.post("editMeldelisteCheck", check_payload, {armed: armed, session_id: cc_session.cookie})
        if cc_session.reauth_if_needed!(check_doc)
          check_res, check_doc = client.post("editMeldelisteCheck", check_payload, {armed: armed, session_id: cc_session.cookie})
        end
        return error("Unexpected nil response from CC (editMeldelisteCheck, armed mode). MockClient may have rejected.") if check_res.nil?
        return error("CC rejected at editMeldelisteCheck: #{parse_cc_error(check_doc)} (HTTP #{check_res&.code})") if check_res&.code != "200"
        check_parsed = parse_cc_error(check_doc)
        return error("CC rejected at editMeldelisteCheck: #{check_parsed}") if check_parsed && check_parsed != "(no error)"

        # Step 2: editMeldelisteSave — actual write mit 9-Felder-Payload.
        # meldelistenName + stag MÜSSEN durchgereicht werden (D-5 aus 06-02 — sonst Datenverlust).
        save_payload = check_payload.except(:nbut).merge(
          meldelistenName: pre_read[:meldelistenName],
          mschluss: new_deadline,
          stag: pre_read[:stag],
          save: "1"
        )
        save_res, save_doc = client.post("editMeldelisteSave", save_payload, {armed: armed, session_id: cc_session.cookie})
        return error("Unexpected nil response from CC (editMeldelisteSave, armed mode).") if save_res.nil?
        return error("CC rejected at editMeldelisteSave: #{parse_cc_error(save_doc)} (HTTP #{save_res&.code})") if save_res&.code != "200"
        save_parsed = parse_cc_error(save_doc)
        return error("CC rejected at editMeldelisteSave: #{save_parsed}") if save_parsed && save_parsed != "(no error)"

        # Optional Read-Back (Schicht 4 Verify): re-read meldeliste, parse new mschluss, compare.
        # Plan 06-04 inline-Patch: Read-Back nutzt dieselben scope_filters wie Pre-Read.
        read_back_match = :skipped
        if read_back
          rb = pre_read_meldeliste(client, meldeliste_cc_id, scope_filters)
          if rb.is_a?(Hash)
            actual = rb[:mschluss_old]  # "current" deadline after save
            read_back_match = (actual == new_deadline)
            unless read_back_match
              return error(
                "Read-back mismatch: expected mschluss=#{new_deadline}, got #{actual.inspect}. " \
                "Save may have failed silently. Inspect CC UI manually (cleanup may be needed)."
              )
            end
          else
            return error("Read-back failed (post-save Pre-Read returned error). Save may have succeeded; inspect CC manually.")
          end
        end

        text(<<~OUT.strip)
          Updated Meldeschluss for meldeliste_cc_id=#{meldeliste_cc_id} (#{pre_read[:meldelistenName]}): #{pre_read[:mschluss_old]} → #{new_deadline}.
          Steps completed: editMeldelisteCheck → editMeldelisteSave#{" → showMeldeliste (read-back)" if read_back}.
          read_back_match: #{read_back_match}
          pre_read_verified: #{pre_read_status[:pre_read_verified]}
          pre_read_source: #{pre_read_status[:pre_read_source]}
          pre_read_warning: #{pre_read_status[:pre_read_warning]}
        OUT
      rescue => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # DB-first-Resolver: tournament_cc.registration_list_cc.cc_id (Phase 5 Plan 05-01 pattern).
      # Best-Effort — kein Block bei DB-Lücke (NBV-only-Boundary; CC-only-Mode überspringt das).
      def self.resolve_meldeliste_cc_id(tournament_cc_id)
        return nil unless tournament_cc_id
        tournament_cc = TournamentCc.find_by(cc_id: tournament_cc_id)
        tournament_cc&.registration_list_cc&.cc_id
      rescue => e
        Rails.logger.warn "[UpdateTournamentDeadline.resolve_meldeliste_cc_id] DB-resolver failed: #{e.class}"
        nil
      end

      # Pre-Read: fetch showMeldeliste, parse all 9 fields from response HTML.
      # Returns Hash with keys [:fedId, :branchId, :disciplinId, :catId, :season, :meldelisteId,
      # :meldelistenName, :mschluss_old, :stag] — or error response on HTTP/parse failure.
      # NBV-only-Boundary: parses directly from HTML, no DB-Beziehung used.
      #
      # scope_filters (Plan 06-04 inline-Patch): optional Hash mit Scope-Keys
      # ({fedId:, branchId:, disciplinId:, catId:, season:}); wenn gegeben, in den Pre-Read-Payload
      # gemergt. Real CC braucht das — antwortet sonst mit Edit-Form-Page ohne hidden-Inputs.
      # Bei MockClient ist scope_filters NoOp (Mock-Response immer rich, unabhängig von Payload).
      def self.pre_read_meldeliste(client, meldeliste_cc_id, scope_filters = {})
        # Plan 06-04 inline-Patch: scope_filters in payload mergen (Real-CC-Anforderung).
        # MockClient ignoriert die Extra-Keys (legacy Mock-Tests bleiben grün).
        payload = {meldelisteId: meldeliste_cc_id}.merge(scope_filters)
        res, doc = client.post("showMeldeliste", payload, {armed: true, session_id: cc_session.cookie})
        if cc_session.reauth_if_needed!(doc)
          res, doc = client.post("showMeldeliste", payload, {armed: true, session_id: cc_session.cookie})
        end
        return error("Pre-Read failed: showMeldeliste returned HTTP #{res&.code}") if res.nil? || res&.code != "200"

        parsed = parse_meldeliste_state(doc)
        return parsed unless parsed.is_a?(Hash)

        # Plan 06-04 inline-Patch (Fallback-Layer): leere Hash-Werte mit User-provided scope_filters auffüllen,
        # falls Real-CC trotz vollständiger Pre-Read-Payload manche hidden-Inputs auslässt.
        scope_filters.each do |key, value|
          if parsed[key].nil? || parsed[key].to_s.empty?
            parsed[key] = value.to_s
          end
        end
        parsed
      rescue => e
        error("Pre-Read parse failed: #{e.class.name} (#{e.message})")
      end

      # Parse 9 fields from showMeldeliste response HTML.
      # Handles BOTH formats:
      #   - Mock convention: HTML5 inputs (`<input type="date" name="mschluss" value="2026-05-26">`)
      #   - Real CC display: German format in `<b>` after label cell (`<td>Meldeschluss:</td><td><b>26.05.2026</b></td>`)
      def self.parse_meldeliste_state(doc)
        return nil unless doc

        # Hidden inputs — always parseable (both Mock + real CC structure them identically)
        hidden = {}
        doc.css('input[type="hidden"]').each { |i| hidden[i["name"]] = i["value"] }

        # mschluss: HTML5 date input (Mock) → fallback to <b>DD.MM.YYYY</b> after "Meldeschluss" (real CC)
        mschluss_input = doc.css('input[type="date"][name="mschluss"]').first
        mschluss_old = if mschluss_input
          mschluss_input["value"]
        else
          extract_german_date_after_label(doc, "Meldeschluss")
        end

        # stag: same dual-format pattern
        stag_input = doc.css('input[type="date"][name="stag"]').first
        stag = if stag_input
          stag_input["value"]
        else
          extract_german_date_after_label(doc, "Stichtag")
        end

        # meldelistenName: text input (Mock) → fallback to <b>NAME</b> after "Meldeliste" (real CC)
        name_input = doc.css('input[name="meldelistenName"]').first
        meldelisten_name = if name_input
          name_input["value"]
        else
          extract_text_after_label(doc, "Meldeliste")
        end

        {
          fedId: hidden["fedId"],
          branchId: hidden["branchId"],
          disciplinId: hidden["disciplinId"],
          catId: hidden["catId"],
          season: hidden["season"],
          meldelisteId: hidden["meldelisteId"],
          meldelistenName: meldelisten_name,
          mschluss_old: mschluss_old,
          stag: stag
        }
      end

      # Extract `<b>DD.MM.YYYY</b>` after a labeled `<td>` cell. Converts to ISO YYYY-MM-DD.
      # Returns nil if pattern not found.
      # Plan 06-04 inline-Patch: starts-with → exakter Label-Match mit ":" Suffix.
      # Grund: starts-with matchte versehentlich die äußere Container-<td>, deren text() den gesamten
      # Tabellen-Inhalt enthält ("Meldeliste:NDM Endrunde...Meldeschluss:26.05.2026...").
      # Mit exakter Gleichheit auf "Meldeschluss:" trifft XPath nur die Leaf-Label-Cell.
      def self.extract_german_date_after_label(doc, label)
        label_td = doc.xpath("//td[normalize-space(.) = '#{label}:']").first
        return nil unless label_td
        sibling = label_td.xpath("following-sibling::td//b").first
        return nil unless sibling
        text = sibling.text.strip
        if text =~ /\A(\d{2})\.(\d{2})\.(\d{4})\z/
          "#{$3}-#{$2}-#{$1}"
        else
          # If not German format, return as-is (could already be ISO from a Mock variant)
          text
        end
      end

      # Extract `<b>TEXT</b>` after a labeled `<td>` cell.
      # Plan 06-04 inline-Patch: starts-with → exakter Label-Match (analog extract_german_date_after_label).
      def self.extract_text_after_label(doc, label)
        label_td = doc.xpath("//td[normalize-space(.) = '#{label}:']").first
        return nil unless label_td
        sibling = label_td.xpath("following-sibling::td//b").first
        sibling&.text&.strip
      end

      # CC-Error-Parser (analog cc_register_for_tournament): scan for error divs / login redirect.
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
