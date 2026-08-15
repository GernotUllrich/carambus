# Phase 12: Tournament Characterization - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Pin Tournament model behavior (AASM state machine, scraping pipeline, dynamic attribute delegation, PaperTrail version baselines, Google Calendar integration, rankings calculation) before any extraction work. Tournament is 1775 lines. No extraction or refactoring in this phase.

</domain>

<decisions>
## Implementation Decisions

### Test Scope Strategy
- **D-01:** Cover all clusters: AASM (10 states, 8 events), scraping pipeline (~420 lines + 10 variant methods), dynamic attributes (13 define_method getters/setters), PaperTrail versioning, Google Calendar reservation, rankings calculation.
- **D-02:** Existing `tournament_test.rb` (51 lines) is left as-is — new characterization tests go in separate files.

### Scraping VCR Approach
- **D-03:** Record VCR cassettes from real ClubCloud tournament URLs. Claude discovers appropriate public tournament URLs from the codebase or existing cassettes during execution.
- **D-04:** The scraping method `scrape_single_tournament_public` has 10+ variant methods for different result formats — VCR cassettes should cover at least the most common variants.

### Test Organization
- **D-05:** Split by concern into separate test files in `test/models/`:
  - `tournament_aasm_test.rb` — AASM state transitions, guards, after_enter callbacks
  - `tournament_scraping_test.rb` — scrape_single_tournament_public with VCR cassettes
  - `tournament_attributes_test.rb` — 13 dynamic define_method getters/setters, tournament_local delegation for global records
  - `tournament_papertrail_test.rb` — PaperTrail version count baselines for all state-changing operations
  - Additional files for calendar/rankings if needed (Claude's discretion)

### PaperTrail Baselines
- **D-06:** Assert version counts for all state-changing operations: create, each AASM transition, attribute updates (including tournament_local delegation path for global records), destroy. These baseline counts are the sync contract — extraction must preserve them exactly.

### Reek Baseline
- **D-07:** Run Reek on `app/models/tournament.rb`. One-time baseline report saved to `.planning/phases/12-tournament-characterization/` for comparison after extraction phases.

### Claude's Discretion
- Exact test method grouping within each concern file
- Which AASM transitions and guard chains to prioritize
- Which scraping variants to cover with VCR (based on URL discovery)
- Whether to create a shared TournamentTestHelper for fixture setup
- How to handle the 13 dynamic attribute test coverage (all paths or representative subset)
- Whether calendar and rankings tests need their own files or fit in existing ones

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models Under Test
- `app/models/tournament.rb` — Primary target (1775 lines, AASM state machine, scraping, dynamic attributes, PaperTrail, calendar, rankings)
- `app/models/tournament_local.rb` — Delegation target for dynamic attribute getters/setters on global records (id < MIN_ID)
- `app/models/tournament_cc.rb` — ClubCloud association, referenced by scraping pipeline

### Related Models
- `app/models/tournament_monitor.rb` — Created by `initialize_tournament_monitor`, destroyed by `reset_tournament`
- `app/models/seeding.rb` — Managed by scraping pipeline, reordered by `reorder_seedings`
- `app/models/game.rb` — Created by scraping pipeline (game results parsing)
- `app/models/tournament_plan.rb` — Plan selection flow (tournament_mode_defined state)

### Test Infrastructure
- `test/test_helper.rb` — LocalProtector/ApiProtector overrides, VCR setup
- `test/models/tournament_test.rb` — Existing minimal test (51 lines)
- `test/support/vcr_setup.rb` — VCR configuration for HTTP recording
- `test/snapshots/vcr/` — Existing VCR cassette storage location

### Research Findings
- `.planning/research/PITFALLS.md` — PaperTrail double-versioning, dynamic attribute gotchas, AASM skip_validation_on_save
- `.planning/research/FEATURES.md` — Tournament responsibility clusters, extraction candidates
- `.planning/research/ARCHITECTURE.md` — Component boundaries, scraping pipeline data flow

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/vcr_setup.rb`: VCR configuration — extend for scraping cassettes
- `test/snapshots/vcr/`: Existing cassette storage — check for reusable tournament scraping cassettes
- `test/fixtures/tournament_plans.yml`: Production fixture plans from Phase 11 — reuse for Tournament tests
- `test/support/t04_tournament_test_helper.rb` / `test/support/t06_tournament_test_helper.rb`: Tournament setup patterns from Phase 11

### Established Patterns
- Minitest with `test "description"` syntax, `fixtures :all`, `use_transactional_tests = true`
- VCR cassettes named descriptively, stored in `test/snapshots/vcr/`
- `frozen_string_literal: true` in all files
- Private methods tested via `send(:method_name)`
- `assert_difference "model.versions.count"` for PaperTrail baselines

### Integration Points
- AASM `after_enter` on `:new_tournament` calls `reset_tournament` which destroys tournament_monitor
- `before_save` block extracts data hash keys into columns (lines 313-330)
- 13 `define_method` attributes delegate to `tournament_local` for records with `id < MIN_ID`
- `scrape_single_tournament_public` creates/updates seedings, games, game_participations via Nokogiri HTML parsing
- `calculate_and_cache_rankings` is AASM `after_enter` on `tournament_seeding_finished`

</code_context>

<specifics>
## Specific Ideas

- VCR cassettes should be recorded from real ClubCloud public tournament pages to capture actual HTML structure
- The 13 dynamic attributes need both paths tested: global record (id < MIN_ID, delegates to tournament_local) and local record (id >= MIN_ID, uses read_attribute directly)
- PaperTrail version counts are the sync contract between API and local servers — these assertions are critical for extraction safety

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 12-tournament-characterization*
*Context gathered: 2026-04-10*
