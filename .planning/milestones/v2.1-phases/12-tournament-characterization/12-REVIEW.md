---
phase: 12-tournament-characterization
reviewed: 2026-04-10T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - test/models/tournament_aasm_test.rb
  - test/models/tournament_attributes_test.rb
  - test/models/tournament_calendar_test.rb
  - test/models/tournament_papertrail_test.rb
  - test/models/tournament_scraping_test.rb
findings:
  critical: 0
  warning: 4
  info: 5
  total: 9
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-10T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Five characterization test files for the Tournament model were reviewed. The tests are well-structured, use transactional isolation, and correctly pin the AASM state machine, dynamic attribute delegation, PaperTrail version counts, Google Calendar integration, and scraping pipeline behavior. No security vulnerabilities or data-loss risks were found.

Four warnings were identified: two tests exercise a method invocation path that is fragile or incorrect given the actual AASM event name, one test has a loose behavioral pin that can mask real regressions, and one test helper passes arguments in a different order than the production method signature. Five info items cover dead variables, duplicated setup helpers, missing fixture teardown, magic IDs, and a silently passing branch in a conditional test.

---

## Warnings

### WR-01: `start_tournament!` AASM event invoked via `public_send(:"start_tournament!!")` — double-bang may call wrong method

**File:** `test/models/tournament_aasm_test.rb:106`

**Issue:** The AASM event is declared as `event :start_tournament!` (line 290 of `tournament.rb`). AASM generates a bang method by appending `!`, producing `start_tournament!!`. The tests use `tournament.public_send(:"start_tournament!!")` to work around this, which is correct. However, the comment on line 105 says "Ruby method becomes `start_tournament!!`" and this is the only way to call this event — no readable alias is defined. This is a test reliability concern: if the AASM event is ever renamed to follow the conventional `start_tournament` form (dropping the `!` from the event name), the `public_send(:"start_tournament!!")` call will silently raise `NoMethodError` rather than fail with a clear assertion, and the transition tests at lines 177–188 ("multi-source transitions") share the same fragile invocation. Additionally, the test at line 177 asserts that calling `start_tournament!!` from `tournament_started` moves to `tournament_started_waiting_for_monitors`. The actual AASM definition (lines 291–292 of `tournament.rb`) does support this, so the test is correct *today*, but the double-bang pattern is a maintenance trap.

**Fix:** Add a plain-Ruby wrapper or a documented alias in the model so tests (and callers) can invoke the event without relying on a double-bang convention. If that is not feasible now, at minimum add an assertion before each such test that the method is actually defined:
```ruby
assert_respond_to tournament, :"start_tournament!!",
  "AASM event :start_tournament! must exist (generates start_tournament!! method)"
tournament.public_send(:"start_tournament!!")
```

---

### WR-02: `call_parse_table_tr` passes arguments in wrong positional order relative to production signature

**File:** `test/models/tournament_scraping_test.rb:338`

**Issue:** The production method `parse_table_tr` (line 1061–1064 of `tournament.rb`) has this signature:

```ruby
def parse_table_tr(region, frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                   header, hs, mp, innings, nbsp, no,
                   player_list, playera_fl_name, playerb_fl_name,
                   points, result, result_lines, result_url, td_lines, tr)
```

The test helper at lines 338–343 passes:

```ruby
@tournament.send(
  :parse_table_tr,
  region, frame1_lines, frame_points, frame_result, frames, gd, group, hb,
  header, hs, mp, innings, nbsp, no, player_list, playera_fl_name, playerb_fl_name,
  points, result, result_lines, result_url, td_lines, tr
)
```

The argument order in the test matches the production signature. However, comparing the return-value mapping in `call_parse_table_tr` (lines 346–353) with the actual `parse_table_tr` return array (line 1164 of `tournament.rb`):

Production returns:
```
[frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no, player_list,
 playera_fl_name, playerb_fl_name, points, result, result_lines, result_url, td_lines, tr]
```
That is 22 elements at indices 0–21.

The test maps `out[5]` to `:group`, `out[7]` to `:header`, and `out[18]` to `:result_lines`. Counting the production array: index 5 = `group` ✓, index 7 = `header` ✓, index 18 = `result_lines` ✓. The mapping appears consistent.

The real concern is the positional call itself. If the production signature changes argument order (very likely during refactoring), the test will silently pass wrong data rather than fail with an argument-count error. This is a characterization test of a 23-argument method — the fragility is inherent, but should be documented.

**Fix:** Add an explicit comment documenting that `call_parse_table_tr` mirrors the exact production signature as of characterization, and add a guard that verifies argument count:
```ruby
# Mirror of parse_table_tr signature as of CHAR-06 characterization.
# If the production method signature changes, this helper MUST be updated.
# Argument count guard:
production_arity = @tournament.method(:parse_table_tr).arity
assert_equal 23, production_arity.abs,
  "parse_table_tr arity changed — update call_parse_table_tr helper"
```

---

### WR-03: Test at line 362 has a conditional branch that makes it trivially pass on most setups

**File:** `test/models/tournament_aasm_test.rb:362`

**Issue:** The test "direct save! runs validations and raises when data is invalid" (lines 362–383) branches on `validation_adds_error = tournament.errors[:data].any?`. If validation does not fire for this data shape (the `else` branch at line 378), the test calls `assert_nothing_raised { tournament.save! }` and passes. This means the test can pass in two mutually exclusive scenarios without actually pinning the specific behavior for this codebase. As a characterization test, this defeats the purpose: it does not record *which* branch the system actually takes. A future refactoring could change the validation path without the test catching it.

**Fix:** Record the actual outcome of `tournament.valid?` at the time of authoring, then assert a single unconditional expectation. For example, if validation does *not* add an error for the duplicate-table-ids case when `tournament_plan` is nil:
```ruby
test "direct save! runs validations and succeeds when data has duplicate table_ids but no tournament_plan" do
  tournament = create_tournament
  tournament.reload
  tournament.data = { "table_ids" => [999, 999] }
  # Characterization: tournament_plan is nil, so the data validator skips the table_ids check.
  # save! succeeds (no ActiveRecord::RecordInvalid raised).
  assert_nothing_raised { tournament.save! }
end
```

---

### WR-04: `stub_remaining_calls` stubs all GET requests to `ndbv.de` uniformly, returning `MELDELISTE_HTML` for all three pages

**File:** `test/models/tournament_scraping_test.rb:304`

**Issue:** The helper (lines 304–308) stubs any GET request matching `/ndbv\.de/` to return `MELDELISTE_HTML`. Three distinct page types are requested: `meldeliste`, `einzelergebnisse`, and `einzelrangliste`. The test for "opts[:tournament_doc] skips meisterschaft HTTP call" (line 134) relies on this stub and then asserts only `source_url.present?` on the tournament (line 144). Because all three calls return identical HTML, the scraping test cannot distinguish between a correct three-call sequence and a scenario where one call is made three times (or the parser silently ignores mismatched pages). This weakens the value of the characterization test for the scraping pipeline.

**Fix:** Use distinct stubs per URL pattern and assert call counts:
```ruby
stub_request(:get, /sb_meldeliste/).to_return(status: 200, body: MELDELISTE_HTML, ...)
stub_request(:get, /sb_einzelergebnisse/).to_return(status: 200, body: EINZELERGEBNISSE_HTML, ...)
stub_request(:get, /sb_einzelrangliste/).to_return(status: 200, body: EINZELRANGLISTE_HTML, ...)
```
Or, if URL patterns overlap, use WebMock's `assert_requested` to verify each stub was called exactly once.

---

## Info

### IN-01: Dead local variables declared in `call_parse_table_tr` but never used in assertions

**File:** `test/models/tournament_scraping_test.rb:320`

**Issue:** Variables `nbsp` (line 319), `frame1_lines` (line 320), `result` (line 320), `no` (line 321), `playera_fl_name` (line 322), `playerb_fl_name` (line 323), `frames` (line 325), `frame_points` (line 326), `innings` (line 327), `hs` (line 328), `hb` (line 329), `mp` (line 330), `gd` (line 331), `points` (line 332), `frame_result` (line 333), and `result_url` (line 335) are initialized and passed in, but the named hash returned by the method is never checked for most of these. They exist solely to populate the positional call. The code would be clearer if the "state struct" were factored out.

**Fix:** Extract the mutable state into a Struct or a simple hash so the helper is self-documenting and the number of local variable assignments is reduced. This is a refactoring suggestion, not a bug.

---

### IN-02: ID constants in AASM and scraping tests use magic numbers without explaining the spacing

**File:** `test/models/tournament_aasm_test.rb:19`, `test/models/tournament_scraping_test.rb:23`

**Issue:** `AASM_TEST_ID_BASE = 50_100_000`, `ATTR_TEST_ID_BASE = 50_150_000`, `SCRAPING_TEST_ID_BASE = 50_200_000` are spread across three files without a shared registry. If a future test file picks a conflicting base (e.g., `50_100_000` again), IDs will collide within a test run (even with transactional tests), because the `@id_counter` only resets per test but the DB sequences can conflict across concurrent test runs. The gap between bases (50,000) is reasonable for 5 tests per file, but there is no documented convention for how future files should pick their base.

**Fix:** Add a comment in each file pointing to a central `ID_REGISTRY` comment block (or a `test/support/id_ranges.rb`), e.g.:
```ruby
# ID base: 50_100_000–50_149_999 (reserved for tournament_aasm_test)
# See test/support/id_ranges.rb for the full registry.
AASM_TEST_ID_BASE = 50_100_000
```

---

### IN-03: `TournamentCalendarTest` uses `Tournament.create!` in `setup` without cleaning up between tests that also call `Tournament.create!`

**File:** `test/models/tournament_calendar_test.rb:17`

**Issue:** `TournamentCalendarTest` does not declare `self.use_transactional_tests = true` (unlike the other four files). It inherits the default (`true` in `ActiveSupport::TestCase`), so this is not a bug. However, the missing explicit declaration makes the isolation intent less visible. If the default ever changes, this file would silently break isolation. The other four files explicitly declare it.

**Fix:** Add `self.use_transactional_tests = true` to `TournamentCalendarTest` alongside the other test classes for explicit consistency.

---

### IN-04: `clear_user_context` is duplicated identically across two files

**File:** `test/models/tournament_aasm_test.rb:35`, `test/models/tournament_attributes_test.rb:42`

**Issue:** The `clear_user_context` method is defined identically in both `TournamentAasmTest` and `TournamentAttributesTest`:
```ruby
def clear_user_context
  User.current = nil
  PaperTrail.request.whodunnit = nil
end
```
This is a maintenance concern: if a third user-context field is introduced, it must be updated in multiple places.

**Fix:** Extract to a shared module in `test/support/`, e.g., `test/support/user_context_helpers.rb`, and include it in both test classes. (This is already the pattern for `ScrapingHelpers` and `SnapshotHelpers` per `CLAUDE.md`.)

---

### IN-05: `tournament_papertrail_test.rb` comment at line 145 incorrectly says `forced_reset_tournament_monitor!` "cannot be tested directly"

**File:** `test/models/tournament_papertrail_test.rb:145`

**Issue:** The comment at lines 145–148 states that `forced_reset_tournament_monitor!` cannot be tested directly because `admin_can_reset_tournament?` requires `User.current` or a blank `PaperTrail whodunnit`, but the before_save hook sets whodunnit to a proc making it non-blank. However, `TournamentAasmTest` successfully calls `tournament.forced_reset_tournament_monitor!` in three tests (lines 243, 267, 283) after `clear_user_context` sets `whodunnit = nil`. The comment in the PaperTrail test appears to be inaccurate and may confuse future developers about what is testable.

**Fix:** Update the comment to reflect that `forced_reset_tournament_monitor!` can be tested when `PaperTrail.request.whodunnit` is set to `nil` *and* the tournament has no local games. Reference `TournamentAasmTest` for examples.

---

_Reviewed: 2026-04-10T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
