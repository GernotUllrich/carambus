# Deferred Items — Phase 41

Out-of-scope discoveries logged during execution, per the executor's scope-boundary rule
(only auto-fix issues directly caused by the current task's changes).

## D-41-02-01 — `test/scraping/change_detection_test.rb` id collision with fixtures

**Found during:** Plan 41-02, Task 3 verification (`bin/rails test:critical`).

**Issue:** `test/scraping/change_detection_test.rb` (3 tests: "sync_date is set when
source_url is present", "sync_date updates when record changes with source_url",
"sync_date does not update when no changes") hardcodes `Tournament.create!(id: 50_000_200
| 50_000_201 | 50_000_202, ...)`. `test/fixtures/tournaments.yml` already defines fixture
rows at exactly those three ids (lines 107, 123, 140). Since `fixtures :all` reloads fixture
tables at the start of every `bin/rails test` process, these three tests deterministically
fail with `ActiveRecord::RecordNotUnique: PG::UniqueViolation ... tournaments_pkey` whenever
run — independent of any Phase 41 change.

**Verified pre-existing:** Reproduced against commit `d7dc0b35` (pre-Phase-41 base, before
41-01 and 41-02 were branched) with the identical failure.

**Not fixed:** Unrelated file, unrelated test suite (scraping vs. version-sync-tagging),
requires either renumbering the test's hardcoded ids or the fixture ids — a decision outside
this phase's scope. `bin/rails test:critical`'s scraping half will show 5 errors from this
file until addressed; `bin/rails test:critical`'s concerns half is unaffected.

**Recommendation:** future quick-task — pick fresh non-colliding ids (e.g. base-offset
`52_000_2xx` per the project's established convention, see
`test/tasks/auto_reserve_tables_test.rb`) for the 3 `Tournament.create!` calls in
`change_detection_test.rb`.
