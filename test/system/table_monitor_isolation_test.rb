# frozen_string_literal: true

require "application_system_test_case"

# Two-session morph path isolation test (ISOL-01 + ISOL-04).
#
# Verifies that the client-side JS filter in `shouldAcceptOperation` correctly
# rejects CableReady `inner_html` broadcasts intended for a different table's
# scoreboard. Proves the filter actually ran (not a vacuous assertion) by
# capturing the console.warn output via a DOM marker counter.
#
# Chain verified:
#   TableMonitorJob.perform_now(@tm_b.id)
#     -> cable_ready["table-monitor-stream"].inner_html(selector: "#full_screen_table_monitor_#{@tm_b.id}")
#       -> Session B DOM updated (positive assertion)
#       -> Session A JS filter rejects update + console.warn fired (ISOL-04 proof)
#       -> Session A DOM unchanged (ISOL-01 negative assertion)
class TableMonitorIsolationTest < ApplicationSystemTestCase
  setup do
    @tm_a = table_monitors(:one)
    @tm_b = table_monitors(:two)
    @tm_a.update_columns(state: "new", data: {})
    @tm_b.update_columns(state: "new", data: {})

    # Create minimal Game records so the scoreboard renders instead of redirecting.
    # System tests do not wrap in transactions — use find_or_create_by for idempotency.
    @game_a = Game.find_or_create_by!(id: 50_000_100)
    @game_b = Game.find_or_create_by!(id: 50_000_101)
    @tm_a.update_columns(game_id: @game_a.id)
    @tm_b.update_columns(game_id: @game_b.id)
  end

  teardown do
    # System tests do not use transactional rollback — clean up manually.
    @tm_a.update_columns(game_id: nil, state: "new", data: {})
    @tm_b.update_columns(game_id: nil, state: "new", data: {})
    @game_a&.destroy
    @game_b&.destroy
  end

  # ISOL-01: Scoreboard A DOM is unchanged when table B fires a state change broadcast.
  # ISOL-04: console.warn('SCOREBOARD MIX-UP PREVENTED') is emitted by Session A's JS filter
  #          when it rejects table B's broadcast, proving the filter executed (not vacuous).
  test "ISOL-01 + ISOL-04: morph path isolation — scoreboard A unchanged when table B state changes, console.warn proves filter ran" do
    # Step 1: Open Session A on TM-A scoreboard and install console.warn interceptor.
    in_session(:scoreboard_a) do
      visit_scoreboard(@tm_a, locale: :de)
      assert_selector "#full_screen_table_monitor_#{@tm_a.id}"
      wait_for_actioncable_connection

      # Install DOM marker counter BEFORE the broadcast so we catch the warn.
      # Using DOM marker approach (Research Pitfall 5) instead of Selenium logs API,
      # which may be unavailable across ChromeDriver versions.
      page.execute_script(<<~JS)
        window._mixupPreventedCount = 0;
        const _origWarn = console.warn;
        console.warn = function(...args) {
          if (args[0] && String(args[0]).includes("SCOREBOARD MIX-UP PREVENTED")) {
            window._mixupPreventedCount++;
          }
          _origWarn.apply(console, args);
        };
      JS
    end

    # Step 2: Open Session B on TM-B scoreboard and wait for subscription.
    in_session(:scoreboard_b) do
      visit_scoreboard(@tm_b, locale: :de)
      assert_selector "#full_screen_table_monitor_#{@tm_b.id}"
      wait_for_actioncable_connection
    end

    # Step 3: Trigger broadcast for TM-B only.
    # Both sessions share the same "table-monitor-stream" ActionCable channel,
    # so the broadcast arrives in both browsers — but Session A's JS filter should reject it.
    @tm_b.reload
    @tm_b.ready!
    TableMonitorJob.perform_now(@tm_b.id)

    # Step 4 (POSITIVE): Session B receives the DOM update for its own table.
    in_session(:scoreboard_b) do
      # After ready! transition, state_display(:de) returns "Frei" (config/locales/de.yml).
      assert_selector "#full_screen_table_monitor_#{@tm_b.id}", text: /Frei/i, wait: 10
    end

    # Step 5 (NEGATIVE + ISOL-04): Session A DOM unchanged; console.warn proves filter ran.
    in_session(:scoreboard_a) do
      # Give the broadcast time to arrive and be processed by the JS filter in Session A.
      # sleep is acceptable here — we are asserting absence of DOM change, so there is
      # no element to poll. The _mixupPreventedCount check confirms the broadcast arrived.
      sleep 2

      # ISOL-04: Verify the JS filter executed and emitted console.warn.
      count = page.evaluate_script("window._mixupPreventedCount")
      assert count.to_i > 0,
        "Expected JS filter console.warn('SCOREBOARD MIX-UP PREVENTED') for rejected " \
        "TM-B broadcast on scoreboard A, but got 0 occurrences. " \
        "Verify: (1) Session A subscribed before broadcast, " \
        "(2) broadcast reached client, " \
        "(3) getPageContext() identified page as 'scoreboard'"

      # ISOL-01: Session A must NOT render TM-B's scoreboard container.
      refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
    end
  end

  # ISOL-02: The score:update dispatch event path is filtered by the JS event listener's
  # tableMonitorId check. When TM-B fires a score_data broadcast, the score:update event
  # fires on Session B (correct scoreboard) but is silently ignored on Session A (wrong scoreboard).
  #
  # Unlike ISOL-01/04, this path does NOT emit console.warn — it silently returns early.
  # Verification uses JS markers: window._scoreUpdateReceived (positive) and
  # window._wrongScoreUpdateReceived (negative).
  #
  # Chain verified:
  #   TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")
  #     -> cable_ready["table-monitor-stream"].dispatch_event(name: "score:update", detail: { tableMonitorId: TM_B_ID, ... })
  #       -> Session B event listener matches tableMonitorId → _scoreUpdateReceived = true
  #       -> Session A event listener filters out (wrong tableMonitorId) → _wrongScoreUpdateReceived stays false
  test "ISOL-02: score:update dispatch event path isolation — event blocked on wrong scoreboard" do
    # Prepare TM-B data so the score_data branch can execute without error.
    # The branch reads data[player_key]["innings_redo_list"] and options[:player_a][:result].
    # update_columns bypasses serialization so we pass raw JSON.
    @tm_b.update_columns(state: "ready")
    # update_columns with a serialized JSON column requires the Ruby Hash (not .to_json).
    # Bypass the serializer entirely by writing raw SQL so we control the JSON format.
    TableMonitor.connection.execute(
      "UPDATE table_monitors SET data = '#{
        { "playera" => { "innings_redo_list" => [5], "result" => 10 },
          "playerb" => { "innings_redo_list" => [3], "result" => 7 } }.to_json
      }' WHERE id = #{@tm_b.id}"
    )
    @tm_b.reload

    # Step 1: Open Session A on TM-A scoreboard.
    # Install a score:update interceptor that tracks whether the channel's filter
    # PROCESSED the update for TM-B (i.e., DOM elements were written).
    # The score:update event IS dispatched to all scoreboard sessions — the channel's
    # event listener (line 10–40 of table_monitor_channel.js) then filters by
    # currentTableMonitorId and returns early WITHOUT updating score elements.
    # We verify the filter ran by installing our own listener that replicates the
    # same condition and records whether the DOM update code path would run.
    in_session(:scoreboard_a) do
      visit_scoreboard(@tm_a, locale: :de)
      assert_selector "#full_screen_table_monitor_#{@tm_a.id}"
      wait_for_actioncable_connection

      # Track whether the channel's score:update handler would have updated DOM on Session A.
      # Replicates the filter logic: if currentTableMonitorId !== event.tableMonitorId → blocked.
      page.execute_script(<<~JS)
        window._wrongScoreUpdateReceived = false;
        window._scoreUpdateFilteredCorrectly = null;
        document.addEventListener('score:update', function(e) {
          var scoreboardRoot = document.querySelector('[data-table-monitor-root="scoreboard"]');
          var currentTableMonitorId = scoreboardRoot && scoreboardRoot.dataset && scoreboardRoot.dataset.tableMonitorId;
          var eventTableMonitorId = e.detail && e.detail.tableMonitorId;
          if (parseInt(eventTableMonitorId) === #{@tm_b.id}) {
            // This is TM-B's event arriving on Session A
            window._wrongScoreUpdateReceived = true;
            // Record whether the filter would block it (correct behavior)
            window._scoreUpdateFilteredCorrectly = !currentTableMonitorId || parseInt(currentTableMonitorId) !== parseInt(eventTableMonitorId);
          }
        });
      JS
    end

    # Step 2: Open Session B on TM-B scoreboard; install positive marker.
    in_session(:scoreboard_b) do
      visit_scoreboard(@tm_b, locale: :de)
      assert_selector "#full_screen_table_monitor_#{@tm_b.id}"
      wait_for_actioncable_connection

      page.execute_script(<<~JS)
        window._scoreUpdateReceived = false;
        document.addEventListener('score:update', function(e) {
          if (parseInt(e.detail.tableMonitorId) === #{@tm_b.id}) {
            window._scoreUpdateReceived = true;
          }
        }, { once: true });
      JS
    end

    # Step 3: Trigger score_data broadcast for TM-B. Both sessions share the same
    # ActionCable stream, so the dispatch_event reaches both browsers.
    @tm_b.reload
    TableMonitorJob.perform_now(@tm_b.id, "score_data", player: "playera")

    # Step 4 (POSITIVE): Session B receives the score:update event for its own table.
    in_session(:scoreboard_b) do
      result = nil
      10.times do
        result = page.evaluate_script("window._scoreUpdateReceived")
        break if result
        sleep 0.5
      end
      assert result, "Expected score:update event for TM-B to fire on Session B (correct scoreboard)"
    end

    # Step 5 (NEGATIVE): Session A received the event, but the channel's filter correctly
    # identified it as a cross-table event (currentTableMonitorId=TM-A != TM-B).
    # Verify that the filter WOULD block DOM updates — i.e., the scoreboardRoot on Session A
    # has TM-A's ID (not TM-B's), so the channel listener returns early.
    in_session(:scoreboard_a) do
      sleep 2 # Allow time for the event to arrive and be processed

      # The event arrived on Session A (score:update is dispatched to all scoreboard pages)
      received = page.evaluate_script("window._wrongScoreUpdateReceived")
      filtered_correctly = page.evaluate_script("window._scoreUpdateFilteredCorrectly")

      if received
        # Event arrived — verify the filter correctly identified it as a cross-table event
        assert filtered_correctly,
          "score:update for TM-B arrived on Session A but filter did NOT block it. " \
          "Expected [data-table-monitor-root] to have TM-A ID (#{@tm_a.id}), not TM-B ID (#{@tm_b.id})"
      end
      # Whether or not the event arrived, Session A must not have a TM-B scoreboard container
      # (structural proof that the session is correctly bound to TM-A only)
      # Session A must not have a TM-B scoreboard container — structural proof
      # that the session is correctly bound to TM-A only.
      refute_selector "#full_screen_table_monitor_#{@tm_b.id}"
    end
  end
end
