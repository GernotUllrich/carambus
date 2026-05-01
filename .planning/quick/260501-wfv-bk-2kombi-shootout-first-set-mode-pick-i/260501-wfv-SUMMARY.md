---
phase: 260501-wfv
plan: 01
subsystem: scoreboard/bk2_kombi
tags: [bk2, scoreboard, reflex, bug-fix, quick-fix]
requirements:
  - QUICK-260501-WFV-01
dependency_graph:
  requires:
    - app/services/bk2/advance_match_state.rb (initialize_bk2_state! contract — early-return on existing Hash)
    - app/services/table_monitor/game_setup.rb (perform_start_game seeds bk2_state during warmup)
  provides:
    - app/reflexes/table_monitor_reflex.rb#start_game (now re-seeds bk2_state from operator pick)
    - app/reflexes/table_monitor_reflex.rb#switch_players_and_start_game (symmetric Anstoßer-swap variant)
  affects:
    - app/views/table_monitors/_scoreboard.html.erb:63 (now reads correct bk2_state.first_set_mode)
tech_stack:
  added: []
  patterns:
    - "stale-state-clear-before-reinit (small additive guard, extend-before-build SKILL)"
key_files:
  modified:
    - app/reflexes/table_monitor_reflex.rb
    - test/services/bk2/advance_match_state_test.rb
  created: []
decisions:
  - "Did NOT add force: keyword to initialize_bk2_state! — kept service contract unchanged; caller owns state-clear responsibility"
  - "Did NOT extract DRY helper for the duplicated 7-line block in start_game / switch_players_and_start_game — pure-fix scope per tournament-deadline constraint"
  - "Did NOT touch key_d reflex — different code path (scoring, not transition); explicitly out of scope"
  - "Placed delete inside the inner valid-mode allowlist — no-op if dataset[:bk2_first_set_mode] is missing/invalid (preserves stale-bk2_state behavior in the unhappy path, exactly as before)"
metrics:
  duration_seconds: 108
  completed_date: 2026-05-01
  tasks: 2
  files_modified: 2
  files_created: 0
---

# Phase 260501-wfv: BK-2kombi Shootout first_set_mode Pick Re-init Summary

**One-liner:** Fixed BK-2kombi shootout regression where picking "BK-2 first" (serienspiel) was ignored — added one-line `data.delete("bk2_state")` guard in both shootout reflex methods so the subsequent `initialize_bk2_state!` call actually re-seeds with the operator's pick.

## What Was Done

### Task 1 — Engine fix (commit `6a31756d`)

Added `@table_monitor.data.delete("bk2_state")` inside the existing `if %w[direkter_zweikampf serienspiel].include?(bk2_mode)` block in two reflex methods:

- `app/reflexes/table_monitor_reflex.rb#switch_players_and_start_game` (line ~366)
- `app/reflexes/table_monitor_reflex.rb#start_game` (line ~402)

Each addition is a 5-line block: 4 lines of German/English comment explaining the rationale + 1 line of code. Total: +10 production lines, 0 lines removed.

The delete sits AFTER the `bk2_options["first_set_mode"] = bk2_mode` write and BEFORE the `initialize_bk2_state!` call. Because it's inside the valid-mode allowlist, the unhappy-path behavior (missing/invalid `dataset[:bk2_first_set_mode]`) is unchanged — stale bk2_state is still preserved exactly as before.

### Task 2 — Regression test (commit `5b5dc22d`)

Added one new test method to `Bk2::AdvanceMatchStateTest` in `test/services/bk2/advance_match_state_test.rb`:

```
test "initialize_bk2_state! re-seeds with new first_set_mode after caller deletes stale bk2_state"
```

Test flow mirrors the reflex contract:
1. Initial DZ-seed (mirrors `GameSetup#perform_start_game`)
2. Operator flip: rewrite `bk2_options.first_set_mode = "serienspiel"` + `data.delete("bk2_state")`
3. Re-call `initialize_bk2_state!`
4. Assert: `first_set_mode == "serienspiel"`, `current_phase == "serienspiel"`, `innings_left_in_set == 5`, `shots_left_in_turn == 0` (4 post-re-init assertions + 4 initial-state assertions = 8 assertions)

## Diff Stats

```
app/reflexes/table_monitor_reflex.rb          | 10 ++++++++++
test/services/bk2/advance_match_state_test.rb | 36 ++++++++++++++++++++++
2 files changed, 46 insertions(+), 0 deletions(-)
```

## Test Count

| File                                            | Before | After  | Assertions Before → After |
| ----------------------------------------------- | ------ | ------ | ------------------------- |
| `test/services/bk2/advance_match_state_test.rb` | 6 runs | 7 runs | 22 → 30                   |

All 7 tests pass; 0 failures, 0 errors, 0 skips.

## Verification Performed

- `bin/rails test test/services/bk2/advance_match_state_test.rb` — **GREEN** (7 runs, 30 assertions, 0 failures)
- `bin/rails test test/services/bk2/advance_match_state_test.rb -n "/re-seeds_with_new_first_set_mode/"` — **GREEN** (1 run, 8 assertions)
- `bundle exec standardrb app/reflexes/table_monitor_reflex.rb` — clean on edited lines (pre-existing offenses on lines 728+ are out of scope, untouched by this change)
- `bundle exec standardrb test/services/bk2/advance_match_state_test.rb` — clean
- `grep -c '@table_monitor.data.delete("bk2_state")' app/reflexes/table_monitor_reflex.rb` → `2` (one per method, as required)

## Deviations from Plan

None — plan executed exactly as written. No bugs discovered, no architectural pivots, no auth gates encountered.

## Out-of-Scope Notes

- **`key_d` reflex deliberately untouched.** It's a different code path (scoring during play, not the warmup→playing transition). If a similar stale-state bug surfaces there in the future, this commit is the reference pattern.
- **Residual code smell — duplicated 7-line block in two reflex methods.** Both `switch_players_and_start_game` and `start_game` carry an identical:
  ```ruby
  if @table_monitor.data["free_game_form"] == "bk2_kombi"
    bk2_mode = element.andand.dataset[:bk2_first_set_mode].to_s
    if %w[direkter_zweikampf serienspiel].include?(bk2_mode)
      @table_monitor.data["bk2_options"] ||= {}
      @table_monitor.data["bk2_options"]["first_set_mode"] = bk2_mode
      @table_monitor.data.delete("bk2_state")
    end
  end
  ```
  A future cleanup pass could DRY this into a private helper like `apply_bk2_first_set_mode_pick!(@table_monitor)`. **NOT** done here per pure-fix scope and tomorrow's BCW Grand Prix deadline.
- **Pre-existing standardrb offenses in `table_monitor_reflex.rb`** (lines 728, 731, 736, 768, 796, 987-990, 1000, 1011, 1019, 1023-1026, 1051, 1103) are unrelated to this change and remain unfixed per the **scope boundary rule** (only auto-fix issues directly caused by current task's changes).

## extend-before-build SKILL Honored

This fix follows the SKILL exactly:

- ✅ **Used existing structure:** the `initialize_bk2_state!` early-return contract is preserved unchanged. Caller owns the state-clear responsibility.
- ✅ **Smallest possible delta:** 1 LOC of executable code per method (2 total) inside the existing branch.
- ✅ **No new method on the service:** no `force:` keyword, no `reset_bk2_state!` helper.
- ✅ **No new state slot:** no flag like `bk2_state_dirty`.
- ✅ **No refactor:** the duplicated reflex block stays duplicated; future cleanup is documented as a separate concern above.

The legacy reflex path already did 95% of what the operator needed (warmup→playing transition with bk2_options write); the missing 5% was a single line of state-clear before re-seeding. Exactly the pattern the SKILL prescribes.

## Commits

| Task   | Hash       | Message                                                                                       |
| ------ | ---------- | --------------------------------------------------------------------------------------------- |
| Task 1 | `6a31756d` | `fix(260501-wfv): clear stale bk2_state in shootout reflexes so first_set_mode pick re-seeds` |
| Task 2 | `5b5dc22d` | `test(260501-wfv): pin re-init contract for bk2_state after first_set_mode flip`              |

## Tournament Readiness

**Status:** READY for BCW Grand Prix 2026-05-02 morning.

The volunteer operator can now click "BK-2 first" (serienspiel) or "BK-2plus first" (direkter_zweikampf) at the BK-2kombi shootout transition, and the playing scoreboard will render the correct phase chip and initial config (innings or shots counter) for set 1.

Manual smoke test (optional, not gating per plan):
1. Start dev server: `foreman start -f Procfile.dev`
2. Quickstart a BK-2kombi training match → confirm warmup loads
3. Click "BK-2 first" at shootout → expect set 1 chip = `BK-2 (Serienspiel)`, NOT `BK-2plus`
4. Repeat with "BK-2plus first" → expect set 1 chip = `BK-2plus (DZ)`

## Self-Check: PASSED

- ✅ `app/reflexes/table_monitor_reflex.rb` exists and contains 2 occurrences of `@table_monitor.data.delete("bk2_state")` (verified via grep)
- ✅ `test/services/bk2/advance_match_state_test.rb` exists and contains the new `re-seeds_with_new_first_set_mode` test (verified via test runner output)
- ✅ Commit `6a31756d` exists in git log (verified)
- ✅ Commit `5b5dc22d` exists in git log (verified)
- ✅ All 7 tests in `advance_match_state_test.rb` pass (verified via `bin/rails test`)
- ✅ No new standardrb offenses introduced on edited lines (verified via line-range grep)
