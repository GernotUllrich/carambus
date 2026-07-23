---
phase: 260414-qb8
plan: 01
subsystem: tournaments-ui
tags: [bugfix, regression-test, quick-task, pg-undefinedcolumn]
requires:
  - games.ended_at column (already exists in schema since 2020)
provides:
  - crash-free tournaments#show for local, not-started, non-CC tournaments
  - regression test pinning the result_a/ended_at swap
affects:
  - app/views/tournaments/show.html.erb
  - app/views/tournaments/finalize_modus.html.erb
  - test/controllers/tournaments_controller_test.rb
tech-stack:
  added: []
  patterns:
    - "fixture association repair via update_columns in-test (bypasses LocalProtector and callbacks without mutating shared fixtures)"
key-files:
  created: []
  modified:
    - app/views/tournaments/show.html.erb
    - app/views/tournaments/finalize_modus.html.erb
    - test/controllers/tournaments_controller_test.rb
decisions:
  - "Auto-fixed a third occurrence of the same bug at show.html.erb:222 (force-reset modal) that the plan didn't explicitly call out — same commit, same crash, same fix. Rule 1/2 deviation."
  - "In-test fixture repair (update_columns on organizer_id/organizer_type/season_id) instead of editing shared tournaments.yml fixture — keeps the regression test self-contained and avoids touching a test-wide fixture rot that predates this task."
  - "Left _tournament_status.html.erb Ruby locals result_a/result_b alone per plan instruction — they read from table_monitor.data['playera']['result'] and are not ActiveRecord column references."
metrics:
  duration: "~15 minutes"
  tasks_completed: 2
  files_modified: 3
  commits: 2
  completed: 2026-04-14
---

# 260414-qb8 Plan 01: Fix PG::UndefinedColumn result_a Crash Summary

Replaces three `games.where.not(result_a: nil).count` calls with `games.where.not(ended_at: nil).count` in the reset-tournament / force-reset confirmation modal bodies of tournaments#show and tournaments#finalize_modus; adds a controller-level regression test that reproduces the crash against the old code and passes against the fix.

## Deliverables

### Fix: view diffs (before → after)

**app/views/tournaments/show.html.erb:195** (reset modal body — from plan)
```diff
- reset_games_count = @tournament.games.where.not(result_a: nil).count
+ reset_games_count = @tournament.games.where.not(ended_at: nil).count
```

**app/views/tournaments/show.html.erb:222** (force-reset modal body — auto-fixed, Rule 1/2)
```diff
- force_games_count = @tournament.games.where.not(result_a: nil).count
+ force_games_count = @tournament.games.where.not(ended_at: nil).count
```

**app/views/tournaments/finalize_modus.html.erb:236** (force-reset modal body — from plan)
```diff
- fm_games_count = @tournament.games.where.not(result_a: nil).count
+ fm_games_count = @tournament.games.where.not(ended_at: nil).count
```

Total diff: 3 insertions, 3 deletions. No other lines in either view touched.

### Regression test

**File:** `test/controllers/tournaments_controller_test.rb` (added 40 lines)

**Test name:** `"GET show renders reset modal for local not-started non-CC tournament (regression: result_a PG::UndefinedColumn)"`

**Run in isolation:**
```
bin/rails test test/controllers/tournaments_controller_test.rb -n "/regression.*result_a/"
```

**What it does:**
1. Sets `Carambus.config.carambus_api_url = "http://local.test"` so `local_server?` returns true
2. Repairs fixture association rot via `@tournament.update_columns(organizer_id: regions(:nbv).id, organizer_type: "Region", season_id: seasons(:current).id)` so the show header's `tournament.organizer.shortname` and `tournament.season.name` resolve — without this, an upstream `NoMethodError` on nil short-circuits the render before reaching the reset modal block
3. Pins the gating state via pre-assertions: `tournament_started == false`, `has_clubcloud_results? == false`, `organizer` and `season` non-nil
4. `GET tournament_url(@tournament)` then asserts `:success` and matches `/reset-tournament-form-#{id}/` in the body — the match only succeeds if the `games.where.not(...).count` line executed without raising

**RED proof (captured against the reverted view):** `ActionView::Template::Error (PG::UndefinedColumn: ERROR: column games.result_a does not exist)` — the exact failure mode the fix targets.

**GREEN proof (against the fix):** 1 run, 7 assertions, 0 failures.

## Gespielte Spiele semantic note

The "Gespielte Spiele" (games played) count in both reset confirmation modals now reflects `games.where.not(ended_at: nil).count` — games whose `ended_at` timestamp has been set by the table monitor when the game finished. This matches the label's intent more accurately than any `result_a` column ever could: `ended_at` is the authoritative "game finished" marker in the schema, while `result_a` never existed as a column. The fix is semantically cleaner AND makes the crash go away.

## Deviations from Plan

### Rule 1/2 auto-fix: third occurrence of the same bug

**Found during:** Task 1 verification grep (before committing)
**Issue:** Plan specified two `result_a` occurrences (show.html.erb:195, finalize_modus.html.erb:236) but `grep -rn result_a app/views/tournaments/` revealed a **third** occurrence at `show.html.erb:222` inside the privileged-user force-reset modal — identical bug pattern, same commit origin (872f92a3), same PG::UndefinedColumn crash path for any user in `User::PRIVILEGED + [scoreboard]`.
**Fix:** Extended the same one-line replacement to line 222 (`force_games_count`). Plan success criterion #1 ("Two view files contain `where.not(ended_at: nil)` and zero `result_a` references") and verification step 1 (`grep -rn result_a app/views/tournaments/` returns zero matches) both REQUIRE this third fix for the gate to pass as written — so the auto-fix is aligned with the plan's own verification intent.
**Files modified:** app/views/tournaments/show.html.erb (one additional line)
**Commit:** dddf47c9 (rolled into the Task 1 commit alongside the two plan-spec'd lines)
**Scope check:** Same commit, same bug family, same fix shape → not a separate issue, not architectural. Rule 1 (bug) and Rule 2 (correctness) both apply. No user decision needed.

### Fixture repair in test body (not in fixtures file)

**Found during:** Task 2 RED verification
**Issue:** Running the new regression test against the buggy code initially failed with `ActionView::Template::Error (undefined method 'shortname' for nil:NilClass)` at `_show.html.erb:5`, not the expected `PG::UndefinedColumn`. Root cause: the `tournaments(:local)` fixture has a polymorphic reference (`organizer: nbv (Region)`) that doesn't correctly resolve the organizer_id to `regions(:nbv).id`, and a similar season_id drift. The show header crashes on `tournament.organizer.shortname` / `tournament.season.name` before ever reaching the reset modal block at line 195. The existing `"unauthenticated GET show is publicly accessible"` test papers over this with `assert_includes [200, 302, 500]` — but a regression test must be stricter to prove the `result_a` fix.
**Fix:** Repaired the associations inside the test body via `@tournament.update_columns(organizer_id: regions(:nbv).id, organizer_type: "Region", season_id: seasons(:current).id)` before issuing the GET. Chose update_columns to skip callbacks and LocalProtector. This keeps the regression test self-contained — no shared-fixture edit, no blast radius on other tests.
**Why not fix the fixture itself:** Out of scope. The polymorphic organizer ID mismatch is a test-wide fixture rot that predates commit 872f92a3; fixing it would potentially change the behavior of any number of unrelated tests that also hit this fixture. This is Rule 4 territory (architectural-adjacent) for the broader fix, but Rule 3 (blocking) for my specific task — and the in-test repair is the minimal unblock.
**Files modified:** test/controllers/tournaments_controller_test.rb only
**Commit:** b787da5e

### Left intentionally untouched

Ruby-local `result_a` / `result_b` tokens elsewhere in the codebase (3 occurrences in `_tournament_status.html.erb` at lines 67, 74, 77) were **not touched**. These are in-memory variables derived from `tm.data["playera"]&.dig("result").to_i`, where `tm` is a TableMonitor Ruby object — they are NOT ActiveRecord column references and have nothing to do with the `games.result_a` bug. The plan explicitly instructs to leave them alone, and grep confirms they still exist post-fix, as intended.

## Verification Gates

| Gate | Command | Result |
| --- | --- | --- |
| 1 | `grep -rn "result_a" app/views/tournaments/` returns zero AR column refs | PASS — only the 3 in-memory Ruby locals in _tournament_status.html.erb remain, as intended |
| 2 | `bin/rails test test/controllers/tournaments_controller_test.rb -n "/regression.*result_a/"` | PASS (1 runs, 7 assertions, 0 failures) |
| 3 | `bin/rails test test/controllers/tournaments_controller_test.rb` (full suite regression) | PASS (56 runs, 119 assertions, 0 failures) |
| 4 | `bundle exec erblint app/views/tournaments/show.html.erb app/views/tournaments/finalize_modus.html.erb` (no NEW offenses) | PASS (exit 0; only pre-existing whitespace offenses at unrelated lines — 22, 49, 79, 87, 95, 198, 208 in finalize_modus.html.erb; zero offenses at lines 195, 222, 236 that the fix touched) |
| 5 | Diff stat minimal | PASS — views: 3 lines changed across 2 files; test: +40 lines |

## Commits

| Hash | Type | Message |
| --- | --- | --- |
| dddf47c9 | fix | `fix(260414-qb8-01): replace non-existent games.result_a with ended_at in reset modals` |
| b787da5e | test | `test(260414-qb8-01): pin games.result_a regression for tournaments#show` |

## Self-Check: PASSED

- [x] `app/views/tournaments/show.html.erb` exists and contains `where.not(ended_at: nil)` at lines 195 and 222, zero `result_a` AR column refs
- [x] `app/views/tournaments/finalize_modus.html.erb` exists and contains `where.not(ended_at: nil)` at line 236, zero `result_a` refs
- [x] `test/controllers/tournaments_controller_test.rb` exists and contains the regression test method matching `/regression.*result_a/`
- [x] Commit `dddf47c9` found in git log (view fixes)
- [x] Commit `b787da5e` found in git log (regression test)
- [x] Regression test PASSES against the fix and FAILED against the reverted (buggy) code with the exact expected `PG::UndefinedColumn: column games.result_a does not exist` error
- [x] Full `TournamentsControllerTest` suite remains green (56/56)
