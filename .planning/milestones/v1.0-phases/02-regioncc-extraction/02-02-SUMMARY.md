---
phase: 02-regioncc-extraction
plan: 02
subsystem: api
tags: [ruby, refactoring, region-cc, club-cloud, service-extraction, league-sync, club-sync, branch-sync]

# Dependency graph
requires:
  - phase: 02-regioncc-extraction
    plan: 01
    provides: RegionCc::ClubCloudClient HTTP client used by all three syncers
provides:
  - RegionCc::LeagueSyncer with .call(operation:) dispatcher for 6 league sync operations
  - RegionCc::ClubSyncer with .call() for club sync operations
  - RegionCc::BranchSyncer with .call() for branch sync operations
  - Unit tests (8) verifying injected client usage and return value contracts
affects:
  - 02-05 (delegation — will replace region_cc.rb sync_* methods with syncer delegation)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Hash kwargs pattern: def initialize(kwargs = {}); @attr = kwargs[:attr] — matches ApplicationService.call(kwargs={})"
    - "Dispatcher .call(operation:): case @operation when :sync_leagues ... else raise ArgumentError"
    - "Minitest::Mock for client injection — @client.expect(:post, stub_response, [action, Hash, Hash])"
    - "Region.find_by_shortname('DBU') guard in test setup — DBU region required by sync_leagues"

key-files:
  created:
    - app/services/region_cc/branch_syncer.rb
    - app/services/region_cc/club_syncer.rb
    - app/services/region_cc/league_syncer.rb
    - test/services/region_cc/branch_syncer_test.rb
    - test/services/region_cc/club_syncer_test.rb
    - test/services/region_cc/league_syncer_test.rb
  modified: []

key-decisions:
  - "All syncer initializers use hash kwargs pattern (def initialize(kwargs={})) to match ApplicationService.call(kwargs={}) base class"
  - "LeagueSyncer uses dispatcher .call(operation:) with 6 private methods per D-04 — all league operations share @region_cc and @client state"
  - "sync_team_players_structure still calls region_cc.sync_team_players internally (Plan 05 will complete the delegation wiring)"
  - "DBU region required by sync_leagues — test creates it on demand when not in fixtures"
  - "CompetitionCc requires discipline_id — test setup passes discipline from fixtures"

requirements-completed: [RGCC-02]

# Metrics
duration: 8min
completed: 2026-04-10
---

# Phase 02 Plan 02: League, Club, Branch Syncer Extraction Summary

**Extracted sync_leagues, sync_league_teams, sync_league_teams_new, sync_league_plan, sync_team_players, sync_team_players_structure into LeagueSyncer; sync_clubs into ClubSyncer; sync_branches into BranchSyncer — all using injected ClubCloudClient**

## Performance

- **Duration:** ~8 min
- **Started:** 2026-04-10T00:13:36Z
- **Completed:** 2026-04-10T00:21:54Z
- **Tasks:** 2
- **Files modified:** 6 created, 0 modified

## Accomplishments

- Created `RegionCc::BranchSyncer` — extracts `sync_branches` (28 lines); uses `@client.get` instead of `get_cc`
- Created `RegionCc::ClubSyncer` — extracts `sync_clubs` (47 lines); uses `@client.post`; context from `@region_cc.shortname.downcase` (not hardcoded "nbv")
- Created `RegionCc::LeagueSyncer` — extracts 6 sync methods behind `.call(operation:)` dispatcher per D-04; all `post_cc`/`get_cc` calls replaced with `@client.post`/`@client.get`
- All three syncers accept `region_cc:` and `client:` via hash kwargs pattern matching `ApplicationService.call(kwargs={})`
- 8 unit tests pass: BranchCc creation, ArgumentError on unknown branch, Club update, no-raise on unknown club, sync_leagues return contract, error return contract, sync_team_players return, ArgumentError on unknown operation
- Characterization tests unaffected: 10 pass, 7 skip (VCR cassettes — same as before Plan 02)

## Task Commits

1. **Task 1 — Syncer extraction** — `2490868a` (feat)
2. **Task 2 — Tests + initialize pattern fix** — `61ca2cc2` (feat)

## Files Created/Modified

- `app/services/region_cc/branch_syncer.rb` — BranchSyncer service; sync_branches extraction; @client.get injection
- `app/services/region_cc/club_syncer.rb` — ClubSyncer service; sync_clubs extraction; @client.post injection; context from shortname
- `app/services/region_cc/league_syncer.rb` — LeagueSyncer service; 6 methods; dispatcher .call(operation:) per D-04
- `test/services/region_cc/branch_syncer_test.rb` — 2 unit tests with Minitest::Mock
- `test/services/region_cc/club_syncer_test.rb` — 2 unit tests with Minitest::Mock
- `test/services/region_cc/league_syncer_test.rb` — 4 unit tests with Minitest::Mock

## Decisions Made

- All syncer `initialize` methods use `def initialize(kwargs = {})` pattern to match `ApplicationService.call(kwargs = {})` which passes kwargs as a positional hash to `new` — NOT keyword arguments
- `LeagueSyncer` dispatcher pattern (6 operations in one class) chosen because all 6 methods share `@region_cc` and `@client` state and form a cohesive league-sync domain
- `sync_team_players_structure` still calls `region_cc.sync_team_players` on the old model — full wiring happens in Plan 05 delegation step
- DBU region created in test setup on demand (not in fixtures) since `sync_leagues` always resolves `Region.find_by_shortname("DBU").id` unconditionally before the branch loop

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed initialize signature mismatch with ApplicationService**
- **Found during:** Task 2 (TDD GREEN — first test run)
- **Issue:** Plan specified `def initialize(region_cc:, client:, **opts)` keyword args, but `ApplicationService.call(kwargs = {})` passes a hash to `new` as positional arg, not keyword args
- **Fix:** Changed all three syncers to `def initialize(kwargs = {}); @attr = kwargs[:attr]` pattern matching existing services (e.g., SearchService)
- **Files modified:** `app/services/region_cc/branch_syncer.rb`, `app/services/region_cc/club_syncer.rb`, `app/services/region_cc/league_syncer.rb`
- **Committed in:** 61ca2cc2

**2. [Rule 2 - Missing] Added discipline_id to CompetitionCc test setup**
- **Found during:** Task 2 (test run)
- **Issue:** `CompetitionCc` has `belongs_to :discipline` (required by default in Rails 5+); test setup omitted `discipline_id`
- **Fix:** Added `discipline_id: @discipline.id` to `CompetitionCc.create!` in club_syncer_test.rb
- **Files modified:** `test/services/region_cc/club_syncer_test.rb`
- **Committed in:** 61ca2cc2

**3. [Rule 2 - Missing] Added DBU region to LeagueSyncer test setup**
- **Found during:** Task 2 (test run)
- **Issue:** `sync_leagues` calls `Region.find_by_shortname("DBU").id` unconditionally before BranchCc loop; DBU region not in fixtures; nil.id raises
- **Fix:** Added `Region.find_by_shortname("DBU") || Region.create!(...)` to test setup
- **Files modified:** `test/services/region_cc/league_syncer_test.rb`
- **Committed in:** 61ca2cc2

---

**Total deviations:** 3 auto-fixed (Rules 1+2 — convention mismatch and missing test dependencies)
**Impact on plan:** Minimal — all service behavior preserved exactly; only initializer signature adjusted for compatibility

## Issues Encountered

None beyond the deviations documented above.

## User Setup Required

None.

## Next Phase Readiness

- All three syncers ready for use from delegation wrappers in Plan 05
- `RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_leagues, **opts)` pattern established
- Original `region_cc.rb` methods untouched — Plans 03 and 04 extract remaining sync methods before Plan 05 adds delegation

## Known Stubs

None — all syncers contain full extracted logic from region_cc.rb, no placeholder implementations.

## Self-Check: PASSED

---
*Phase: 02-regioncc-extraction*
*Completed: 2026-04-10*
