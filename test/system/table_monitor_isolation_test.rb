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
end
