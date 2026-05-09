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
        Register a player for a ClubCloud Einzelturnier (single-tournament) Meldeliste.
        Workflow: 2-Step CC POST (cc_add → editMeldelisteSave) + optional read-only verification.
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
          fed_id:            { type: "integer", description: "ClubCloud federation ID (e.g. 20 for NBV). Optional — resolved via region lookup; ENV CC_FED_ID overrides." },
          branch_cc_id:      { type: "integer", description: "CC admin branch ID (e.g. 8 for Kegel, 10 for Karambol). NOTE: admin-cc-id from HAR/Sniff, NOT public scraping branch_id." },
          season:            { type: "string",  description: "Season name like '2025/2026' (CC sends this string format, not season_id)" },
          meldeliste_cc_id:  { type: "integer", description: "CC meldelisteId of the target Meldeliste — get from CC Meldelisten-Übersicht (admin/myclub/meldewesen/single)" },
          player_cc_id:      { type: "integer", description: "CC player ID of the player to register (Player.cc_id)" },
          club_cc_id:        { type: "integer", description: "CC club ID (Club.cc_id) — required for the form payload (clubId + selectedClubId)" },
          discipline_id:     { type: "integer", description: "Optional Carambus Discipline.id for consistency-check scoping (defaults to all disciplines)" },
          armed:             { type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POSTs to CC." }
        },
        required: ["branch_cc_id", "season", "meldeliste_cc_id", "player_cc_id", "club_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id: nil, branch_cc_id: nil, season: nil, meldeliste_cc_id: nil, player_cc_id: nil,
                    club_cc_id: nil, discipline_id: nil, armed: false, server_context: nil)
        fed_id ||= default_fed_id

        err = validate_required!(
          { branch_cc_id: branch_cc_id, season: season, meldeliste_cc_id: meldeliste_cc_id,
            player_cc_id: player_cc_id, club_cc_id: club_cc_id },
          [:branch_cc_id, :season, :meldeliste_cc_id, :player_cc_id, :club_cc_id]
        )
        return err if err

        # Schicht 3 (Server-Level): Rails-env-Check — armed:true in production blockiert.
        if armed && Rails.env.production?
          return error("Live-CC writes are blocked in Rails production env via MCP. Run from development env.")
        end

        # Konsistenz-Check (read-only) läuft in beiden armed-Pfaden.
        consistency_msg = consistency_check(
          player_cc_id: player_cc_id,
          season: season,
          fed_id: fed_id,
          discipline_id: discipline_id
        )

        # Schicht 4 (Network-Level): Detail-Dry-Run-Echo — alle IDs explizit.
        unless armed
          extras = "discipline_id=#{discipline_id}" if discipline_id
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would register player_cc_id=#{player_cc_id} into meldeliste_cc_id=#{meldeliste_cc_id} \
            (club_cc_id=#{club_cc_id}, fed_id=#{fed_id}, branch_cc_id=#{branch_cc_id}, season=#{season}#{extras ? ", #{extras}" : ""}).
            Workflow: 2-Step (addPlayerToMeldeliste → saveMeldeliste) + optional verification via showCommittedMeldeliste.
            #{consistency_msg}
            Pass armed:true to actually perform this registration.
          DRY_RUN
        end

        # Armed=true: 2-Step-Workflow + Verifikation. Field-Mapping aus SNIFF v2 §"Common Hidden-Inputs".
        # Disziplin/Kategorie als Wildcard — CC inferiert intern aus meldelisteId.
        client = cc_session.client_for
        base_payload = {
          clubId: club_cc_id, fedId: fed_id, branchId: branch_cc_id,
          disciplinId: "*", catId: "*", season: season,
          meldelisteId: meldeliste_cc_id, firstEntry: 1, rang: 1,
          selectedClubId: club_cc_id
          # NB: gd, d aus SNIFF v2 sind im Original leer; client.post().reject(&:blank?)
          # filtert sie weg. CC akzeptiert das (PHP-typisch optional fields).
        }

        # Step 1: cc_add.php — Player in Edit-Buffer
        add_res, add_doc = client.post(
          "addPlayerToMeldeliste",
          base_payload.merge(a: player_cc_id),
          { armed: armed, session_id: cc_session.cookie }
        )
        if cc_session.reauth_if_needed!(add_doc)
          add_res, add_doc = client.post(
            "addPlayerToMeldeliste",
            base_payload.merge(a: player_cc_id),
            { armed: armed, session_id: cc_session.cookie }
          )
        end
        return error("Unexpected nil response from CC (cc_add, armed mode). MockClient may have rejected.") if add_res.nil?
        return error("CC rejected at cc_add: #{parse_cc_error(add_doc)} (HTTP #{add_res&.code})") if add_res&.code != "200"
        add_parsed = parse_cc_error(add_doc)
        return error("CC rejected at cc_add: #{add_parsed}") if add_parsed && add_parsed != "(no error)"

        # Step 2: editMeldelisteSave.php — Commit Buffer in DB
        # `save: "1"` als non-blank Sentinel (CC PHP-Code prüft typisch isset($_POST['save']),
        # nicht den Wert). client.post() würde leere Strings via .reject(&:blank?) wegwerfen.
        save_res, save_doc = client.post(
          "saveMeldeliste",
          base_payload.merge(a: player_cc_id, save: "1"),
          { armed: armed, session_id: cc_session.cookie }
        )
        return error("Unexpected nil response from CC (editMeldelisteSave, armed mode).") if save_res.nil?
        return error("CC rejected at editMeldelisteSave: #{parse_cc_error(save_doc)} (HTTP #{save_res&.code})") if save_res&.code != "200"
        save_parsed = parse_cc_error(save_doc)
        return error("CC rejected at editMeldelisteSave: #{save_parsed}") if save_parsed && save_parsed != "(no error)"

        # Step 3 (Verifikation): showCommittedMeldeliste — Player-Marker im HTML-Body suchen
        # Marker aus SNIFF v2 A2: <td align="center">{player_cc_id}</td> in der commited Liste.
        verify_res, _verify_doc = client.post(
          "showCommittedMeldeliste",
          base_payload.merge(sortOrder: "player"),
          { armed: armed, session_id: cc_session.cookie }
        )
        verified = verify_res&.body.to_s.include?(%(<td align="center">#{player_cc_id}</td>))

        text(<<~OUT.strip)
          Registered player_cc_id=#{player_cc_id} into meldeliste_cc_id=#{meldeliste_cc_id} (2-Step CC workflow OK).
          verified_in_committed_list: #{verified}
          #{consistency_msg}
        OUT
      rescue StandardError => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # Existenz-Check auf PlayerRanking (RESEARCH §4 Option A).
      # Liefert menschenlesbare Status-String — KEIN Block (Discussion-Decision: Warnung + TM-Override).
      def self.consistency_check(player_cc_id:, season:, fed_id:, discipline_id: nil)
        player = Player.find_by(cc_id: player_cc_id)
        return "[Konsistenz-Check übersprungen: Player mit cc_id=#{player_cc_id} nicht in Carambus-DB]" unless player

        season_record = Season.find_by(name: season)
        region = Region.joins(:region_cc).find_by(region_ccs: { cc_id: fed_id })

        unless season_record && region
          missing = []
          missing << "Saison '#{season}'" unless season_record
          missing << "Region für fed_id=#{fed_id}" unless region
          return "[Konsistenz-Check übersprungen: #{missing.join(', ')} nicht in Carambus-DB]"
        end

        scope = PlayerRanking.where(player_id: player.id, season_id: season_record.id, region_id: region.id)
        scope = scope.where(discipline_id: discipline_id) if discipline_id
        ranking = scope.first

        if ranking
          "[Konsistenz-Check OK] Player #{player.fl_name} ist gerankt (rank=#{ranking.rank}, gd=#{ranking.gd&.round(3)})"
        else
          "[KONSISTENZ-WARNUNG] Player #{player.fl_name} ist in Saison #{season} (Region #{region.shortname}) nicht gerankt — TM-Confirm empfohlen vor armed:true"
        end
      rescue StandardError => e
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
