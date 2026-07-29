# frozen_string_literal: true

module Tournaments
  # Plan 35-03: Die ERGEBNISLISTE für CC-lose Turniere auf dem Region Server.
  #
  # Der LSW überträgt hier Spielergebnisse aus Papier-/PDF-Spielberichten. Bewusst entkoppelt vom
  # TableMonitor: der läuft am Spielort auf dem Location Server, der Region Server ist reiner
  # Verwaltungsplatz (Betreiber 2026-07-25). Das bestehende Ergebnis-Partial
  # (tournament_monitors/_game_results.html.erb) ist deshalb NICHT wiederverwendbar — es setzt
  # `tournament_monitor` und `table_monitor.present?` voraus, beides existiert hier nicht.
  #
  # Geschwisterseite zu Tournaments::EntryListsController (35-01): gleiche Gates, gleicher Aufbau.
  # Dort entsteht die Meldeliste, hier die Ergebnisliste — zusammen der CC-lose Fluss.
  class GameResultsController < ApplicationController
    before_action :set_tournament
    before_action :ensure_local_server
    before_action :ensure_cc_less
    before_action :authorize_manage_teilnehmerliste, only: %i[create destroy]

    # GET /tournaments/:tournament_id/game_results
    def show
      @games = recorded_games
      @selectable_names = RegionServer::AcceptancePlan.selectable_names
      @selectable_players = selectable_players
    end

    # POST /tournaments/:tournament_id/game_results
    def create
      error = validation_error
      if error.present?
        return redirect_to tournament_game_results_path(@tournament), alert: error
      end

      written = RegionServer::GameResultWriter.new(
        tournament: @tournament,
        gname: params[:gname],
        seqno: params[:seqno],
        ended_at: Time.current,
        participations: submitted_participations
      ).call

      key = written.created ? "recorded" : "updated"
      redirect_to tournament_game_results_path(@tournament),
        notice: t("tournaments.game_results.flash.#{key}", gname: params[:gname], seqno: params[:seqno])
    end

    # DELETE /tournaments/:tournament_id/game_results/:id
    def destroy
      game = @tournament.games.where(id: params[:id]).first

      # Nur lokale Spiele: globale gehören der Authority und kämen beim nächsten Sync ohnehin
      # zurück (dieselbe Grenze wie bei der Meldeliste, PlayerRegistration.withdraw).
      if game.nil? || game.id < Game::MIN_ID
        return redirect_to tournament_game_results_path(@tournament),
          alert: t("tournaments.game_results.flash.delete_failed")
      end

      game.destroy!

      # Plan 36-03: auch eine Löschung muss oben ankommen — sonst bliebe die zurückgezogene
      # Ergebniszeile global stehen und flösse weiter ins Ranking ein. Der Anstoß im
      # GameResultWriter deckt nur das Schreiben ab; dieser Pfad läuft nicht durch ihn.
      # (Das Gegenstück auf der Authority ist GameResultImporter#prune_removed_games.)
      GameResultSyncJob.enqueue_for(tournament: @tournament)

      redirect_to tournament_game_results_path(@tournament),
        notice: t("tournaments.game_results.flash.deleted")
    end

    private

    def set_tournament
      @tournament = Tournament.find(params[:tournament_id])
    end

    def recorded_games
      @tournament.games.includes(game_participations: :player).order(:gname, :seqno)
    end

    # Nur gemeldete Spieler MIT dbu_nr. Ohne sie verwirft der Authority-Importer die Zeile still
    # (game_result_importer.rb:117-129) — das Ergebnis sähe lokal richtig aus und käme oben nie an.
    def selectable_players
      @tournament.seedings
        .where.not(state: "no_show")
        .includes(:player)
        .filter_map { |s| s.player }
        .select { |p| p.dbu_nr.present? }
        .uniq
        .sort_by { |p| p.fullname.to_s }
    end

    # Serverseitig prüfen, nicht nur im Formular — ein Formular ist keine Zusicherung.
    def validation_error
      return t("tournaments.game_results.flash.name_invalid") unless
        RegionServer::AcceptancePlan.accepts?(params[:gname])
      return t("tournaments.game_results.flash.seqno_missing") if params[:seqno].blank?

      ids = [params[:player_a_id], params[:player_b_id]]
      return t("tournaments.game_results.flash.players_missing") if ids.any?(&:blank?)
      return t("tournaments.game_results.flash.players_equal") if ids.first == ids.last

      allowed = selectable_players.map(&:id).map(&:to_s)
      return t("tournaments.game_results.flash.players_unknown") unless ids.all? { |id| allowed.include?(id.to_s) }

      nil
    end

    def submitted_participations
      players = selectable_players.index_by(&:id)

      [
        {suffix: "a", id: params[:player_a_id]},
        {suffix: "b", id: params[:player_b_id]}
      ].map do |side|
        {
          player: players[side[:id].to_i],
          result: params[:"result_#{side[:suffix]}"].presence,
          innings: params[:"innings_#{side[:suffix]}"].presence,
          hs: params[:"hs_#{side[:suffix]}"].presence
        }
      end
    end

    # Wie im Meldelisten-Fluss (35-01): Turnierverwaltung nur auf lokalen Servern.
    def ensure_local_server
      return if local_server?

      flash[:alert] = t("tournaments.game_results.flash.local_server_only")
      redirect_to tournaments_path
    end

    # CC-Turniere behalten ihren gewachsenen Weg (ClubCloud hält dort die Ergebnisse).
    def ensure_cc_less
      return if helpers.wizard_cc_less?(@tournament)

      redirect_to tournament_path(@tournament),
        alert: t("tournaments.game_results.flash.cc_tournament")
    end

    # Plan 32-07: dasselbe Schreib-Gate wie die übrigen Meldelisten-/Ergebnis-Aktionen.
    def authorize_manage_teilnehmerliste
      authorize @tournament, :manage_teilnehmerliste?
    rescue Pundit::NotAuthorizedError
      flash[:alert] = I18n.t("tournaments.errors.manage_teilnehmerliste_denied")
      redirect_to(@tournament)
    end
  end
end
