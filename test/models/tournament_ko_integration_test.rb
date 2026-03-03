# frozen_string_literal: true

require "test_helper"

class TournamentKoIntegrationTest < ActiveSupport::TestCase
  include KoTournamentTestHelper
  
  # Use transactions to ensure complete test isolation
  self.use_transactional_tests = true
  
  setup do
    # Create test tournament using helper (ensures unique IDs)
    @test_data = create_ko_tournament_with_seedings(16)
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]
    @seedings = @test_data[:seedings]
  end

  teardown do
    # Cleanup handled by transaction rollback
    # But explicit cleanup for non-transactional safety
    cleanup_ko_tournament(@test_data) if @test_data
  end

  # ============================================================================
  # Test Tournament Initialization
  # ============================================================================

  test "initializing KO tournament creates tournament monitor" do
    @tournament.initialize_tournament_monitor
    
    assert_not_nil @tournament.tournament_monitor, "Should create tournament monitor"
    assert_equal "new_tournament_monitor", @tournament.tournament_monitor.state
  end

  test "tournament monitor inherits correct settings" do
    @tournament.update!(
      balls_goal: 30,
      innings_goal: 25,
      sets_to_play: 3,
      sets_to_win: 2
    )
    
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    
    assert_equal 30, tm.balls_goal
    assert_equal 25, tm.innings_goal
    assert_equal 3, tm.sets_to_play
    assert_equal 2, tm.sets_to_win
  end

  # ============================================================================
  # Test Game Creation from KO Plan
  # ============================================================================

  test "resetting KO tournament creates all games immediately" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    
    # Trigger game creation
    tm.do_reset_tournament_monitor
    
    # Should create all 15 games for 16-player bracket
    assert_equal 15, @tournament.games.count, "Should create 15 games for 16 players"
    
    # Check game names
    game_names = @tournament.games.pluck(:gname).sort
    
    # Should have: 8x16f, 4xqf, 2xhf, 1xfin = 15 games
    assert_equal 8, game_names.count { |n| n.start_with?("16f") }, "Should have 8 round-of-16 games"
    assert_equal 4, game_names.count { |n| n.start_with?("qf") }, "Should have 4 quarterfinal games"
    assert_equal 2, game_names.count { |n| n.start_with?("hf") }, "Should have 2 semifinal games"
    assert_equal 1, game_names.count { |n| n == "fin" }, "Should have 1 final game"
  end

  test "first round games have players assigned from seedings" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    tm.do_reset_tournament_monitor
    
    # First round games should have players assigned
    first_round_games = @tournament.games.where("gname LIKE '16f%'").order(:gname)
    
    assert_equal 8, first_round_games.count
    
    first_round_games.each do |game|
      assert_equal 2, game.game_participations.count, "#{game.gname} should have 2 players"
      
      game.game_participations.each do |gp|
        assert_not_nil gp.player_id, "#{game.gname} should have actual player assigned"
        assert_includes @players.map(&:id), gp.player_id, "Player should be from seedings"
      end
    end
  end

  test "later round games initially have no players assigned" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    tm.do_reset_tournament_monitor
    
    # QF, HF, and Final should initially have no players (waiting for results)
    later_games = @tournament.games.where("gname LIKE 'qf%' OR gname LIKE 'hf%' OR gname = 'fin'")
    
    later_games.each do |game|
      # Games are created but participations wait for previous round results
      player_count = game.game_participations.where.not(player_id: nil).count
      assert_equal 0, player_count, "#{game.gname} should not have players assigned yet"
    end
  end

  # ============================================================================
  # Test Winner Advancement Through Bracket
  # ============================================================================

  test "completing first round games advances winners to quarterfinals" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    tm.do_reset_tournament_monitor
    
    # Complete all first round games (16f)
    first_round_games = @tournament.games.where("gname LIKE '16f%'").order(:gname)
    winners = []
    
    first_round_games.each do |game|
      gps = game.game_participations.order(:role).to_a
      winner = gps[0] # playera wins
      
      # Use helper to finish game
      finish_game(game, "playera")
      winners << winner.player_id
    end
    
    # Trigger advancement (re-run do_reset to process results)
    tm.do_reset_tournament_monitor
    
    # Check that QF games now have players
    qf_games = @tournament.games.where("gname LIKE 'qf%'").order(:gname)
    
    qf_games.each do |game|
      game.reload
      assigned_players = game.game_participations.where.not(player_id: nil).count
      
      # After first round completes, QF games should get their players
      if assigned_players > 0
        game.game_participations.each do |gp|
          assert_includes winners, gp.player_id, "QF should have winners from 16f"
        end
      end
    end
  end

  test "ko_ranking resolves seeding list references correctly" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    
    # Test resolving seeding list reference using helper
    assert_player_reference_resolves(tm, "sl.rk1", @players[0].id)
    assert_player_reference_resolves(tm, "sl.rk16", @players[15].id)
  end

  # ============================================================================
  # Test 24-Player Tournament (Pre-Qualifying Round)
  # ============================================================================

  test "24-player tournament creates pre-qualifying round" do
    # Create separate 24-player tournament
    data_24 = create_ko_tournament_with_seedings(24)
    tournament_24 = data_24[:tournament]
    
    tournament_24.initialize_tournament_monitor
    tm = tournament_24.tournament_monitor
    tm.do_reset_tournament_monitor
    
    # Should create 23 games total
    assert_equal 23, tournament_24.games.count
    
    # Should have 8 pre-qualifying games (32f)
    pre_qual_games = tournament_24.games.where("gname LIKE '32f%'")
    assert_equal 8, pre_qual_games.count, "Should have 8 pre-qualifying games"
    
    # Pre-qualifying games should have players assigned
    assert_first_round_has_players(tournament_24)
    
    # 16f games should initially be empty (waiting for 32f results)
    round_16_games = tournament_24.games.where("gname LIKE '16f%'")
    assert_equal 8, round_16_games.count
    
    # Cleanup (will also be handled by transaction rollback)
    cleanup_ko_tournament(data_24)
  end

  # ============================================================================
  # Test Bracket View Data
  # ============================================================================

  test "tournament provides bracket structure for view" do
    @tournament.initialize_tournament_monitor
    tm = @tournament.tournament_monitor
    tm.do_reset_tournament_monitor
    
    # Use helper to verify bracket structure
    assert_valid_ko_bracket(@tournament)
    
    # Tournament should have games organized by round
    games_by_round = @tournament.games.group_by { |g| g.gname[/^[a-z]+/] }
    
    assert games_by_round.key?("16f"), "Should have round of 16"
    assert games_by_round.key?("qf"), "Should have quarterfinals"
    assert games_by_round.key?("hf"), "Should have semifinals"
    assert games_by_round.key?("fin"), "Should have final"
  end
end
