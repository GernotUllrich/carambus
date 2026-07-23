---
phase: 38.9
plan: 01
created: 2026-05-01
type: deferred-discoveries
---

# Phase 38.9-01 — Deferred (Out-of-Scope) Discoveries

These pre-existing failures in `test/system/bk2_scoreboard_test.rb` were observed during the
Task 4 regression sweep but are **completely unrelated to Phase 38.9's `end_of_set?` fix**.
They were verified to be pre-existing by checking out `cfee5962` (the commit immediately
before Phase 38.9 work began) and re-running the suite: identical 6 failures + 13 errors.

Per the GSD scope-boundary rule, these are NOT auto-fixed by Phase 38.9. They should be
addressed by a future cleanup plan (likely a small phase or quick-task).

## Failures observed at HEAD (pre-existing, NOT caused by Phase 38.9)

`test/system/bk2_scoreboard_test.rb`: 58 runs / 268 assertions / 6 failures / 13 errors.

### Cluster A — `Bk2::CommitInning` removed in Phase 38.5 (test references stale)

| Test | Failure type |
|------|--------------|
| `test_I9a_38.4-07: set closes when player reaches balls_goal for BK-2 (I9 regression guard)` | `NameError: uninitialized constant Bk2::CommitInning` (test/system/bk2_scoreboard_test.rb:558) |
| `test_T-BK2kombi-SP_38.4-05: BK-2kombi in SP phase uses additive rule` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T8_38.3-01+04: SP positive inning commits additively to self (D-12)` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK50_38.4-05: BK50 additive scoring closes at balls_goal 50` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK2plus-pos_38.4-05: BK-2plus credits positive inning to current player` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK2plus-neg_38.4-05: BK-2plus opponent-credit for negative inning` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T11_38.4-07_I9: set closes when player reaches balls_goal (D-06 migration)` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK2kombi-DZ_38.4-05: BK-2kombi in DZ phase uses opponent-credit rule` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK100_38.4-05: BK100 additive scoring closes at balls_goal 100` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T10_38.3-01+04: DZ negative inning credits opponent on commit (D-11)` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T9_38.3-01+04: player at table flips after CommitInning` | `NameError: uninitialized constant Bk2::CommitInning` |
| `test_T-BK2-neg_38.4-05: BK-2 additive scoring keeps negative on player` | `NameError: uninitialized constant Bk2::CommitInning` |

**Root cause:** Phase 38.5 D-13 deleted `Bk2::CommitInning` (predicate-based dispatch
replaced the classed-based one). The system tests were not updated to follow.

### Cluster B — `BK2-Kombi` → `BK-2kombi` rename in Phase 38.6 (regex assertions stale)

| Test | Failure type |
|------|--------------|
| `test_Phase_38.5_D-11: BK-2kombi DZ -3 credits Spieler B end-to-end` | DOM/data assertion against pre-rename name |
| `test_T-P1-clamp-fallback-constant_38.4-13: BK_FAMILY_BALLZIEL_FALLBACK constant present` | Regex expects `"BK2-Kombi"`; controller has `"BK-2kombi"` |
| `test_T-P4-add-n-balls-bk-family-routes-through-bk2-commitinning_38.4-14` | DOM assertion against pre-rename name |
| `test_T-O8-no-dz-row_38.4-10: standalone DZ-max row removed; controller hardcodes dz_max=2 for BK-2plus and BK2-Kombi` | Regex expects `BK2-Kombi`; controller has `BK-2kombi` |
| `test_T-O4-protokoll-editor-accepts-equal_38.4-11: close_set_if_reached! has Nachstoß-aware branch` | DOM/data assertion against pre-rename name |
| `test_T-P1-fallback-mirrors-seed_38.4-13: BK_FAMILY_BALLZIEL_FALLBACK values match script/seed` | Regex expects `"BK2\-Kombi"`; controller has `"BK-2kombi"` |

**Root cause:** Phase 38.6 D-12 renamed `BK2-Kombi` → `BK-2kombi` and updated the controller
constant + most fixtures. These 6 system tests still reference the old name.

## Verification of pre-existence

```bash
# Run at commit cfee5962 (before any Phase 38.9 work):
git checkout cfee5962 -- app/models/table_monitor.rb test/models/table_monitor_test.rb
bin/rails test test/system/bk2_scoreboard_test.rb 2>&1 | tail -3
# Output: 58 runs, 268 assertions, 6 failures, 13 errors, 0 skips
# (identical numbers to HEAD)
```

## Recommended follow-up

Open a small cleanup quick-task (or a Phase 38.10 cleanup plan) that:

1. Audits `test/system/bk2_scoreboard_test.rb` for stale `Bk2::CommitInning` references and
   either removes those tests (the predicate replaced the class — many of these may be
   redundant with the existing `score_engine` unit tests) or rewrites them to dispatch via
   the new predicate path.
2. Replaces `BK2-Kombi` → `BK-2kombi` regex literals in the same file (6 occurrences).

Estimated scope: ~1 hour, single plan, no production code change required.

## Phase 38.9 SC-3 verification path

The plan's SC-3 is verified instead via:

- 21/21 `test/models/table_monitor_test.rb` GREEN (5 Plan 38.7-02 D-02 tests + 2 new Phase
  38.9 tests + the 14 baseline tests — see SUMMARY.md regression sweep section)
- 4/4 `test/system/tiebreak_test.rb` (Phase 38.7 SC-4 seal — preserves the tied-at-equal-
  innings tiebreak path that flows through the legacy karambol parity branch)
- 4/4 `test/system/final_match_score_operator_gate_test.rb` (Phase 38.8 regression seal)

The 19 pre-existing `bk2_scoreboard_test.rb` failures do not affect the SC-3 conclusion
because the new 4th branch in `end_of_set?` is gated on `bk_with_nachstoss && anstoss_at_goal &&
anstoss_innings >= 2` — none of the failing tests exercise that gate, and none touch
`end_of_set?` semantics (they all crash earlier on stale `Bk2::CommitInning` references or
fail on stale-name regexes).
