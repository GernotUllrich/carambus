# Phase 38.5 Plan 06 — Deferred Items

## Out-of-scope test failures discovered during Plan 06 verification

The following pre-existing test errors in `test/system/bk2_scoreboard_test.rb`
were observed when running the full file but are NOT introduced by Plan 06.
They reference `Bk2::CommitInning` (constant removed in commit `4c3abdf4` —
"refactor(38.4): Bk2::CommitInning calls karambol_commit_inning! internally —
single source at boundary"). The 35-test suite still has 9 tests calling the
removed constant.

Tests that error with `NameError: uninitialized constant Bk2::CommitInning`:
- T8 38.3-01+04: SP positive inning commits additively to self (D-12)
- T9 38.3-01+04: player_at_table flips after CommitInning
- T10 38.3-01+04: DZ negative inning credits opponent on commit (D-11)
- T11 38.4-07 I9: set closes when player reaches balls_goal
- I9a 38.4-07: set closes when player reaches balls_goal for BK-2
- I9b 38.4-07: set does NOT close below balls_goal for BK-2
- T-BK50 38.4-05: BK50 additive scoring closes at balls_goal 50
- T-BK100 38.4-05: BK100 additive scoring closes at balls_goal 100
- T-BK2plus-neg 38.4-05: BK-2plus opponent-credit for negative inning
- T-BK2plus-pos 38.4-05: BK-2plus credits positive inning to current player
- T-BK2-neg 38.4-05: BK-2 additive scoring keeps negative on player
- T-BK2kombi-DZ 38.4-05: BK-2kombi in DZ phase uses opponent-credit rule
- T-BK2kombi-SP 38.4-05: BK-2kombi in SP phase uses additive rule

**Why deferred:** Per Plan 06 scope boundary (rule "Only auto-fix issues DIRECTLY
caused by the current task's changes"), these are out of scope. They are
pre-existing and should be addressed in a separate phase or quick-task focused
on test-suite hygiene.

**Recommended fix:** Update the 9 tests to use the actual current entry point
(likely `tm.add_n_balls(...)` which routes BK-family-with-nachstoss through the
karambol path per commit `4c3abdf4`), or restore a `Bk2::CommitInning` shim
that delegates. A future phase or quick task can investigate.

