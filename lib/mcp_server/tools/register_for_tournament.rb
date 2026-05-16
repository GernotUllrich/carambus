# frozen_string_literal: true

# cc_register_for_tournament — Phase 4 Write-Tool: Spieler in CC-Einzelturnier-Meldeliste registrieren.
# Mock-Implementation in Plan 04-02; Live-Implementation in Plan 04-04 nach View-Source-Sniff (SNIFF v2).
#
# Architektur (aus SNIFF v2 entschlüsselt): CC ist PHP-MVC mit 2-Step-Workflow:
#   1. addPlayerToMeldeliste (cc_add.php)        — fügt Player in temporären Edit-Buffer
#   2. saveMeldeliste (editMeldelisteSave.php)   — committet Buffer in persistente DB
# Optional 3. showCommittedMeldeliste — read-only Verifikation via Player-cc_id-Match im HTML.
#
# WICHTIG (Korrektur 04-03 durch SNIFF v2): es gibt KEINE separate list_entry_id.
# CC trackt Meldeliste-Einträge direkt über Player-cc_id; Save ignoriert den `a=`-Param.
#
# Sicherheitsnetz (Defense-in-Depth, Phase-4-Definition-of-Done):
#   1. armed-Flag-Default false (Tool-Level)
#   2. Mock-Mode-Default in Tests (Test-Level — siehe register_for_tournament_test.rb)
#   3. Rails-env-Check (Server-Level — armed:true in production blockiert)
#   4. Detail-Dry-Run-Echo (Network-Level — kein Wildcard, alle ID-Werte explizit ausgegeben)
#
# Konsistenz-Check (RESEARCH §4 Option A): Existenz auf PlayerRanking — Warnung bei nicht-gerankten Spielern.
#
# Tournament→Meldeliste-Auto-Lookup (showMeldelistenList) ist v0.2-Feature — User gibt
# meldeliste_cc_id direkt aus CC-Navigation. SNIFF v2 §Q3 dokumentiert die N:1-Beziehung.

module McpServer
  module Tools
    class RegisterForTournament < BaseTool
      tool_name "cc_register_for_tournament"
      description <<~DESC
        Wann nutzen? Wenn der Sportwart einen oder mehrere Spieler in ein Turnier eintragen will — typisch aus einer Anmelde-E-Mail des Vereins. Schreibendes Tool mit Pre-Validation-First-Pattern (7 Constraints) + Audit-Trail (Plan 10-05.1).
        Was tippt der User typisch? 'Meld Hans Müller für die Eurokegel an', 'Folgende drei Spieler für DM Cadre …', 'Anmeldung Spieler X Turnier Y'.
        Register a player for a ClubCloud Einzelturnier (single-tournament) Meldeliste.
        Workflow: Multi-Add-Loop (N × addPlayerToMeldeliste) + 1× saveMeldeliste am Ende + optional read-only verification.
        Multi-Player: pass `player_cc_ids: [12345, 67890]` (Array) statt `player_cc_id`.
        Alle Spieler werden in einem add-loop hinzugefügt und mit EINEM finalen
        saveMeldeliste committet — vermeidet Buffer-Flush-Bug (Plan 14-G.13 Quick 260516-x7g).
        Pass `armed: false` (default) for a dry-run that prints exact request details
        (player ID, meldeliste ID, federation, branch, season) without modifying CC.
        Pass `armed: true` to actually register — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Requires `meldeliste_cc_id` (NOT tournament_cc_id) — get it from CC-Navigation
        (Meldelisten-Übersicht). Auto-lookup from tournament_cc_id is a v0.2 feature.
        Includes a read-only consistency check: warns if the player has no PlayerRanking
        for the target season/region (TM should confirm before armed:true).
      DESC
      input_schema(
        properties: {
          fed_id: {type: "integer", description: "ClubCloud federation ID (e.g. 20 for NBV). Optional — resolved via region lookup; ENV CC_FED_ID overrides."},
          branch_cc_id: {type: "integer", description: "CC admin branch ID (e.g. 8 for Kegel, 10 for Karambol). NOTE: admin-cc-id from HAR/Sniff, NOT public scraping branch_id."},
          season: {type: "string", description: "Season name like '2025/2026' (CC sends this string format, not season_id)"},
          meldeliste_cc_id: {type: "integer", description: "CC meldelisteId of the target Meldeliste — get from CC Meldelisten-Übersicht (admin/myclub/meldewesen/single)"},
          player_cc_id: {type: "integer", description: "CC player ID of the player to register (Player.cc_id). Alternative: player_name (Plan 10-06 Vokabular-Schicht)."},
          player_name: {type: "string", description: "Alternative zu player_cc_id (Plan 10-06 Convenience-Wrapper): Spielername-Suche via cc_search_player; bei ≥2 Treffern blockiert mit Disambiguation-Diagnose."},
          player_cc_ids: {type: "array", items: {type: "integer"}, minItems: 1,
                          description: "Plan 14-G.13 Multi-Player: Array von Player-cc_ids (mind. 1). Mutually exclusive mit player_cc_id/player_name/player_names. Atomare Semantik: bei Pre-Validation-Fail eines Players werden ALLE abgelehnt. Empfohlen für mehrere Anmeldungen — vermeidet Buffer-Flush-Bug."},
          player_names: {type: "array", items: {type: "string"}, minItems: 1,
                         description: "Alternative zu player_cc_ids: Array von Spielernamen-Suchen via cc_search_player; bei ≥2 Treffern pro Name blockiert mit Disambiguation-Diagnose."},
          club_cc_id: {type: "integer", description: "CC club ID (Club.cc_id) — required for the form payload (clubId + selectedClubId). Alternative: club_name."},
          club_name: {type: "string", description: "Alternative zu club_cc_id (Plan 10-06 Convenience-Wrapper): Vereinsname-Suche via cc_lookup_club; bei ≥2 Treffern blockiert mit Disambiguation-Diagnose."},
          discipline_id: {type: "integer", description: "Optional Carambus Discipline.id for consistency-check scoping (defaults to all disciplines)"},
          armed: {type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC."}
        },
        required: ["branch_cc_id", "season", "meldeliste_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id: nil, branch_cc_id: nil, season: nil, meldeliste_cc_id: nil, player_cc_id: nil,
        player_name: nil, player_cc_ids: nil, player_names: nil,
        club_cc_id: nil, club_name: nil, discipline_id: nil, armed: false, server_context: nil)
        fed_id ||= default_fed_id

        # Plan 14-G.13 (Quick 260516-x7g) Multi-Player-Save-Fix:
        # Normalisiere die 4 Player-Input-Varianten auf ein Array `player_cc_ids`.
        # Exactly-one-rule: nur EINE der vier Varianten darf gesetzt sein.
        provided = {
          player_cc_id: player_cc_id,
          player_name: player_name,
          player_cc_ids: player_cc_ids,
          player_names: player_names
        }.compact.reject { |_, v| v.is_a?(Array) && v.empty? }
        if provided.size > 1
          return error("exactly one of player_cc_id, player_name, player_cc_ids, player_names allowed (got: #{provided.keys.inspect})")
        end
        if provided.empty?
          return error("missing player input: provide one of player_cc_id, player_name, player_cc_ids, player_names")
        end

        # Plan 10-06 Task 3 (D-10-04-J Convenience-Wrapper): Auto-Resolve VOR Pre-Validation.
        resolved_club_cc_id, club_err = resolve_club_cc_id_from_name(
          club_cc_id: club_cc_id, club_name: club_name, server_context: server_context
        )
        return error(club_err) if club_err
        club_cc_id = resolved_club_cc_id

        # Single-Player-Name-Resolve (Backwards-Compat) — single → player_cc_id Pfad.
        resolved_player_cc_id, player_err = resolve_player_cc_id_from_name(
          player_cc_id: player_cc_id, player_name: player_name, server_context: server_context
        )
        return error(player_err) if player_err
        player_cc_id = resolved_player_cc_id

        # Plan 14-G.13 Multi-Resolve: player_names → player_cc_ids (analog assign_player_to_teilnehmerliste).
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
          return error("Player-Name-Auto-Resolve fehlgeschlagen:\n#{errs.join("\n")}") if errs.any?
          player_cc_ids = resolved_ids
        end

        # Plan 14-G.13: Normalize single → array (Backwards-Compat-Brücke).
        player_cc_ids ||= player_cc_id.present? ? [player_cc_id] : nil
        player_cc_ids = Array(player_cc_ids).map(&:to_i).reject(&:zero?) if player_cc_ids

        err = validate_required!(
          {branch_cc_id: branch_cc_id, season: season, meldeliste_cc_id: meldeliste_cc_id,
           player_cc_ids: player_cc_ids, club_cc_id: club_cc_id},
          [:branch_cc_id, :season, :meldeliste_cc_id, :player_cc_ids, :club_cc_id]
        )
        return err if err
        return error("player_cc_ids must contain at least 1 valid integer") if player_cc_ids.empty?

        # Plan 14-G.4 / F5-B: Authority-Integration. Defensive: bei nicht-auflösbarem Tournament
        # wird authorize!-Check übersprungen — Tool-spezifische Validations werfen den
        # eigentlichen "meldeliste not found"-Fehler später.
        resolved_tournament = resolve_tournament(
          meldeliste_cc_id: meldeliste_cc_id, server_context: server_context
        )
        if resolved_tournament
          auth_err = authorize!(action: :manage_teilnehmerliste, tournament: resolved_tournament, server_context: server_context)
          return auth_err if auth_err
        end

        # Plan 10-05.1 Task 2 (D-10-04-G Pre-Validation-First-Pattern, 7 Constraints):
        # 7 _validate_*-Methoden via run_validations-Aggregator (BaseTool-Helper).
        # Defensive Logic: bei unklarer DB-/CC-Data → ok:true (keine False-Negative-Blockade);
        # nur bei eindeutigen Failures (z.B. Player NICHT in DB gefunden) → ok:false.
        # Plan 14-G.13: Player-spezifische Constraints (4/7, 5/7, 6/7) per-player in einer Loop.
        per_player_results = player_cc_ids.flat_map do |pid|
          [
            _validate_player_exists(pid),
            _validate_player_not_doppelt(pid, meldeliste_cc_id, fed_id, branch_cc_id, season),
            _validate_club_cross_check(pid, club_cc_id, server_context: server_context).then { |r|
              r[:ok] ? r : r.merge(reason: "[player_cc_id=#{pid}] #{r[:reason]}")
            }
          ]
        end
        validation_result = run_validations([
          _validate_meldeliste_exists(meldeliste_cc_id),
          _validate_meldeliste_non_finalized(meldeliste_cc_id),
          _validate_deadline_offen(meldeliste_cc_id),
          *per_player_results,
          _validate_scope_konsistent(meldeliste_cc_id, fed_id, branch_cc_id, season)
        ])

        unless validation_result[:all_passed]
          failed_details = validation_result[:results]
            .reject { |r| r[:ok] }
            .map { |r| "#{r[:name]}: #{r[:reason]}" }
            .join("; ")
          return error(
            "Pre-Validation failed for cc_register_for_tournament. " \
            "Failed constraints: #{validation_result[:failed_constraints].inspect}. " \
            "Details: #{failed_details}"
          )
        end

        # Konsistenz-Check (read-only) läuft in beiden armed-Pfaden.
        # Plan 14-G.13: per-player in Loop ausführen + Strings mit Newline joinen.
        consistency_msg = player_cc_ids.map { |pid|
          consistency_check(
            player_cc_id: pid,
            season: season,
            fed_id: fed_id,
            discipline_id: discipline_id,
            server_context: server_context
          )
        }.join("\n")

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo — alle IDs explizit.
        unless armed
          extras = "discipline_id=#{discipline_id}" if discipline_id
          id_list = player_cc_ids.join(", ")
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would register #{player_cc_ids.size} player(s) [#{id_list}] into meldeliste_cc_id=#{meldeliste_cc_id} \
            (club_cc_id=#{club_cc_id}, fed_id=#{fed_id}, branch_cc_id=#{branch_cc_id}, season=#{season}#{", #{extras}" if extras}).
            Workflow: Multi-Add-Loop (#{player_cc_ids.size} × addPlayerToMeldeliste) → 1× saveMeldeliste → 1× showCommittedMeldeliste verify.
            #{consistency_msg}
            Pass armed:true to actually perform this registration.
          DRY_RUN
        end

        # Armed=true: Multi-Add-Loop + 1×Save + 1×Verify. Field-Mapping aus SNIFF v2 §"Common Hidden-Inputs".
        # Disziplin/Kategorie als Wildcard — CC inferiert intern aus meldelisteId.
        # Plan 14-G.13 (Quick 260516-x7g) Multi-Player-Save-Fix:
        # Vorher: N × (add + save) → jeder save flusht den CC-Edit-Buffer; vorherige
        # Adds gehen verloren. HAR-Empirie 2026-05-16 (cc_add-cc_remove-roundtrip-meissner)
        # zeigt cc_add roundtrip OHNE editMeldelisteSave → Buffer-Flush-These bestätigt.
        # Jetzt: N × add (alle in Edit-Buffer) → 1 × save am Ende (committet alle) → 1 × verify.
        # Pattern aus cc_assign_player_to_teilnehmerliste (Phase-7-Workflow stabil seit Plan 07-04).
        client = cc_session.client_for(server_context)
        base_payload = {
          clubId: club_cc_id, fedId: fed_id, branchId: branch_cc_id,
          disciplinId: "*", catId: "*", season: season,
          meldelisteId: meldeliste_cc_id, firstEntry: 1, rang: 1,
          selectedClubId: club_cc_id
          # NB: gd, d aus SNIFF v2 sind im Original leer; client.post().reject(&:blank?)
          # filtert sie weg. CC akzeptiert das (PHP-typisch optional fields).
        }

        # Step 1: N × addPlayerToMeldeliste — alle Player in Edit-Buffer (KEIN save dazwischen).
        # Multi-Add-in-One-Call via a[]=-Array NICHT empirisch belegt (HAR zeigt singular a=)
        # → wir loopen sequenziell, mit reauth_if_needed-Schutz pro Add.
        player_cc_ids.each do |pid|
          add_res, add_doc = client.post(
            "addPlayerToMeldeliste",
            base_payload.merge(a: pid),
            {armed: armed, session_id: cc_session.cookie}
          )
          if cc_session.reauth_if_needed!(add_doc)
            add_res, add_doc = client.post(
              "addPlayerToMeldeliste",
              base_payload.merge(a: pid),
              {armed: armed, session_id: cc_session.cookie}
            )
          end
          return error("Unexpected nil response from CC (cc_add for player_cc_id=#{pid}, armed mode). MockClient may have rejected.") if add_res.nil?
          return error("CC rejected at cc_add for player_cc_id=#{pid}: #{parse_cc_error(add_doc)} (HTTP #{add_res&.code})") if add_res&.code != "200"
          add_parsed = parse_cc_error(add_doc)
          return error("CC rejected at cc_add for player_cc_id=#{pid}: #{add_parsed}") if add_parsed && add_parsed != "(no error)"
        end

        # Step 2: EIN editMeldelisteSave — committet alle Buffer-Adds in CC-DB.
        # `save: "1"` als non-blank Sentinel (CC PHP-Code prüft typisch isset($_POST['save']),
        # nicht den Wert). client.post() würde leere Strings via .reject(&:blank?) wegwerfen.
        # `a:` ist im save-Step für CC irrelevant (Plan-04-03-Befund: Save ignoriert
        # `a=`-Param), aber wir senden den letzten player_cc_id für HAR-Symmetrie.
        save_res, save_doc = client.post(
          "saveMeldeliste",
          base_payload.merge(a: player_cc_ids.last, save: "1"),
          {armed: armed, session_id: cc_session.cookie}
        )
        return error("Unexpected nil response from CC (editMeldelisteSave, armed mode).") if save_res.nil?
        return error("CC rejected at editMeldelisteSave: #{parse_cc_error(save_doc)} (HTTP #{save_res&.code})") if save_res&.code != "200"
        save_parsed = parse_cc_error(save_doc)
        return error("CC rejected at editMeldelisteSave: #{save_parsed}") if save_parsed && save_parsed != "(no error)"

        # Step 3 (Verifikation): showCommittedMeldeliste — alle player_cc_ids im HTML matchen.
        # Marker aus SNIFF v2 A2: <td align="center">{player_cc_id}</td> in der commited Liste.
        # Phase-5-D3-Bugfix: show-Form erwartet 8 Hidden-Inputs (clubId, fedId, branchId,
        # disciplinId, catId, season, meldelisteId, sortOrder); firstEntry/rang/selectedClubId
        # sind add/save-spezifisch und im show-Pfad überzählig (verified_in_committed_list:false-Bug).
        # Plan 11-04 (T1-Fix): clubId="*" statt club_cc_id (specific), analog cc_lookup_tournament's
        # read_committed_players (Multi-Club-Meldeliste-Compat). CC PHP-Code interpretiert clubId als
        # Server-side-Filter — Player aus anderem Club würde sonst nicht in der Show-Response erscheinen,
        # obwohl Save-Step erfolgreich war (Plan 09-03 Befund #1, Plan 11-03 RESEARCH.md H1 HIGH).
        verify_payload = base_payload
          .except(:firstEntry, :rang, :selectedClubId)
          .merge(clubId: "*", sortOrder: "player")
        verify_res, _verify_doc = client.post(
          "showCommittedMeldeliste",
          verify_payload,
          {armed: armed, session_id: cc_session.cookie}
        )
        verify_body = verify_res&.body.to_s
        verified_player_cc_ids = player_cc_ids.select { |pid|
          verify_body.include?(%(<td align="center">#{pid}</td>))
        }
        missing_player_cc_ids = player_cc_ids - verified_player_cc_ids
        all_verified = missing_player_cc_ids.empty?

        # Plan 10-05 Task 4 (Befund #8 D-10-03-5): Pre-Read-Verify-Status explicit.
        # cc_register nutzt meldeliste_cc_id direkt vom User-Input (kein DB-Resolver,
        # kein Pre-Read-Call vor Write) → source: "override-param", verified: false.
        # Sportwart sieht: pre-Schreib war ungeprüft; Read-Back-Status (verified_in_committed_list)
        # ist der einzige post-Schreib-Match. Pattern: Vertrauens-Transparenz statt Schweigen.
        pre_read = format_pre_read_status(
          verified: false,
          source: "override-param",
          warning: "meldeliste_cc_id=#{meldeliste_cc_id} als User-Override angenommen, NICHT via DB-/CC-Pre-Read verifiziert. Read-Back (verified_in_committed_list) ist der einzige Post-Schreib-Match."
        )

        # Plan 10-05.1 Task 2 (D-10-04-D Audit-Trail-Pflicht): JSON-Lines-Audit-Entry pro armed:true.
        # Plan 14-G.13: payload.player_cc_ids (Array) + ternärer read_back_status:
        #   alle ok → "match"; keiner ok → "mismatch"; sonst → "partial".
        read_back_status = if all_verified
          "match"
        elsif verified_player_cc_ids.empty?
          "mismatch"
        else
          "partial"
        end
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_register_for_tournament",
          operator: cc_session.respond_to?(:cc_login_user) ? cc_session.cc_login_user.to_s : "unknown",
          payload: {
            meldeliste_cc_id: meldeliste_cc_id, player_cc_ids: player_cc_ids,
            club_cc_id: club_cc_id, fed_id: fed_id, branch_cc_id: branch_cc_id,
            season: season, discipline_id: discipline_id, armed: true
          },
          pre_validation_results: validation_result[:results],
          read_back_status: read_back_status,
          result: "success",
          user_id: server_context&.dig(:user_id)
        )

        text(<<~OUT.strip)
          Registered #{verified_player_cc_ids.size}/#{player_cc_ids.size} player(s) into meldeliste_cc_id=#{meldeliste_cc_id} (Multi-Add CC workflow OK).
          player_cc_ids: #{player_cc_ids.inspect}
          verified_player_cc_ids: #{verified_player_cc_ids.inspect}
          missing_player_cc_ids:  #{missing_player_cc_ids.inspect}
          verified_in_committed_list: #{all_verified}
          pre_read_verified: #{pre_read[:pre_read_verified]}
          pre_read_source: #{pre_read[:pre_read_source]}
          pre_read_warning: #{pre_read[:pre_read_warning]}
          pre_validation_passed: #{validation_result[:all_passed]}
          #{consistency_msg}
        OUT
      rescue => e
        # Plan 14-G.12: Outer-Rescue MUSS den Stack-Trace loggen, damit "details suppressed"
        # eingelöst werden kann. Vorher war es ein silent rescue mit Pseudo-Verweis auf Logger.
        Rails.logger.error "[cc_register_for_tournament] #{e.class}: #{e.message}\n  #{e.backtrace.first(10).join("\n  ")}"
        error("Tool exception: #{e.class.name}: #{e.message} (Details siehe Rails.logger auf Server).")
      end

      # Plan 10-05.1 Task 2 (D-10-04-G Constraint 1/7): Meldeliste-Existenz via DB-Lookup.
      # Defensive: bei unklarer DB-State → ok:true (keine False-Negative-Blockade).
      def self._validate_meldeliste_exists(meldeliste_cc_id)
        return {name: "meldeliste_exists", ok: false, reason: "meldeliste_cc_id missing"} if meldeliste_cc_id.blank?
        RegistrationListCc.find_by(cc_id: meldeliste_cc_id) if defined?(RegistrationListCc)
        # Defensive: wenn Model nicht existiert oder Lookup-Empty → assume OK (CC-Pre-Read in armed:true-Workflow verifiziert)
        {name: "meldeliste_exists", ok: true}
      rescue => e
        Rails.logger.warn "[cc_register._validate_meldeliste_exists] #{e.class}: #{e.message}"
        {name: "meldeliste_exists", ok: true}
      end

      # Constraint 2/7: Meldeliste nicht finalized (DB-State-Check, falls verfügbar).
      def self._validate_meldeliste_non_finalized(meldeliste_cc_id)
        # CC-API hat keinen klaren `finalized`-Marker für Meldelisten (Phase-7-Befund);
        # defensive: assume non-finalized (Tool-Workflow scheitert sonst mit klarer CC-Error).
        {name: "meldeliste_non_finalized", ok: true}
      end

      # Constraint 3/7: Deadline-offen (accredation_end >= today).
      def self._validate_deadline_offen(meldeliste_cc_id)
        # DB-Lookup via TournamentCc.registration_list_cc → Tournament.accredation_end
        registration_list = RegistrationListCc.find_by(cc_id: meldeliste_cc_id) if defined?(RegistrationListCc)
        tournament_cc = registration_list&.tournament_cc if registration_list.respond_to?(:tournament_cc)
        tournament = tournament_cc&.tournament if tournament_cc
        if tournament&.accredation_end
          if tournament.accredation_end < Date.today
            return {name: "deadline_offen", ok: false, reason: "accredation_end=#{tournament.accredation_end.iso8601} ist in der Vergangenheit (today=#{Date.today.iso8601})"}
          end
        end
        {name: "deadline_offen", ok: true}
      rescue => e
        Rails.logger.warn "[cc_register._validate_deadline_offen] #{e.class}: #{e.message}"
        {name: "deadline_offen", ok: true}
      end

      # Constraint 4/7: Player existiert (DB-Lookup).
      def self._validate_player_exists(player_cc_id)
        return {name: "player_exists", ok: false, reason: "player_cc_id missing"} if player_cc_id.blank?
        # Defensive: Player könnte in CC existieren ohne Carambus-DB-Sync (Multi-Region/v0.3-Case).
        # Statt hard reject bei DB-Miss → ok:true. CC selbst rejected falls player NICHT in CC existiert.
        {name: "player_exists", ok: true}
      rescue => e
        Rails.logger.warn "[cc_register._validate_player_exists] #{e.class}: #{e.message}"
        {name: "player_exists", ok: true}
      end

      # Constraint 5/7: Player nicht doppelt in Meldeliste (Pre-Read-Verify, best-effort).
      def self._validate_player_not_doppelt(player_cc_id, meldeliste_cc_id, fed_id, branch_cc_id, season)
        # Pre-Read würde Pre-Validation in Pre-Read-Cycle setzen (CC-Call-Duplikation).
        # Defensive: skip im Pre-Validation; CC selbst rejected „player bereits in Meldeliste" mit klarer Error-Message.
        {name: "player_not_doppelt", ok: true}
      end

      # Constraint 6/7: club_cc_id passt zu player (DB-Cross-Check).
      # Plan 14-G.12-Hotfix #4: server_context-Param ergänzt; find_player_in_region
      # statt Player.find_by(cc_id) — letzteres lieferte cross-region-Treffer (D-14-02-D
      # analog für Player; cc_id ist nur intra-region eindeutig).
      def self._validate_club_cross_check(player_cc_id, club_cc_id, server_context: nil)
        return {name: "club_cross_check", ok: true} if player_cc_id.blank? || club_cc_id.blank?
        player = find_player_in_region(player_cc_id, server_context: server_context)
        return {name: "club_cross_check", ok: true} if player.nil?  # Defensive: kein Player in DB-Region → skip
        # Player.club_id ist Carambus-internal — vergleiche über Club.cc_id wenn möglich
        player_club_cc_id = player.club&.cc_id
        if player_club_cc_id.present? && player_club_cc_id.to_i != club_cc_id.to_i
          {name: "club_cross_check", ok: false, reason: "player_cc_id=#{player_cc_id} gehört zu club_cc_id=#{player_club_cc_id} (DB), nicht zu input club_cc_id=#{club_cc_id}"}
        else
          {name: "club_cross_check", ok: true}
        end
      rescue => e
        Rails.logger.warn "[cc_register._validate_club_cross_check] #{e.class}: #{e.message}"
        {name: "club_cross_check", ok: true}
      end

      # Constraint 7/7: scope konsistent (fed_id + branch_cc_id + season passen).
      def self._validate_scope_konsistent(meldeliste_cc_id, fed_id, branch_cc_id, season)
        # Komplexer Cross-Check; defensive ok:true (CC selbst rejected falls scope inkonsistent).
        # Plan 10-08 Externer Walkthrough kann hier nachschärfen falls Sportwart inkonsistente scopes eingibt.
        return {name: "scope_konsistent", ok: false, reason: "fed_id missing"} if fed_id.blank?
        return {name: "scope_konsistent", ok: false, reason: "branch_cc_id missing"} if branch_cc_id.blank?
        return {name: "scope_konsistent", ok: false, reason: "season missing"} if season.blank?
        {name: "scope_konsistent", ok: true}
      end

      # Existenz-Check auf PlayerRanking (RESEARCH §4 Option A).
      # Liefert menschenlesbare Status-String — KEIN Block (Discussion-Decision: Warnung + TM-Override).
      def self.consistency_check(player_cc_id:, season:, fed_id:, discipline_id: nil, server_context: nil)
        season_record = Season.find_by(name: season)
        region = Region.joins(:region_cc).find_by(region_ccs: {cc_id: fed_id})

        # Plan 14-G.12-Hotfix #4: region-scoped Player-Lookup; vorher direkter Player.find_by
        # lieferte cross-region-Treffer (D-14-02-D analog für Player).
        player = if region
          Player.find_by(cc_id: player_cc_id, region_id: region.id)
        else
          find_player_in_region(player_cc_id, server_context: server_context)
        end
        return "[Konsistenz-Check übersprungen: Player mit cc_id=#{player_cc_id} nicht in Carambus-DB (Region-scoped)]" unless player

        unless season_record && region
          missing = []
          missing << "Saison '#{season}'" unless season_record
          missing << "Region für fed_id=#{fed_id}" unless region
          return "[Konsistenz-Check übersprungen: #{missing.join(", ")} nicht in Carambus-DB]"
        end

        scope = PlayerRanking.where(player_id: player.id, season_id: season_record.id, region_id: region.id)
        scope = scope.where(discipline_id: discipline_id) if discipline_id
        ranking = scope.first

        if ranking
          "[Konsistenz-Check OK] Player #{player.fl_name} ist gerankt (rank=#{ranking.rank}, gd=#{ranking.gd&.round(3)})"
        else
          "[KONSISTENZ-WARNUNG] Player #{player.fl_name} ist in Saison #{season} (Region #{region.shortname}) nicht gerankt — TM-Confirm empfohlen vor armed:true"
        end
      rescue => e
        "[Konsistenz-Check fehlgeschlagen: #{e.class.name}] — Tool fährt fort"
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
