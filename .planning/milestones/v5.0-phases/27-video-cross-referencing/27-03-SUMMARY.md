---
phase: 27-video-cross-referencing
plan: "03"
subsystem: jobs/rake
tags: [video-matching, daily-job, rake-task, sooplive, kozoom]
dependency_graph:
  requires:
    - 27-01  # Video::TournamentMatcher + Video::MetadataExtractor
    - 27-02  # SoopliveBilliardsClient with cross_reference_kozoom_videos
  provides:
    - DailyInternationalScrapeJob with Steps 3a/3b/3c
    - rake videos:match_tournaments backfill task
  affects:
    - app/jobs/daily_international_scrape_job.rb
    - lib/tasks/video_game_matching.rake
tech_stack:
  added: []
  patterns:
    - defined?(ClassName) guard for defensive loading in background jobs
    - begin/rescue per step in job (no abort on partial failure)
key_files:
  created:
    - test/jobs/daily_international_scrape_job_test.rb
  modified:
    - app/jobs/daily_international_scrape_job.rb
    - lib/tasks/video_game_matching.rake
    - app/models/video/metadata_extractor.rb   # standardrb fixes only
    - app/models/video/tournament_matcher.rb    # standardrb fixes only
    - app/services/sooplive_billiards_client.rb # standardrb fixes only
decisions:
  - "Step 3 split into 3a/3b/3c rather than replacing Step 3; TournamentDiscoveryService preserved as 3a"
  - "Step 1b added for SoopliveBilliardsClient#fetch_games (D-04); match data fetched on-demand, not bulk-stored"
  - "defined?() guards on Video::TournamentMatcher and SoopliveBilliardsClient for safe autoload"
  - "rescue => e (not rescue StandardError) per Standard Ruby style"
  - "Rake task uses no rescue — admin CLI, failure is visible and expected to surface"
metrics:
  duration: "~25 minutes"
  completed: "2026-04-12"
  tasks_completed: 3
  files_changed: 6
  tests_added: 6
requirements_validated:
  - VIDEO-01
  - VIDEO-02
  - VIDEO-03
---

# Phase 27 Plan 03: Job Wiring + Rake Task Summary

Job wiring for Video::TournamentMatcher (Step 3b) and Kozoom cross-referencing (Step 3c) added to DailyInternationalScrapeJob; rake videos:match_tournaments backfill task created; all Phase 27 files brought to standardrb clean.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Wire video matching into DailyInternationalScrapeJob | 130ef990 | app/jobs/daily_international_scrape_job.rb, test/jobs/daily_international_scrape_job_test.rb |
| 2 | Create rake videos:match_tournaments backfill task | 7d3192d8 | lib/tasks/video_game_matching.rake |
| 3 | Full suite verification + standardrb fixes | b0fe44b3 | 5 Phase 27 files |

## What Was Built

### DailyInternationalScrapeJob changes

Step 3 was split into three sequential sub-steps:

- **Step 3a** (existing): `TournamentDiscoveryService.discover_from_videos` — discovers new tournaments from video metadata
- **Step 3b** (new): `Video::TournamentMatcher.call` — assigns unassigned videos to InternationalTournaments using confidence scoring (>= 0.75 threshold)
- **Step 3c** (new): `SoopliveBilliardsClient.cross_reference_kozoom_videos` — matches Kozoom videos via `json_data["eventId"]` to `InternationalTournament.external_id`

**Step 1b** (new): `SoopliveBilliardsClient.new.fetch_games` — syncs SoopLive billiards tournament list (D-04). Match data is fetched on-demand during VOD linking, not bulk-stored here.

Return hash now includes `:matched` key (sum of TournamentMatcher assigned_count + Kozoom assigned_count).

Each new step is wrapped in `begin/rescue` — a failure in Steps 1b, 3b, or 3c does not abort Steps 4 (translation) or 5 (stats update).

### rake videos:match_tournaments

Added to the existing `videos` namespace in `lib/tasks/video_game_matching.rake`. Runs both matching passes with before/after unassigned count output:

```
=== Matching unassigned Videos to InternationalTournaments ===
Unassigned videos before: N
--- Step 1: Confidence-scored matching ---
Matched: X, Skipped: Y
--- Step 2: Kozoom eventId cross-referencing ---
Kozoom matched: Z
=== Summary ===
Unassigned before: N
Unassigned after:  M
Total assigned:    N-M
```

Existing `match_to_games` task preserved intact.

### Tests (6 new tests in daily_international_scrape_job_test.rb)

1. Step 3b calls `Video::TournamentMatcher.call`
2. Step 3c calls `SoopliveBilliardsClient.cross_reference_kozoom_videos`
3. Error in Step 3b does not abort job (`assert_nothing_raised`)
4. Error in Step 3c does not abort job (`assert_nothing_raised`)
5. Return hash includes `:matched` key with correct sum
6. Integration: `Video.unassigned.count` decreases after job runs with `jaspers_cho_wc_2024` fixture (end-to-end, real matcher logic, no mocks)

## Verification Results

- `bin/rails test`: **1130 runs, 2514 assertions, 0 failures, 0 errors, 13 skips**
- `bin/rails -T videos:match_tournaments`: task visible
- `bundle exec brakeman --no-pager -q`: no new warnings for Phase 27 files
- `bundle exec standardrb --no-fix [all 5 Phase 27 files]`: **0 offenses**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Style] standardrb offenses in Plans 01/02 files carried forward**
- **Found during:** Task 3
- **Issue:** `SpaceInsideHashLiteralBraces`, `rescue StandardError` (should omit class), `MultilineMethodCallIndentation`, `TernaryParentheses`, redundant `to_s` in metadata_extractor, tournament_matcher, sooplive_billiards_client, and the pre-existing rake task
- **Fix:** All offenses corrected manually per plan Task 3 instructions ("fix each reported offense by hand")
- **Files modified:** all 5 Phase 27 files
- **Commit:** b0fe44b3

**2. [Rule 3 - Blocking] Worktree missing config/carambus.yml and config/database.yml**
- **Found during:** Task 1 test run
- **Issue:** Worktree did not have `config/carambus.yml` (generated file, gitignored); `LocalProtector` reads it at include time, causing `ClubLocation` to fail loading, which broke fixture label resolution for `club_locations.yml`
- **Fix:** Copied both files from main repo checkout to worktree — these are generated/local config files, not committed
- **Files modified:** config/carambus.yml, config/database.yml (worktree only, not committed)

## Known Stubs

None. All wiring calls real service methods from Plans 01 and 02.

## Threat Flags

None. No new network endpoints, auth paths, or schema changes introduced. The `defined?()` guards and per-step `rescue` blocks implement T-27-08 (DoS mitigation) as specified in the plan threat register.

## Self-Check: PASSED

All files created/modified exist on disk. All three task commits present in git log.

| Check | Result |
|-------|--------|
| app/jobs/daily_international_scrape_job.rb | FOUND |
| lib/tasks/video_game_matching.rake | FOUND |
| test/jobs/daily_international_scrape_job_test.rb | FOUND |
| commit 130ef990 | FOUND |
| commit 7d3192d8 | FOUND |
| commit b0fe44b3 | FOUND |
