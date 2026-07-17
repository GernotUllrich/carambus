# frozen_string_literal: true

# cc_fast_assign_to_teilnehmerliste — Plan 32-01 (DEFER-D2-2, 2026-06-10).
#
# Schnellanmeldung: Spieler direkt via foundpid in die Teilnehmerliste eintragen.
# Kein Pre-Read, kein Edit-Buffer, kein 3-Step-Workflow — atomarer Single-POST.
#
# Endpoint: POST /admin/einzel/meisterschaft/cc_fast_assign.php
# Pflicht-Params: meisterschaftsId (tournament_cc_id) + foundpid (player_cc_id) + fedId + branchId
# Optional: akkpid (leer = reines Hinzufügen; befüllt = Spieler-Swap)
#
# Vorteile gegenüber cc_assign_player_to_teilnehmerliste:
# - Kein PUT-Replace-Race (kein Edit-Buffer)
# - Kein Meldeschluss-Workaround nötig
# - Spieler muss NICHT in Meldeliste sein
#
# Sicherheitsnetz (Defense-in-Depth):
#   1. armed-Flag-Default false (Dry-Run)
#   2. Pre-Validation: tournament_cc_id + player_cc_id + Scope (fedId/branchId)
#   3. Audit-Trail bei armed:true
#   4. Read-Back via showTeilnehmerliste (Tab-3, defensiv)

module McpServer
  module Tools
    class FastAssignToTeilnehmerliste < BaseTool
      tool_name "cc_fast_assign_to_teilnehmerliste"
      description <<~DESC
        Wann nutzen? Am Turniertag — Spieler direkt in die Teilnehmerliste eintragen ohne Meldelisten-Umweg.
        Unterschied zu cc_assign_player_to_teilnehmerliste: kein Pre-Read, kein Edit-Buffer, kein Race-Condition-Risiko.
        Spieler muss NICHT in der Meldeliste sein (Schnellanmeldung direkt via CC-ID).
        Was tippt der User typisch? 'Schnell akkreditieren X', 'Fast-Assign Y', 'Direkt eintragen Z'.
        Akzeptiert player_cc_id (CC-Spieler-ID) ODER player_name (Auto-Resolve via cc_search_player).
        Optional: replace_player_cc_id (akkpid) fuer Spieler-Swap (Ersatz eines bereits akkreditierten Spielers).
        Pass armed:false (default) fuer Dry-Run. Pass armed:true fuer Live-Write in CC.
        Schreibendes Tool mit Audit-Trail (armed:true).
      DESC

      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "CC meisterschaftsId (= TournamentCc.cc_id). REQUIRED."},
          player_cc_id: {type: "integer", description: "CC Spieler-ID (foundpid). REQUIRED — oder player_name fuer Auto-Resolve."},
          player_name: {type: "string", description: "Alternative zu player_cc_id: Spielername-Suche via cc_search_player."},
          replace_player_cc_id: {type: "integer", description: "Optional: CC-ID des zu ersetzenden Spielers (akkpid). Leer = reines Hinzufuegen; gesetzt = Spieler-Swap."},
          fed_cc_id: {type: "integer", description: "Optional: CC federation ID (z.B. 20 fuer NBV). Default aus DB-Mirror des Turniers."},
          branch_cc_id: {type: "integer", description: "Optional: admin-cc-id (8=Kegel, 6=Pool, 7=Snooker, 10=Karambol). Default aus DB-Mirror des Turniers."},
          armed: {type: "boolean", default: false, description: "false (default) = Dry-Run. true = Live-Write in CC (destruktiv)."}
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(tournament_cc_id: nil, player_cc_id: nil, player_name: nil,
        replace_player_cc_id: nil, fed_cc_id: nil, branch_cc_id: nil,
        armed: false, server_context: nil)

        # player_name → player_cc_id Auto-Resolve
        if player_cc_id.blank? && player_name.present?
          resolved_id, err = resolve_player_cc_id_from_name(
            player_cc_id: nil, player_name: player_name, server_context: server_context
          )
          return error(err) if err
          player_cc_id = resolved_id
        end

        # Required-Validation
        err = validate_required!(
          {tournament_cc_id: tournament_cc_id, player_cc_id: player_cc_id},
          [:tournament_cc_id, :player_cc_id]
        )
        return err if err

        # Scope-Resolution: fedId + branchId aus DB-Mirror oder explizit
        context = effective_cc_region(server_context).to_s.downcase
        tournament_cc = begin
          if context.present?
            TournamentCc.find_by(cc_id: tournament_cc_id.to_i, context: context)
          else
            TournamentCc.find_by(cc_id: tournament_cc_id.to_i)
          end
        rescue => e
          Rails.logger.warn "[cc_fast_assign] TournamentCc-Lookup failed: #{e.class}: #{e.message}"
          nil
        end

        effective_fed = (fed_cc_id || tournament_cc&.branch_cc&.region_cc&.cc_id || default_fed_id(server_context))&.to_i
        effective_branch = (branch_cc_id || tournament_cc&.branch_cc&.cc_id)&.to_i

        if effective_fed.blank? || effective_branch.blank?
          missing = []
          missing << "fed_cc_id (z.B. 20=NBV)" if effective_fed.blank?
          missing << "branch_cc_id (8=Kegel, 6=Pool, 7=Snooker, 10=Karambol)" if effective_branch.blank?
          return error(
            "Scope-Params fehlen: #{missing.join("; ")}. " \
            "Bitte explizit angeben oder cc_whoami aufrufen um Scope zu ermitteln."
          )
        end

        akkpid = replace_player_cc_id.present? ? replace_player_cc_id.to_s : ""
        swap_mode = replace_player_cc_id.present?
        tournament_name = tournament_cc&.name

        # Plan 39-03 (D-39-8/-9): effektive CC-Identität (TL-Vererbung via Turnier); armed:true
        # ohne eigene CC-Identität (:none) blockt hier (Dry-Run bleibt). Write läuft unter cookie_for(account).
        account = resolve_cc_account(tournament: tournament_cc&.tournament, server_context: server_context)
        identity_block = cc_write_identity_block(account, armed: armed)
        return identity_block if identity_block

        # Dry-Run
        unless armed
          dry = <<~DRY.strip
            [DRY-RUN] cc_fast_assign_to_teilnehmerliste
            tournament_cc_id: #{tournament_cc_id} (#{tournament_name || "unbekannt"})
            player_cc_id:     #{player_cc_id} (foundpid)
            replace_player:   #{swap_mode ? "#{replace_player_cc_id} (SWAP-Modus)" : "— (reines Hinzufuegen)"}
            akkpid:           "#{akkpid}"
            fedId:            #{effective_fed}
            branchId:         #{effective_branch}
            Modus:            #{swap_mode ? "Swap — ersetzt Spieler #{replace_player_cc_id}" : "Add — fuegt Spieler hinzu"}
            Pass armed:true um tatsaechlich in CC zu schreiben.
          DRY
          if (hint = cc_identity_hint(account))
            dry = "#{dry}\n\nHinweis: #{hint}"
          end
          return text(dry)
        end

        # Armed=true: POST cc_fast_assign.php
        client = cc_session.client_for(server_context)
        payload = {
          meisterschaftsId: tournament_cc_id,
          foundpid: player_cc_id,
          akkpid: akkpid,
          fedId: effective_fed,
          branchId: effective_branch
        }

        res, _doc = client.post("cc_fast_assign", payload, {armed: true, session_id: cc_session.cookie_for(account)})
        if res.nil? || res.code != "200"
          McpServer::AuditTrail.write_entry(
            tool_name: "cc_fast_assign_to_teilnehmerliste",
            operator: cc_audit_operator,
            payload: payload,
            pre_validation_results: [{name: "http_response", ok: false, reason: "HTTP #{res&.code}"}],
            read_back_status: "skipped",
            result: "cc-error",
            user_id: account.acting_user_id
          )
          return error("CC rejected cc_fast_assign: HTTP #{res&.code}")
        end

        # Read-Back: prüfe ob Spieler in Teilnehmerliste erscheint (defensiv, keine Fehler-Eskalation)
        read_back_status = "skipped"
        begin
          scope = {fedId: effective_fed, branchId: effective_branch, season: tournament_cc&.season&.to_s, disciplinId: "*", catId: "*"}
          if scope[:season].present?
            confirmed_list = McpServer::Tools::LookupTeilnehmerliste.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
            if confirmed_list.is_a?(Array)
              read_back_status = confirmed_list.any? { |p| p[:cc_id] == player_cc_id.to_i } ? "match" : "mismatch"
            end
          end
        rescue => e
          Rails.logger.warn "[cc_fast_assign] read-back failed (non-fatal): #{e.class}: #{e.message}"
          read_back_status = "failed"
        end

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_fast_assign_to_teilnehmerliste",
          operator: cc_audit_operator,
          payload: payload,
          pre_validation_results: [{name: "http_response", ok: true, reason: "HTTP 200"}],
          read_back_status: read_back_status,
          result: "success",
          user_id: account.acting_user_id
        )

        text(<<~OUT.strip)
          cc_fast_assign_to_teilnehmerliste: success
          tournament_cc_id: #{tournament_cc_id} (#{tournament_name || "unbekannt"})
          player_cc_id:     #{player_cc_id}
          modus:            #{swap_mode ? "Swap (ersetzt #{replace_player_cc_id})" : "Add"}
          read_back:        #{read_back_status}
          #{"Hinweis: read_back=mismatch — Spieler nicht sofort in Teilnehmerliste sichtbar. CC-View braucht evtl. einen Moment." if read_back_status == "mismatch"}
        OUT
      rescue => e
        Rails.logger.error "[cc_fast_assign_to_teilnehmerliste] #{e.class}: #{e.message}\n  #{e.backtrace&.first(8)&.join("\n  ")}"
        error("Tool exception: #{e.class.name}: #{e.message} (Details siehe Rails.logger auf Server).")
      end
    end
  end
end
