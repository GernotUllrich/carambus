# Phase 9: Controller, System & Other Tests Review - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Review and improve all 27 remaining test files (11 controller + 13 system + 3 other categories) against Phase 6 standards. Bulk frozen_string_literal sweep + 6 targeted logic fixes. Characterization tests (2 files) left as-is per STANDARDS.md exemption.

</domain>

<decisions>
## Implementation Decisions

### Targeted Fixes (6 issues)
- **D-01:** Delete `test/optimistic_updates_test.rb` — not a test file (standalone Ruby script with `puts`, no test class, no assertions). Causes errors when Rails test glob picks it up.
- **D-02:** Fix `test/scraping/scraping_smoke_test.rb` line 151 — `assert true` always passes. Either test the actual batch-continues-after-failure behavior or delete the test with justification.
- **D-03:** Fix `test/helpers/current_helper_test.rb` — empty `LoggedInTest` subclass (0 tests), misleading test name on line 27 ("returns true for admin" but asserts nil). Clean up structure.
- **D-04:** Fix `test/concerns/source_handler_test.rb` line 71 — sole `assert_nothing_raised` on save. Add post-condition checking `sync_date` didn't change.
- **D-05:** Fix `test/controllers/registrations_controller_test.rb` — brittle CSRF regex parsing. Replace with `assert_select 'meta[name="csrf-token"]'` or similar Rails helper.
- **D-06:** Fix `test/system/user_authentication_test.rb` — remove `sleep 3` hardcoded wait (line 13). Use Capybara async wait instead.

### Characterization Tests
- **D-07:** Leave both characterization test files (region_cc_char_test.rb, table_monitor_char_test.rb) as-is. They are explicitly exempt per STANDARDS.md. Only add frozen_string_literal if missing.

### frozen_string_literal Sweep
- **D-08:** Add `# frozen_string_literal: true` to all ~25 files missing it across controllers, system tests, and other test categories.

### Plan Structure
- **D-09:** Two parallel plans: one for the bulk frozen_string_literal sweep (~25 files), one for the 6 targeted logic fixes. No file overlap between plans.

### Carrying Forward
- **D-10:** Fixtures primary, `test "desc" do` naming, MiniTest assertions baseline, fix sole-assertion cases only (from Phases 6-8).

### Claude's Discretion
- Exact replacement for the CSRF regex in registrations_controller_test.rb
- Whether to delete or fix the `assert true` test in scraping_smoke_test.rb
- Capybara wait mechanism to replace the `sleep 3`
- How to restructure current_helper_test.rb (delete empty class vs add tests)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 6 Outputs
- `.planning/phases/06-audit-baseline-standards/STANDARDS.md` — Issue categories, conventions, exemptions
- `.planning/phases/06-audit-baseline-standards/AUDIT-REPORT.md` — Per-file issue catalogue (controller, system, other sections)

### Files to Fix
- `test/optimistic_updates_test.rb` — Delete (not a test file)
- `test/scraping/scraping_smoke_test.rb` — Fix assert true at line 151
- `test/helpers/current_helper_test.rb` — Fix structure and misleading test name
- `test/concerns/source_handler_test.rb` — Strengthen assertion at line 71
- `test/controllers/registrations_controller_test.rb` — Replace CSRF regex
- `test/system/user_authentication_test.rb` — Remove sleep 3

### Test Infrastructure
- `test/test_helper.rb` — Main test config
- `test/system_test_helper.rb` — System test base (Capybara/Selenium)

</canonical_refs>

<code_context>
## Existing Code Insights

### Bulk Sweep Files (~25 needing frozen_string_literal)
Controllers (10): application_controller_test, club_locations_controller_test, discipline_phases_controller_test, party_monitors_controller_test, registrations_controller_test, slots_controller_test, table_locals_controller_test, table_monitors_controller_test, uploads_controller_test, users/registrations_controller_test

System (12): admin/user_management_test, admin_access_test, club_locations_test, discipline_phases_test, game_plans_test, party_monitors_test, preferences_test, slots_test, table_locals_test, uploads_test, user_authentication_test, user_profile_test

Other (3): current_helper_test, users_test (integration), auto_reserve_tables_test

### Already Have frozen_string_literal
- test/controllers/game_plans_controller_test.rb
- test/system/docs_page_test.rb
- All characterization, scraping, concern, and filters_helper test files

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

*Phase: 09-controller-system-other-tests-review*
*Context gathered: 2026-04-10*
