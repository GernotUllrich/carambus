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
  # Explizite ID >= MIN_ID: der Scope `Game.training` (game.rb:59) filtert auf
  # `id >= MIN_ID`, die Test-Sequenz vergibt aber vierstellige IDs. Ohne feste ID faellt
  # das Spiel aus dem Scope, `finalize_if_decided` liefert false und der Terminate-Pfad
  # landet im destroy-Zweig — der Keep-Test konnte so nie gruen werden.
  def build_app_game(external_id:, acknowledged: false)
    data = external_id.nil? ? {} : {"external_id" => external_id}
    @next_build_id = (@next_build_id || 63_000_000) + 1
    game = Game.create!(id: @next_build_id, tournament_id: nil, data: data, group_no: 1, seqno: 1, table_no: 1,
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

  # ⚠️ ERWARTUNG ABGELOEST durch Milestone v0.3 Plan 01-02 (2026-08-29).
  # Urspruenglich hiess dieser Test "terminate destroys non-external game" und war ein
  # Regressionsschutz fuer Phase 18: der App-Result-Hold sollte normale Spiele nicht
  # blockieren. Das Spiel hier ist lokal, ohne tournament_id, ohne external_id und steht
  # auf :final_match_score — nach neuer Regel ist das ein FERTIGES Trainingsspiel und
  # wird bewusst BEHALTEN statt geloescht (sonst ginge die erfasste Statistik verloren).
  # Der eigentliche Regressionsschutz bleibt erhalten: der Terminate-Pfad laeuft, der
  # Hold greift nicht, und der Tisch wird freigegeben.
  test "terminate keeps a finished non-external training game but frees the table" do
    game = build_app_game(external_id: nil)
    assert_not game.table_monitor&.external_result_pending?, "precondition: no external_id → not pending"
    tm_id = game.table_monitor.id

    terminate(game)

    assert Game.exists?(game.id), "finished training game must be kept (v0.3 Plan 01-02)"
    freed = TableMonitor.find(tm_id)
    assert_equal "ready", freed.state, "terminate must still free the table"
    assert_nil freed.game_id
  end
end
