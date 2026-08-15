---
phase: 22-partymonitor-extraction
fixed_at: 2026-04-11T00:00:00Z
review_path: .planning/phases/22-partymonitor-extraction/22-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 22: Code Review Fix Report

**Fixed at:** 2026-04-11
**Source review:** .planning/phases/22-partymonitor-extraction/22-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### WR-01: `add_result_to` silently swallows all exceptions

**Files modified:** `app/services/party_monitor/result_processor.rb`
**Commit:** 3cee834e
**Applied fix:** Replaced bare `rescue => e; e` (returning the exception as a value) with `Rails.logger.error` logging the player ID, message, and first 5 backtrace lines, followed by `raise e` to re-raise the original exception. Callers in `accumulate_results` will now see failures rather than silently accumulating incomplete rankings.

---

### WR-02: Division-by-zero in `update_game_participations` when `innings` is zero

**Files modified:** `app/services/party_monitor/result_processor.rb`
**Commit:** 72e0574c
**Applied fix:** Replaced `format("%.2f", result.to_f / innings).to_f` on the `else` branch (single-set path) with `innings.positive? ? format("%.2f", result.to_f / innings).to_f : 0.0`. This prevents `Infinity`/`NaN` propagation and `ArgumentError` from `format` when innings is zero or nil.

---

### WR-03: `Time.parse` used instead of timezone-aware parse in `write_game_result_data`

**Files modified:** `app/services/party_monitor/result_processor.rb`
**Commit:** 56fef618
**Applied fix:** Changed `Time.parse(game.data["finalized_at"])` to `Time.zone.parse(game.data["finalized_at"])` inside the idempotency guard in `write_game_result_data`. `Time.zone.parse` respects Rails' configured timezone and correctly handles ISO8601 strings stored via `Time.current.iso8601`.

---

### WR-04: `try do` is not a Ruby construct — bare `rescue` in `do_placement` wraps the entire method body

**Files modified:** `app/services/party_monitor/table_populator.rb`
**Commit:** 7d37990c
**Applied fix:** Removed the `try do ... end` wrapper from `do_placement`. All method body statements are now at the method's top level, with the `rescue` clause moved to method-level scope (after the closing `end` of the inner `if` block). This makes the rescue semantics explicit and eliminates the misleading `Object#try` block wrapping. The rescue was also improved as part of this change (see WR-05).

---

### WR-05: `rescue => e; raise StandardError unless Rails.env == "production"` anti-pattern repeated in both services

**Files modified:** `app/services/party_monitor/result_processor.rb`, `app/services/party_monitor/table_populator.rb`
**Commit:** 409460c6 (result_processor.rb), 7d37990c (table_populator.rb — fixed together with WR-04)
**Applied fix:** Three rescue blocks updated:
- `report_result` (result_processor.rb): replaced `Rails.logger.info` + `raise StandardError unless ...` with `Rails.logger.error` using structured format (`e.class`, `e.message`, first 10 backtrace lines), then `raise ActiveRecord::Rollback` (preserved — required by the surrounding `TournamentMonitor.transaction`).
- `finalize_game_result` (result_processor.rb): replaced conditional `Rails.logger.info` + `raise StandardError unless ...` with unconditional `Rails.logger.error` + bare `raise` to re-raise the original exception with backtrace preserved.
- `do_placement` (table_populator.rb): fixed as part of WR-04 — rescue now uses `Rails.logger.error` with structured format and bare `raise`.

---

### WR-06: `next_seqno` uses string interpolation in SQL query

**Files modified:** `app/services/party_monitor/table_populator.rb`
**Commit:** 853a50f1
**Applied fix:** Replaced all three string-interpolated `where` clauses in `table_populator.rb` with parameterized form using `?` placeholder:
- `reset_party_monitor`: `where("games.id >= #{Game::MIN_ID}")` → `where("games.id >= ?", Game::MIN_ID)`
- `reset_party_monitor`: `where("id > #{Game::MIN_ID}")` → `where("id > ?", Game::MIN_ID)`
- `next_seqno`: `where("games.id >= #{Game::MIN_ID}")` → `where("games.id >= ?", Game::MIN_ID)`

The `result_processor.rb` reference cited by the reviewer (line 224) was already using the parameterized form — no change needed there.

---

_Fixed: 2026-04-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
