---
phase: 39-dtp-backed-parameter-ranges
plan: 01
subsystem: testing
tags: [discipline, parameter-ranges, refactor, dtp, fixtures, minitest, rails-7.2]

# Dependency graph
requires:
  - phase: 38-ux-polish-i18n-debt
    provides: "G-06 DATA-01 widening hint (Phase 36B D-17 hardcoded ranges)"
  - phase: 38.6-discipline-master-data-cleanup
    provides: "Canonical 5 BK-* discipline records (BK-2kombi/BK50/BK100/BK-2/BK-2plus) — none have DTP rows; D-10 short-circuit relies on this"
provides:
  - "Discipline#parameter_ranges(tournament:) DTP-backed keyword-arg method"
  - "PLAYER_CLASS_ORDER constant (D-04, walk worst→best)"
  - "REDUCED_FACTOR constant (D-07, 0.75 lenient-OR factor)"
  - "5 DTP fixture rows + 8 tournament fixtures + 41 seeding fixtures"
  - "9 D-16/RQ-driven test cases for new method (replaces 8 old constant-based tests)"
affects: ["39-02 (controller migration + sentinels deletion + system test)"]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DTP-backed lookup with class-walk fallback (D-05): exact match first, then walk PLAYER_CLASS_ORDER toward stricter classes."
    - "Lenient-OR Range derivation (D-08): ((canonical * 0.75).floor..canonical), nil on canonical==0 (Cup-series)."
    - "6 early-return {} branches: handicap, no plan, blank class, DTP miss, walk exhaustion, zero-canonical."

key-files:
  created:
    - "test/fixtures/discipline_tournament_plans.yml"
  modified:
    - "app/models/discipline.rb (replaces 51 lines of constants + method body with 65 LOC of method + 2 helpers + 2 constants)"
    - "test/fixtures/tournaments.yml (+8 tournament fixtures, IDs 50_000_200..50_000_207)"
    - "test/fixtures/seedings.yml (+41 ERB-driven seedings, IDs 50_000_300..50_000_405)"
    - "test/models/discipline_test.rb (-8 old tests + helper + constant; +9 D-16/RQ tests)"

key-decisions:
  - "Ranges returned as native Ruby Range; nil sentinels for absent fields; entire {} when no DTP data."
  - "PLAYER_CLASS_ORDER lives as a Discipline constant (D-04); deferred PlayerClass#order_index migration."
  - "REDUCED_FACTOR=0.75 (Phase 38 D-20 was 0.80 — corrected per CONTEXT.md D-07: standard practice is 80/20 → 60/15 = 0.75)."
  - "Plan AC text says 'exactly 8 tests' but the prescribed action lists 8 D-16/RQ + 1 defensive regression = 9. Followed the action verbatim — 9 tests landed."
  - "private/public sectioning chosen over inline `private :method` (matches majority Ruby idiom + the file already used neither — the section style is cleaner for the 2-helper extraction)."

patterns-established:
  - "ERB-driven seeding fixtures: each_with_index loop generates 35 normal + 6 zero-canonical seedings without manually expanding 41 YAML entries."
  - "Test-only DTP fixtures land in global ID range (id < 50_000_000) — test DB rebuild is fixture-driven, no LocalProtector concerns."

requirements-completed: [DATA-01]

# Metrics
duration: 7min
completed: 2026-05-06
---

# Phase 39 Plan 01: DTP-Backed Parameter Ranges Summary

**Replaced hardcoded `Discipline::DISCIPLINE_PARAMETER_RANGES` with DTP-backed `Discipline#parameter_ranges(tournament:)` keyword-arg method that queries discipline_tournament_plans by (discipline, plan, players, class) with class-walk fallback and lenient-OR Range derivation, landed 5 DTP + 8 tournament + 41 seeding fixtures and 9 D-16/RQ test cases atomically.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-05-06T20:47:10Z
- **Completed:** 2026-05-06T20:53:54Z
- **Tasks:** 3
- **Files modified:** 4 (1 created, 3 extended/rewritten)

## Accomplishments

- DTP-backed `parameter_ranges(tournament:)` shipped with 6 explicit early-return `{}` branches covering D-05/D-10/D-11/D-16f/RQ-01/RQ-03 — no caller-visible changes needed in Plan 01 (`tournaments_controller.rb#verify_tournament_start_parameters` will be migrated in Plan 02).
- 3 hardcoded constants deleted (`UI_07_SHARED_RANGES`, `UI_07_DISCIPLINE_SPECIFIC_RANGES`, `DISCIPLINE_PARAMETER_RANGES`) plus their D-17 + 2026-04-27-widening comments — 51 lines removed.
- 2 new constants added (`PLAYER_CLASS_ORDER`, `REDUCED_FACTOR`) with Discipline-namespaced D-04/D-07 traceability comments.
- 2 private helpers extracted (`lookup_dtp_with_class_walk`, `range_from_canonical`) — 30 LOC of focused logic, no parallel resolver service (extend-before-build SKILL honored).
- All 22 tests in `discipline_test.rb` GREEN: 9 new parameter_ranges tests + 14 untouched BK-family/KARAMBOL_DISCIPLINE_MAP/nachstoss_allowed?/T-P5 regression tests.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add DTP fixtures + extend tournaments/seedings fixtures** — `aace404c` (test)
2. **Task 2: Refactor `Discipline#parameter_ranges` to DTP-backed keyword-arg method** — `c98fb5a3` (refactor)
3. **Task 3: Rewrite `parameter_ranges` test block in `discipline_test.rb`** — `66833fb6` (test)

## Files Created/Modified

- `test/fixtures/discipline_tournament_plans.yml` (CREATED) — 5 DTP rows for D-16(a)/(b)/(c)/(d)/RQ-01 cases (FPK class 1/3/II for plan t04_5; FPK zero-canonical for plan t06_6; carom_3band class 1 to prove walk does not cross discipline boundaries).
- `test/fixtures/tournaments.yml` (EXTENDED) — 8 new tournament fixtures (`local_fpk_class1`, `local_fpk_class5_walks_to_3`, `local_carom_classIII_walk_miss`, `local_handicap`, `local_no_plan`, `local_fpk_zero_canonical`, `local_fpk_blank_class`, `local_bk2kombi_non_dtp`), IDs 50_000_200..50_000_207.
- `test/fixtures/seedings.yml` (EXTENDED) — 41 ERB-driven seedings: 5 per tournament for the 7 t04_5-based fixtures (35) + 6 for the t06_6 zero-canonical fixture; IDs 50_000_300..50_000_369 + 50_000_400..50_000_405.
- `app/models/discipline.rb` (REFACTORED) — Lines 51-101 replaced. 3 constants deleted (UI_07_SHARED_RANGES, UI_07_DISCIPLINE_SPECIFIC_RANGES, DISCIPLINE_PARAMETER_RANGES). 2 constants added (PLAYER_CLASS_ORDER, REDUCED_FACTOR). 1 method body replaced (parameter_ranges no-arg → parameter_ranges(tournament:)). 2 private helpers added (lookup_dtp_with_class_walk, range_from_canonical). Public marker restored at line 119.
- `test/models/discipline_test.rb` (REWRITTEN) — Deleted: UI_07_EXPECTED_KEYS constant (9 LOC), freie_partie_fixture helper (9 LOC), 4 old parameter_ranges tests (43 LOC), 2 anchor tests referencing deleted constant (16 LOC). Inserted: 9 new parameter_ranges tests (D-16 a-f + RQ-01 + RQ-03 + defensive regression) at top of class body. Untouched: BK2_DISCIPLINE_MAP, bk_family?, ballziel_choices, BK2_FREE_GAME_FORMS, KARAMBOL_DISCIPLINE_MAP regression-snapshot, nachstoss_allowed?, T-P5 seed-replay tests.

## Decisions Made

- **Method composition (D-01 / Researcher's recommended pattern):** Single public entry `parameter_ranges(tournament:)` with 6 early-return guards, dispatching to 2 private helpers (`lookup_dtp_with_class_walk` for D-05 walk, `range_from_canonical` for D-08 lenient-OR + RQ-01 zero-canonical). 30 LOC of focused logic, no abstraction beyond the 2 helpers — extend-before-build SKILL upheld.
- **`private`/`public` section markers:** Existing Discipline class doesn't use sections — methods are top-level. Inserted `private` after `parameter_ranges` and `public` before `TRANSLATIONS` to scope only the 2 helpers as private; everything before and after stays public exactly as before.
- **9 tests landed (not 8):** Plan AC text said "exactly 8" but the prescribed `<action>` listed 8 typed cases + 1 defensive regression = 9. The action is the authoritative source — landed 9.
- **standardrb auto-fix accepted on test file:** Removed parens around Range arguments to `assert_equal` (e.g., `assert_equal((187..250), foo)` → `assert_equal(187..250, foo)`), removed extra spaces, removed trailing blank line. Tests still GREEN (22/22) — the parens were not load-bearing for Ruby parsing because of the trailing comma.
- **No FactoryBot — fixtures only:** Per CLAUDE.md project convention + Researcher Finding 2.

## Deviations from Plan

**1. [Rule 1 - Pre-existing FK in fixtures] `wc_2024` fixture references nonexistent international_source ID via fixture-relation hashing**
- **Found during:** Task 1 verification (post-edit DB load smoke test).
- **Issue:** `bin/rails runner -e test 'create_fixtures(...)'` raised PG::ForeignKeyViolation on `tournaments.international_source_id` for the existing `wc_2024` (id 50_002_001) and `wc_no_end_date` (id 50_002_002) fixtures. They use the `international_source: youtube_source` fixture-relation syntax which Rails hashes to ID 255386517, but `international_sources.yml` wasn't included in my smoke-test load list.
- **Fix:** None needed — the issue was in MY ad-hoc test load (I omitted `international_sources` from the explicit fixture list). Adding it to the load list resolved the error. The actual project test DB rebuild (via `bin/rails db:test:prepare` or full `bin/rails test test/models/discipline_test.rb`) loads ALL fixtures and works correctly. **No code change required.**
- **Files modified:** None (smoke-test artifact only).
- **Verification:** `bin/rails test test/models/discipline_test.rb` runs all 22 tests with all fixtures loaded, 0 failures, 0 errors.
- **Committed in:** N/A (no fix needed).

**2. [Rule 1 - Plan AC text vs. action mismatch] Plan AC says "exactly 8 tests" but action prescribes 8 + 1 defensive = 9**
- **Found during:** Task 3 verification.
- **Issue:** Plan AC line says `grep -c "test \"parameter_ranges " test/models/discipline_test.rb` returns exactly 8 (the new D-16+RQ tests; one regression test). But the parenthetical "one regression test" implies 9 total (8 typed + 1 regression). The action body explicitly INSERTs all 9.
- **Fix:** Followed the action verbatim — 9 tests landed. AC literal "8" interpreted as a typo for "9" since the parenthetical clarifies "one regression test" is included.
- **Files modified:** `test/models/discipline_test.rb`.
- **Verification:** All 9 parameter_ranges tests pass; 22/22 total file tests GREEN.
- **Committed in:** `66833fb6`.

**3. [Rule 1 - standardrb auto-fix] Auto-fix accepted on `app/models/discipline.rb` and `test/models/discipline_test.rb`**
- **Found during:** Task 2 + Task 3 post-edit lint runs.
- **Issue:** Plan-prescribed code had `Layout/ExtraSpacing` (alignment of `=` in 4 places), `Layout/MultilineMethodCallIndentation` (15-space indentation under `discipline_tournament_plans`), and `Style/RedundantParentheses` (parens around Range literal in `assert_equal`).
- **Fix:** `bundle exec standardrb --fix` on each file. Tests still GREEN (22/22), method signature still `[[:keyreq, :tournament]]`, all acceptance criteria still pass.
- **Files modified:** `app/models/discipline.rb`, `test/models/discipline_test.rb`.
- **Verification:** standardrb lint clean for both files (one pre-existing line 249 warning in discipline.rb is untouched — `Style/RedundantInterpolation` from Phase 38.6).
- **Committed in:** `c98fb5a3` (model) and `66833fb6` (tests).

**4. [Rule 3 - Pre-edit cross-checkout cleanup] carambus_master was 2 behind origin/master, carambus_bcw 2 ahead with unpushed Phase 39 planning commits**
- **Found during:** Pre-execution scenario-management cleanliness check.
- **Issue:** Per CLAUDE.md scenario-management rule, all 4 checkouts must be clean wrt master before edits begin. bcw had 2 unpushed planning commits (Phase 39); master + phat + api were 2 behind origin/master.
- **Fix:** `git push origin master` from bcw, then `git pull --ff-only` in master + phat + api to align everyone with origin/master at commit `87bbdba7`.
- **Files modified:** None (git remote sync only).
- **Verification:** `git status` clean across all 4 checkouts; `git log` shows all 4 at `87bbdba7` before Task 1 starts.

---

**Total deviations:** 4 documented (1 smoke-test artifact, 1 AC text-vs-action arithmetic, 1 standardrb cosmetics, 1 cross-checkout sync).
**Impact on plan:** No scope creep. All deviations are book-keeping or stylistic. The model logic, test cases, and fixture content are pixel-perfect against the plan's `<action>` blocks.

## Issues Encountered

- **Old tests + Task-3-not-yet-applied + caller-not-yet-migrated produces RED state between Task 2 and Task 3:** This is a deliberate plan-level decision (Plan 01 ships a model+test rewrite atomically; Plan 02 ships the controller migration + sentinels deletion + system-test update). After Task 2 ran, `bin/rails test test/models/discipline_test.rb` showed 5 errors + 1 failure on the OLD tests calling no-arg `parameter_ranges`. After Task 3 these flipped to GREEN. Production caller `tournaments_controller.rb:1026` still calls `parameter_ranges` (no-arg), which will RAISE on tournament-start until Plan 02 lands. **Plan 39-02 MUST land before any production deploy.**

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

**Plan 39-02 (controller migration + sentinels deletion + system test) is unblocked and MUST land in Wave 2.** It will:
1. Update `tournaments_controller.rb:1026` from `parameter_ranges` to `parameter_ranges(tournament: tournament)` (D-01).
2. Reduce `UI_07_FIELDS` to `%i[balls_goal innings_goal]` (D-12).
3. Delete `UI_07_SENTINEL_VALUES` constant (D-13) + the dead-code references at line 1039.
4. Delete `test/integration/tournament_verification_sentinels_test.rb` entire file (RQ-04).
5. Update `test/system/tournament_parameter_verification_test.rb:31, 133` to new keyword-arg signature (D-17).
6. Add new system-test cases for Pool/BK/handicap → modal does NOT fire.

Until Plan 39-02 ships, **production tournament-start will RAISE `ArgumentError: missing keyword: :tournament`** at `app/models/discipline.rb:69`. This is the deliberate Wave-1/Wave-2 hand-off.

## Threat Flags

None. Plan was a read-side AR-query refactor over an existing global-record table; no new HTTP entry points, no new auth surface, no schema changes. Threat model T-39-01 (information disclosure) and T-39-02 (test fixture tampering) both remain `accept` per the planned register.

## Self-Check: PASSED

- File `test/fixtures/discipline_tournament_plans.yml` exists.
- File `.planning/phases/39-dtp-backed-parameter-ranges/39-01-SUMMARY.md` exists.
- Commit `aace404c` (Task 1: fixtures) exists.
- Commit `c98fb5a3` (Task 2: model refactor) exists.
- Commit `66833fb6` (Task 3: tests) exists.

---
*Phase: 39-dtp-backed-parameter-ranges*
*Completed: 2026-05-06*
