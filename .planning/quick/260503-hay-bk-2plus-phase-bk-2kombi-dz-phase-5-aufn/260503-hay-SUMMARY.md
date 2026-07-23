---
phase: quick-260503-hay
plan: 01
subsystem: scoring
tags: [bk-2plus, bk-2kombi, end_of_set, innings_goal, regression-fix, extend-before-build]
requires: []
provides:
  - "Phase-aware guard on legacy innings_goal-close branch in TableMonitor#end_of_set?"
affects:
  - "BK-2plus standalone games — no longer close prematurely after 5 innings"
  - "BK-2kombi DZ-Phase games — no longer close prematurely after 5 innings"
tech-stack:
  added: []
  patterns:
    - "extend-before-build SKILL applied: 1 local var + 1 && guard, no new predicate"
key-files:
  created: []
  modified:
    - app/models/table_monitor.rb
    - test/models/table_monitor_test.rb
decisions:
  - "Single inline `no_innings_limit_phase` local var inside end_of_set? — no new predicate method, no method extraction (extend-before-build SKILL)"
  - "Guard scope = bk_2plus + bk2_kombi-DZ only — karambol/BK-2/BK-2kombi-SP keep legacy branch, defense-in-depth via earlier branches"
metrics:
  duration: ~6 minutes
  completed: 2026-05-03
  loc_delta: +17 (model) +95 (tests) = +112 total
  tests_added: 4
---

# Quick-260503-hay: BK-2plus / BK-2kombi DZ-Phase phase-blind innings_goal close fix

## One-liner

Legacy karambol innings_goal-close branch in `TableMonitor#end_of_set?` was phase-blind — closed BK-2plus standalone and BK-2kombi DZ-Phase sets prematurely after 5 innings on BCW Grand Prix tournament day. Fixed via 2-line `no_innings_limit_phase` local + `&&` guard.

## Background (BCW Grand Prix 2026-05-03)

During the BCW Grand Prix tournament on 2026-05-03, BK-2plus standalone games and BK-2kombi DZ-Phase games aborted after 5 innings even though no Aufnahmenbegrenzung exists for those modes. BK-2plus uses balls_goal only; BK-2kombi DZ uses shot-limit per turn (NOT inning-limit per set).

Root cause: commit `1491385f` (2026-04-26) set `innings_goal=5` for the entire BK-* family as an SP-phase safety net (controller line 305). The legacy karambol close branch at `app/models/table_monitor.rb:1583-1587` had no phase awareness — it fired whenever both players reached `innings_goal` (or any single player reached it when `!allow_follow_up`).

For BK-2plus, `allow_follow_up` is `false` (controller line 329), so the branch fired immediately when `playera.innings >= 5`.
For BK-2kombi DZ-Phase, `allow_follow_up` is `true`, so the branch fired when `playera.innings == playerb.innings` AND both `>= 5`.

## What changed

### `app/models/table_monitor.rb` (+17 / -1 LOC)

Added a `no_innings_limit_phase` local variable just before the legacy `if/elsif/end` close-branch chain in `end_of_set?` (around line 1578), and prepended `!no_innings_limit_phase &&` as the first clause of the legacy `elsif` branch:

```ruby
no_innings_limit_phase = case data["free_game_form"]
                         when "bk_2plus" then true
                         when "bk2_kombi" then bk2_kombi_current_phase == "direkter_zweikampf"
                         else false
                         end
```

Branch protected: lines 1583-1587 elsif now reads `elsif !no_innings_limit_phase && data["innings_goal"].to_i.positive? && …`.

Karambol, BK-2, and BK-2kombi-SP are untouched (they evaluate `no_innings_limit_phase` to `false`, so the legacy branch keeps firing as before).

### `test/models/table_monitor_test.rb` (+95 LOC, 4 new tests)

New section `Quick-260503-hay — BK-2plus / BK-2kombi DZ-Phase MUST NOT close on innings_goal=5` after the existing 260501-uxo block:

1. `end_of_set? does NOT close BK-2plus standalone when both reach 5 innings without balls_goal` — RED→GREEN
2. `end_of_set? does NOT close BK-2kombi DZ-Phase when both reach 5 innings without balls_goal` — RED→GREEN
3. `end_of_set? STILL closes karambol when innings_goal reached at equal innings` — GREEN throughout (legacy branch regression guard)
4. `end_of_set? STILL closes BK-2kombi SP-Phase via the existing 260501-uxo SP-inning-limit branch` — GREEN throughout (the SP-inning-limit branch fires earlier, never reaches the legacy branch)

All 4 tests reuse the existing `build_bk_data` helper (line 107). Test data is set directly on `@tm.data` rather than via `update!`, matching the existing convention on lines 254-258 / 269-273 of the same file.

## Test results

### Before Task 2 (RED baseline)
```
30 runs, 56 assertions, 2 failures, 0 errors, 0 skips
- Test 1 (BK-2plus) FAILED — legacy branch is phase-blind
- Test 2 (BK-2kombi DZ) FAILED — legacy branch is phase-blind
- Test 3 (karambol regression) PASSED
- Test 4 (BK-2kombi SP regression) PASSED
- 26 pre-existing tests (incl. 21 in target subset) PASSED
```

### After Task 2 (GREEN)
```
30 runs, 56 assertions, 0 failures, 0 errors, 0 skips
```

### Broader regression sweep
```
bin/rails test test/system/tiebreak_test.rb test/system/final_match_score_operator_gate_test.rb
8 runs, 51 assertions, 0 failures, 0 errors, 0 skips
```

No new failures introduced. Pre-existing failures in `test/services/bk2/scoreboard/` from Phase 38.9 STATE notes are not affected by this change (legacy karambol branch was untouched for the karambol/snooker/pool path).

## Deviations from Plan

None — plan executed exactly as written. Both Task 1 (RED) and Task 2 (GREEN) hit their predicted state on first run.

## SKILL extend-before-build attestation

- No new predicate method introduced (`no_innings_limit_phase` is an inline local variable, mirroring the pre-existing `no_followup_phase` local at line 1481).
- No refactor of `end_of_set?` — only an additive guard on an existing `elsif`.
- No parallel state machine — single execution flow preserved.
- Diff is +17 LOC of code (excluding comments + tests). Well under the SKILL's "small delta" threshold.

The pattern is identical to the pre-existing `no_followup_phase` local just above (line 1481-1485) — extends a phase-aware guard to one more existing branch using the same shape.

## Verification status

- **Automated:** GREEN. 30/30 in target test file, 8/8 in broader system regression suite.
- **Manual (deferred to post-tournament):**
  - Quick-game start a BK-2plus standalone match, play past 5 innings, confirm set stays open until a player reaches balls_goal.
  - Quick-game start a BK-2kombi match (first_set_mode=DZ), play DZ-Phase past 5 innings without balls_goal, confirm set stays open.
  - Quick-game start a BK-2kombi match into SP-Phase, play 5 innings each, confirm set DOES close (260501-uxo branch unchanged).

## Commits

- `5f9b3b14` test(quick-260503-hay): RED tests for BK-2plus / BK-2kombi DZ phase-blind legacy innings_goal close
- `12276841` fix(quick-260503-hay): exclude BK-2plus / BK-2kombi DZ from legacy innings_goal close

## Self-Check: PASSED

- File `test/models/table_monitor_test.rb` modified — verified by `git log`
- File `app/models/table_monitor.rb` modified — verified by `git log`
- Commit `5f9b3b14` exists in git log
- Commit `12276841` exists in git log
