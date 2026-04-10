# frozen_string_literal: true

# Helper module for creating T04 (round-robin "jeder gegen jeden") tournament
# test data. Uses production-exported fixture plan per D-03 to ensure tests
# exercise the same executor_params structure as production.
module T04TournamentTestHelper
  # Base ID for test data to avoid conflicts with production or KO helper data.
  # KoTournamentTestHelper uses TEST_ID_BASE + 10_000; we use 20_000.
  TEST_ID_BASE = 50_000_000

  # Counter for unique IDs within a test run (class-level, persists across tests)
  @@t04_test_counter = 0

  # Create a complete T04 test tournament with seedings.
  # The T04 fixture plan (tournament_plans(:t04_5)) has exactly 5 players —
  # caller should pass player_count: 5 to match the fixture plan.
  #
  # @param player_count [Integer] Number of players (should be 5 to match t04_5 fixture)
  # @param tournament_attrs [Hash] Additional tournament attributes to merge
  # @return [Hash] { tournament:, players:, seedings: }
  def create_t04_tournament_with_seedings(player_count, tournament_attrs = {})
    discipline = disciplines(:carom_3band)
    season     = seasons(:current)
    region     = regions(:nbv)

    @@t04_test_counter += 1
    tournament_id = TEST_ID_BASE + 20_000 + (@@t04_test_counter * 200)

    # Use production-exported fixture plan per D-03 (NOT TournamentPlan.default_plan)
    plan = tournament_plans(:t04_5)

    tournament = Tournament.create!({
      id: tournament_id,
      title: "Test T04 Tournament #{player_count}",
      season: season,
      organizer: region,
      organizer_type: "Region",
      discipline: discipline,
      state: "initialized",
      date: 2.weeks.from_now,
      balls_goal: 30,
      innings_goal: 25,
      tournament_plan: plan
    }.merge(tournament_attrs))

    players = (1..player_count).map do |i|
      Player.create!(
        id: tournament_id + i,
        firstname: "T04Test",
        lastname: "Player#{i}",
        ba_id: tournament_id + 1_000_000 + i
      )
    end

    seedings = players.each_with_index.map do |player, idx|
      Seeding.create!(
        id: tournament_id + 1000 + idx,
        tournament: tournament,
        player: player,
        position: idx + 1,
        region_id: region.id
      )
    end

    { tournament: tournament, players: players, seedings: seedings }
  end

  # Clean up test tournament and related data in correct FK order.
  # @param data [Hash] Return value from create_t04_tournament_with_seedings
  def cleanup_t04_tournament(data)
    return unless data.is_a?(Hash)

    tournament = data[:tournament]
    return unless tournament

    # Reload to get fresh associations
    tournament = Tournament.find_by(id: tournament.id)
    return unless tournament

    # Clean up game_participations first (FK dependency)
    tournament.games.each { |g| g.game_participations.destroy_all }

    # Clean up in correct FK order
    tournament.games.destroy_all
    tournament.seedings.destroy_all

    # Destroy tournament_monitor (FK: tournament_monitor -> tournament)
    tournament.reload.tournament_monitor&.destroy

    tournament.destroy

    # Clean up players
    data[:players]&.each { |p| p.destroy if Player.exists?(p.id) }
  end
end
