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

## From Plan 38.4-09

### 4 pre-existing system test errors (commit_inning.rb:108 string-not-Discipline)

**Discovered during:** Plan 38.4-09 Task 2 verification sweep (full
`bin/rails test test/system/bk2_scoreboard_test.rb` after adding the 4 new
T-Punktziel-/T-DZ-max-/T-SP-max-/T-hidden-inputs guards).

**Verified pre-existing:** Stashed my Plan 38.4-09 changes and re-ran T8 against
pre-fix code: same `NoMethodError: undefined method 'data' for "BK2-Kombi":String`
at `app/services/bk2/commit_inning.rb:108`. NOT a Plan 09 regression — Plan 09
only modified the view DOM and the test file.

**Failing tests:**
1. `test/system/bk2_scoreboard_test.rb:225` — T8 38.3-01+04: SP positive inning commits additively to self (D-12)
2. `test/system/bk2_scoreboard_test.rb:260` — T9 38.3-01+04: player at table flips after CommitInning; phase chip unchanged within same set
3. `test/system/bk2_scoreboard_test.rb` — T10 38.3-01+04: DZ negative inning credits opponent on commit (D-11)
4. `test/system/bk2_scoreboard_test.rb` — T11 38.4-07 I9: set closes when player reaches balls_goal (D-06 migration)

**Root cause:** All 4 errors trace to `commit_inning.rb:108` calling `.data` on
the `discipline` argument expecting a `Discipline` ActiveRecord object, but the
test fixtures (or test setup) are passing a String like `"BK2-Kombi"` instead.
Likely root cause: the test setup synthesises a `tournament_monitor.data` hash
with `playera.discipline = "BK2-Kombi"` (string) and `commit_inning` later
treats this string value as if it were the ActiveRecord Discipline.

**Why deferred:**
- Out of scope for Plan 38.4-09 (which targets test 3 of UAT — detail-view UI
  touch-button conversion, not BK2 service-layer test fixture wiring).
- Pre-existing errors (verified via stash-and-rerun against HEAD~1).
- Likely a Discipline lookup gap in either commit_inning.rb (should resolve the
  string to a Discipline via `Discipline.find_by(name:)`) or test setup
  (should populate Discipline references not raw name strings).

**Recommended action:** Schedule a separate plan or quick task to triage:
either harden `commit_inning.rb:108` to accept either a Discipline or a name
string, OR update the 4 test setups to use proper Discipline fixtures.

**Status:** Deferred for follow-up.
