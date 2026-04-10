---
phase: 02-regioncc-extraction
plan: "04"
subsystem: region_cc_services
tags: [extraction, service-objects, dispatcher-pattern, sync]
dependency_graph:
  requires: ["02-01"]
  provides: ["RegionCc::PartySyncer", "RegionCc::GamePlanSyncer", "RegionCc::MetadataSyncer"]
  affects: ["app/models/region_cc.rb"]
tech_stack:
  added: []
  patterns: ["dispatcher .call(operation:)", "keyword-arg initializer with self.call(**kwargs) override"]
key_files:
  created:
    - app/services/region_cc/party_syncer.rb
    - app/services/region_cc/game_plan_syncer.rb
    - app/services/region_cc/metadata_syncer.rb
    - test/services/region_cc/party_syncer_test.rb
    - test/services/region_cc/game_plan_syncer_test.rb
    - test/services/region_cc/metadata_syncer_test.rb
  modified: []
decisions:
  - "Override self.call(**kwargs) in each syncer class — ApplicationService.call passes kwargs as positional hash; syncer initializers use keyword args requiring **-splat at call site"
  - "sync_game_details preserved at full length without simplification per plan requirement"
  - "MetadataSyncer renames local cc_id variable to option_cc_id in sync_category_ccs and sync_group_ccs to avoid shadowing @region_cc.cc_id"
metrics:
  duration_minutes: ~10
  completed_date: "2026-04-09"
  tasks_completed: 2
  files_created: 6
  files_modified: 0
---

# Phase 02 Plan 04: Party, GamePlan, and Metadata Syncers Summary

**One-liner:** Three RegionCc sync service classes extracted with `.call(operation:, **kwargs)` dispatcher pattern, injected ClubCloudClient, and 19 unit tests covering dispatch routing and ArgumentError guard.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extract PartySyncer, GamePlanSyncer, MetadataSyncer | d04b53cc | 3 service files created |
| 2 | Write unit tests (TDD) | 924390ea | 3 test files created; also fixes self.call override in service files |

## What Was Built

**RegionCc::PartySyncer** (`app/services/region_cc/party_syncer.rb`)
- Operations: `:sync_parties`, `:sync_party_games`
- Accepts `parties_todo_ids:` keyword for `:sync_party_games`
- `sync_parties` returns `[parties, party_ccs]` array

**RegionCc::GamePlanSyncer** (`app/services/region_cc/game_plan_syncer.rb`)
- Operations: `:sync_game_plans`, `:sync_game_details`
- `sync_game_details` preserved at full ~280 lines including complex HTML table parsing, player lookup fallback logic, and Snooker/Karambol/Pool branch handling

**RegionCc::MetadataSyncer** (`app/services/region_cc/metadata_syncer.rb`)
- Operations: `:sync_category_ccs`, `:sync_group_ccs`, `:sync_discipline_ccs`
- Local variable `cc_id` renamed to `option_cc_id` in sync_category_ccs and sync_group_ccs to avoid shadowing `@region_cc.cc_id`

All three:
- Inherit from `ApplicationService`
- Override `self.call(**kwargs)` to support keyword argument initializers
- Use `@client.post(...)` / `@client.get(...)` instead of `post_cc(...)` / `get_cc(...)`
- Have `# frozen_string_literal: true`
- All private sync methods callable only through dispatcher

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ApplicationService.call incompatible with keyword-arg initializers**
- **Found during:** Task 2 (first test run)
- **Issue:** `ApplicationService.call(kwargs = {})` calls `new(kwargs)` passing a hash positionally. Syncer initializers use `def initialize(region_cc:, client:, operation:, ...)` which requires keyword args. This raises `ArgumentError: wrong number of arguments (given 1, expected 0; required keywords: region_cc, client, operation)`.
- **Fix:** Added `def self.call(**kwargs); new(**kwargs).call; end` override to all three syncer classes. This intercepts the class-level call and passes kwargs correctly via double-splat.
- **Files modified:** `app/services/region_cc/party_syncer.rb`, `app/services/region_cc/game_plan_syncer.rb`, `app/services/region_cc/metadata_syncer.rb`
- **Commit:** 924390ea (included in test commit)

**2. [Rule 2 - Missing] Local variable cc_id shadows @region_cc.cc_id in MetadataSyncer**
- **Found during:** Task 1 (code review during extraction)
- **Issue:** Original `sync_category_ccs` and `sync_group_ccs` use a local `cc_id = option["value"].to_i` inside an each loop. After extraction, the method also has `@region_cc.cc_id` in scope, creating a shadowing risk.
- **Fix:** Renamed local variable to `option_cc_id` as specified in plan action notes.
- **Files modified:** `app/services/region_cc/metadata_syncer.rb`
- **Commit:** d04b53cc

## Verification

```
bin/rails test test/services/region_cc/party_syncer_test.rb \
              test/services/region_cc/game_plan_syncer_test.rb \
              test/services/region_cc/metadata_syncer_test.rb
# => 19 runs, 21 assertions, 0 failures, 0 errors, 0 skips
```

```
grep -c "def call" app/services/region_cc/party_syncer.rb     # => 1
grep -c "def call" app/services/region_cc/game_plan_syncer.rb # => 1
grep -c "def call" app/services/region_cc/metadata_syncer.rb  # => 1
```

## Known Stubs

None. No UI rendering paths, no placeholder data.

## Threat Flags

None. No new network endpoints, auth paths, or trust boundary crossings introduced. All three syncers delegate to the injected ClubCloudClient (existing trust model from Plan 01).

## Self-Check: PASSED
