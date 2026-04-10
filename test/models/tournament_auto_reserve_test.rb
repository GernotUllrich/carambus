# frozen_string_literal: true

require "test_helper"

class TournamentAutoReserveTest < ActiveSupport::TestCase
  # IDs must be >= Table::MIN_ID (50_000_000) so tpl_ip_address check works for "local" tables
  TABLE_BASE_ID = 51_000_000
  LOCATION_BASE_ID = 51_000_100
  REGION_BASE_ID = 51_000_200
  DISCIPLINE_BASE_ID = 51_000_300
  TABLE_KIND_BASE_ID = 51_000_400

  setup do
    @season = seasons(:current)
    @region = Region.create!(id: REGION_BASE_ID + 1, shortname: "TEST", name: "Test Region")

    # Create table kinds
    @table_kind_small = TableKind.create!(id: TABLE_KIND_BASE_ID + 1, name: "Small Billard")
    @table_kind_pool = TableKind.create!(id: TABLE_KIND_BASE_ID + 2, name: "Pool")
    @table_kind_match = TableKind.create!(id: TABLE_KIND_BASE_ID + 3, name: "Match Billard")

    # Create disciplines
    @discipline_cadre = Discipline.create!(id: DISCIPLINE_BASE_ID + 1, name: "Cadre 35/2", table_kind: @table_kind_small)
    @discipline_pool = Discipline.create!(id: DISCIPLINE_BASE_ID + 2, name: "8-Ball", table_kind: @table_kind_pool)
    @discipline_dreiband = Discipline.create!(id: DISCIPLINE_BASE_ID + 3, name: "Dreiband groß", table_kind: @table_kind_match)

    # Create location
    @location = Location.create!(id: LOCATION_BASE_ID + 1, name: "Test Club", address: "Test Street 1", organizer: @region)

    # Create tables with heaters — IDs >= MIN_ID so tpl_ip_address is checked directly on table
    @table1 = Table.create!(id: TABLE_BASE_ID + 1, name: "T1", location: @location, table_kind: @table_kind_small, tpl_ip_address: 1)
    @table2 = Table.create!(id: TABLE_BASE_ID + 2, name: "T2", location: @location, table_kind: @table_kind_small, tpl_ip_address: 2)
    @table3 = Table.create!(id: TABLE_BASE_ID + 3, name: "T3", location: @location, table_kind: @table_kind_small, tpl_ip_address: 3)

    # Table without heater
    @table4_no_heater = Table.create!(id: TABLE_BASE_ID + 4, name: "T4", location: @location, table_kind: @table_kind_small, tpl_ip_address: nil)

    # Pool table
    @table_pool1 = Table.create!(id: TABLE_BASE_ID + 11, name: "P1", location: @location, table_kind: @table_kind_pool, tpl_ip_address: 11)

    # Match Billard tables
    @table_match1 = Table.create!(id: TABLE_BASE_ID + 21, name: "M1", location: @location, table_kind: @table_kind_match, tpl_ip_address: 21)
    @table_match2 = Table.create!(id: TABLE_BASE_ID + 22, name: "M2", location: @location, table_kind: @table_kind_match, tpl_ip_address: 22)

    # Create tournament plan
    @tournament_plan = TournamentPlan.create!(name: "T21", players: 12, tables: 6, ngroups: 3, nrepeats: 1)
  end

  # Helper: stub Tournament::TableReservationService.call to return a fake response,
  # bypassing the Google Calendar credential guard entirely.
  # After extraction, create_table_reservation delegates to the service, so we
  # stub the service's .call class method rather than a private tournament method.
  def stub_calendar_event(tournament, response: nil)
    fake_response = response || OpenStruct.new(id: "test_event_stub", summary: "stubbed")
    Tournament::TableReservationService.stub(:call, ->(_kwargs) { fake_response }) do
      yield
    end
  end

  # ===== Tests for required_tables_count =====

  test "required_tables_count returns 0 when location is missing" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: nil,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_equal 0, tournament.required_tables_count
  end

  test "required_tables_count returns 0 when discipline is missing" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: nil,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_equal 0, tournament.required_tables_count
  end

  test "required_tables_count returns 0 when no participants" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_equal 0, tournament.required_tables_count
  end

  test "required_tables_count uses tournament_plan.tables when available" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      tournament_plan: @tournament_plan
    )

    12.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    assert_equal 6, tournament.required_tables_count
  end

  test "required_tables_count uses fallback calculation when no plan" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    10.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    # Fallback: (10 / 2).ceil = 5
    assert_equal 5, tournament.required_tables_count
  end

  test "required_tables_count excludes no_show participants" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    10.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    2.times do |i|
      player = Player.create!(firstname: "NoShow", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "no_show")
    end

    # Should only count registered: (10 / 2).ceil = 5
    assert_equal 5, tournament.required_tables_count
  end

  test "required_tables_count handles odd number of participants" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    7.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    # Fallback: (7 / 2.0).ceil = 4
    assert_equal 4, tournament.required_tables_count
  end

  # ===== Tests for create_table_reservation guard conditions =====

  test "create_table_reservation returns nil when location missing" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: nil,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_nil tournament.create_table_reservation
  end

  test "create_table_reservation returns nil when discipline missing" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: nil,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_nil tournament.create_table_reservation
  end

  test "create_table_reservation returns nil when date missing" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: nil
    )

    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    assert_nil tournament.create_table_reservation
  end

  test "create_table_reservation returns nil when no participants" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    assert_nil tournament.create_table_reservation
  end

  # ===== Tests for table selection logic (via available_tables_with_heaters) =====

  test "create_table_reservation selects correct table_kind for cadre" do
    tournament = Tournament.create!(
      title: "NDM Cadre 35/2",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    stub_calendar_event(tournament) do
      result = tournament.create_table_reservation
      assert_not_nil result
    end
  end

  test "available_tables_with_heaters excludes tables without heater" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    available = tournament.available_tables_with_heaters
    table_names = available.map(&:name)

    # T4 has no heater (tpl_ip_address: nil) — must be excluded
    refute_includes table_names, "T4"
    # T1, T2, T3 have heaters — must be included
    assert_includes table_names, "T1"
    assert_includes table_names, "T2"
    assert_includes table_names, "T3"
  end

  test "available_tables_with_heaters filters by discipline table_kind" do
    cadre_tournament = Tournament.create!(
      title: "Cadre Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    pool_tournament = Tournament.create!(
      title: "Pool Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_pool,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    match_tournament = Tournament.create!(
      title: "Match Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_dreiband,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    cadre_tables = cadre_tournament.available_tables_with_heaters.map(&:name)
    pool_tables = pool_tournament.available_tables_with_heaters.map(&:name)
    match_tables = match_tournament.available_tables_with_heaters.map(&:name)

    # Cadre: only Small Billard tables
    assert(cadre_tables.all? { |n| n.start_with?("T") })
    assert(cadre_tables.none? { |n| n.start_with?("P") || n.start_with?("M") })

    # Pool: only Pool tables
    assert(pool_tables.all? { |n| n.start_with?("P") })

    # Match: only Match Billard tables
    assert(match_tables.all? { |n| n.start_with?("M") })
  end

  test "create_table_reservation calls calendar and returns response" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      shortname: "TT",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    6.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    fake_response = OpenStruct.new(id: "test_event_125", summary: "T1-T3 TT Cadre 35/2")

    stub_calendar_event(tournament, response: fake_response) do
      result = tournament.create_table_reservation
      assert_not_nil result
      assert_equal "test_event_125", result.id
    end
  end

  test "create_table_reservation handles Google API errors gracefully" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )

    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    # Stub GoogleCalendarService to raise — the rescue inside
    # Tournament::TableReservationService#create_google_calendar_event catches it.
    # Bypass credential guard by stubbing Rails credentials to return a fake key.
    error_service = Object.new
    def error_service.insert_event(*_args)
      raise Google::Apis::Error.new("API Error")
    end

    Rails.application.credentials.stub(:dig, "fake-private-key") do
      GoogleCalendarService.stub(:calendar_service, error_service) do
        GoogleCalendarService.stub(:calendar_id, "test_cal") do
          assert_nil tournament.create_table_reservation
        end
      end
    end
  end
end
