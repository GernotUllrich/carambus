---
phase: 27-video-cross-referencing
plan: "01"
subsystem: video-matching
tags: [video, matching, metadata, poro, application-service, tdd]
dependency_graph:
  requires: []
  provides: [Video::MetadataExtractor, Video::TournamentMatcher]
  affects: [Video, InternationalTournament, DailyInternationalScrapeJob]
tech_stack:
  added: []
  patterns:
    - PORO for pure metadata extraction (MetadataExtractor)
    - ApplicationService for side-effect matching (TournamentMatcher)
    - Regex-first + AI-fallback extraction strategy (D-09, D-10)
    - Weighted confidence scoring: date overlap (0.40) + Jaccard player intersection (0.35) + Levenshtein title similarity (0.25)
key_files:
  created:
    - app/models/video/metadata_extractor.rb
    - app/models/video/tournament_matcher.rb
    - test/models/video/metadata_extractor_test.rb
    - test/models/video/tournament_matcher_test.rb
    - test/fixtures/videos.yml
    - test/fixtures/players.yml
    - test/fixtures/seedings.yml
    - test/fixtures/international_sources.yml
  modified:
    - test/fixtures/tournaments.yml
decisions:
  - "Confidence scoring: date overlap 0.40 + Jaccard player intersection 0.35 + Levenshtein title 0.25; threshold 0.75 locked per D-01"
  - "No review tier for 0.5–0.75 range — auto-assign only per D-02"
  - "tournament_type in seedings fixtures must be 'Tournament' (STI base class) not 'InternationalTournament' due to Rails polymorphic as: :tournament behavior"
  - "Videos fixtures use youtube_source not umb_source to avoid FK teardown conflict with archive_scraper_test.rb which deletes all umb-type sources"
  - "Player fixture IDs use 50_001_xxx range; tournament fixture IDs use 50_002_xxx range to avoid conflicts with inline .create!(id: ...) calls in existing tests"
metrics:
  duration: "~83 minutes"
  completed_date: "2026-04-12"
  tasks_completed: 2
  tests_added: 30
  files_created: 8
  files_modified: 1
---

# Phase 27 Plan 01: MetadataExtractor + TournamentMatcher Summary

Video::MetadataExtractor (PORO) and Video::TournamentMatcher (ApplicationService) implementing regex-first metadata extraction and confidence-scored video-to-tournament assignment.

## What Was Built

### Video::MetadataExtractor

PORO that extracts structured metadata from video titles and descriptions:

- `extract_players` — delegates to `video.detect_player_tags` (no duplicated logic)
- `extract_round` — matches against `Umb::DetailsScraper::GAME_TYPE_MAPPINGS.keys` with word-boundary anchors
- `extract_tournament_type` — detects world_cup, world_championship, european_championship, masters, grand_prix
- `extract_year` — matches 4-digit year pattern `\b(20[12]\d)\b`
- `extract_with_ai_fallback(ai_extraction_enabled:)` — calls OpenAI GPT-4o-mini only when regex returns empty AND flag is true (T-27-02 guard)

### Video::TournamentMatcher

ApplicationService that scores unassigned videos against InternationalTournament records:

- `CONFIDENCE_THRESHOLD = 0.75` (locked, D-01)
- Date overlap score (weight 0.40): `video.published_at` within `tournament.date..end_date+3days`; nil end_date falls back to `date + 7.days`
- Player intersection score (weight 0.35): Jaccard similarity of detected player tags vs tournament seeding tags
- Title similarity score (weight 0.25): normalized Text::Levenshtein distance
- Assignment via `video.update(videoable: tournament)` — Rails STI + polymorphic stores `videoable_type = "Tournament"` (base class)

## Test Results

- Task 1 (MetadataExtractor): 20 tests, 37 assertions, 0 failures
- Task 2 (TournamentMatcher): 10 tests, 25 assertions, 0 failures
- Full suite: 1124 runs, 2506 assertions, 0 failures, 0 errors (no regressions)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Test 4 assertion corrected: Rails STI + polymorphic stores base class name**
- **Found during:** Task 2 GREEN phase
- **Issue:** Plan stated `videoable_type` would be `"InternationalTournament"` but Rails polymorphic `belongs_to :videoable` with STI always stores the base class name `"Tournament"`
- **Fix:** Updated Test 4 to assert `videoable_type = "Tournament"` and verify `video.videoable` is an `InternationalTournament` instance
- **Files modified:** test/models/video/tournament_matcher_test.rb

**2. [Rule 3 - Blocking] Fixture ID conflicts with existing inline Player.create!/Tournament.create! calls**
- **Found during:** Task 2 fixture setup
- **Issue:** players.yml IDs `50_000_001..50_000_003` conflicted with `game_setup_test.rb` inline creates; tournament IDs `50_000_010/011` conflicted with `source_handler_test.rb`
- **Fix:** Players use `50_001_xxx` range; tournaments use `50_002_xxx` range
- **Files modified:** test/fixtures/players.yml, test/fixtures/seedings.yml, test/fixtures/videos.yml, test/fixtures/tournaments.yml

**3. [Rule 3 - Blocking] FK teardown conflict with archive_scraper_test.rb**
- **Found during:** Full suite run after Task 2
- **Issue:** `archive_scraper_test.rb` teardown deletes all `InternationalSource.where(source_type: "umb")` records, including the fixture-loaded `umb_source`, causing FK violations when Rails cleans up video fixtures referencing it
- **Fix:** Videos and tournament fixtures use `youtube_source` instead of `umb_source` — the archive scraper test only cleans up umb-type sources
- **Files modified:** test/fixtures/videos.yml, test/fixtures/tournaments.yml

**4. [Rule 1 - Bug] Seedings fixture tournament_type must be "Tournament" not "InternationalTournament"**
- **Found during:** Task 2 debugging
- **Issue:** Rails polymorphic `has_many :seedings, as: :tournament` on Tournament base class generates `WHERE tournament_type = 'Tournament'`, not `'InternationalTournament'`
- **Fix:** seedings.yml uses `tournament_type: "Tournament"`
- **Files modified:** test/fixtures/seedings.yml

## Known Stubs

None — both classes are fully implemented with no placeholder behavior.

## Threat Flags

No new security-relevant surface introduced beyond what is documented in the plan's threat model (T-27-01, T-27-02, T-27-03).

## Self-Check: PASSED
