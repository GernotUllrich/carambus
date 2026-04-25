# Phase 38.4 — Deferred Items

Items discovered during plan execution that are out-of-scope for the current plan
and have been deferred per the SCOPE BOUNDARY rule.

## From Plan 38.4-08

### 3 pre-existing controller test failures (legacy set_target_points field)

**Discovered during:** Plan 38.4-08 Task 3 verification sweep.

**Verified pre-existing:** Stashing my Task 2 + Task 3 changes and re-running these
3 tests against pre-fix code reproduces the same failures, confirming they are NOT
regressions caused by Plan 38.4-08.

**Failing tests:**
1. `test/controllers/table_monitors_controller_test.rb:110` — `start_game with free_game_form=bk2_kombi seeds BK2 TableMonitor from detail form`
   — asserts `bk2_options.set_target_points == 60`, gets `nil`.
2. `test/controllers/table_monitors_controller_test.rb:153` — `start_game with quick_game_form=bk2_kombi bypasses the unless-block but still seeds bk2_kombi form`
   — asserts `bk2_options.set_target_points == 50`, gets `nil`.
3. `test/controllers/table_monitors_controller_test.rb:221` — `start_game BK2 detail-form persists first_set_mode=serienspiel when whitelisted value is submitted`
   — asserts `bk2_options.set_target_points == 50`, gets `nil`.

**Root cause:** All 3 tests POST `set_target_points: 50/60` (the legacy field). Per
Phase 38.4-04 D-06, `set_target_points` was replaced by `balls_goal` as the canonical
per-set Ballziel target. The controller no longer reads `set_target_points` as a
top-level param (it reads `balls_goal` and clamps via `clamp_bk_family_params!`).
These tests were written under the old D-06 contract and never updated.

**Why deferred:**
- Out of scope for Plan 38.4-08 (which targets I9 UnfilteredParameters crash, not
  field rename test debt).
- Pre-existing failures (verified via stash-and-rerun against HEAD~3).
- Trivially fixable in a follow-up: replace `set_target_points: N` → `balls_goal: N`
  in the 3 tests, and update the assertions to `bk2_options.balls_goal == N`
  instead of `bk2_options.set_target_points == N`.

**Recommended action:** Schedule a small chore commit to update the 3 tests under
the D-06 contract. Could be bundled with Plan 38.4-09 follow-up or a quick task.

**Status:** Deferred for follow-up.
