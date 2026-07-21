# frozen_string_literal: true

module Api
  # Plan 29-03: Nimmt den ABSCHLUSS eines Turniers vom Location Server entgegen.
  #
  # Laeuft auf dem REGION SERVER. Der Weg des Ergebnisses ist bewusst dreistufig:
  #   Location Server (gespielt) → Region Server (hier) → Phase-28-Ingest → Authority → Sync
  # Die Authority bleibt dadurch fuer Schreibzugriffe von aussen geschlossen (Betreiber-Entscheidung
  # 2026-07-21); sie holt weiterhin nur.
  #
  # WARUM DER REGION SERVER DAS ZIEL IST: Dort liegt das lokale Arbeitsexemplar des Turniers, das der
  # Sportwart pflegt. Der Location Server kennt dessen ID aus der `source_url` des globalen Turniers
  # ("<region-base>/tournaments/<lokale-id>") — dieselbe Provenienz-Konvention, die Plan 28-01 gesetzt
  # hat, nur rueckwaerts gelesen. Deshalb braucht es hier keine Aufloesung, nur eine Pruefung.
  #
  # Auth: devise-jwt + Service-Account je Region (Muster aus EntryListsController / Plan 28-01).
  class TournamentResultsController < ApplicationController
    before_action :authenticate_user!
    skip_forgery_protection

    # POST /api/tournament_results
    #
    # Body:
    #   { "schema": "carambus.tournament_result/v1",
    #     "source_tournament_id": 50002001,
    #     "entries": [ {"dbu_nr": "12345", "Gesamtrangliste": {"Rang": 1, "Bälle": 120, ...}}, ... ] }
    #
    # Response (200): { "accepted": 6, "unresolved": [...], "skipped_foreign": 0 }
    # Errors: 401 (Auth) / 404 (Turnier unbekannt) / 422 (Payload unbrauchbar)
    def create
      tournament = ::Tournament.find_by(id: params[:source_tournament_id])
      return render(json: {error: "Tournament not found"}, status: :not_found) if tournament.nil?

      entries = params[:entries]
      return render(json: {error: "entries missing"}, status: :unprocessable_entity) unless entries.is_a?(Array)

      render json: apply_entries(tournament, entries)
    end

    private

    def apply_entries(tournament, entries)
      accepted = 0
      unresolved = []
      skipped_foreign = 0
      seedings = tournament.seedings.includes(:player).to_a

      entries.each do |entry|
        ranking = entry["Gesamtrangliste"]
        next if ranking.blank?

        seeding = seeding_for(seedings, entry["dbu_nr"])
        if seeding.nil?
          # Niemals einen Spieler oder ein Seeding anlegen — Stammdaten bleiben DBU-CC-gepflegt
          # (Grundsatz aus Plan 28-01). Eine gemeldete Luecke ist besser als eine erfundene Zuordnung.
          unresolved << entry_label(entry)
          next
        end

        # Dieselbe Schutzregel wie beim Erzeugen: gescrapte Ranglisten gehoeren der ClubCloud.
        unless ::Tournament::FinalRankingWriter.writable?(seeding)
          skipped_foreign += 1
          next
        end

        ::Tournament::FinalRankingWriter.write_gesamtrangliste(seeding, ranking.to_unsafe_h.to_h)
        accepted += 1
      end

      {accepted: accepted, unresolved: unresolved, skipped_foreign: skipped_foreign}
    end

    # dbu_nr ist die einzige Kennung, die ueber Instanzgrenzen traegt — IDs sind je Instanz verschieden.
    def seeding_for(seedings, dbu_nr)
      return nil if dbu_nr.blank?

      seedings.find { |s| s.player&.dbu_nr.to_s == dbu_nr.to_s }
    end

    def entry_label(entry)
      gr = entry["Gesamtrangliste"]
      name = gr.respond_to?(:[]) ? gr["Name"] : nil
      [name.presence || "(ohne Namen)", "DBU #{entry["dbu_nr"].presence || "fehlt"}"].join(" · ")
    end
  end
end
