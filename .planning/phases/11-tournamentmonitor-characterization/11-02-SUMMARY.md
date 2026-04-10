---
phase: 11-tournamentmonitor-characterization
plan: "02"
subsystem: testing
tags: [minitest, tournament-monitor, aasm, characterization, fixtures, t06, finals]

# Dependency graph
requires:
  - phase: 11-01
    provides: "tournament_plans.yml fixture with t06_6 entry; T04TournamentTestHelper pattern"
provides:
  - "T06TournamentTestHelper module with create/cleanup helpers using fixture plan per D-03"
  - "24 characterization tests for TournamentMonitor T06 covering AASM full lifecycle, game creation, result pipeline, group phase detection"
  - "TournamentMonitor size/method baseline for pre-extraction comparison"
affects:
  - "13-tmex-player-group-distributor (T06 group distribution pinned)"
  - "14-tmex-ranking-resolver (T06 AASM transitions pinned)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "T06TournamentTestHelper counter offset: TEST_ID_BASE + 30_000 (KO=10_000, T04=20_000, T06=30_000)"
    - "JSON round-trip key coercion: integer player_id keys become strings after data['rankings'] reload"
    - "Use update!(data: {}) not update_column(:data, '{}') for JSON-serialized columns"
    - "Reek fallback: use wc/grep size baseline when reek not in Gemfile"
    - "High-ID game creation in tests to exercise MIN_ID-filtered queries"

key-files:
  created:
    - "test/support/t06_tournament_test_helper.rb"
    - "test/models/tournament_monitor_t06_test.rb"
    - ".planning/phases/11-tournamentmonitor-characterization/11-reek-baseline.txt"
  modified: []

key-decisions:
  - "Use update!(data: {}) not update_column for JSON-serialized Game.data — serializer rejects String input"
  - "JSON round-trip coerces integer player_id keys to strings; assertions use player_a.id.to_s as key"
  - "group_phase_finished? returns true (0==0) in test env due to MIN_ID filtering; pinned as documented behavior"
  - "accumulate_results requires high-ID games to exercise non-empty rankings path; documented both empty and high-ID branches"
  - "Reek not in Gemfile; size/method baseline used per plan fallback (D-07 intent preserved)"
  - "Tests run from main repo (EXT2TB) not worktree — worktree has Rails fixture schema resolution issue"

patterns-established:
  - "T06TournamentTestHelper counter offset: TEST_ID_BASE + 30_000 avoids collision with KO (10_000) and T04 (20_000)"
  - "High-ID game trick: create Game with id >= MIN_ID to exercise MIN_ID-filtered production queries in tests"
  - "TableMonitor test setup: save(validate: false) bypasses AASM after_enter callback; ensure block cleans up before teardown"

requirements-completed: [CHAR-01, CHAR-02, CHAR-03]

# Metrics
duration: 45min
completed: 2026-04-10
---

# Phase 11 Plan 02: T06 Characterization Tests Summary

**24 Minitest characterization tests pinning TournamentMonitor T06 with-finals behavior: AASM full lifecycle through group and finals phases, group game creation, result pipeline (update_game_participations, write_game_result_data, accumulate_results), and group phase detection — plus pre-extraction size baseline**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-04-10T23:05:00Z
- **Completed:** 2026-04-10T23:50:00Z
- **Tasks:** 2
- **Files modified:** 3 created, 0 modified

## Accomplishments

- Created `test/support/t06_tournament_test_helper.rb` using `tournament_plans(:t06_6)` fixture per D-03 (6 players, 2 groups of 3, with hf1/hf2/fin/p<3-4>/p<5-6> endgame keys)
- Created `test/models/tournament_monitor_t06_test.rb` with 24 tests covering AASM lifecycle (6 tests), game creation (7 tests), result pipeline (5 tests), group phase detection (3 tests), accumulate_results (2 tests), and 1 additional AASM test
- Created `11-reek-baseline.txt` as size/method baseline: TM 499L/20M, TM-Support 1078L/10M, TM-State 522L/8M
- Full test suite green: 522 runs, 1348 assertions, 0 failures, 0 errors, 11 justified skips
- All 3 TM test files pass together: 62 runs (15 KO + 23 T04 + 24 T06), 0 failures

## Task Commits

1. **Task 1: Create T06TournamentTestHelper and TournamentMonitorT06Test** - `b38c66e1` (feat)
2. **Task 2: Create Reek baseline and verify full suite** - `895d62d9` (chore)

## Files Created/Modified

- `test/support/t06_tournament_test_helper.rb` - T06 helper module with `create_t06_tournament_with_seedings` (no args, always 6 players) and `cleanup_t06_tournament`, using `tournament_plans(:t06_6)` fixture per D-03
- `test/models/tournament_monitor_t06_test.rb` - 24 characterization tests: AASM full lifecycle (playing_groups -> playing_finals -> closed), 6 group games (2x3), correct gnames, result pipeline (update_game_participations_for_game winner/loser/tie, write_game_result_data with ba_results guards, accumulate_results), group_phase_finished? MIN_ID pinned behavior and high-ID branches
- `.planning/phases/11-tournamentmonitor-characterization/11-reek-baseline.txt` - Size/method baseline for TM, TM-Support, TM-State files (reek not in Gemfile; fallback used)

## Decisions Made

- **`update!(data: {})` not `update_column`**: Game.data is JSON-serialized as Hash. `update_column` bypasses serialization and stores a String, which Rails then rejects with `SerializationTypeMismatch` on subsequent saves. Fixed to `update!(data: {})`.
- **JSON key coercion**: After `accumulate_results` saves rankings via JSON, integer player_id keys become strings. Assertions use `player_a.id.to_s` as the hash key.
- **Tests run from main repo**: The git worktree (`.claude/worktrees/agent-a0915908/`) has a Rails fixture schema resolution issue causing `ActiveRecord::Fixture::FixtureError` for `club_locations`. Tests are run from the main repo at `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/` where the test DB's schema cache resolves fixture associations correctly.
- **Reek fallback**: `reek` gem is not in the Gemfile. Used `wc -l` / `grep -c 'def '` baseline per plan's fallback instructions.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `update_column(:data, '{}')` causes SerializationTypeMismatch**
- **Found during:** Task 1 (result pipeline tests)
- **Issue:** `game.update_column(:data, '{}')` stores a raw String for a JSON Hash column. On next save, Rails raises `can't dump data: was supposed to be a Hash, but was a String`
- **Fix:** Changed all `update_column(:data, '{}')` calls to `update!(data: {})` and moved GameParticipation data into `create!` attributes (using Hash not String)
- **Files modified:** test/models/tournament_monitor_t06_test.rb
- **Committed in:** b38c66e1 (Task 1 commit)

**2. [Rule 1 - Bug] Integer player_id keys become strings after JSON round-trip**
- **Found during:** Task 1 (accumulate_results test)
- **Issue:** `rankings["groups"]["group1"].key?(player_a.id)` fails because JSON serialization converts integer keys to strings during `save!` in `accumulate_results`
- **Fix:** Changed assertion to use `player_a.id.to_s` as the key
- **Files modified:** test/models/tournament_monitor_t06_test.rb
- **Committed in:** b38c66e1 (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Both fixes necessary for tests to pass. No scope creep. Production behavior is accurately characterized.

## Issues Encountered

- Git worktree cannot run `bin/rails test` directly due to Rails fixture schema resolution issue for `club_locations` table — Rails in the worktree context cannot resolve `belongs_to :club` fixture associations. Tests run from main repo instead.
- `reek` not available in bundle — used wc/grep size baseline per plan fallback instructions.

## Known Stubs

None — all test assertions exercise real production code paths.

## Next Phase Readiness

- All 3 TM test files (KO, T04, T06) pass together at 62 runs, 0 failures — characterization coverage complete for Phase 11
- `11-reek-baseline.txt` committed as pre-extraction snapshot for comparison after extractions in Phases 13-14
- Phase 12 (Tournament characterization) can proceed independently
- Phases 13-14 (TM extractions) gated on Phase 11 characterization — now unblocked

---
*Phase: 11-tournamentmonitor-characterization*
*Completed: 2026-04-10*

## Self-Check: PASSED
