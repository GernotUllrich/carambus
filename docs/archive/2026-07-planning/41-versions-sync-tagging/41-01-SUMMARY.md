---
phase: 41-versions-sync-tagging
plan: 01
subsystem: testing
tags: [paper_trail, minitest, region_taggable, versioning, characterization-tests]

# Dependency graph
requires:
  - phase: 41-versions-sync-tagging (41-RESEARCH.md)
    provides: HIGH-confidence gem-source-verified findings on PaperTrail version tagging, touch-forces-version, and get_updates ordering
provides:
  - "test/models/region_taggable_sync_test.rb — 4 green characterization tests locking the sync mechanisms Plan 02's data-fix rake task depends on"
  - "Executable ground truth for the locked selection criterion (Tournament OR League, region_id IS NULL, global_context != true)"
affects: [41-02 (rake task implementation), any future change to RegionTaggable or PaperTrail config]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "skip_unless_api_server scenario gate for tests that depend on PaperTrail being active (mirrors existing test/test_helper.rb convention)"
    - "Base-offset fixture IDs (REGION_BASE_ID = 52_000_200, >= MIN_ID) for newly created Region/Tournament/League test records"

key-files:
  created:
    - test/models/region_taggable_sync_test.rb
  modified: []

key-decisions:
  - "assert_nil branch (instead of assert_equal(nil, ...)) added to the version-tagging test to avoid the Minitest 6 deprecation warning while still asserting region_id equality generically — Rule 1 auto-fix, not a plan deviation in substance"

requirements-completed: [H1-01, H1-02, H1-03]

# Metrics
duration: 25min
completed: 2026-07-12
---

# Phase 41 Plan 01: Sync-Mechanism Characterization Tests Summary

**4 new Minitest characterization tests in `test/models/region_taggable_sync_test.rb` lock the locked selection query, its idempotency, PaperTrail's `global_context` version-tagging, and the `touch`-forces-version + ordering guarantee that Plan 02's data-fix rake task will rely on.**

## Performance

- **Duration:** ~25 min
- **Tasks:** 2
- **Files modified:** 1 (new file)

## Accomplishments
- Locked selection criterion (`Tournament OR League`, `region_id IS NULL`, `global_context != true`) captured verbatim in a private `affected_regions` helper — byte-for-byte identical to the query 41-RESEARCH.md's recommended Plan 02 task will run
- Idempotency proven: after a Region's `global_context` flips to `true`, a second selection run returns nothing for it
- `region.update!(global_context: true)` proven to create a NEW PaperTrail version tagged `global_context: true` and `region_id` from the record's own column (via `RegionTaggable#update_version_region_data`), not bypassed
- `tournament.touch` proven to force a version despite zero attribute diff, with blank `object_changes` + populated `object` snapshot, strictly ordered AFTER a preceding region version (higher version id) — the invariant the client apply-order depends on

## Task Commits

Each task was committed atomically:

1. **Task 1: Selection-criterion + idempotency characterization tests** - `eacd351e` (test)
2. **Task 2: PaperTrail version-tagging + touch-forces-version characterization tests** - `be40fcce` (test)

**Plan metadata:** (pending — this commit)

## Files Created/Modified
- `test/models/region_taggable_sync_test.rb` - New file, `class RegionTaggableSyncTest`, 4 tests: selection criterion (Tournament+League union, global_context filter), idempotent re-selection, version-tagging from the `global_context` column, touch-forces-version with ordering assertion

## Decisions Made
- Used `assert_nil`/`assert_equal` branch on `region_intl.region_id.nil?` in the version-tagging test instead of a bare `assert_equal region_intl.region_id, v.region_id` to avoid Minitest 6's `assert_equal(nil, ...)` deprecation warning while keeping the assertion generically correct for either a nil or a populated `region_id` column.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Avoided Minitest 6 deprecation warning on nil-expected assertion**
- **Found during:** Task 2 (version-tagging test)
- **Issue:** The plan-prescribed `assert_equal region_intl.region_id, v.region_id` triggers Minitest's `assert_equal` deprecation warning when the expected value is `nil` (as it is for a top-level international Region with no German Landesverband parent) — "This will fail in Minitest 6."
- **Fix:** Branch on `region_intl.region_id.nil?` — `assert_nil` for the nil case, `assert_equal` otherwise. Same assertion strength, no deprecation output.
- **Files modified:** test/models/region_taggable_sync_test.rb
- **Verification:** `bin/rails test test/models/region_taggable_sync_test.rb` — no deprecation output, 4/4 green
- **Committed in:** be40fcce (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Cosmetic test-hygiene fix only; no semantic change to what's being asserted. No scope creep.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Plan 02 (the rake task implementation) can now build against a green, executable ground truth for all four locked mechanisms: selection criterion, idempotency, version-tagging-from-column, and touch-forces-version-with-ordering.
- No blockers. The selection query in the test is verified identical (via shared literal clause) to the query 41-RESEARCH.md recommends for the Plan 02 task.
- Full test file green: `bin/rails test test/models/region_taggable_sync_test.rb` → 4 runs, 19 assertions, 0 failures, 0 errors, 0 skips (all 4 tests execute — this checkout runs in the authority scenario, `carambus_api_url` blank, so the `skip_unless_api_server`-gated tests are NOT skipped here).

---
*Phase: 41-versions-sync-tagging*
*Completed: 2026-07-12*

## Self-Check: PASSED

- FOUND: test/models/region_taggable_sync_test.rb
- FOUND: eacd351e (Task 1 commit)
- FOUND: be40fcce (Task 2 commit)
