# frozen_string_literal: true

require "test_helper"

# Phase 18 / Hold-Guard-Followup zu 18-03: GamesController#destroy darf ein App-Spiel mit
# unbestätigtem Ergebnis (TableMonitor#external_result_pending?) NICHT löschen — auch nicht
# durch Admins — solange die App es nicht via acknowledge_result abgeholt hat. Override via
# ?force=1. (DELETE /games/:id ist der admin-zugängliche Direkt-Lösch-Pfad, den 18-03 nicht
# abdeckte: force_next_state + locations-Terminate.)
#
# Test-Note: der tatsächliche destroy löst über has_one :table_monitor, dependent: :nullify
# ein TM-Update → after_update_commit → TableMonitorJob (volles Scoreboard-Render) aus, das bei
# synthetischer TM (ohne Table) NPEt — daher TableMonitorJob.perform_later gestubbt (wie 18-03).
class GamesControllerHoldGuardTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:admin) # admin_only_check verlangt current_user.admin?
    @player_a = Player.create!(id: 50_100_411, firstname: "DelA", lastname: "Test", dbu_nr: 44_011, ba_id: 44_011)
    @player_b = Player.create!(id: 50_100_412, firstname: "DelB", lastname: "Test", dbu_nr: 44_012, ba_id: 44_012)
  end

  teardown do
    GameParticipation.where(player: [@player_a, @player_b].compact).destroy_all
    TableMonitor.where("created_at > ?", 1.minute.ago).destroy_all
    Game.where("created_at > ?", 1.minute.ago).destroy_all
    Player.where(id: [@player_a&.id, @player_b&.id].compact).destroy_all
  end

  # App-Game (kein tournament_id) auf :final_match_score, optional bereits acknowledged.
  # external_id: nil → Nicht-App-Game (Regressionsarm).
  def build_app_game(external_id:, acknowledged: false)
    data = external_id.nil? ? {} : {"external_id" => external_id}
    game = Game.create!(tournament_id: nil, data: data, group_no: 1, seqno: 1, table_no: 1,
      result_acknowledged_at: acknowledged ? Time.current : nil)
    GameParticipation.create!(game: game, player: @player_a, role: "playera")
    GameParticipation.create!(game: game, player: @player_b, role: "playerb")
    TableMonitor.create!(state: "final_match_score", game: game,
      data: {"playera" => {"result" => 100}, "playerb" => {"result" => 60}})
    game.reload
  end

  def delete_game(game, params = {})
    TableMonitorJob.stub(:perform_later, nil) do
      delete game_path(game), params: params
    end
  end

  test "destroy is blocked for App-game with pending result (even as admin)" do
    game = build_app_game(external_id: "g-del-1")
    assert game.table_monitor&.external_result_pending?, "precondition: external result pending"

    delete_game(game)

    assert Game.exists?(game.id), "held App-game must NOT be destroyed without force"
  end

  test "destroy proceeds with ?force=1 override" do
    game = build_app_game(external_id: "g-del-2")
    assert game.table_monitor&.external_result_pending?

    delete_game(game, {force: "1"})

    assert_not Game.exists?(game.id), "force=1 overrides the hold (admin escape hatch)"
  end

  test "destroy proceeds once result acknowledged" do
    game = build_app_game(external_id: "g-del-3", acknowledged: true)
    assert_not game.table_monitor&.external_result_pending?

    delete_game(game)

    assert_not Game.exists?(game.id), "acknowledged App-game deletes normally"
  end

  test "destroy of a non-external game is unaffected (regression)" do
    game = build_app_game(external_id: nil)
    assert_not game.table_monitor&.external_result_pending?

    delete_game(game)

    assert_not Game.exists?(game.id), "normal game deletes as before"
  end
end
