# frozen_string_literal: true

module ExternalTournament
  # Phase 30-01: Welche App-Spiele laufen gerade, und wer steht dort auf welcher Seite?
  #
  # Beim Ausstossen ("Spieler wechseln und starten", TableMonitorReflex#switch_players_and_start_game)
  # tauscht TableMonitor#switch_players die game_participation.role persistent — der Anstoss-Spieler
  # steht danach als playera links. Die App erfuhr davon bis zum Ergebnis nichts und zeigte die Partie
  # weiter in Plan-Reihenfolge; beim GP 17./18.10. musste der Turnierleiter deshalb bei mindestens 14
  # von 43 Partien von Hand tauschen (Befund 30-01, bc-wedel-Logs). Diese Abfrage liefert die aktuelle
  # Rollenbelegung, damit die App ihre Anzeige selbst nachziehen kann.
  #
  # Rein lesend: kein Release, keine Quittung. Geliefert wird nur das aktuelle Spiel eines gebundenen
  # Tisches (tm.game), nicht prev_game_id — und nur, solange das Ergebnis nicht abgeholt ist.
  class RunningGamesQuery
    # Die Zuordnung App-Spiel ↔ Turnier haengt allein an den gebundenen TableMonitors und der
    # external_id — dieselbe Invariante wie bei acknowledge_result/cancel_game.
    include AppGameLookup

    Entry = Struct.new(:game, :table_monitor, :table, :participations, keyword_init: true)

    class TournamentNotFoundError < StandardError; end

    def initialize(region:, tournament_id: nil, tournament_external_id: nil)
      @region = region
      @tournament_id = tournament_id
      @tournament_external_id = tournament_external_id
    end

    def call
      tournament = resolve_tournament
      owner = tournament.tournament_monitor
      return [] if owner.blank?

      TableMonitor.where(tournament_monitor_id: owner.id, tournament_monitor_type: "TournamentMonitor")
        .includes(:table, game: {game_participations: :player}).order(:id).filter_map do |tm|
        g = tm.game
        next if g.blank? || g.result_acknowledged_at.present?
        next if lookup_safe_data(g)["external_id"].to_s.blank?

        Entry.new(game: g, table_monitor: tm, table: tm.table, participations: g.game_participations.to_a)
      end
    end

    private

    def resolve_tournament
      tournament =
        if @tournament_id.present?
          Tournament.find_by(id: @tournament_id, region_id: @region.id)
        elsif @tournament_external_id.present?
          Tournament.where(region_id: @region.id, external_id: @tournament_external_id).first
        end
      raise TournamentNotFoundError, "tournament not found" if tournament.blank?
      tournament
    end
  end
end
