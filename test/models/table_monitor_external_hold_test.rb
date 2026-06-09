# frozen_string_literal: true

require "test_helper"

# Phase 17 / 17-04 — App-driven Result-Hold guards on TableMonitor.
#
# Verifies:
#   - operator-release (:close_match / :start_rematch) is BLOCKED for an App-driven
#     game (game.data["external_id"] present) until result_acknowledged_at is set;
#   - normal games are unaffected (AC-4 regression);
#   - App/manual_assignment tournaments do NOT trigger the executor round-progression
#     cascade on close_match! (the acknowledge_result release must not crash/mis-advance).
#
# Pattern follows test/system/final_match_score_operator_gate_test.rb
# (ActiveSupport::TestCase; state coerced via update_columns + reload).
class TableMonitorExternalHoldTest < ActiveSupport::TestCase
  setup do
    @player_a = Player.create!(id: 50_100_301, firstname: "HoldA", lastname: "Test", dbu_nr: 41001, ba_id: 41001)
    @player_b = Player.create!(id: 50_100_302, firstname: "HoldB", lastname: "Test", dbu_nr: 41002, ba_id: 41002)
    @seqno = 0
  end

  teardown do
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
  end

  # Single-set TM coerced to :final_match_score with the given game data.
  def build_tm_at_final_match_score(game_data: {}, tournament_monitor: nil, tournament_id: nil)
    @seqno += 1
    game = Game.create!(tournament_id: tournament_id, data: game_data, group_no: 1, seqno: @seqno, table_no: 1)
    GameParticipation.create!(game: game, player: @player_a, role: "playera")
    GameParticipation.create!(game: game, player: @player_b, role: "playerb")
    tm = TableMonitor.create!(state: "playing", game: game, tournament_monitor: tournament_monitor,
      data: {"playera" => {"result" => 100}, "playerb" => {"result" => 60}})
    tm.update_columns(state: "final_match_score")
    tm.reload
    tm
  end

  test "external game without ack blocks operator release (close_match + start_rematch)" do
    tm = build_tm_at_final_match_score(game_data: {"external_id" => "g-hold-1"})
    assert tm.external_result_pending?, "precondition: external result pending"
    assert_not tm.may_close_match?, "close_match must be blocked for unacknowledged external game"
    assert_not tm.may_start_rematch?, "start_rematch must be blocked for unacknowledged external game"
  end

  test "setting result_acknowledged_at releases the guard" do
    tm = build_tm_at_final_match_score(game_data: {"external_id" => "g-hold-2"})
    assert_not tm.may_close_match?
    tm.game.update!(result_acknowledged_at: Time.current)
    tm.reload
    assert_not tm.external_result_pending?, "no longer pending after ack"
    assert tm.may_close_match?, "close_match allowed after ack"
    assert tm.may_start_rematch?, "start_rematch allowed after ack"
  end

  test "non-external game is unaffected (AC-4 regression)" do
    tm = build_tm_at_final_match_score(game_data: {})
    assert_not tm.external_result_pending?, "no external_id → not pending"
    assert tm.may_close_match?, "normal game close_match unaffected"
    assert tm.may_start_rematch?, "normal game start_rematch unaffected"
  end

  # Phase 18 / 18-03 — force_next_state (Scoreboard-Spielstand-Klickfläche) guard.
  # force_next_state ist die zweite Operator-Freigabe-/Weiterschalt-Fläche neben
  # close_match/start_rematch; für ein App-Spiel in :final_match_score läuft sie via
  # evaluate_result in den ResultRecorder (direkter state-Set) — muss bei pending
  # App-Result blockiert sein. evaluate_result wird gestubbt, um den Guard zu isolieren.
  test "force_next_state is blocked (no advance) for unacknowledged external game" do
    tm = build_tm_at_final_match_score(game_data: {"external_id" => "g-fns-1"})
    assert tm.external_result_pending?, "precondition: external result pending"

    called = false
    tm.stub(:evaluate_result, -> { called = true }) do
      tm.force_next_state
    end
    assert_not called, "evaluate_result must NOT run while external result is pending"
    tm.reload
    assert_equal "final_match_score", tm.state, "state must stay at the hold"
    assert tm.game_id.present?, "game must remain bound (no release)"
  end

  test "force_next_state proceeds after result_acknowledged_at is set" do
    tm = build_tm_at_final_match_score(game_data: {"external_id" => "g-fns-2"})
    tm.game.update!(result_acknowledged_at: Time.current)
    tm.reload
    assert_not tm.external_result_pending?, "no longer pending after ack"

    called = false
    tm.stub(:evaluate_result, -> { called = true }) do
      tm.force_next_state
    end
    assert called, "force_next_state must proceed (evaluate_result) once the app acknowledged"
  end

  test "force_next_state unaffected for non-external game (AC-4 regression)" do
    tm = build_tm_at_final_match_score(game_data: {})
    assert_not tm.external_result_pending?, "no external_id → not pending"

    called = false
    tm.stub(:evaluate_result, -> { called = true }) do
      tm.force_next_state
    end
    assert called, "normal game force_next_state proceeds as before"
  end

  test "manual_assignment tournament does NOT trigger round-progression cascade on close_match!" do
    nbv = regions(:nbv)
    location = locations(:one)
    tournament = ExternalTournament::LocalTournamentCreator.new(region: nbv, payload: {
      external_id: "app-hold-casc", title: "Hold Cascade Cup", location: {id: location.id}
    }).call.tournament
    assert tournament.manual_assignment?, "App tournament must be manual_assignment"
    owner = tournament.tournament_monitor
    assert owner.present?, "lean TournamentMonitor present"

    tm = build_tm_at_final_match_score(game_data: {"external_id" => "g-casc-1"},
      tournament_monitor: owner, tournament_id: tournament.id)
    # acknowledge so the release guard passes; we are isolating the cascade no-op.
    tm.game.update!(result_acknowledged_at: Time.current)
    tm.reload
    assert tm.may_close_match?, "release allowed after ack"

    cascade_called = false
    fail_if_instantiated = lambda do |_arg|
      cascade_called = true
      raise "cascade must not run for manual_assignment"
    end
    TournamentMonitor::ResultProcessor.stub(:new, fail_if_instantiated) do
      assert_nothing_raised { tm.close_match! }
    end
    tm.reload
    assert_equal "ready_for_new_match", tm.state, "close_match! still transitions"
    assert_not cascade_called, "executor round-progression cascade must be skipped for manual_assignment tournament"
  end
end
