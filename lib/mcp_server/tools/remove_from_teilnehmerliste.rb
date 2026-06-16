# frozen_string_literal: true

# cc_remove_from_teilnehmerliste — Phase 7 Plan 07-04; Plan 33-01 (2026-06-11) Toggle-Umbau.
# Entfernt einen Spieler aus der Teilnehmerliste eines Turniers (Deakkreditierung).
#
# Plan 33-01: ersetzt den race-anfälligen 3-Schritt-Edit-Buffer-Workflow
# (editTeilnehmerlisteCheck → removePlayer.php → editTeilnehmerlisteSave) durch ZWEI
# atomare Pfade, abhängig vom Live-Zustand des Spielers (accreditation_state):
#
#   :accredited    (gemeldet + Teilnehmer, roter Toggle-Button in der Meldeliste)
#                  → POST showMeldeliste_teilnahme.php?...&pid=X  (Toggle, zurück in die Meldeliste)
#   :fast_assigned (Teilnehmer OHNE Meldeliste-Eintrag, per Schnellanmeldung eingetragen)
#                  → POST cc_remove_tn.php?...&akkpid=X  (Spieler verschwindet ganz)
#   :reported_only / :not_in_tournament → Ablehnung (nichts zu entfernen)
#
# Beide Schreib-Pfade sind atomare Single-POSTs: kein Edit-Buffer, kein Save-Step,
# kein PUT-Replace-Race. Live-State aus persistierten CC-DB-Views (DEFER-D2-1).

module McpServer
  module Tools
    class RemoveFromTeilnehmerliste < BaseTool
      tool_name "cc_remove_from_teilnehmerliste"
      description <<~DESC
        Wann nutzen? Am Turniertag, wenn der Turnierleiter einen Spieler von der Teilnehmerliste entfernt (Rückzug, versehentliche Akkreditierung korrigieren). Schreibendes Tool mit Pre-Validation-First + Audit-Trail.
        Was tippt der User typisch? 'Raus Hans Müller', 'Raus Spieler X', 'Müller zurückziehen', 'entferne Schmidt'.
        Entfernt einen Spieler aus der Teilnehmerliste eines Turniers (Rückzug nach Akkreditierung, Korrektur einer versehentlichen Übernahme).
        Zwei automatische Pfade je nach Live-Zustand: war der Spieler über die Meldeliste akkreditiert, wird er dorthin zurückgeschoben; wurde er per Schnellanmeldung direkt eingetragen, wird er ganz entfernt.
        Pass `armed: false` (default) for a dry-run that prints request details without modifying CC.
        Pass `armed: true` to actually remove — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Pass `tournament_cc_id` (= CC meisterschaftsId, REQUIRED) + `player_cc_id` (Single Integer, REQUIRED).
        Pre-Validation: player_cc_id MUSS aktuell Teilnehmer sein (sonst Ablehnung mit Hinweis).
        NICHT verwechseln mit `cc_unregister_for_tournament` (wirkt auf Meldeliste, anderer Pfad) — dieses Tool wirkt auf Teilnehmerliste-Akkreditierung.
        Symmetrisches Cleanup-Tool zu cc_assign_player_to_teilnehmerliste / cc_fast_assign_to_teilnehmerliste.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "Tournament-cc_id (= CC meisterschaftsId). REQUIRED."},
          player_cc_id: {type: "integer", description: "Player-cc_id zum Entfernen. REQUIRED. Single Integer."},
          armed: {type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POST to CC."},
          read_back: {type: "boolean", default: true, description: "If true (default) and armed:true, verify player_cc_id NOT in post-write Teilnehmerliste."},
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

        player_cc_id = player_cc_id.to_i

        # Plan 14-G.4 / F5-B: Authority-Integration. Defensiv-Skip bei unauflösbar.
        resolved_tournament = resolve_tournament(
          tournament_cc_id: tournament_cc_id, server_context: server_context
        )
        if resolved_tournament
          auth_err = authorize!(action: :manage_teilnehmerliste, tournament: resolved_tournament, server_context: server_context)
          return auth_err if auth_err
        end

        # Plan 39-03 (D-39-8/-9): effektive CC-Identität; armed:true ohne eigene CC-Identität (:none)
        # blockt hier (Dry-Run bleibt). Write läuft unter cookie_for(account).
        account = resolve_cc_account(tournament: resolved_tournament, server_context: server_context)
        identity_block = cc_write_identity_block(account, armed: armed)
        return identity_block if identity_block

        # Reuse Phase-7 helpers from AssignPlayerToTeilnehmerliste (DRY).
        scope = AssignPlayerToTeilnehmerliste.resolve_scope_filters(tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id, server_context: server_context)
        client = cc_session.client_for(server_context)

        # Plan 33-01: Live-State-Check (showTeilnehmerliste Tab-3 + showMeldeliste Tab-2) statt
        # editTeilnehmerlisteCheck-Edit-Buffer. Bestimmt sicher die Entfernungs-Richtung.
        acc = AssignPlayerToTeilnehmerliste.accreditation_state(client, tournament_cc_id, scope, player_cc_id)
        return acc[:error] if acc[:error]
        tournament_name = AssignPlayerToTeilnehmerliste.tournament_name_for(tournament_cc_id, server_context)

        # Pre-Validation: nur :accredited oder :fast_assigned sind entfernbar.
        validation_result = run_validations([
          _validate_removable(acc[:state], player_cc_id, tournament_cc_id, tournament_name)
        ])
        unless validation_result[:all_passed]
          failed_details = validation_result[:results].reject { |r| r[:ok] }.map { |r| "#{r[:name]}: #{r[:reason]}" }.join("; ")
          return error("Pre-Validation failed for cc_remove_from_teilnehmerliste. Failed: #{validation_result[:failed_constraints].inspect}. #{failed_details}")
        end

        pre_read_status = format_pre_read_status(
          verified: true,
          source: "live-cc (showTeilnehmerliste Tab-3 + showMeldeliste Tab-2)",
          warning: "Live-Zustand von player_cc_id=#{player_cc_id}: #{acc[:state]} (#{acc[:label] || "?"})."
        )

        teilnehmer_count_before = acc[:teilnehmer].size
        # Pfad-Wahl aus Live-Zustand.
        path = (acc[:state] == :accredited) ? :toggle : :fast_remove

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo
        unless armed
          aktion = if path == :toggle
            "zurück in die Meldeliste verschieben (Toggle showMeldeliste_teilnahme)"
          else
            "ganz aus der Teilnehmerliste entfernen (Schnellanmeldung ohne Meldeliste-Eintrag, cc_remove_tn)"
          end
          dry_run = <<~DRY_RUN.strip
            [DRY-RUN] Would remove player_cc_id=#{player_cc_id} (#{acc[:label] || "?"}) from Teilnehmerliste of tournament_cc_id=#{tournament_cc_id} (#{tournament_name}).
            Aktion: #{aktion}
            teilnehmerliste_count_before: #{teilnehmer_count_before}
            teilnehmerliste_count_after:  #{teilnehmer_count_before - 1}
            Live-Zustand: #{acc[:state]}
            Scope: fed_id=#{scope[:fedId]}, branch_cc_id=#{scope[:branchId]}, season=#{scope[:season]}, disciplin_id=#{scope[:disciplinId]}, cat_id=#{scope[:catId]}
            pre_read_verified: #{pre_read_status[:pre_read_verified]}
            pre_read_source: #{pre_read_status[:pre_read_source]}
            Pass armed:true to actually perform this removal.
          DRY_RUN
          if (hint = cc_identity_hint(account))
            dry_run = "#{dry_run}\n\nHinweis: #{hint}"
          end
          return text(dry_run)
        end

        # Armed=true: atomarer Single-POST je nach Pfad.
        if path == :toggle
          # :accredited — derselbe bidirektionale Toggle wie cc_assign (HAR-belegt 2026-06-11).
          payload = AssignPlayerToTeilnehmerliste.base_payload(tournament_cc_id, scope).except(:firstEntry).merge(pid: player_cc_id)
          action_name = "showMeldeliste_teilnahme"
          steps = "showMeldeliste_teilnahme (atomarer Toggle → zurück in Meldeliste)"
        else
          # :fast_assigned — cc_remove_tn.php?akkpid=<pid> (HAR-Goldvorlage schnellanmeldung_entfernen).
          payload = AssignPlayerToTeilnehmerliste.base_payload(tournament_cc_id, scope).except(:firstEntry).merge(dla: 1, akkpid: player_cc_id)
          action_name = "cc_remove_tn"
          steps = "cc_remove_tn (atomares Entfernen — Schnellanmeldungs-Spieler verschwindet ganz)"
        end

        res, doc = client.post(action_name, payload, {armed: armed, session_id: cc_session.cookie_for(account)})
        if cc_session.reauth_if_needed!(doc)
          res, doc = client.post(action_name, payload, {armed: armed, session_id: cc_session.cookie_for(account)})
        end
        return error("Unexpected nil response from CC (#{action_name}, armed mode).") if res.nil?
        return error("CC rejected at #{action_name}: #{AssignPlayerToTeilnehmerliste.parse_cc_error(doc)} (HTTP #{res&.code})") if res&.code != "200"
        parsed = AssignPlayerToTeilnehmerliste.parse_cc_error(doc)
        return error("CC rejected at #{action_name}: #{parsed}") if parsed && parsed != "(no error)"

        # Optional Read-Back (Schicht 4 Verify): Spieler darf nicht mehr Teilnehmer sein.
        # Persistierte Tab-3-View (kein Edit-Buffer). Defensiv: Hinweis statt Hard-Fail bei CC-Nachhinken.
        read_back_match = :skipped
        if read_back
          rb = McpServer::Tools::LookupTeilnehmerliste.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
          if rb.is_a?(Array)
            still_present = rb.any? { |opt| opt[:cc_id] == player_cc_id }
            read_back_match = !still_present
            unless read_back_match
              return error(
                "Read-back: Spieler ist noch in der Teilnehmerliste. " \
                "Die ClubCloud braucht einen Moment, bis sie den neuen Stand übernimmt — bitte gleich erneut prüfen."
              )
            end
          else
            return error("Read-back failed (post-write persisted read returned error). Write may have succeeded; inspect CC manually.")
          end
        end

        # Plan 10-05.1 Task 4 (D-10-04-D Audit-Trail-Pflicht):
        McpServer::AuditTrail.write_entry(
          tool_name: "cc_remove_from_teilnehmerliste",
          operator: cc_audit_operator,
          payload: {tournament_cc_id: tournament_cc_id, player_cc_id: player_cc_id, path: action_name, armed: true},
          pre_validation_results: validation_result[:results],
          read_back_status: read_back_match.to_s,
          result: "success",
          user_id: account.acting_user_id
        )

        text(<<~OUT.strip)
          Removed player_cc_id=#{player_cc_id} (#{acc[:label] || "?"}) from Teilnehmerliste of tournament_cc_id=#{tournament_cc_id} (#{tournament_name}).
          teilnehmerliste_count_before: #{teilnehmer_count_before}
          teilnehmerliste_count_after:  #{teilnehmer_count_before - 1}
          Steps completed: #{steps}#{" → Read-Back" if read_back}.
          read_back_match: #{read_back_match}
          pre_validation_passed: #{validation_result[:all_passed]}
          pre_read_verified: #{pre_read_status[:pre_read_verified]}
          pre_read_source: #{pre_read_status[:pre_read_source]}
        OUT
      rescue => e
        Rails.logger.error("[cc_remove_from_teilnehmerliste] #{e.class}: #{e.message}\n  #{e.backtrace&.first(10)&.join("\n  ")}")
        error("Tool exception: #{e.class.name} (Details siehe Rails.logger auf dem Server).")
      end

      # Plan 33-01: Matrix-Pre-Validation. Entfernbar sind nur akkreditierte Spieler
      # (:accredited via Toggle, :fast_assigned via cc_remove_tn). Ablehnung mit Sportwart-Sprache.
      def self._validate_removable(state, player_cc_id, tournament_cc_id, tournament_name)
        case state
        when :accredited, :fast_assigned
          {name: "player_entfernbar", ok: true}
        when :reported_only
          {name: "player_entfernbar", ok: false,
           reason: "Spieler #{player_cc_id} ist für #{tournament_name || "tournament_cc_id=#{tournament_cc_id}"} nur gemeldet, aber nicht akkreditiert — in der Teilnehmerliste ist nichts zu entfernen."}
        when :not_in_tournament
          {name: "player_entfernbar", ok: false,
           reason: "Spieler #{player_cc_id} ist in #{tournament_name || "tournament_cc_id=#{tournament_cc_id}"} weder gemeldet noch Teilnehmer."}
        else
          {name: "player_entfernbar", ok: false, reason: "Unbekannter Live-Zustand '#{state}' für Spieler #{player_cc_id}."}
        end
      end
    end
  end
end
