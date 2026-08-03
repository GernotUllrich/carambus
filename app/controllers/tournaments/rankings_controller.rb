# frozen_string_literal: true

module Tournaments
  # Plan 36-01: Die RANGLISTE eines CC-losen Turniers auf dem Region Server.
  #
  # Dritte Geschwisterseite neben Meldeliste (35-01) und Ergebnisliste (35-03): dort entsteht, WER
  # antritt und WAS gespielt wurde — hier, WIE das Turnier ausging. Damit ist der CC-lose Fluss von
  # der Meldung bis zur Auswertung geschlossen.
  #
  # ERFASSEN, NICHT BERECHNEN (Betreiber 2026-07-29): Auch in der ClubCloud wird die Ranking-Table
  # bei Direkteingabe der Ergebniszeilen manuell eingetragen, weil Serienturniere (GrandPrix,
  # NordCup) je Position eigene Punkte vergeben. Diese Seite bildet das ab. Sie sortiert nicht,
  # wertet keine `executor_params["RK"]` aus und kennt keine Gruppensieger — das waere
  # Turniermanagement, und das gehoert auf den Location Server.
  #
  # Aus den ueber 35-03 erfassten Spielen werden Baelle/Aufnahmen/HS (bzw. Siege/Niederlagen) nur
  # VORGESCHLAGEN. Platz und Punkte bleiben leer.
  class RankingsController < ApplicationController
    before_action :set_tournament
    before_action :ensure_local_server
    before_action :ensure_cc_less
    before_action :authorize_manage_teilnehmerliste, only: %i[create]

    # GET /tournaments/:tournament_id/ranking
    def show
      @schema = ranking_writer.schema
      @seedings = ranking_writer.seedings
      @clubs = ranking_writer.club_names
      @rows = rows_for_form
    end

    # POST /tournaments/:tournament_id/ranking
    def create
      result = ranking_writer.call(submitted_entries)

      redirect_to tournament_ranking_path(@tournament),
        notice: t("tournaments.rankings.flash.saved",
          written: result.written, skipped: result.skipped_foreign)
    end

    private

    def set_tournament
      @tournament = Tournament.find(params[:tournament_id])
    end

    def ranking_writer
      @ranking_writer ||= RegionServer::RankingWriter.new(tournament: @tournament)
    end

    # Gespeicherte Werte gewinnen ueber den Vorschlag — sonst ueberschriebe ein erneutes Oeffnen der
    # Seite die Korrektur des Sportwarts optisch wieder, und die naechste Speicherung schriebe den
    # abgeleiteten Wert zurueck.
    def rows_for_form
      stored = ranking_writer.stored
      suggested = ranking_writer.suggestions

      ranking_writer.seedings.each_with_object({}) do |seeding, acc|
        acc[seeding.id] = suggested[seeding.id].merge(stored[seeding.id])
      end
    end

    # params[:rankings] ist { "<seeding_id>" => { "Rang" => "1", ... } }. Die Schluessel sind die
    # Feldnamen des Schemas; `permit!` waere hier bequem, aber der Writer castet ohnehin nur, was das
    # Schema kennt — alles andere faellt still weg.
    def submitted_entries
      submitted = params[:rankings]
      return {} if submitted.blank?

      submitted.to_unsafe_h.to_h
    end

    # Wie bei den Geschwisterseiten: Turnierverwaltung nur auf lokalen Servern.
    def ensure_local_server
      return if local_server?

      flash[:alert] = t("tournaments.rankings.flash.local_server_only")
      redirect_to tournaments_path
    end

    # CC-Turniere behalten ihren gewachsenen Weg — dort berechnet und liefert die ClubCloud die
    # Rangliste, und `FinalRankingWriter.writable?` schuetzt sie zusaetzlich im Writer.
    def ensure_cc_less
      return if helpers.wizard_cc_less?(@tournament)

      redirect_to tournament_path(@tournament),
        alert: t("tournaments.rankings.flash.cc_tournament")
    end

    # Plan 32-07: dasselbe Schreib-Gate wie die uebrigen Meldelisten-/Ergebnis-Aktionen.
    def authorize_manage_teilnehmerliste
      authorize @tournament, :manage_teilnehmerliste?
    rescue Pundit::NotAuthorizedError
      flash[:alert] = I18n.t("tournaments.errors.manage_teilnehmerliste_denied")
      redirect_to(@tournament)
    end
  end
end
