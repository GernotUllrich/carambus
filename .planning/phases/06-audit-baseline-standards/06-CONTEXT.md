# Phase 6: Audit Baseline & Standards - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning

<domain>
## Phase Boundary

Survey all 72 existing test files and document quality issues. Establish consistent patterns (fixtures, assertions, naming, helpers) that Phases 7-9 will apply during file-by-file review. No test files are modified in this phase — output is a standards document and per-file audit report.

</domain>

<decisions>
## Implementation Decisions

### Audit Approach
- **D-01:** Run automated scan first — grep/analysis scripts to categorize issues (skips, empty tests, assertion counts per test, naming style, setup patterns, unused helpers) before any manual review
- **D-02:** Comprehensive scan scope — check for skipped/pending tests, assertion count per test method, empty tests, naming style consistency, setup pattern usage, unused helpers, and test-to-code mapping
- **D-03:** Manual review only for files flagged by the automated scan as problematic

### Fixtures vs Factories Standard
- **D-04:** Fixtures are the primary standard — already dominant (`fixtures :all`), fast, well-understood. FactoryBot stays in Gemfile but is not the default approach.
- **D-05:** Use `Model.create!` for one-off complex setups where fixtures are insufficient. No new factory definitions needed.

### Assertion & Naming Style
- **D-06:** Standard test naming is `test "description" do` blocks (Rails default), not `def test_method_name`
- **D-07:** Keep shoulda-matchers available — useful for concise validation/association tests, but not mandated
- **D-08:** Standard MiniTest assertions (`assert_equal`, `assert_nil`, `assert_includes`, etc.) are the baseline assertion style

### Audit Output Format
- **D-09:** Per-file issue list in Markdown — each test file listed with categorized issues (naming, assertions, skips, structure). This becomes the work queue for Phases 7-9.

### Claude's Discretion
- Exact automated scan scripts and implementation approach
- How to categorize issue severity (critical vs minor)
- Whether to include summary statistics alongside per-file detail
- How to handle edge cases (e.g., characterization tests that intentionally use different patterns)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Testing Infrastructure
- `test/test_helper.rb` — Main test configuration, fixture loading, LocalProtector override, FactoryBot setup
- `test/system_test_helper.rb` — System test base configuration (Capybara/Selenium)
- `test/support/vcr_setup.rb` — VCR configuration for HTTP recording/playback
- `test/support/scraping_helpers.rb` — Scraping test utilities and custom assertions
- `test/support/snapshot_helpers.rb` — VCR snapshot helpers
- `test/support/ko_tournament_test_helper.rb` — Complex tournament test setup/teardown

### Codebase Maps
- `.planning/codebase/TESTING.md` — Comprehensive testing patterns analysis (test types, mocking, coverage)
- `.planning/codebase/CONVENTIONS.md` — Project coding conventions

### Standards (to be created in this phase)
- Audit report output will be written to `.planning/phases/06-audit-baseline-standards/AUDIT-REPORT.md`

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/support/` directory has 4 helper modules already — review these for redundancy/gaps
- `.simplecov` configuration exists — can inform test-to-code mapping analysis
- `Gemfile` includes shoulda-matchers, webmock, vcr, factory_bot_rails — all test infrastructure in place

### Established Patterns
- Fixtures primary: `fixtures :all` loads all YAML fixtures in every test
- WebMock disables all external HTTP by default
- VCR cassettes in `test/snapshots/vcr/` for scraping tests
- KO tournament tests have dedicated helper with setup/teardown pattern
- Characterization tests (from v1.0) follow a specific pattern with `LocalProtector` override

### Integration Points
- 8 files already identified with skipped/pending tests — priority targets for the scan
- 3 large test files (824L, 703L, 586L) need structural assessment
- test_helper.rb is the central configuration point — any standard changes would be documented there

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches for the automated scan and report generation.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 06-audit-baseline-standards*
*Context gathered: 2026-04-10*
