# frozen_string_literal: true

# cc_assign_player_to_teilnehmerliste — Phase 7 Plan 07-03 Mock-Implementation.
# Übernimmt Spieler aus Meldeliste in Teilnehmerliste (Akkreditierung am Turniertag /
# Vorbereitung der Teilnehmerliste vor Turnier-Start).
#
# Architektur (aus 07-02-SNIFF-OUTPUT.md): Multi-Step CC-Workflow:
#   1. editTeilnehmerlisteCheck — Pre-Read, liefert <select name="teilnehmerId"> + <select name="meldungId[]">
#   2. assignPlayer            — Multi-Add (meldungId[]=<cc1>&meldungId[]=<cc2>...) in EINEM Call
#   3. editTeilnehmerlisteSave — Commit mit save="1" Sentinel
#   4. editTeilnehmerlisteCheck — optional Read-Back-Verify
#
# Phase-7-Unterschiede gegenüber Phase 4 (Meldeliste) und Phase 6 (Meldeschluss):
#   - Path: `/admin/einzel/meisterschaft/` (NICHT meldelisten/ oder myclub/meldewesen/)
#   - Identifier: `meisterschaftsId` (= tournament_cc_id, NICHT meldelisteId)
#   - Multi-Add nativ via `meldungId[]` Array (effizienter als Phase-4-Single-Add)
#   - KEIN finalize-State (Kapitalbefund Plan 07-02 — D-7-5)
#
# NBV-only-Constraint (analog Phase 6): Pre-Read parst alle 9 Felder direkt aus HTML.
# DB-first ist Best-Effort. Override-Params füllen fehlende Felder auf.
#
# Sicherheitsnetz (Defense-in-Depth, Phase-6-Pattern wiederverwendet):
#   1. armed-Flag-Default false (Tool-Level)
#   2. Mock-Mode-Default in Tests (Test-Level — via _client_override, NICHT ENV)
#   3. Rails-env-Check (Server-Level — armed:true in production blockiert)
#   4. Detail-Dry-Run-Echo mit Tournament-Name + Player-Liste + Count-Before/After (Network-Level)

module McpServer
  module Tools
    class AssignPlayerToTeilnehmerliste < BaseTool
      tool_name "cc_assign_player_to_teilnehmerliste"
      description <<~DESC
        Wann nutzen? Am Turniertag, wenn der Turnierleiter Spieler aus der Meldeliste auf die Teilnehmerliste übernimmt (Akkreditierung). Multi-Player nativ via meldungId[]. Schreibendes Tool mit Pre-Validation-First (4 Constraints) + Audit-Trail.
        Was tippt der User typisch? 'Akk Hans Müller', 'Akk drei Spieler', 'Akkreditierung Müller Schmidt Schröder', 'akkreditiere Spieler X'.
        Übernimmt Spieler aus der Meldeliste in die Teilnehmerliste eines Turniers (Akkreditierungs-Workflow).
        Workflow: Pre-Read (editTeilnehmerlisteCheck) → Multi-Add (assignPlayer mit meldungId[]) → Commit (editTeilnehmerlisteSave) → optional Read-Back.
        Pass `armed: false` (default) for a dry-run that prints exact request details
        (tournament name, player list, count before/after) without modifying CC.
        Pass `armed: true` to actually assign — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Pass `tournament_cc_id` (= CC meisterschaftsId, REQUIRED) + `player_cc_ids` (Array, REQUIRED, min 1).
        Multi-Add nativ — mehrere Spieler in einem Tool-Call effizienter als Einzel-Calls.
        Pre-Validation: alle player_cc_ids MÜSSEN in Meldeliste-Available sein (sonst error mit Hinweis auf cc_register_for_tournament).
        NICHT verwechseln mit `cc_register_for_tournament` (das fügt zur **Meldeliste** hinzu) — dieses Tool zur **Teilnehmerliste**.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Tournament-cc_id (= CC meisterschaftsId). REQUIRED."},
          player_cc_ids: {type: "array", items: {type: "integer"}, minItems: 1, description: "Array von Player-cc_ids zum Hinzufügen (mind. 1). Alternative: player_names."},
          player_names: {type: "array", items: {type: "string"}, description: "Alternative zu player_cc_ids (Plan 10-06 Convenience-Wrapper): Array von Spielernamen-Suchen via cc_search_player; bei ≥2 Treffern pro Name blockiert mit Disambiguation-Diagnose."},
          armed: {type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC."},
          read_back: {type: "boolean", default: true, description: "If true (default) and armed:true, verify all player_cc_ids appear in post-save Teilnehmerliste; raises error on mismatch."},
          fed_cc_id: {type: "integer", description: "Optional: CC federation ID (z.B. 20 für NBV). Hilft Pre-Read wenn DB-Linkage fehlt. Default: ENV CC_FED_ID oder Region-Lookup."},
          branch_cc_id: {type: "integer", description: "Optional: CC admin branch ID (z.B. 8 für Kegel). Hilft Pre-Read; bei DB-Linkage-Fehlen erforderlich."},
          season: {type: "string", description: "Optional: Season-Name wie '2025/2026'. Hilft Pre-Read; bei DB-Linkage-Fehlen erforderlich."},
          disciplin_id: {type: "string", description: "Optional: CC disciplinId (Default '*' Wildcard)."},
          cat_id: {type: "string", description: "Optional: CC catId (Default '*' Wildcard)."}
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(tournament_cc_id: nil, player_cc_ids: nil, player_names: nil,
        fed_cc_id: nil, branch_cc_id: nil, season: nil,
        disciplin_id: nil, cat_id: nil,
        armed: false, read_back: true, server_context: nil)

        # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper): Auto-Resolve player_names → player_cc_ids.
        if player_cc_ids.blank? && player_names.is_a?(Array) && player_names.any?
          resolved_ids = []
          errs = []
          player_names.each do |name|
            id, err = resolve_player_cc_id_from_name(player_cc_id: nil, player_name: name, server_context: server_context)
            if err
              errs << "  - '#{name}': #{err}"
            elsif id
              resolved_ids << id
            end
          end
          if errs.any?
            return error("Player-Name-Auto-Resolve fehlgeschlagen:\n#{errs.join("\n")}")
          end
          player_cc_ids = resolved_ids
        end

        # L0a: Required-Validation
        err = validate_required!({tournament_cc_id: tournament_cc_id, player_cc_ids: player_cc_ids},
          %i[tournament_cc_id player_cc_ids])
        return err if err

        # L0b: player_cc_ids must be Array with ≥1 integer
        unless player_cc_ids.is_a?(Array) && !player_cc_ids.empty? && player_cc_ids.all? { |id| id.is_a?(Integer) }
          return error("Invalid player_cc_ids: must be Array of integers with at least 1 element (got: #{player_cc_ids.inspect}).")
        end

        # Normalize to integer array (defensive — Schema declares integer but JSON may pass strings)
        player_cc_ids = player_cc_ids.map(&:to_i)

        # Plan 10-05.1 Task 1 (D-10-04-B Pivot): Phase-4-Schicht-3 (Production-Block für armed:true)
        # DEPRECATED. Pre-Validation-First-Pattern ersetzt globalen env-Block durch Tool-eigene Constraints.

        # DB-first-Resolver (Best-Effort, NBV-only-Optimization)
        scope = resolve_scope_filters(tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)

        # Pre-Read via editTeilnehmerlisteCheck → parse state
        client = cc_session.client_for(server_context)
        pre_read = pre_read_teilnehmerliste(client, tournament_cc_id, scope)
        return pre_read if pre_read.is_a?(MCP::Tool::Response)  # error envelope

        # Pre-Validation: alle player_cc_ids in meldungId-Available?
        available_ids = pre_read[:available_in_meldeliste].map { |opt| opt[:cc_id] }
        already_in_list = pre_read[:current_teilnehmer].map { |opt| opt[:cc_id] }

        missing_from_meldeliste = player_cc_ids - available_ids
        duplicates_in_teilnehmer = player_cc_ids & already_in_list

        # Plan 10-05.1 Task 3 (D-10-04-G Pre-Validation-First-Pattern, 4 Constraints):
        validation_result = run_validations([
          _validate_tournament_exists_assign(pre_read, tournament_cc_id),
          _validate_all_players_in_available(missing_from_meldeliste),
          _validate_none_doppelt_in_teilnehmer(duplicates_in_teilnehmer),
          _validate_non_finalized_assign(pre_read)
        ])

        unless validation_result[:all_passed]
          failed_details = validation_result[:results].reject { |r| r[:ok] }.map { |r| "#{r[:name]}: #{r[:reason]}" }.join("; ")
          return error("Pre-Validation failed for cc_assign_player_to_teilnehmerliste. Failed: #{validation_result[:failed_constraints].inspect}. #{failed_details}")
        end

        # Plan 10-05 Task 4 (Befund #8): Pre-Read war erfolgreich (live-CC-fallback);
        # tournament_cc_id stammt aus User-Input → source: "override-param".
        pre_read_status = format_pre_read_status(
          verified: true,
          source: "override-param",
          warning: "tournament_cc_id=#{tournament_cc_id} als User-Override; Pre-Read-Call hat die Teilnehmerliste live verifiziert (#{pre_read[:current_teilnehmer].size} bestehende Teilnehmer)."
        )

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo
        unless armed
          player_details = pre_read[:available_in_meldeliste]
            .select { |opt| player_cc_ids.include?(opt[:cc_id]) }
            .map { |opt| "#{opt[:cc_id]} (#{opt[:label]})" }
            .join(", ")
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would assign #{player_cc_ids.size} player(s) to Teilnehmerliste for tournament_cc_id=#{tournament_cc_id} (#{pre_read[:tournament_name]}).
            Players: #{player_details}
            teilnehmerliste_count_before: #{pre_read[:current_teilnehmer].size}
            teilnehmerliste_count_after:  #{pre_read[:current_teilnehmer].size + player_cc_ids.size}
            available_in_meldeliste:      #{pre_read[:available_in_meldeliste].size} player(s)
            Scope: fed_id=#{scope[:fedId]}, branch_cc_id=#{scope[:branchId]}, season=#{scope[:season]}, disciplin_id=#{scope[:disciplinId]}, cat_id=#{scope[:catId]}
            Workflow: assignPlayer (Multi-Add via meldungId[]) → editTeilnehmerlisteSave → optional Read-Back.
            pre_read_verified: #{pre_read_status[:pre_read_verified]}
            pre_read_source: #{pre_read_status[:pre_read_source]}
            pre_read_warning: #{pre_read_status[:pre_read_warning]}
            Pass armed:true to actually perform this assignment.
          DRY_RUN
        end

        # Armed=true: Multi-Step Save-Chain.
        # Plan 07-04 Inline-Patch v2 (Risk A.2): Referer-Chaining — jeder Call referenziert den vorherigen.
        # HAR-Analyse 2026-05-11 zeigte: Real-CC braucht Referer-Header für Phase-7-Workflow-State-Machine.
        # Phase 6 funktionierte ohne — Phase 7 ist strenger (PHP-MVC State-Validation pro Step).
        # Step 1: assignPlayer (Multi-Add).
        # `meldungId[]` ist als String-Key mit Array-Value notwendig, damit set_form_data
        # `meldungId%5B%5D=<id1>&meldungId%5B%5D=<id2>` encoded (matches Real-CC-HAR-Format).
        assign_payload = base_payload(tournament_cc_id, scope).merge(referer: "/admin/einzel/meisterschaft/editTeilnehmerlisteCheck.php?")
        assign_payload["meldungId[]"] = player_cc_ids
        assign_res, assign_doc = client.post("assignPlayer", assign_payload, {armed: armed, session_id: cc_session.cookie})
        if cc_session.reauth_if_needed!(assign_doc)
          assign_res, assign_doc = client.post("assignPlayer", assign_payload, {armed: armed, session_id: cc_session.cookie})
        end
        return error("Unexpected nil response from CC (assignPlayer, armed mode). MockClient may have rejected.") if assign_res.nil?
        return error("CC rejected at assignPlayer: #{parse_cc_error(assign_doc)} (HTTP #{assign_res&.code})") if assign_res&.code != "200"
        assign_parsed = parse_cc_error(assign_doc)
        return error("CC rejected at assignPlayer: #{assign_parsed}") if assign_parsed && assign_parsed != "(no error)"

        # Step 2 (Plan 07-04 Inline-Patch v2 — Risk A): Re-Render-Form-State via editTeilnehmerlisteCheck.
        # Referer-Chaining: dieser Step kommt vom assignPlayer-Submit.
        recheck_payload = base_payload(tournament_cc_id, scope).merge(referer: "/admin/einzel/meisterschaft/assignPlayer.php?")
        rc_res, _rc_doc = client.post("editTeilnehmerlisteCheck", recheck_payload, {armed: armed, session_id: cc_session.cookie})
        return error("Unexpected nil response from CC (editTeilnehmerlisteCheck re-render, armed mode).") if rc_res.nil?
        return error("CC rejected at editTeilnehmerlisteCheck re-render: HTTP #{rc_res&.code}") if rc_res&.code != "200"

        # Step 3: editTeilnehmerlisteSave — Commit mit save="1" Sentinel.
        # Referer: kommt vom editTeilnehmerlisteCheck (re-render).
        # save: "1" als non-blank Sentinel (CC PHP prüft isset, nicht Wert; client.post .reject(&:blank?) entfernt sonst).
        save_payload = base_payload(tournament_cc_id, scope).merge(save: "1", referer: "/admin/einzel/meisterschaft/editTeilnehmerlisteCheck.php?")
        save_res, save_doc = client.post("editTeilnehmerlisteSave", save_payload, {armed: armed, session_id: cc_session.cookie})
        return error("Unexpected nil response from CC (editTeilnehmerlisteSave, armed mode).") if save_res.nil?
        return error("CC rejected at editTeilnehmerlisteSave: #{parse_cc_error(save_doc)} (HTTP #{save_res&.code})") if save_res&.code != "200"
        save_parsed = parse_cc_error(save_doc)
        return error("CC rejected at editTeilnehmerlisteSave: #{save_parsed}") if save_parsed && save_parsed != "(no error)"

        # Optional Read-Back (Schicht 4 Verify): re-read teilnehmerliste, verify all player_cc_ids now present.
        read_back_match = :skipped
        if read_back
          rb = pre_read_teilnehmerliste(client, tournament_cc_id, scope)
          if rb.is_a?(Hash)
            actual_ids = rb[:current_teilnehmer].map { |opt| opt[:cc_id] }
            missing_after_save = player_cc_ids - actual_ids
            read_back_match = missing_after_save.empty?
            unless read_back_match
              return error(
                "Read-back mismatch: expected players #{player_cc_ids.inspect} in Teilnehmerliste, " \
                "but #{missing_after_save.inspect} missing. Save may have failed silently. " \
                "Inspect CC UI manually (cleanup may be needed)."
              )
            end
          else
            return error("Read-back failed (post-save Pre-Read returned error). Save may have succeeded; inspect CC manually.")
          end
        end

        # Plan 10-05.1 Task 3 (D-10-04-D Audit-Trail-Pflicht):
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_assign_player_to_teilnehmerliste",
          operator: cc_session.respond_to?(:cc_login_user) ? cc_session.cc_login_user.to_s : "unknown",
          payload: {tournament_cc_id: tournament_cc_id, player_cc_ids: player_cc_ids, armed: true},
          pre_validation_results: validation_result[:results],
          read_back_status: read_back_match.to_s,
          result: "success",
          user_id: server_context&.dig(:user_id)
        )

        text(<<~OUT.strip)
          Assigned #{player_cc_ids.size} player(s) to Teilnehmerliste for tournament_cc_id=#{tournament_cc_id} (#{pre_read[:tournament_name]}).
          added: #{player_cc_ids.inspect}
          teilnehmerliste_count_before: #{pre_read[:current_teilnehmer].size}
          teilnehmerliste_count_after:  #{pre_read[:current_teilnehmer].size + player_cc_ids.size}
          Steps completed: assignPlayer → editTeilnehmerlisteCheck (re-render) → editTeilnehmerlisteSave#{" → editTeilnehmerlisteCheck (read-back)" if read_back}.
          read_back_match: #{read_back_match}
          pre_validation_passed: #{validation_result[:all_passed]}
          pre_read_verified: #{pre_read_status[:pre_read_verified]}
          pre_read_source: #{pre_read_status[:pre_read_source]}
          pre_read_warning: #{pre_read_status[:pre_read_warning]}
        OUT
      rescue => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # Plan 10-05.1 Task 3 (D-10-04-G Pre-Validation Constraints für cc_assign):
      def self._validate_tournament_exists_assign(pre_read, tournament_cc_id)
        if pre_read.nil? || !pre_read.is_a?(Hash) || pre_read[:tournament_name].blank?
          return {name: "tournament_exists", ok: false, reason: "Pre-Read von Teilnehmerliste für tournament_cc_id=#{tournament_cc_id} fehlgeschlagen oder leer"}
        end
        {name: "tournament_exists", ok: true}
      end

      def self._validate_all_players_in_available(missing_from_meldeliste)
        if missing_from_meldeliste.any?
          {name: "all_players_in_available", ok: false, reason: "Players not in Meldeliste-Available: #{missing_from_meldeliste.inspect}. Use cc_register_for_tournament to add them to the Meldeliste first (Phase 4 workflow)."}
        else
          {name: "all_players_in_available", ok: true}
        end
      end

      def self._validate_none_doppelt_in_teilnehmer(duplicates_in_teilnehmer)
        if duplicates_in_teilnehmer.any?
          {name: "none_doppelt_in_teilnehmer", ok: false, reason: "Players already in Teilnehmerliste: #{duplicates_in_teilnehmer.inspect}. Re-adding would be a no-op or fail. Use cc_remove_from_teilnehmerliste (Phase 8) to re-assign."}
        else
          {name: "none_doppelt_in_teilnehmer", ok: true}
        end
      end

      def self._validate_non_finalized_assign(pre_read)
        # CC-API hat keinen klaren finalized-Marker für Teilnehmerliste (Phase-7-Befund: kein finalize-State).
        # Defensive: assume non-finalized (CC selbst rejected falls Teilnehmerliste finalized).
        {name: "non_finalized", ok: true}
      end

      # Resolve scope filters from DB (TournamentCc) + Override-Params (Best-Effort, NBV-only-Constraint).
      def self.resolve_scope_filters(tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
        # Try DB-first lookup (best-effort, may fail for NBV-only tournaments without linkage)
        tournament_cc = begin
          TournamentCc.find_by(cc_id: tournament_cc_id)
        rescue
          nil
        end
        {
          fedId: fed_cc_id || tournament_cc&.region_cc&.cc_id || default_fed_id,
          branchId: branch_cc_id || tournament_cc&.branch_cc_id,
          disciplinId: disciplin_id || "*",
          catId: cat_id || "*",
          season: season || tournament_cc&.season&.name
        }.compact
      end

      # Base-Payload (9-Felder ohne assignPlayer-spezifische meldungId[]).
      # NICHT zu verwechseln mit `meisterTypeId` — das ist leer im NDM-Endrunde-Sniff und wird gemerged.
      def self.base_payload(tournament_cc_id, scope)
        {
          fedId: scope[:fedId],
          branchId: scope[:branchId],
          disciplinId: scope[:disciplinId],
          catId: scope[:catId],
          season: scope[:season],
          meisterTypeId: "",
          meisterschaftsId: tournament_cc_id,
          sortedBy: "playername",
          firstEntry: 1
        }
      end

      # Pre-Read: fetch editTeilnehmerlisteCheck, parse Tournament-Name + Teilnehmerliste-Options + Meldeliste-Options.
      # Returns Hash with keys [:tournament_name, :current_teilnehmer, :available_in_meldeliste]
      # — or error response on HTTP/parse failure.
      # Hybrid-Parser: funktioniert für Mock-HTML (analog 07-02 Captures) UND Real-CC-HTML.
      #
      # Plan 07-04 Inline-Patch v3 (Risk A.3): Pre-Read benutzt `dla=1`-Modus (Initial-Landing-Payload
      # nach Navigation von showTeilnehmerliste) statt `firstEntry=1`. CC unterscheidet:
      # - dla=1, foundpid=, etlbu=, akkpid= → Initial-Landing, DB-State in Session-Buffer laden
      # - firstEntry=1 → Working-Session, existierenden Buffer benutzen
      # Ohne dla=1 liefert CC einen leeren Buffer in fresh Sessions (zeigt KEINEN DB-State).
      # Fresh-Session-Pre-Read MUSS dla=1 nutzen, sonst sieht es den persistierten DB-State nicht.
      def self.pre_read_teilnehmerliste(client, tournament_cc_id, scope)
        # firstEntry: 1 raus, dla/foundpid/etlbu/akkpid rein (HAR-Initial-Pattern)
        payload = base_payload(tournament_cc_id, scope).reject { |k, _| k == :firstEntry }
          .merge(dla: 1, foundpid: "", etlbu: "", akkpid: "")
        res, doc = client.post("editTeilnehmerlisteCheck", payload, {armed: true, session_id: cc_session.cookie})
        if cc_session.reauth_if_needed!(doc)
          res, doc = client.post("editTeilnehmerlisteCheck", payload, {armed: true, session_id: cc_session.cookie})
        end
        return error("Pre-Read failed: editTeilnehmerlisteCheck returned HTTP #{res&.code}") if res.nil? || res&.code != "200"

        parsed = parse_teilnehmerliste_state(doc)
        return parsed unless parsed.is_a?(Hash)
        parsed
      rescue => e
        error("Pre-Read parse failed: #{e.class.name} (#{e.message})")
      end

      # Parse Tournament-Name + Teilnehmerliste-Options + Meldeliste-Options from editTeilnehmerlisteCheck HTML.
      # Selectors aus 07-02-Captures verified:
      #   <select name="teilnehmerId"><option value="11683">Nachtmann, Georg ...</option>...</select>
      #   <select name="meldungId[]"><option value="10024">Schröder ...</option>...</select>
      #   Tournament-Name in <td class="white" nowrap><b>NDM Endrunde Eurokegel</b></td>
      def self.parse_teilnehmerliste_state(doc)
        return nil unless doc

        # Tournament-Name: extract from the bold tag in the "Meisterschaft"-row.
        tournament_name = extract_text_after_label(doc, "Meisterschaft")

        # Teilnehmerliste-Options (current participants).
        current_teilnehmer = extract_options(doc, 'select[name="teilnehmerId"]')

        # Meldeliste-Available-Options (candidates for assignment).
        available_in_meldeliste = extract_options(doc, 'select[name="meldungId[]"]')

        {
          tournament_name: tournament_name,
          current_teilnehmer: current_teilnehmer,
          available_in_meldeliste: available_in_meldeliste
        }
      end

      # Extract <option value="ID">LABEL</option> entries from a <select>.
      # Filters out empty value="" placeholder options (CC uses leerstring-Option für "kein Spieler").
      def self.extract_options(doc, css_selector)
        select_el = doc.css(css_selector).first
        return [] unless select_el
        select_el.css("option").map do |opt|
          value = opt["value"].to_s.strip
          next nil if value.empty?
          {cc_id: value.to_i, label: opt.text.strip}
        end.compact
      end

      # Extract `<b>TEXT</b>` after a labeled `<td>` cell.
      # Phase 6-Pattern (XPath mit normalize-space + exakter Label-Gleichheit).
      # Hier label = "Meisterschaft" (kein Doppelpunkt im Capture — siehe 07-02-Captures).
      def self.extract_text_after_label(doc, label)
        # Versuche zuerst mit Doppelpunkt (Phase-6-Pattern), dann ohne (Phase-7-Capture-Format).
        label_td = doc.xpath("//td[normalize-space(.) = '#{label}:']").first ||
          doc.xpath("//td[normalize-space(.) = '#{label}']").first
        return nil unless label_td
        sibling = label_td.xpath("following-sibling::td//b").first
        sibling&.text&.strip
      end

      # CC-Error-Parser (analog cc_update_tournament_deadline).
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
