# frozen_string_literal: true
# cc_lookup_meldeliste_for_tournament — Phase 8 Plan 08-02.
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
          tournament_cc_id: { type: "integer", description: "CC TournamentCc.cc_id (= meisterschaftsId)." },
          force_refresh:    { type: "boolean", default: false, description: "If true, skips DB cache and queries CC live via showMeldelistenList." }
        },
        required: ["tournament_cc_id"]
      )
      annotations(read_only_hint: true, destructive_hint: false)

      def self.call(tournament_cc_id: nil, force_refresh: false, server_context: nil)
        err = validate_required!({ tournament_cc_id: tournament_cc_id }, [:tournament_cc_id])
        return err if err

        candidates = []

        # DB-first
        unless force_refresh
          candidates = fetch_from_db(tournament_cc_id)
        end

        # Live-CC-Fallback (force_refresh oder DB empty)
        if candidates.empty? || force_refresh
          live_candidates = fetch_from_cc(tournament_cc_id)
          # Live-Candidates haben Vorrang nur bei force_refresh oder DB-empty
          candidates = live_candidates if !live_candidates.empty?
        end

        case candidates.size
        when 0
          error(
            "Tournament #{tournament_cc_id} has no Meldelisten. " \
            "Either create one in CC-Admin first, or check tournament_cc_id."
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
      rescue StandardError => e
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
      rescue StandardError => e
        Rails.logger.warn "[LookupMeldelisteForTournament.fetch_from_db] #{e.class}: #{e.message}"
        []
      end

      # Live-CC-Lookup via showMeldelistenList Action.
      # Parst Response-HTML via Nokogiri; extrahiert meldeliste_cc_id + name pro Row.
      # Real-CC-HTML-Schema noch nicht final spezifiziert (Plan 08-03 Live-Test) —
      # defensiver Mock-HTML5-Parser mit Fallback auf einfache Anchor-Match-Heuristik.
      def self.fetch_from_cc(tournament_cc_id)
        client = cc_session.client_for
        res, doc = client.post(
          "showMeldelistenList",
          { meisterschaftsId: tournament_cc_id },
          { armed: true, session_id: cc_session.cookie }
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
      rescue StandardError => e
        Rails.logger.warn "[LookupMeldelisteForTournament.fetch_from_cc] #{e.class}: #{e.message}"
        []
      end
    end
  end
end
