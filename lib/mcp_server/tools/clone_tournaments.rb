# frozen_string_literal: true

# cc_clone_tournaments — v1.3 Phase 51 (Bulk/Weg 2): klont MEHRERE Vorsaison-Turniere
# einer Saison in die Folgesaison — NUR in ClubCloud (nbv-CC-Write).
#
# FILTERBASIERT statt turnierweise: Der Landessportwart sagt „klone alle Karambol-Turniere
# der Saison 2025/2026 in die neue Saison". Das Tool ermittelt die Kandidaten SELBST
# (region-scoped, Saison + optional Branch/Disziplin) und klont sie per
# TournamentPreparation::TournamentCloner (idempotent, pro Turnier gekapselt).
#
# Warum: umgeht das Einzel-Turnier-Auflösungsproblem (AC-2). Beim Einzeltool musste das LLM
# einen Turnier-Titel aus Freitext auflösen — flaky. Hier reicht EIN High-Level-Intent
# (Saison + Sparte); es werden KEINE einzelnen IDs vom LLM übertragen.
#
# ZWEISTUFIGE Bestätigung (identisch zum Einzeltool cc_clone_tournament):
#   armed:false            → Dry-Run (Kandidatenliste + geplante Daten, keine CC-Mutation)
#   armed:true             → je Turnier Meldeliste anlegen (REVERSIBEL/löschbar)
#   armed:true release:true → je Turnier Meldeliste FREIGEBEN (IRREVERSIBEL) + Meisterschaft
module McpServer
  module Tools
    class CloneTournaments < BaseTool
      tool_name "cc_clone_tournaments"
      description <<~DESC
        Wann nutzen? Wenn der Landessportwart MEHRERE Turniere — oder alle Turniere einer Sparte/Saison — auf einmal in die neue Saison übernehmen will (Sammel-/Bulk-Klon). Für EIN einzelnes benanntes Turnier nutze stattdessen cc_clone_tournament.
        Was tippt der User typisch? 'Klone alle Karambol-Turniere der Saison 2025/2026 in die neue Saison', 'Übernimm die ganze Karambol-Saison', 'Alle Dreiband-Turniere für 2026/2027 anlegen'.
        Filterbasiert: übergib `source_season` (Quell-Saison) und optional `discipline` (Sparte/Branch, z.B. 'Karambol'). Das Tool ermittelt die passenden Turniere der Region SELBST und klont sie — du musst KEINE einzelnen Turniere auflösen und KEINE Turnier-IDs übertragen. Optional `tournament_ids` für eine explizite Teilmenge (aus cc_list_open_tournaments).
        Datum je Turnier +1 Jahr auf den nächsten gleichen Wochentag; Spielort + Format exakt aus der Quelle; Meldelisten leer. Idempotent: bereits geklonte Turniere werden übersprungen (kein Duplikat).
        ⚠️ ZWEI Stufen: `armed:true` legt je Turnier die Meldeliste an (REVERSIBEL/löschbar). Erst `armed:true, release:true` gibt die Meldelisten FREI (IRREVERSIBEL) und legt die verborgenen Meisterschaften an. `armed:false` (Default) = Dry-Run (zeigt nur den Plan).
        Rufe dieses Tool DIREKT auf. Meldet es „keine Turnier gefunden", frage Saison/Sparte nach — verweise NIE auf das ClubCloud-Portal als Ersatz.
      DESC
      input_schema(
        properties: {
          source_season: {type: "string", description: "Quell-Saison 'yyyy/yyyy+1' (z.B. '2025/2026'), aus der geklont wird. Default: aktuelle Saison."},
          target_season: {type: "string", description: "Optional: Ziel-Saison 'yyyy/yyyy+1' (Default: Folgesaison der Quell-Saison)."},
          discipline: {type: "string", description: "Optionaler Sparten-/Branch-Filter ('Karambol', 'Pool', 'Snooker', 'Kegel') oder Discipline-Name ('Dreiband'). Leer = ALLE Disziplinen der Region."},
          tournament_ids: {type: "array", items: {type: "integer"}, description: "Optional: explizite Teilmenge als Carambus tournament_id (aus cc_list_open_tournaments). Leer = alle Treffer des Saison/Branch-Filters."},
          armed: {type: "boolean", default: false, description: "false (Default) = Dry-Run. true = legt je Turnier die Meldeliste an (reversibel)."},
          release: {type: "boolean", default: false, description: "Nur zusammen mit armed:true. true = gibt je Turnier die Meldeliste FREI (IRREVERSIBEL) und legt die verborgene Meisterschaft an."}
        }
      )
      annotations(read_only_hint: false, destructive_hint: true)

      def self.call(source_season: nil, target_season: nil, discipline: nil, tournament_ids: nil,
        armed: false, release: false, server_context: nil)
        region_name = effective_cc_region(server_context)
        return scenario_config_missing_error if region_name.blank?
        region = Region.find_by(shortname: region_name)
        return error("Region '#{region_name}' nicht in Carambus gefunden — bitte LSW/SysAdmin informieren.") if region.nil?

        src_season = effective_season(server_context, override: source_season)
        return error("Quell-Saison nicht ermittelbar (source_season=#{source_season.inspect}).") unless src_season
        tgt_season = target_season.present? ? Season.find_by_name(target_season) : src_season.next_season
        return error("Ziel-Saison nicht ermittelbar (target_season=#{target_season.inspect}).") unless tgt_season

        discipline_ids = nil
        matched_branch = nil
        if discipline.present?
          discipline_ids, matched_branch = resolve_discipline_or_branch(discipline)
          return error("Discipline/Branch nicht gefunden: '#{discipline}'. Beispiele: 'Karambol', 'Pool', 'Snooker', 'Kegel' oder Discipline-Namen wie 'Dreiband'.") if discipline_ids.blank?
        end

        rel = Tournament.where(region_id: region.id, season_id: src_season.id).order(:date, :title)
        rel = rel.where(discipline_id: discipline_ids) if discipline_ids.present?
        rel = rel.where(id: Array(tournament_ids).map(&:to_i)) if tournament_ids.present?
        candidates = rel.to_a

        if candidates.empty?
          filters = ["Saison #{src_season.name}"]
          filters << "Sparte #{matched_branch || discipline}" if discipline.present?
          filters << "ids=#{Array(tournament_ids).inspect}" if tournament_ids.present?
          return error("Keine Quell-Turniere gefunden (#{filters.join(", ")}).")
        end

        # Authority pro Kandidat (Region ist bereits erzwungen; hier zählt der Disziplin-Wirkbereich).
        authorized = []
        skipped = []
        candidates.each do |t|
          if authorize!(action: :prepare_tournament, tournament: t, server_context: server_context)
            skipped << {tournament_id: t.id, title: t.title, reason: "außerhalb deines Wirkbereichs / nicht zuständig"}
          else
            authorized << t
          end
        end
        if authorized.empty?
          return error("Kein Turnier in deinem Wirkbereich (#{skipped.size} außerhalb: #{skipped.map { |s| s[:title] }.join(", ")}).")
        end

        return dry_run_response(authorized, skipped, src_season, tgt_season, matched_branch || discipline) unless armed

        # ARMED — CC-Account einmal auflösen (alle Kandidaten selbe Region → selbes Konto).
        account = resolve_cc_account(tournament: authorized.first, server_context: server_context)
        identity_block = cc_write_identity_block(account, armed: armed)
        return identity_block if identity_block
        opts = {session_id: cc_session.cookie_for(account)}

        results = authorized.map do |t|
          clone_one(t, tgt_season, release, opts)
        end

        ok_count = results.count { |r| r[:status] == "ok" }
        err_count = results.count { |r| r[:status] == "error" }
        summary = "#{ok_count}/#{results.size} geklont"
        summary += ", #{err_count} Fehler" if err_count.positive?

        McpServer::AuditTrail.write_entry(
          tool_name: "cc_clone_tournaments",
          operator: cc_audit_operator,
          payload: {source_season: src_season.name, target_season: tgt_season.name,
                    discipline: matched_branch || discipline, armed: armed, release: release,
                    tournament_ids: authorized.map(&:id), count: results.size},
          pre_validation_results: skipped,
          read_back_status: "#{ok_count}/#{results.size} ok",
          result: "success",
          user_id: account.acting_user_id
        )

        text(JSON.generate(
          mode: (release ? "released" : "armed"),
          source_season: src_season.name,
          target_season: tgt_season.name,
          discipline: matched_branch || discipline,
          summary: summary,
          results: results,
          skipped: skipped
        ))
      rescue => e
        Rails.logger.warn "[cc_clone_tournaments] #{e.class}: #{e.message}"
        error("Tool-Exception: #{e.class.name} (Details im Rails-Log).")
      end

      # Klont EIN Turnier gekapselt — ein Fehler bricht den Batch NICHT ab (pro Turnier rescue).
      def self.clone_one(tournament, target_season, release, opts)
        r = TournamentPreparation::TournamentCloner.call(
          source_tournament: tournament, armed: true, release: release, target_season: target_season, opts: opts
        )
        {
          tournament_id: tournament.id, title: tournament.title, status: "ok",
          meldeliste_cc_id: r[:meldeliste_cc_id], meldeliste_status: r[:meldeliste_status],
          meisterschaft_cc_id: r[:meisterschaft_cc_id], meisterschaft_status: r[:meisterschaft_status]
        }
      rescue => e
        Rails.logger.warn "[cc_clone_tournaments] Turnier #{tournament.id} '#{tournament.title}': #{e.class}: #{e.message}"
        {tournament_id: tournament.id, title: tournament.title, status: "error", error: "#{e.class}: #{e.message}"}
      end

      def self.dry_run_response(authorized, skipped, src_season, tgt_season, discipline_label)
        plan = authorized.map do |t|
          new_start = TournamentPreparation::TournamentCloner.shift_to_next_season_same_weekday(t.date)
          row = {
            tournament_id: t.id, title: t.title,
            from: t.date&.strftime("%Y-%m-%d"), to: new_start&.strftime("%Y-%m-%d"),
            branch: branch_name(t)
          }
          row[:warnung] = "nur Karambol ist live verifiziert — Pool/Snooker/Kegel ungetestet (D-50-03-B)" unless karambol?(t)
          row[:nicht_klonbar] = "kein CC-Turnier hinterlegt — wird beim Klonen übersprungen" if t.tournament_cc.nil?
          row
        end
        text(JSON.generate(
          mode: "dry_run",
          source_season: src_season.name,
          target_season: tgt_season.name,
          discipline: discipline_label,
          count: plan.size,
          tournaments: plan,
          skipped: skipped,
          next_steps: "armed:true → Meldelisten (reversibel); danach armed:true + release:true → FREIGABE (IRREVERSIBEL) + Meisterschaften."
        ))
      end

      def self.branch_name(tournament)
        tournament.discipline&.root&.name || tournament.discipline&.super_discipline&.name || tournament.discipline&.name
      end

      def self.karambol?(tournament)
        branch_name(tournament).to_s.match?(/karambol/i)
      end
    end
  end
end
