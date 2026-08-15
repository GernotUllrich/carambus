# Phase 7: Model Tests Review - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Review and improve all 22 model test files against Phase 6 standards (STANDARDS.md). Fix issues identified in AUDIT-REPORT.md. This phase modifies existing test files only — no new test files for untested models (that's a future milestone).

</domain>

<decisions>
## Implementation Decisions

### Empty Stub Handling
- **D-01:** Delete all 10 empty scaffold test stubs (E01). Files: club_location_test.rb, discipline_phase_test.rb, game_plan_test.rb, party_monitor_test.rb, slot_test.rb, source_attribution_test.rb, sync_hash_test.rb, table_local_test.rb, training_source_test.rb, upload_test.rb. They provide false confidence — if tests are needed, they'll be created in the coverage expansion milestone.

### Weak Assertion Fixes
- **D-02:** Fix only sole-assertion cases (E02) — where `assert_nothing_raised` or `assert_not_nil` is the ONLY assertion in a test. Add post-condition checks (verify actual values, state changes, or side effects).
- **D-03:** Leave precondition checks alone — `assert_not_nil` followed by stronger assertions is an acceptable pattern per STANDARDS.md.

### Large File Structure
- **D-04:** Clean up the 3 large files in place — do not split them. They're legitimately large because they test complex features. Fix issues (weak assertions, duplication) within existing structure.
  - table_heater_management_test.rb (824L, 46 tests)
  - score_engine_test.rb (703L, 69 tests)
  - tournament_auto_reserve_test.rb (586L, 18 tests)

### frozen_string_literal
- **D-05:** Add `# frozen_string_literal: true` to all model test files that are missing it during this phase. Natural touchpoint since we're editing them anyway.

### Skipped Test Resolution
- **D-06:** Fix the league_test.rb conditional skip (E03 at line 10) — either ensure the fixture has the required associations or restructure the test.

### Carrying Forward from Phase 6
- **D-07:** Fixtures primary (D-04 from Phase 6)
- **D-08:** `test "description" do` naming standard (D-06 from Phase 6)
- **D-09:** MiniTest assertions baseline (D-08 from Phase 6)
- **D-10:** shoulda-matchers available but not mandated (D-07 from Phase 6)

### Claude's Discretion
- Exact post-condition assertions to add for each weak-assertion fix (read the model code to determine meaningful checks)
- Order of file processing within the phase
- Whether to add missing frozen_string_literal to files that are only being deleted

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Outputs (rubric and work queue)
- `.planning/phases/06-audit-baseline-standards/STANDARDS.md` — Issue categories, severity levels, conventions to enforce
- `.planning/phases/06-audit-baseline-standards/AUDIT-REPORT.md` — Per-file issue catalogue with line numbers — the work queue for this phase

### Testing Infrastructure
- `test/test_helper.rb` — Main test configuration, fixture loading, LocalProtector override
- `test/support/ko_tournament_test_helper.rb` — Complex tournament test setup/teardown (used by tournament_* test files)

### Model Files (for understanding what to assert)
- `app/models/table_monitor.rb` — Source for score_engine_test and table_heater_management_test assertions
- `app/models/league.rb` — Source for fixing league_test.rb skip
- `app/models/tournament.rb` — Source for tournament_test.rb assertion strengthening

</canonical_refs>

<code_context>
## Existing Code Insights

### Files to Delete (10 empty stubs)
- test/models/club_location_test.rb (18L)
- test/models/discipline_phase_test.rb (20L)
- test/models/game_plan_test.rb (18L)
- test/models/party_monitor_test.rb (32L)
- test/models/slot_test.rb (24L)
- test/models/source_attribution_test.rb (7L)
- test/models/sync_hash_test.rb (18L)
- test/models/table_local_test.rb (18L)
- test/models/training_source_test.rb (7L)
- test/models/upload_test.rb (18L)

### Files to Fix (weak assertions — sole-assertion cases only)
- test/models/table_heater_management_test.rb — Lines 541, 575 (assert_not_nil as sole assertion)
- test/models/table_monitor/options_presenter_test.rb — Lines 206, 234, 247 (assert_not_nil as sole assertion)
- test/models/tournament_monitor_ko_test.rb — Lines 155, 177 (assert_nothing_raised as sole assertion)
- test/models/tournament_test.rb — Line 16 (assert_nothing_raised as sole assertion)

### Files to Fix (skipped test)
- test/models/league_test.rb — Line 10 conditional skip

### Files Needing frozen_string_literal
- Check each of the 22 model test files; add where missing

### Clean Files (no changes needed beyond frozen_string_literal)
- test/models/club_search_test.rb
- test/models/location_search_test.rb
- test/models/player_search_test.rb
- test/models/tournament_plan_ko_test.rb
- test/models/tournament_search_test.rb
- test/models/tournament_auto_reserve_test.rb
- test/models/tournament_ko_integration_test.rb
- test/models/user_test.rb
- test/models/table_monitor/score_engine_test.rb

</code_context>

<specifics>
## Specific Ideas

No specific requirements — apply STANDARDS.md consistently per AUDIT-REPORT.md findings.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 07-model-tests-review*
*Context gathered: 2026-04-10*
