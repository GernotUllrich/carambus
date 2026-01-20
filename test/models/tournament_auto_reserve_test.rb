require "test_helper"

class TournamentAutoReserveTest < ActiveSupport::TestCase
  setup do
    @season = Season.create!(name: "2025/2026")
    @region = Region.create!(shortname: "TEST", name: "Test Region")
    
    # Create table kinds
    @table_kind_small = TableKind.create!(name: "Small Billard")
    @table_kind_pool = TableKind.create!(name: "Pool")
    @table_kind_match = TableKind.create!(name: "Match Billard")
    
    # Create disciplines
    @discipline_cadre = Discipline.create!(
      name: "Cadre 35/2",
      table_kind: @table_kind_small
    )
    @discipline_pool = Discipline.create!(
      name: "8-Ball",
      table_kind: @table_kind_pool
    )
    @discipline_dreiband = Discipline.create!(
      name: "Dreiband groß",
      table_kind: @table_kind_match
    )
    
    # Create location
    @location = Location.create!(
      name: "Test Club",
      address: "Test Street 1",
      organizer: @region
    )
    
    # Create tables with heaters (tpl_ip_address present)
    @table1 = Table.create!(
      name: "T1",
      location: @location,
      table_kind: @table_kind_small,
      tpl_ip_address: 1
    )
    @table2 = Table.create!(
      name: "T2",
      location: @location,
      table_kind: @table_kind_small,
      tpl_ip_address: 2
    )
    @table3 = Table.create!(
      name: "T3",
      location: @location,
      table_kind: @table_kind_small,
      tpl_ip_address: 3
    )
    
    # Create tables without heaters
    @table4_no_heater = Table.create!(
      name: "T4",
      location: @location,
      table_kind: @table_kind_small,
      tpl_ip_address: nil
    )
    
    # Create pool tables
    @table_pool1 = Table.create!(
      name: "P1",
      location: @location,
      table_kind: @table_kind_pool,
      tpl_ip_address: 11
    )
    
    # Create match billard tables
    @table_match1 = Table.create!(
      name: "M1",
      location: @location,
      table_kind: @table_kind_match,
      tpl_ip_address: 21
    )
    @table_match2 = Table.create!(
      name: "M2",
      location: @location,
      table_kind: @table_kind_match,
      tpl_ip_address: 22
    )
    
    # Create tournament plan
    @tournament_plan = TournamentPlan.create!(
      name: "T21",
      players: 12,
      tables: 6,
      ngroups: 3,
      nrepeats: 1
    )
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
    
    # Add participants
    12.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
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
    
    # Add 10 participants
    10.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
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
    
    # Add 10 registered + 2 no_show
    10.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    2.times do |i|
      player = Player.create!(firstname: "NoShow", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "no_show")
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
    
    # Add 7 participants
    7.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Fallback: (7 / 2.0).ceil = 4
    assert_equal 4, tournament.required_tables_count
  end

  # ===== Tests for create_table_reservation =====
  
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
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
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
  
  test "create_table_reservation selects correct table_kind" do
    # Create tournament with Cadre discipline (Small Billard)
    tournament = Tournament.create!(
      title: "NDM Cadre 35/2",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_123",
      summary: "T1, T2 NDM Cadre 35/2",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      # Verify that only Small Billard tables are in the summary
      assert_match(/T1/, event.summary) || assert_match(/T2/, event.summary) || assert_match(/T3/, event.summary)
      # Pool table should NOT be included
      refute_match(/P1/, event.summary)
      # Match tables should NOT be included
      refute_match(/M1|M2/, event.summary)
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        # Verify mock was called
        mock_service.verify
      end
    end
  end
  
  test "create_table_reservation only selects tables with heaters" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )
    
    # Add participants requiring 2 tables
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_124",
      summary: "T1, T2 Test Tournament",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      # Should NOT include T4 (no heater)
      refute_match(/T4/, event.summary)
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        mock_service.verify
      end
    end
  end
  
  test "create_table_reservation formats consecutive tables as range" do
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
    
    # Add participants requiring 3 consecutive tables
    6.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_125",
      summary: "T1-T3 TT Cadre 35/2",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      # Should use range format for consecutive tables
      assert_match(/T1-T3/, event.summary)
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        mock_service.verify
      end
    end
  end
  
  test "create_table_reservation uses starting_at from tournament_cc" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: Date.new(2026, 3, 15)
    )
    
    # Create tournament_cc with custom starting time
    tournament_cc = TournamentCc.create!(
      tournament: tournament,
      starting_at: Time.parse("14:00")
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_126",
      summary: "T1, T2 Test Tournament",
      start: OpenStruct.new(date_time: Time.utc(2026, 3, 15, 13, 0)),
      end: OpenStruct.new(date_time: Time.utc(2026, 3, 15, 19, 0))
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      start_time = Time.parse(event.start[:date_time])
      # Should be 14:00 local time = 13:00 UTC (CET)
      assert_equal 13, start_time.hour
      assert_equal 0, start_time.min
      
      # End should be 20:00 local = 19:00 UTC
      end_time = Time.parse(event.end[:date_time])
      assert_equal 19, end_time.hour
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        mock_service.verify
      end
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
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API to raise error
    mock_service = Minitest::Mock.new
    mock_service.expect(:insert_event, nil) do
      raise Google::Apis::Error.new("API Error")
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        # Should return nil instead of raising
        assert_nil tournament.create_table_reservation
      end
    end
  end

  # ===== Integration tests with different disciplines =====
  
  test "Match Billard tournament selects Match Billard tables" do
    tournament = Tournament.create!(
      title: "NDM Dreiband groß",
      season: @season,
      organizer: @region,
      discipline: @discipline_dreiband,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_127",
      summary: "M1, M2 NDM Dreiband groß",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      # Should include Match tables
      assert_match(/M1|M2/, event.summary)
      # Should NOT include Small Billard tables
      refute_match(/T1|T2|T3/, event.summary)
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        mock_service.verify
      end
    end
  end
  
  test "Pool tournament selects Pool tables" do
    tournament = Tournament.create!(
      title: "8-Ball Meisterschaft",
      season: @season,
      organizer: @region,
      discipline: @discipline_pool,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament: tournament, player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_128",
      summary: "P1 8-Ball Meisterschaft",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response) do |calendar_id, event|
      # Should include Pool table
      assert_match(/P1/, event.summary)
      # Should NOT include other table types
      refute_match(/T1|T2|T3|M1|M2/, event.summary)
      true
    end
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        result = tournament.create_table_reservation
        mock_service.verify
      end
    end
  end
end
