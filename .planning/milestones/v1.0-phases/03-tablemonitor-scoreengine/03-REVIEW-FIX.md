---
phase: 03-tablemonitor-scoreengine
fixed_at: 2026-04-09T00:00:00Z
review_path: .planning/phases/03-tablemonitor-scoreengine/03-REVIEW.md
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 03: Code Review Fix Report

**Fixed at:** 2026-04-09
**Source review:** .planning/phases/03-tablemonitor-scoreengine/03-REVIEW.md
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0

## Fixed Issues

### WR-01 + WR-02: Dead expression and nil `add` variable in `set_n_balls` Biathlon 3b branch

**Files modified:** `app/models/table_monitor/score_engine.rb`
**Commit:** 805b56a8
**Applied fix:** Replaced the dead `[n_balls, to_play_3b].min` expression with `add_3b = [n_calls, to_play_3b].min`, assigned `add = add_3b` so the subsequent `if add == to_play` check at line 238 has a defined value, added `data[current_role]["fouls_1"] = 0` and `data[current_role]["innings_redo_list"][-1] = add_3b` to properly cap and store the biathlon 3b inning value. Both WR-01 and WR-02 were addressed atomically as they share the same code location.

### WR-03: Division by zero in `undo_hash` when `current_role` has zero innings

**Files modified:** `app/models/table_monitor/score_engine.rb`
**Commit:** fc06e2a6
**Applied fix:** Changed the `gd` divisor in `undo_hash` non-snooker path from `data[current_role]["innings"].to_i` to `data[the_other_player]["innings"].to_i`. This is the correct denominator since it is `the_other_player`'s innings being decremented and their average being recomputed.

### WR-04: `redo_hash` never mutates data

**Files modified:** `app/models/table_monitor/score_engine.rb`
**Commit:** 1d5df8a7
**Applied fix:** Replaced the predicate-only implementation with the full symmetric mutation: appends the redo entry to `innings_list`, zeroes out the `innings_redo_list` slot, increments `innings`, calls `recompute_result`, and returns `:inning_terminated`. This mirrors `undo_hash` semantics.
**Note:** This fix requires human verification — the redo mutation logic is behaviorally correct per the reviewer's suggestion but the exact interaction with callers in `TableMonitor` should be confirmed before production deployment.

### WR-05: `render_innings_list` always reads `playera` innings count

**Files modified:** `app/models/table_monitor/score_engine.rb`
**Commit:** e24f4dba
**Applied fix:** Changed `innings = data["playera"]["innings"].to_i` to `innings = data[role]["innings"].to_i` so the column count is derived from the requested role's actual inning count, preventing truncated display when playerb has more innings than playera.

### WR-06: `@collected_dada_changes` typo logs nil instead of actual data

**Files modified:** `app/models/table_monitor.rb`
**Commit:** 5d5db691
**Applied fix:** Corrected the typo from `@collected_dada_changes` to `@collected_data_changes` on line 93 of the `after_update_commit` callback log statement.

---

_Fixed: 2026-04-09_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
