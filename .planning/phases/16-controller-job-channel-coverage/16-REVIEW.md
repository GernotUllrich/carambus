---
phase: 16-controller-job-channel-coverage
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - test/controllers/tournaments_controller_test.rb
  - test/controllers/tournament_monitors_controller_test.rb
  - test/channels/tournament_channel_test.rb
  - test/channels/tournament_monitor_channel_test.rb
  - test/jobs/tournament_status_update_job_test.rb
  - test/jobs/tournament_monitor_update_results_job_test.rb
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 16: Code Review Report

**Reviewed:** 2026-04-10
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Six new test files covering `TournamentsController`, `TournamentMonitorsController`, `TournamentChannel`, `TournamentMonitorChannel`, `TournamentStatusUpdateJob`, and `TournamentMonitorUpdateResultsJob`. Tests are well-structured, follow project conventions (`frozen_string_literal`, Minitest, fixtures + direct object creation), and correctly exercise the `ensure_local_server` guard pattern throughout.

Three warnings were found: one duplicate test that adds no additional coverage, one missing assertion in a write-path test, and one silent `rescue nil` in teardown that can hide setup failures. Four info items note overly broad status-range assertions, an unused `@original_api_url` capture pattern that is inconsistently applied, a missing `unsubscribed` test for `TournamentChannel`, and a test name that describes the current workaround rather than the intended behavior.

No security or logic bugs were found.

---

## Warnings

### WR-01: Duplicate test — second job test adds no coverage over the first

**File:** `test/jobs/tournament_status_update_job_test.rb:19-25`
**Issue:** The test `"returns early when tournament is not started (registration state)"` exercises the exact same code path as `"returns early when tournament has no tournament_monitor"`. The `tournaments(:local)` fixture has neither a `tournament_monitor` nor a started state, so the job returns at the `tournament_monitor.present?` guard on line 19 of the job — the state check on line 24 is never reached. The second test therefore provides zero additional coverage.
**Fix:** Replace with a test that actually exercises the state guard. Create a monitor, then verify the job returns without broadcasting when the tournament is in `registration` state:

```ruby
test "returns early when tournament has no started state even with monitor present" do
  monitor = TournamentMonitor.create!(
    tournament: @tournament,
    state: "new_tournament_monitor",
    balls_goal: 30, innings_goal: 25, timeout: 0, timeouts: 2
  )
  # tournament is in 'registration' — state guard should fire
  assert_nothing_raised do
    TournamentStatusUpdateJob.perform_now(@tournament)
  end
ensure
  monitor&.destroy
end
```

---

### WR-02: Write-path test does not assert side effect after update

**File:** `test/controllers/tournament_monitors_controller_test.rb:72-82`
**Issue:** `"should update tournament_monitor"` asserts `assert_redirected_to tournament_monitor_url(@tournament_monitor)` but never calls `@tournament_monitor.reload` and asserts the new attribute value. A regression where the controller redirects without saving would pass this test undetected.
**Fix:** Add a reload + attribute assertion after the redirect check:

```ruby
test "should update tournament_monitor" do
  patch tournament_monitor_url(@tournament_monitor), params: {
    tournament_monitor: {
      balls_goal: 35,
      innings_goal: 30,
      timeout: 0,
      timeouts: 2
    }
  }
  assert_redirected_to tournament_monitor_url(@tournament_monitor)
  @tournament_monitor.reload
  assert_equal 35, @tournament_monitor.balls_goal
  assert_equal 30, @tournament_monitor.innings_goal
end
```

---

### WR-03: Silent `rescue nil` in teardown masks setup failures

**File:** `test/controllers/tournament_monitors_controller_test.rb:25`
**Issue:** `@tournament_monitor&.destroy rescue nil` swallows any exception during teardown. If `destroy` raises (e.g. a foreign-key constraint, or the record was corrupted by the test), the error is silently discarded and subsequent tests may share polluted state or receive misleading failures.
**Fix:** Either let it raise (preferred — failures should be visible) or rescue only the specific expected case:

```ruby
teardown do
  Carambus.config.carambus_api_url = @original_api_url
  @tournament_monitor&.destroy
end
```

If the `"should destroy tournament_monitor"` test sets `@tournament_monitor = nil`, the safe-navigation operator `&.` already handles the nil case without needing a blanket rescue.

---

## Info

### IN-01: Overly broad status assertions obscure real regression signal

**File:** `test/controllers/tournaments_controller_test.rb:56,87,107,169,180,193,205,217,308,323`
**Issue:** Many tests use `assert_includes [200, 302, 500], response.status` with a comment acknowledging 500 as acceptable due to fixture gaps. While the intent (guard coverage, not view coverage) is documented, including 500 in passing criteria means a genuine crash in the action body goes undetected. This pattern appears in ~10 test cases.
**Fix:** This is a known trade-off and the comments explain the rationale well. As the fixture set matures, replace the three-value assertions with either `assert_response :success` or `assert_redirected_to`. Consider tracking these as follow-up items with a `# TODO: tighten to :success once fixtures cover view dependencies` comment to distinguish intentional leniency from permanent acceptance.

---

### IN-02: `TournamentChannel` — `unsubscribed` callback has no test

**File:** `test/channels/tournament_channel_test.rb`
**Issue:** `TournamentChannel#unsubscribed` is a no-op now, but the channel has no test for it. If cleanup logic is added later, the test file provides no safety net to catch regressions. `TournamentMonitorChannel` has the same gap but that channel also has no cleanup logic.
**Fix:** Add a minimal smoke test:

```ruby
test "unsubscribes without error" do
  subscribe(tournament_id: 42)
  assert_nothing_raised { unsubscribe }
end
```

---

### IN-03: `TournamentMonitorUpdateResultsJob` — only the guard path is tested, not the happy path

**File:** `test/jobs/tournament_monitor_update_results_job_test.rb`
**Issue:** Both tests verify the early-return guard (`local_server? == false`). The job's main body — rendering two partials and broadcasting via CableReady — is not exercised at all. A broken partial path, typo in a CSS selector, or nil `tournament_monitor` passed to the partials will not be caught by tests.
**Fix:** Add a test that stubs `local_server?` to `true` and passes a real `TournamentMonitor` instance, asserting `assert_nothing_raised`. Rendering the partials in test environment requires a monitor with associated data, so even a smoke test with `assert_nothing_raised` raises the bar significantly over no coverage:

```ruby
test "broadcasts without error on local server with valid monitor" do
  monitor = TournamentMonitor.create!(
    tournament: tournaments(:local),
    state: "new_tournament_monitor",
    balls_goal: 30, innings_goal: 25, timeout: 0, timeouts: 2
  )
  Carambus.config.carambus_api_url = "http://local.test"
  assert_nothing_raised do
    TournamentMonitorUpdateResultsJob.perform_now(monitor)
  end
ensure
  monitor&.destroy
end
```

---

### IN-04: Test name describes workaround, not the intended contract

**File:** `test/controllers/tournaments_controller_test.rb:382-398`
**Issue:** The test `"POST reload_from_cc on API server scrapes CC and redirects to tournament"` has a body comment `# WebMock blocks network` and asserts `[200, 302, 500]`. The test name says "scrapes CC and redirects" but the test does not actually verify that behavior — it only verifies that the guard does not fire. The mismatch between the name and the assertion makes it hard to trust the test suite at a glance.
**Fix:** Rename to reflect what is actually being verified:

```ruby
test "POST reload_from_cc is not guarded by ensure_local_server on API server" do
```

---

_Reviewed: 2026-04-10_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
