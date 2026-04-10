# frozen_string_literal: true

require "test_helper"

# Characterization tests for Tournament's Google Calendar reservation cluster.
#
# Pins the exact behavior of:
#   - create_table_reservation (public) — guard conditions
#   - create_google_calendar_event (private) — credential guard, API integration, error handling
#   - End-to-end wiring: create_table_reservation -> create_google_calendar_event
#
# All Google API calls are fully stubbed. No real HTTP requests are made.
# WebMock will block any unexpected external HTTP interactions.
class TournamentCalendarTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    # Base local tournament: has discipline and location, used by most tests
    @discipline = disciplines(:carom_3band)
    @location = locations(:one)

    # A fresh local tournament with location and discipline but no seedings
    @tournament = Tournament.create!(
      title: "Calendar Test Tournament",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      discipline: @discipline,
      location: @location,
      date: 2.weeks.from_now
    )
  end

  # ===== Guard Conditions in create_table_reservation =====

  # Baseline: create_table_reservation returns nil when location is missing.
  # Guard: return nil unless location.present? && discipline.present? && date.present?
  test "create_table_reservation returns nil when location is missing" do
    tournament = Tournament.create!(
      title: "No Location",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      discipline: @discipline,
      date: 2.weeks.from_now
    )
    result = tournament.create_table_reservation
    assert_nil result, "Baseline: no location -> nil. Must return nil without calling GoogleCalendarService."
  end

  # Baseline: create_table_reservation returns nil when discipline is missing.
  test "create_table_reservation returns nil when discipline is missing" do
    tournament = Tournament.create!(
      title: "No Discipline",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      location: @location,
      date: 2.weeks.from_now
    )
    result = tournament.create_table_reservation
    assert_nil result, "Baseline: no discipline -> nil. Must return nil without calling GoogleCalendarService."
  end

  # Baseline: create_table_reservation returns nil when date is missing (nil).
  # Note: Tournament before_save sets date to Time.at(0) when blank, so we need date: nil
  # and bypass before_save via update_column to ensure a truly nil date.
  test "create_table_reservation returns nil when date is nil" do
    @tournament.update_column(:date, nil)
    @tournament.reload
    result = @tournament.create_table_reservation
    assert_nil result, "Baseline: nil date -> nil. Must return nil without calling GoogleCalendarService."
  end

  # Baseline: create_table_reservation returns nil when required_tables_count is zero.
  # required_tables_count returns 0 when seedings is empty (no participants).
  test "create_table_reservation returns nil when required_tables_count is zero (no seedings)" do
    # @tournament has no seedings, so required_tables_count returns 0
    assert_equal 0, @tournament.seedings.count, "precondition: no seedings"
    result = @tournament.create_table_reservation
    assert_nil result, "Baseline: zero required tables -> nil. Must return nil before checking available tables."
  end

  # Baseline: create_table_reservation returns nil when no tables with heaters are available.
  # available_tables_with_heaters filters by tpl_ip_address presence and table_kind.
  # The location fixture's tables have no tpl_ip_address set.
  test "create_table_reservation returns nil when no available tables with heaters" do
    # Stub required_tables_count to return non-zero (bypassing seedings lookup)
    # so we isolate the available_tables_with_heaters guard.
    @tournament.stub(:required_tables_count, 2) do
      # available_tables_with_heaters finds no tables because:
      # - The location fixtures have no tables with matching table_kind_id
      # - No tpl_ip_address is set on any table linked to this location
      result = @tournament.create_table_reservation
      assert_nil result, "Baseline: no available tables with heaters -> nil."
    end
  end

  # ===== create_google_calendar_event guard and integration =====

  # Baseline: create_google_calendar_event returns nil when Google credentials are missing.
  # Guard: return nil unless Rails.application.credentials.dig(:google_service, :private_key).present?
  test "create_google_calendar_event returns nil when credentials missing" do
    # Stub credentials to return nil for the private_key path
    Rails.application.credentials.stub(:dig, nil) do
      result = @tournament.send(:create_google_calendar_event,
        "Test Summary",
        "2026-01-01T10:00:00Z",
        "2026-01-01T18:00:00Z")
      assert_nil result, "Baseline: missing credentials -> nil. Must not attempt Google API call."
    end
  end

  # Baseline: create_google_calendar_event calls GoogleCalendarService with correct parameters.
  # When credentials are present, it must invoke calendar_service.insert_event with
  # the correct calendar_id and an Event object with the right summary.
  test "create_google_calendar_event calls GoogleCalendarService.calendar_service when credentials present" do
    fake_key = "fake-private-key"
    mock_response = OpenStruct.new(id: "test-event-id-123")
    inserted_args = []

    mock_service = Object.new
    mock_service.define_singleton_method(:insert_event) do |calendar_id, event|
      inserted_args << { calendar_id: calendar_id, event: event }
      mock_response
    end

    Rails.application.credentials.stub(:dig, fake_key) do
      GoogleCalendarService.stub(:calendar_service, mock_service) do
        GoogleCalendarService.stub(:calendar_id, "test-calendar-id") do
          result = @tournament.send(:create_google_calendar_event,
            "Test Summary",
            "2026-01-01T10:00:00Z",
            "2026-01-01T18:00:00Z")

          assert_equal mock_response, result,
            "Baseline: successful API call returns the service response."
          assert_equal 1, inserted_args.length, "insert_event must be called exactly once"
          assert_equal "test-calendar-id", inserted_args.first[:calendar_id],
            "Must pass the calendar_id from GoogleCalendarService.calendar_id"
          assert_equal "Test Summary", inserted_args.first[:event].summary,
            "Event object must have the summary passed to create_google_calendar_event"
        end
      end
    end
  end

  # Baseline: create_google_calendar_event rescues StandardError and returns nil.
  # When GoogleCalendarService.calendar_service raises, the method must rescue and return nil.
  test "create_google_calendar_event rescues StandardError and returns nil on failure" do
    fake_key = "fake-private-key"

    Rails.application.credentials.stub(:dig, fake_key) do
      GoogleCalendarService.stub(:calendar_service, ->{ raise StandardError.new("API unavailable") }) do
        result = @tournament.send(:create_google_calendar_event,
          "Test Summary",
          "2026-01-01T10:00:00Z",
          "2026-01-01T18:00:00Z")
        assert_nil result,
          "Baseline: StandardError from GoogleCalendarService -> nil (no exception raised to caller)."
      end
    end
  end

  # ===== End-to-end wiring =====

  # Baseline: create_table_reservation -> create_google_calendar_event wiring.
  # When all preconditions are met (location, discipline, date, seedings, available tables),
  # create_table_reservation must flow through to create_google_calendar_event and return
  # the service response. This pins the full chain from public method to Google API call.
  test "create_table_reservation calls create_google_calendar_event when all preconditions met" do
    fake_key = "fake-private-key"
    mock_response = OpenStruct.new(id: "wiring-test-event-id")

    mock_service = Object.new
    mock_service.define_singleton_method(:insert_event) do |_calendar_id, _event|
      mock_response
    end

    # Stub the internals so we can focus on the wiring:
    # - required_tables_count returns 2 (non-zero, so we pass the zero guard)
    # - available_tables_with_heaters returns a non-empty mock list so we pass the empty guard
    # - create_google_calendar_event is reachable with stubbed credentials + service
    fake_table = OpenStruct.new(name: "T1")
    fake_tables = [fake_table, OpenStruct.new(name: "T2")]

    Rails.application.credentials.stub(:dig, fake_key) do
      GoogleCalendarService.stub(:calendar_service, mock_service) do
        GoogleCalendarService.stub(:calendar_id, "wiring-calendar-id") do
          @tournament.stub(:required_tables_count, 2) do
            @tournament.stub(:available_tables_with_heaters, fake_tables) do
              result = @tournament.create_table_reservation
              assert_equal mock_response, result,
                "Baseline: create_table_reservation -> create_google_calendar_event -> GoogleCalendarService response. " \
                "Full chain must be wired correctly."
            end
          end
        end
      end
    end
  end
end
