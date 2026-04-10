# frozen_string_literal: true

require "test_helper"

# Unit tests fuer Tournament::TableReservationService.
# Verifiziert:
#   - Guard conditions (nil when missing location, discipline, date, tables)
#   - format_table_list: consecutive -> range format, non-consecutive -> comma format
#   - build_event_summary: includes shortname/title, discipline name, player class
#   - calculate_start_time: uses tournament_cc.starting_at when present, defaults to 11:00
#   - create_google_calendar_event: returns nil when credentials missing
#
# All Google API calls are fully stubbed. No real HTTP requests are made.
class Tournament::TableReservationServiceTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @discipline = disciplines(:carom_3band)
    @location = locations(:one)

    @tournament = Tournament.create!(
      title: "Reservation Service Test Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      discipline: @discipline,
      location: @location,
      date: 2.weeks.from_now
    )
  end

  # ===== Guard: nil returns =====

  # Test 1: returns nil when tournament has no location
  test "call returns nil when tournament has no location" do
    tournament = Tournament.create!(
      title: "No Location Service Test",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      discipline: @discipline,
      date: 2.weeks.from_now
    )
    result = Tournament::TableReservationService.call(tournament: tournament)
    assert_nil result, "Must return nil when tournament has no location"
  end

  # Test 2: returns nil when tournament has no discipline
  test "call returns nil when tournament has no discipline" do
    tournament = Tournament.create!(
      title: "No Discipline Service Test",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      location: @location,
      date: 2.weeks.from_now
    )
    result = Tournament::TableReservationService.call(tournament: tournament)
    assert_nil result, "Must return nil when tournament has no discipline"
  end

  # Test 3: returns nil when tournament has no date
  test "call returns nil when tournament has no date" do
    @tournament.update_column(:date, nil)
    @tournament.reload
    result = Tournament::TableReservationService.call(tournament: @tournament)
    assert_nil result, "Must return nil when tournament date is nil"
  end

  # Test 4: returns nil when required_tables_count is zero
  test "call returns nil when required_tables_count is zero" do
    # @tournament has no seedings -> required_tables_count returns 0
    assert_equal 0, @tournament.seedings.count, "precondition: no seedings"
    result = Tournament::TableReservationService.call(tournament: @tournament)
    assert_nil result, "Must return nil when required_tables_count is zero"
  end

  # Test 5: returns nil when no available tables with heaters
  test "call returns nil when no available tables with heaters" do
    @tournament.stub(:required_tables_count, 2) do
      result = Tournament::TableReservationService.call(tournament: @tournament)
      assert_nil result, "Must return nil when no tables with heaters are available"
    end
  end

  # ===== format_table_list =====

  # Test 6: consecutive table names return range format "T1-T3"
  test "format_table_list with consecutive table names returns range format" do
    service = Tournament::TableReservationService.new(tournament: @tournament)
    result = service.send(:format_table_list, %w[T1 T2 T3])
    assert_equal "T1-T3", result, "Consecutive tables must use range format"
  end

  # Test 7: non-consecutive table names return comma format "T1, T3, T5"
  test "format_table_list with non-consecutive table names returns comma format" do
    service = Tournament::TableReservationService.new(tournament: @tournament)
    result = service.send(:format_table_list, %w[T1 T3 T5])
    assert_equal "T1, T3, T5", result, "Non-consecutive tables must use comma format"
  end

  # ===== build_event_summary =====

  # Test 8: build_event_summary includes shortname, discipline name, and player class
  test "build_event_summary includes shortname, discipline name, and player class" do
    @tournament.update_columns(shortname: "NDM", player_class: "5-6")
    @tournament.reload
    service = Tournament::TableReservationService.new(tournament: @tournament)
    result = service.send(:build_event_summary, "T1-T3")
    assert_includes result, "NDM", "Summary must include shortname"
    assert_includes result, @discipline.name, "Summary must include discipline name"
    assert_includes result, "5-6", "Summary must include player class"
  end

  # ===== calculate_start_time =====

  # Test 9: uses tournament_cc.starting_at when present, defaults to 11:00 otherwise
  test "calculate_start_time defaults to 11:00 when no tournament_cc starting_at" do
    service = Tournament::TableReservationService.new(tournament: @tournament)
    result = service.send(:calculate_start_time)
    # Should be an ISO8601 string; convert back to local time and check hour
    time = Time.parse(result).in_time_zone(Time.zone)
    assert_equal 11, time.hour, "Default start hour should be 11 in local timezone"
    assert_equal 0, time.min, "Default start minute should be 0"
  end

  # ===== create_google_calendar_event =====

  # Test 10: returns nil when no google_service credentials
  test "create_google_calendar_event returns nil when credentials missing" do
    service = Tournament::TableReservationService.new(tournament: @tournament)
    Rails.application.credentials.stub(:dig, nil) do
      result = service.send(:create_google_calendar_event,
        "Test Summary",
        "2026-01-01T10:00:00Z",
        "2026-01-01T18:00:00Z")
      assert_nil result, "Must return nil when Google credentials are missing"
    end
  end
end
