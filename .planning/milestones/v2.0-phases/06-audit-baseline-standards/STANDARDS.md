# Test Suite Standards

**Version:** 1.0
**Created:** 2026-04-10
**Phase:** 06-audit-baseline-standards
**Applies to:** All 72 test files in the Carambus API test suite

This document codifies the test suite conventions for the v2.0 Test Suite Audit. Phases 7-9
executors use this as their primary reference when reviewing each test file. Where a test
file deviates from these standards, it is flagged using the issue category codes defined in
the Issue Categories section below.

---

## Setup Patterns

**Standard (per D-04, D-05):** Fixtures are the primary setup mechanism. `fixtures :all` is
loaded globally in `test/test_helper.rb` and applies to every `ActiveSupport::TestCase`
subclass. All standard test data (players, tournaments, users, seasons, regions, disciplines)
should come from fixture files in `test/fixtures/`.

**Fixture access pattern:**

```ruby
setup do
  @player = players(:one)
  @tournament = tournaments(:imported)
  @season = seasons(:current)
end
```

**When `Model.create!` is acceptable (D-05):**

`Model.create!` with explicit attributes is acceptable when fixtures cannot represent the
required complexity — for example, KO tournament brackets that need specific ID sequences,
records that must traverse an AASM state machine, or multi-record setups with computed
relationships. Use inline attributes, not factory definitions.

```ruby
# Acceptable: complex setup not expressible in static fixtures
setup do
  @tournament = Tournament.create!(
    title: "Test KO",
    season: seasons(:current),
    organizer: regions(:nbv),
    organizer_type: "Region",
    discipline: disciplines(:carom_3band),
    state: "initialized",
    date: 2.weeks.from_now
  )
end
```

**FactoryBot policy (D-04):**

FactoryBot is present in the Gemfile and `include FactoryBot::Syntax::Methods` is available
globally. However, no factory files exist (`test/factories/` does not exist; no
`FactoryBot.define` calls found in the test suite). Existing usage via the test helpers
(e.g., `KoTournamentTestHelper#create_ko_tournament_with_seedings`) uses `Model.create!`
directly, not factory definitions. New tests must not introduce FactoryBot factory
definitions.

**Decision table:**

| Situation | Use |
|-----------|-----|
| Standard test data (players, tournaments, users, seasons, regions) | Fixtures |
| Complex multi-record setup (KO brackets, state-dependent sequences) | `Model.create!` with explicit attributes |
| Existing FactoryBot usage | Tolerate (none currently exists) — do not expand |
| New factory definitions | Not permitted |

**Non-compliant patterns:**

```ruby
# Non-compliant: factory definition (none exist, don't create any)
build(:player)
create(:tournament, state: "started")

# Non-compliant: creating records that match existing fixtures
setup do
  @player = Player.create!(firstname: "Hans", lastname: "Meyer")  # use players(:one)
end
```

---

## Assertion Style

**Standard (per D-07, D-08):** MiniTest assertions are the baseline assertion style.
Use the most specific assertion available. shoulda-matchers are encouraged for concise
validation and association tests but are not mandated.

**Preferred MiniTest assertions:**

```ruby
assert_equal expected, actual          # Exact value match (most common)
assert_nil record.deleted_at           # Expects nil
assert_not_nil result                  # Expects non-nil (prefer assert_equal when value known)
assert_includes collection, item       # Collection membership
assert_difference "Model.count", 1 do  # Numeric change over block
  Model.create!(...)
end
assert_raises(ActiveRecord::RecordInvalid) { model.save! }
refute condition                       # Negative assertion
refute_nil value                       # Value is present
refute_equal unexpected, actual        # Values differ
assert_predicate record, :valid?       # Predicate method
assert respond_to?(method)             # Method presence
```

**shoulda-matchers (encouraged for model tests):**

```ruby
# Concise validation and association assertions
should validate_presence_of(:title)
should belong_to(:season)
should have_many(:games)
should validate_uniqueness_of(:cc_id).scoped_to(:region_id)
```

**Weak assertion checklist (issues to flag in audit):**

| Pattern | Problem | Flag |
|---------|---------|------|
| `assert true` | Always passes, tests nothing | E02 |
| `assert_not_nil x` alone | Does not verify the value | E02 |
| `assert x.valid?` without inspecting errors | Passes on any validation error path | E02 |
| Empty test body | Zero assertions — dead test | E01 |
| `assert_nothing_raised` as the only assertion | Acceptable in scraping smoke tests only; flag elsewhere | E02 |
| `assert result.nil? \|\| result.is_a?(SomeClass)` | Disjunction allows nil to pass silently | E02 |

**Compliant examples:**

```ruby
# Good: specific value check
assert_equal "Hans Meyer", player.full_name

# Good: difference assertion
assert_difference "Game.count", 3 do
  tournament.initialize_games
end

# Good: error message inspection
record.valid?
assert_includes record.errors[:email], "can't be blank"

# Good: shoulda-matcher
should validate_presence_of(:title)
```

**Non-compliant examples:**

```ruby
# Non-compliant: tests nothing
test "player exists" do
  assert true
end

# Non-compliant: value should be checked specifically
test "returns a result" do
  result = service.call
  assert_not_nil result
end

# Non-compliant: empty test
test "something works" do
end
```

---

## Test Naming

**Standard (per D-06):** Test method blocks using `test "description" do` syntax (Rails
default). This is the project-wide standard.

**Compliant naming:**

```ruby
test "creates a game when started" do
  ...
end

test "returns nil when tournament has no players" do
  ...
end

test "raises RecordInvalid when title is blank" do
  ...
end
```

**Naming guidelines:**

- Describe behavior, not implementation: "creates a game when started" not "test_start_creates_game"
- Use present tense: "returns nil" not "returned nil"
- Include the condition: "raises error when title is blank" not just "invalid without title"
- Be specific enough that failure message identifies the problem without reading the test body

**Non-compliant pattern (W01):**

```ruby
# Non-compliant: def test_ style
def test_create_player
  ...
end

def test_search_returns_results
  ...
end
```

Existing `def test_` methods are flagged (W01) but are not blocking issues. They should be
converted during the audit phase review.

---

## Helper & Support Files

**Standard (per CONS-04):** All support files live in `test/support/`. They are auto-loaded
by `test_helper.rb` via `Dir[Rails.root.join('test', 'support', '**', '*.rb')]`. Helpers
should be included only where needed. The two exceptions — `ScrapingHelpers` and
`SnapshotHelpers` — are included globally in `ActiveSupport::TestCase` (see note below).

---

### `test/support/scraping_helpers.rb`

**Module:** `ScrapingHelpers`
**Included:** Globally via `include ScrapingHelpers` in `ActiveSupport::TestCase` (test_helper.rb:78)
**Purpose:** Utilities for scraping tests — HTTP stubbing, fixture loading, sync date assertions, and factory method for scrapable tournaments.

**Public methods:**

| Method | Signature | Purpose |
|--------|-----------|---------|
| `snapshot_name` | `snapshot_name(prefix, *args)` | Generates VCR cassette names |
| `mock_clubcloud_html` | `mock_clubcloud_html(url, html_content)` | Stubs GET request returning HTML |
| `read_html_fixture` | `read_html_fixture(filename)` | Reads file from `test/fixtures/html/` |
| `assert_sync_date_updated` | `assert_sync_date_updated(record, since:, tolerance: 5.seconds)` | Time-range assertion on sync_date |
| `assert_sync_date_unchanged` | `assert_sync_date_unchanged(record, original_sync_date)` | Verifies sync_date not modified |
| `create_scrapable_tournament` | `create_scrapable_tournament(attrs = {})` | Creates Tournament via Model.create! |
| `assert_tournament_scraped` | `assert_tournament_scraped(tournament)` | Checks title/date/sync_date present |
| `assert_scraping_detected_changes` | `assert_scraping_detected_changes(record, *attrs)` | Checks `previous_changes` keys |
| `stub_clubcloud_auth` | `stub_clubcloud_auth(region_cc)` | Stubs POST login endpoint |

**Active usage:** Methods called outside of support files:
- `create_scrapable_tournament` — `test/scraping/scraping_smoke_test.rb`, `test/scraping/tournament_scraper_test.rb`
- `mock_clubcloud_html`, `read_html_fixture`, `assert_sync_date_updated`, `stub_clubcloud_auth` — scraping test files

**Global inclusion note:** `ScrapingHelpers` is included in ALL test classes (not just scraping tests). Methods like `snapshot_name`, `assert_tournament_scraped`, `assert_scraping_detected_changes`, and `assert_sync_date_unchanged` appear unused outside of scraping tests. Flag as I01 if confirmed unused. Recommend narrowing inclusion scope in a future refactor.

---

### `test/support/snapshot_helpers.rb`

**Module:** `SnapshotHelpers`
**Included:** Globally via `include SnapshotHelpers` in `ActiveSupport::TestCase` (test_helper.rb:79)
**Purpose:** Helpers for data snapshot comparison — save/load YAML snapshots for regression comparison and HTML structure comparison via VCR.

**Public methods:**

| Method | Signature | Purpose |
|--------|-----------|---------|
| `save_snapshot` | `save_snapshot(name, data)` | Writes YAML snapshot to `test/snapshots/data/` |
| `load_snapshot` | `load_snapshot(name)` | Reads YAML snapshot file |
| `assert_matches_snapshot` | `assert_matches_snapshot(name, data)` | Compares data against saved snapshot; skips on first run |
| `update_snapshot` | `update_snapshot(name, data)` | Overwrites existing snapshot |
| `snapshot_attributes` | `snapshot_attributes(record, *attrs)` | Extracts attribute hash from AR record |
| `assert_html_structure_unchanged` | `assert_html_structure_unchanged(cassette_name)` | Structure-only HTML comparison via VCR |

**Active usage:** No calls to `SnapshotHelpers` methods were found outside the module's own file. The module is defined and globally included but appears unused in any test file. Flag all methods as I01 (unused helper). The module may be intended for future scraping regression tests.

---

### `test/support/vcr_setup.rb`

**Module:** None (top-level VCR configuration block)
**Included:** Auto-loaded at startup via `Dir[...]` glob in test_helper.rb
**Purpose:** Configures the VCR gem for HTTP recording and playback in scraping tests.

**Configuration details:**

| Setting | Value | Purpose |
|---------|-------|---------|
| `cassette_library_dir` | `test/snapshots/vcr` | Storage location for cassette files |
| `hook_into` | `:webmock` | Uses WebMock for HTTP interception |
| `ignore_localhost` | `true` | Local connections bypass VCR |
| `record` | `:once` | Record on first run, replay thereafter |
| `match_requests_on` | `[:method, :uri]` | Match by HTTP method + URI |
| `allow_playback_repeats` | `true` | Same cassette entry can be replayed multiple times |
| Sensitive data filtering | `<CC_USERNAME>`, `<CC_PASSWORD>` | Strips credentials from recorded cassettes |
| JSON pretty-print | Enabled | Formats JSON cassettes for readable diffs |

**Active usage:** VCR is used in 3 service test files (`tournament_syncer_test.rb`, `registration_syncer_test.rb`, `competition_syncer_test.rb`), 1 characterization test (`region_cc_char_test.rb`), and referenced in documentation. Configuration is shared and correctly scoped — no redundancy.

---

### `test/support/ko_tournament_test_helper.rb`

**Module:** `KoTournamentTestHelper`
**Included:** Explicitly via `include KoTournamentTestHelper` in test files that need it (not global)
**Purpose:** Complex KO tournament test setup and teardown — creates complete bracket structures with players, seedings, and games.

**Public methods:**

| Method | Signature | Purpose |
|--------|-----------|---------|
| `create_ko_tournament_with_seedings` | `create_ko_tournament_with_seedings(player_count, tournament_attrs = {})` | Creates Tournament + Players + Seedings; returns hash |
| `cleanup_ko_tournament` | `cleanup_ko_tournament(data)` | Destroys tournament, seedings, games, and players |
| `finish_game` | `finish_game(game, winner_role = "playera")` | Updates game with result data to simulate completion |
| `assert_valid_ko_bracket` | `assert_valid_ko_bracket(tournament)` | Checks game count matches `executor_params["GK"]` |
| `assert_first_round_has_players` | `assert_first_round_has_players(tournament)` | Verifies first-round games have 2 players each |
| `assert_player_reference_resolves` | `assert_player_reference_resolves(tm, reference, expected_id)` | Checks `ko_ranking` reference resolution |

**Active usage:** Included in 2 test files:
- `test/models/tournament_monitor_ko_test.rb`
- `test/models/tournament_ko_integration_test.rb`

**Correctly scoped:** `KoTournamentTestHelper` is the only support module with targeted inclusion. This is the model pattern for complex helpers.

---

### Global inclusion assessment

`ScrapingHelpers` and `SnapshotHelpers` are included in every `ActiveSupport::TestCase`. This is a smell — most test files do not scrape anything. The practical consequence is namespace pollution (methods available where they are irrelevant) and potentially slower test startup. Flagged as I01 for audit. Resolution is out of scope for Phase 6 but should be noted in the per-file audit for model/controller tests that never call these methods.

---

## File Structure

**Standard test file template:**

```ruby
# frozen_string_literal: true

require "test_helper"

class ModelNameTest < ActiveSupport::TestCase
  setup do
    @record = model_names(:fixture_key)
  end

  test "describes expected behavior" do
    # arrange (if needed beyond setup)
    # act
    result = @record.some_method
    # assert
    assert_equal expected_value, result
  end
end
```

**Base class by test type:**

| Test type | Base class | Location |
|-----------|------------|----------|
| Model/unit | `ActiveSupport::TestCase` | `test/models/` |
| Controller/API | `ActionDispatch::IntegrationTest` | `test/controllers/` |
| Integration workflow | `ActionDispatch::IntegrationTest` | `test/integration/` |
| System (browser) | `ApplicationSystemTestCase` | `test/system/` |
| Scraping | `ActiveSupport::TestCase` | `test/scraping/` |
| Concern | `ActiveSupport::TestCase` | `test/concerns/` |
| Task | `ActiveSupport::TestCase` | `test/tasks/` |
| Characterization | `ActiveSupport::TestCase` | `test/characterization/` |

**Required file elements (in order):**

1. `# frozen_string_literal: true` — top of every file
2. `require "test_helper"` — second line
3. Class declaration with appropriate parent class
4. `setup` block for shared state (when needed)
5. Test methods using `test "description" do` style
6. `teardown` block only when non-transactional cleanup is needed

**Characterization test exception:**

Characterization tests (in `test/characterization/`) were written during the v1.0 model
refactoring to pin existing behavior. They may use `def test_` naming, broader
`assert_nothing_raised` assertions, or setup patterns that differ from these standards.
Deviations in characterization tests are noted but not flagged as violations — they document
existing behavior rather than test new behavior.

**System test exception:**

System tests (`test/system/`) may include JavaScript wait patterns, Capybara DSL
(`visit`, `fill_in`, `click_button`, `assert_text`), and `login_as` helpers that do not
appear in unit tests. These are not violations.

---

## Issue Categories

These codes are used by AUDIT-REPORT.md (Plan 02) to tag per-file issues consistently.

| Category | Code | Severity | Description | Example |
|----------|------|----------|-------------|---------|
| Empty test | E01 | Error | Test method with zero assertions | `test "something" do; end` |
| Weak assertion | E02 | Error | Assertion that cannot fail meaningfully | `assert true`, `assert_not_nil` alone |
| Skipped/pending | E03 | Error | Test marked skip or pending without valid justification | `skip "not implemented"` |
| Missing assertion | E04 | Error | Test has code but no `assert`/`refute` call | Method runs code but never asserts |
| Naming violation | W01 | Warning | Uses `def test_` instead of `test "desc" do` | `def test_create_player` |
| Setup pattern | W02 | Warning | Uses FactoryBot factory where fixture would suffice | `create(:player)` |
| Unused helper | I01 | Info | Helper method defined but never called | Methods in `SnapshotHelpers` |
| Global include smell | I02 | Info | Helper included globally but only relevant to a subset of tests | `ScrapingHelpers` in model tests |

**Severity definitions:**

- **Error (E)** — Must be addressed. The test either provides no coverage, can never fail, or creates false confidence in the suite.
- **Warning (W)** — Should be addressed. The deviation reduces consistency or creates maintenance burden, but the test is not wrong.
- **Info (I)** — Noted for reference. Low impact; resolve opportunistically.

**Skipped test disposition (E03):**

A `skip` is acceptable only when:
1. The test documents a known intermittent failure with a linked issue, or
2. The test requires infrastructure not available in CI (e.g., live external service) and a VCR cassette would not be appropriate.

All other skips are E03 and must be resolved (either fix the test or delete it with a commit message explaining why).

**Decision references:**

| Standard | Decision | Source |
|----------|----------|--------|
| Fixtures primary | D-04 | 06-CONTEXT.md |
| Model.create! for complex setups | D-05 | 06-CONTEXT.md |
| test "description" naming | D-06 | 06-CONTEXT.md |
| shoulda-matchers available | D-07 | 06-CONTEXT.md |
| MiniTest assertions baseline | D-08 | 06-CONTEXT.md |
