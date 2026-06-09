# frozen_string_literal: true

require "test_helper"

# Phase 18 / 18-03 — App-driven result-hold guard on the Scoreboard "tables"
# terminate path (LocationsController#show, params[:terminate_game_id]).
#
# App-games have no tournament_id (game.tournament.blank?) and would otherwise hit
# the destroy branch. While the app has not pulled the result (result_acknowledged_at
# nil) the game must NOT be destroyed/reset — the operator must wait for
# POST acknowledge_result. Once acknowledged (or for non-external games) the
# terminate path behaves exactly as before.
#
# Test notes:
#   - A user is signed in so set_location skips the no-current_user scoreboard
#     bypass branch (which NPEs in test when User.scoreboard is absent).
#   - The non-pending terminate path calls reset_table_monitor, whose after_update_commit
#     enqueues TableMonitorJob to render the FULL scoreboard partial; that partial needs a
#     fully-formed Table/Game (table_monitor.table.location) which our synthetic TM lacks.
#     We stub TableMonitorJob.perform_later to isolate the controller's terminate decision
#     (the broadcast itself is end-to-end-verified live, not here). The pending arm never
#     resets/destroys, so it triggers no broadcast.
class LocationsTerminateExternalHoldTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin)
    @location = locations(:one)
    @player_a = Player.create!(id: 50_100_311, firstname: "TermA", lastname: "Test", dbu_nr: 41_011, ba_id: 41_011)
    @player_b = Player.create!(id: 50_100_312, firstname: "TermB", lastname: "Test", dbu_nr: 41_012, ba_id: 41_012)
  end

  teardown do
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
  end

  # App-game (no tournament_id) at :final_match_score, optionally already acknowledged.
  # external_id: nil → non-external game (regression arm).
  def build_app_game(external_id:, acknowledged: false)
    data = external_id.nil? ? {} : {"external_id" => external_id}
    game = Game.create!(tournament_id: nil, data: data, group_no: 1, seqno: 1, table_no: 1,
      result_acknowledged_at: acknowledged ? Time.current : nil)
    GameParticipation.create!(game: game, player: @player_a, role: "playera")
    GameParticipation.create!(game: game, player: @player_b, role: "playerb")
    TableMonitor.create!(state: "final_match_score", game: game,
      data: {"playera" => {"result" => 100}, "playerb" => {"result" => 60}})
    game.reload
    game
  end

  # Drive the terminate path with the scoreboard broadcast stubbed out (see class note).
  def terminate(game)
    TableMonitorJob.stub(:perform_later, nil) do
      get location_path(@location, sb_state: "tables", terminate_game_id: game.id)
    end
  end

  test "terminate is blocked for App-game with pending result (game not destroyed)" do
    game = build_app_game(external_id: "g-term-1")
    assert game.table_monitor&.external_result_pending?, "precondition: external result pending"

    terminate(game)

    assert Game.exists?(game.id), "App-game with pending result must NOT be destroyed"
  end

  test "terminate destroys App-game once result acknowledged" do
    game = build_app_game(external_id: "g-term-2", acknowledged: true)
    assert_not game.table_monitor&.external_result_pending?, "precondition: acknowledged → not pending"

    terminate(game)

    assert_not Game.exists?(game.id), "acknowledged App-game terminates as before"
  end

  test "terminate destroys non-external game (AC-4 regression)" do
    game = build_app_game(external_id: nil)
    assert_not game.table_monitor&.external_result_pending?, "precondition: no external_id → not pending"

    terminate(game)

    assert_not Game.exists?(game.id), "non-external game terminates as before"
  end
end
