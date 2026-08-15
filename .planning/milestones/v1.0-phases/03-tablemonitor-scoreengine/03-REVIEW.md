---
phase: 03-tablemonitor-scoreengine
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - app/models/table_monitor/score_engine.rb
  - app/models/table_monitor.rb
  - test/models/table_monitor/score_engine_test.rb
findings:
  critical: 0
  warning: 6
  info: 5
  total: 11
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The `TableMonitor::ScoreEngine` extraction is structurally sound. The engine correctly operates as a pure hash-mutation collaborator with no ActiveRecord dependencies, and `TableMonitor` properly delegates to it via a lazy accessor that is invalidated on `reload`. The test file is well-organized with a clean fixture helper.

Six warnings were found, all logic/correctness issues. No security vulnerabilities were identified. Five info items cover dead code and minor quality gaps.

---

## Warnings

### WR-01: Dead expression in `set_n_balls` Biathlon 3b branch silently discards computed value

**File:** `app/models/table_monitor/score_engine.rb:208`
**Issue:** The expression `[n_balls, to_play_3b].min` is evaluated but its return value is never assigned. The intention is identical to the `add_n_balls` Biathlon path which assigns `add = [n_balls, to_play_3b].min` and then uses `add`. As written, `innings_redo_list[-1]` is set to `set` (line 194, the pre-clamp value) rather than the capped value, so a player can receive more balls than the 3b phase allows in `set_n_balls`.

**Fix:**
```ruby
# Replace line 208:
[n_balls, to_play_3b].min
# With:
add_3b = [n_balls, to_play_3b].min
data[current_role]["innings_redo_list"][-1] = add_3b
```

---

### WR-02: `add` variable used in `set_n_balls` is `nil` when Biathlon 3b branch executes

**File:** `app/models/table_monitor/score_engine.rb:238`
**Issue:** After the `if data["biathlon_phase"] == "3b"` / `else` split (lines 207-237), the code at line 238 unconditionally checks `if add == to_play`. Inside the Biathlon 3b branch `add` is never assigned (see WR-01), so `add` holds the value from an outer scope if one exists, or raises `NameError` if this code path is first entered with `biathlon_phase == "3b"`. This could crash live scoring for Biathlon games using `set_n_balls`.

**Fix:**
```ruby
# After the if/else block ends at line 237, guard with:
if add == to_play
  return :goal_reached
end
# And ensure `add` is always assigned in the biathlon branch (see WR-01).
```

---

### WR-03: Division by zero in `undo_hash` when `current_role` has zero innings

**File:** `app/models/table_monitor/score_engine.rb:405`
**Issue:** In the non-snooker undo path (else branch at line 396), `gd` is computed as:
```ruby
format("%.2f", data[the_other_player]["result"].to_f / data[current_role]["innings"].to_i)
```
The divisor uses `current_role`'s innings count, not `the_other_player`'s innings count. If `current_role` (playera) has `innings == 0` at the moment undo rolls back the other player's inning, this divides by zero, producing `Infinity` or raising `ZeroDivisionError` depending on float/integer context. The correct denominator is `the_other_player`'s innings (which was just decremented by 1 on line 401).

**Fix:**
```ruby
# Line 405 — change divisor from current_role to the_other_player
data[the_other_player]["gd"] =
  format("%.2f", data[the_other_player]["result"].to_f / data[the_other_player]["innings"].to_i)
```

---

### WR-04: `redo_hash` never mutates data — always returns `:inning_terminated` or `nil` without side effects

**File:** `app/models/table_monitor/score_engine.rb:416-423`
**Issue:** `redo_hash` checks whether there are innings to redo and returns `:inning_terminated` if so, but never actually moves the redo data into the committed innings list. The method is effectively a predicate. If `TableMonitor` calls `redo_hash` expecting the hash state to be mutated (mirroring what `undo_hash` does), the redo signal is returned but the data remains unchanged, producing a no-op redo for non-PaperTrail disciplines.

**Fix:** Either document explicitly that redo mutation is intentionally handled by the caller (and rename to `redo_hash_signal?`), or implement the symmetric mutation:
```ruby
def redo_hash
  current_role = data["current_inning"]["active_player"]
  innings_redo = Array(data[current_role]["innings_redo_list"]).last.to_i
  return nil unless innings_redo > 0

  # Commit current redo entry into innings_list
  data[current_role]["innings_list"] ||= []
  data[current_role]["innings_list"] << innings_redo
  data[current_role]["innings_redo_list"][-1] = 0
  data[current_role]["innings"] = (data[current_role]["innings"].to_i + 1)
  recompute_result(current_role)
  :inning_terminated
end
```

---

### WR-05: `render_innings_list` always reads `playera`'s innings count regardless of `role` argument

**File:** `app/models/table_monitor/score_engine.rb:433`
**Issue:**
```ruby
innings = data["playera"]["innings"].to_i
```
The `role` parameter is used for `show_innings` and `show_fouls` (lines 435-436), but the column count `cols` is always derived from `playera`'s innings. When `role == "playerb"` and playerb has more innings than playera, the rendered table will be truncated and omit rows. This is a display correctness bug for asymmetric inning counts.

**Fix:**
```ruby
innings = data[role]["innings"].to_i
```

---

### WR-06: `@collected_dada_changes` typo in `after_update_commit` callback logs stale data silently

**File:** `app/models/table_monitor.rb:93`
**Issue:** The log line references `@collected_dada_changes` (typo: `dada` instead of `data`). Because Ruby instance variables return `nil` on first access, this never raises but always logs `nil` instead of the actual collected data changes, making the debug log misleading when diagnosing broadcast issues.

**Fix:**
```ruby
# Line 93 — fix typo
Rails.logger.info "🔔 Previous data changes: #{@collected_data_changes.inspect}"
```

---

## Info

### IN-01: `set_n_balls` parameter `change_to_pointer_mode` is unused (rubocop suppression comment present)

**File:** `app/models/table_monitor/score_engine.rb:180`
**Issue:** The method signature includes `change_to_pointer_mode = false` with an inline rubocop disable comment. The parameter was presumably moved to the caller but the signature was not cleaned up. It misleads callers into thinking the argument has an effect.
**Fix:** Remove the parameter from `ScoreEngine#set_n_balls`. If the caller (`TableMonitor`) needs to change pointer mode, it should handle that after receiving the return value.

---

### IN-02: `recalculate_player_stats` parameter `save_now:` is unused (rubocop suppression present)

**File:** `app/models/table_monitor/score_engine.rb:903`
**Issue:** The `save_now:` keyword argument is suppressed with a rubocop disable comment but never used. The method only mutates the hash; persistence is always deferred to the caller regardless of this flag.
**Fix:** Remove `save_now:` from the signature and update all call sites.

---

### IN-03: `raise StandardError` (bare, no message) in error rescue blocks loses original error type

**File:** `app/models/table_monitor/score_engine.rb:174, 278, 294, 305, 331`
**Issue:** Multiple rescue blocks log the original error then `raise StandardError` (not `raise e`, not `raise StandardError, e.message`). This converts typed errors (e.g., `NoMethodError`, `TypeError`) into generic `StandardError`, making caller rescue clauses and exception monitoring tools unable to distinguish error categories. The production guard (`raise ... unless Rails.env == "production"`) in `set_n_balls` and `render_innings_list` is appropriate but the same unconditional bare raise in `foul_one`, `foul_two`, etc. silences type information in all environments.
**Fix:** Use `raise` (re-raise) to preserve the original exception:
```ruby
rescue StandardError => e
  Rails.logger.error "ERROR foul_one: #{e}, #{e.backtrace&.join("\n")}"
  raise  # re-raises the original exception with original class and backtrace
end
```

---

### IN-04: `balls_goal` for playerb hardcoded to `game.data["balls_goal_a"]` in `initialize_game`

**File:** `app/models/table_monitor.rb:945`
**Issue:** In the `PartyMonitor` branch for playerb's `balls_goal`, the value is read from `game.data["balls_goal_a"]` (same key as playera). This appears to be a copy-paste error — it likely should be `"balls_goal_b"`. This causes both players to receive playerA's balls goal in PartyMonitor games with different handicaps.
**Fix:**
```ruby
# Line 945
"balls_goal" => if tournament_monitor.is_a?(PartyMonitor)
                  game.data["balls_goal_b"]   # was "balls_goal_a"
                else
                  ...
```

---

### IN-05: Missing test coverage for `redo_hash` when no undo has occurred (edge case) and for Biathlon phase transitions

**File:** `test/models/table_monitor/score_engine_test.rb`
**Issue:** `redo_hash` is tested for the happy path (points exist) and nil (no points), but not for the transition behavior (the mutation described in WR-04 is not tested). Additionally, the Biathlon 3b→5k phase transition — one of the most complex branches in `add_n_balls` and `set_n_balls` — has no test coverage at all. These are the highest-risk untested paths given the complexity of the Biathlon logic.
**Fix:** Add characterization tests for:
1. Biathlon `add_n_balls`: confirm phase transitions from `"3b"` to `"5k"` and the x6 multiplier applied to all prior innings.
2. `redo_hash` mutation: confirm that calling `undo_hash` then `redo_hash` produces the original state.

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
