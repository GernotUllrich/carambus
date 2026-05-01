---
quick_task: 260501-uxo
plan: 01
title: BK-2kombi SP-Phase Aufnahmegrenze enforcement (per-set inning limit)
subsystem: scoring-engine
tags: [bk2-kombi, bk-2, end-of-set, score-engine, scoreboard, scenario-management, extend-before-build]
requirements: [QUICK-260501-uxo-01]
status: complete
completed_at: 2026-05-01
duration_minutes: 18
commits:
  - 0be63e38: feat(260501-uxo) add BK-2/BK-2kombi-SP per-set inning-limit close branch
  - 4038c26c: feat(260501-uxo) thread bk2_sp_max_innings preset through quick-game form + carambus.yml.erb
  - b3fcfeca: test(260501-uxo) add 5 unit tests for BK-2/BK-2kombi-SP per-set inning-limit branch
files_modified:
  - app/models/table_monitor.rb (+23 LOC)
  - app/views/locations/_quick_game_buttons.html.erb (+5 LOC)
  - config/carambus.yml.erb (1 line changed)
  - config/carambus.yml (1 line changed, gitignored — local-only edit, see Deviations)
  - test/models/table_monitor_test.rb (+83 LOC)
test_results:
  before: { runs: 21, assertions: 43, failures: 0, errors: 0 }
  after:  { runs: 26, assertions: 50, failures: 0, errors: 0 }
  delta:  { runs: +5, assertions: +7, failures: 0, errors: 0 }
red_then_green: confirmed (2 RED on engine-branch revert → 0 failures on restore)
---

# Quick Task 260501-uxo: BK-2kombi SP-Phase Aufnahmegrenze (per-set inning limit) Summary

One-liner: BK-2kombi SP-Phase / pure BK-2 set now closes when both players complete `bk2_options.serienspiel_max_innings_per_set` innings (default 5, configurable via `bk2_sp_max_innings` preset key), preventing unbounded play in tied SP sets where neither side reaches `balls_goal`.

## Goal

Tomorrow's BCW Grand Prix (2026-05-02) needs a hard inning-limit so an SP set where neither player reaches 70 balls cannot run forever. Previously: deadlock — set never closed. Now: closes at 5 innings each; tied scores flow through the existing Plan 04 tiebreak modal; non-tied → higher score wins via standard set-close.

## Files Changed

| File | Δ LOC | Change |
|------|------:|--------|
| `app/models/table_monitor.rb` | +23 | New 5th sub-branch in `end_of_set?` inside the existing `bk_with_nachstoss` block (additive guard, no parallel state machine) |
| `app/views/locations/_quick_game_buttons.html.erb` | +5 | Conditional emission of `bk2_options[serienspiel_max_innings_per_set]` hidden field when preset has `bk2_sp_max_innings` |
| `config/carambus.yml.erb` | 1 line | "BK-2kombi 2/5/70+NS" preset now carries `bk2_sp_max_innings: 5` |
| `config/carambus.yml` | 1 line | Same key (compiled file kept in sync per Phase 38.4 D-decision) — **gitignored, see Deviations** |
| `test/models/table_monitor_test.rb` | +83 | 5 new unit tests covering close, parity-guard, DZ-exemption, pure-BK-2, regression-guard |

## Pipeline (preset → engine)

```
config/carambus.yml(.erb) preset
   │   bk2_sp_max_innings: 5
   ▼
_quick_game_buttons.html.erb (conditional emit)
   │   <%= hidden_field_tag 'bk2_options[serienspiel_max_innings_per_set]', button['bk2_sp_max_innings'] %>
   ▼
TableMonitorsController#clamp_bk_family_params! (UNCHANGED, table_monitors_controller.rb:521-525)
   │   reads params, clamps to 1..99, defaults to 5 if missing
   ▼
TableMonitor.data["bk2_options"]["serienspiel_max_innings_per_set"]
   ▼
TableMonitor#end_of_set? new branch (table_monitor.rb:1568-1575)
   │   sp_max = data.dig("bk2_options", "serienspiel_max_innings_per_set").to_i
   │   if sp_max.positive? && anstoss_innings >= sp_max && nachstoss_innings >= sp_max
   ▼
return true → standard set-close + tiebreak gate (Plan 04) handles tied scores at the level above
```

Zero controller change required — `clamp_bk_family_params!` already has the read/clamp/default-5 logic from Phase 38.4 D-07.

## Test Results

```
$ bin/rails test test/models/table_monitor_test.rb
26 runs, 50 assertions, 0 failures, 0 errors, 0 skips
```

Pre-existing 21 tests preserved (43 assertions); 5 new tests added (7 assertions).

### Test Cases (260501-uxo)

| # | Scenario | Expected | Result |
|---|----------|---------:|-------:|
| 1 | BK-2kombi SP-Phase, both inning 5, sp_max=5, no goal | `true` (close) | ✓ |
| 2 | BK-2kombi SP-Phase, playera inning 5, playerb inning 4, sp_max=5 | `false` (parity guard) | ✓ |
| 3 | BK-2kombi DZ-Phase, both inning 5, sp_max=5 | `false` (DZ exempt — `bk_with_nachstoss` is false) | ✓ |
| 4 | Pure BK-2, both inning 5, sp_max=5 | `true` (same engine) | ✓ |
| 5 | sp_max missing/0, both inning 5 | `false` (branch no-op, regression guard) | ✓ |

### RED-then-GREEN proof

Temporarily reverted the engine branch (commented out `sp_max = …` lines in `table_monitor.rb`) and re-ran:

```
26 runs, 50 assertions, 2 failures, 0 errors, 0 skips
  - test_end_of_set?_closes_BK-2kombi_SP-Phase_when_both_players_reach_sp_max_innings
  - test_end_of_set?_closes_pure_BK-2_set_when_both_players_reach_sp_max_innings
```

Exactly 2 failures, exactly the predicted tests (#1 and #4 — the close-side asserts). Tests #2, #3, #5 stayed GREEN because they expect `false`, which the legacy path also returns.

Engine branch then restored to the canonical form, all 26 tests GREEN.

## SKILL Compliance

### extend-before-build (mandatory)

- ✅ ONE additive guard branch inside the existing `bk_with_nachstoss` block.
- ✅ NO new method extracted.
- ✅ NO parallel state machine.
- ✅ Reuses `anstoss_role`, `nachstoss_role`, `anstoss_innings`, `nachstoss_innings` locals already in scope (zero recomputation).
- ✅ Branches 1, 2a, 2b, 3, 4 of `end_of_set?` UNCHANGED.
- ✅ Memory hint "Extend before build" honored — additive guard, NO parallel state machine.

### scenario-management

- ✅ Both `config/carambus.yml.erb` and `config/carambus.yml` carry the new key.
- ⚠ `config/carambus.yml` is **gitignored in carambus_bcw** (different from carambus_master where it's tracked) — see Deviations.

### Memory hint: "Tiebreak independent from Discipline"

- ✅ No new Discipline fields, no new tiebreak path. Tied case at inning-limit rides the existing Plan 04 `Game.data['tiebreak_required']` gate.

## Deviations from Plan

### [Rule 3 - Blocking issue] config/carambus.yml is gitignored in carambus_bcw

**Found during:** Task 2 commit step.
**Issue:** Plan + orchestrator gotchas asserted `config/carambus.yml` is checked in for both .erb and .yml (per Phase 38.4 D-decision). In **this** carambus_bcw checkout, `git ls-files config/carambus.yml` returns `did not match any file(s) known to git` — the file is gitignored locally.
**Fix:** Edited `config/carambus.yml` for runtime correctness (so the BCW server's `Carambus.config` reads the new `bk2_sp_max_innings: 5`), but committed only the tracked `config/carambus.yml.erb`. Added an explanatory note to the Task 2 commit body referencing the project convention "carambus.yml is compiled/ignored" (STATE.md Phase 38.4 decision).
**Files modified:** `config/carambus.yml` (local-only, intentionally not committed), `config/carambus.yml.erb` (committed in 4038c26c).
**Commit:** 4038c26c (carambus.yml.erb only).
**Impact on tournament:** Zero — the local `.yml` was edited in lockstep so the BCW dev/test runtime sees the new key. On user's `git pull` + Capistrano deploy, the production checkout's `.yml` will need to be regenerated from the `.erb` per existing project convention (handled outside this task).

### [Rule 3 - Blocking issue] Spurious stash auto-pop during RED-verification

**Found during:** Task 3 RED-then-GREEN verification step.
**Issue:** Ran `git stash push app/models/table_monitor.rb` to temp-revert Task 1 for RED proof. Stash push reported "No local changes to save" because Task 1 was already committed (stash push only stashes uncommitted changes), but `git stash pop` then auto-popped a pre-existing top-of-stash WIP from a prior session — flooding the working tree with merge conflicts in unrelated `public/docs/*.html` files.
**Fix:** Used `git checkout -- public/docs/` to reset to HEAD, clearing the conflicts. The pre-existing WIP stash entries (stash@{0}, stash@{1}) remain in the stash list — untouched, owner can inspect them later.
**Files affected:** Hundreds of `public/docs/*.html` files temporarily marked as conflicted, all reverted to HEAD; no commits made with these files.
**Then performed proper RED verification by editing the engine branch in place** (commenting out the new lines) and reverting via Edit tool — the cleaner approach for an already-committed change.

## Manual smoke test (user-driven, not gated)

Per the plan's verification section item 5:

1. On BCW dev: start a BK-2kombi 2/5/70+NS quick game.
2. Drive both players to inning 5 without either reaching 70 balls (e.g., both at 50/65).
3. Observe: set closes immediately on the inning-5 transition.
4. Confirm log line in `log/development.log`: `[TableMonitor#end_of_set?] Quick-260501-uxo BK-SP-inning-limit-close: form=bk2_kombi anstoss=playera(50/5) nachstoss=playerb(65/5) goal=70 sp_max=5 — both players completed 5 innings`.
5. If scores tied at limit, the existing Plan 04 tiebreak modal opens; otherwise the higher score wins the set.

User has the smoke-test ground truth — agent did not run a live server smoke test (URGENT path).

## Self-Check: PASSED

Verified post-write:

| Item | Status |
|------|:------:|
| `app/models/table_monitor.rb` contains `serienspiel_max_innings_per_set` reference inside `end_of_set?` | ✓ |
| `app/views/locations/_quick_game_buttons.html.erb` carries `bk2_sp_max_innings` conditional + `bk2_options[serienspiel_max_innings_per_set]` hidden field | ✓ |
| `config/carambus.yml.erb` BK-2kombi 2/5/70+NS row carries `bk2_sp_max_innings: 5` (and 3 sibling rows unchanged) | ✓ |
| `config/carambus.yml` BK-2kombi 2/5/70+NS row carries `bk2_sp_max_innings: 5` (local-only, gitignored) | ✓ |
| `test/models/table_monitor_test.rb` has 5 new tests under "Quick-260501-uxo Plan 01" header | ✓ (11 occurrences of `260501-uxo` in file) |
| Commit 0be63e38 exists | ✓ |
| Commit 4038c26c exists | ✓ |
| Commit b3fcfeca exists | ✓ |
| `bin/rails test test/models/table_monitor_test.rb` GREEN (26/26) | ✓ |
| `bundle exec erblint app/views/locations/_quick_game_buttons.html.erb` clean | ✓ |

## Ready for tournament 2026-05-02

The fix is complete and tested. User actions before BCW Grand Prix:

1. `cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw && git push` (3 commits ready).
2. On the BCW production server (or dev for sanity): `git pull` and ensure the local (gitignored) `config/carambus.yml` is regenerated from `config/carambus.yml.erb` so the runtime sees `bk2_sp_max_innings: 5` on the canonical preset.
3. Smoke test via the manual procedure above before tournament start.
