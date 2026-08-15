# Phase 10: Final Pass & Green Suite - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve all remaining test failures, errors, and skips to achieve a fully green test suite. Fix pre-existing fixture issues, broken controller scaffolds, ApiProtector test override, and attempt VCR cassette recording. Target: `bin/rails test` with 0 failures, 0 errors, minimal justified skips.

</domain>

<decisions>
## Implementation Decisions

### Green Suite Strategy
- **D-01:** Fix everything possible — attempt to resolve all 106 pre-existing failures/errors (31 failures + 75 errors). This includes:
  - Add missing fixtures: `club_bochum` (19 errors), `season_2024` (7 errors)
  - Fix `table_monitors` controller test fixture reference (10 errors)
  - Fix JSON::ParserError in tournament fixtures (4 errors)
  - Fix tournament_auto_reserve_test.rb PG::UniqueViolation (18 errors)
  - Fix auto_reserve_tables_test.rb issues (12 errors)
  - Fix controller scaffold test failures (auth, redirects)
  - Fix registrations_controller_test.rb remaining failures

### ApiProtector Override
- **D-02:** Add `ApiProtectorTestOverride` to `test/test_helper.rb`, mirroring the existing `LocalProtectorTestOverride`. This disables ApiProtector's `disallow_saving_local_records` in tests, preventing silent rollbacks for models with `include ApiProtector` (TournamentMonitor, PartyMonitor, TableMonitor, TableLocal, TournamentLocal, StreamConfiguration, CalendarEvent). This resolves TODO-01 from Phase 7.

### VCR Cassette Recording
- **D-03:** Attempt to record VCR cassettes for the 7 skipped characterization tests using NBV Region[1] dev credentials. If credentials work and external service is accessible, record cassettes and remove skips. If not, document skips as accepted with justification.

### Carrying Forward
- **D-04:** All conventions from Phases 6-9 remain in effect (fixtures primary, test "desc" naming, MiniTest assertions, frozen_string_literal).

### Claude's Discretion
- Exact fixture data for club_bochum, season_2024
- How to fix PG::UniqueViolation in auto_reserve tests (likely fixture ID conflicts)
- Controller test auth setup (sign_in helpers, fixture users)
- VCR recording approach and credential handling
- Order of fixes (infrastructure first, then cascading fixes)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Test Infrastructure
- `test/test_helper.rb` — Main config, LocalProtectorTestOverride (add ApiProtectorTestOverride here)
- `app/models/api_protector.rb` — ApiProtector concern source (understand what to override)
- `app/models/application_record.rb` — `local_server?` method definition
- `test/support/vcr_setup.rb` — VCR configuration for cassette recording
- `test/support/scraping_helpers.rb` — HTTP stubbing helpers

### Fixture Files
- `test/fixtures/clubs.yml` — Add club_bochum fixture here
- `test/fixtures/seasons.yml` — Add season_2024 fixture here
- `test/fixtures/table_monitors.yml` — Fix fixture reference for controller test

### Error Source Files
- `test/models/tournament_auto_reserve_test.rb` — PG::UniqueViolation (18 errors)
- `test/tasks/auto_reserve_tables_test.rb` — Related fixture issues (12 errors)
- `test/controllers/table_monitors_controller_test.rb` — Missing table_monitors method (10 errors)
- `test/models/player_search_test.rb` — Missing club_bochum fixture (12 errors)

### Phase 6 Outputs
- `.planning/phases/06-audit-baseline-standards/AUDIT-REPORT.md` — Full audit findings
- `.planning/phases/06-audit-baseline-standards/STANDARDS.md` — Convention reference

</canonical_refs>

<code_context>
## Existing Code Insights

### Pre-existing Failure Categories (from `bin/rails test`)
| Category | Count | Root Cause |
|----------|-------|------------|
| Missing club_bochum fixture | 19 errors | search tests reference non-existent fixture |
| Missing season_2024 fixture | 7 errors | controller/search tests reference non-existent fixture |
| table_monitors method missing | 10 errors | controller test scaffold uses wrong fixture accessor |
| PG::UniqueViolation | 18 errors | tournament_auto_reserve creates conflicting IDs |
| auto_reserve_tables | 12 errors | related fixture/setup issues |
| JSON::ParserError | 4 errors | tournament fixture has 'MyText' instead of valid JSON |
| Controller auth/redirect | ~6 failures | scaffold tests expect wrong redirects |
| registrations_controller | 4 failures | account registration test setup issues |
| Other | ~6 | miscellaneous |

### ApiProtector Models (will benefit from test override)
- TournamentMonitor, PartyMonitor, TableMonitor, TableLocal, TournamentLocal, StreamConfiguration, CalendarEvent

### Existing Patterns
- LocalProtectorTestOverride: prepends module that returns true from `disallow_saving_global_records`
- Same pattern needed for ApiProtector: prepend module returning true from `disallow_saving_local_records`

</code_context>

<specifics>
## Specific Ideas

- Fix infrastructure first (fixtures, ApiProtector override), then re-run to see cascading effect before tackling individual test fixes
- The 19 club_bochum + 7 season_2024 errors may resolve 26+ errors with just 2 fixture additions

</specifics>

<deferred>
## Deferred Ideas

None — this is the final phase.

</deferred>

---

*Phase: 10-final-pass-green-suite*
*Context gathered: 2026-04-10*
