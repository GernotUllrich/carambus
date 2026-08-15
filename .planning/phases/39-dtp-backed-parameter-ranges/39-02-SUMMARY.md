---
phase: 39-dtp-backed-parameter-ranges
plan: 02
subsystem: controller
tags: [controller, parameter-ranges, refactor, dtp, system-test, cleanup]

# Dependency graph
requires:
  - phase: 39-dtp-backed-parameter-ranges
    plan: 01
    provides: "Discipline#parameter_ranges(tournament:) keyword-arg API + 8 tournament fixtures (local_fpk_class1, local_bk2kombi_non_dtp, local_handicap, local_no_plan, etc.)"
provides:
  - "Migrated production caller in tournaments_controller.rb#verify_tournament_start_parameters to parameter_ranges(tournament: tournament)"
  - "UI_07_FIELDS narrowed to %i[balls_goal innings_goal] (5 operator-input fields removed)"
  - "UI_07_SENTINEL_VALUES constant + sentinel guard line both deleted (dead code per D-12+D-13)"
  - "test/integration/tournament_verification_sentinels_test.rb deleted (7 tests of dead code per RQ-04)"
  - "test/system/tournament_parameter_verification_test.rb updated for keyword-arg signature + 3 new no-fire tests"
affects: ["Phase 39 closure: DATA-01 fully delivered; production tournament-start path unblocked"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Keyword-arg API migration: single production call site updated to parameter_ranges(tournament: tournament) — Plan 01's deliberate Wave-1/Wave-2 hand-off resolved."
    - "Dead-code cleanup of sentinel exemption: 13-line constant + 3-line guard + 107-line regression test all removed atomically."
    - "Deterministic system-test fixture lookup: replaced brittle dynamic Tournament.joins(:discipline).find { ... parameter_ranges&.any? } with tournaments(:local_fpk_class1) hard reference + raise-if-missing guards (Phase 39 contract requires all 4 lookup keys to match)."

key-files:
  created:
    - ".planning/phases/39-dtp-backed-parameter-ranges/39-02-SUMMARY.md"
  modified:
    - "app/controllers/tournaments_controller.rb (-27 LOC: UI_07_FIELDS reduced 9→2 entries; UI_07_SENTINEL_VALUES 13-line constant deleted; sentinel guard 3 lines deleted; production caller migrated to keyword-arg)"
    - "test/system/tournament_parameter_verification_test.rb (+59/-10 LOC: setup block replaced with deterministic fixture lookup; line 136 keyword-arg migration; 3 new no-fire tests for D-10/D-11/D-16f; obsolete DISCIPLINE_PARAMETER_RANGES comment replaced with Phase 39 explanation)"
  deleted:
    - "test/integration/tournament_verification_sentinels_test.rb (-106 LOC: 7 tests of dead UI_07_SENTINEL_VALUES exemption logic)"

key-decisions:
  - "Plan 01's deliberate Wave-1/Wave-2 production-deploy gate closed: tournaments_controller.rb:1008 now passes tournament: tournament — production tournament-start no longer raises ArgumentError on the parameter_ranges call."
  - "Sentinel guard removal is unconditional: with UI_07_FIELDS = %i[balls_goal innings_goal], the verifier never inspects sets_to_play/sets_to_win/timeout/warm-up fields, so the `next if (UI_07_SENTINEL_VALUES[field] || []).include?(value)` line is unreachable. No conditional retention needed."
  - "test/integration/tournament_verification_sentinels_test.rb deletion vs. refactor: per RQ-04 (orchestrator-locked), delete the entire file. The Struct doubles (FakeDiscipline, FakeTournament) and constant references would all need to be re-grounded against the 2-field UI_07_FIELDS, with no useful new test coverage emerging — refactoring would be a net-negative."
  - "System test setup uses tournaments(:local_fpk_class1) directly with raise-if-missing guards instead of skip — Phase 39 fixtures are MANDATORY and any test environment missing them indicates a broken setup, not a soft-skip condition."

requirements-completed: [DATA-01]

# Metrics
duration: 4min
completed: 2026-05-06
---

# Phase 39 Plan 02: Controller Migration + System Test Update Summary

**Closed Phase 39 by migrating the single production caller of `Discipline#parameter_ranges` to the new keyword-arg API, deleting the dead UI_07_SENTINEL_VALUES constant + its sentinel guard line + its 7-test integration regression file, narrowing UI_07_FIELDS from 7 to 2 entries, and updating the system test with deterministic Phase 39 fixtures plus 3 new no-fire test cases for non-DTP / handicap / no-plan tournaments.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-06T20:59:01Z
- **Completed:** 2026-05-06T21:02:56Z
- **Tasks:** 3
- **Files touched:** 3 (1 modified, 1 modified, 1 deleted)
- **Net LOC delta:** -181 LOC removed (sentinel constant + guard + integration test) / +59 LOC added (3 new system tests + setup deterministic-fixture rewiring) → **-122 net LOC**

## Accomplishments

- **Controller migration complete:** `tournaments_controller.rb#verify_tournament_start_parameters` now calls `parameter_ranges(tournament: tournament)` (D-01). Plan 01's deliberate Wave-1/Wave-2 production-deploy gate is now closed — production tournament-start path no longer raises `ArgumentError: missing keyword: :tournament`.
- **UI_07_FIELDS narrowed to 2 entries** (D-12): `%i[balls_goal innings_goal]`. Removed `timeout`, `time_out_warm_up_first_min`, `time_out_warm_up_follow_up_min`, `sets_to_play`, `sets_to_win` — all operator-input fields from the Turnier-Einladung that have no master-data backing and should never have been system-verified.
- **UI_07_SENTINEL_VALUES + sentinel guard fully deleted** (D-13/D-15): 13-line constant block + 3-line `next if (UI_07_SENTINEL_VALUES[field] || []).include?(value)` guard inside `verify_tournament_start_parameters`. Both became unreachable dead code after D-12.
- **test/integration/tournament_verification_sentinels_test.rb deleted** (RQ-04): 7 tests of dead UI_07_SENTINEL_VALUES exemption logic. The file's `FakeDiscipline` / `FakeTournament` Struct doubles + `RANGES` constant + 6 test methods all referenced behavior that is no longer code-reachable after Plan 02 Task 1.
- **System test rewired for Phase 39 contract** (D-17): setup block now uses deterministic `tournaments(:local_fpk_class1)` instead of dynamic `Tournament.joins(:discipline).find { ... parameter_ranges&.any? }` — required because Phase 39 ranges depend on all 4 lookup keys (discipline, plan, players, class) matching, not just discipline. Existing 4 tests + 3 new no-fire tests = 7 total.
- **Cross-repo regression sweep clean:** `grep -rn "DISCIPLINE_PARAMETER_RANGES\|UI_07_SHARED_RANGES\|UI_07_DISCIPLINE_SPECIFIC_RANGES\|UI_07_SENTINEL_VALUES" app/ test/` returns 0 matches (Plan 01 cleaned model side, Plan 02 cleaned controller + test sides).
- **Test suite GREEN:** `bin/rails test test/controllers test/models test/integration` returns 757 runs, 2056 assertions, 0 failures, 0 errors, 8 pre-existing skips. All Phase 38.x BK-family + tiebreak tests remain GREEN.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate `tournaments_controller.rb`** — `6bafba88` (refactor): UI_07_FIELDS reduced 9→2, UI_07_SENTINEL_VALUES + sentinel guard deleted, parameter_ranges call site migrated to keyword-arg form.
2. **Task 2: Delete `tournament_verification_sentinels_test.rb`** — `169b0ea6` (test): -107 LOC, 7 tests of dead code removed.
3. **Task 3: Update `tournament_parameter_verification_test.rb`** — `d8a92a57` (test): setup deterministic fixture lookup, line 136 keyword-arg migration, 3 new no-fire tests, comment refresh.

## Files Created/Modified

### `app/controllers/tournaments_controller.rb` (modified, commit `6bafba88`)

**A. Lines 21-48 (28 LOC) replaced with lines 21-30 (10 LOC):**
- Old: `UI_07_FIELDS = %i[balls_goal innings_goal timeout time_out_warm_up_first_min time_out_warm_up_follow_up_min sets_to_play sets_to_win].freeze` (7 entries) + 13-line `UI_07_SENTINEL_VALUES = {...}.freeze` block.
- New: 6-line Phase-39 D-12 explanatory comment + `UI_07_FIELDS = %i[balls_goal innings_goal].freeze` (2 entries). UI_07_SENTINEL_VALUES gone entirely.

**B. Line 1008 (production caller):**
- Old: `ranges = tournament.discipline&.parameter_ranges || {}`
- New: `ranges = tournament.discipline&.parameter_ranges(tournament: tournament) || {}`

**C. Lines 1037-1039 (sentinel guard, 3 lines) deleted:**
- Old: 2-line comment + `next if (UI_07_SENTINEL_VALUES[field] || []).include?(value)`
- New: removed entirely. The `next if range.cover?(value)` line that followed remains.

### `test/integration/tournament_verification_sentinels_test.rb` (DELETED, commit `169b0ea6`)

107 lines / 7 tests / 1 Struct double pair (FakeDiscipline + FakeTournament) / 1 RANGES constant. All testing dead code per D-13.

### `test/system/tournament_parameter_verification_test.rb` (modified, commit `d8a92a57`)

**A. Setup block (lines 28-32 → 28-34):** dynamic `Tournament.joins(:discipline).find { ... parameter_ranges&.any? }` replaced with deterministic `tournaments(:local_fpk_class1)` lookup + raise-if-missing guards (Phase 39 contract requires all 4 lookup keys to match).

**B. Line 133 → 136 (Test 4 in-range value derivation):** `parameter_ranges` → `parameter_ranges(tournament: @tournament)`.

**C. Comment block at lines 131-132 → 133-135:** obsolete `DISCIPLINE_PARAMETER_RANGES` reference replaced with Phase 39 DTP-derivation explanation (range = 187..250 from FPK class 1 / plan t04_5 / 5 players, points=250).

**D. 3 new no-fire tests appended at end of class (before closing `end`):**
- `test "non-DTP discipline (BK-2kombi) skips verification entirely"` — D-10. Uses `tournaments(:local_bk2kombi_non_dtp)` (BK-2kombi has no DTP rows → parameter_ranges returns {} → modal MUST NOT appear).
- `test "handicap_tournier=true tournament skips verification entirely"` — D-11. Uses `tournaments(:local_handicap)`.
- `test "tournament without tournament_plan skips verification (defensive)"` — D-16(f). Uses `tournaments(:local_no_plan)`.

Each new test fills balls_goal=99999 (would have tripped the old hardcoded ranges) and asserts the modal does NOT appear (`assert_no_text verification_title`) plus the tournament_monitor URL pattern is hit.

**Final system test count: 7** (4 existing rewired + 3 new no-fire).

## Decisions Made

- **Sentinel-guard removal is unconditional, not conditional:** With UI_07_FIELDS = %i[balls_goal innings_goal], the verifier's `each_with_object` loop only iterates these two fields. The sentinel guard `next if (UI_07_SENTINEL_VALUES[field] || []).include?(value)` would have looked up `UI_07_SENTINEL_VALUES[:balls_goal]` and `UI_07_SENTINEL_VALUES[:innings_goal]` — both keys absent, both lookups returning [], the `include?(value)` always false. The guard is unreachable for any value of `value`. Deletion is safe; no conditional retention warranted.
- **Integration test file deletion (vs. refactor):** Per RQ-04. The file's structural elements (FakeDiscipline/FakeTournament Struct doubles, RANGES constant mirroring UI_07_SHARED_RANGES, 6 test methods asserting sets_to_play=0/999 + sets_to_win=0 exemptions) all rest on UI_07_FIELDS containing those fields. After Task 1, none of the asserted behavior is code-reachable. Refactoring would require rewriting every test from scratch; deletion is the honest choice.
- **System test setup uses raise (not skip) on fixture-missing:** Phase 39 fixtures (`local_fpk_class1`, etc.) are MANDATORY for the system test contract. A test environment missing them is a broken setup, not a soft-skip condition. The two `raise` lines fail loudly so misconfigured test environments produce diagnostic errors instead of silently passing.
- **3 new no-fire tests use service-level dispatch (no Selenium):** Following the project pattern (see Phase 38.x BK system tests at `test/system/bk2_scoreboard_test.rb` Phase 38.5/38.6), the 3 new tests rely on the existing `visit_monitor_or_skip` helper + `fill_balls_goal` / `click_start_button` setup that the file already establishes. The skip-on-500 fallback is preserved so a pre-existing fixture/view error doesn't cascade into the new tests.

## Deviations from Plan

**1. [Rule 1 - Pre-existing standardrb noise on tournaments_controller.rb] Pre-existing layout warnings on unmodified code**
- **Found during:** Task 1 verification.
- **Issue:** `bundle exec standardrb app/controllers/tournaments_controller.rb` reports many `Layout/MultilineMethodCallIndentation` and `Layout/ArrayAlignment` warnings on lines 8-11, 94, 98, 174, 176, 296, 532, 631, 770, 816, 851, 928, 977-984, 1077-1080, 1106-1107, 1118-1123, 1141 — all on code I did NOT modify in this plan.
- **Fix:** None — these are pre-existing warnings (verified by checking that all reported line ranges fall outside my edits at lines 21-30 and 1007-1019). Plan AC says "passes (or no new lints introduced)" — no new lints in my touched lines.
- **Files modified:** None (no fix needed).
- **Verification:** Plan AC line "no new lints introduced" satisfied; my edits at lines 21-30 + 1007-1019 produce zero standardrb warnings.

**2. [No deviation - perfect plan execution otherwise]** All other ACs hit exactly: UI_07_FIELDS.size=2, UI_07_SENTINEL_VALUES=GONE, parameter_ranges(tournament: tournament) call site count=1, parameter_ranges&?.any? count=0, DISCIPLINE_PARAMETER_RANGES references=0 across app/ + test/, 7 test methods in system test, 3 new no-fire tests, 4 fixture references.

---

**Total deviations:** 1 documented (pre-existing standardrb noise on unmodified lines — non-blocking per AC wording).
**Impact on plan:** Zero scope creep. All code changes are pixel-perfect against the plan's `<action>` blocks.

## Issues Encountered

- **Phase 38.x test surface preserved:** Confirmed via `bin/rails test test/controllers test/models test/integration` — 757 runs / 2056 assertions / 0 failures / 0 errors / 8 pre-existing skips. The 8 skips are pre-existing (e.g., test/models/tournament_ko_integration_test.rb:112 "Test is missing assertions"). None are regressions from this plan.
- **System test (Capybara/Selenium) NOT executed in this plan:** Plan AC's verification block lists `bin/rails test test/controllers test/models test/integration` as the canonical run; system tests require Selenium/ChromeDriver and are out of CI scope. The system test edits are statically verified by the AC grep checks (parameter_ranges keyword-arg count, tournament fixture refs, test count, etc.). Future human UAT or system test run can confirm end-to-end Selenium behavior.

## User Setup Required

None — no external service configuration changes.

## Next Phase Readiness

**Phase 39 is now COMPLETE (2/2 plans, DATA-01 delivered).** No follow-up work in scope. Production deploy is unblocked: the parameter_ranges call site is now correct, the verification modal will fire on out-of-range balls_goal / innings_goal for matched DTP rows AND will skip non-DTP / handicap / no-plan / blank-class / zero-canonical configurations entirely.

Phase 39 closure cleanups:
- ROADMAP.md Phase 39 row "Plans Complete" updates from `1/2` to `2/2`.
- REQUIREMENTS.md DATA-01 marked Complete in traceability table.
- STATE.md current_plan advances; status flips appropriately.

Per `roadmap update-plan-progress` execution.

## Threat Flags

None. Plan was a controller method-body migration (parameter pass-through, single call site) + 3 file edits / 1 file deletion across the test surface. No new HTTP entry points, no auth changes, no schema changes, no new write paths. Threat model T-39-03 (Tampering on verifier) and T-39-04 (Information disclosure on verifier error paths) and T-39-05 (DoS on DTP query) all remain `accept` per the planned register.

## Self-Check: PASSED

- File `.planning/phases/39-dtp-backed-parameter-ranges/39-02-SUMMARY.md` exists.
- Commit `6bafba88` (Task 1: controller migration) exists.
- Commit `169b0ea6` (Task 2: integration test deletion) exists.
- Commit `d8a92a57` (Task 3: system test update) exists.
- File `app/controllers/tournaments_controller.rb` exists in master with `parameter_ranges(tournament: tournament)` at line 1008.
- File `test/integration/tournament_verification_sentinels_test.rb` no longer exists.
- File `test/system/tournament_parameter_verification_test.rb` exists with 7 test methods.

---
*Phase: 39-dtp-backed-parameter-ranges*
*Completed: 2026-05-06*
