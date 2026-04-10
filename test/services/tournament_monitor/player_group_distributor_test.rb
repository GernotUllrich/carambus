# frozen_string_literal: true

require "test_helper"

# Unit tests for TournamentMonitor::PlayerGroupDistributor
# Covers distribute_to_group, distribute_with_sizes, and constants.
class TournamentMonitor::PlayerGroupDistributorTest < ActiveSupport::TestCase
  # Use integer arrays as player inputs (methods handle Integer via player.is_a?(Integer) check).

  # ============================================================================
  # Constants
  # ============================================================================

  test "DIST_RULES is a frozen hash" do
    assert TournamentMonitor::PlayerGroupDistributor::DIST_RULES.is_a?(Hash)
    assert TournamentMonitor::PlayerGroupDistributor::DIST_RULES.frozen?
  end

  test "GROUP_RULES is a frozen hash" do
    assert TournamentMonitor::PlayerGroupDistributor::GROUP_RULES.is_a?(Hash)
    assert TournamentMonitor::PlayerGroupDistributor::GROUP_RULES.frozen?
  end

  test "GROUP_SIZES is a frozen hash" do
    assert TournamentMonitor::PlayerGroupDistributor::GROUP_SIZES.is_a?(Hash)
    assert TournamentMonitor::PlayerGroupDistributor::GROUP_SIZES.frozen?
  end

  # ============================================================================
  # distribute_to_group — 2-group zig-zag
  # ============================================================================

  test "distribute_to_group with 8 players 2 groups returns correct zig-zag assignment" do
    players = [1, 2, 3, 4, 5, 6, 7, 8]
    result = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 2)

    # 8 players, 2 groups → GROUP_SIZES[8] = [4, 4], uses GROUP_RULES[8] path
    # GROUP_RULES[8] = [[1, 4, 5, 8], [2, 3, 6, 7]]
    # group1 gets positions 1,4,5,8 → players[0,3,4,7] = 1,4,5,8
    # group2 gets positions 2,3,6,7 → players[1,2,5,6] = 2,3,6,7
    assert_equal 2, result.keys.length
    assert_includes result.keys, "group1"
    assert_includes result.keys, "group2"
    assert_equal [1, 4, 5, 8], result["group1"].sort
    assert_equal [2, 3, 6, 7], result["group2"].sort
  end

  test "distribute_to_group with 12 players 3 groups returns correct GROUP_RULES[12] assignment" do
    players = (1..12).to_a
    result = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 3)

    # GROUP_SIZES[12] = [4, 4, 4], uses GROUP_RULES[12] path
    # GROUP_RULES[12] = [[1, 6, 7, 12], [2, 5, 8, 11], [3, 4, 9, 10]]
    # group1: positions 1,6,7,12 → players 1,6,7,12
    # group2: positions 2,5,8,11 → players 2,5,8,11
    # group3: positions 3,4,9,10 → players 3,4,9,10
    assert_equal 3, result.keys.length
    assert_equal [1, 6, 7, 12], result["group1"].sort
    assert_equal [2, 5, 8, 11], result["group2"].sort
    assert_equal [3, 4, 9, 10], result["group3"].sort
  end

  test "distribute_to_group with 16 players 4 groups returns correct GROUP_RULES[16] assignment" do
    players = (1..16).to_a
    result = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 4)

    # GROUP_SIZES[16] = [4, 4, 4, 4], uses GROUP_RULES[16] path
    # GROUP_RULES[16] = [[1, 8, 9, 16], [2, 6, 10, 15], [3, 7, 11, 14], [4, 5, 12, 13]]
    assert_equal 4, result.keys.length
    assert_equal [1, 8, 9, 16], result["group1"].sort
    assert_equal [2, 6, 10, 15], result["group2"].sort
    assert_equal [3, 7, 11, 14], result["group3"].sort
    assert_equal [4, 5, 12, 13], result["group4"].sort
  end

  test "distribute_to_group with 9 players 3 groups returns 3 groups of 3" do
    players = (1..9).to_a
    result = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 3)

    # GROUP_SIZES[9] = [3, 3, 3], uses GROUP_RULES[9] path
    # GROUP_RULES[9] = [[1, 4, 9], [2, 5, 8], [3, 6, 7]]
    assert_equal 3, result.keys.length
    assert_equal 3, result["group1"].length
    assert_equal 3, result["group2"].length
    assert_equal 3, result["group3"].length
    assert_equal [1, 4, 9], result["group1"].sort
    assert_equal [2, 5, 8], result["group2"].sort
    assert_equal [3, 6, 7], result["group3"].sort
  end

  # ============================================================================
  # distribute_with_sizes — custom group sizes
  # ============================================================================

  test "distribute_with_sizes with custom group_sizes distributes correctly" do
    players = (1..7).to_a
    # Custom sizes: group1 gets 4, group2 gets 3
    result = TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, 2, [4, 3])

    assert_equal 2, result.keys.length
    total_assigned = result.values.flatten.length
    assert_equal 7, total_assigned
    assert_equal 4, result["group1"].length
    assert_equal 3, result["group2"].length
  end

  test "distribute_to_group with custom group_sizes array delegates to distribute_with_sizes" do
    players = (1..7).to_a
    result = TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 2, [4, 3])

    assert_equal 2, result.keys.length
    assert_equal 7, result.values.flatten.length
  end

  # ============================================================================
  # Edge cases
  # ============================================================================

  test "distribute_to_group with 0 ngroups does not raise" do
    players = (1..8).to_a
    result = assert_nothing_raised do
      TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, 0)
    end
    # With ngroups == 0 it falls through to GROUP_SIZES path using player count
    assert result.is_a?(Hash)
  end
end
