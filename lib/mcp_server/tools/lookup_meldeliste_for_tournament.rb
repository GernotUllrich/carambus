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
        Wann nutzen? Wenn ein Write-Tool (register/unregister/update_deadline) eine meldeliste_cc_id braucht, der User aber nur die tournament_cc_id (oder den Turniernamen via cc_lookup_tournament) kennt. Auto-Lookup-Bridge.
        Was tippt der User typisch? Selten direkt — meist transparent vor Write-Tools.
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
          club_cc_id: {type: "integer", description: "Optional: CC Club.cc_id (z.B. 1010 für BC Wedel). Plan 14-G.12: Sportwart-Scope-Anker — wenn gesetzt, primärer Discovery-Pfad via /admin/myclub/meldewesen/single/showMeldelistenList.php (club-scoped). Ohne club_cc_id → legacy LSW-Pfade als Fallback."},
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

      def self.call(tournament_cc_id: nil, club_cc_id: nil, force_refresh: false,
        fed_cc_id: nil, branch_cc_id: nil, season: nil,
        disciplin_id: nil, cat_id: nil, server_context: nil)
        err = validate_required!({tournament_cc_id: tournament_cc_id}, [:tournament_cc_id])
        return err if err

        # Plan 14-G.7 / AC-2 + Diagnostic-Logging: per-Path-Telemetrie für Production-Debug.
        # Bei tournament_cc_id=890 schlugen auf carambus_nbv-Production alle 4 Pfade fehl
        # ohne sichtbaren Grund. Diese Logs machen den nächsten Production-Test ein-Schritt-debugbar.
        # Fix selbst (Auth-/HTML-Format-Issue auf Production) → v0.5-Backlog (lokale Repro fehlt).
        # Plan 14-G.12 Task 4: Auto-Resolve club_cc_id aus Sportwart-Wirkbereich,
        # falls nicht explizit gesetzt. Defensive: bei Auth-Error (kein Wirkbereich
        # / N>1) NICHT crashen — Lookup ist read-only und LSW darf ohne Sportwart-
        # Wirkbereich querien (Fall-through zu legacy-Pfaden).
        effective_club_cc_id = if club_cc_id.present?
          club_cc_id
        else
          auto_resolved, _auth_err = resolve_club_cc_id(server_context: server_context)
          auto_resolved # nil bei N=0/N>1/kein User; Integer bei N=1
        end

        # Plan 14-G.12-Hotfix #2: Auto-Default Scope-Params aus existierenden Helpers.
        # `fed_cc_id` und `season` haben robust ableitbare Defaults aus Carambus.config /
        # current_season — ohne sie liefert die CC-API leere Responses (CC-Hierarchie-Pattern:
        # alle Eltern-Params müssen mit durchgeschleift werden). `branch_cc_id` bleibt
        # erstmal manuell (kein admin-cc-id-Mapping im Code; Hint in Error-Message).
        effective_fed = fed_cc_id || default_fed_id(server_context)
        effective_season_name = season.presence || (effective_season(server_context)&.name rescue nil)

        Rails.logger.info "[LookupMeldelistе] start tournament_cc_id=#{tournament_cc_id} club_cc_id=#{effective_club_cc_id || "-"} (explicit=#{!club_cc_id.nil?}) fed=#{effective_fed || "-"} branch=#{branch_cc_id || "-"} season=#{effective_season_name || "-"} force_refresh=#{force_refresh}"

        # Plan 14-G.12 / NEU primary path-0: Sportwart-Discovery via club-scoped showMeldelistenList.
        # Wenn effective_club_cc_id resolved → /admin/myclub/meldewesen/single/showMeldelistenList.php mit
        # clubId-Scope abfragen. Response enthält <select name="meldelisteId"> mit allen Meldelisten
        # für den Club + Branch + Saison; Tournament-Name-Match liefert meldeliste_cc_id.
        # Ohne effective_club_cc_id → Fall-through zu legacy LSW-Pfaden (Backwards-Compat).
        if effective_club_cc_id.present?
          sportwart_candidates = fetch_from_sportwart_list(
            tournament_cc_id,
            club_cc_id: effective_club_cc_id,
            fed_cc_id: effective_fed, branch_cc_id: branch_cc_id,
            season: effective_season_name, disciplin_id: disciplin_id, cat_id: cat_id,
            server_context: server_context
          )
          Rails.logger.info "[LookupMeldelistе] path-0 sportwart-list (clubId=#{effective_club_cc_id}): #{sportwart_candidates.size} candidate(s)"
          if sportwart_candidates.any?
            case sportwart_candidates.size
            when 1
              c = sportwart_candidates.first
              return text(<<~OUT.strip)
                meldeliste_cc_id: #{c[:meldeliste_cc_id]}
                (source: sportwart-showMeldelistenList; club_cc_id=#{effective_club_cc_id})
                candidates: #{sportwart_candidates.inspect}
              OUT
            else
              return text(<<~OUT.strip)
                meldeliste_cc_id: (unresolved — multiple candidates)
                warning: Multiple Meldelisten matched (#{sportwart_candidates.size}) — User-Disambiguation needed.
                candidates: #{sportwart_candidates.inspect}
                Pick one meldeliste_cc_id from the candidates list and use it explicitly.
              OUT
            end
          end
          # Fall-through nur wenn 0 Treffer — vielleicht ist der Tournament für einen
          # anderen Club registriert oder TournamentCc.name driftet von Meldeliste-Title.
        end

        # Plan 14-02.3 / F-5 (legacy primary): Live-CC-Overview via editMeldelisteCheck.php.
        # D-14-02-A Helper A — der CC selbst ist source-of-truth für meldeliste_cc_id.
        # DB-Mirror war oft veraltet (z.B. NDM 14/1 Herren cc_id 912, 30 angemeldete Spieler,
        # TournamentCc.registration_list_cc nicht verlinkt). Defensive: nil bei Network/Parse-Fail.
        overview = cc_session.fetch_meldeliste_overview(tournament_cc_id, server_context: server_context)
        Rails.logger.info "[LookupMeldelistе] path-1 live-cc-overview: #{overview ? "hit (meldeliste_cc_id=#{overview[:meldeliste_cc_id]})" : "miss (nil)"}"
        if overview && overview[:meldeliste_cc_id]
          return text(<<~OUT.strip)
            meldeliste_cc_id: #{overview[:meldeliste_cc_id]}
            (source: live-cc-overview)
            clubs_count: #{overview[:clubs]&.length || 0}
            candidates: [{meldeliste_cc_id: #{overview[:meldeliste_cc_id]}, source: "live-cc-overview"}]
          OUT
        end

        candidates = []
        scope_given = scope_filter_given?(fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)
        retry_path_used = nil # Plan 10-02 Task 1: tracking für Error-Message

        # Plan 14-02.3 / F-5: Pfad 2 fallback — DB-Bridge via TournamentCc.registration_list_cc.
        unless force_refresh
          candidates = fetch_from_db(tournament_cc_id)
          Rails.logger.info "[LookupMeldelistе] path-2 db-bridge: #{candidates.size} candidate(s)"
        end

        # Plan 14-02.3 / F-5: Pfad 3 legacy-fallback — showMeldelistenList-Parser.
        if candidates.empty? || force_refresh
          live_candidates = fetch_from_cc(
            tournament_cc_id,
            fed_cc_id: fed_cc_id, branch_cc_id: branch_cc_id,
            season: season, disciplin_id: disciplin_id, cat_id: cat_id,
            server_context: server_context
          )
          Rails.logger.info "[LookupMeldelistе] path-3 cc-live (scope_given=#{scope_filter_given?(fed_cc_id, branch_cc_id, season, disciplin_id, cat_id)}): #{live_candidates.size} candidate(s)"
          # Live-Candidates haben Vorrang nur bei force_refresh oder DB-empty
          candidates = live_candidates if !live_candidates.empty?
        end

        # Plan 10-02 Task 1 (Befund #5 Fix): Retry-Other-Mode-Fallback —
        # wenn erster Live-CC-Versuch 0 Treffer hatte, probiere den ANDEREN Payload-Pfad.
        # Hintergrund: Phase-9-Plan-09-03 Live-Cycle Step A zeigte „0 Treffer" trotz existierender
        # Meldeliste — Ursache vermutlich Scope-Filter-Pfad-Wahl. Retry erhöht Trefferquote materiell.
        # retry_path_used wird gesetzt sobald retry ATTEMPTED ist (auch wenn 0 Treffer) —
        # transparent in Error-Message, damit Sportwart sieht was alles versucht wurde.
        if candidates.empty?
          if scope_given
            # Erster Versuch: Scope-Filter-Pfad. Retry: meisterschaftsId-Pfad ohne Scope.
            retry_path_used = "meisterschaftsId-fallback"
            live_retry = fetch_from_cc(tournament_cc_id, server_context: server_context)
            candidates = live_retry if !live_retry.empty?
          else
            # Erster Versuch: meisterschaftsId-Pfad. Retry: Scope-Filter mit Default-Region (CC_REGION-ENV).
            default_fed = default_fed_id(server_context)
            if default_fed
              retry_path_used = "scope-filter-fallback (fed_cc_id=#{default_fed})"
              live_retry = fetch_from_cc(
                tournament_cc_id,
                fed_cc_id: default_fed,
                disciplin_id: "*", cat_id: "*",
                server_context: server_context
              )
              candidates = live_retry if !live_retry.empty?
            end
          end
          Rails.logger.info "[LookupMeldelistе] path-4 retry (#{retry_path_used || "skipped"}): #{candidates.size} candidate(s)"
        end

        case candidates.size
        when 0
          # Plan 14-02.3 / F-6: Sportwart-Vokabular statt Entwickler-Diagnose. Behält
          # interne attempted-Pfade als Diagnose-Tail (für Audit-Trail), aber führender
          # User-facing Text ist klar und lösungsorientiert.
          attempted = if scope_given
            "scope-filter (fed=#{fed_cc_id || "-"}, branch=#{branch_cc_id || "-"}, season=#{season || "-"}, discipline=#{disciplin_id || "-"}, cat=#{cat_id || "-"})"
          else
            "meisterschaftsId=#{tournament_cc_id}"
          end
          attempted += " + retry-#{retry_path_used}" if retry_path_used

          # Plan 14-G.12-Hotfix #2: Diagnose-Message konditional. Wenn relevante
          # Scope-Params fehlen → Hint statt „LSW kontaktieren". Vorherige Annahme
          # „keine Meldeliste in CC" ist oft falsch (Plan 14-G.12 hat empirisch
          # bewiesen: Resolver findet Meldeliste nicht, obwohl sie existiert).
          missing_scope_hints = []
          missing_scope_hints << "branch_cc_id (z.B. 8=Kegel, 6=Pool, 7=Snooker, 10=Karambol — admin-cc-ids)" if branch_cc_id.blank?
          missing_scope_hints << "fed_cc_id (z.B. 20=NBV)" if effective_fed.blank?
          missing_scope_hints << "season (z.B. '2025/2026')" if effective_season_name.blank?
          missing_scope_hints << "Sportwart-Wirkbereich (user.sportwart_locations) — oder club_cc_id explicit mitgeben" if effective_club_cc_id.blank?

          if missing_scope_hints.any?
            error(
              "Resolver konnte Meldeliste nicht finden (tournament_cc_id=#{tournament_cc_id}). " \
              "FEHLENDE PARAMS für Sportwart-Pfad: #{missing_scope_hints.join("; ")}. " \
              "Bitte Tool erneut aufrufen mit den fehlenden Params; CC-API verlangt vollständigen " \
              "Scope-Tupel (Hierarchie-Pattern). Geprüfte Pfade: live-cc-overview, db-bridge, #{attempted}."
            )
          else
            error(
              "Resolver konnte meldeliste_cc_id nicht ableiten (tournament_cc_id=#{tournament_cc_id}). " \
              "Alle Scope-Params waren gesetzt aber CC lieferte 0 Treffer. Mögliche Ursachen: " \
              "(1) Meldeliste existiert in CC unter anderem Club/Branch als angegeben — " \
              "anderen club_cc_id oder branch_cc_id probieren; " \
              "(2) Tournament-Name in Carambus-DB-Mirror weicht von CC-Meldeliste-Title ab — LSW informieren; " \
              "(3) Permission-Issue auf MCP-Server-CC-Credentials. " \
              "Geprüfte Pfade: live-cc-overview, db-bridge, #{attempted}."
            )
          end
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
        season: nil, disciplin_id: nil, cat_id: nil, server_context: nil)
        client = cc_session.client_for(server_context)
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

      # Plan 14-G.12 / NEU primary path-0:
      # Sportwart-Discovery via /admin/myclub/meldewesen/single/showMeldelistenList.php (club-scoped).
      # Response enthält ein <select name="meldelisteId"> mit allen Meldelisten für den
      # angegebenen Club + Branch + Saison. Match auf TournamentCc.name liefert die
      # meldeliste_cc_id für unsere tournament_cc_id.
      #
      # Returns Array[Hash{meldeliste_cc_id:, name:, count:, source:}] (kann leer sein).
      # Defensive: rescue StandardError → [] (analog fetch_from_cc).
      def self.fetch_from_sportwart_list(tournament_cc_id, club_cc_id:, fed_cc_id: nil,
        branch_cc_id: nil, season: nil, disciplin_id: nil, cat_id: nil, server_context: nil)
        client = cc_session.client_for(server_context)
        payload = {
          clubId: club_cc_id,
          fedId: fed_cc_id,
          branchId: branch_cc_id,
          season: season,
          disciplinId: disciplin_id || "*",
          catId: cat_id || "*"
        }.reject { |_, v| v.nil? }

        res, doc = client.post(
          "sportwart-showMeldelistenList",
          payload,
          {armed: true, session_id: cc_session.cookie}
        )
        return [] if res.nil? || res.code != "200" || doc.nil?

        # Parser für Sportwart-Response (HTML-Save-Substrate
        # `sniffs/showMeldelistenList-bcw-kegel-2026-05-16.html`):
        # <select name="meldelisteId" size="15">
        #   <option value="1310">NDM Endrunde Eurokegel [1 Meldungen]</option>
        #   <option value="1264">1. Quali NDM Eurokegel [7 Meldungen]</option>
        #   ...
        # </select>
        options = doc.css('select[name="meldelisteId"] option')
        all_candidates = options.map do |opt|
          value = opt["value"].to_s
          next nil if value.blank?
          title_with_count = opt.text.to_s.strip
          # Regex: "Title [N Meldungen]" mit optionalem Count-Suffix
          if (m = title_with_count.match(/\A(.+?)\s+\[(\d+)\s+Meldungen\]\s*\z/))
            {meldeliste_cc_id: value.to_i, name: m[1].strip, count: m[2].to_i, source: "sportwart-list"}
          else
            # Edge-Case: kein Count-Suffix (z.B. leere Liste ohne "[N Meldungen]")
            {meldeliste_cc_id: value.to_i, name: title_with_count, count: 0, source: "sportwart-list"}
          end
        end.compact

        # Tournament-Name-Match: TournamentCc.name kann von Meldeliste-Title abweichen.
        # Strategie: Exact-Match auf normalized name → Substring-Match → keine Heuristik
        # (lieber 0 Treffer zurückgeben als falsche positive Matches).
        #
        # Plan 14-G.12-Hotfix (D-14-02-D): TournamentCc.cc_id ist nur regions-eindeutig
        # (gleiche cc_id kann in mehreren Regionen vorkommen, z.B. blmr + nbv).
        # Daher Context-Filter Pflicht — Default aus server_context (oder Scenario-Config).
        # Ohne Context-Filter würde find_by den ersten Treffer zurückgeben (oft falsche Region)
        # → 0 Match-Treffer → User-facing-Bug „keine Meldeliste" trotz existierender Liste.
        context = effective_cc_region(server_context).to_s.downcase
        tcc = begin
          if context.present?
            TournamentCc.find_by(cc_id: tournament_cc_id, context: context)
          else
            TournamentCc.find_by(cc_id: tournament_cc_id) # Defensive Fallback ohne Context
          end
        rescue StandardError
          nil
        end
        return all_candidates unless tcc # Keine Tournament-Info → alle Candidates zurück (Disambiguation)

        tournament_name = tcc.name.to_s.strip
        return all_candidates if tournament_name.blank?

        # Exact-Match (case-insensitive)
        exact_matches = all_candidates.select { |c| c[:name].casecmp?(tournament_name) }
        return exact_matches if exact_matches.any?

        # Substring-Match (case-insensitive; beidseitig — Meldeliste-Title enthält Tournament-Name oder umgekehrt)
        substring_matches = all_candidates.select do |c|
          name = c[:name].to_s.downcase
          tn = tournament_name.downcase
          name.include?(tn) || tn.include?(name)
        end
        substring_matches
      rescue => e
        Rails.logger.warn "[LookupMeldelisteForTournament.fetch_from_sportwart_list] #{e.class}: #{e.message}"
        []
      end
    end
  end
end
