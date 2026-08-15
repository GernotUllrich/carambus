---
phase: 41-versions-sync-tagging
plan: 02
subsystem: sync
tags: [paper_trail, minitest, rake-task, region_taggable, versioning, idempotent-data-fix]

# Dependency graph
requires:
  - phase: 41-versions-sync-tagging (41-01)
    provides: "test/models/region_taggable_sync_test.rb — 4 green characterization tests locking the sync mechanisms this plan's rake task depends on"
provides:
  - "lib/tasks/region_taggings.rake#fix_international_organizer_context — idempotent, PaperTrail-tracked data-fix task (DRY-RUN default, ARMED=1 to mutate)"
  - "test/tasks/region_taggings_test.rb — end-to-end armed run + no-op-on-second-invocation + dry-run-does-not-mutate task tests"
  - "test/models/version_test.rb — ordered-redelivery integration test proving organizer resolves before tournament apply"
affects: [41-03 (gated authority execution and verification)]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rake task DRY-RUN default + ENV ARMED=1 opt-in mutation gate for one-time authority-side data fixes"
    - "Instance-level update!/touch (never update_all) so PaperTrail callbacks fire and propagate via the normal sync cron"
    - "Idempotent redelivery: compare rec.versions.maximum(:created_at) against the fix version's created_at before touching"

key-files:
  created:
    - test/tasks/region_taggings_test.rb
  modified:
    - lib/tasks/region_taggings.rake
    - test/models/version_test.rb
    - app/models/version.rb

key-decisions:
  - "region_taggings:fix_international_organizer_context added inside the existing namespace, never calling update_all or global_context? for mutation (locked anti-pattern from CONTEXT.md/RESEARCH.md)"
  - "Rule 3 (blocking) fix: Version.last_version's early-return branch (app/models/version.rb:198) lacked safe navigation on Version.last.id, crashing whenever the test DB has zero Version rows — this blocked the plan's mandated verification command from exiting 0. Verified pre-existing at commit d7dc0b35 (before any Phase 41 work). Minimal one-token fix (&.)."
  - "Rule 1 (test hygiene) follow-on: the H33 test's own assert_equal(nil, nil) now hits the Minitest 6 deprecation warning once the crash above stopped masking it; branched to assert_nil, same pattern as 41-01."

requirements-completed: [H1-01, H1-02, H1-03]

# Metrics
duration: 50min
completed: 2026-07-12
---

# Phase 41 Plan 02: Fix Task and Redelivery Tests Summary

**New `region_taggings:fix_international_organizer_context` rake task (DRY-RUN default, `ARMED=1` to mutate) tags international organizer Regions `global_context=true` via PaperTrail-tracked `update!`, then redelivers their stuck tournaments/leagues via idempotent `touch`, proven end-to-end + idempotent + dry-run-safe by a new task test, plus an integration test proving the ordered-apply guarantee (organizer resolves before tournament).**

## Performance

- **Duration:** ~50 min
- **Tasks:** 3
- **Files modified:** 3 (1 created, 2 modified) + 1 pre-existing-bug fix (`app/models/version.rb`)

## Accomplishments
- `region_taggings:fix_international_organizer_context` added to the existing `region_taggings` namespace: locked selection criterion (Region organizing a `region_id IS NULL` Tournament OR League, `global_context != true`), instance-level `region.update!(global_context: true)` (real PaperTrail-tracked save) + idempotent `rec.touch` redelivery ordered strictly after the region's fix version, both defensive guards (`ApplicationRecord.local_server?` raise, `PaperTrail.enabled? && PaperTrail.request.enabled?` raise)
- DRY-RUN verified live against the dev checkout (same "authority scenario" as production): correctly found Region #25 (UMB), 433 `region_id`-nil tournaments, 0 leagues, zero mutation performed
- `test/tasks/region_taggings_test.rb` (3 tests): armed run tags region + redelivers tournament with correct version ordering; second armed run is a provable no-op (zero new versions on either side); default dry-run performs zero mutation
- `test/models/version_test.rb` extended with the ordered-redelivery integration test (name matches `/redeliver/`): a Region update-version (lower id) applied before its Tournament's update-version (higher id) via `Version.update_from_carambus_api` lets the tournament's `organizer` resolve and the tournament apply successfully — the exact failure mode ("Organisiert von muss ausgefüllt werden") this phase fixes, proven via stub_request/YAML.dump round-trip mirroring the existing test's conventions
- Full required verification green: `bin/rails test test/tasks/region_taggings_test.rb test/models/version_test.rb test/models/region_taggable_sync_test.rb` → 31 runs / 57 assertions / 0 failures / 0 errors / 2 skips (the two `skip_unless_local_server` tests correctly skip in this authority-scenario checkout)
- `bundle exec standardrb lib/tasks/region_taggings.rake` clean for the newly added task body (all remaining reported offenses are pre-existing, outside the new task, per CLAUDE.md surgical-changes convention)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add region_taggings:fix_international_organizer_context** - `d96b7cf4` (feat)
2. **Task 2: Rake-task test — end-to-end + idempotency + dry-run** - `e94f50da` (test)
3. **Task 3: Ordered-redelivery integration test + Version.last_version fix** - `672dd986` (test)

**Plan metadata:** (pending — this commit)

## Files Created/Modified
- `lib/tasks/region_taggings.rake` - New `fix_international_organizer_context` task inside the existing namespace (DRY-RUN default, `ARMED=1` mutate, both defensive guards, idempotent by construction)
- `test/tasks/region_taggings_test.rb` - New file, `RegionTaggingsTaskTest`, 3 tests (armed end-to-end + redelivery ordering, second-run no-op, dry-run non-mutation)
- `test/models/version_test.rb` - Extended with the ordered-redelivery integration test; also carries the Rule 1 test-hygiene fix on the pre-existing H33 `last_version` fallback test
- `app/models/version.rb` - One-token Rule 3 fix: `Version.last.id` → `Version.last&.id` in `last_version`'s early-return branch

## Decisions Made
- Followed the plan's prescribed task body verbatim (matches 41-RESEARCH.md's "Recommended task shape" exactly) — no deviation on the core mutation/redelivery logic.
- Applied the Rule 3 blocking-issue fix and its Rule 1 test-hygiene follow-on inline rather than deferring, because the plan's `<success_criteria>` explicitly mandates the combined three-file test command exit 0, and the crash was directly in that command's path — see Deviations below.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `Version.last_version` crashed with `NoMethodError` on an empty test-DB Version table**
- **Found during:** Task 3 (running the plan-mandated `bin/rails test test/tasks/region_taggings_test.rb test/models/version_test.rb test/models/region_taggable_sync_test.rb` verification command)
- **Issue:** `app/models/version.rb:198`'s early-return branch (`return Version.last.id if Carambus.config.carambus_api_url.blank?`) lacked safe navigation, while the sibling fallback branch a few lines below already used `Version.last&.id`. This deterministically crashed the pre-existing H33 test `"last_version falls back to local last id on empty API body"` whenever the test database's `versions` table is genuinely empty (no `versions` fixture exists in this project) — the normal state for a fresh test-DB run in the authority scenario this checkout runs in. Verified pre-existing (reproduces identically) at commit `d7dc0b35`, before any Phase 41 work — completely unrelated to this plan's files, but directly blocking the exact command the plan requires to exit 0.
- **Fix:** Added `&.` — `Version.last&.id`.
- **Files modified:** app/models/version.rb
- **Verification:** `bin/rails test test/models/version_test.rb` — 0 failures/errors (was 1 error before the fix)
- **Committed in:** 672dd986 (Task 3 commit)

**2. [Rule 1 - Bug] Minitest 6 deprecation warning exposed by the fix above**
- **Found during:** Task 3, immediately after applying the Rule 3 fix
- **Issue:** The H33 test's own assertion (`assert_equal Version.last&.id, Version.last_version`) now reaches an `assert_equal(nil, nil)` comparison (since `Version.last` is genuinely `nil` in this test DB state), which Minitest flags as deprecated ("This will fail in Minitest 6") — previously masked because the code crashed before the assertion ran.
- **Fix:** Branched on `expected.nil?` to use `assert_nil` in the nil case, `assert_equal` otherwise — same pattern already established in Phase 41-01's `region_taggable_sync_test.rb`.
- **Files modified:** test/models/version_test.rb
- **Verification:** `bin/rails test test/models/version_test.rb` — no deprecation output
- **Committed in:** 672dd986 (Task 3 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug/test-hygiene)
**Impact on plan:** Both fixes are minimal (one-token / one-branch), necessary for the plan's own mandated verification command to exit 0, and unrelated to the plan's core deliverable (the rake task and its tests, which match the plan's prescribed code verbatim). No scope creep on the task/test logic itself.

## Issues Encountered

- `bin/rails test:critical` (the plan's `<verification>` scraping+concerns sampling check) fails with 5 pre-existing errors in `test/scraping/change_detection_test.rb`, unrelated to this plan: that file hardcodes `Tournament.create!(id: 50_000_200 | 50_000_201 | 50_000_202, ...)`, and `test/fixtures/tournaments.yml` already defines fixture rows at those exact three ids — a deterministic id collision, verified pre-existing at commit `d7dc0b35` (before any Phase 41 work). Logged to `.planning/phases/41-versions-sync-tagging/deferred-items.md` per the scope-boundary rule (out-of-scope, unrelated file) rather than fixed. Does not affect this plan's own mandated verification command, which is green.

## User Setup Required

None - no external service configuration required. No production/authority mutation was performed (per CONTEXT.md, prod runs are gated to Plan 03 after explicit user sign-off); the DRY-RUN preview was run only against the local dev checkout for verification.

## Next Phase Readiness

- Plan 03 (gated authority execution and verification) can now run the read-only DRY-RUN preview on the actual authority (`api.carambus.de`) and, after explicit user sign-off, `ARMED=1` to perform the real fix — the task, its idempotency, and the apply-side ordering guarantee are all proven here.
- No blockers. `bin/rails test test/tasks/region_taggings_test.rb test/models/version_test.rb test/models/region_taggable_sync_test.rb` → 31 runs / 57 assertions / 0 failures / 0 errors / 2 skips.
- One pre-existing, unrelated issue documented in `deferred-items.md` (`test/scraping/change_detection_test.rb` id collision) — not blocking, not in this plan's scope.

---
*Phase: 41-versions-sync-tagging*
*Completed: 2026-07-12*

## Self-Check: PASSED

- FOUND: lib/tasks/region_taggings.rake
- FOUND: test/tasks/region_taggings_test.rb
- FOUND: test/models/version_test.rb
- FOUND: .planning/phases/41-versions-sync-tagging/41-02-SUMMARY.md
- FOUND: d96b7cf4 (Task 1 commit)
- FOUND: e94f50da (Task 2 commit)
- FOUND: 672dd986 (Task 3 commit)
