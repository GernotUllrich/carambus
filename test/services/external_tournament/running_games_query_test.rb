# frozen_string_literal: true

require "test_helper"

# Phase 30-01: RunningGamesQuery — aktuelle Seitenbelegung laufender App-Spiele (nach dem Ausstossen).
module ExternalTournament
  class RunningGamesQueryTest < ActiveSupport::TestCase
    setup do
      @nbv = regions(:nbv)
      @location = locations(:one)
      @tournament = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-run-1", title: "Run Cup", location: {id: @location.id}
      }).call.tournament
      @owner = @tournament.tournament_monitor
      @player_a = Player.create!(id: 50_100_601, firstname: "RunA", lastname: "Test", dbu_nr: 44001, ba_id: 44001)
      @player_b = Player.create!(id: 50_100_602, firstname: "RunB", lastname: "Test", dbu_nr: 44002, ba_id: 44002)
      @seqno = 0
    end

    teardown do
      GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
      TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
      Game.where("created_at > ?", 1.minute.ago).destroy_all
      Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
    end

    # Laufendes App-Spiel auf einem an das Turnier gebundenen Tisch, so wie start_game es anlegt:
    # Plan-Seite A als playera.
    def build_running_game(external_id:, owner: @owner, state: "playing")
      @seqno += 1
      game = Game.create!(group_no: 1, seqno: @seqno, table_no: 1, data: {"external_id" => external_id})
      GameParticipation.create!(game: game, player: @player_a, role: "playera")
      GameParticipation.create!(game: game, player: @player_b, role: "playerb")
      tm = TableMonitor.create!(state: state, game: game, tournament_monitor: owner,
        data: {"playera" => {"balls_goal" => 120}, "playerb" => {"balls_goal" => 100}})
      [game, tm]
    end

    def query(**kw)
      RunningGamesQuery.new(region: @nbv, tournament_id: @tournament.id, **kw).call
    end

    def playera_name(entry)
      entry.participations.find { |p| p.role == "playera" }.player.firstname
    end

    test "liefert das laufende Spiel mit Plan-Seite A als playera" do
      game, tm = build_running_game(external_id: "run-g1")
      entries = query

      assert_equal [game.id], entries.map { |e| e.game.id }
      assert_equal tm.id, entries.first.table_monitor.id
      assert_equal "RunA", playera_name(entries.first)
    end

    test "nach dem Ausstossen (switch_players) steht Spieler B auf playera" do
      _game, tm = build_running_game(external_id: "run-g2")
      tm.switch_players

      assert_equal "RunB", playera_name(query.first), "Rollen folgen dem Tausch am Tisch"
    end

    test "findet das Turnier auch ueber die external_id" do
      build_running_game(external_id: "run-g3")
      entries = RunningGamesQuery.new(region: @nbv, tournament_external_id: "app-run-1").call
      assert_equal 1, entries.size
    end

    test "abgeholte Ergebnisse, Spiele ohne external_id und fremde Tische fehlen" do
      acked, = build_running_game(external_id: "run-acked")
      acked.update_columns(result_acknowledged_at: Time.current)
      build_running_game(external_id: "")
      other = LocalTournamentCreator.new(region: @nbv, payload: {
        external_id: "app-run-2", title: "Anderes", location: {id: @location.id}
      }).call.tournament
      build_running_game(external_id: "run-fremd", owner: other.tournament_monitor)

      assert_empty query
    end

    test "ist rein lesend: keine Quittung, kein Zustandswechsel" do
      game, tm = build_running_game(external_id: "run-g4", state: "final_match_score")
      query

      assert_nil game.reload.result_acknowledged_at
      assert_equal "final_match_score", tm.reload.state
    end

    test "unbekanntes Turnier" do
      assert_raises(RunningGamesQuery::TournamentNotFoundError) do
        RunningGamesQuery.new(region: @nbv, tournament_id: 0).call
      end
    end
  end
end
