# frozen_string_literal: true

require "test_helper"

# Tests for League::StandingsCalculator PORO service.
# Verifies that the service returns identical results to the original League model methods.
class League::StandingsCalculatorTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 70_000

  @@counter = 0

  def next_base
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def create_league_with_teams(discipline_fixture:)
    base = next_base
    league = League.create!(
      id: base,
      name: "SC Test #{base}",
      shortname: "SC#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(discipline_fixture)
    )
    team_a = LeagueTeam.create!(id: base + 1, league: league, name: "TeamA_#{base}", cc_id: base + 10)
    team_b = LeagueTeam.create!(id: base + 2, league: league, name: "TeamB_#{base}", cc_id: base + 11)
    { league: league, team_a: team_a, team_b: team_b }
  end

  def add_party(league:, team_a:, team_b:, result:)
    base = next_base
    Party.create!(
      id: base,
      league: league,
      league_team_a: team_a,
      league_team_b: team_b,
      data: { "result" => result }
    )
  end

  # --- League::StandingsCalculator.new(league).karambol ---

  test "karambol returns an Array" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "3:1")

    result = League::StandingsCalculator.new(league).karambol

    assert_instance_of Array, result
  end

  test "karambol returns rows with platz key" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "3:1")

    result = League::StandingsCalculator.new(league).karambol

    result.each { |row| assert row.key?(:platz), "Expected :platz key in row" }
    assert_equal 1, result.first[:platz]
  end

  test "karambol ranks winning team first" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "3:1")

    result = League::StandingsCalculator.new(league).karambol

    assert_equal 2, result.size
    assert_equal setup[:team_a].id, result.first[:team].id
    assert result.first[:punkte] > result.last[:punkte]
  end

  test "karambol returns same result as league#standings_table_karambol" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "2:1")

    via_service = League::StandingsCalculator.new(league).karambol
    via_model = league.standings_table_karambol

    assert_equal via_model.map { |r| r.except(:team) }, via_service.map { |r| r.except(:team) }
  end

  # --- League::StandingsCalculator.new(league).snooker ---

  test "snooker returns an Array" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "4:2")

    result = League::StandingsCalculator.new(league).snooker

    assert_instance_of Array, result
  end

  test "snooker returns rows with :frames key" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "3:1")

    result = League::StandingsCalculator.new(league).snooker

    result.each { |row| assert row.key?(:frames), "Expected :frames key in snooker row" }
  end

  test "snooker returns same result as league#standings_table_snooker" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "4:2")

    via_service = League::StandingsCalculator.new(league).snooker
    via_model = league.standings_table_snooker

    assert_equal via_model.map { |r| r.except(:team) }, via_service.map { |r| r.except(:team) }
  end

  # --- League::StandingsCalculator.new(league).pool ---

  test "pool returns an Array" do
    setup = create_league_with_teams(discipline_fixture: :pool_8ball)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "5:3")

    result = League::StandingsCalculator.new(league).pool

    assert_instance_of Array, result
  end

  test "pool returns rows with :partien key" do
    setup = create_league_with_teams(discipline_fixture: :pool_8ball)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "5:2")

    result = League::StandingsCalculator.new(league).pool

    result.each { |row| assert row.key?(:partien), "Expected :partien key in pool row" }
  end

  test "pool returns same result as league#standings_table_pool" do
    setup = create_league_with_teams(discipline_fixture: :pool_8ball)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "5:3")

    via_service = League::StandingsCalculator.new(league).pool
    via_model = league.standings_table_pool

    assert_equal via_model.map { |r| r.except(:team) }, via_service.map { |r| r.except(:team) }
  end

  # --- League::StandingsCalculator.new(league).schedule_by_rounds ---

  test "schedule_by_rounds returns a Hash" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]

    result = League::StandingsCalculator.new(league).schedule_by_rounds

    assert_instance_of Hash, result
  end

  test "schedule_by_rounds returns same result as league#schedule_by_rounds" do
    setup = create_league_with_teams(discipline_fixture: :carom_3band)
    league = setup[:league]
    add_party(league: league, team_a: setup[:team_a], team_b: setup[:team_b], result: "3:1")

    via_service = League::StandingsCalculator.new(league).schedule_by_rounds
    via_model = league.schedule_by_rounds

    assert_equal via_model.keys, via_service.keys
    assert_equal via_model.values.map(&:size), via_service.values.map(&:size)
  end
end
