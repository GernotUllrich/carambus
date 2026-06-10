# frozen_string_literal: true

# cc_lookup_teilnehmerliste — Plan 25-01 T3a Spike (2026-06-02), Plan 31-01 Live-Read-Fix.
#
# Liest Teilnehmerliste + Meldeliste immer live aus CCs persistierter DB-View:
#   - current_teilnehmer: showTeilnehmerliste.php -3 (Tab 3, akkreditierte Spieler)
#   - available_in_meldeliste: showTeilnehmerliste.php -2 (Tab 2, registrierte Spieler) minus Tab-3
#
# Plan 31-01: ersetzt den alten editTeilnehmerlisteCheck-Edit-Buffer fuer available_in_meldeliste.
# Root Cause DEFER-D2-1: Edit-Buffer spiegelt CC-UI-Aenderungen aus anderen Sessions nicht sofort wider.
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
                  "Live-CC Pfaede: showTeilnehmerliste.php -3 (Teilnehmerliste, persistiert) + -2 (Meldeliste, persistiert). " \
                  "Plan 31-01: immer live aus CC, kein Edit-Buffer-Seiteneffekt."
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
        # Plan 25-01 T3b-ContextFix (2026-06-02): cc_id ist NICHT global eindeutig in TournamentCc.
        # Memory project_cc_id_not_unique: TCc.cc_id existiert ggf. in mehreren context-Spalten
        # (z.B. cc_id 859 sowohl context=nbv (DFP SU) als auch context=blmr (2.BLMR LM 8-Ball)).
        # Default-Scope-Resolution MUSS context-scoped sein — sonst kommen falsche defaults.
        # Wir bauen den Scope hier selbst (statt AssignPlayerToTeilnehmerliste.resolve_scope_filters
        # zu nutzen, das context-unaware ist).
        context = effective_cc_region(server_context)&.to_s&.downcase

        tournament_cc = if context.present?
          TournamentCc.find_by(cc_id: tournament_cc_id, context: context)
        else
          TournamentCc.find_by(cc_id: tournament_cc_id)
        end

        # Plan 25-01 T3b-AssocFix (2026-06-02): TournamentCc hat KEINE direkte region_cc-Assoziation,
        # nur belongs_to :branch_cc, das wiederum belongs_to :region_cc. Pfad: tcc.branch_cc.region_cc.
        # User-Live-Befund: NoMethodError "undefined method 'region_cc'" wurde von Outer-Rescue
        # abgefangen und als saubere Fehlermeldung mit Workaround geliefert (= Defensive funktioniert).
        scope = {
          fedId: fed_cc_id || tournament_cc&.branch_cc&.region_cc&.cc_id,
          branchId: branch_cc_id || tournament_cc&.branch_cc&.cc_id,
          disciplinId: disciplin_id || "*",
          catId: cat_id || "*",
          season: season || tournament_cc&.season&.to_s
        }.compact

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

        # SECONDARY READ (persistiert, stabil): showTeilnehmerliste.php -2 (Meldeliste-Tab).
        # Plan 31-01 T1: ersetzt editTeilnehmerlisteCheck (Edit-Buffer) — der spiegelt CC-UI-Aenderungen
        # aus anderen Browser-Sessions nicht sofort wider. Tab-2 liest direkt aus CCs persistierter DB-View.
        all_registered = fetch_meldeliste_persisted(client, tournament_cc_id, scope)
        akkreditierte_ids = teilnehmer.map { |t| t[:cc_id] }.to_set
        meldung = all_registered.reject { |r| akkreditierte_ids.include?(r[:cc_id]) }
        tournament_name = tournament_cc&.name

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
            teilnehmer: "showTeilnehmerliste.php -3 (persistiert, stabil)",
            meldung: "showMeldeliste.php -2 (persistiert, stabil)"
          }
        ))
      rescue => e
        Rails.logger.error "[cc_lookup_teilnehmerliste] live_lookup CRASH tournament_cc_id=#{tournament_cc_id}: #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}"
        error("Tool-internal Fehler beim Read der Teilnehmerliste fuer tournament_cc_id=#{tournament_cc_id}: #{e.class.name} (#{e.message}). " \
              "Workaround: cc_lookup_tournament(cc_id: #{tournament_cc_id}, with_committed_list: true, meldeliste_cc_id: <override>) — siehe production-log fuer Stacktrace.")
      end

      # Plan 25-01 T3b Spike + T3b-Hotfix (2026-06-02): persistierte Teilnehmerliste via showTeilnehmerliste.php.
      # URL-Pattern aus User-Browser-Capture: /admin/einzel/meisterschaft/showTeilnehmerliste.php?p=<fed>-<branch>-*-<season>-*--<meisterschaftsId>-3
      # "3" am Ende = Tab-Indicator fuer Teilnehmerliste (2 = Meldeliste, 1 = Details).
      #
      # T3b-Hotfix Parser-Pivot: live-HTML-Capture (DFP SU 2026-06-02) zeigt, dass
      # CC die Player-cc_id NICHT in einer eigenen <td align="center">-Cell rendert
      # (mein erster Spike-Regex aus read_committed_players match fehl). Stattdessen
      # ist die cc_id im title-Attribut des showTeilnehmer.php-Links eingebettet:
      #   <a href="showTeilnehmer.php?p=...-859-10165&amp;"
      #      title="Ben Ghaffar, Ramzi (10165)" class="cc_bluelink">Ben Ghaffar</a>
      # Sauberer Parse: title-Attribut liefert Last+First+cc_id atomar. Plus die
      # vorhandenen <td align="center">-Cells nutzen `class="bb1" align="center"`-
      # Attribute-Reihenfolge — mein alter Regex `<td align=...>` matched das nicht.
      def self.fetch_teilnehmerliste_persisted(client, tournament_cc_id, scope)
        p_param = "#{scope[:fedId]}-#{scope[:branchId]}-*-#{scope[:season]}-*--#{tournament_cc_id}-3"
        Rails.logger.info "[cc_lookup_teilnehmerliste] fetch p_param=#{p_param.inspect} session_id_prefix=#{cc_session.cookie&.[](0..7)}"
        res, _doc = client.get("showTeilnehmerliste", {p: p_param}, {session_id: cc_session.cookie})
        return error("showTeilnehmerliste fetch failed: HTTP #{res&.code}") if res.nil? || res.code != "200"

        # Plan 25-01 T3b-DiagLog (2026-06-02): Diagnose-Output fuer das False-Negativ-Problem
        # (DFP SU Browser zeigt 3 Spieler, Tool sagt 0). Body-Inspect zeigt ob Session expired
        # (Login-Form-HTML statt Tabelle) oder URL-Encoding das CC verwirrt.
        body = res.body.to_s
        # Plan 25-01 T3b-QuoteFix (2026-06-02): CC sendet single quotes (' nicht "), siehe
        # Memory Plan-14-G.13 Bug #3. Pattern MUSS beide Quote-Forms akzeptieren.
        # title_count + DiagLog bleiben fuer Robustheits-Monitoring noch eine Runde.
        title_count = body.scan(/title=["'][^"']+\(\d+\)["']/).size
        first_anchor = body[/<a\s[^>]{0,400}cc_bluelink[^>]{0,200}>[^<]{0,80}<\/a>/]
        Rails.logger.info "[cc_lookup_teilnehmerliste] body_bytes=#{body.bytesize} has_cc_bluelink=#{body.include?("cc_bluelink")} has_loginButton=#{body.include?("loginButton")} title_with_id_count=#{title_count}"
        Rails.logger.info "[cc_lookup_teilnehmerliste] first_anchor=#{first_anchor.inspect}"

        # Scan: title='Last, First (cc_id)' class='cc_bluelink' — accepts both ' and ".
        matches = body.scan(/title=["']([^"']+?)\s*\((\d+)\)["']\s+class=["']cc_bluelink["']/)
        matches.uniq { |_name, cc_id| cc_id.to_i }.map do |name, cc_id|
          {cc_id: cc_id.to_i, label: name.strip}
        end
      rescue => e
        Rails.logger.warn "[cc_lookup_teilnehmerliste] fetch_teilnehmerliste_persisted failed: #{e.class}: #{e.message}"
        error("showTeilnehmerliste parse failed: #{e.class.name} (#{e.message})")
      end

      # Plan 31-01 T1 (Bug-Fix 2026-06-10): persistierte Meldeliste via meisterschaft-showMeldeliste.
      # Smoke-Test 2026-06-10 ergab: showTeilnehmerliste.php -2 hat anderes HTML-Format als -3;
      # tatsaechliche Meldeliste liegt auf showMeldeliste.php (Endpunkt "meisterschaft-showMeldeliste").
      # URL-Pattern: /admin/einzel/meisterschaft/showMeldeliste.php?p=<fed>-<branch>-*-<season>-*--<meisterschaftsId>-2
      # HTML-Format (live-capture): <tr class="even|odd"> mit <td class="bb1"><b>Nachname</b></td>
      #   <td class="bb1"><b>Vorname</b></td> <td class="bb1" align="center">cc_id</td>
      # Bei HTTP-Fehler: [] (defensiv — Lookup laeuft mit leerem Ergebnis weiter).
      def self.fetch_meldeliste_persisted(client, tournament_cc_id, scope)
        p_param = "#{scope[:fedId]}-#{scope[:branchId]}-*-#{scope[:season]}-*--#{tournament_cc_id}-2"
        Rails.logger.info "[cc_lookup_teilnehmerliste] fetch_meldeliste p_param=#{p_param.inspect}"
        res, _doc = client.get("meisterschaft-showMeldeliste", {p: p_param}, {session_id: cc_session.cookie})
        return [] if res.nil? || res.code != "200"

        body = res.body.to_s
        Rails.logger.info "[cc_lookup_teilnehmerliste] meldeliste body_bytes=#{body.bytesize} has_bb1=#{body.include?("bb1")} has_loginButton=#{body.include?("loginButton")}"

        # Live-HTML: <td class="bb1"><b>Nachname</b></td><td class="bb1"><b>Vorname</b></td>
        #            <td class="bb1" align="center">10024</td>  (Pass-Nr. = cc_id)
        matches = body.scan(/<td class="bb1"><b>([^<]+)<\/b><\/td>\s*<td class="bb1"><b>([^<]+)<\/b><\/td>\s*<td class="bb1" align="center">(\d+)<\/td>/m)
        matches.uniq { |_nachname, _vorname, cc_id| cc_id.to_i }.map do |nachname, vorname, cc_id|
          {cc_id: cc_id.to_i, label: "#{nachname}, #{vorname}"}
        end
      rescue => e
        Rails.logger.warn "[cc_lookup_teilnehmerliste] fetch_meldeliste_persisted failed: #{e.class}: #{e.message}"
        []
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
