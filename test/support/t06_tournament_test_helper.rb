# frozen_string_literal: true

# Helper module for creating T06 (with finals round "mit Finalrunde") tournament
# test data. Uses production-exported fixture plan per D-03 to ensure tests
# exercise the same executor_params structure as production.
module T06TournamentTestHelper
  # Base ID for test data to avoid conflicts with production or other helper data.
  # KoTournamentTestHelper uses TEST_ID_BASE + 10_000;
  # T04TournamentTestHelper uses TEST_ID_BASE + 20_000;
  # We use 30_000.
  TEST_ID_BASE = 50_000_000

  # Counter for unique IDs within a test run (class-level, persists across tests)
  @@t06_test_counter = 0

  # Create a complete T06 test tournament with seedings.
  # The T06 fixture plan (tournament_plans(:t06_6)) has exactly 6 players —
  # 2 groups of 3, with semifinals and finals endgame keys.
  #
  # @param tournament_attrs [Hash] Additional tournament attributes to merge
  # @return [Hash] { tournament:, players:, seedings: }
  def create_t06_tournament_with_seedings(tournament_attrs = {})
    discipline = disciplines(:carom_3band)
    season     = seasons(:current)
    region     = regions(:nbv)

    @@t06_test_counter += 1
    tournament_id = TEST_ID_BASE + 30_000 + (@@t06_test_counter * 200)

    # Use production-exported fixture plan per D-03 (NOT inline executor_params construction)
    plan = tournament_plans(:t06_6)

    tournament = Tournament.create!({
      id: tournament_id,
      title: "Test T06 Tournament",
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

    # T06 fixture plan has 6 players (2 groups of 3)
    players = (1..6).map do |i|
      Player.create!(
        id: tournament_id + i,
        firstname: "T06Test",
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
  # @param data [Hash] Return value from create_t06_tournament_with_seedings
  def cleanup_t06_tournament(data)
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
