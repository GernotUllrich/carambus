# frozen_string_literal: true

require "test_helper"

class TournamentPlanKoTest < ActiveSupport::TestCase
  setup do
    @discipline = disciplines(:carom_3band)
    @season = seasons(:current)
    @region = regions(:nbv)
  end

  # ============================================================================
  # Test KO Plan Generation for Various Player Counts
  # ============================================================================

  test "generates correct KO plan for 16 players" do
    plan = TournamentPlan.ko_plan(16)

    assert_not_nil plan
    assert_equal "KO_16", plan.name
    assert_equal 16, plan.players
    assert_equal 1, plan.ngroups
    assert_equal 999, plan.tables

    params = JSON.parse(plan.executor_params)

    # 16 players = 15 games total (8f=8, qf=4, hf=2, fin=1)
    assert_equal 15, params["GK"], "Should have 15 total games for 16 players"

    # Verify game structure: 16-player plan uses 8f (8 first-round games)
    assert params.key?("8f1"), "Should have 8f games as first round"
    assert params.key?("qf1"), "Should have quarterfinal games"
    assert params.key?("hf1"), "Should have semifinal games"
    assert params.key?("fin"), "Should have final game"

    # Verify ranking structure
    assert params["RK"].is_a?(Array), "Should have ranking structure"
    assert_equal "fin.rk1", params["RK"][0], "Winner should be fin.rk1"
    assert_equal "fin.rk2", params["RK"][1], "Runner-up should be fin.rk2"
  end

  test "generates correct KO plan for 24 players" do
    plan = TournamentPlan.ko_plan(24)

    assert_not_nil plan
    assert_equal "KO_24", plan.name
    assert_equal 24, plan.players

    params = JSON.parse(plan.executor_params)

    # 24 players: 8 pre-qualifying (16f) + 8 round-of-8 (8f) + 4 QF + 2 SF + 1 Final = 23 games
    assert_equal 23, params["GK"], "Should have 23 total games for 24 players"

    # Verify pre-qualifying round exists (16f for 24-player plan)
    assert params.key?("16f1"), "Should have 16f pre-qualifying games"
    assert params.key?("16f8"), "Should have 8 pre-qualifying games"

    # Verify main bracket
    assert params.key?("8f1"), "Should have round of 8"
    assert params.key?("qf1"), "Should have quarterfinals"
    assert params.key?("hf1"), "Should have semifinals"
    assert params.key?("fin"), "Should have final"
  end

  test "generates correct KO plan for 32 players" do
    plan = TournamentPlan.ko_plan(32)

    assert_not_nil plan
    assert_equal "KO_32", plan.name
    assert_equal 32, plan.players

    params = JSON.parse(plan.executor_params)

    # 32 players = 31 games
    assert_equal 31, params["GK"], "Should have 31 total games for 32 players"

    # Verify first round uses 16f (16 games)
    assert params.key?("16f1"), "Should have round of 16"
    assert params.key?("16f16"), "Should have 16 games in first round"
  end

  test "handles edge cases for player counts" do
    # Test minimum
    plan = TournamentPlan.ko_plan(2)
    assert_not_nil plan
    params = JSON.parse(plan.executor_params)
    assert_equal 1, params["GK"], "2 players need 1 game"

    # Test invalid counts
    assert_nil TournamentPlan.ko_plan(1), "Should reject 1 player"
    assert_nil TournamentPlan.ko_plan(65), "Should reject > 64 players"
    assert_nil TournamentPlan.ko_plan(0), "Should reject 0 players"
  end

  # ============================================================================
  # Test Bracket Structure and Player References
  # ============================================================================

  test "KO plan references seedings correctly for first round" do
    plan = TournamentPlan.ko_plan(16)
    params = JSON.parse(plan.executor_params)

    # 16-player plan uses 8f as first round
    first_game = params["8f1"]["r1"]["t-rand*"]
    assert first_game.is_a?(Array), "Game should have two player references"
    assert_equal 2, first_game.length, "Game should have exactly 2 players"

    # Check that references are seeding list references (sl.rk<n>)
    first_game.each do |ref|
      assert_match(/^sl\.rk\d+$/, ref, "First round should reference seeding list")
    end
  end

  test "KO plan references previous game results correctly" do
    plan = TournamentPlan.ko_plan(16)
    params = JSON.parse(plan.executor_params)

    # Quarterfinal should reference winners from round of 8 (8f)
    qf_game = params["qf1"]["r3"]["t-rand*"]

    qf_game.each do |ref|
      # Should reference winner (rk1) of 8f games
      assert_match(/^8f\d+\.rk1$/, ref, "QF should reference 8f winners")
    end

    # Semifinal should reference QF winners
    hf_game = params["hf1"]["r4"]["t-rand*"]
    hf_game.each do |ref|
      assert_match(/^qf\d+\.rk1$/, ref, "SF should reference QF winners")
    end

    # Final should reference SF winners
    fin_game = params["fin"]["r5"]["t-rand*"]
    fin_game.each do |ref|
      assert_match(/^hf\d+\.rk1$/, ref, "Final should reference SF winners")
    end
  end

  test "KO plan creates proper ranking structure" do
    plan = TournamentPlan.ko_plan(16)
    params = JSON.parse(plan.executor_params)

    rk = params["RK"]
    assert rk.is_a?(Array), "RK should be an array"

    # First two entries are winner and runner-up
    assert_equal "fin.rk1", rk[0], "First rank should be final winner"
    assert_equal "fin.rk2", rk[1], "Second rank should be final loser"

    # Subsequent entries should be arrays of losers from previous rounds
    rk[2..].each do |entry|
      if entry.is_a?(Array)
        entry.each do |ref|
          assert_match(/\.rk2$/, ref, "Lower ranks should reference losers")
        end
      end
    end
  end

  # ============================================================================
  # Test rf() helper method (filters problematic game names)
  # ============================================================================

  test "rf method handles problematic game name patterns" do
    # The rf() method prevents issues with game names that look like numbers
    assert_equal "qf1", TournamentPlan.rf("4f1"), "Should convert 4f to qf"
    assert_equal "hf1", TournamentPlan.rf("2f1"), "Should convert 2f to hf"
    assert_equal "fin", TournamentPlan.rf("1f1"), "Should convert 1f1 to fin"
    assert_equal "64f1", TournamentPlan.rf("64f1"), "Should preserve 64f"
    assert_equal "32f1", TournamentPlan.rf("32f1"), "Should preserve 32f"
  end

  # ============================================================================
  # Test Plan Persistence and Reuse
  # ============================================================================

  test "KO plan can be saved and reused" do
    plan = TournamentPlan.ko_plan(24)
    assert plan.save, "Plan should be saveable"

    # Calling again should return same plan
    plan2 = TournamentPlan.ko_plan(24)
    assert_equal plan.id, plan2.id, "Should reuse existing plan"
  end

  test "KO plan detects correct rounds_count as nil" do
    plan = TournamentPlan.ko_plan(16)
    plan.save!

    # KO plans should return nil for rounds_count (complex structure)
    assert_nil plan.rounds_count, "KO plans should not report simple rounds count"
  end
end
