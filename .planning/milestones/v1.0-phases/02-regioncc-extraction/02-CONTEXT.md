# Phase 2: RegionCc Extraction - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Reduce RegionCc from 2728 lines to ~200-300 lines by extracting all HTTP and sync logic into independently testable service objects. The public model interface (all sync_* and fix method signatures) must remain unchanged. No new features, no framework changes.

</domain>

<decisions>
## Implementation Decisions

### HTTP Client Design
- **D-01:** Extract get_cc, post_cc, post_cc_with_formdata into a standalone RegionCc::ClubCloudClient class. Keep Net::HTTP as the transport layer — replacing with Faraday is explicitly out of scope (REQUIREMENTS.md).
- **D-02:** ClubCloudClient manages its own login/session state internally. Caller passes base_url + credentials at initialization; client handles login/re-login and cookie management transparently. This preserves the current RegionCc behavior where login is implicit.

### Syncer Service Granularity
- **D-03:** Fine-grained syncers — 7-8 separate service classes, each focused on one domain:
  - `RegionCc::LeagueSyncer` — sync_leagues, sync_league_teams, sync_league_teams_new, sync_league_plan, sync_competitions, sync_seasons_in_competitions
  - `RegionCc::TournamentSyncer` — sync_tournaments, sync_tournament_ccs, sync_tournament_series_ccs, sync_championship_type_ccs
  - `RegionCc::PartySyncer` — sync_parties, sync_party_games
  - `RegionCc::BranchSyncer` — sync_branches
  - `RegionCc::ClubSyncer` — sync_clubs
  - `RegionCc::GamePlanSyncer` — sync_game_plans, sync_game_details
  - `RegionCc::CompetitionSyncer` — sync_competitions (if distinct from LeagueSyncer)
  - `RegionCc::RegistrationSyncer` — sync_registration_list_ccs, sync_registration_list_ccs_detail
  - Additional syncers for remaining methods: sync_team_players, sync_team_players_structure, sync_category_ccs, sync_group_ccs, sync_discipline_ccs, fix_tournament_structure
- **D-04:** Each syncer inherits from ApplicationService and follows the existing `.call(kwargs)` pattern. Consistent with all other services in `app/services/`.

### Delegation Pattern
- **D-05:** RegionCc keeps all sync_* and fix_* methods as thin one-liner wrappers that delegate to the corresponding service. External callers (jobs, controllers, rake tasks) continue calling `region_cc.sync_leagues(opts)` unchanged. Zero caller migration needed.
- **D-06:** The wrappers pass `self` (the RegionCc instance) and `opts` to each service: `RegionCc::LeagueSyncer.call(region_cc: self, **opts)`.

### VCR Cassette Strategy
- **D-07:** Reuse existing VCR cassettes unchanged. VCR intercepts at the Net::HTTP level, so the same cassettes work regardless of which Ruby class makes the HTTP call. Only re-record if tests actually fail after extraction.
- **D-08:** If cassette failures occur, re-record only the specific failing cassettes — not a blanket re-record of all cassettes.

### Claude's Discretion
- File organization within `app/services/region_cc/` — flat directory or subdirectories
- Internal method distribution when a sync method has helpers (keep helpers in the syncer that uses them)
- Error handling patterns within syncers (preserve existing rescue behavior)
- Exact method signature for ClubCloudClient initialization
- Whether fix_tournament_structure gets its own syncer or stays in RegionCc model

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models Under Extraction
- `app/models/region_cc.rb` — The 2728-line god object being extracted (HTTP methods at lines 586-700, sync methods at lines 795-2728)
- `app/models/application_record.rb` — Base model class with CableReady includes

### Existing Service Pattern
- `app/services/application_service.rb` — Base class for all services (`.call(kwargs)` pattern)
- `app/services/cuesco_scraper.rb` — Example of an HTTP-calling service in this codebase
- `app/services/kozoom_scraper.rb` — Another HTTP service example

### Characterization Tests (Safety Net)
- `test/characterization/region_cc_char_test.rb` — 56 characterization tests pinning sync behavior with VCR cassettes
- `test/support/vcr_setup.rb` — VCR configuration

### Phase 1 Context
- `.planning/phases/01-characterization-tests-hardening/01-CONTEXT.md` — Prior decisions on test infrastructure

### Quality Baselines
- `.planning/reek_baseline_region_cc.txt` — 460 Reek warnings before extraction (comparison target)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `ApplicationService` base class: `.call(kwargs)` → `new(kwargs).call` pattern ready to use
- VCR setup in `test/support/vcr_setup.rb`: cassette recording infrastructure
- Existing scraper services (`CuescoScraper`, `KozoomScraper`): patterns for HTTP-calling services
- `test/characterization/region_cc_char_test.rb`: 56 tests as extraction safety net

### Established Patterns
- Services in `app/services/` use `ApplicationService` base with single `.call` entry point
- Net::HTTP used directly (no HTTP abstraction gem) throughout the codebase
- `WebMock.disable_net_connect!` in tests — all HTTP must go through VCR or stubs
- `LocalProtector` concern guards global records — services don't need this (model keeps it)

### Integration Points
- `RegionCc` is called from: Sidekiq jobs (scheduled sync), admin controllers, rake tasks
- PATH_MAP constant defines all ClubCloud API endpoints — moves to ClubCloudClient
- `REPORT_LOGGER` and `DEBUG` constant — stay in model or move to services
- `belongs_to :region` and `has_many :branch_ccs` — stay in model

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for service extraction.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-regioncc-extraction*
*Context gathered: 2026-04-09*
