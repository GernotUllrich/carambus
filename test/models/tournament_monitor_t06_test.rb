# frozen_string_literal: true

require "test_helper"

# Characterization tests for TournamentMonitor with T06 (with finals round "mit Finalrunde") plan.
#
# Covers:
# - AASM state transitions through group phase and finals phase (CHAR-01)
# - Game creation and sequencing in group and finals stages (CHAR-03)
# - Result pipeline: update_game_participations_for_game, write_game_result_data (CHAR-02)
# - accumulate_results behavior in test environment (CHAR-02)
# - group_phase_finished? detection (CHAR-03)
#
# Uses production-exported fixture plan (tournament_plans(:t06_6)) per D-03.
# T06 plan: 6 players, 2 groups of 3, with semifinals (hf1, hf2) and finals (fin, p<3-4>, p<5-6>).
#
# NOTE on test environment limitation (same as T04):
# In the test DB, auto-generated game IDs are low integers (< MIN_ID = 50_000_000).
# do_reset_tournament_monitor destroys only games with id >= MIN_ID and then checks the
# count of id >= MIN_ID games — so it always reports "0 games created" in tests and
# returns an ERROR hash instead of transitioning to playing_groups.
# This is pinned behavior. Tests that need playing_groups state call start_playing_groups!
# directly after initialization.
#
# NOTE on use_transactional_tests:
# use_transactional_tests = true means after_commit callbacks (broadcast_status_update)
# will NOT fire during test transactions — this is intentional for characterization tests.
class TournamentMonitorT06Test < ActiveSupport::TestCase
  include T06TournamentTestHelper

  self.use_transactional_tests = true

  setup do
    @test_data = create_t06_tournament_with_seedings(balls_goal: 30, innings_goal: 25)
    @tournament = @test_data[:tournament]
    @players    = @test_data[:players]
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
  end

  teardown do
    # CRITICAL: Reset cattr_accessor class-level state to prevent test pollution (T-11-04)
    TournamentMonitor.current_admin       = nil
    TournamentMonitor.allow_change_tables = nil
    cleanup_t06_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # AASM Full Lifecycle — T06 States (CHAR-01)
  # ============================================================================

  test "T06 tournament monitor is created in new_tournament_monitor or playing_groups state" do
    # After initialize_tournament_monitor, the TM is created. In test env,
    # do_reset_tournament_monitor cannot complete (MIN_ID game count check fails),
    # so state remains new_tournament_monitor. This pins the actual test env behavior.
    assert_includes %w[new_tournament_monitor playing_groups], @tm.state
  end

  test "T06 can transition to playing_groups via start_playing_groups!" do
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state
  end

  test "T06 can transition from playing_groups to playing_finals" do
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state

    assert @tm.may_start_playing_finals?,
      "Should be able to call start_playing_finals! from playing_groups"

    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state
  end

  test "T06 transitions through full AASM lifecycle" do
    # playing_groups -> playing_finals -> closed
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state

    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state

    @tm.end_of_tournament!
    assert_equal "closed", @tm.state
  end

  test "T06 end_of_tournament transitions to closed from any state" do
    # end_of_tournament has no from: guard — transitions to closed from any state
    @tm.start_playing_groups!
    assert @tm.may_end_of_tournament?

    @tm.end_of_tournament!
    assert_equal "closed", @tm.state
  end

  test "T06 start_playing_finals is reachable from new_tournament_monitor" do
    # start_playing_finals transitions from: [:new_tournament_monitor, :playing_groups, :playing_finals]
    assert @tm.may_start_playing_finals?,
      "Should be able to start finals from new_tournament_monitor"

    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state
  end

  # ============================================================================
  # Game Creation for T06 (CHAR-03)
  # ============================================================================

  test "T06 creates 6 group games for 2 groups of 3 players" do
    # T06: 2 groups of 3 => 3 games each (3C2 = 3) => 6 group games total.
    # Games are created even though do_reset returns an error hash (due to MIN_ID check).
    # Use plain tournament.games.count (not the MIN_ID-filtered version).
    game_count = @tournament.games.count
    assert_equal 6, game_count,
      "T06 with 6 players in 2 groups of 3 should create 6 round-robin group games"
  end

  test "T06 group game names follow group<N>:pair format" do
    game_names = @tournament.games.pluck(:gname)
    assert game_names.any?, "Should have games after initialization"

    game_names.each do |gname|
      assert_match(/\Agroup\d+:\d+-\d+\z/, gname,
        "T06 game name '#{gname}' should match pattern group<N>:<a>-<b>")
    end
  end

  test "T06 creates correct group1 game names" do
    game_names = @tournament.games.pluck(:gname)
    assert_includes game_names, "group1:1-2"
    assert_includes game_names, "group1:1-3"
    assert_includes game_names, "group1:2-3"
  end

  test "T06 creates correct group2 game names" do
    game_names = @tournament.games.pluck(:gname)
    assert_includes game_names, "group2:1-2"
    assert_includes game_names, "group2:1-3"
    assert_includes game_names, "group2:2-3"
  end

  test "T06 each group game has exactly 2 player participations" do
    games = @tournament.games
    assert games.any?, "Should have games after initialization"

    games.each do |game|
      gp_count = game.game_participations.count
      assert_equal 2, gp_count,
        "Game #{game.gname} should have 2 game_participations, got #{gp_count}"
    end
  end

  test "T06 game participations have player_ids from the seedings" do
    seeded_player_ids = @players.map(&:id).sort
    games = @tournament.games

    assert games.any?, "Should have games to check"

    games.each do |game|
      game.game_participations.each do |gp|
        assert_includes seeded_player_ids, gp.player_id,
          "GameParticipation player_id #{gp.player_id} should be in seeded players"
      end
    end
  end

  test "T06 tournament monitor data contains groups key after initialization" do
    assert @tm.data.is_a?(Hash), "TournamentMonitor data should be a Hash"
    assert @tm.data.key?("groups"),
      "TournamentMonitor data should contain 'groups' key after do_reset"
    assert @tm.data["groups"].key?("group1"),
      "groups should contain 'group1'"
    assert @tm.data["groups"].key?("group2"),
      "groups should contain 'group2' for T06 two-group plan"
  end

  test "T06 group1 and group2 each contain exactly 3 player_ids" do
    group1 = @tm.data["groups"]["group1"]
    group2 = @tm.data["groups"]["group2"]
    assert_equal 3, group1.count,
      "T06 group1 should contain 3 players"
    assert_equal 3, group2.count,
      "T06 group2 should contain 3 players"
  end

  test "T06 all 6 players are distributed across both groups" do
    group1 = @tm.data["groups"]["group1"]
    group2 = @tm.data["groups"]["group2"]
    all_distributed = (group1 + group2).sort
    all_player_ids = @players.map(&:id).sort
    assert_equal all_player_ids, all_distributed,
      "All 6 players should be distributed across group1 and group2 with no overlap"
  end

  # ============================================================================
  # Result Pipeline — update_game_participations_for_game (CHAR-02)
  # ============================================================================

  test "update_game_participations_for_game writes correct results to participations" do
    # Find a real group game with 2 participants
    game = @tournament.games.first
    assert game.present?, "Should have at least one game"
    assert_equal 2, game.game_participations.count

    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")
    assert gp_a.present?, "Should have playera participation"
    assert gp_b.present?, "Should have playerb participation"

    # Prepare table_monitor_data matching the single-set path in update_game_participations_for_game
    # (sets_to_play defaults to 1 for TournamentMonitor)
    table_monitor_data = {
      "playera" => {
        "result"     => 30,
        "innings"    => 15,
        "hs"         => 7,
        "balls_goal" => 30
      },
      "playerb" => {
        "result"     => 20,
        "innings"    => 15,
        "hs"         => 4,
        "balls_goal" => 30
      }
    }

    # Initialize game.data so deep_merge_data! works
    game.update!(data: {})

    @tm.update_game_participations_for_game(game, table_monitor_data)

    gp_a.reload
    gp_b.reload

    # playera has higher result (30 > 20), gets 2 points; playerb gets 0
    assert_equal 30, gp_a.result, "playera result should be 30"
    assert_equal 15, gp_a.innings, "playera innings should be 15"
    assert_equal 7,  gp_a.hs, "playera hs should be 7"
    assert_equal 2,  gp_a.points, "playera (winner) should get 2 points"

    assert_equal 20, gp_b.result, "playerb result should be 20"
    assert_equal 15, gp_b.innings, "playerb innings should be 15"
    assert_equal 4,  gp_b.hs, "playerb hs should be 4"
    assert_equal 0,  gp_b.points, "playerb (loser) should get 0 points"
  end

  test "update_game_participations_for_game assigns 1 point each for tied results" do
    game = @tournament.games.first
    gp_a = game.game_participations.find_by(role: "playera")
    gp_b = game.game_participations.find_by(role: "playerb")

    # Tied: same result relative to balls_goal (100% each)
    table_monitor_data = {
      "playera" => {
        "result"     => 30,
        "innings"    => 20,
        "hs"         => 5,
        "balls_goal" => 30
      },
      "playerb" => {
        "result"     => 30,
        "innings"    => 20,
        "hs"         => 5,
        "balls_goal" => 30
      }
    }

    game.update!(data: {})
    @tm.update_game_participations_for_game(game, table_monitor_data)

    gp_a.reload
    gp_b.reload

    assert_equal 1, gp_a.points, "Tied game: playera should get 1 point"
    assert_equal 1, gp_b.points, "Tied game: playerb should get 1 point"
  end

  # ============================================================================
  # Result Pipeline — write_game_result_data (CHAR-02)
  # ============================================================================

  test "write_game_result_data writes table_monitor data to game" do
    # write_game_result_data has guard clauses:
    # 1. table_monitor.data must have ba_results
    # 2. table_monitor.state must be in final_match_score or final_set_score
    # We set up a TableMonitor satisfying these guards.

    game = @tournament.games.first
    game.update!(data: {})

    # Create a local TableMonitor (id >= MIN_ID to pass ApiProtector in test env)
    tm_id = TEST_ID_BASE + 30_900 + @tournament.id

    table_monitor = TableMonitor.new(
      id: tm_id,
      state: "final_match_score",
      data: {
        "ba_results" => {
          "Ergebnis1" => 30,
          "Aufnahmen1" => 15,
          "Höchstserie1" => 7,
          "Ergebnis2" => 20,
          "Aufnahmen2" => 15,
          "Höchstserie2" => 4,
          "Sets1" => 1,
          "Sets2" => 0
        }
      }
    )
    # Associate with game (set via direct attribute to bypass AASM new state after_enter)
    table_monitor.game = game
    table_monitor.save(validate: false)

    @tm.write_game_result_data(table_monitor)

    game.reload
    assert game.data.key?("ba_results"),
      "game.data should contain ba_results after write_game_result_data"
    assert game.data.key?("finalized_at"),
      "game.data should contain finalized_at timestamp after write_game_result_data"
    assert_equal 30, game.data["ba_results"]["Ergebnis1"],
      "ba_results should contain the data written from table_monitor"
  ensure
    TableMonitor.find_by(id: tm_id)&.destroy
  end

  test "write_game_result_data is skipped when table_monitor has no ba_results" do
    game = @tournament.games.first
    game.update!(data: {})

    tm_id = TEST_ID_BASE + 30_901 + @tournament.id
    table_monitor = TableMonitor.new(
      id: tm_id,
      state: "final_match_score",
      data: {} # no ba_results
    )
    table_monitor.game = game
    table_monitor.save(validate: false)

    @tm.write_game_result_data(table_monitor)

    game.reload
    # Should NOT write finalized_at because ba_results is blank
    assert_not game.data.key?("finalized_at"),
      "write_game_result_data should skip when ba_results is absent"
  ensure
    TableMonitor.find_by(id: tm_id)&.destroy
  end

  # ============================================================================
  # Group Phase Detection (CHAR-03)
  # ============================================================================

  test "group_phase_finished? returns true in test env due to MIN_ID game filtering" do
    # group_phase_finished? counts games.id >= MIN_ID where gname ilike 'group%'
    # In test env, auto-assigned game IDs are < MIN_ID, so 0 == 0 => returns true.
    # This is pinned behavior — documents the MIN_ID filtering limitation in tests.
    assert @tm.group_phase_finished?,
      "group_phase_finished? returns true in test env (0 MIN_ID group games == 0 done)"
  end

  test "group_phase_finished? returns false when high-ID group games exist without ended_at" do
    # To exercise the false branch, we create a game with id >= MIN_ID and no ended_at
    high_id_game = @tournament.games.create!(
      id: TEST_ID_BASE + 30_800 + @tournament.id,
      gname: "group1:high-test",
      group_no: 1
    )

    assert_not @tm.group_phase_finished?,
      "group_phase_finished? should return false when high-ID group game has no ended_at"
  ensure
    Game.find_by(id: TEST_ID_BASE + 30_800 + @tournament.id)&.destroy
  end

  test "group_phase_finished? returns true when all high-ID group games have ended_at" do
    high_id = TEST_ID_BASE + 30_801 + @tournament.id
    high_id_game = @tournament.games.create!(
      id: high_id,
      gname: "group1:high-test2",
      group_no: 1,
      ended_at: Time.current
    )

    assert @tm.group_phase_finished?,
      "group_phase_finished? should return true when all high-ID group games are done"
  ensure
    Game.find_by(id: high_id)&.destroy
  end

  # ============================================================================
  # accumulate_results behavior (CHAR-02)
  # ============================================================================

  test "accumulate_results builds rankings hash in data" do
    # accumulate_results filters GameParticipation by games.id >= MIN_ID AND tournament_id.
    # In test env, game IDs are auto-assigned low integers, so no GPs are found.
    # The result is an empty rankings structure — documenting this pinned behavior.
    @tm.accumulate_results

    @tm.reload
    assert @tm.data.key?("rankings"),
      "data should contain rankings key after accumulate_results"

    rankings = @tm.data["rankings"]
    assert rankings.key?("total"), "rankings should have 'total' key"
    assert rankings.key?("groups"), "rankings should have 'groups' key"
    assert rankings.key?("endgames"), "rankings should have 'endgames' key"
  end

  test "accumulate_results with high-ID game includes results in rankings" do
    # To exercise the result accumulation path, we create a game with id >= MIN_ID
    # and properly set up game_participations with result data.
    high_game_id = TEST_ID_BASE + 30_802 + @tournament.id
    player_a = @players[0]
    player_b = @players[1]

    high_game = @tournament.games.create!(
      id: high_game_id,
      gname: "group1:1-2",
      group_no: 1
    )

    gp_a = high_game.game_participations.create!(
      player: player_a,
      role: "playera",
      points: 2,
      result: 30,
      innings: 15,
      gd: 2.0,
      hs: 7,
      data: { "results" => { "Gr." => "group1:1-2", "Ergebnis" => 30, "Aufnahme" => 15, "GD" => 2.0, "HS" => 7 } }
    )

    gp_b = high_game.game_participations.create!(
      player: player_b,
      role: "playerb",
      points: 0,
      result: 20,
      innings: 15,
      gd: 1.33,
      hs: 4,
      data: { "results" => { "Gr." => "group1:1-2", "Ergebnis" => 20, "Aufnahme" => 15, "GD" => 1.33, "HS" => 4 } }
    )

    @tm.accumulate_results
    @tm.reload

    rankings = @tm.data["rankings"]
    assert rankings["groups"].key?("group1"),
      "rankings should contain group1 when high-ID group1 game results are present"
    # JSON round-trip converts integer player_id keys to strings
    player_a_key = player_a.id.to_s
    assert rankings["groups"]["group1"].key?(player_a_key),
      "group1 rankings should contain player_a (key=#{player_a_key})"
    assert_equal 2, rankings["groups"]["group1"][player_a_key]["points"],
      "player_a should have 2 points in group1 rankings"
  ensure
    GameParticipation.where(game_id: high_game_id).destroy_all
    Game.find_by(id: high_game_id)&.destroy
  end
end
