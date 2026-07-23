---
phase: 27-video-cross-referencing
plan: "02"
subsystem: services
tags: [sooplive, kozoom, video, cross-referencing, api-client, tdd]
dependency_graph:
  requires: []
  provides:
    - SoopliveBilliardsClient PORO
    - billiards.sooplive.com API adapter (3 endpoints)
    - SoopLive VOD linking via replay_no (VIDEO-02)
    - Kozoom eventId cross-referencing (VIDEO-03)
  affects:
    - app/services/sooplive_billiards_client.rb
    - test/services/sooplive_billiards_client_test.rb
tech_stack:
  added: []
  patterns:
    - PORO adapter for undocumented JSON API (mirrors SoopliveScraper fetch_json pattern)
    - TDD RED→GREEN for all three tasks in single implementation file
    - WebMock stubs for external HTTP in tests
    - Inline DB setup/teardown via ensure blocks (no fixtures needed)
key_files:
  created:
    - app/services/sooplive_billiards_client.rb
    - test/services/sooplive_billiards_client_test.rb
  modified: []
decisions:
  - All three tasks implemented in one class file — VOD linking and Kozoom cross-ref colocate ID-based matching in SoopliveBilliardsClient
  - Kozoom cross_reference_kozoom_videos as class method — stateless, no HTTP needed
  - Tests use inline create!/destroy in ensure blocks — no fixture conflicts with Plan 01 artifacts
  - ssl_verify_mode follows existing SoopliveScraper pattern (VERIFY_NONE outside production)
metrics:
  duration_minutes: 12
  completed_date: "2026-04-12"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 0
  tests_added: 17
  assertions_added: 32
requirements:
  - VIDEO-02
  - VIDEO-03
---

# Phase 27 Plan 02: SoopliveBilliardsClient Summary

**One-liner:** PORO adapter for billiards.sooplive.com (3 JSON endpoints) with SoopLive VOD linking via `replay_no` and Kozoom eventId cross-referencing.

## What Was Built

`SoopliveBilliardsClient` covers the full VIDEO-02 and VIDEO-03 requirements:

**API Client (Task 1):**
- `fetch_games` — GET `/api/games` → tournament list
- `fetch_matches(game_no)` — GET `/api/game/{game_no}/matches` → match list with `replay_no`
- `fetch_results(game_no)` — GET `/api/game/{game_no}/results` → rankings
- `self.vod_url(replay_no)` — constructs `vod.sooplive.com/player/{replay_no}`
- Private `fetch_json` with `StandardError` rescue → returns nil on error (mirrors SoopliveScraper)
- `ssl_verify_mode` — VERIFY_NONE outside production

**VOD Linking (Task 2 / VIDEO-02):**
- `link_match_vods(game_no, international_game:)` — finds pre-existing Video records by `external_id == replay_no.to_s` with `fivesix` source and assigns unassigned ones to InternationalGame
- Skips `replay_no == 0` (Pitfall 4: no VOD available)
- Skips `record_yn != "Y"` (match not recorded)
- Skips videos with `videoable_id` already set
- Returns `[{ video_id:, replay_no: }]` for each linked video

**Kozoom Cross-Referencing (Task 3 / VIDEO-03):**
- `self.cross_reference_kozoom_videos` — finds unassigned Kozoom Video records with `data->>'eventId' IS NOT NULL` (Pitfall 2 guard), matches to `InternationalTournament.external_id`
- Uses parameterized `find_by(external_id: event_id.to_s)` — no raw SQL interpolation (T-27-06)
- Returns `{ assigned_count: N }`
- Graceful degradation when no Kozoom source exists

## Tests

17 tests, 32 assertions, 0 failures, 0 errors, 0 skips.

All tests use WebMock for HTTP stubs and inline `create!`/`ensure` teardown to avoid fixture conflicts.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed as written.

### Out-of-scope Pre-existing Failures

The full test suite (`bin/rails test`) shows failures in `Umb::ArchiveScraperTest`, `Umb::FutureScraperTest`, `TableMonitor::GameSetupTest`, and `Video::TournamentMatcherTest`. These are pre-existing failures from Plan 01 artifacts (unmerged fixture files and uncommitted code in the parallel worktree) and are not caused by any Plan 02 changes. Confirmed by verifying the failures existed before Plan 02 commits.

These are logged to `deferred-items.md` scope for the orchestrator.

## Threat Surface Scan

| Flag | File | Description |
|------|------|-------------|
| threat_flag: server-side-request-forgery | app/services/sooplive_billiards_client.rb | `fetch_json` constructs URLs from `game_no` parameter. `game_no` comes from our own DB (not user input per T-27-04), so SSRF risk is negligible. No additional mitigation needed beyond current integer conversion. |

T-27-06 (Kozoom eventId SQL injection) mitigated: `find_by(external_id: event_id.to_s)` is parameterized ActiveRecord query.

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| app/services/sooplive_billiards_client.rb exists | FOUND |
| test/services/sooplive_billiards_client_test.rb exists | FOUND |
| 27-02-SUMMARY.md exists | FOUND |
| feat commit 0fba26a2 exists | FOUND |
| test commit 98c92f6f exists | FOUND |
| Plan 02 tests: 17 runs, 32 assertions, 0 failures, 0 errors | PASSED |
