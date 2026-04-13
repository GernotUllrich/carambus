# frozen_string_literal: true

require "application_system_test_case"

# Smoke test: proves end-to-end broadcast delivery for TableMonitor state changes.
#
# Chain verified: AASM state change -> TableMonitorJob.perform_now
#   -> CableReady inner_html -> browser DOM update
#
# This is the foundational proof that Phase 17 infrastructure works:
# ActionCable broadcasts reach real browser WebSocket connections through
# the async adapter, and the client-side CableReady integration updates the DOM.
#
# Phase 18 isolation tests build on this proven foundation.
class TableMonitorBroadcastSmokeTest < ApplicationSystemTestCase
  setup do
    # Build complete fixture chain for get_options! and scoreboard rendering.
    # TableMonitor -> Table (with location + table_kind) must all be linked.
    # tables(:one) already has location: one and table_kind: one after fixture update.
    @table_monitor = table_monitors(:one)

    # Reset to "new" state for the ready! transition (per D-06).
    # Use update_columns to bypass callbacks and AASM guards.
    # data column is serialized as JSON Hash — pass SQL JSON literal via Arel.
    @table_monitor.update_columns(state: "new", data: {})

    # Create a minimal Game so the show action renders the scoreboard
    # rather than redirecting to the location page (show redirects when
    # both game_id and prev_game_id are blank — see TableMonitorsController#show).
    # Use find_or_create_by because system tests do not wrap in transactions —
    # the game may already exist from a previous run.
    @game = Game.find_or_create_by!(id: 50_000_100)
    @table_monitor.update_columns(game_id: @game.id)
  end

  teardown do
    # System tests do not use transactional rollback, so we clean up manually.
    # This prevents the smoke-test game (id: 50_000_100) from persisting and
    # confusing other tests that use Game.last (e.g., game_setup_test.rb).
    @table_monitor.update_columns(game_id: nil, state: "new", data: {})
    @game&.destroy
  end

  test "AASM state change broadcasts visible DOM update to subscribed browser session" do
    # Visit the scoreboard page — this establishes a WebSocket subscription
    # to the "table-monitor-stream" ActionCable channel (per TableMonitorChannel).
    visit_scoreboard(@table_monitor, locale: :de)

    # Verify the scoreboard page loaded (not redirected to location path).
    assert_selector "#full_screen_table_monitor_#{@table_monitor.id}"

    # Wait for the ActionCable WebSocket subscription to be established before broadcasting.
    # The browser opens a WebSocket after the page loads; subscribing takes a round trip.
    # We poll the JS consumer state via Capybara's synchronize mechanism (no sleep needed).
    wait_for_actioncable_connection

    # Trigger AASM state change: new -> ready (per D-06).
    @table_monitor.reload
    @table_monitor.ready!

    # Force job execution synchronously — test queue adapter does not auto-execute
    # perform_later calls. TableMonitorJob default branch renders the full scoreboard
    # partial and broadcasts inner_html to #full_screen_table_monitor_{id}.
    TableMonitorJob.perform_now(@table_monitor.id)

    # Capybara waits up to default_max_wait_time (10s) for the DOM to update (per D-05).
    # After the ready! transition, state_display(:de) returns "Frei" (config/locales/de.yml).
    # Asserting the text is present within the scoreboard container proves that:
    #   1. The job rendered the partial with the new "ready" state
    #   2. CableReady broadcast the inner_html update over ActionCable
    #   3. The browser WebSocket received and applied the DOM update
    assert_selector "#full_screen_table_monitor_#{@table_monitor.id}", text: /Frei/i
  end
end
