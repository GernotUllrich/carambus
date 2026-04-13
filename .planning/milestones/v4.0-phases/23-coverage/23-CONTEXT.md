# Phase 23: Coverage - Context

**Gathered:** 2026-04-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Controller, channel, and job test coverage for the League/Party/PartyMonitor ecosystem. Tests for LeaguesController, PartiesController, PartyMonitorsController, LeagueTeamsController, PartyMonitorReflex (critical paths), and auth guard smoke tests. Fix existing broken/skipped tests. Full suite must remain green.

</domain>

<decisions>
## Implementation Decisions

### Controller Scope & Depth
- **D-01:** Test all four controllers: LeaguesController, PartiesController, PartyMonitorsController, LeagueTeamsController.
- **D-02:** Test key actions + auth guards per controller — not full CRUD for standard scaffold actions. Focus on: index/show (public), create/update/destroy (admin guard verified), plus custom actions (reload_from_cc, party_monitor, assign_player, remove_player, upload_form).
- **D-03:** Fix the 4 skipped tests in PartyMonitorsControllerTest (caused by missing Party/League fixture chain).

### Reflex Testing
- **D-04:** Test critical paths only for PartyMonitorReflex — 5-6 key methods: start_round, finish_round, assign_player, close_party, reset_party_monitor. Skip parameter editing and edge case methods.
- **D-05:** Reflex tests need proper AASM state setup — use fixtures with PartyMonitor in the correct state for each test.

### Auth Guard Testing
- **D-06:** Per-controller smoke tests for auth guards: one test verifying unauthenticated access is blocked for admin actions, one test verifying public actions (index/show) work without auth. Plus `local_server?` guard test on PartyMonitorsController.
- **D-07:** No full per-action auth matrix — trust Devise/admin_only_check works; smoke tests catch regressions.

### Fixture Strategy
- **D-08:** Fix existing Party fixture to include league association (unblocks 4 skipped tests). Add minimal League/LeagueTeam/Party fixture chain for controller tests. Reuse existing fixtures where possible.
- **D-09:** No new FactoryBot factories — use fixtures consistently with the rest of the test suite.

### Claude's Discretion
- How to structure test files (one per controller vs grouped)
- Which specific reflex methods beyond the 5-6 critical paths to include if easy
- Test helper design for PartyMonitor AASM state setup
- Whether to add channel tests (no PartyMonitor-specific channels found — may be unnecessary)
- Whether to add job tests (no dedicated PartyMonitor/League jobs found — may be unnecessary)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Target Controllers (PRIMARY)
- `app/controllers/leagues_controller.rb` — CRUD + reload_from_cc custom actions, admin_only_check guard
- `app/controllers/parties_controller.rb` — CRUD + party_monitor custom action, admin_only_check guard
- `app/controllers/party_monitors_controller.rb` — CRUD + assign_player/remove_player/upload_form, local_server? guard
- `app/controllers/league_teams_controller.rb` — Standard CRUD, admin_only_check guard

### Target Reflex
- `app/reflexes/party_monitor_reflex.rb` — 17 methods, test critical paths only

### Existing Tests (fix/extend)
- `test/controllers/party_monitors_controller_test.rb` — 6 tests (4 skipped), fix fixture gaps
- `test/system/party_monitors_test.rb` — Basic system tests (reference)

### Test Patterns (follow these)
- `test/controllers/tournaments_controller_test.rb` — v2.1 controller test pattern (if exists)
- `test/controllers/tournament_monitors_controller_test.rb` — v2.1 controller test pattern (if exists)
- `test/support/party_monitor_test_helper.rb` — Existing PartyMonitor test helpers

### Fixtures
- `test/fixtures/parties.yml` — Needs league association fix
- `test/fixtures/leagues.yml` — Existing league fixtures
- `test/fixtures/league_teams.yml` — Existing league team fixtures

### Requirements
- `.planning/REQUIREMENTS.md` — COV-01 (controller tests), COV-02 (channel/job tests), COV-03 (all tests green)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApiProtectorTestOverride` and `LocalProtectorTestOverride` — in test_helper.rb
- `party_monitor_test_helper.rb` — existing helper for PartyMonitor test setup
- Existing `party_monitors_controller_test.rb` — 6 tests to fix and extend
- v2.1 controller test patterns from TournamentMonitor/Tournament controllers

### Established Patterns
- Minitest with fixtures (not RSpec, not FactoryBot)
- `admin_only_check` is a before_action in ApplicationController — test with sign_in/sign_out
- `local_server?` check in PartyMonitorsController — test by stubbing `ApplicationRecord.local_server?`
- WebMock disables external HTTP in tests
- `frozen_string_literal: true` in all Ruby files

### Integration Points
- LeaguesController `reload_from_cc` actions need local_server? check + league fixture
- PartiesController `party_monitor` action creates a PartyMonitor — needs party with league
- PartyMonitorsController `assign_player`/`remove_player` manipulate Seedings — need player fixtures
- PartyMonitorReflex methods fire AASM events — need PartyMonitor in correct state

</code_context>

<specifics>
## Specific Ideas

- Follow the v2.1 controller test pattern from TournamentMonitorsController tests — same auth guard structure, same fixture approach.
- The 4 skipped tests in party_monitors_controller_test.rb fail because `party.league` returns nil in the view — fixing the party fixture chain unblocks them immediately.
- Channel/job tests may not be needed — no dedicated PartyMonitor/League channels or jobs were found. COV-02 may be satisfied by documenting the absence rather than writing tests for non-existent code.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 23-coverage*
*Context gathered: 2026-04-12*
