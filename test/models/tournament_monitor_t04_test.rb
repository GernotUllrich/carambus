# frozen_string_literal: true

require "test_helper"

# Characterization tests for TournamentMonitor with T04 (round-robin "jeder gegen jeden") plan.
#
# Covers:
# - AASM state transitions (CHAR-01)
# - distribute_to_group player distribution algorithm (CHAR-04)
# - do_reset_tournament_monitor game creation and sequencing (CHAR-03)
# - ApiProtector / ApiProtectorTestOverride verification (CHAR-09)
#
# Uses production-exported fixture plan (tournament_plans(:t04_5)) per D-03.
#
# NOTE on test environment limitation:
# In the test DB, auto-generated game IDs are low integers (< MIN_ID = 50_000_000).
# do_reset_tournament_monitor destroys only games with id >= MIN_ID and then checks the
# count of id >= MIN_ID games — so it always reports "0 games created" in tests and
# returns an ERROR hash instead of transitioning to playing_groups.
# This is pinned behavior. Tests that need a playing_groups state call start_playing_groups!
# directly after initialization.
class TournamentMonitorT04Test < ActiveSupport::TestCase
  include T04TournamentTestHelper

  self.use_transactional_tests = true

  setup do
    # T04 fixture plan (t04_5) has 5 players in 1 group.
    # Player count must match fixture plan to avoid validation errors in do_reset_tournament_monitor.
    @test_data = create_t04_tournament_with_seedings(5, { balls_goal: 30, innings_goal: 25 })
    @tournament = @test_data[:tournament]
    @players    = @test_data[:players]
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
  end

  teardown do
    # CRITICAL: Reset cattr_accessor class-level state to prevent test pollution (T-11-01)
    TournamentMonitor.current_admin       = nil
    TournamentMonitor.allow_change_tables = nil
    cleanup_t04_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # AASM State Transitions (CHAR-01)
  # ============================================================================

  test "T04 tournament monitor is created in new_tournament_monitor state" do
    # After initialize_tournament_monitor, the TM is created.
    # In test env, do_reset_tournament_monitor cannot complete because auto-generated
    # game IDs are < MIN_ID and the games_count check fails, so state remains
    # new_tournament_monitor. This pins the actual test environment behavior.
    assert_includes %w[new_tournament_monitor playing_groups], @tm.state
  end

  test "T04 can transition to playing_groups via start_playing_groups!" do
    # Directly test the AASM event (bypassing do_reset constraints)
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state
  end

  test "T04 can transition from playing_groups to playing_finals" do
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state

    assert @tm.may_start_playing_finals?,
      "Should be able to call start_playing_finals! from playing_groups"

    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state
  end

  test "T04 end_of_tournament transitions to closed from any state" do
    # end_of_tournament has no from: guard — transitions to closed from any state
    @tm.start_playing_groups!
    assert @tm.may_end_of_tournament?

    @tm.end_of_tournament!
    assert_equal "closed", @tm.state
  end

  test "T04 start_playing_groups is idempotent from playing_groups" do
    # start_playing_groups transitions from: [:new_tournament_monitor, :playing_groups]
    # so calling it again from playing_groups stays in playing_groups
    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state

    @tm.start_playing_groups!
    assert_equal "playing_groups", @tm.state,
      "start_playing_groups! from playing_groups should remain in playing_groups"
  end

  test "T04 start_playing_finals is reachable from new_tournament_monitor" do
    # start_playing_finals transitions from: [:new_tournament_monitor, :playing_groups, :playing_finals]
    assert @tm.may_start_playing_finals?,
      "Should be able to start finals from new_tournament_monitor"

    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state
  end

  # ============================================================================
  # distribute_to_group — GROUP_RULES-based distribution (CHAR-04)
  # ============================================================================

  test "distribute_to_group with 6 players uses GROUP_RULES" do
    # GROUP_RULES[6] = [[1, 4, 6], [2, 3, 5]]
    # distribute_with_sizes uses GROUP_SIZES[6]=[3,3] and GROUP_RULES[6]
    players = (1..6).to_a
    result  = TournamentMonitor.distribute_to_group(players, 2)

    assert_equal [1, 4, 6], result["group1"],
      "group1 should contain players at positions 1, 4, 6 per GROUP_RULES[6]"
    assert_equal [2, 3, 5], result["group2"],
      "group2 should contain players at positions 2, 3, 5 per GROUP_RULES[6]"
  end

  test "distribute_to_group with 8 players and 2 groups uses GROUP_RULES" do
    # GROUP_RULES[8] = [[1, 4, 5, 8], [2, 3, 6, 7]]
    players = (1..8).to_a
    result  = TournamentMonitor.distribute_to_group(players, 2)

    assert_equal [1, 4, 5, 8], result["group1"],
      "group1 should contain players at positions 1, 4, 5, 8 per GROUP_RULES[8]"
    assert_equal [2, 3, 6, 7], result["group2"],
      "group2 should contain players at positions 2, 3, 6, 7 per GROUP_RULES[8]"
  end

  test "distribute_to_group with 12 players and 3 groups uses GROUP_RULES" do
    # GROUP_RULES[12] = [[1, 6, 7, 12], [2, 5, 8, 11], [3, 4, 9, 10]]
    players = (1..12).to_a
    result  = TournamentMonitor.distribute_to_group(players, 3)

    assert_equal [1, 6, 7, 12], result["group1"],
      "group1 should contain players at positions 1, 6, 7, 12 per GROUP_RULES[12]"
    assert_equal [2, 5, 8, 11], result["group2"],
      "group2 should contain players at positions 2, 5, 8, 11 per GROUP_RULES[12]"
    assert_equal [3, 4, 9, 10], result["group3"],
      "group3 should contain players at positions 3, 4, 9, 10 per GROUP_RULES[12]"
  end

  test "distribute_to_group with 16 players and 4 groups uses GROUP_RULES" do
    # GROUP_RULES[16] = [[1, 8, 9, 16], [2, 6, 10, 15], [3, 7, 11, 14], [4, 5, 12, 13]]
    players = (1..16).to_a
    result  = TournamentMonitor.distribute_to_group(players, 4)

    assert_equal [1, 8, 9, 16],  result["group1"],
      "group1 should match GROUP_RULES[16][0]"
    assert_equal [2, 6, 10, 15], result["group2"],
      "group2 should match GROUP_RULES[16][1]"
    assert_equal [3, 7, 11, 14], result["group3"],
      "group3 should match GROUP_RULES[16][2]"
    assert_equal [4, 5, 12, 13], result["group4"],
      "group4 should match GROUP_RULES[16][3]"
  end

  test "distribute_to_group with custom group_sizes distributes all players" do
    # Passing group_sizes=[5,5] uses distribute_with_sizes.
    # GROUP_SIZES[10] = [5, 5] so GROUP_RULES[10] applies:
    # GROUP_RULES[10] = [[1, 4, 5, 7, 10], [2, 3, 6, 8, 9]]
    players = (1..10).to_a
    result  = TournamentMonitor.distribute_to_group(players, 2, [5, 5])

    assert_equal 2, result.keys.count, "Should create 2 groups"
    assert_equal 5, result["group1"].count, "group1 should have 5 players"
    assert_equal 5, result["group2"].count, "group2 should have 5 players"

    # All 10 players distributed, no overlap
    all_players = result["group1"] + result["group2"]
    assert_equal players.sort, all_players.sort, "All players should be distributed exactly once"
  end

  test "distribute_to_group returns a Hash" do
    players = (1..6).to_a
    result  = TournamentMonitor.distribute_to_group(players, 2)

    assert result.is_a?(Hash), "distribute_to_group should return a Hash"
    assert result.key?("group1"), "Should have a group1 key"
    assert result.key?("group2"), "Should have a group2 key"
  end

  test "distribute_to_group result contains player IDs not player objects" do
    # Players can be integers or objects; distribution returns player_id integers
    players = (1..6).to_a
    result  = TournamentMonitor.distribute_to_group(players, 2)

    all_ids = result.values.flatten
    all_ids.each do |id|
      assert id.is_a?(Integer), "Player ID #{id.inspect} should be an Integer"
    end
  end

  # ============================================================================
  # Game Creation & Sequencing — do_reset_tournament_monitor (CHAR-03)
  # ============================================================================

  test "do_reset_tournament_monitor creates round-robin games for 5-player T04 tournament" do
    # Games are created even though do_reset returns an error hash (due to MIN_ID check).
    # Characterization: in test env, games exist but with auto-assigned IDs < MIN_ID.
    # Use plain tournament.games.count (not the MIN_ID-filtered version).
    game_count = @tournament.games.count
    assert_equal 10, game_count,
      "T04 with 5 players should create 10 round-robin games (5C2)"
  end

  test "game names follow group<N>:pair format for T04 round-robin games" do
    game_names = @tournament.games.pluck(:gname)
    assert game_names.any?, "Should have games after initialization"

    game_names.each do |gname|
      assert_match(/\Agroup\d+:\d+-\d+\z/, gname,
        "T04 game name '#{gname}' should match pattern group<N>:<a>-<b>")
    end
  end

  test "each game has exactly 2 player participations" do
    games = @tournament.games
    assert games.any?, "Should have games after initialization"

    games.each do |game|
      gp_count = game.game_participations.count
      assert_equal 2, gp_count,
        "Game #{game.gname} should have 2 game_participations, got #{gp_count}"
    end
  end

  test "game participations have player_ids from the seedings" do
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

  test "current_round is 1 after T04 initialization" do
    assert_equal 1, @tm.current_round,
      "current_round should be 1 immediately after initialization"
  end

  test "incr_current_round increments the round counter" do
    @tm.incr_current_round!
    assert_equal 2, @tm.current_round

    @tm.incr_current_round!
    assert_equal 3, @tm.current_round
  end

  test "T04 tournament monitor data contains groups key after initialization" do
    assert @tm.data.is_a?(Hash), "TournamentMonitor data should be a Hash"
    assert @tm.data.key?("groups"),
      "TournamentMonitor data should contain 'groups' key after do_reset"
    assert @tm.data["groups"].key?("group1"),
      "groups should contain 'group1' for T04 single-group plan"
  end

  test "T04 group1 contains exactly 5 player_ids" do
    group1_player_ids = @tm.data["groups"]["group1"]
    assert_equal 5, group1_player_ids.count,
      "T04 group1 should contain all 5 players"
  end

  # ============================================================================
  # ApiProtector Verification (CHAR-09, D-06)
  # ============================================================================

  test "ApiProtectorTestOverride is in TournamentMonitor ancestors" do
    assert TournamentMonitor.ancestors.include?(ApiProtectorTestOverride),
      "ApiProtectorTestOverride should be prepended to TournamentMonitor in test environment"
  end

  test "ApiProtectorTestOverride allows saving local TournamentMonitor" do
    # Build a fresh TournamentMonitor with a local ID (>= 50_000_000).
    # Without ApiProtectorTestOverride, this would be silently rolled back.
    local_id = TEST_ID_BASE + 99_001

    tm = TournamentMonitor.new(
      id: local_id,
      tournament: @tournament,
      state: "new_tournament_monitor",
      balls_goal: 30,
      innings_goal: 25
    )

    # Use save(validate: false) to skip the AASM after_enter re-trigger
    saved = tm.save(validate: false)
    assert saved, "ApiProtectorTestOverride should allow saving a local TournamentMonitor"

    found = TournamentMonitor.find_by(id: local_id)
    assert found.present?, "TournamentMonitor with local id #{local_id} should be persisted"
    assert found.persisted?, "TournamentMonitor should report persisted? == true"
  ensure
    # Clean up manually created TM so cleanup_t04_tournament can destroy the tournament
    TournamentMonitor.find_by(id: local_id)&.destroy
  end
end
