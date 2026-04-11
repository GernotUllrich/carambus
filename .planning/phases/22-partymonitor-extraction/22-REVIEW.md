---
phase: 22-partymonitor-extraction
reviewed: 2026-04-11T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - app/models/party_monitor.rb
  - app/services/party_monitor/result_processor.rb
  - app/services/party_monitor/table_populator.rb
  - test/services/party_monitor/result_processor_test.rb
  - test/services/party_monitor/table_populator_test.rb
findings:
  critical: 0
  warning: 6
  info: 5
  total: 11
status: issues_found
---

# Phase 22: Code Review Report

**Reviewed:** 2026-04-11
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 22 extracted result processing and table population logic out of `PartyMonitor` into two POROs (`ResultProcessor` and `TablePopulator`). The structural extraction is correct and the delegation wrappers on the model are clean. The test coverage validates structural invariants (method visibility, delegation, transaction scope) but is intentionally thin on runtime behavior — which is acceptable for a characterization-based refactoring.

Several pre-existing bugs and hazards were carried over from the original model. A few new concerns were introduced in the extracted code. The most important issues are: a silent error swallower in `add_result_to`, a division-by-zero path in `update_game_participations`, inconsistent error handling across the two services, a data mutation that is documented-but-intentional, and a `rescue` that uses bare `Time.parse` without timezone awareness.

No critical (security, data loss, authentication bypass) issues were found.

---

## Warnings

### WR-01: `add_result_to` silently swallows all exceptions

**File:** `app/services/party_monitor/result_processor.rb:400-402`
**Issue:** The rescue block catches any exception and returns it as a value (`rescue => e; e`). This means a failed `add_result_to` call returns an exception object instead of raising, and the rankings hash accumulation silently produces incomplete results. Callers (`accumulate_results`) iterate with `.each` and do not check return values, so ranking corruption goes unnoticed and unlogged.
**Fix:**
```ruby
rescue => e
  Rails.logger.error "[add_result_to] Error for player #{gp.player_id}: #{e.message}"
  raise e   # or: return if you want silent skip, but log it
end
```
At minimum, log the error. Returning the exception object as a value is a bug pattern that hides failures.

---

### WR-02: Division-by-zero in `update_game_participations` when `innings` is zero

**File:** `app/services/party_monitor/result_processor.rb:312`
**Issue:** `gd` is calculated as `result.to_f / innings.to_i`. When `tabmon.data["player#{c}"]["innings"]` is `0` or `nil`, `innings.to_i` is `0`, producing `Infinity` or `NaN` via float division. This value is then passed to `format("%.2f", ...)` which raises `ArgumentError: invalid value for format` on some Ruby versions, and otherwise writes `"Infinity"` or `"NaN"` into the `gd` column.
**Fix:**
```ruby
gd = innings.positive? ? format("%.2f", result.to_f / innings).to_f : 0.0
```
The same pattern is also present on line 294 (sets_to_play > 1 branch) but `innings` there comes from `Aufnahmen#{n}` which is validated upstream; line 312 is the more exposed path.

---

### WR-03: `Time.parse` used instead of timezone-aware parse in `write_game_result_data`

**File:** `app/services/party_monitor/result_processor.rb:358-361`
**Issue:** `Time.parse(game.data["finalized_at"])` uses Ruby's stdlib `Time.parse`, which interprets the string in the local system timezone, not UTC. The value being parsed was stored as `Time.current.iso8601` (UTC-aware via Rails). In production servers where the system timezone differs from UTC, the idempotency window comparison (`finalized_at > 1.minute.ago`) can be off by hours, either causing duplicate writes or blocking legitimate re-writes.
**Fix:**
```ruby
finalized_at = Time.zone.parse(game.data["finalized_at"]) rescue nil
```
`Time.zone.parse` respects Rails' configured timezone and handles ISO8601 strings correctly.

---

### WR-04: `try do` is not a Ruby construct — bare `rescue` in `do_placement` wraps the entire method body

**File:** `app/services/party_monitor/table_populator.rb:72`
**Issue:** `try do ... rescue ... end` — `try` is not a Ruby keyword. In Ruby, `try` is an `Object` method from ActiveSupport that calls a method if the receiver is not nil. When called with a block, `Object#try { block }` executes the block and returns its result. This means the `do_placement` body runs inside `Object#try`, which does NOT rescue exceptions from the block — the `rescue` clause on line 148 is inside the block passed to `try`, but `try` with a block does not rescue. The actual exception handling is only by the explicit `rescue => e` at line 148-153. This is confusing and misleading code structure. The same pattern appears in `report_result` (result_processor.rb:32).

This is a pre-existing pattern carried over from `TournamentMonitor`, so it is not new debt introduced by this phase, but it is worth flagging since the extracted services make it more visible.
**Fix:**
Remove the `try do` wrapper and use a plain `begin...rescue...end` block, or move the rescue to wrap only the parts that need it:
```ruby
def do_placement(new_game, r_no, t_no, row = nil, row_nr = nil)
  # ... method body ...
rescue => e
  Rails.logger.info "StandardError #{e}, #{e.backtrace.to_a.join("\n")}"
  raise StandardError unless Rails.env == "production"
  raise ActiveRecord::Rollback
end
```

---

### WR-05: `rescue => e; raise StandardError unless Rails.env == "production"` anti-pattern repeated in both services

**File:** `app/services/party_monitor/result_processor.rb:104-108`, `app/services/party_monitor/result_processor.rb:195-198`, `app/services/party_monitor/table_populator.rb:148-153`
**Issue:** The pattern `rescue => e; raise StandardError unless Rails.env == "production"` re-raises in dev/test but silently swallows in production. This is the inverse of what is usually wanted: production errors need to surface (e.g., to Sentry/Bugsnag), while dev/test errors should also surface to catch regressions. Additionally, `raise StandardError` discards the original exception and backtrace, making debugging harder.
**Fix:**
```ruby
rescue => e
  Rails.logger.error "StandardError #{e.class}: #{e.message}\n#{e.backtrace.to_a.first(10).join("\n")}"
  raise  # re-raise original exception with backtrace preserved
end
```
If production must not raise (fire-and-forget), the pattern should at minimum re-raise the original: `raise e` not `raise StandardError`.

---

### WR-06: `next_seqno` uses string interpolation in SQL query

**File:** `app/services/party_monitor/table_populator.rb:159`
**Issue:** `@party_monitor.party.games.where("games.id >= #{Game::MIN_ID}")` uses string interpolation with a constant. While `Game::MIN_ID` is a constant (not user input), this is a habit-forming pattern that linters and security scanners will flag. If the constant were ever replaced by a variable, it would become a SQL injection risk.

The same pattern appears on line 41-42 of `table_populator.rb` and line 224 of `result_processor.rb`.
**Fix:**
```ruby
@party_monitor.party.games.where("games.id >= ?", Game::MIN_ID).where.not(seqno: nil).map(&:seqno).max.to_i + 1
```

---

## Info

### IN-01: Commented-out code blocks are large and should be removed or extracted

**File:** `app/services/party_monitor/result_processor.rb:79-100`
**Issue:** A large block of commented-out code (22 lines) from the original `TournamentMonitor` remains in `report_result`. These comments add noise and create confusion about whether the commented logic might be re-enabled. The surrounding comment `# unless tournament.manual_assignment || tournament.continuous_placements` suggests these are intentionally disabled, not temporarily disabled.
**Fix:** Remove the commented-out block, or move to a `FIXME` note with a ticket reference if future reinstatement is planned.

---

### IN-02: `fixed_display_left?` predicate method returns a string, not a boolean

**File:** `app/models/party_monitor.rb:90-92`
**Issue:** The method is named `fixed_display_left?` (predicate convention implies boolean) but returns the hardcoded string `"playera"`. This is confusing — callers expecting `true`/`false` will get a truthy string value, which may work by accident but is misleading. The schema has a `fixed_display_left` string column; the method appears to shadow it incorrectly.
**Fix:** Either return a boolean:
```ruby
def fixed_display_left?
  fixed_display_left == "playera"
end
```
Or remove the `?` suffix and have it return the string value like the other attribute accessors.

---

### IN-03: `DEBUG` constant evaluated at load time, not per-request

**File:** `app/models/party_monitor.rb:40`
**Issue:** `DEBUG = Rails.env != "production"` is evaluated when the class is loaded. This is fine for typical deployments, but means the `DEBUG` constant cannot be toggled at runtime for targeted logging. More importantly, it creates a load-order dependency: if `Rails.env` is not yet set when this constant is evaluated (e.g., during certain initializer sequences), it will silently default to the wrong value.
**Fix:** This is low-risk but consider using `Rails.env.production?` as a direct inline check, or wrapping in `if Rails.env.development? || Rails.env.test?` which makes intent explicit without a constant.

---

### IN-04: `@@pm_counter` class variable in test helper is shared across test classes

**File:** `test/support/party_monitor_test_helper.rb:13`
**Issue:** `@@pm_counter` is a Ruby class variable on the module, meaning it is shared across all classes that include `PartyMonitorTestHelper`. If two test classes include this helper and run in the same process, the counter increments across class boundaries. This is unlikely to cause failures given the large `base_id` offset but is an unusual pattern.
**Fix:**
```ruby
@pm_counter ||= 0
@pm_counter += 1
```
Use `@pm_counter` (instance variable on the module itself) rather than `@@pm_counter` to scope it to the module's own instance.

---

### IN-05: Test suite has no behavioral coverage for `update_game_participations` or `finalize_game_result`

**File:** `test/services/party_monitor/result_processor_test.rb`
**Issue:** The tests verify structural properties (method visibility, delegation wiring, transaction scope via source inspection) but there are no behavioral tests for `update_game_participations`, `finalize_game_result`, or `finalize_round`. This is acknowledged as a characterization-phase limitation in the test comments, but the division-by-zero risk on `update_game_participations` (WR-02) means there is no test catching that edge case.
**Fix:** Add at minimum a smoke test for `update_game_participations` with a mock `tabmon` where `innings` is zero, to guard against WR-02.

---

_Reviewed: 2026-04-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
