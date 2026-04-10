# Milestones

## v2.0 Test Suite Audit & Improvement (Shipped: 2026-04-10)

**Phases completed:** 5 phases, 11 plans, 14 tasks

**Key accomplishments:**

- STANDARDS.md created with 6-section conventions rubric covering fixtures-first setup, MiniTest assertion style, test naming, 4 support file analysis with usage data, file structure template, and 7 issue category codes for the Phase 7-9 audit.
- Per-file issue catalogue for all 72 test files — 10 empty scaffold stubs, 26 files with weak assertions, 2 skipped tests, 40 files missing frozen_string_literal, zero naming or FactoryBot violations.
- 10 empty scaffold test stubs deleted from test/models/ and frozen_string_literal: true added to 2 clean model test files
- Sole assert_nothing_raised and assert_not_nil weak assertions fixed in 5 test files; 6 pre-existing bugs auto-fixed including ko_ranking nil guard and test helper attribute errors
- One-liner:
- 3 presence-only and sole-assertion weak spots fixed in GameSetup and ResultRecorder tests — game_id now verified by value; evaluate_result path confirmed via state and panel_state assertions
- 6 targeted test quality fixes: deleted non-test script, removed always-passing assertion, rewrote phantom-method tests against actual helper, strengthened sync_date assertion, replaced brittle CSRF regex, removed hardcoded sleep
- ApiProtectorTestOverride added and 5 fixture files fixed, reducing errors from 75 to 66 and revealing 82 pre-existing failures previously masked by setup errors
- 1. [Rule 1 - Bug] League::DBU_ID crashes in test env without safe navigation
- 7 VCR cassettes created for RegionCcCharTest — all 17 tests now green (0 failures, 0 errors, 0 skips), QUAL-04 resolved

---

## v1.0 Model Refactoring (Shipped: 2026-04-10)

**Phases completed:** 5 phases, 18 plans, 28 tasks

**Key accomplishments:**

- 39-test characterization suite pins TableMonitor AASM state machine, after_enter callbacks, and all after_update_commit routing branches before extraction work begins
- 56-test RegionCc characterization suite with VCR cassette wrappers, plus Reek smell baselines documenting 781 TableMonitor and 460 RegionCc warnings before extraction begins
- Two end-to-end tests close the VERIFICATION.md SC-1 gap: ultra_fast ("score_data") and simple ("player_score_panel") after_update_commit branches are now pinned through the full before_save -> log_state_change -> @collected_data_changes -> routing pipeline
- Extracted get_cc/post_cc/post_cc_with_formdata/get_cc_with_url from RegionCc model into standalone RegionCc::ClubCloudClient with PATH_MAP constant and zero ActiveRecord coupling
- Extracted sync_leagues, sync_league_teams, sync_league_teams_new, sync_league_plan, sync_team_players, sync_team_players_structure into LeagueSyncer; sync_clubs into ClubSyncer; sync_branches into BranchSyncer — all using injected ClubCloudClient
- RegionCc::TournamentSyncer
- One-liner:
- 1. sync_team_players_structure delegation
- One-liner:
- One-liner:
- One-liner:
- TableMonitor::GameSetup extracts start_game/assign_game from the 3900-line model into a testable ApplicationService with dual entry points, ensure-guaranteed broadcast cleanup, and single job enqueue
- 1. [Rule 1 - Bug] Kept initialize_game in model
- get_options! extracted from ~193-line inline body to TableMonitor::OptionsPresenter PORO + 23-line delegation wrapper, with 11 unit tests — 121 total tests pass
- Mechanical rename of 79 skip_update_callbacks occurrences to suppress_broadcast across 7 files, removing transitional alias shims from TableMonitor to close SC #2 verification gap
- TableMonitor::ResultRecorder ApplicationService extracted with 5 entry points (save_result, save_current_set, get_max_number_of_wins, switch_to_next_set, evaluate_result), removing ~300 lines from TableMonitor via thin delegation wrappers
- Part A: initialize_game → GameSetup
- All 4 extracted TableMonitor services verified with 140 passing tests; Reek warnings reduced from 781 to 306 (61% reduction), confirming measurable quality improvement from Phase 1 baseline

---
