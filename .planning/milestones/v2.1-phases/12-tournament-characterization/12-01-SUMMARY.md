---
phase: 12-tournament-characterization
plan: "01"
subsystem: testing
tags: [minitest, aasm, tournament, characterization, dynamic-attributes, tournament-local]

# Dependency graph
requires: []
provides:
  - Tournament AASM state machine characterization (28 tests covering all 8 events, guards, callbacks)
  - Tournament dynamic attribute delegation characterization (25 tests covering all 4 getter/setter paths)
affects: [13-tournament-extraction, 14-tournament-extraction-2, 15-tournament-extraction-3]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "clear_user_context helper: reset User.current AND PaperTrail.request.whodunnit after any save! call to ensure guard methods see no user"
    - "update_columns(data: Hash) for serialized JSON columns — update_column with string raises SerializationTypeMismatch"
    - "save!(validate: false) + clear_user_context for creating test fixtures in AASM characterization tests"

key-files:
  created:
    - test/models/tournament_aasm_test.rb
    - test/models/tournament_attributes_test.rb
  modified: []

key-decisions:
  - "reset_tournament does NOT clear data for local tournaments (id > Seeding::MIN_ID = 50_000_000) — the data-reset block is skipped; only global records (id <= MIN_ID) get data cleared"
  - "auto_upload_to_cc IS present on tournament_locals schema (column confirmed via TournamentLocal.column_names) — plan research based on outdated schema annotation was incorrect; all 13 define_method attributes work identically"
  - "PaperTrail.request.whodunnit is set to empty string by save! callbacks — must be cleared after every create to prevent admin_can_reset_tournament? guard from treating empty string as a non-blank user"

patterns-established:
  - "TournamentAasmTest::AASM_TEST_ID_BASE = 50_100_000, TournamentAttributesTest::ATTR_TEST_ID_BASE = 50_150_000 — separate ID bases per test file to avoid cross-file collisions"
  - "update_column(:state, 'state_name') to set AASM state without triggering callbacks, then call bang event"

requirements-completed: [CHAR-05, CHAR-07]

# Metrics
duration: 30min
completed: 2026-04-10
---

# Phase 12 Plan 01: Tournament AASM and Dynamic Attribute Characterization Summary

**53 characterization tests pinning Tournament AASM state machine (8 events, 2 guards, 2 callbacks) and all 13 dynamic define_method getter/setter paths before extraction work begins**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-04-10T22:00:00Z
- **Completed:** 2026-04-10T22:00:33Z
- **Tasks:** 2
- **Files modified:** 2 created

## Accomplishments

- 28 AASM tests covering all 8 events (finish_seeding, finish_mode_selection, start_tournament, signal_tournament_monitors_ready, finish_tournament, have_results_published, reset_tmt_monitor, forced_reset_tournament_monitor), both guards, both after_enter callbacks, and skip_validation_on_save
- 25 attribute delegation tests covering all 4 getter paths (local, global+tol, global-no-tol, new) and all 4 setter paths (new record, global creates tol, global updates tol, local) for all 13 attributes
- Discovered and characterized key behavioral nuances: data-reset scope, PaperTrail context contamination, auto_upload_to_cc schema correctness

## Task Commits

Each task was committed atomically:

1. **Task 1: Tournament AASM state machine characterization** - `ecbf1133` (test)
2. **Task 2: Dynamic attribute delegation characterization** - `cf8dcb79` (test)

**Plan metadata:** (see final commit below)

## Files Created/Modified

- `test/models/tournament_aasm_test.rb` - 28 AASM tests: state transitions, guards, callbacks, skip_validation_on_save
- `test/models/tournament_attributes_test.rb` - 25 tests: all getter/setter paths for 13 dynamic attributes including auto_upload_to_cc

## Decisions Made

- **PaperTrail context contamination:** `save!(validate: false)` triggers PaperTrail callbacks that set `whodunnit = ""`. A `clear_user_context` helper resets both `User.current` and `PaperTrail.request.whodunnit` after every save to prevent `admin_can_reset_tournament?` from treating `""` as a non-blank user.
- **data-reset scope:** `reset_tournament` only resets `data` for tournaments where `id <= Seeding::MIN_ID`. Local tournaments (id > 50_000_000) skip the reset block — this is the characterized behavior.
- **auto_upload_to_cc schema:** The actual `tournament_locals` table includes `auto_upload_to_cc` — the plan's research was based on an outdated schema annotation. The column exists and all 13 attributes behave identically.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected auto_upload_to_cc characterization — column exists on TournamentLocal**
- **Found during:** Task 2 (tournament_attributes_test.rb)
- **Issue:** Plan stated auto_upload_to_cc was NOT in TournamentLocal schema. Runtime confirmed it IS present.
- **Fix:** Replaced assert_raises(ActiveModel::UnknownAttributeError) tests with correct passing-behavior tests
- **Files modified:** test/models/tournament_attributes_test.rb
- **Verification:** `TournamentLocal.column_names.include?("auto_upload_to_cc")` => true; all 25 tests pass
- **Committed in:** cf8dcb79 (Task 2 commit)

**2. [Rule 1 - Bug] Corrected data-reset test — local tournaments do NOT get data cleared by reset_tournament**
- **Found during:** Task 1 (tournament_aasm_test.rb)
- **Issue:** Plan expected `data = {}` after reset for local tournaments; actual code skips the reset block for `id > Seeding::MIN_ID`
- **Fix:** Changed assertion to pin the actual behavior (data preserved for local tournaments)
- **Files modified:** test/models/tournament_aasm_test.rb
- **Verification:** Test passes; code path confirmed in tournament.rb:857
- **Committed in:** ecbf1133 (Task 1 commit)

**3. [Rule 1 - Bug] Fixed PaperTrail whodunnit contamination breaking admin_can_reset_tournament? guard**
- **Found during:** Task 1 (guard tests)
- **Issue:** After `save!(validate: false)`, PaperTrail sets `whodunnit = ""`. The guard `admin_can_reset_tournament?` checks `User.current || PaperTrail.request.whodunnit` — with whodunnit set, guard returned nil/false instead of true
- **Fix:** Added `clear_user_context` helper called after every `save!` to reset both User.current and PaperTrail whodunnit
- **Files modified:** test/models/tournament_aasm_test.rb
- **Verification:** All guard tests pass; admin_can_reset_tournament? returns true with no user context
- **Committed in:** ecbf1133 (Task 1 commit)

---

**Total deviations:** 3 auto-fixed (all Rule 1 - Bug: incorrect plan research / environment side-effects)
**Impact on plan:** All fixes necessary for characterization correctness. Tests pin actual behavior, not assumed behavior.

## Issues Encountered

- `assert_nothing_raised { ... }, "message"` syntax rejected by Ruby parser — trailing comma after block. Fixed by moving message inside or removing it.
- `update_column(:data, hash.to_json)` raises `SerializationTypeMismatch` — the `serialize :data, coder: JSON, type: Hash` column requires a Hash value via `update_columns`, not a pre-serialized string.
- `Tournament.id < MIN_ID` setter uses `id < MIN_ID` not `id >= MIN_ID` — the setter creates tournament_local when `id < MIN_ID` (global records), uses write_attribute otherwise.

## Next Phase Readiness

- AASM characterization complete — all 8 events, 2 guards, 2 callbacks pinned
- Attribute delegation complete — all 13 attributes, all 4 getter/setter paths pinned
- Safety net in place for Phase 13+ Tournament extraction work
- No blockers

---
*Phase: 12-tournament-characterization*
*Completed: 2026-04-10*

## Self-Check: PASSED

- test/models/tournament_aasm_test.rb: FOUND
- test/models/tournament_attributes_test.rb: FOUND
- .planning/phases/12-tournament-characterization/12-01-SUMMARY.md: FOUND
- Commit ecbf1133 (Task 1): FOUND
- Commit cf8dcb79 (Task 2): FOUND
