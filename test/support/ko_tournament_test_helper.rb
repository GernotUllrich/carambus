# frozen_string_literal: true

module KoTournamentTestHelper
  # Base ID for test data to avoid conflicts with production data
  # Using IDs >= 50_000_000 ensures no collision with imported or local data
  TEST_ID_BASE = 50_000_000

  # Counter for unique IDs within a test run
  @@ko_test_counter = 0

  # Create a complete test tournament with seedings
  # @param player_count [Integer] Number of players (2-64)
  # @param tournament_attrs [Hash] Additional tournament attributes
  # @return [Hash] { tournament:, players:, seedings: }
  def create_ko_tournament_with_seedings(player_count, tournament_attrs = {})
    # Ensure we have required fixtures
    discipline = disciplines(:carom_3band)
    season = seasons(:current)
    region = regions(:nbv)

    # Generate unique IDs using counter to avoid rand() conflicts between test runs
    @@ko_test_counter += 1
    tournament_id = TEST_ID_BASE + 10_000 + (@@ko_test_counter * 200)

    # Create tournament
    tournament = Tournament.create!({
      id: tournament_id,
      title: "Test KO Tournament #{player_count}",
      season: season,
      organizer: region,
      organizer_type: "Region",
      discipline: discipline,
      state: "initialized",
      date: 2.weeks.from_now,
      balls_goal: 30,
      innings_goal: 25,
      tournament_plan: TournamentPlan.ko_plan(player_count)
    }.merge(tournament_attrs))

    # Create players
    players = (1..player_count).map do |i|
      Player.create!(
        id: tournament_id + i,
        firstname: "Test",
        lastname: "Player#{i}",
        ba_id: tournament_id + 1_000_000 + i
      )
    end

    # Create seedings
    seedings = players.each_with_index.map do |player, idx|
      Seeding.create!(
        id: tournament_id + 1000 + idx,
        tournament: tournament,
        player: player,
        position: idx + 1,
        region_id: region.id
      )
    end

    {
      tournament: tournament,
      players: players,
      seedings: seedings
    }
  end

  # Clean up test tournament and related data
  def cleanup_ko_tournament(data)
    return unless data.is_a?(Hash)

    tournament = data[:tournament]
    return unless tournament

    # Reload to get fresh associations
    tournament = Tournament.find_by(id: tournament.id)
    return unless tournament

    # Clean up game_participations first (FK dependency)
    tournament.games.each { |g| g.game_participations.destroy_all }

    # Clean up in correct order (respecting foreign keys)
    tournament.games.destroy_all
    tournament.seedings.destroy_all

    # Destroy tournament_monitor (FK: tournament_monitor -> tournament)
    tournament.reload.tournament_monitor&.destroy

    tournament.destroy

    # Clean up players
    data[:players]&.each { |p| p.destroy if Player.exists?(p.id) }
  end

  # Simulate finishing a game with a winner
  # @param game [Game] The game to finish
  # @param winner_role [String] "playera" or "playerb"
  def finish_game(game, winner_role = "playera")
    loser_role = winner_role == "playera" ? "playerb" : "playera"

    game.update!(data: {
      "results" => {
        winner_role => {
          "balls" => 30,
          "innings" => 20,
          "hs" => 5,
          "gd" => "1.50"
        },
        loser_role => {
          "balls" => 20,
          "innings" => 20,
          "hs" => 4,
          "gd" => "1.00"
        }
      },
      "finished_at" => Time.current.iso8601
    })
  end

  # Assert bracket structure is correct
  def assert_valid_ko_bracket(tournament)
    params = JSON.parse(tournament.tournament_plan.executor_params)
    expected_games = params["GK"]

    assert_equal expected_games, tournament.games.count,
      "Should have #{expected_games} games"

    # Verify all game names are present
    game_names = tournament.games.pluck(:gname).sort
    expected_names = params.keys.reject { |k| k.in?(["GK", "RK"]) }.sort

    assert_equal expected_names, game_names,
      "Game names should match executor_params"
  end

  # Assert first round games have players assigned
  def assert_first_round_has_players(tournament)
    # Determine first round prefix based on actual KO plan structure
    # The plan's first round is the smallest numeric prefix (most players)
    params = JSON.parse(tournament.tournament_plan.executor_params)
    game_keys = params.keys.reject { |k| ["GK", "RK"].include?(k) }

    # Find the first round: games that reference seeding list (sl.rk<n>)
    first_round_games = tournament.games.select do |game|
      game_params = params[game.gname]
      next false unless game_params.is_a?(Hash)
      # First round games reference sl.rk entries
      game_params.values.any? do |round_data|
        next false unless round_data.is_a?(Hash)
        round_data.values.any? do |refs|
          refs.is_a?(Array) && refs.any? { |r| r.to_s.start_with?("sl.") }
        end
      end
    end

    first_round_games.each do |game|
      participations = game.game_participations.where.not(player_id: nil)
      assert_equal 2, participations.count,
        "#{game.gname} should have 2 players assigned"
    end
  end

  # Verify player reference resolution
  # ko_ranking is private so we use send to test it
  def assert_player_reference_resolves(tournament_monitor, reference, expected_player_id)
    actual_player_id = tournament_monitor.send(:ko_ranking, reference)
    assert_equal expected_player_id, actual_player_id,
      "#{reference} should resolve to player #{expected_player_id}"
  end
end
