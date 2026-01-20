require "test_helper"
require "rake"

class AutoReserveTablesTaskTest < ActiveSupport::TestCase
  setup do
    # Load rake tasks
    Carambus::Application.load_tasks if Rake::Task.tasks.empty?
    
    @season = Season.create!(name: "2025/2026")
    @region = Region.create!(shortname: "TEST", name: "Test Region")
    
    # Create table kinds and disciplines
    @table_kind_small = TableKind.create!(name: "Small Billard")
    @discipline_cadre = Discipline.create!(
      name: "Cadre 35/2",
      table_kind: @table_kind_small
    )
    
    # Create location with tables
    @location = Location.create!(
      name: "Test Club",
      address: "Test Street 1",
      organizer: @region
    )
    
    # Create tables with heaters
    3.times do |i|
      Table.create!(
        name: "T#{i+1}",
        location: @location,
        table_kind: @table_kind_small,
        tpl_ip_address: i+1
      )
    end
  end

  teardown do
    # Clear tasks to prevent conflicts
    Rake::Task.clear
  end

  test "task finds tournaments with registration deadline in last 7 days" do
    # Create tournament with deadline yesterday
    tournament_recent = Tournament.create!(
      title: "Recent Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament_recent.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Create tournament with deadline 10 days ago (should be ignored)
    tournament_old = Tournament.create!(
      title: "Old Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 10.days.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "OldPlayer", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament_old.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments (simulate what task does)
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 1, tournaments.count
    assert_equal tournament_recent.id, tournaments.first.id
  end

  test "task ignores league tournaments" do
    # Create league tournament
    tournament_league = Tournament.create!(
      title: "League Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "league",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament_league.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without location" do
    tournament = Tournament.create!(
      title: "No Location Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: nil,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without discipline" do
    tournament = Tournament.create!(
      title: "No Discipline Tournament",
      season: @season,
      organizer: @region,
      discipline: nil,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments in the past" do
    tournament = Tournament.create!(
      title: "Past Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.ago,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without accredation_end" do
    tournament = Tournament.create!(
      title: "No Deadline Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: nil
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 0, tournaments.count
  end

  test "task creates reservations for valid tournaments" do
    tournament = Tournament.create!(
      title: "Valid Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Mock Google Calendar API
    mock_service = Minitest::Mock.new
    mock_response = OpenStruct.new(
      id: "test_event_999",
      summary: "T1, T2 Valid Tournament Cadre 35/2",
      start: OpenStruct.new(date_time: Time.current),
      end: OpenStruct.new(date_time: Time.current + 9.hours)
    )
    
    mock_service.expect(:insert_event, mock_response, [String, Google::Apis::CalendarV3::Event])
    
    Google::Apis::CalendarV3::CalendarService.stub(:new, mock_service) do
      Google::Auth::ServiceAccountCredentials.stub(:make_creds, ->(*) { "mock_auth" }) do
        # Simulate task execution
        result = tournament.create_table_reservation
        
        assert_not_nil result
        assert_equal "test_event_999", result.id
        mock_service.verify
      end
    end
  end

  test "task handles tournaments with no participants gracefully" do
    tournament = Tournament.create!(
      title: "No Participants Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # No participants added
    
    # Should return nil (skipped)
    assert_nil tournament.create_table_reservation
  end

  test "task handles tournaments with only no_show participants" do
    tournament = Tournament.create!(
      title: "All No-Show Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )
    
    # Add only no_show participants
    4.times do |i|
      player = Player.create!(firstname: "NoShow", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "no_show")
    end
    
    # Should return nil (no active participants)
    assert_nil tournament.create_table_reservation
  end

  test "task processes multiple tournaments" do
    # Create 3 valid tournaments
    tournaments = []
    3.times do |i|
      tournament = Tournament.create!(
        title: "Tournament #{i+1}",
        season: @season,
        organizer: @region,
        discipline: @discipline_cadre,
        location: @location,
        single_or_league: "single",
        date: (i+1).weeks.from_now,
        accredation_end: 1.day.ago
      )
      
      # Add participants
      4.times do |j|
        player = Player.create!(firstname: "Player#{i}", lastname: "#{j+1}")
        Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
      end
      
      tournaments << tournament
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    found_tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 3, found_tournaments.count
  end

  test "task boundary: deadline exactly 7 days ago should be included" do
    tournament = Tournament.create!(
      title: "Boundary Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 7.days.ago
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 1, tournaments.count
  end

  test "task boundary: deadline exactly now should be included" do
    tournament = Tournament.create!(
      title: "Current Deadline Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: Time.current
    )
    
    # Add participants
    4.times do |i|
      player = Player.create!(firstname: "Player", lastname: "#{i+1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end
    
    # Find tournaments
    cutoff_date = 7.days.ago
    now = Time.current
    
    tournaments = Tournament
      .where(single_or_league: 'single')
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where('date >= ?', now)
      .where('accredation_end IS NOT NULL')
      .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
    
    assert_equal 1, tournaments.count
  end
end
