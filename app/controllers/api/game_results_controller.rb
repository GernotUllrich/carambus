# frozen_string_literal: true

module Api
  # Plan 32-08: Nimmt SPIEL-ERGEBNISZEILEN vom Location Server entgegen — laufend waehrend des
  # Turniers, eine Zeile je abgeschlossenem Spiel (Betreiber-Entscheidungen D4/D5/D8).
  #
  # Laeuft auf dem REGION SERVER, der hier die Rolle der ClubCloud einnimmt: er haelt die
  # Ergebniszeilen, bis die Authority sie holt (Plan 32-10). Die Authority bleibt fuer
  # Schreibzugriffe von aussen geschlossen (Betreiber-Entscheidung 2026-07-21) — deshalb geht der
  # Weg ueber den Region Server und nicht direkt.
  #
  # ABGRENZUNG ZU /api/tournament_results (Plan 29-03): dort reist die GESAMTRANGLISTE beim
  # Turnier-ABSCHLUSS, hier reisen einzelne SPIELE waehrend des Turniers. Andere Kadenz, anderes
  # Objekt — deshalb ein eigener Endpunkt, der den 29-03-Weg unberuehrt laesst.
  #
  # LESEN VS. SCHREIBEN (Betreiber-Entscheidung D9, 2026-07-24): Dieser SCHREIB-Weg ist
  # authentifiziert — er ist die "Adminschnittstelle" im CC-Sinn. Die oeffentliche Lese-Sicht
  # entsteht in Plan 32-10 daneben (Api::Public), nicht hier.
  #
  # Auth: devise-jwt + Service-Account je Region (Muster aus EntryListsController / Plan 28-01).
  class GameResultsController < ApplicationController
    before_action :authenticate_user!
    skip_forgery_protection

    # CC-lose regionale Ligen (Betreiber-Hinweis 2026-07-24) laufen ueber PartyGame/Party und
    # brauchen spaeter denselben Kanal. Das Schemafeld jetzt mitzufuehren kostet nichts,
    # es nachzuruesten waere teuer. Unterstuetzt wird heute ausschliesslich "Tournament".
    SUPPORTED_TARGET_TYPES = %w[Tournament].freeze

    # POST /api/game_results
    #
    # Body:
    #   { "schema": "carambus.game_result/v1",
    #     "target_type": "Tournament",
    #     "source_tournament_id": 50000021,
    #     "tournament_plan_id": 42,
    #     "games": [ { "group": "Gruppe A", "seqno": 7, "ended_at": "2026-07-24T14:12:00+02:00",
    #                  "participations": [
    #                    {"dbu_nr": "12345", "role": "playera", "result": 100, "innings": 24, "hs": 16, "gd": 4.17},
    #                    {"dbu_nr": "95678", "role": "playerb", "result": 85,  "innings": 24, "hs": 9,  "gd": 3.54}
    #                  ] } ] }
    #
    # `group` traegt den VEREINFACHTEN Namen, nicht den feinen `game.gname` — die Vereinfachung
    # passiert beim Sender, wie im CC-Weg.
    #
    # Response (200): { "accepted": 1, "updated": 0, "unresolved": [...] }
    # Errors: 401 (Auth) / 404 (Turnier unbekannt) / 422 (Payload unbrauchbar, globales Turnier,
    #         unbekanntes target_type, abweichender Turnierplan)
    def create
      target_type = params[:target_type].presence || "Tournament"
      unless SUPPORTED_TARGET_TYPES.include?(target_type)
        return render(json: {error: "target_type '#{target_type}' not supported"},
          status: :unprocessable_entity)
      end

      tournament = ::Tournament.find_by(id: params[:source_tournament_id])
      return render(json: {error: "Tournament not found"}, status: :not_found) if tournament.nil?

      # Ergebnisse gehoeren an das LOKALE Arbeitsexemplar. Ein globales Turnier waere
      # Authority-Hoheit — LocalProtector wuerde ohnehin greifen, aber ein klarer Fehler ist
      # besser als eine Exception.
      if tournament.id < ::Tournament::MIN_ID
        return render(json: {error: "Tournament is global — results belong to the local working copy"},
          status: :unprocessable_entity)
      end

      games = params[:games]
      return render(json: {error: "games missing"}, status: :unprocessable_entity) unless games.is_a?(Array)

      result = ::RegionServer::GameResultIngest.new(
        tournament: tournament,
        games: games.map { |game| game.to_unsafe_h.to_h },
        tournament_plan_id: params[:tournament_plan_id]
      ).call

      return render(json: {error: result.error}, status: :unprocessable_entity) if result.error.present?

      render json: {accepted: result.accepted, updated: result.updated, unresolved: result.unresolved}
    end
  end
end
