# frozen_string_literal: true

# cc_lookup_teilnehmerliste — Plan 25-01 T3a Spike (2026-06-02).
#
# Plan 25 Live-Smoke-Befund: Pre-existing-Stub (D-18 Phase) lieferte nur einen
# HTTP-Status-String aus `showMeldelistenList` — keine Player-Liste, keine Phasen-
# Erkennung. DFP SU (cc_id=859) zeigt in CC-UI 3 Teilnehmerliste-Doppel, das alte
# Tool sagte "leer" → Sportwart-Workflow "wer ist akkreditiert?" war via MCP blind.
#
# Spike-Strategie (DRY): wiederverwendet `AssignPlayerToTeilnehmerliste.pre_read_teilnehmerliste`
# (Plan 07-04 Inline-Patch v3 `dla=1` Initial-Landing-Payload). Pre-Read parst
# editTeilnehmerlisteCheck-HTML und liefert sowohl `current_teilnehmer` (akkreditiert)
# als auch `available_in_meldeliste` (noch zur Übernahme verfügbar) plus Tournament-Name.
#
# Output-Anreicherung: Phase-Heuristik (open/partial/finalized/empty) + Counts, damit
# Claude/Sportwart sofort sieht ob Tournament im Anmelde-Stand, gemischt, oder schon
# vom Verbandsadmin finalisiert wurde.

module McpServer
  module Tools
    class LookupTeilnehmerliste < BaseTool
      tool_name "cc_lookup_teilnehmerliste"
      description "Wann nutzen? Vor Akkreditierung/Finalisierung — Turnierleiter will den aktuellen Stand der Teilnehmerliste sehen ('wer ist schon akkreditiert?'). " \
                  "Auch um den Phase-Status zu pruefen (Anmeldephase vs. schon-finalisiert). " \
                  "Was tippt der User typisch? 'Liste zeigen', 'Wer ist akkreditiert fuer die Eurokegel?', 'Status Teilnehmerliste DFP SU'. " \
                  "Liefert die committed Teilnehmerliste (akkreditierte Spieler) UND die noch zur Uebernahme verfuegbare Meldeliste-Reste. " \
                  "Phase-Indikator im Output: 'empty' (nichts da), 'open' (alle in Meldeliste, noch nicht uebernommen), " \
                  "'partial' (teils uebernommen), 'finalized' (alle in Teilnehmerliste, Meldeliste leer). " \
                  "Use VOR cc_assign_player_to_teilnehmerliste / cc_remove_from_teilnehmerliste / cc_finalize_teilnehmerliste. " \
                  "Live-CC Pfad via editTeilnehmerlisteCheck mit dla=1 (Initial-Landing-Payload). " \
                  "Plan 25-01 T3a (2026-06-02): vorheriger Stub lieferte nur Status-String."
      input_schema(
        properties: {
          tournament_cc_id: {type: "integer", description: "CC meisterschaft ID (= TournamentCc.cc_id). REQUIRED fuer Live-Pfad — oder via tournament_id mit Mirror."},
          tournament_id: {type: "integer", description: "Carambus-internal Tournament ID (alternativer Anker; setzt TournamentCc-Mirror voraus)."},
          fed_cc_id: {type: "integer", description: "Optional: CC federation ID (z.B. 20 fuer NBV). Default aus RegionCc des Mirror."},
          branch_cc_id: {type: "integer", description: "Optional: admin-cc-id (8=Kegel, 6=Pool, 7=Snooker, 10=Karambol). Default aus TournamentCc.branch_cc_id."},
          season: {type: "string", description: "Optional: Season-Name (z.B. '2025/2026'). Default aus TournamentCc.season."},
          disciplin_id: {type: "string", default: "*", description: "Optional: CC disciplinId (Default '*' Wildcard)."},
          cat_id: {type: "string", default: "*", description: "Optional: CC catId (Default '*' Wildcard)."}
        }
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(tournament_cc_id: nil, tournament_id: nil, fed_cc_id: nil, branch_cc_id: nil,
        season: nil, disciplin_id: "*", cat_id: "*", server_context: nil)
        # Anker-Resolution: tournament_cc_id direkt ODER via tournament_id->TournamentCc-Mirror.
        if tournament_cc_id.blank? && tournament_id.present?
          tc = TournamentCc.find_by(tournament_id: tournament_id)
          tournament_cc_id = tc&.cc_id
        end

        if tournament_cc_id.blank?
          return error("Bitte gib `tournament_cc_id` (CC meisterschaft ID) oder `tournament_id` (Carambus-id mit TournamentCc-Mirror) an.")
        end

        live_lookup(
          tournament_cc_id: tournament_cc_id, fed_cc_id: fed_cc_id, branch_cc_id: branch_cc_id,
          season: season, disciplin_id: disciplin_id, cat_id: cat_id, server_context: server_context
        )
      end

      def self.live_lookup(tournament_cc_id:, fed_cc_id:, branch_cc_id:, season:, disciplin_id:, cat_id:, server_context: nil)
        # Wiederverwendet AssignPlayerToTeilnehmerliste.resolve_scope_filters (DB-Fallback fuer fed/branch/season).
        scope = AssignPlayerToTeilnehmerliste.resolve_scope_filters(
          tournament_cc_id, fed_cc_id, branch_cc_id, season, disciplin_id, cat_id
        )

        missing = [:fedId, :branchId, :season].select { |k| scope[k].blank? }
        if missing.any?
          return error("Scope-Filter unvollstaendig: fehlend [#{missing.join(", ")}]. " \
                       "Bitte explizit mitgeben (z.B. fed_cc_id=20, branch_cc_id=7 fuer Snooker, season='2025/2026') " \
                       "ODER TournamentCc-DB-Mirror anlegen. " \
                       "admin-cc-ids: 8=Kegel, 6=Pool, 7=Snooker, 10=Karambol.")
        end

        client = cc_session.client_for(server_context)

        # PRIMARY READ (persistierte DB-View, stabil): showTeilnehmerliste.php fuer current_teilnehmer.
        # Plan 25-01 T3b Spike-Followup (2026-06-02): Pivot weg von editTeilnehmerlisteCheck (Edit-Buffer-View),
        # die nach Writes 1-3s eventual sein kann (User-Live-Befund: flappende Reads im Sekundenabstand).
        teilnehmer = fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
        return teilnehmer if teilnehmer.is_a?(MCP::Tool::Response)

        # SECONDARY READ (Buffer-View, kann eventual sein): editTeilnehmerlisteCheck fuer tournament_name +
        # available_in_meldeliste. Caveat im Output. Phase 26 sollte showMeldeliste.php als stabile Quelle ergaenzen.
        edit_view = AssignPlayerToTeilnehmerliste.pre_read_teilnehmerliste(client, tournament_cc_id, scope)
        meldung = (edit_view.is_a?(Hash) ? (edit_view[:available_in_meldeliste] || []) : [])
        tournament_name = edit_view.is_a?(Hash) ? edit_view[:tournament_name] : nil

        text(JSON.generate(
          tournament_cc_id: tournament_cc_id,
          tournament_name: tournament_name,
          fed_cc_id: scope[:fedId],
          branch_cc_id: scope[:branchId],
          season: scope[:season],
          phase: compute_phase(teilnehmer.size, meldung.size),
          counts: {teilnehmer: teilnehmer.size, meldung_open: meldung.size},
          current_teilnehmer: teilnehmer,
          available_in_meldeliste: meldung,
          read_pfade: {
            teilnehmer: "showTeilnehmerliste.php (persistiert, stabil)",
            meldung: "editTeilnehmerlisteCheck dla=1 (Edit-Buffer, kann nach Writes 1-3s eventual sein)"
          }
        ))
      end

      # Plan 25-01 T3b Spike: persistierte Teilnehmerliste via showTeilnehmerliste.php.
      # URL-Pattern aus User-Browser-Capture: /admin/einzel/meisterschaft/showTeilnehmerliste.php?p=<fed>-<branch>-*-<season>-*--<meisterschaftsId>-3
      # "3" am Ende = Tab-Indicator fuer Teilnehmerliste (2 = Meldeliste, 1 = Details).
      # Parser-Pattern analog read_committed_players in cc_lookup_tournament: Regex auf <td align="center">{cc_id}</td>
      # (Plan 14-G.13 Bug #3: single + double quotes akzeptieren).
      def self.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
        p_param = "#{scope[:fedId]}-#{scope[:branchId]}-*-#{scope[:season]}-*--#{tournament_cc_id}-3"
        res, _doc = client.get("showTeilnehmerliste", {p: p_param}, {session_id: cc_session.cookie})
        return error("showTeilnehmerliste fetch failed: HTTP #{res&.code}") if res.nil? || res.code != "200"

        cc_ids = res.body.to_s.scan(%r{<td align=['"]center['"]>(\d+)</td>}).flatten.map(&:to_i).uniq
        # Optional: detail-extract (last_name, first_name, club_cc_id) ueber DOM-Walk. Best-effort.
        cc_ids.map { |cc_id| extract_teilnehmer_detail(res.body, cc_id) || {cc_id: cc_id, label: cc_id.to_s} }
      rescue => e
        Rails.logger.warn "[cc_lookup_teilnehmerliste] fetch_teilnehmerliste_persisted failed: #{e.class}: #{e.message}"
        error("showTeilnehmerliste parse failed: #{e.class.name} (#{e.message})")
      end

      # Best-effort Detail-Extract um eine Player-Row aus dem HTML.
      # Heuristik: <tr>...<td align="center">{cc_id}</td>...</tr> — Cells davor sind Nachname/Vorname,
      # Cells danach enthalten Verein + VNR + Status. Bricht gracefully auf {cc_id, label} zurueck.
      def self.extract_teilnehmer_detail(body, cc_id)
        # Finde die <tr>...</tr> Sektion mit der cc_id-Cell darin (greedy-non-multiline-safe).
        match = body.match(%r{<tr[^>]*>(?:(?!</tr>).)*?<td[^>]*>#{cc_id}</td>(?:(?!</tr>).)*?</tr>}m)
        return nil unless match
        row_html = match[0]
        # Extract alle <td>-Inhalte (text-only, strip tags).
        cells = row_html.scan(%r{<td[^>]*>(.*?)</td>}m).flatten.map { |t| t.gsub(%r{<[^>]+>}, "").strip }
        # Heuristik: position-basiert (pos | nachname | vorname | pass-nr | ...weitere... | verein | vnr | status | ...)
        return nil if cells.size < 4
        cc_id_pos = cells.index(cc_id.to_s)
        return nil unless cc_id_pos && cc_id_pos >= 2
        last_name = cells[cc_id_pos - 2]
        first_name = cells[cc_id_pos - 1]
        # Best-effort Verein + VNR: suche nach numerischem 4-stelligem Wert > cc_id_pos
        vnr_pos = cells[(cc_id_pos + 1)..]&.find_index { |c| c.match?(/\A\d{3,5}\z/) && c.to_i != cc_id }
        club_name = (vnr_pos && cc_id_pos + 1 + vnr_pos >= 1) ? cells[cc_id_pos + vnr_pos] : nil
        club_cc_id = vnr_pos ? cells[cc_id_pos + 1 + vnr_pos].to_i : nil
        status = (cells[cc_id_pos + 2 + (vnr_pos || 0)] if vnr_pos)
        {
          cc_id: cc_id,
          label: [last_name, first_name].compact.reject(&:empty?).join(", ").presence || cc_id.to_s,
          club_name: club_name.presence,
          club_cc_id: club_cc_id,
          status: status.presence
        }.compact
      rescue
        {cc_id: cc_id, label: cc_id.to_s}
      end

      # Phase-Heuristik: "open" (alle in Meldeliste), "partial" (teils transferiert),
      # "finalized" (alle in Teilnehmerliste), "empty" (beide leer).
      def self.compute_phase(teilnehmer_count, meldung_count)
        return "empty" if teilnehmer_count.zero? && meldung_count.zero?
        return "open" if teilnehmer_count.zero? && meldung_count.positive?
        return "finalized" if teilnehmer_count.positive? && meldung_count.zero?
        "partial"
      end
    end
  end
end
