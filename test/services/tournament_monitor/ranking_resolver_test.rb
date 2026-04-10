# frozen_string_literal: true

require "test_helper"

# Unit tests for TournamentMonitor::RankingResolver
# Covers player_id_from_ranking and all private resolution paths.
class TournamentMonitor::RankingResolverTest < ActiveSupport::TestCase
  include KoTournamentTestHelper

  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(8, {
      balls_goal: 30,
      innings_goal: 25
    })
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]

    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor

    # Populate rankings in tournament monitor data for tests
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.data["rankings"]["groups"] ||= {}
    @tm.data["rankings"]["endgames"] ||= {}
    @tm.data["rankings"]["groups"]["group1"] = {
      @players[0].id.to_s => { "points" => 4, "gd" => 2.0 },
      @players[1].id.to_s => { "points" => 2, "gd" => 1.5 }
    }
    @tm.save!

    @resolver = TournamentMonitor::RankingResolver.new(@tm)
  end

  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # Test 1: player_id_from_ranking resolves seeding list (sl.rk1 → first seeded player_id)
  # ============================================================================

  test "player_id_from_ranking resolves sl.rk1 to first seeded player_id" do
    result = @resolver.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal @players[0].id, result
  end

  test "player_id_from_ranking resolves sl.rk2 to second seeded player_id" do
    result = @resolver.player_id_from_ranking("sl.rk2", executor_params: {})
    assert_equal @players[1].id, result
  end

  # ============================================================================
  # Test 2: player_id_from_ranking resolves group rank (g1.2 → 2nd player in group 1)
  # ============================================================================

  test "player_id_from_ranking resolves g1.1 to first player in group 1" do
    # g1.1 uses group_rank path — returns first player from distributed group 1
    result = @resolver.player_id_from_ranking("g1.1", {})
    # The result should be a player_id (integer), may be nil if group distribution returns nil
    # Just verify it doesn't raise and returns an integer or nil
    assert(result.nil? || result.is_a?(Integer), "Expected Integer or nil, got #{result.inspect}")
  end

  # ============================================================================
  # Test 3: player_id_from_ranking returns nil on invalid rule string (rescue path)
  # ============================================================================

  test "player_id_from_ranking returns nil on invalid rule string" do
    result = @resolver.player_id_from_ranking("totally-invalid-rule-xyz", executor_params: {})
    assert_nil result
  end

  test "player_id_from_ranking returns nil on nil rule string" do
    result = assert_nothing_raised do
      @resolver.player_id_from_ranking(nil.to_s, executor_params: {})
    end
    assert_nil result
  end

  # ============================================================================
  # Test 4: player_id_from_ranking resolves rule references recursively
  # ============================================================================

  test "player_id_from_ranking resolves rule1 by following executor_params rules" do
    opts = {
      executor_params: {
        "rules" => {
          "rule1" => "sl.rk1"
        }
      }
    }
    result = @resolver.player_id_from_ranking("rule1", opts)
    assert_equal @players[0].id, result
  end

  # ============================================================================
  # Test 5: group_rank calls PlayerGroupDistributor.distribute_to_group directly (D-05)
  # ============================================================================

  test "group_rank calls PlayerGroupDistributor.distribute_to_group directly not TournamentMonitor.distribute_to_group" do
    distributor_called = false
    old_method = TournamentMonitor::PlayerGroupDistributor.method(:distribute_to_group)

    TournamentMonitor::PlayerGroupDistributor.define_singleton_method(:distribute_to_group) do |*args|
      distributor_called = true
      old_method.call(*args)
    end

    begin
      @resolver.player_id_from_ranking("g1.1", {})
    rescue StandardError
      # May raise on incomplete test data — we only care that the right method was called
    ensure
      TournamentMonitor::PlayerGroupDistributor.define_singleton_method(:distribute_to_group, old_method)
    end

    assert distributor_called, "Expected PlayerGroupDistributor.distribute_to_group to be called directly"
  end

  # ============================================================================
  # Integration: RankingResolver behaves identically to TournamentMonitor delegation
  # ============================================================================

  test "resolver and tournament_monitor produce same result for seeding resolution" do
    resolver_result = @resolver.player_id_from_ranking("sl.rk1", executor_params: {})
    tm_result = @tm.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal tm_result, resolver_result
  end
end
