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
        parsed = AssignPlayerToTeilnehmerliste.pre_read_teilnehmerliste(client, tournament_cc_id, scope)
        # pre_read returns either Hash with [:tournament_name, :current_teilnehmer, :available_in_meldeliste]
        # OR error(...)-Tool-Result (auf HTTP/Parse-Fehler).
        return parsed unless parsed.is_a?(Hash)

        teilnehmer = parsed[:current_teilnehmer] || []
        meldung = parsed[:available_in_meldeliste] || []

        text(JSON.generate(
          tournament_cc_id: tournament_cc_id,
          tournament_name: parsed[:tournament_name],
          fed_cc_id: scope[:fedId],
          branch_cc_id: scope[:branchId],
          season: scope[:season],
          phase: compute_phase(teilnehmer.size, meldung.size),
          counts: {teilnehmer: teilnehmer.size, meldung_open: meldung.size},
          current_teilnehmer: teilnehmer,
          available_in_meldeliste: meldung
        ))
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
