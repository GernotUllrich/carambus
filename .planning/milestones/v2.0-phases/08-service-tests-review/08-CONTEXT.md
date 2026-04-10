# Phase 8: Service Tests Review - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Review and improve all 12 service test files against Phase 6 standards (STANDARDS.md). Fix issues identified in AUDIT-REPORT.md. This phase modifies existing test files only — 10 RegionCc syncer tests + 2 TableMonitor service tests.

</domain>

<decisions>
## Implementation Decisions

### RegionCc Syncer Assertion Strategy
- **D-01:** Add post-condition assertions after each sole `assert_nothing_raised` — keep the no-crash check, then add 1-2 assertions verifying the sync outcome (record count changed, attribute set, association created). ~15 cases across 8 files.
- **D-02:** Files affected: branch_syncer_test.rb, competition_syncer_test.rb, game_plan_syncer_test.rb, metadata_syncer_test.rb, party_syncer_test.rb, registration_syncer_test.rb, tournament_syncer_test.rb. (league_syncer_test.rb and club_syncer_test.rb are clean.)
- **D-03:** Do NOT remove `assert_nothing_raised` blocks — they serve as the characterization baseline from v1.0. Add assertions after them, not instead of them.

### ClubCloud Client Tests
- **D-04:** Strengthen response checks in club_cloud_client_test.rb — replace `assert_not_nil res/doc` with checks on response structure (status code, parsed body type, expected keys).
- **D-05:** Remove the useless `assert_not_nil PATH_MAP` constant test — constants are never nil unless the class failed to load.

### TableMonitor Service Tests
- **D-06:** Fix sole-assertion cases only in game_setup_test.rb and result_recorder_test.rb — same approach as Phase 7. These were written in v1.0 and are mostly solid.
- **D-07:** game_setup_test.rb: Line 97 `assert_not_nil @tm.game_id` — strengthen to verify the actual game ID value.
- **D-08:** result_recorder_test.rb: Lines 120, 236 `assert_nothing_raised` — add post-condition assertions on game state/scores.

### Carrying Forward
- **D-09:** Add `# frozen_string_literal: true` to all service test files missing it.
- **D-10:** Fixtures primary, `test "desc" do` naming, MiniTest assertions baseline (from Phase 6).

### Claude's Discretion
- Exact post-condition assertions for each syncer (read the syncer code and VCR cassettes to determine meaningful checks)
- Whether to use `assert_difference` or explicit before/after counts for record creation assertions
- Processing order within the phase

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Outputs
- `.planning/phases/06-audit-baseline-standards/STANDARDS.md` — Issue categories and conventions
- `.planning/phases/06-audit-baseline-standards/AUDIT-REPORT.md` — Per-file issue catalogue (service tests section)

### Service Source Files (for understanding what to assert)
- `app/services/region_cc/club_cloud_client.rb` — HTTP client, PATH_MAP constant
- `app/services/region_cc/branch_syncer.rb` — Branch sync logic
- `app/services/region_cc/competition_syncer.rb` — Competition sync logic
- `app/services/region_cc/game_plan_syncer.rb` — Game plan sync logic
- `app/services/region_cc/metadata_syncer.rb` — Metadata (categories, groups, disciplines) sync
- `app/services/region_cc/party_syncer.rb` — Party sync logic
- `app/services/region_cc/registration_syncer.rb` — Registration sync logic
- `app/services/region_cc/tournament_syncer.rb` — Tournament sync logic
- `app/services/table_monitor/game_setup.rb` — Game setup service
- `app/services/table_monitor/result_recorder.rb` — Result recording service

### Test Infrastructure
- `test/support/vcr_setup.rb` — VCR configuration (cassette recording/playback)
- `test/support/scraping_helpers.rb` — HTTP stubbing helpers
- `test/snapshots/vcr/` — VCR cassettes used by syncer tests

</canonical_refs>

<code_context>
## Existing Code Insights

### Files with Issues (from AUDIT-REPORT.md)
- test/services/region_cc/branch_syncer_test.rb — 1 E02 (assert_not_nil as weak post-condition)
- test/services/region_cc/club_cloud_client_test.rb — 8 E02 (7 weak response checks + 1 useless constant test)
- test/services/region_cc/competition_syncer_test.rb — 2 E02 (assert_nothing_raised sole assertion)
- test/services/region_cc/game_plan_syncer_test.rb — 2 E02 (assert_nothing_raised sole assertion)
- test/services/region_cc/metadata_syncer_test.rb — 3 E02 (assert_nothing_raised sole assertion)
- test/services/region_cc/party_syncer_test.rb — 1 E02 (assert_nothing_raised sole assertion)
- test/services/region_cc/registration_syncer_test.rb — 1 E02 (assert_nothing_raised sole assertion)
- test/services/region_cc/tournament_syncer_test.rb — 3 E02 (assert_nothing_raised sole assertion)
- test/services/table_monitor/game_setup_test.rb — 1 E02 (assert_not_nil game_id)
- test/services/table_monitor/result_recorder_test.rb — 2 E02 (assert_nothing_raised sole assertion)

### Clean Files
- test/services/region_cc/league_syncer_test.rb — No issues (good assertion density)
- test/services/region_cc/club_syncer_test.rb — No significant issues

### Established Patterns
- All syncer tests use VCR cassettes via `vcr_cassette` helper or `VCR.use_cassette`
- Tests inject `ClubCloudClient` doubles into syncers
- WebMock stubs HTTP requests globally in test env

</code_context>

<specifics>
## Specific Ideas

No specific requirements — apply STANDARDS.md consistently per AUDIT-REPORT.md findings. Read each syncer's source to determine what meaningful post-conditions to assert.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 08-service-tests-review*
*Context gathered: 2026-04-10*
