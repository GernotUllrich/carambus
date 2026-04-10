# frozen_string_literal: true

require "test_helper"
require "rake"

class AutoReserveTablesTaskTest < ActiveSupport::TestCase
  # IDs >= Table::MIN_ID (50_000_000) so tpl_ip_address is read directly from table
  TABLE_BASE_ID = 52_000_000
  LOCATION_BASE_ID = 52_000_100
  REGION_BASE_ID = 52_000_200
  DISCIPLINE_BASE_ID = 52_000_300
  TABLE_KIND_BASE_ID = 52_000_400

  setup do
    # Load rake tasks
    Rails.application.load_tasks if Rake::Task.tasks.empty?

    @season = seasons(:current)
    @region = Region.create!(id: REGION_BASE_ID + 1, shortname: "TASK", name: "Task Test Region")

    # Create table kinds and disciplines
    @table_kind_small = TableKind.create!(id: TABLE_KIND_BASE_ID + 1, name: "Small Billard Task")
    @discipline_cadre = Discipline.create!(id: DISCIPLINE_BASE_ID + 1, name: "Cadre 35/2 Task", table_kind: @table_kind_small)

    # Create location with tables — IDs >= MIN_ID
    @location = Location.create!(id: LOCATION_BASE_ID + 1, name: "Task Test Club", address: "Task Street 1", organizer: @region)

    3.times do |i|
      Table.create!(
        id: TABLE_BASE_ID + i + 1,
        name: "T#{i + 1}",
        location: @location,
        table_kind: @table_kind_small,
        tpl_ip_address: i + 1
      )
    end
  end

  teardown do
    # Clear tasks to prevent conflicts
    Rake::Task.clear
  end

  # Helper: stub Tournament::TableReservationService.call to return a fake response,
  # bypassing the Google Calendar credential guard entirely.
  # After extraction, create_table_reservation delegates to the service.
  def stub_calendar_event(tournament, response: nil)
    fake_response = response || OpenStruct.new(id: "test_event_stub", summary: "stubbed")
    Tournament::TableReservationService.stub(:call, ->(_kwargs) { fake_response }) do
      yield
    end
  end

  test "task finds tournaments with registration deadline in last 7 days" do
    freeze_time = Time.current

    travel_to freeze_time do
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
        player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
        Seeding.create!(tournament_id: tournament_recent.id, tournament_type: "Tournament", player: player, state: "registered")
      end

      # Create tournament with deadline 10 days ago (should be ignored)
      Tournament.create!(
        title: "Old Tournament",
        season: @season,
        organizer: @region,
        discipline: @discipline_cadre,
        location: @location,
        single_or_league: "single",
        date: 1.week.from_now,
        accredation_end: 10.days.ago
      )

      # Find tournaments (simulate what task does)
      cutoff_date = 7.days.ago
      now = freeze_time

      tournaments = Tournament
        .where(single_or_league: "single")
        .where.not(location_id: nil)
        .where.not(discipline_id: nil)
        .where("date >= ?", now)
        .where("accredation_end IS NOT NULL")
        .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

      assert_equal 1, tournaments.count
      assert_equal tournament_recent.id, tournaments.first.id
    end
  end

  test "task ignores league tournaments" do
    # Create league tournament
    Tournament.create!(
      title: "League Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "league",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )

    cutoff_date = 7.days.ago
    now = Time.current

    tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without location" do
    Tournament.create!(
      title: "No Location Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: nil,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )

    cutoff_date = 7.days.ago
    now = Time.current

    tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without discipline" do
    Tournament.create!(
      title: "No Discipline Tournament",
      season: @season,
      organizer: @region,
      discipline: nil,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: 1.day.ago
    )

    cutoff_date = 7.days.ago
    now = Time.current

    tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments in the past" do
    Tournament.create!(
      title: "Past Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.ago,
      accredation_end: 1.day.ago
    )

    cutoff_date = 7.days.ago
    now = Time.current

    tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

    assert_equal 0, tournaments.count
  end

  test "task ignores tournaments without accredation_end" do
    Tournament.create!(
      title: "No Deadline Tournament",
      season: @season,
      organizer: @region,
      discipline: @discipline_cadre,
      location: @location,
      single_or_league: "single",
      date: 1.week.from_now,
      accredation_end: nil
    )

    cutoff_date = 7.days.ago
    now = Time.current

    tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

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
      player = Player.create!(firstname: "Player", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "registered")
    end

    fake_response = OpenStruct.new(id: "test_event_999", summary: "T1, T2 Valid Tournament Cadre 35/2 Task")

    stub_calendar_event(tournament, response: fake_response) do
      result = tournament.create_table_reservation

      assert_not_nil result
      assert_equal "test_event_999", result.id
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

    # No participants added — should return nil (skipped)
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
      player = Player.create!(firstname: "NoShow", lastname: "#{i + 1}")
      Seeding.create!(tournament_id: tournament.id, tournament_type: "Tournament", player: player, state: "no_show")
    end

    # Should return nil (no active participants)
    assert_nil tournament.create_table_reservation
  end

  test "task processes multiple tournaments" do
    # Create 3 valid tournaments
    3.times do |i|
      Tournament.create!(
        title: "Tournament #{i + 1}",
        season: @season,
        organizer: @region,
        discipline: @discipline_cadre,
        location: @location,
        single_or_league: "single",
        date: (i + 1).weeks.from_now,
        accredation_end: 1.day.ago
      )
    end

    cutoff_date = 7.days.ago
    now = Time.current

    found_tournaments = Tournament
      .where(single_or_league: "single")
      .where.not(location_id: nil)
      .where.not(discipline_id: nil)
      .where("date >= ?", now)
      .where("accredation_end IS NOT NULL")
      .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

    assert_equal 3, found_tournaments.count
  end

  test "task boundary: deadline exactly 7 days ago should be included" do
    # Use travel_to to freeze time and avoid millisecond drift
    freeze_time = Time.current

    travel_to freeze_time do
      exactly_7_days_ago = 7.days.ago

      Tournament.create!(
        title: "Boundary Tournament",
        season: @season,
        organizer: @region,
        discipline: @discipline_cadre,
        location: @location,
        single_or_league: "single",
        date: 1.week.from_now,
        accredation_end: exactly_7_days_ago
      )

      cutoff_date = 7.days.ago
      now = freeze_time

      tournaments = Tournament
        .where(single_or_league: "single")
        .where.not(location_id: nil)
        .where.not(discipline_id: nil)
        .where("date >= ?", now)
        .where("accredation_end IS NOT NULL")
        .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

      assert_equal 1, tournaments.count
    end
  end

  test "task boundary: deadline exactly now should be included" do
    freeze_time = Time.current

    travel_to freeze_time do
      Tournament.create!(
        title: "Current Deadline Tournament",
        season: @season,
        organizer: @region,
        discipline: @discipline_cadre,
        location: @location,
        single_or_league: "single",
        date: 1.week.from_now,
        accredation_end: freeze_time
      )

      cutoff_date = 7.days.ago
      now = freeze_time

      tournaments = Tournament
        .where(single_or_league: "single")
        .where.not(location_id: nil)
        .where.not(discipline_id: nil)
        .where("date >= ?", now)
        .where("accredation_end IS NOT NULL")
        .where("accredation_end >= ? AND accredation_end <= ?", cutoff_date, now)

      assert_equal 1, tournaments.count
    end
  end
end
