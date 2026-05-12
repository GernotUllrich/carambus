# frozen_string_literal: true

# cc_lookup_meldeliste_for_tournament — Phase 8 Plan 08-02 + Phase 9 Plan 09-02 (Scope-Filter-Konsolidierung).
# Resolve tournament_cc_id → meldeliste_cc_id(s) for a ClubCloud Einzelturnier.
#
# Background (SUBSTRATE-08.md Sektion 3): One Tournament may have N Meldelisten
# (Quali-Listen pro Region, separate Klassen, etc.). cc_register_for_tournament /
# cc_unregister_for_tournament / cc_update_tournament_deadline brauchen meldeliste_cc_id —
# dieses Tool liefert die Auflösung mit Disambiguation-Rückfrage bei N:1 (D-08-E).
#
# DB-first via TournamentCc → registration_list_cc → cc_id (1:1-Beziehung in Carambus-DB,
# kann N:1 sein wenn mehrere RegistrationListCc auf dasselbe Tournament verweisen).
# Falls DB-Lookup leer ODER force_refresh:true → Live-CC via showMeldelistenList Action.
#
# Plan 09-02 (v0.2.1-Spec-Issue konsolidiert): Tool akzeptiert jetzt 5 optionale Scope-Filter-Params
# (fed_cc_id/branch_cc_id/season/disciplin_id/cat_id) analog Phase 6 cc_update_tournament_deadline.
# Hybrid-POST: mit Scope-Filter → fedId/branchId/season/disciplinId/catId-Payload (Real-CC erwartet das);
# ohne Scope-Filter → meisterschaftsId-Payload (Backwards-Compat mit Plan 08-02 Mock-Tests).
#
# Output-Schema (D-08-E):
#   - 0 Treffer: error
#   - 1 Treffer: { meldeliste_cc_id: <id>, candidates: [<eintrag>] }
#   - ≥2 Treffer: { meldeliste_cc_id: nil, candidates: [...], warning: "..." }
#
# KOEXISTENZ-Pattern: showMeldelistenList ist bereits in ALLOWLIST (Phase 2/3),
# primary owner ist `cc_lookup_teilnehmerliste`. Dieses Tool ist alternativer Wrapper
# für die N:1-Disambiguation-Specific-Use-Case (read-only, kein armed-Flag).

module McpServer
  module Tools
    class LookupMeldelisteForTournament < BaseTool
      tool_name "cc_lookup_meldeliste_for_tournament"
      description <<~DESC
        Resolve tournament_cc_id → meldeliste_cc_id(s) for a ClubCloud Einzelturnier.
        Use BEFORE cc_register_for_tournament / cc_unregister_for_tournament / cc_update_tournament_deadline if meldeliste_cc_id unknown.
        One Tournament may have N Meldelisten (Quali-Listen pro Region etc.).
        Returns single meldeliste_cc_id if unambiguous; otherwise candidates-array for User-Disambiguation.
        DB-first via TournamentCc.registration_list_cc; falls DB empty or force_refresh:true, queries CC showMeldelistenList live.
        Read-only — no armed-flag needed.
      DESC
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "CC TournamentCc.cc_id (= meisterschaftsId)."},
          force_refresh: {type: "boolean", default: false, description: "If true, skips DB cache and queries CC live via showMeldelistenList."},
          fed_cc_id: {type: "integer", description: "Optional: CC federation ID (z.B. 20 für NBV). Plan 09-02 v0.2.1-Konsolidierung — wenn gesetzt, sendet showMeldelistenList Scope-Filter-Payload statt meisterschaftsId."},
          branch_cc_id: {type: "integer", description: "Optional: CC admin branch ID (z.B. 8 für Kegel admin-cc-id). Plan 09-02 — siehe fed_cc_id."},
          season: {type: "string", description: "Optional: Season-Name wie '2025/2026' (CC-Format mit Slash). Plan 09-02 Scope-Filter."},
          disciplin_id: {type: "string", description: "Optional: CC disciplinId (Default '*' Wildcard — alle Disziplinen). Plan 09-02 Scope-Filter."},
          cat_id: {type: "string", description: "Optional: CC catId. Plan 09-02 Scope-Filter."}
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(tournament_cc_id: nil, force_refresh: false,
        fed_cc_id: nil, branch_cc_id: nil, season: nil,
        disciplin_id: nil, cat_id: nil, server_context: nil)
        err = validate_required!({tournament_cc_id: tournament_cc_id}, [:tournament_cc_id])
        return err if err

        candidates = []
        scope_given = scope_filter_given?(fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
        retry_path_used = nil # Plan 10-02 Task 1: tracking für Error-Message

        # DB-first
        unless force_refresh
          candidates = fetch_from_db(tournament_cc_id)
        end

        # Live-CC-Fallback (force_refresh oder DB empty)
        if candidates.empty? || force_refresh
          live_candidates = fetch_from_cc(
            tournament_cc_id,
            fed_cc_id: fed_cc_id, branch_cc_id: branch_cc_id,
            season: season, disciplin_id: disciplin_id, cat_id: cat_id
          )
          # Live-Candidates haben Vorrang nur bei force_refresh oder DB-empty
          candidates = live_candidates if !live_candidates.empty?
        end

        # Plan 10-02 Task 1 (Befund #5 Fix): Retry-Other-Mode-Fallback —
        # wenn erster Live-CC-Versuch 0 Treffer hatte, probiere den ANDEREN Payload-Pfad.
        # Hintergrund: Phase-9-Plan-09-03 Live-Cycle Step A zeigte „0 Treffer" trotz existierender
        # Meldeliste — Ursache vermutlich Scope-Filter-Pfad-Wahl. Retry erhöht Trefferquote materiell.
        if candidates.empty?
          if scope_given
            # Erster Versuch: Scope-Filter-Pfad. Retry: meisterschaftsId-Pfad ohne Scope.
            live_retry = fetch_from_cc(tournament_cc_id)
            if !live_retry.empty?
              candidates = live_retry
              retry_path_used = "meisterschaftsId-fallback"
            end
          else
            # Erster Versuch: meisterschaftsId-Pfad. Retry: Scope-Filter mit Default-Region (CC_REGION-ENV).
            default_fed = default_fed_id
            if default_fed
              live_retry = fetch_from_cc(
                tournament_cc_id,
                fed_cc_id: default_fed,
                disciplin_id: "*", cat_id: "*"
              )
              if !live_retry.empty?
                candidates = live_retry
                retry_path_used = "scope-filter-fallback (fed_cc_id=#{default_fed})"
              end
            end
          end
        end

        case candidates.size
        when 0
          # Plan 10-02 Task 1 (Befund #5 Fix): Diagnostic Error-Message statt False-Claim.
          # Vorher: „has no Meldelisten" → Sportwart bekam falsche Info → kontaktierte Verbandsadmin unnötig.
          # Neu: Tool sagt ehrlich was es probiert hat + bietet Workarounds an.
          attempted = if scope_given
            "scope-filter (fed=#{fed_cc_id || "-"}, branch=#{branch_cc_id || "-"}, season=#{season || "-"}, discipline=#{disciplin_id || "-"}, cat=#{cat_id || "-"})"
          else
            "meisterschaftsId=#{tournament_cc_id}"
          end
          attempted += " + retry-#{retry_path_used}" if retry_path_used
          error(
            "Could not auto-resolve meldeliste_cc_id for tournament_cc_id=#{tournament_cc_id} " \
            "(attempted: #{attempted}). " \
            "This does NOT necessarily mean no meldeliste exists. Common causes: " \
            "(1) TournamentCc has no registration_list_cc_id linkage in DB, " \
            "(2) scope filter combination too narrow for CC, " \
            "(3) CC response HTML format does not match parser variants. " \
            "Workaround: pass meldeliste_cc_id directly to subsequent tool calls " \
            "(find it in CC-Admin URL of the Meldeliste-Edit-View)."
          )
        when 1
          c = candidates.first
          text(<<~OUT.strip)
            meldeliste_cc_id: #{c[:meldeliste_cc_id]}
            (1 candidate found)
            candidates: #{candidates.inspect}
          OUT
        else
          text(<<~OUT.strip)
            meldeliste_cc_id: (unresolved — multiple candidates)
            warning: Multiple Meldelisten found (#{candidates.size}) — User-Disambiguation needed.
            candidates: #{candidates.inspect}
            Pick one meldeliste_cc_id from the candidates list and use it explicitly in subsequent tool calls.
          OUT
        end
      rescue => e
        error("Tool exception: #{e.class.name} (details suppressed; check Rails.logger on stderr).")
      end

      # DB-first Lookup via TournamentCc → registration_list_cc-Beziehung.
      # Defensiv: rescue StandardError für fehlende Models / fehlende Records / nil-Werte.
      def self.fetch_from_db(tournament_cc_id)
        tcc = TournamentCc.find_by(cc_id: tournament_cc_id)
        return [] unless tcc

        # Erste Quelle: belongs_to :registration_list_cc (1:1)
        rl = tcc.registration_list_cc
        return [] unless rl

        [{
          meldeliste_cc_id: rl.cc_id,
          name: (rl.respond_to?(:name) ? rl.name : nil) || "Meldeliste #{rl.cc_id}",
          source: "db"
        }]
      rescue => e
        Rails.logger.warn "[LookupMeldelisteForTournament.fetch_from_db] #{e.class}: #{e.message}"
        []
      end

      # Live-CC-Lookup via showMeldelistenList Action.
      # Parst Response-HTML via Nokogiri; extrahiert meldeliste_cc_id + name pro Row.
      # Plan 09-02 (v0.2.1-Konsolidierung): Hybrid-POST-Logik — wenn mind. ein Scope-Filter
      # angegeben (fed_cc_id/branch_cc_id/season/disciplin_id/cat_id), sendet showMeldelistenList
      # Scope-Filter-Payload (fedId/branchId/season/disciplinId/catId) wie Real-CC erwartet
      # (Plan 08-03 Live-Test AC-1 Limited PASS — Spec-Issue konsolidiert).
      # Backwards-Compat: ohne Scope-Filter wird der bisherige meisterschaftsId-Pfad genutzt
      # (Plan 08-02 Mock-Tests bleiben grün).
      def self.fetch_from_cc(tournament_cc_id, fed_cc_id: nil, branch_cc_id: nil,
        season: nil, disciplin_id: nil, cat_id: nil)
        client = cc_session.client_for
        payload = if scope_filter_given?(fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
          {
            fedId: fed_cc_id,
            branchId: branch_cc_id,
            season: season,
            disciplinId: disciplin_id || "*",
            catId: cat_id
          }.reject { |_, v| v.nil? }
        else
          {meisterschaftsId: tournament_cc_id}
        end

        res, doc = client.post(
          "showMeldelistenList",
          payload,
          {armed: true, session_id: cc_session.cookie}
        )
        return [] if res.nil? || res.code != "200" || doc.nil?

        # Hybrid-HTML-Parser (Phase 6/7 Pattern)
        # Variante A: Mock-HTML5 mit data-Attributen
        rows = doc.css("tr[data-meldeliste-cc-id]")
        if rows.any?
          return rows.map do |row|
            {
              meldeliste_cc_id: row["data-meldeliste-cc-id"].to_i,
              name: row.text.strip[0, 80],
              source: "cc-live"
            }
          end
        end

        # Variante B: Anchor-Tags mit meldelisteId-Query-Param (Real-CC-Heuristik)
        anchors = doc.css("a[href*='meldelisteId=']")
        anchors.map do |a|
          m = a["href"].to_s.match(/meldelisteId=(\d+)/)
          next nil unless m
          {
            meldeliste_cc_id: m[1].to_i,
            name: a.text.strip[0, 80],
            source: "cc-live"
          }
        end.compact
      rescue => e
        Rails.logger.warn "[LookupMeldelisteForTournament.fetch_from_cc] #{e.class}: #{e.message}"
        []
      end

      # Plan 09-02: true wenn mind. einer der 5 Scope-Filter-Params nicht-nil ist.
      def self.scope_filter_given?(fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
        !fed_cc_id.nil? || !branch_cc_id.nil? || !season.nil? ||
          !disciplin_id.nil? || !cat_id.nil?
      end
    end
  end
end
