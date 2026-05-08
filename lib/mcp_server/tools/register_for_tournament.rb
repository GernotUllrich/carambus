# frozen_string_literal: true
# cc_register_for_tournament — Phase 4 Write-Tool: Spieler in CC-Einzelturnier-Meldeliste registrieren.
# Mock-Implementation in Plan 04-02; Live-Validation + PATH_MAP-Erweiterung in Plan 04-03 nach DevTools-Sniff.
#
# Sicherheitsnetz (Defense-in-Depth, Phase-4-Definition-of-Done):
#   1. armed-Flag-Default false (Tool-Level)
#   2. Mock-Mode-Default in Tests (Test-Level — siehe register_for_tournament_test.rb)
#   3. Rails-env-Check (Server-Level — armed:true in production blockiert)
#   4. Detail-Dry-Run-Echo (Network-Level — kein Wildcard, alle ID-Werte explizit ausgegeben)
#
# Konsistenz-Check (RESEARCH §4 Option A): Existenz auf PlayerRanking — Warnung bei nicht-gerankten Spielern.

module McpServer
  module Tools
    class RegisterForTournament < BaseTool
      tool_name "cc_register_for_tournament"
      description <<~DESC
        Register a player for a ClubCloud Einzelturnier (single-tournament) Meldeliste.
        Pass `armed: false` (default) for a dry-run that prints exact request details
        (player ID, tournament ID, federation, branch, season) without modifying CC.
        Pass `armed: true` to actually register — this is a destructive write to ClubCloud.
        Tool refuses to run armed:true in Rails production env.
        Includes a read-only consistency check: warns if the player has no PlayerRanking
        for the target season/region (TM should confirm before armed:true).
      DESC
      input_schema(
        properties: {
          fed_id:           { type: "integer", description: "ClubCloud federation ID (e.g. 20 for NBV). Optional — resolved via region lookup; ENV CC_FED_ID overrides." },
          branch_id:        { type: "integer", description: "CC branch (e.g. 10 for Karambol)" },
          season:           { type: "string",  description: "Season name like '2025/2026'" },
          tournament_cc_id: { type: "integer", description: "CC tournament/Meldeliste ID for the target tournament" },
          player_cc_id:     { type: "integer", description: "CC player ID of the player to register (Player.cc_id)" },
          club_cc_id:       { type: "integer", description: "Optional CC club ID (Club.cc_id) — only required if player disambiguation needs it" },
          discipline_id:    { type: "integer", description: "Optional Carambus Discipline.id for consistency-check scoping (defaults to all disciplines)" },
          armed:            { type: "boolean", default: false, description: "If false (default), dry-run only — no CC mutation. If true, performs destructive POST to CC." }
        },
        required: ["branch_id", "season", "tournament_cc_id", "player_cc_id"]
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(fed_id: nil, branch_id: nil, season: nil, tournament_cc_id: nil, player_cc_id: nil,
                    club_cc_id: nil, discipline_id: nil, armed: false, server_context: nil)
        fed_id ||= default_fed_id

        err = validate_required!(
          { branch_id: branch_id, season: season, tournament_cc_id: tournament_cc_id, player_cc_id: player_cc_id },
          [:branch_id, :season, :tournament_cc_id, :player_cc_id]
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
          extras = []
          extras << "club_cc_id=#{club_cc_id}" if club_cc_id
          extras << "discipline_id=#{discipline_id}" if discipline_id
          extras_str = extras.empty? ? "" : ", #{extras.join(', ')}"
          return text(<<~DRY_RUN.strip)
            [DRY-RUN] Would register player_cc_id=#{player_cc_id} at tournament_cc_id=#{tournament_cc_id} \
            (fed_id=#{fed_id}, branch_id=#{branch_id}, season=#{season}#{extras_str}).
            #{consistency_msg}
            Pass armed:true to actually perform this registration.
          DRY_RUN
        end

        # Armed=true: POST gegen CC (im Mock liefert MockClient die Response).
        # NOTE: Action-Name "registerForTournament" ist Platzhalter — wird in Plan 04-03 nach
        # DevTools-Sniff finalisiert (PATH_MAP-Eintrag + ggf. Umbenennung). MockClient
        # akzeptiert beliebige Action-Namen (siehe Plan 04-02 Task 2 WRITABLE_ACTIONS_NOT_IN_PATH_MAP).
        client = cc_session.client_for
        payload = {
          fedId: fed_id, branchId: branch_id, season: season,
          meldelisteId: tournament_cc_id, playerId: player_cc_id
        }
        payload[:clubId] = club_cc_id if club_cc_id
        payload[:disciplinId] = discipline_id if discipline_id

        res, doc = client.post("registerForTournament", payload, { armed: armed, session_id: cc_session.cookie })

        if res.nil?
          return error("Unexpected nil response from CC (armed mode). MockClient may have rejected.")
        end

        # Reauth-Retry bei Login-Redirect (Pattern aus finalize_teilnehmerliste).
        if cc_session.reauth_if_needed!(doc)
          res, doc = client.post("registerForTournament", payload, { armed: armed, session_id: cc_session.cookie })
        end

        if res&.code != "200"
          return error("CC rejected: #{parse_cc_error(doc)} (HTTP #{res&.code})")
        end

        parsed = parse_cc_error(doc)
        return error("CC rejected: #{parsed}") if parsed && parsed != "(no error)"

        text("Registered player_cc_id=#{player_cc_id} at tournament_cc_id=#{tournament_cc_id}.\n#{consistency_msg}")
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
