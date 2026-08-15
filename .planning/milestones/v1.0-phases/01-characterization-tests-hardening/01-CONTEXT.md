# Phase 1: Characterization Tests & Hardening - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Pin existing behavior of TableMonitor (3903 lines) and RegionCc (2728 lines) with characterization tests. Fix AASM configuration and test infrastructure issues that would corrupt tests. Establish Reek baseline for smell measurement. No extraction or refactoring in this phase.

</domain>

<decisions>
## Implementation Decisions

### Test Scope Strategy
- **D-01:** Critical paths only — focus on state transitions, callbacks, broadcasts, sync operations. Target ~30-40 tests total, not exhaustive coverage of all 96+ methods.
- **D-02:** Use test_after_commit gem (or equivalent) to fire after_commit callbacks inside transactional tests. Avoid creating a separate non-transactional test base class.
- **D-03:** Record fresh VCR cassettes for RegionCc char tests against real ClubCloud API. Existing cassettes may not cover all sync paths needed for characterization.

### Test File Organization
- **D-04:** Characterization tests go in `test/characterization/` — a new dedicated directory, separate from unit tests. Run as group via `bin/rails test test/characterization/`.
- **D-05:** File naming convention: `{model_name}_char_test.rb` (e.g., `table_monitor_char_test.rb`, `region_cc_char_test.rb`).

### AASM Hardening
- **D-06:** Enable `whiny_transitions: true` globally in the TableMonitor AASM block. If existing tests break, fix them — those are real bugs being surfaced by silent guard failures.
- **D-07:** Include PartyMonitor in characterization tests. PartyMonitor has its own table and inherits from ApplicationRecord (NOT an STI subclass of TableMonitor). It connects via a polymorphic `tournament_monitor` relationship. Extraction may affect shared interfaces — pin both now.

### Reek Integration
- **D-08:** One-time Reek report only. Run reek on TableMonitor and RegionCc, save output to `.planning/` as baseline. Run again after Phase 5 for comparison. No gem addition to Gemfile, no CI integration.

### Claude's Discretion
- Exact test method grouping and organization within char test files
- Which specific state transitions and callback chains to prioritize within the ~30-40 test target
- Whether to add a `test:characterization` Rake task for convenience

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Models Under Test
- `app/models/table_monitor.rb` — Primary extraction target (3903 lines, AASM state machine, 96 methods)
- `app/models/region_cc.rb` — Secondary extraction target (2728 lines, ClubCloud sync)
- `app/models/party_monitor.rb` — Separate model (own table, inherits ApplicationRecord), connected via polymorphic `tournament_monitor` relationship

### Test Infrastructure
- `test/test_helper.rb` — Main test config, LocalProtector override, FactoryBot setup
- `test/support/vcr_setup.rb` — VCR configuration for HTTP recording
- `test/support/scraping_helpers.rb` — Helpers for scraping-related tests
- `test/support/snapshot_helpers.rb` — Snapshot test helpers
- `lib/tasks/test.rake` — Custom test tasks (test:critical, test:scraping, etc.)

### Existing Test Patterns
- `test/concerns/` — Example of how concerns are tested in this codebase
- `test/scraping/` — Example of VCR-based tests

### Research Findings
- `.planning/research/PITFALLS.md` — Critical pitfalls for after_commit testing, AASM whiny_transitions, VCR cassette staleness
- `.planning/research/FEATURES.md` — Characterization test scope and extraction ordering
- `.planning/research/ARCHITECTURE.md` — Component boundaries and data flow for TableMonitor and RegionCc

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/vcr_setup.rb`: VCR configuration already exists — extend for RegionCc ClubCloud cassettes
- `test/support/scraping_helpers.rb`: Pattern for HTTP-dependent tests — adapt for sync tests
- `lib/tasks/test.rake`: Custom Rake tasks exist — add `test:characterization` following same pattern
- `test/fixtures/`: Extensive fixture set for models — use for setting up char test preconditions

### Established Patterns
- Minitest with `test "description"` syntax (not `def test_method`)
- `fixtures :all` loaded in base test class
- FactoryBot available via `include FactoryBot::Syntax::Methods`
- WebMock blocks all external HTTP by default (`WebMock.disable_net_connect!`)
- Sidekiq testing mode available (`require "sidekiq/testing"`)
- LocalProtector disabled in test env via `LocalProtectorTestOverride`

### Integration Points
- AASM block in `app/models/table_monitor.rb` — where `whiny_transitions: true` goes
- `config/application.rb` line 119 — ActionCable config referenced by TableMonitor broadcasts
- `app/reflexes/table_monitor_reflex.rb` — Reflex that triggers TableMonitor state changes
- `app/jobs/table_monitor_job.rb` — Job triggered by after_update_commit callback

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for characterization testing.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-characterization-tests-hardening*
*Context gathered: 2026-04-09*
