# Test Suite Audit Report

**Generated:** 2026-04-10
**Standards:** STANDARDS.md (Phase 06)
**Files audited:** 72
**Total test methods:** 538
**Total lines:** 8770

---

## Summary Statistics

| Category | Code | Count | Files Affected |
|----------|------|-------|----------------|
| Empty test (no test body, Rail scaffold stub) | E01 | 10 | club_location, discipline_phase, game_plan, party_monitor, slot, source_attribution, sync_hash, table_local, training_source, upload |
| Weak assertion | E02 | 26 files | See per-file entries |
| Skipped/pending | E03 | 2 | league_test, region_cc_char_test |
| Naming violation | W01 | 0 | None — no `def test_` found |
| Setup pattern | W02 | 0 | No FactoryBot factories used |
| Missing assertion | E04 | 1 | scraping_smoke_test (assert true only) |
| Non-test file in test directory | E04+ | 1 | optimistic_updates_test.rb (plain Ruby script, no test class) |
| Missing frozen_string_literal | I03 | 40 | See per-file entries |

**Note on I03:** `frozen_string_literal: true` is absent from 40 of 72 files. This is not in the original STANDARDS.md issue codes but is flagged as informational (I03) because CLAUDE.md mandates it in all Ruby files. Added to track for Phase 7-9 cleanup.

---

## Model Tests (22 files)

### test/models/club_location_test.rb
- **Lines:** 18 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 15–17 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/club_search_test.rb
- **Lines:** 98 | **Tests:** 8 | **Assertions:** 25
- Issues: None significant. Assertion ratio 3.1 per test. Good coverage of search column names, SQL, joins, distinct, filters, field types, and examples.
  - E02 (minor): Line 62 — `assert_not_nil sql` followed by more specific includes-assertions, so the nil check is complementary not the only assertion. Not a violation in isolation.

### test/models/discipline_phase_test.rb
- **Lines:** 20 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 17–19 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/game_plan_test.rb
- **Lines:** 18 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 14–17 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/league_test.rb
- **Lines:** 34 | **Tests:** 3 | **Assertions:** 6
- Issues:
  - E03: Line 10 — `skip unless @league.discipline.present? && @league.parties.any?` — test silently skips when fixture doesn't have the required associations; no VCR or CI limitation justifies this skip. The test should either ensure the fixture has discipline/parties or be deleted.
  - E02: Line 15 — `assert result.nil? || result.is_a?(GamePlan)` — disjunction allows nil to pass silently. Should assert specific outcome.
  - I03: Missing `# frozen_string_literal: true`

### test/models/location_search_test.rb
- **Lines:** 81 | **Tests:** 7 | **Assertions:** 20
- Issues: None. Good coverage of search interface (column names, SQL, joins, distinct, cascading filters, field types, examples).

### test/models/party_monitor_test.rb
- **Lines:** 32 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 26–32 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/player_search_test.rb
- **Lines:** 144 | **Tests:** 12 | **Assertions:** 41
- Issues:
  - E02: Line 62 — `assert_not_nil sql` — nil check alone as precondition assertion; however the subsequent `assert_includes` assertions make it acceptable context. Low priority.
  - E02: Line 112 — `assert_not_nil examples[:description]` — confirms key presence but doesn't verify content. Should `assert examples[:description].present?` or check specific value.

### test/models/slot_test.rb
- **Lines:** 24 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 21–23 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/source_attribution_test.rb
- **Lines:** 7 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 3–7 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/sync_hash_test.rb
- **Lines:** 18 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 15–17 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/table_heater_management_test.rb
- **Lines:** 824 | **Tests:** 46 | **Assertions:** 83
- Issues:
  - E02: Lines 156, 193, 218, 257, 541, 575 — `assert_not_nil @table.heater_switched_on_at` / `scoreboard_on_at` / `scoreboard_off_at` — the timestamps should also be checked against expected time ranges. In most cases additional assertions follow, making these acceptable as preconditions, but lines 541 and 575 are sole assertions in their respective contexts. Medium priority.
  - W02 (setup): Uses `Model.create!` extensively in setup. STANDARDS.md permits `Model.create!` for complex setups not representable in fixtures. The table/location/event mock setup in this file is complex and cannot be expressed in static fixtures, so this is **acceptable**.
  - I03: Missing `# frozen_string_literal: true` (has it — verified)
  - Structure notes: 824 lines. Well-organized into named sections with comment headers (pre_heating_time_in_hours, heater_protected?, switch_heater_on!, etc.). Test grouping is clear. No obvious duplication. The use of Minitest::Mock for Google Calendar Event is the correct approach for this level of integration. No structural issues requiring change.

### test/models/table_local_test.rb
- **Lines:** 18 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 15–17 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/table_monitor/options_presenter_test.rb
- **Lines:** 295 | **Tests:** 11 | **Assertions:** 24
- Issues:
  - E02: Lines 206, 234, 247 — `assert_not_nil presenter.gps`, `assert_not_nil presenter.location`, `assert_not_nil presenter.my_table` — these are the only assertions in their respective tests. Should verify the actual return values (type, content, id) not just presence.
- Structure notes: 295 lines. Setup/teardown correctly resets cattr_accessors to prevent state leaks. Organized into logical sections. The three not_nil-only tests are the primary issue.

### test/models/table_monitor/score_engine_test.rb
- **Lines:** 703 | **Tests:** 69 | **Assertions:** 89
- Issues:
  - E02 (multiple): Assertion ratio 1.29 assertions per test. Scan shows many tests assert specific return values (good), but ratio indicates some tests have only 1 assertion verifying a single condition when more complex behavior is exercised. Manual review confirms most single-assertion tests are appropriately focused. Not a structural problem.
  - Structure notes: 703 lines. Organized by method under test with clear comment sections. Helper methods `playing_data` and `snooker_data` avoid fixture dependency appropriately (PORO — no DB). Well-structured. Largest test file by complexity but logical grouping is clear.

### test/models/tournament_auto_reserve_test.rb
- **Lines:** 586 | **Tests:** 18 | **Assertions:** 27
- Issues:
  - W02 (setup): Uses `Model.create!` for complex bracket/seeding setups. Per STANDARDS.md D-05, this is acceptable for multi-record setups with computed relationships.
  - I03: Missing `# frozen_string_literal: true`
  - Structure notes: 586 lines. Uses `Model.create!` for all setup — season, region, table kinds, disciplines, location, multiple tables with and without heaters, and seedings. Cannot be replaced with static fixtures. Well-organized into test sections with comment headers. The assertion ratio (1.5 per test) is at the lower boundary — some tests verify only one outcome when side effects could also be checked.

### test/models/tournament_ko_integration_test.rb
- **Lines:** 213 | **Tests:** 9 | **Assertions:** 34
- Issues:
  - E02: Line 32 — `assert_not_nil @tournament.tournament_monitor, "Should create tournament monitor"` — precondition check in setup context; subsequent assertions verify specific values. Acceptable.
  - E02: Line 91 — `assert_not_nil gp.player_id, "#{game.gname} should have actual player assigned"` — inside a loop, verifies that player assignment happened. Acceptable as loop assertion.

### test/models/tournament_monitor_ko_test.rb
- **Lines:** 233 | **Tests:** 15 | **Assertions:** 31
- Issues:
  - E02: Lines 50, 155, 177, 231 — `assert_not_nil qf_game`, `assert_nothing_raised` (×2), `assert_not_nil @tm.data`. The two `assert_nothing_raised` occurrences at lines 155 and 177 are the only assertions in their tests — should verify actual post-conditions (game count, state, etc.).
  - E02: Line 231 — `assert_not_nil @tm.data` — should also verify `@tm.data.is_a?(Hash)` (which follows on line 213 in a different test, but not here).

### test/models/tournament_plan_ko_test.rb
- **Lines:** 193 | **Tests:** 10 | **Assertions:** 59
- Issues:
  - E02: Lines 19, 45, 68, 85 — `assert_not_nil plan` — each followed by more specific assertions on plan fields. The nil checks serve as preconditions. Acceptable pattern since plan creation is the thing under test. Low priority.

### test/models/tournament_search_test.rb
- **Lines:** 95 | **Tests:** 7 | **Assertions:** 25
- Issues: None. Solid assertion ratio (3.6 per test). Covers column names, SQL, joins, distinct flag, cascading filters, field types, and examples.

### test/models/tournament_test.rb
- **Lines:** 48 | **Tests:** 3 | **Assertions:** 11
- Issues:
  - E02: Line 16 — `assert_nothing_raised do ... local.update!(...)` — in `allows local modifications to data field`. The `assert_nothing_raised` is the only assertion; could additionally verify `local.reload.data` contains the expected value.
  - I03: Missing `# frozen_string_literal: true`

### test/models/training_source_test.rb
- **Lines:** 7 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 3–7 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/upload_test.rb
- **Lines:** 18 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E01: Lines 14–17 — Rails scaffold stub class, all test content commented out. No tests exist.
  - I03: Missing `# frozen_string_literal: true`

### test/models/user_test.rb
- **Lines:** 120 | **Tests:** 6 (via single-quote syntax) + 1 `test "` = 7 | **Assertions:** 14
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: File uses both `test "..."` and `test '...'` — both are valid Rails syntax. No naming violation (W01 only applies to `def test_`).

---

## Service Tests (12 files)

### test/services/region_cc/branch_syncer_test.rb
- **Lines:** 81 | **Tests:** 2 | **Assertions:** 7
- Issues:
  - E02: Line 53 — `assert_not_nil branch_cc` — verifies the branch was found, but should also verify `branch_cc.cc_id == 5` or similar specific attribute. Weak as sole post-condition check.

### test/services/region_cc/club_cloud_client_test.rb
- **Lines:** 184 | **Tests:** 12 | **Assertions:** 36
- Issues:
  - E02: Lines 48, 49, 65, 94, 111, 137, 138 — `assert_not_nil res` / `assert_not_nil doc` — many tests verify presence only (res, doc) without checking response status, content type, or parsed document structure. For a client test, verifying the response body or status would be more meaningful. Medium priority.
  - E02: Line 146 — `assert_not_nil RegionCc::ClubCloudClient::PATH_MAP` — constants are never nil unless the class failed to load; this effectively tests nothing.

### test/services/region_cc/club_syncer_test.rb
- **Lines:** 103 | **Tests:** 2 | **Assertions:** 5
- Issues: None significant. `assert_nothing_raised` at line 94 captures return value and verifies downstream — acceptable given the deep stub complexity.

### test/services/region_cc/competition_syncer_test.rb
- **Lines:** 107 | **Tests:** 3 | **Assertions:** 3
- Issues:
  - E02: Lines 40, 83 — `assert_nothing_raised do ... end` is the **only** assertion in 2 of 3 tests. For a syncer test, the post-condition (record created, count changed, attribute set) should also be asserted. Medium priority.
  - Note: These tests are characterization-like in style — verifying no crash rather than verifying outcome. Acceptable as a baseline, but should be strengthened.

### test/services/region_cc/game_plan_syncer_test.rb
- **Lines:** 121 | **Tests:** 6 | **Assertions:** 7
- Issues:
  - E02: Lines 68, 84 — `assert_nothing_raised do` — two tests assert only that no exception is raised when syncing game plans with stubbed HTML. No post-condition verification.

### test/services/region_cc/league_syncer_test.rb
- **Lines:** 110 | **Tests:** 4 | **Assertions:** 12
- Issues: None. Tests verify specific attributes after sync (names, counts). Good assertion density (3.0 per test).

### test/services/region_cc/metadata_syncer_test.rb
- **Lines:** 133 | **Tests:** 6 | **Assertions:** 6
- Issues:
  - E02: Lines 77, 93, 109 — Three tests use `assert_nothing_raised` as their **only** assertion. The metadata syncer reads category lists, group lists, and discipline lists — specific returned data could be verified. Medium priority.

### test/services/region_cc/party_syncer_test.rb
- **Lines:** 131 | **Tests:** 7 | **Assertions:** 8
- Issues:
  - E02: Line 78 — `assert_nothing_raised` as the only assertion in the "syncs party results" test. Should verify record state after sync.

### test/services/region_cc/registration_syncer_test.rb
- **Lines:** 71 | **Tests:** 2 | **Assertions:** 2
- Issues:
  - E02: Line 47 — `assert_nothing_raised` as the only assertion for the first test. The syncer creates RegistrationListCc records — at minimum assert that `RegistrationListCc.new` was called or that the record attributes were set.

### test/services/region_cc/tournament_syncer_test.rb
- **Lines:** 140 | **Tests:** 4 | **Assertions:** 4
- Issues:
  - E02: Lines 38, 74, 117 — Three of four tests use `assert_nothing_raised` as their only assertion. The tournament syncer should result in verifiable state (TournamentCc records, sync counts, etc.). Medium priority.

### test/services/table_monitor/game_setup_test.rb
- **Lines:** 280 | **Tests:** 10 | **Assertions:** 24
- Issues:
  - E02: Line 97 — `assert_not_nil @tm.game_id, "game_id muss nach GameSetup gesetzt sein"` — verifies presence only. Should also verify `@tm.game_id == game.id`.

### test/services/table_monitor/result_recorder_test.rb
- **Lines:** 253 | **Tests:** 9 | **Assertions:** 24
- Issues:
  - E02: Lines 120, 236 — `assert_nothing_raised` as sole or primary assertion in two tests. The result recorder writes to DB — post-conditions (game state, player scores) can be verified.

---

## Controller Tests (11 files)

### test/controllers/application_controller_test.rb
- **Lines:** 33 | **Tests:** 2 | **Assertions:** 8
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: Uses single-quote `test '...'` syntax. Valid but inconsistent with the file's own style (no double-quote test blocks). Cosmetic only.

### test/controllers/club_locations_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: Rails scaffold-generated CRUD tests. Good coverage pattern (index, new, create, show, edit, update, destroy). Assertions verify redirects and counts — adequate.

### test/controllers/discipline_phases_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/game_plans_controller_test.rb
- **Lines:** 52 | **Tests:** 7 | **Assertions:** 16
- Issues: None (has `frozen_string_literal: true`).

### test/controllers/party_monitors_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/registrations_controller_test.rb
- **Lines:** 51 | **Tests:** 2 | **Assertions:** 10
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: Manually inspects CSRF token via regex (`response.body.match(/<meta name="csrf-token"...>`). This is a brittle technique — if the HTML changes, the match fails. Medium priority to use `assert_csrf_meta_tags` helper or Rails `assert_select`.

### test/controllers/slots_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/table_locals_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/table_monitors_controller_test.rb
- **Lines:** 84 | **Tests:** 10 | **Assertions:** 22
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/uploads_controller_test.rb
- **Lines:** 48 | **Tests:** 7 | **Assertions:** 16
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/controllers/users/registrations_controller_test.rb
- **Lines:** 67 | **Tests:** 7 | **Assertions:** 11
- Issues:
  - I03: Missing `# frozen_string_literal: true`

---

## System Tests (13 files)

### test/system/admin/user_management_test.rb
- **Lines:** 15 | **Tests:** 2 | **Assertions:** 3
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/admin_access_test.rb
- **Lines:** 11 | **Tests:** 2 | **Assertions:** 3
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/club_locations_test.rb
- **Lines:** 46 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: Rails scaffold-generated system tests. Basic CRUD UI flows. Tests use `assert_selector` and `assert_text` which are Capybara-appropriate. No violations.

### test/system/discipline_phases_test.rb
- **Lines:** 50 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/docs_page_test.rb
- **Lines:** 27 | **Tests:** 3 | **Assertions:** 5
- Issues: None (has `frozen_string_literal: true`).

### test/system/game_plans_test.rb
- **Lines:** 46 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/party_monitors_test.rb
- **Lines:** 50 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/preferences_test.rb
- **Lines:** 31 | **Tests:** 2 | **Assertions:** 5
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/slots_test.rb
- **Lines:** 58 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/table_locals_test.rb
- **Lines:** 46 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/uploads_test.rb
- **Lines:** 46 | **Tests:** 4 | **Assertions:** 6
- Issues:
  - I03: Missing `# frozen_string_literal: true`

### test/system/user_authentication_test.rb
- **Lines:** 91 | **Tests:** 6 (3 via double-quote + 3 single-quote) | **Assertions:** 13
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - E04 (weak): Line 13 — `sleep 3 # Simulate the time it takes for a human to fill out the form` — hardcoded sleep in a test is a test smell. Should use Capybara's async wait instead. Not a missing assertion, but a brittle pattern.
  - Note: Uses single-quote test syntax in first 3 tests, double-quote in last 3. Mixed style in same file.

### test/system/user_profile_test.rb
- **Lines:** 14 | **Tests:** 1 | **Assertions:** 1
- Issues:
  - I03: Missing `# frozen_string_literal: true`

---

## Other Tests (14 files)

### Characterization (2)

#### test/characterization/region_cc_char_test.rb
- **Lines:** 296 | **Tests:** 17 | **Assertions:** 36
- Issues:
  - E03: Lines 39–41 — `skip "VCR-Kassette '#{name}.yml' fehlt..."` — this skip is **acceptable** per STANDARDS.md E03 exception #2: the tests require VCR cassettes from a live external service. The `with_vcr_cassette` helper correctly skips when cassettes are absent. Not a violation.
  - E02: Lines 166, 177 — `assert_not_nil result` as the only assertion in two tests that call `sync_league_teams_new`. Characterization tests are exempt from strict assertion standards per STANDARDS.md, but these should ideally verify the specific rescue behavior documented in the comments.
  - Note: Characterization tests are explicitly exempt from naming/assertion standards per STANDARDS.md. All issues noted here are informational only.

#### test/characterization/table_monitor_char_test.rb
- **Lines:** 504 | **Tests:** 41 | **Assertions:** 81
- Issues:
  - E02: Lines 223, 234 — `assert_not_nil game.started_at` / `assert_not_nil game.ended_at` — followed by more specific assertions in context (the timestamp is checked for presence after a state transition). Acceptable as precondition checks in characterization tests.
  - Note: Characterization tests are explicitly exempt from naming/assertion standards per STANDARDS.md. Good assertion density (1.98 per test).

---

### Scraping (3)

#### test/scraping/change_detection_test.rb
- **Lines:** 139 | **Tests:** 5 | **Assertions:** 10
- Issues:
  - E02: Line 29 — `assert_not_nil tournament.reload.sync_date` — followed by stronger time-delta assertion on line 30–31. The not_nil is a precondition. Acceptable.
  - Note: Has `frozen_string_literal: true`. Good coverage.

#### test/scraping/scraping_smoke_test.rb
- **Lines:** 226 | **Tests:** 11 | **Assertions:** 13
- Issues:
  - E04: Line 151 — `assert true, "Individual failures should not stop batch scraping"` — the test contains only this assertion. The behavior documented in the comment (batch continues after individual failure) is not actually tested; the assertion always passes. Either test the actual behavior (with stubs triggering one failure) or delete this test with a comment in the commit message.
  - E02: Lines 27, 35, 54, 83, 100, 120, 137 — `assert_nothing_raised` as primary assertion in 7 of 11 tests. Per STANDARDS.md, `assert_nothing_raised` is acceptable in scraping smoke tests (explicit exception in the standards). These are correctly scoped to scraping tests only.
  - Note: Has `frozen_string_literal: true`. The smoke test philosophy (verify no crash) is documented in the file header. Per STANDARDS.md, `assert_nothing_raised` is acceptable here.

#### test/scraping/tournament_scraper_test.rb
- **Lines:** 124 | **Tests:** 5 | **Assertions:** 28
- Issues: None. Has `frozen_string_literal: true`. Good assertion density (5.6 per test). Comment at line 9 explicitly states no skip-tests philosophy.

---

### Concerns (2)

#### test/concerns/local_protector_test.rb
- **Lines:** 98 | **Tests:** 5 | **Assertions:** 11
- Issues: None. Has `frozen_string_literal: true`. Tests correctly document that LocalProtector is disabled in tests and verifies only helper methods (hash_diff, unprotected accessor).

#### test/concerns/source_handler_test.rb
- **Lines:** 73 | **Tests:** 4 | **Assertions:** 10
- Issues:
  - E02: Line 71 — `assert_nothing_raised { tournament.save! }` — only assertion in the "only runs when record has changes" test. Should also verify that `tournament.reload.sync_date` did not change (i.e., the side effect of the save-without-changes path).
  - Note: Has `frozen_string_literal: true`.

---

### Helpers (2)

#### test/helpers/current_helper_test.rb
- **Lines:** 38 | **Tests:** 5 | **Assertions:** 6
- Issues:
  - E01 (structural): The `LoggedInTest` subclass (lines 4–11) defines `attr_reader :current_user` and a `setup` block but contains **zero test methods**. It appears to be a test base class that was never given tests. The outer `CurrentHelperTest` class also has no tests — all 5 tests are in `LoggedOutTest`. This structure may cause confusion about scope.
  - E02: Line 27 — `test "current_user&.admin? returns true for an admin"` asserts `assert_nil current_account_user` — the test name says "returns true for an admin" but the assertion checks nil (which is what a logged-out test would return). The test name is misleading.
  - I03: Missing `# frozen_string_literal: true`

#### test/helpers/filters_helper_test.rb
- **Lines:** 74 | **Tests:** 13 | **Assertions:** 14
- Issues:
  - Note: Has `frozen_string_literal: true`. Good coverage with 1.08 assertions per test — typical for single-input/output helper tests where each test case directly verifies one behavior.

---

### Integration (1)

#### test/integration/users_test.rb
- **Lines:** 20 | **Tests:** 2 | **Assertions:** 3
- Issues:
  - I03: Missing `# frozen_string_literal: true`
  - Note: Tests account deletion and invalid timezone handling. Adequate coverage for the behaviors tested.

---

### Tasks (1)

#### test/tasks/auto_reserve_tables_test.rb
- **Lines:** 446 | **Tests:** 12 | **Assertions:** 17
- Issues:
  - E02: Line 295 — `assert_not_nil result` — verifies Google Calendar event was returned but should also verify `result.id == "test_event_999"`. The mock already defines this expectation, so the assertion can be tightened.
  - W02 (setup): Uses `Model.create!` extensively. Per STANDARDS.md, acceptable for complex multi-record setups. The tournament bracket + table kinds + players + seedings cannot be expressed in static fixtures.
  - I03: Missing `# frozen_string_literal: true`
  - Note: Good test coverage of the auto-reserve task logic. 446 lines is large but the setup complexity justifies it.

---

### Other (1 — optimistic_updates)

#### test/optimistic_updates_test.rb
- **Lines:** 65 | **Tests:** 0 | **Assertions:** 0
- Issues:
  - E04 (critical): This is **not a test file** — it is a standalone Ruby script with `puts` statements, not a Minitest test class. It loads `config/environment` directly (not `test_helper`) and has no class definition, no assertions, and no test runner invocation. It runs `ScoreboardOptimisticService` which may not exist. This file should be **deleted** (it runs when `rails test` glob includes the test directory, which causes errors) or moved to a `bin/` script.
  - I03: Missing `# frozen_string_literal: true`

---

## Priority Files for Phase 7-9

**Phase assignment:** Phase 7 = model tests | Phase 8 = service tests | Phase 9 = controller, system, other tests

---

### High Priority — Error Level (E01, E02, E03, E04)

#### Phase 7 (Model Tests)

| File | Issues | Action |
|------|--------|--------|
| test/models/club_location_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/discipline_phase_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/game_plan_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/party_monitor_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/slot_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/source_attribution_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/sync_hash_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/table_local_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/training_source_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/upload_test.rb | E01 — zero tests, scaffold stub | Delete stub or write real tests |
| test/models/league_test.rb | E03 (line 10 skip), E02 (disjunction) | Fix skip and weak assertion |
| test/models/tournament_test.rb | E02 — assert_nothing_raised only | Add post-condition assertion |
| test/models/tournament_monitor_ko_test.rb | E02 — 2 tests with assert_nothing_raised only | Add post-condition assertions |
| test/models/table_monitor/options_presenter_test.rb | E02 — 3 not_nil-only tests | Strengthen to verify actual values |
| test/models/player_search_test.rb | E02 — assert_not_nil examples[:description] | Verify content, not just presence |

#### Phase 8 (Service Tests)

| File | Issues | Action |
|------|--------|--------|
| test/services/region_cc/competition_syncer_test.rb | E02 — 2 of 3 tests are assert_nothing_raised only | Add post-condition assertions |
| test/services/region_cc/tournament_syncer_test.rb | E02 — 3 of 4 tests are assert_nothing_raised only | Add post-condition assertions |
| test/services/region_cc/metadata_syncer_test.rb | E02 — 3 tests assert_nothing_raised only | Add post-condition assertions |
| test/services/region_cc/registration_syncer_test.rb | E02 — primary test assert_nothing_raised only | Add post-condition assertions |
| test/services/region_cc/party_syncer_test.rb | E02 — 1 test assert_nothing_raised only | Add post-condition assertion |
| test/services/region_cc/club_cloud_client_test.rb | E02 — assert_not_nil res/doc/PATH_MAP | Verify content, check PATH_MAP usage |
| test/services/region_cc/branch_syncer_test.rb | E02 — assert_not_nil branch_cc | Verify cc_id attribute |
| test/services/table_monitor/result_recorder_test.rb | E02 — 2 assert_nothing_raised only tests | Add post-condition assertions |

#### Phase 9 (Controller/System/Other Tests)

| File | Issues | Action |
|------|--------|--------|
| test/optimistic_updates_test.rb | E04 — not a test file, plain Ruby script | Delete or move to bin/ |
| test/scraping/scraping_smoke_test.rb | E04 — assert true at line 151 | Fix or delete test at line 146–152 |
| test/helpers/current_helper_test.rb | E01 (LoggedInTest empty), E02 (misleading test name) | Remove empty subclass or add tests; fix test name |
| test/concerns/source_handler_test.rb | E02 — assert_nothing_raised only | Add sync_date unchanged assertion |
| test/system/user_authentication_test.rb | sleep 3 brittle pattern | Replace with Capybara async wait |

---

### Medium Priority — Warning Level (W01, W02)

No W01 (def test_) violations found — the codebase already uses `test "description" do` universally.

No W02 (FactoryBot) violations found — no factory files exist, no `build()`/`create()` factory calls found.

---

### Informational — I01, I02, I03

#### I01/I02: Global helper inclusion smell

`SnapshotHelpers` is globally included in all test classes but has **zero callers** outside its own file. All 6 methods (save_snapshot, load_snapshot, assert_matches_snapshot, update_snapshot, snapshot_attributes, assert_html_structure_unchanged) are unused. Recommended action: remove global inclusion or delete the module if it is not intended for near-term use.

`ScrapingHelpers` is globally included in all test classes but is only relevant to ~4 scraping test files. Methods like `assert_tournament_scraped`, `assert_scraping_detected_changes`, `assert_sync_date_unchanged`, `snapshot_name` are not called in model/controller/system tests. Recommended action: narrow inclusion scope in test_helper.rb.

#### I03: Missing frozen_string_literal

40 files are missing `# frozen_string_literal: true`. This violates the project-wide convention mandated in CLAUDE.md. Files affected:

**Controllers (10):** application_controller_test, club_locations_controller_test, discipline_phases_controller_test, party_monitors_controller_test, registrations_controller_test, slots_controller_test, table_locals_controller_test, table_monitors_controller_test, uploads_controller_test, users/registrations_controller_test

**Models (16):** club_location, discipline_phase, game_plan, league, party_monitor, slot, source_attribution, sync_hash, table_local, tournament_auto_reserve, tournament_test, training_source, upload, user_test, + table_monitor/options_presenter (has it), table_heater_management (has it)

**System (12):** admin/user_management, admin_access, club_locations, discipline_phases, game_plans, party_monitors, preferences, slots, table_locals, uploads, user_authentication, user_profile

**Other (2):** helpers/current_helper_test, tasks/auto_reserve_tables_test, integration/users_test, optimistic_updates_test

---

### Clean Files (no E/W issues)

Files with no error or warning-level issues (may have I03):

- test/models/club_search_test.rb
- test/models/location_search_test.rb
- test/models/tournament_search_test.rb
- test/models/tournament_ko_integration_test.rb
- test/models/tournament_plan_ko_test.rb (E02 minor — nil checks with follow-on assertions)
- test/models/table_monitor/score_engine_test.rb
- test/models/table_heater_management_test.rb (setup complexity acceptable)
- test/services/region_cc/club_syncer_test.rb
- test/services/region_cc/league_syncer_test.rb
- test/services/table_monitor/game_setup_test.rb (E02 minor — one not_nil check)
- test/controllers/game_plans_controller_test.rb
- test/scraping/tournament_scraper_test.rb
- test/scraping/change_detection_test.rb
- test/concerns/local_protector_test.rb
- test/helpers/filters_helper_test.rb
- test/characterization/table_monitor_char_test.rb (exempt)
- test/characterization/region_cc_char_test.rb (E03 exempt — VCR infrastructure)
- test/system/docs_page_test.rb
- test/integration/users_test.rb
- test/models/user_test.rb
- test/models/tournament_monitor_ko_test.rb (after E02 fixes)
