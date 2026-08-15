---
phase: 23-coverage
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - test/controllers/league_teams_controller_test.rb
  - test/controllers/leagues_controller_test.rb
  - test/controllers/parties_controller_test.rb
  - test/controllers/party_monitors_controller_test.rb
  - test/fixtures/party_monitors.yml
  - test/models/party_monitor_placement_test.rb
  - test/reflexes/party_monitor_reflex_test.rb
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 23: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Seven test files for the Phase 23 coverage work were reviewed. The code is generally
well-structured — fixtures use local IDs correctly, the test helper uses a class-level
counter to avoid ID collisions, and characterization intent is clearly documented.

One critical issue was found in the production controller (surfaced by reading the code
under test): a SQL injection vector in `set_party_monitor_controller.rb`. Four warning-level
issues affect test reliability: over-broad status-code assertions that let real errors pass
silently, a class-level mutable counter that can leak state between test runs, a missing
`teardown` in the reflex test file, and an `update_column` usage that bypasses callbacks.
Three informational items round out the review.

---

## Critical Issues

### CR-01: SQL Injection in `PartyMonitorsController#show` (controller under test)

**File:** `app/controllers/party_monitors_controller.rb:32-33`
**Issue:** Two raw string interpolations of `league_team_a_name` and `league_team_b_name`
are passed directly into `where` clauses without parameterization. These values originate
from `@party.league_team_a.name` and `@party.league_team_b.name` — ActiveRecord model
attributes, which can be user-supplied or attacker-controlled. The test suite exercises
the `show` action and therefore validates this code path.

```ruby
# Current — injectable
replacement_teams_a_ids = LeagueTeam.joins(:league)
  .where(leagues: { season_id: Season.current_season.id })
  .where(club_id: @party.league_team_a.club_id)
  .where("league_teams.name > '#{league_team_a_name}'")   # <-- injection
  .ids - @available_players_a_ids

replacement_teams_b_ids = LeagueTeam.joins(:league)
  .where(leagues: { season_id: Season.current_season.id })
  .where(club_id: @party.league_team_b.club_id)
  .where("league_teams.name > '#{league_team_b_name}'")   # <-- injection
  .ids - @available_players_b_ids
```

**Fix:** Use parameterized queries:
```ruby
.where("league_teams.name > ?", league_team_a_name)
.where("league_teams.name > ?", league_team_b_name)
```

---

## Warnings

### WR-01: Over-broad status-code assertions mask real failures

**File:** `test/controllers/league_teams_controller_test.rb:31,39,44,55`  
**File:** `test/controllers/leagues_controller_test.rb:41,45,55,62`  
**File:** `test/controllers/parties_controller_test.rb:29,33,40,44,52,57`  
**File:** `test/controllers/party_monitors_controller_test.rb:24,38,44,72`

**Issue:** Assertions of the form `assert_includes [200, 500], response.status` and
`assert_includes [200, 302, 500], response.status` allow a 500 response to pass silently.
A 500 is an unhandled exception — accepting it as a "valid" outcome means the tests provide
no signal when a real regression introduces a crash. The comment pattern ("fixture organizer
may lack that method — accept 200 or 500") indicates these are explicitly written as
fault-tolerant, but the consequence is that a broken action will never fail CI.

**Fix:** Where the underlying fixture setup is incomplete, fix the fixture rather than
accepting 500 as a valid result. For actions that genuinely cannot be made deterministic
without major fixture work, at minimum assert `assert_not_equal 404, response.status`
and add a comment documenting the known fixture gap as a separate ticket. Accepting 500
unconditionally should be reserved only for explicitly documented known-broken paths.

---

### WR-02: Class-level `@@pm_counter` leaks state between test runs

**File:** `test/support/party_monitor_test_helper.rb:13-14`

**Issue:** `@@pm_counter` is a class variable initialized with `||=` on first use.
Because Minitest reuses the same Ruby process across test files, this counter is
never reset between test classes. If tests run in a different order (e.g. with
`--seed`) or if the counter overflows its ID allocation window (`30_000 + counter * 100`),
records can collide. With 300 test invocations the counter hits 30,000 and the computed
`base_id` wraps into the next 100-record window.

**Fix:** Use an instance variable initialized in `setup`, or use a thread-safe generator
such as `SecureRandom.random_number(9_999_000) + TEST_ID_BASE`. Alternatively, remove
the fixed-ID pattern and rely on Rails' default auto-increment IDs for local records:

```ruby
def create_party_monitor_with_party(attrs = {})
  league = League.create!(name: "PM Test League", ...)
  # IDs are assigned by DB sequence — no collision risk
end
```

---

### WR-03: `teardown` missing in `PartyMonitorReflexTest` — Player records leak

**File:** `test/reflexes/party_monitor_reflex_test.rb:77-93, 95-113`

**Issue:** The `assign_player` tests create `Player` records with fixed IDs
(`50_000_999`, `50_001_000`) using `ensure` blocks to destroy them, but the
`ensure` cleanup only runs if the test body itself is reached. If an earlier test
raises before the `ensure`, or if the fixtures already contain a player with those IDs,
the `Player.create!` will raise `ActiveRecord::RecordNotInvalid` and the guard block will
not execute. The pattern is fragile; if `use_transactional_tests = true` (the default for
`ActiveSupport::TestCase`) were ever disabled, these records would persist across test runs.

More importantly, the test class does not declare `self.use_transactional_tests = true`
explicitly. `PartyMonitorPlacementTest` does (line 26), but `PartyMonitorReflexTest` does
not. If the default ever changes, the `ensure` cleanup becomes the sole guard.

**Fix:** Add `self.use_transactional_tests = true` explicitly to `PartyMonitorReflexTest`,
matching the pattern in `PartyMonitorPlacementTest`. Remove the `ensure` blocks and rely
on transaction rollback for cleanup (which is cleaner and guaranteed):

```ruby
class PartyMonitorReflexTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  include PartyMonitorTestHelper
  ...
end
```

---

### WR-04: `update_column` bypasses AASM callbacks — tests may not reflect real transitions

**File:** `test/reflexes/party_monitor_reflex_test.rb:35,57,123`

**Issue:** Several tests use `pm.update_column(:state, "ready_for_next_round")` /
`"playing_round"` / `"party_result_checking_mode"` to put the record into a state that
cannot be reached from `seeding_mode` via normal AASM transitions. `update_column` skips
validations, callbacks, and AASM guards. If AASM defines entry/exit callbacks that set
up required data (e.g. initializing `data` keys, updating timestamps), those are not
executed, leaving the record in a partially initialized state that may not match
production behavior.

**Fix:** Where a valid AASM path exists to reach the target state, drive the record
through transitions explicitly:

```ruby
# Instead of:
pm.update_column(:state, "playing_round")

# Prefer (if the AASM machine allows it):
pm.update_column(:state, "ready_for_next_round")
pm.reload
pm.start_round!  # triggers all callbacks and guards
```

Where no valid path exists (characterization of invalid state), document the reason
inline so it is clear this is an intentional bypass.

---

## Info

### IN-01: `party_monitors` fixture `party_id` values reference non-fixture parties

**File:** `test/fixtures/party_monitors.yml:28,35`

**Issue:** Both fixture records use `party_id: 50_000_020` and `50_000_021`, which
correspond to `party_one` and `party_two` in `test/fixtures/parties.yml`. However,
the fixture references are plain integers rather than using Rails' label-based
cross-referencing syntax (`party_id: party_one (Party)`). This works incidentally
because the IDs happen to match, but is fragile — if either fixture ID changes,
the cross-reference breaks silently.

**Fix:** Use Rails fixture label references:
```yaml
one:
  party: party_one
  state: seeding_mode
  ...
```

---

### IN-02: Redundant tests in `LeaguesControllerTest`

**File:** `test/controllers/leagues_controller_test.rb:33-41`

**Issue:** `"should get index"` (line 33) and `"index renders successfully with fixture data"`
(line 38) both issue `GET leagues_url`. The first asserts `:success` (200 only); the second
asserts `[200, 500]`. The two assertions are contradictory: if the view can return 500,
the first test should not assert `:success` exclusively. If 500 is acceptable, only the
second test is needed.

**Fix:** Consolidate into a single test with the correct assertion level. If the view is
known-stable, assert `:success`. If there is a known fixture gap, use `[200, 500]` and
document it.

---

### IN-03: `raise "StandardError"` in controller uses wrong syntax — raises `RuntimeError`

**File:** `app/controllers/party_monitors_controller.rb:130`

**Issue:** `raise "StandardError", "Funktion not allowed on API Server"` does not raise a
`StandardError` — it raises a `RuntimeError` with the message `"StandardError"`. The first
argument to `raise` when a String is passed is the error message, not the class. The test
at line 72 asserts `[302, 500]`, which accepts a 500 (unhandled exception) as valid,
so the misuse is currently masked.

**Fix:**
```ruby
raise StandardError, "Funktion not allowed on API Server"
```
Or, since this is a guard that should redirect rather than crash:
```ruby
redirect_to root_path, alert: "..." and return
```

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
