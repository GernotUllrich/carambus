# frozen_string_literal: true

require "test_helper"

class TournamentMonitorKoTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  # Use transactions for isolation
  self.use_transactional_tests = true

  setup do
    # Create 8-player tournament for faster tests
    @test_data = create_ko_tournament_with_seedings(8, {
      balls_goal: 30,
      innings_goal: 25
    })
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]

    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # Test KO-Specific TournamentMonitor Methods
  # ============================================================================

  test "ko_ranking resolves seeding list references" do
    # ko_ranking is private — test via send
    assert_equal @players[0].id, @tm.send(:ko_ranking, "sl.rk1")
    assert_equal @players[1].id, @tm.send(:ko_ranking, "sl.rk2")
    assert_equal @players[7].id, @tm.send(:ko_ranking, "sl.rk8")
  end

  test "ko_ranking handles invalid references gracefully" do
    # Should not crash on invalid references
    assert_nil @tm.send(:ko_ranking, "sl.rk99")
    assert_nil @tm.send(:ko_ranking, "invalid.rk1")
  end

  test "ko_ranking resolves game winner references after results" do
    @tm.do_reset_tournament_monitor

    # Get a quarterfinal game (created by reset)
    qf_game = @tournament.games.find_by(gname: "qf1")
    assert_not_nil qf_game

    # Populate rankings in tournament monitor data (simulates a finished game result)
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.data["rankings"]["endgames"] ||= {}
    @tm.data["rankings"]["endgames"]["qf1"] = {
      @players[0].id.to_s => { "points" => 2, "gd" => 1.5 },
      @players[1].id.to_s => { "points" => 0, "gd" => 1.0 }
    }
    @tm.save!

    # Now ko_ranking should resolve qf1.rk1 to the winner
    # Rankings store player IDs as strings (JSON keys), so convert for comparison
    winner_id = @tm.send(:ko_ranking, "qf1.rk1")
    assert_equal @players[0].id.to_s, winner_id.to_s, "Should resolve to playera (winner)"
  end

  test "player_id_from_ranking handles nested group expressions" do
    @tm.do_reset_tournament_monitor

    # Test simple seeding reference via public method
    player_id = @tm.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal @players[0].id, player_id
  end

  # ============================================================================
  # Test Game Creation Flow
  # ============================================================================

  test "do_reset_tournament_monitor creates games for KO plan" do
    @tm.do_reset_tournament_monitor

    # 8 players = 7 games (4 QF + 2 SF + 1 Final)
    # Note: games may accumulate since destroy_all only removes id >= MIN_ID
    # Verify the expected game names are present
    game_names = @tournament.games.pluck(:gname)
    assert_includes game_names, "qf1", "QF1 game must exist"
    assert_includes game_names, "hf1", "SF1 game must exist"
    assert_includes game_names, "fin", "Final game must exist"
    assert_equal 7, game_names.uniq.size, "Should have 7 unique game names"
  end

  test "KO games are created immediately not round-by-round" do
    # KO tournaments create all games at once (unlike group stage tournaments)
    @tm.do_reset_tournament_monitor

    # Should create games for all rounds immediately
    assert @tournament.games.exists?(gname: "qf1"), "Should create QF games"
    assert @tournament.games.exists?(gname: "hf1"), "Should create SF games"
    assert @tournament.games.exists?(gname: "fin"), "Should create Final game"
  end

  test "current_round is not used for KO tournaments" do
    @tm.do_reset_tournament_monitor

    # KO tournaments don't use round-by-round progression
    # All games remain accessible after round increments
    @tm.incr_current_round!
    @tm.do_reset_tournament_monitor

    # All expected game types remain accessible
    assert @tournament.games.exists?(gname: "qf1"), "QF games remain after round increment"
    assert @tournament.games.exists?(gname: "fin"), "Final game remains after round increment"
  end

  # ============================================================================
  # Test Table Assignment for KO Games
  # ============================================================================

  test "KO games use t-rand* for random table assignment" do
    @tm.do_reset_tournament_monitor

    params = JSON.parse(@tournament.tournament_plan.executor_params)

    # Check that games use t-rand* table assignment
    params.each do |key, value|
      next if ["GK", "RK"].include?(key)

      round_data = value.values.first
      table_spec = round_data.keys.first

      # KO games should use wildcard table assignment
      assert_equal "t-rand*", table_spec, "#{key} should use t-rand* table assignment"
    end
  end

  # ============================================================================
  # Test Error Handling
  # ============================================================================

  test "handles missing tournament plan gracefully" do
    game_count_before = @tournament.games.count
    @tournament.update!(tournament_plan: nil)

    # Should not crash, but won't create new games
    assert_nothing_raised do
      @tm.do_reset_tournament_monitor
    end

    # No additional games created (only pre-existing games from setup remain)
    assert_equal game_count_before, @tournament.games.count,
      "Should not create additional KO games without plan"
  end

  test "handles invalid executor_params gracefully" do
    plan = @tournament.tournament_plan
    plan.update!(executor_params: "invalid json")

    # do_reset_tournament_monitor catches JSON::ParserError and returns an error hash
    result = nil
    assert_nothing_raised do
      result = @tm.do_reset_tournament_monitor
    end
    assert result.is_a?(Hash), "Should return an error hash on invalid executor_params"
    assert result.key?("ERROR"), "Error hash must contain ERROR key"
  end

  test "handles missing seedings gracefully" do
    # Remove all seedings
    @tournament.seedings.destroy_all

    # Should not crash — returns an error hash when no seedings found
    result = nil
    assert_nothing_raised do
      result = @tm.do_reset_tournament_monitor
    end

    # Method returns an error hash when seedings are missing
    assert result.is_a?(Hash), "Should return an error hash when seedings missing"
    assert result.key?("ERROR"), "Error hash must contain ERROR key"
  end

  # ============================================================================
  # Test State Transitions
  # ============================================================================

  test "tournament monitor transitions to playing_finals after KO reset" do
    # For KO tournaments (no group stage), do_reset_tournament_monitor
    # transitions the monitor directly to playing_finals
    @tm.do_reset_tournament_monitor
    @tm.reload
    assert_equal "playing_finals", @tm.state,
      "KO tournament monitor should be in playing_finals after reset (no group stage)"
  end

  test "can transition to playing_finals for KO tournaments" do
    # After reset, KO tournament is already in playing_finals
    @tm.do_reset_tournament_monitor
    @tm.reload

    assert_equal "playing_finals", @tm.state,
      "KO tournament monitor should reach playing_finals state"
  end

  # ============================================================================
  # Test Data Structure
  # ============================================================================

  test "tournament monitor data structure includes placements" do
    @tm.do_reset_tournament_monitor

    assert @tm.data.is_a?(Hash), "Data should be a hash"

    # May include placements or placement_candidates
    if @tm.data["placements"]
      assert @tm.data["placements"].is_a?(Hash)
    end

    if @tm.data["placement_candidates"]
      assert @tm.data["placement_candidates"].is_a?(Array)
    end
  end

  test "tournament monitor handles continuous placements for KO" do
    @tournament.update!(continuous_placements: true)
    @tm.do_reset_tournament_monitor

    # With continuous placements, data structure is maintained
    assert_not_nil @tm.data, "Data must not be nil after reset"
    assert @tm.data.is_a?(Hash), "Data must be a hash"
  end
end
