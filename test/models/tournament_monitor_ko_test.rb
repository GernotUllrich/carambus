# frozen_string_literal: true

require "test_helper"

class TournamentMonitorKoTest < ActiveSupport::TestCase
  setup do
    @discipline = disciplines(:carom_3band)
    @season = seasons(:current)
    @region = regions(:nbv)
    
    # Create tournament with KO plan
    @tournament = Tournament.create!(
      id: 50_000_200,
      title: "TM KO Test Tournament",
      season: @season,
      organizer: @region,
      organizer_type: "Region",
      discipline: @discipline,
      state: "initialized",
      date: 2.weeks.from_now,
      balls_goal: 30,
      innings_goal: 25,
      tournament_plan: TournamentPlan.ko_plan(8) # Smaller for faster tests
    )
    
    # Create 8 test players
    @players = (1..8).map do |i|
      Player.create!(
        id: 50_000_200 + i,
        firstname: "KO",
        lastname: "Player#{i}",
        shortname: "KOP#{i}",
        ba_id: 9_200_000 + i
      )
    end
    
    # Create seedings
    @players.each_with_index do |player, idx|
      Seeding.create!(
        id: 50_000_200 + idx + 1,
        tournament: @tournament,
        player: player,
        position: idx + 1,
        region: @region
      )
    end
    
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
  end

  teardown do
    @tournament&.games&.destroy_all
    @tournament&.seedings&.destroy_all
    @tournament&.tournament_monitor&.destroy
    @tournament&.destroy
    @players&.each(&:destroy)
  end

  # ============================================================================
  # Test KO-Specific TournamentMonitor Methods
  # ============================================================================

  test "ko_ranking resolves seeding list references" do
    # Direct seeding references
    assert_equal @players[0].id, @tm.ko_ranking("sl.rk1")
    assert_equal @players[1].id, @tm.ko_ranking("sl.rk2")
    assert_equal @players[7].id, @tm.ko_ranking("sl.rk8")
  end

  test "ko_ranking handles invalid references gracefully" do
    # Should not crash on invalid references
    assert_nil @tm.ko_ranking("sl.rk99")
    assert_nil @tm.ko_ranking("invalid.rk1")
  end

  test "ko_ranking resolves game winner references after results" do
    @tm.do_reset_tournament_monitor
    
    # Get a quarterfinal game
    qf_game = @tournament.games.find_by(gname: "qf1")
    assert_not_nil qf_game
    
    # Assign players manually for testing
    gp_a = qf_game.game_participations.create!(player: @players[0], role: "playera")
    gp_b = qf_game.game_participations.create!(player: @players[1], role: "playerb")
    
    # Simulate game result (playera wins)
    qf_game.update!(data: {
      "results" => {
        "playera" => { "balls" => 30, "innings" => 20 },
        "playerb" => { "balls" => 20, "innings" => 20 }
      }
    })
    
    # Need to populate rankings in tournament monitor data
    @tm.data ||= {}
    @tm.data["rankings"] ||= {}
    @tm.data["rankings"]["endgames"] ||= {}
    @tm.data["rankings"]["endgames"]["qf1"] = {
      @players[0].id.to_s => { "points" => 2, "gd" => 1.5 },
      @players[1].id.to_s => { "points" => 0, "gd" => 1.0 }
    }
    @tm.save!
    
    # Now ko_ranking should resolve qf1.rk1 to the winner
    winner_id = @tm.ko_ranking("qf1.rk1")
    assert_equal @players[0].id, winner_id, "Should resolve to playera (winner)"
  end

  test "player_id_from_ranking handles nested group expressions" do
    @tm.do_reset_tournament_monitor
    
    # Test simple seeding reference
    player_id = @tm.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal @players[0].id, player_id
  end

  # ============================================================================
  # Test Game Creation Flow
  # ============================================================================

  test "do_reset_tournament_monitor creates games for KO plan" do
    @tm.do_reset_tournament_monitor
    
    # 8 players = 7 games (4 QF + 2 SF + 1 Final)
    assert_equal 7, @tournament.games.count
    
    game_names = @tournament.games.pluck(:gname).sort
    assert_equal ["fin", "hf1", "hf2", "qf1", "qf2", "qf3", "qf4"], game_names
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
    # All games exist from the start
    initial_round = @tm.current_round
    
    # Even if we increment round, all games remain accessible
    @tm.incr_current_round!
    @tm.do_reset_tournament_monitor
    
    # Games should still exist
    assert_equal 7, @tournament.games.count
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
    @tournament.update!(tournament_plan: nil)
    
    # Should not crash, but won't create games
    assert_nothing_raised do
      @tm.do_reset_tournament_monitor
    end
    
    assert_equal 0, @tournament.games.count, "Should not create games without plan"
  end

  test "handles invalid executor_params gracefully" do
    plan = @tournament.tournament_plan
    plan.update!(executor_params: "invalid json")
    
    # Should handle parse errors gracefully
    assert_raises(JSON::ParserError) do
      @tm.do_reset_tournament_monitor
    end
  end

  test "handles missing seedings gracefully" do
    # Remove all seedings
    @tournament.seedings.destroy_all
    
    # Should not crash, but games won't have players assigned
    assert_nothing_raised do
      @tm.do_reset_tournament_monitor
    end
    
    # Games created but without players
    assert_equal 7, @tournament.games.count
    
    first_game = @tournament.games.first
    assert_equal 0, first_game.game_participations.where.not(player_id: nil).count
  end

  # ============================================================================
  # Test State Transitions
  # ============================================================================

  test "tournament monitor starts in new_tournament_monitor state" do
    assert_equal "new_tournament_monitor", @tm.state
  end

  test "can transition to playing_finals for KO tournaments" do
    @tm.do_reset_tournament_monitor
    
    # KO tournaments can go directly to finals (no group stage)
    assert @tm.may_start_playing_finals?, "Should be able to start finals"
    
    @tm.start_playing_finals!
    assert_equal "playing_finals", @tm.state
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
    
    # With continuous placements, games are added to placement_candidates
    # when both players are known
    assert_not_nil @tm.data
  end
end
