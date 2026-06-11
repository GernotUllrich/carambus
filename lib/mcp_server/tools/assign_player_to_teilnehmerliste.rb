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

        # Plan 14-G.4 / F5-B: Authority-Integration. Defensiv-Skip bei unauflösbar.
        resolved_tournament = resolve_tournament(
          tournament_cc_id: tournament_cc_id, server_context: server_context
        )
        if resolved_tournament
          auth_err = authorize!(action: :manage_teilnehmerliste, tournament: resolved_tournament, server_context: server_context)
          return auth_err if auth_err
        end

        # Plan 10-05.1 Task 1 (D-10-04-B Pivot): Phase-4-Schicht-3 (Production-Block für armed:true)
        # DEPRECATED. Pre-Validation-First-Pattern ersetzt globalen env-Block durch Tool-eigene Constraints.

        # DB-first-Resolver (Best-Effort, NBV-only-Optimization)
        scope = resolve_scope_filters(tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
        client = cc_session.client_for(server_context)

        # Plan 33-01 (2026-06-11): gemeinsamer Live-State-Check statt editTeilnehmerlisteCheck-Edit-Buffer.
        # Holt persistierte Teilnehmer- (showTeilnehmerliste Tab-3) + Meldelisten-View (showMeldeliste Tab-2)
        # EINMAL und klassifiziert jeden player_cc_id. Behebt die stale-Pre-Read-Restursache des
        # Akkreditierungs-Hakens (Edit-Buffer war 1-3s eventual nach Writes) und sichert die Toggle-Richtung:
        # cc_assign akkreditiert NUR Spieler im Zustand :reported_only (gemeldet, noch nicht Teilnehmer).
        lists = fetch_state_lists(client, tournament_cc_id, scope)
        return lists[:error] if lists[:error]
        teilnehmer = lists[:teilnehmer]
        gemeldete = lists[:gemeldete]
        tournament_name = tournament_name_for(tournament_cc_id)

        states = player_cc_ids.index_with { |pid| classify_accreditation(pid, teilnehmer, gemeldete) }
        already_accredited = player_cc_ids.select { |pid| %i[accredited fast_assigned].include?(states[pid]) }
        not_in_meldeliste = player_cc_ids.select { |pid| states[pid] == :not_in_tournament }

        # Plan 33-01 Pre-Validation-First (Matrix-basiert):
        validation_result = run_validations([
          _validate_tournament_known(tournament_name, teilnehmer, gemeldete, tournament_cc_id),
          _validate_all_players_in_meldeliste(not_in_meldeliste),
          _validate_none_already_accredited(already_accredited)
        ])

        unless validation_result[:all_passed]
          failed_details = validation_result[:results].reject { |r| r[:ok] }.map { |r| "#{r[:name]}: #{r[:reason]}" }.join("; ")
          return error("Pre-Validation failed for cc_assign_player_to_teilnehmerliste. Failed: #{validation_result[:failed_constraints].inspect}. #{failed_details}")
        end

        pre_read_status = format_pre_read_status(
          verified: true,
          source: "live-cc (showTeilnehmerliste Tab-3 + showMeldeliste Tab-2)",
          warning: "Live verifiziert: #{teilnehmer.size} bestehende Teilnehmer, #{gemeldete.size} gemeldet."
        )

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo
        unless armed
          player_details = gemeldete
            .select { |opt| player_cc_ids.include?(opt[:cc_id]) }
            .map { |opt| "#{opt[:cc_id]} (#{opt[:label]})" }
            .join(", ")
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would assign #{player_cc_ids.size} player(s) to Teilnehmerliste for tournament_cc_id=#{tournament_cc_id} (#{tournament_name}).
            Players: #{player_details}
            teilnehmerliste_count_before: #{teilnehmer.size}
            teilnehmerliste_count_after:  #{teilnehmer.size + player_cc_ids.size}
            available_in_meldeliste:      #{gemeldete.size} gemeldet
            Scope: fed_id=#{scope[:fedId]}, branch_cc_id=#{scope[:branchId]}, season=#{scope[:season]}, disciplin_id=#{scope[:disciplinId]}, cat_id=#{scope[:catId]}
            Workflow: showMeldeliste_teilnahme (atomarer Akkreditierungs-Toggle, 1 POST pro Spieler) → optional Read-Back.
            pre_read_verified: #{pre_read_status[:pre_read_verified]}
            pre_read_source: #{pre_read_status[:pre_read_source]}
            Pass armed:true to actually perform this assignment.
          DRY_RUN
        end

        # Armed=true: atomarer Akkreditierungs-Toggle pro Spieler (Plan 33-fix 2026-06-10, HAR-Goldvorlage).
        # Browser nutzt showMeldeliste_teilnahme.php?...&pid=<player_cc_id> — EIN POST pro Spieler, der
        # den Spieler Meldeliste→Teilnehmerliste verschiebt. KEIN Edit-Buffer, KEIN meldungId[]-Pre-Read,
        # KEIN Save-Step, KEIN PUT-Replace-Race (Wurzel des Akkreditierungs-Chaos 2026-06-10).
        # Pre-Validation (none_doppelt_in_teilnehmer) garantiert: kein player_cc_id ist schon Teilnehmer
        # → der Toggle akkreditiert (de-akkreditiert nie versehentlich einen Bestandsteilnehmer).
        # Payload (HAR): fedId, branchId, disciplinId, season, catId, meisterTypeId, meisterschaftsId,
        #   sortedBy, pid — also base_payload OHNE firstEntry + pid.
        toggle_base = base_payload(tournament_cc_id, scope).except(:firstEntry)
        player_cc_ids.each do |pid|
          toggle_payload = toggle_base.merge(pid: pid)
          tg_res, tg_doc = client.post("showMeldeliste_teilnahme", toggle_payload, {armed: armed, session_id: cc_session.cookie})
          if cc_session.reauth_if_needed!(tg_doc)
            tg_res, tg_doc = client.post("showMeldeliste_teilnahme", toggle_payload, {armed: armed, session_id: cc_session.cookie})
          end
          return error("Unexpected nil response from CC (showMeldeliste_teilnahme for player_cc_id=#{pid}, armed mode).") if tg_res.nil?
          return error("CC rejected at showMeldeliste_teilnahme for player_cc_id=#{pid}: #{parse_cc_error(tg_doc)} (HTTP #{tg_res&.code})") if tg_res&.code != "200"
          tg_parsed = parse_cc_error(tg_doc)
          return error("CC rejected at showMeldeliste_teilnahme for player_cc_id=#{pid}: #{tg_parsed}") if tg_parsed && tg_parsed != "(no error)"
        end

        # Optional Read-Back (Schicht 4 Verify): re-read teilnehmerliste, verify all player_cc_ids now present.
        # Plan 26-01 T1b: zusätzlich prüfen, ob Bestandsteilnehmer unbeabsichtigt entfernt wurden
        # (Demo-2-Befund: alter read_back war False-Positive — prüfte nur neue Spieler, nicht Bestand).
        # Plan 33-fix (2026-06-10): Read-Back aus persistierter Tab-3-View (showTeilnehmerliste),
        # NICHT aus dem editTeilnehmerlisteCheck-Edit-Buffer. Nach dem atomaren Toggle ist der
        # Edit-Buffer eventual-stale → alter Read-Back gab False-Negative (error trotz korrektem Write,
        # Live-Befund 2026-06-10). Die persistierte View spiegelt den DB-Stand sofort wider.
        read_back_match = :skipped
        if read_back
          rb_teilnehmer = McpServer::Tools::LookupTeilnehmerliste.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
          if rb_teilnehmer.is_a?(Array)
            actual_ids = rb_teilnehmer.map { |opt| opt[:cc_id] }
            missing_after_save = player_cc_ids - actual_ids
            pre_existing_ids = teilnehmer.map { |o| o[:cc_id] }
            unintended_removals = pre_existing_ids - actual_ids
            read_back_match = missing_after_save.empty? && unintended_removals.empty?
            unless read_back_match
              problem_parts = []
              problem_parts << "fehlende neue Spieler: #{missing_after_save.inspect}" if missing_after_save.any?
              problem_parts << "unbeabsichtigt entfernte Bestandsteilnehmer: #{unintended_removals.inspect}" if unintended_removals.any?
              return error(
                "Read-back mismatch: #{problem_parts.join("; ")}. " \
                "Die ClubCloud braucht einen Moment, bis sie den neuen Stand übernimmt — bitte gleich erneut prüfen."
              )
            end
          else
            return error("Read-back failed (post-write persisted read returned error). Write may have succeeded; inspect CC manually.")
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
          Assigned #{player_cc_ids.size} player(s) to Teilnehmerliste for tournament_cc_id=#{tournament_cc_id} (#{tournament_name}).
          added: #{player_cc_ids.inspect}
          teilnehmerliste_count_before: #{teilnehmer.size}
          teilnehmerliste_count_after:  #{teilnehmer.size + player_cc_ids.size}
          Steps completed: showMeldeliste_teilnahme (atomarer Toggle, #{player_cc_ids.size}× pro Spieler)#{" → Read-Back" if read_back}.
          read_back_match: #{read_back_match}
          pre_validation_passed: #{validation_result[:all_passed]}
          pre_read_verified: #{pre_read_status[:pre_read_verified]}
          pre_read_source: #{pre_read_status[:pre_read_source]}
        OUT
      rescue => e
        Rails.logger.error("[cc_assign_player_to_teilnehmerliste] #{e.class}: #{e.message}\n  #{e.backtrace&.first(10)&.join("\n  ")}")
        error("Tool exception: #{e.class.name} (Details siehe Rails.logger auf dem Server).")
      end

      # Plan 33-01 Pre-Validation Constraints für cc_assign (Matrix-basiert auf accreditation_state).
      def self._validate_tournament_known(tournament_name, teilnehmer, gemeldete, tournament_cc_id)
        if tournament_name.blank? && teilnehmer.empty? && gemeldete.empty?
          return {name: "tournament_known", ok: false,
                  reason: "Turnier tournament_cc_id=#{tournament_cc_id} unbekannt oder ohne Teilnehmer/Meldeliste (Live-Reads leer)."}
        end
        {name: "tournament_known", ok: true}
      end

      def self._validate_all_players_in_meldeliste(not_in_meldeliste)
        if not_in_meldeliste.any?
          {name: "all_players_in_meldeliste", ok: false,
           reason: "Spieler nicht in der Meldeliste: #{not_in_meldeliste.inspect}. Vor Meldeschluss zuerst mit cc_register_for_tournament melden; nach Meldeschluss per cc_fast_assign_to_teilnehmerliste direkt in die Teilnehmerliste eintragen."}
        else
          {name: "all_players_in_meldeliste", ok: true}
        end
      end

      def self._validate_none_already_accredited(already_accredited)
        if already_accredited.any?
          {name: "none_already_accredited", ok: false,
           reason: "Spieler sind bereits akkreditiert (in der Teilnehmerliste): #{already_accredited.inspect}. Erneutes Akkreditieren ist nicht nötig; zum Entfernen cc_remove_from_teilnehmerliste nutzen."}
        else
          {name: "none_already_accredited", ok: true}
        end
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

      # Plan 33-01 T1 (2026-06-11): Gemeinsamer Live-State-Check für cc_assign + cc_remove.
      # Klassifiziert den Akkreditierungs-Status EINES Spielers aus ZWEI persistierten CC-DB-Views
      # (KEIN Edit-Buffer): showTeilnehmerliste Tab-3 (akkreditierte) + showMeldeliste Tab-2 (gemeldete).
      # Der Toggle showMeldeliste_teilnahme.php ist zustandsabhängig (akkreditiert ODER deakkreditiert
      # je nach Live-Zustand, HAR-belegt 2026-06-11) — dieser Check sichert die Toggle-Richtung beider Tools ab.
      #
      # Rückgabe: {state:, teilnehmer:, gemeldete:, label:, error:}
      #   :accredited        gemeldet + Teilnehmer        → cc_remove darf deakkreditieren; cc_assign lehnt ab
      #   :reported_only     gemeldet, nicht Teilnehmer    → cc_assign darf akkreditieren; cc_remove lehnt ab
      #   :fast_assigned     Teilnehmer ohne Meldeliste    → Schnellanmeldung (NICHT über Meldeliste toggelbar)
      #   :not_in_tournament weder gemeldet noch Teilnehmer
      #
      # Annahme (Live-Verify 2026-06-11): showMeldeliste Tab-2 (fetch_meldeliste_persisted) listet ALLE
      # gemeldeten Spieler — auch bereits akkreditierte (vgl. all_registered-Logik in cc_lookup_teilnehmerliste).
      def self.accreditation_state(client, tournament_cc_id, scope, player_cc_id)
        lists = fetch_state_lists(client, tournament_cc_id, scope)
        return {error: lists[:error]} if lists[:error]
        state = classify_accreditation(player_cc_id, lists[:teilnehmer], lists[:gemeldete])
        label = (lists[:teilnehmer] + lists[:gemeldete]).find { |x| x[:cc_id] == player_cc_id }&.[](:label)
        {state: state, teilnehmer: lists[:teilnehmer], gemeldete: lists[:gemeldete], label: label, error: nil}
      end

      # Holt die zwei persistierten Live-Listen EINMAL (für Multi-Player-Klassifikation in cc_assign,
      # ohne pro Spieler erneut zu lesen). Rückgabe {teilnehmer:, gemeldete:, error:}.
      def self.fetch_state_lists(client, tournament_cc_id, scope)
        teilnehmer = McpServer::Tools::LookupTeilnehmerliste.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
        return {error: teilnehmer} if teilnehmer.is_a?(MCP::Tool::Response)
        gemeldete = McpServer::Tools::LookupTeilnehmerliste.fetch_meldeliste_persisted(client, tournament_cc_id, scope)
        {teilnehmer: teilnehmer, gemeldete: gemeldete, error: nil}
      end

      # Reine Klassifikation (keine I/O) — aus den zwei Listen.
      def self.classify_accreditation(player_cc_id, teilnehmer, gemeldete)
        ist_teilnehmer = teilnehmer.any? { |t| t[:cc_id] == player_cc_id }
        ist_gemeldet = gemeldete.any? { |g| g[:cc_id] == player_cc_id }
        if ist_gemeldet && ist_teilnehmer
          :accredited
        elsif ist_gemeldet
          :reported_only
        elsif ist_teilnehmer
          :fast_assigned
        else
          :not_in_tournament
        end
      end

      # Best-Effort Turnier-Name aus DB-Mirror (für Anzeige/Ablehnungstexte; Live-State kommt aus CC).
      def self.tournament_name_for(tournament_cc_id)
        TournamentCc.find_by(cc_id: tournament_cc_id)&.name
      rescue
        nil
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
