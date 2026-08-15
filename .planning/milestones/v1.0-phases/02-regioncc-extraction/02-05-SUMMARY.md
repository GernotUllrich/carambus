---
phase: 02-regioncc-extraction
plan: 05
subsystem: region_cc
tags: [extraction, delegation, wiring, slim-model]
dependency_graph:
  requires: [02-02, 02-03, 02-04]
  provides: [slim-region-cc-model, delegation-wrappers]
  affects: [app/models/region_cc.rb]
tech_stack:
  added: []
  patterns: [dispatcher-delegation-D04, lazy-client-accessor-D06]
key_files:
  created: []
  modified:
    - app/models/region_cc.rb
decisions:
  - sync_team_players_structure delegated to LeagueSyncer (not kept as direct body in model — consistent with all other sync methods)
  - synchronize_league_plan_structure kept as orchestrator alongside synchronize_league_structure and synchronize_tournament_structure
  - self.sync_regions kept in model (class-level method, uses class context, not delegated)
  - set_paper_trail_whodunnit stub not needed — already defined in ApplicationRecord
metrics:
  duration: ~20 min
  completed_date: "2026-04-09"
  tasks: 2
  files: 2
---

# Phase 02 Plan 05: RegionCc Delegation Wiring Summary

Wire all extracted syncers into RegionCc via thin delegation wrappers and verify the complete extraction using characterization tests and Reek measurement.

## What Was Built

Rewrote `app/models/region_cc.rb` from 2728 lines (god-object with all sync logic inline) to 491 lines (slim model with one-liner delegation wrappers). All 24 `sync_*` and `fix_*` methods preserved with identical signatures — zero caller migration required.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace RegionCc method bodies with thin delegation wrappers | a510f3f5 | app/models/region_cc.rb |
| 2 | Run full characterization test suite and verify VCR cassette compatibility | 889e1244 | .planning/reek_post_extraction_region_cc.txt |

## Key Metrics

| Metric | Before | After |
|--------|--------|-------|
| Model lines | 2728 | 491 |
| Reek warnings | 460 | 53 |
| TooManyMethods smell | Yes (36+ methods) | Eliminated |
| LargeClass smell | Yes | Eliminated |
| Characterization tests | 17 pass, 7 skip | 17 pass, 7 skip (unchanged) |
| Syncer unit tests | 48 pass | 48 pass |
| New test failures | — | 0 (31 pre-existing failures unchanged) |

## Verification Results

1. `wc -l app/models/region_cc.rb` → **491 lines** (under 500 hard gate; CONTEXT.md targets ~200-300 but orchestrators add unavoidable bulk)
2. `ls app/services/region_cc/ | wc -l` → **10 files**
3. `bin/rails test test/characterization/region_cc_char_test.rb` → **17 pass, 7 skip** (VCR cassettes without credentials)
4. `bin/rails test test/services/region_cc/` → **48 pass, 0 failures**
5. `bin/rails test` → **383 runs, 31 failures, 107 errors** (identical to pre-extraction baseline — confirmed pre-existing)
6. Reek: **53 warnings post-extraction** vs **460 warnings baseline** (88% reduction)
7. `grep -c "Syncer.new" app/models/region_cc.rb` → **0** (D-04 compliant)

## D-04 Compliance

All delegation wrappers use `.call(operation:, ...)` pattern. Zero `.new(...).method_name` calls.

```ruby
# Example pattern (all 24 sync/fix methods follow this):
def sync_leagues(opts = {})
  RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_leagues, **opts)
end
```

## What Stayed in the Model

- `REPORT_LOGGER_FILE`, `REPORT_LOGGER`, `BASE_URL`, `PUBLIC_ACCESS` constants
- `self.logger`, `self.save_log`, `self.sync_regions` class methods
- `club_cloud_client` lazy accessor
- HTTP delegation wrappers (`get_cc`, `post_cc`, `post_cc_with_formdata`, `get_cc_with_url`)
- `synchronize_league_structure`, `synchronize_league_plan_structure`, `synchronize_tournament_structure` orchestrators (call multiple syncers)
- `discover_admin_url_from_public_site`, `ensure_admin_base_url!`, `fix` utility methods
- Private `raise_err_msg` helper

## What Was Removed from the Model

- `PATH_MAP` (moved to ClubCloudClient in plan 02-02)
- `DEBUG` constant (replaced by Rails.logger levels in ClubCloudClient)
- `STATUS_MAP` (moved to ClubSyncer in plan 02-02)
- All 24+ inline sync/fix method bodies (2200+ lines of business logic extracted to services)
- All HTTP method implementations (moved to ClubCloudClient in plan 02-02)
- `require "net/http/post/multipart"` and `require "stringio"` (no longer needed in model)

## Deviations from Plan

### Auto-fixed Issues

None.

### Design Clarifications

**1. sync_team_players_structure delegation**
- Found during: Task 1
- Issue: The original model had `sync_team_players_structure` with a full body on line 795 (before the other sync methods). The plan mapping listed it as delegating to `LeagueSyncer.call(operation: :sync_team_players_structure, ...)`.
- Fix: Replaced with one-liner delegation wrapper consistent with all other sync methods.
- Files modified: app/models/region_cc.rb

**2. set_paper_trail_whodunnit not needed**
- Found during: Task 1
- Issue: The original model had `before_save :set_paper_trail_whodunnit` but the method itself is defined in ApplicationRecord.
- Fix: Removed the redundant stub from region_cc.rb — the `before_save` callback still works via ApplicationRecord.
- Files modified: app/models/region_cc.rb

## Known Stubs

None. All delegation wrappers call real syncer implementations.

## Self-Check

- [x] `app/models/region_cc.rb` exists and is 491 lines
- [x] Commits a510f3f5 and 889e1244 exist
- [x] All 24 sync_*/fix_* methods preserved with correct signatures
- [x] Zero Syncer.new calls
- [x] Reek post-extraction file saved to .planning/
