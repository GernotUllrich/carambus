# frozen_string_literal: true

require "test_helper"
require_relative "../../support/party_monitor_test_helper"

class PartyMonitor::ResultProcessorTest < ActiveSupport::TestCase
  include PartyMonitorTestHelper

  self.use_transactional_tests = true

  setup do
    result = create_party_monitor_with_party
    @pm = result[:party_monitor]
    @party = result[:party]
  end

  teardown do
    PartyMonitor.allow_change_tables = nil
  end

  test "initializes with party_monitor reference" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert_instance_of PartyMonitor::ResultProcessor, rp
  end

  test "write_game_result_data is private on ResultProcessor" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert rp.respond_to?(:write_game_result_data, true), "write_game_result_data should be private on ResultProcessor"
    refute rp.respond_to?(:write_game_result_data), "write_game_result_data should not be public"
  end

  test "add_result_to is private on ResultProcessor" do
    rp = PartyMonitor::ResultProcessor.new(@pm)
    assert rp.respond_to?(:add_result_to, true), "add_result_to should be private on ResultProcessor"
    refute rp.respond_to?(:add_result_to), "add_result_to should not be public"
  end

  test "accumulate_results delegates to service and runs without error" do
    assert_nothing_raised { @pm.accumulate_results }
  end

  test "report_result preserves TournamentMonitor.transaction scope" do
    source = File.read(Rails.root.join("app/services/party_monitor/result_processor.rb"))
    assert_match(/TournamentMonitor\.transaction/, source,
      "report_result must use TournamentMonitor.transaction (not PartyMonitor.transaction)")
  end

  test "write_game_result_data is NOT defined on PartyMonitor model" do
    refute @pm.respond_to?(:write_game_result_data, true),
      "write_game_result_data must NOT be on PartyMonitor model"
  end

  test "add_result_to is NOT defined on PartyMonitor model" do
    refute @pm.respond_to?(:add_result_to, true),
      "add_result_to must NOT be on PartyMonitor model"
  end

  # ============================================================================
  # Phase 38.7 Plan 03 — D-10 Tiebreak-Vorrang-Branch tests.
  # ============================================================================
  #
  # The new branch in update_game_participations honours
  # game.data['tiebreak_winner'] when the rank-comparison would have produced
  # a draw. Defensive against forged values: only the literal strings
  # 'playera' / 'playerb' override the legacy logic; everything else
  # (nil, '', 'playerc', 42, Hash) falls through to the legacy rank branch.
  #
  # Tests stub get_attribute_by_gname (sets-to-play) and
  # get_game_plan_attribute_by_gname (game_points hash) so they don't depend
  # on a fully-populated league.game_plan fixture chain.

  # Phase 38.7 Plan 03 helper: prime a Game + GameParticipation pair for
  # tiebreak-branch testing. Returns [table_monitor, game].
  def prime_tiebreak_game(rank_a:, rank_b:, tiebreak_winner: nil, balls_goal: 100)
    base_id = @pm.id + 700
    game = Game.create!(
      id: base_id,
      gname: "1-tiebreak",
      tournament: nil,
      data: {}
    )
    GameParticipation.create!(id: base_id + 1, game: game, role: "playera")
    GameParticipation.create!(id: base_id + 2, game: game, role: "playerb")

    tm = TableMonitor.create!(
      id: base_id + 3,
      state: "playing",
      data: {
        "ba_results" => {"Sets1" => 0, "Sets2" => 0, "Ergebnis1" => rank_a.to_i, "Ergebnis2" => rank_b.to_i, "Aufnahmen1" => 1, "Aufnahmen2" => 1, "Höchstserie1" => 0, "Höchstserie2" => 0},
        "playera" => {"result" => rank_a, "balls_goal" => balls_goal, "innings" => 1, "hs" => 0},
        "playerb" => {"result" => rank_b, "balls_goal" => balls_goal, "innings" => 1, "hs" => 0}
      }
    )
    tm.update_columns(game_id: game.id)
    tm.reload

    if tiebreak_winner
      game.update!(data: {"tiebreak_winner" => tiebreak_winner})
    end

    [tm, game]
  end

  # Stub-based dispatch helper: runs update_game_participations with stubbed
  # PartyMonitor query methods so we don't need a populated game_plan fixture.
  def run_update_game_participations(tm, sets_to_play: 1, game_points: {"win" => 2, "lost" => 0, "draw" => 1})
    stub_game_points = HashWithIndifferentAccess.new(game_points)
    @pm.stub(:get_attribute_by_gname, sets_to_play) do
      @pm.stub(:get_game_plan_attribute_by_gname, stub_game_points) do
        PartyMonitor::ResultProcessor.new(@pm).update_game_participations(tm)
      end
    end
  end

  test "update_game_participations awards win to playera when tiebreak_winner=playera and rank tied" do
    tm, game = prime_tiebreak_game(rank_a: 50.0, rank_b: 50.0, tiebreak_winner: "playera")
    run_update_game_participations(tm)
    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")
    assert_equal 2, gp_a.points, "playera must receive game_points['win'] after tiebreak override"
    assert_equal 0, gp_b.points, "playerb must receive game_points['lost'] after tiebreak override"
  end

  test "update_game_participations awards win to playerb when tiebreak_winner=playerb and rank tied" do
    tm, game = prime_tiebreak_game(rank_a: 50.0, rank_b: 50.0, tiebreak_winner: "playerb")
    run_update_game_participations(tm)
    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")
    assert_equal 0, gp_a.points, "playera must receive game_points['lost'] after tiebreak override"
    assert_equal 2, gp_b.points, "playerb must receive game_points['win'] after tiebreak override"
  end

  test "update_game_participations falls through to legacy logic when tiebreak_winner=playera but rank NOT tied" do
    # playera already legitimately outranks playerb (60 > 50). Tiebreak key irrelevant — legacy wins.
    tm, game = prime_tiebreak_game(rank_a: 60.0, rank_b: 50.0, tiebreak_winner: "playera")
    run_update_game_participations(tm)
    gp_a = game.game_participations.find_by(role: "playera")
    assert_equal 2, gp_a.points, "Legacy logic must still fire — tiebreak only applies on tie"
  end

  test "update_game_participations awards draw via legacy logic when tiebreak_winner missing and rank tied (regression)" do
    tm, game = prime_tiebreak_game(rank_a: 50.0, rank_b: 50.0, tiebreak_winner: nil)
    run_update_game_participations(tm)
    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")
    assert_equal 1, gp_a.points, "Legacy regression: tied rank with no tiebreak_winner key must produce draw"
    assert_equal 1, gp_b.points
  end

  test "update_game_participations falls through to legacy logic when tiebreak_winner is invalid (defense-in-depth)" do
    tm, game = prime_tiebreak_game(rank_a: 50.0, rank_b: 50.0, tiebreak_winner: "playerc")
    run_update_game_participations(tm)
    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")
    assert_equal 1, gp_a.points, "Invalid tiebreak_winner='playerc' must fall through to legacy draw"
    assert_equal 1, gp_b.points
  end
end
