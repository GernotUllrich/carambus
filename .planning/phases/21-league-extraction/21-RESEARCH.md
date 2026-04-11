# Phase 21: League Extraction - Research

**Researched:** 2026-04-11
**Domain:** Rails model extraction — service object pattern, PORO vs ApplicationService, delegation wrappers
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Extract all three characterized clusters plus BBV scraping. Target ~1100 line reduction (50%).
- **D-02:** Extraction order: standings (easiest, pure calculation) -> game plan reconstruction (moderate, DB writes) -> ClubCloud scraping (hardest, network I/O + bulk writes) -> BBV scraping (small, similar to ClubCloud).
- **D-03:** BBV scraping is extracted alongside ClubCloud scraping in the same phase, not deferred.
- **D-04:** All extracted services use `League::` namespace under `app/services/league/` directory.
- **D-05:** `League::StandingsCalculator` is a PORO — `initialize(league)` with instance methods. No `.call` convention. Pure calculation, no side effects.
- **D-06:** `League::GamePlanReconstructor` inherits from `ApplicationService` — uses `.call(kwargs)` pattern since it writes to database.
- **D-07:** `League::ClubCloudScraper` inherits from `ApplicationService`.
- **D-08:** `League::BbvScraper` is a separate `ApplicationService`.
- **D-09:** The 821-line `scrape_single_league_from_cc` is extracted into `League::ClubCloudScraper` as a single service class, broken into well-named private methods internally.
- **D-10:** BBV scraping methods go into `League::BbvScraper`, separate from ClubCloudScraper.
- **D-11:** League model keeps thin one-liner wrapper methods that delegate to extracted services.
- **D-12:** Wrapper methods are not marked as deprecated — they are the permanent public API.

### Claude's Discretion

- Internal method decomposition within `League::ClubCloudScraper`
- Test file organization for new service classes
- Whether `League::GamePlanReconstructor` uses a single `.call` entry point or dispatches by operation type
- GamePlan utility methods (find_leagues_with_same_gameplan, find_or_create_shared_gameplan, delete_game_plans_for_season) — include in GamePlanReconstructor or leave in model

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXTR-01 | Extract service classes from League reducing line count significantly | Cluster analysis shows 1100+ extractable lines across 4 service classes |
| EXTR-03 | All existing characterization tests pass after extractions | Tests call public League methods — thin delegation wrappers preserve all call sites |
| EXTR-04 | All existing tests green after extractions (751+ runs, 0 failures) | Baseline confirmed 831 runs, 0 failures; extraction must preserve all public method signatures |
</phase_requirements>

## Summary

Phase 21 extracts four service classes from League (2221 lines) following patterns already established in this codebase (TournamentMonitor, TableMonitor, Tournament extractions). The extraction domain is pure Rails service object refactoring — no new dependencies, no framework changes.

The League model has three cohesive behavioral clusters plus one ancillary scraper that are clearly delimited in the file. Their line ranges and caller maps are now fully documented. The characterization test suite in `test/models/league_test.rb` uses `league.method_name` call syntax throughout — thin delegation wrappers in the League model preserve all call sites without any test changes.

The most important technical risk is the 821-line `scrape_single_league_from_cc` method, which interleaves team parsing, player parsing, party game parsing, and game plan creation in a single deeply-nested method. It must be moved wholesale into `League::ClubCloudScraper` and decomposed into private methods there; the delegation wrapper on the model is a single-line pass-through.

**Primary recommendation:** Follow D-02 extraction order exactly (standings first, game plan second, CC scraper third, BBV scraper fourth) to keep each extraction independently verifiable with the test suite.

## Standard Stack

### Core (already in project — no new gems required)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Rails ActiveRecord | 7.2.0.beta2 | ORM — service classes use model associations | Already in project |
| ApplicationService | (project file) | Base class for services with side effects | Established project pattern |
| Minitest | bundled | Test framework | Project uses Minitest, not RSpec |
| WebMock | bundled | HTTP mocking for scraper tests | Already used in scraping test suite |
| VCR | bundled | Cassette recording for HTTP interactions | Already used in `test/snapshots/vcr/` |

No new gems are required for this phase. [VERIFIED: Gemfile.lock present, app/services/ inspected]

**Installation:** None needed.

## Architecture Patterns

### Recommended Directory Structure

```
app/services/league/                       # NEW — create this directory
├── standings_calculator.rb                # PORO, no ApplicationService
├── game_plan_reconstructor.rb             # < ApplicationService
├── club_cloud_scraper.rb                  # < ApplicationService
└── bbv_scraper.rb                         # < ApplicationService

test/services/league/                      # NEW — create this directory
├── standings_calculator_test.rb
├── game_plan_reconstructor_test.rb
├── club_cloud_scraper_test.rb
└── bbv_scraper_test.rb
```

### Pattern 1: PORO Calculator (League::StandingsCalculator)

Follows `Tournament::RankingCalculator` exactly. [VERIFIED: app/services/tournament/ranking_calculator.rb]

**What:** Plain Ruby object, `initialize(league)`, multiple public instance methods, no `.call`.
**When to use:** Pure calculation with no DB writes or side effects (standings methods read from DB, compute, return data).

```ruby
# Source: app/services/tournament/ranking_calculator.rb pattern
# frozen_string_literal: true

class League::StandingsCalculator
  def initialize(league)
    @league = league
  end

  def karambol
    # body of League#standings_table_karambol
  end

  def snooker
    # body of League#standings_table_snooker
  end

  def pool
    # body of League#standings_table_pool
  end

  def schedule_by_rounds
    # body of League#schedule_by_rounds
  end
end
```

Delegation wrappers in `league.rb` (D-11):

```ruby
def standings_table_karambol
  League::StandingsCalculator.new(self).karambol
end

def standings_table_snooker
  League::StandingsCalculator.new(self).snooker
end

def standings_table_pool
  League::StandingsCalculator.new(self).pool
end

def schedule_by_rounds
  League::StandingsCalculator.new(self).schedule_by_rounds
end
```

### Pattern 2: ApplicationService with Dispatcher (League::GamePlanReconstructor)

Follows `RegionCc::LeagueSyncer` dispatcher pattern. [VERIFIED: app/services/region_cc/league_syncer.rb]

**What:** `initialize(kwargs)`, `call` dispatches to private methods.
**When to use:** Multiple related operations with DB writes, all sharing context (the league).

Candidate entry points (Claude's discretion):
- `operation: :reconstruct` — calls `reconstruct_game_plan_from_existing_data` (currently private, ~238 lines)
- `operation: :reconstruct_for_season` — calls `reconstruct_game_plans_for_season` (class method, ~54 lines)

GamePlan utility methods (`find_leagues_with_same_gameplan`, `find_or_create_shared_gameplan`, `delete_game_plans_for_season`) are short (7-33 lines) and called only internally within the game plan reconstruction flow. These should move into the service as private helpers, removed from the League model. [VERIFIED: grep found zero external callers outside league.rb and test/models/league_test.rb]

`analyze_game_plan_structure` is only called from `reconstruct_game_plan_from_existing_data` — move into the service as a private method.

```ruby
# frozen_string_literal: true

class League::GamePlanReconstructor < ApplicationService
  def initialize(kwargs = {})
    @league = kwargs[:league]
    @season = kwargs[:season]
    @operation = kwargs[:operation] || :reconstruct
    @opts = kwargs.except(:league, :season, :operation)
  end

  def call
    case @operation
    when :reconstruct then reconstruct
    when :reconstruct_for_season then reconstruct_for_season
    when :delete_for_season then delete_for_season
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private
  # ... extracted method bodies
end
```

Delegation in `league.rb`:

```ruby
def reconstruct_game_plan_from_existing_data
  League::GamePlanReconstructor.call(league: self, operation: :reconstruct)
end

def self.reconstruct_game_plans_for_season(season, opts = {})
  League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season, **opts)
end
```

**Important:** The current characterization test calls `@league.send(:reconstruct_game_plan_from_existing_data)` — treating it as a private method. After extraction, the delegation wrapper makes it public on League. The test uses `.send` so it will still work. [VERIFIED: test/models/league_test.rb line 26]

### Pattern 3: ApplicationService — Single-Entry Scraper (League::ClubCloudScraper)

Follows `TournamentMonitor::ResultProcessor` pattern. [VERIFIED: app/services/tournament_monitor/result_processor.rb]

**What:** `initialize(kwargs)`, single `call` entry point, all work in private methods.
**When to use:** One primary operation with many steps (the 821-line `scrape_single_league_from_cc`).

The 821-line method has three identifiable internal phases (D-09 guidance):
1. **Team parsing** (~lines 624-760): Scrapes team table, resolves clubs, creates/updates LeagueTeam records
2. **Party game parsing** (~lines 761-1200): Scrapes game schedule, creates/updates Party and PartyGame records
3. **Game plan creation** (~lines 1200-1393): Analyzes game structure, creates GamePlan record

```ruby
# frozen_string_literal: true

class League::ClubCloudScraper < ApplicationService
  def initialize(kwargs = {})
    @league = kwargs[:league]
    @opts = kwargs.except(:league)
  end

  def call
    scrape_league
  end

  private

  def scrape_league
    # guard + orchestration formerly in scrape_single_league_from_cc
  end

  def parse_teams(league_doc, url)
    # team table scraping block
  end

  def parse_parties(league_doc, url)
    # party/party_game scraping block
  end

  def build_game_plan(disciplines)
    # game plan creation block
  end
end
```

Delegation in `league.rb`:

```ruby
def scrape_single_league_from_cc(opts = {})
  League::ClubCloudScraper.call(league: self, **opts)
end
```

`scrape_leagues_from_cc` and `scrape_leagues_optimized` are class methods that orchestrate multiple league scrapes — they call `scrape_single_league_from_cc` internally. These class methods can remain on the League model (they are coordination logic, not the bulk of lines). [VERIFIED: lines 303-573 inspected; these are ~230 lines total and are callers, not part of the 821-line method]

### Pattern 4: ApplicationService — BBV Scraper (League::BbvScraper)

**What:** Small standalone scraper for BBV-specific HTML structure. ~135 lines.

```ruby
class League::BbvScraper < ApplicationService
  def initialize(kwargs = {})
    @league = kwargs[:league]
    @region = kwargs[:region]
    @opts = kwargs.except(:league, :region)
  end

  def call
    scrape_single_bbv_league
  end

  # Class-level entry point for the `scrape_bbv_leagues` class method pattern
  def self.scrape_all(region:, season:, opts: {})
    # body of League.scrape_bbv_leagues
  end

  private
  # body of scrape_single_bbv_league + scrape_bbv_league_teams
end
```

Delegation in `league.rb`:

```ruby
def scrape_single_bbv_league(region, opts = {})
  League::BbvScraper.call(league: self, region: region, **opts)
end

def self.scrape_bbv_leagues(region, season, opts = {})
  League::BbvScraper.scrape_all(region: region, season: season, opts: opts)
end
```

### Anti-Patterns to Avoid

- **Changing callers:** Views call `@league.standings_table_snooker`, controllers call `@league.scrape_single_league_from_cc`. None of these call sites should change.
- **Removing the delegation wrapper:** Service classes are the implementation; wrapper methods are the permanent API (D-12).
- **Splitting ClubCloudScraper across multiple files:** D-09 is explicit — keep it in one file even if still large.
- **Making `reconstruct_game_plan_from_existing_data` public in tests via different means:** The existing test uses `.send` which works on both private and public methods — no test change needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP mocking in scraper tests | Custom HTTP stub classes | WebMock (already configured) | Already in project, VCR cassettes exist |
| Service base class | Custom `.call` wiring | ApplicationService (5-line base) | Established project pattern |
| Test ID management | Random IDs | `TEST_ID_BASE + offset` pattern (already in league_test.rb) | Prevents LocalProtector collisions, matches existing tests |

**Key insight:** This phase is pure structural movement — no new libraries, no new patterns. The work is identifying method boundaries, moving code, and writing thin delegation wrappers.

## Cluster Size Analysis

[VERIFIED: line counts from league.rb inspection]

| Cluster | Methods | Approx Lines | Target Service |
|---------|---------|--------------|----------------|
| Standings | `standings_table_karambol`, `standings_table_snooker`, `standings_table_pool`, `schedule_by_rounds` | ~226 | `League::StandingsCalculator` |
| GamePlan | `reconstruct_game_plan_from_existing_data`, `analyze_game_plan_structure`, `reconstruct_game_plans_for_season`, `find_leagues_with_same_gameplan`, `find_or_create_shared_gameplan`, `delete_game_plans_for_season` | ~426 | `League::GamePlanReconstructor` |
| CC Scraper | `scrape_single_league_from_cc` (body) | ~821 | `League::ClubCloudScraper` |
| BBV Scraper | `scrape_bbv_leagues`, `scrape_single_bbv_league`, `scrape_bbv_league_teams` | ~135 | `League::BbvScraper` |
| **Total extractable** | | **~1608 lines** | |
| Delegation wrappers (kept) | | ~40 lines | (stay in league.rb) |
| **Net reduction** | | **~1568 lines** | from 2221 to ~653 |

The target of ~1100 line reduction (D-01) is achievable and likely exceeded. The model retains associations, validations, constants, class-level search/scraping coordination, and delegation wrappers.

## Caller Map

[VERIFIED: grep across app/ and test/]

| Method | Called From |
|--------|-------------|
| `league.standings_table_karambol` | `app/views/leagues/show.html.erb:62` |
| `league.standings_table_snooker` | `app/views/leagues/show.html.erb:59` |
| `league.standings_table_pool` | `app/views/leagues/show.html.erb:65` |
| `league.schedule_by_rounds` | `app/views/leagues/show.html.erb:69`, `app/views/leagues/_schedule_table.html.erb:2` |
| `league.scrape_single_league_from_cc` | `app/controllers/leagues_controller.rb:64,73,81`, `app/controllers/versions_controller.rb:96` |
| `League.scrape_leagues_from_cc` | `app/models/region.rb:372` |
| `League.scrape_bbv_leagues` | called internally from `scrape_leagues_from_cc` and `scrape_leagues_optimized` |
| `reconstruct_game_plan_from_existing_data` | Only from `League.reconstruct_game_plans_for_season` internally + tests via `.send` |
| `League.reconstruct_game_plans_for_season` | No external callers found — only test assertions |
| `find_leagues_with_same_gameplan` | No external callers — only within league.rb |
| `find_or_create_shared_gameplan` | No external callers — only within league.rb |
| `delete_game_plans_for_season` | No external callers — only within league.rb |

## Common Pitfalls

### Pitfall 1: Characterization Tests Use `.send` for Private Methods

**What goes wrong:** `reconstruct_game_plan_from_existing_data` is called via `@league.send(:reconstruct_game_plan_from_existing_data)` in the test. If the extraction makes it a delegating public method on League, `.send` still works. But if a future test refactor removes the `.send` and calls it directly, it would only work if the method stays public on League.
**Why it happens:** Method was private before Phase 20 added characterization tests.
**How to avoid:** Keep the delegation wrapper public on League. Do not rename the delegation method. Test the service class directly in new service tests.

### Pitfall 2: The 821-line Method Has Internal Early Returns

**What goes wrong:** `scrape_single_league_from_cc` has 5 early `return` statements at different guard levels. When moving to a service class, each `return` inside a private method only returns from that private method, not from `call`. If the original `return` was meant to abort the whole operation, the private method must signal this (return value, raise, or boolean flag).
**Why it happens:** Extracting a method with guards into sub-methods changes control flow semantics.
**How to avoid:** Map all `return` statements in `scrape_single_league_from_cc` before extraction. The first `return unless opts[:league_details]` is an entry guard — implement as a guard in `call`. Other returns (`return if skip`, `return` at end) are local exits within their own scope.

### Pitfall 3: Instance Variables Crossing Method Boundaries

**What goes wrong:** The 821-line method uses many local variables (`clubs_cache`, `league_teams_cache`, `league_team_players`, `global_context`, `region_id`, etc.) that are shared across the team-parsing and party-parsing sections. When split into private methods, these must become instance variables or be passed as parameters.
**Why it happens:** The method was never designed to be split — it reads as one linear script.
**How to avoid:** Use instance variables (`@clubs_cache`, `@league_teams_cache`) in the service class for cross-method state. Declare them explicitly in `call` before delegating to private methods.

### Pitfall 4: `scrape_bbv_leagues` Has `records_to_tag` Return Value

**What goes wrong:** `scrape_bbv_leagues` returns `records_to_tag` (an array of records for region tagging). When extracted, the return value must be preserved. `scrape_leagues_from_cc` (which calls it) uses the return value.
**Why it happens:** The tag-and-return pattern is part of the broader scraping contract.
**How to avoid:** `League::BbvScraper.scrape_all` must return the `records_to_tag` array. The delegation wrapper `League.scrape_bbv_leagues` must pass through the return value.

### Pitfall 5: `scrape_single_league_from_cc` Returns `nil` Implicitly

**What goes wrong:** The CC scraper method does not explicitly return a meaningful value — it returns `nil` (bare `return` at line 1390). The caller `scrape_leagues_from_cc` does not use its return value. However `scrape_single_bbv_league` does call `scrape_single_league_from_cc` and uses its return for `records_to_tag`.
**Why it happens:** The return contract is not documented.
**How to avoid:** The service `call` method returns `nil` by default. The delegation wrapper can return whatever `call` returns. Check the exact return usage in `scrape_single_bbv_league` and `scrape_leagues_from_cc` before finalizing.

### Pitfall 6: Test ID Collisions With Existing League Tests

**What goes wrong:** New service tests that create League/Party/LeagueTeam fixtures with hardcoded IDs may collide with existing fixtures or other test files.
**Why it happens:** The project uses ID ranges to avoid LocalProtector issues (IDs < 50_000_000 are "global").
**How to avoid:** Follow the `TEST_ID_BASE + ID_OFFSET` pattern from `league_test.rb`. Choose a new `ID_OFFSET` range for each new test file (e.g., 70_000 for standings, 80_000 for game plan, etc.). Verify no collision with other files.

## Code Examples

### Correct PORO Test Pattern (from existing ranking_calculator_test.rb)

```ruby
# Source: test/services/tournament/ranking_calculator_test.rb
# frozen_string_literal: true
require "test_helper"

class League::StandingsCalculatorTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 70_000   # unique offset for this test file

  @@counter = 0

  def next_id
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  test "karambol returns sorted rows with platz key" do
    base = next_id
    league = League.create!(
      id: base,
      name: "Test Karambol #{base}",
      shortname: "TK#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band)
    )
    # ... setup teams + parties with result data ...

    result = League::StandingsCalculator.new(league).karambol
    assert result.is_a?(Array)
    assert result.all? { |row| row.key?(:platz) }
  end
end
```

### Correct ApplicationService Test Pattern (from result_recorder_test.rb)

```ruby
# Source: test/services/table_monitor/result_recorder_test.rb (structure)
# frozen_string_literal: true
require "test_helper"

class League::GamePlanReconstructorTest < ActiveSupport::TestCase
  # Use unique ID range
  ID_BASE = 50_080_000

  setup do
    @league = League.create!(
      id: ID_BASE + 1,
      name: "GPR Test League",
      shortname: "GPRTEST",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band)
    )
  end

  test "reconstruct returns nil when league has no parties" do
    result = League::GamePlanReconstructor.call(league: @league, operation: :reconstruct)
    assert_nil result
  end

  test "reconstruct_for_season returns result hash" do
    season = seasons(:current)
    result = League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season)
    assert result.key?(:success)
  end
end
```

### Thin Delegation Wrapper Template

```ruby
# In league.rb — all delegations are one-liners
def standings_table_karambol
  League::StandingsCalculator.new(self).karambol
end

def scrape_single_league_from_cc(opts = {})
  League::ClubCloudScraper.call(league: self, **opts)
end

def self.scrape_bbv_leagues(region, season, opts = {})
  League::BbvScraper.scrape_all(region: region, season: season, opts: opts)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| All logic in model | Service objects for cohesive clusters | v2.1 (TournamentMonitor, TableMonitor) | Already established — phase 21 applies same pattern to League |
| Methods directly in League | Thin wrappers delegating to services | Phase 21 | Callers unchanged, model shrinks significantly |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `scrape_leagues_from_cc` is a coordination method that should remain on League (not extracted) | Architecture Patterns — CC Scraper | If extracted, callers in region.rb would need updating |
| A2 | `schedule_by_rounds` belongs in StandingsCalculator despite being schedule-not-standings | Architecture Patterns — PORO | If wrong, it stays in League model or gets its own service (low impact) |

**If this table is empty:** All other claims were verified against actual source files in this session.

## Open Questions

1. **GamePlanReconstructor: single `.call` or multiple entry points?**
   - What we know: `reconstruct_game_plan_from_existing_data` (instance) and `reconstruct_game_plans_for_season` (class-level) are different signatures
   - What's unclear: Whether the dispatcher pattern (with `operation:`) is cleaner than two separate class-level entry points
   - Recommendation: Dispatcher pattern (like RegionCc::LeagueSyncer) handles both cleanly; `call(league: l, operation: :reconstruct)` vs `call(season: s, operation: :reconstruct_for_season)`

2. **`records_to_tag` return value from BBV scraping**
   - What we know: `scrape_bbv_leagues` returns an array, `scrape_single_bbv_league` returns `[league_url, records_to_tag]`
   - What's unclear: Whether these return values are used at the call site in `scrape_leagues_from_cc`
   - Recommendation: Verify by reading `scrape_leagues_from_cc` fully before extracting BBV; preserve whatever return value exists

## Environment Availability

Step 2.6: SKIPPED — this phase is code-only refactoring. No new external dependencies, no new CLI tools required. The test suite (Minitest) and linter (StandardRB) are already available.

```
bin/rails test                    # already available [VERIFIED: 831 runs, 0 failures]
bundle exec standardrb            # already available
```

## Sources

### Primary (HIGH confidence)
- `app/models/league.rb` — 2221 lines, read directly; method locations and line counts verified
- `app/services/tournament/ranking_calculator.rb` — PORO pattern verified
- `app/services/tournament_monitor/result_processor.rb` — ApplicationService pattern verified
- `app/services/table_monitor/result_recorder.rb` — ApplicationService with multiple entry points verified
- `app/services/region_cc/league_syncer.rb` — Dispatcher ApplicationService pattern verified
- `app/services/application_service.rb` — 5-line base class verified
- `test/models/league_test.rb` — All characterization tests read; call sites verified
- `test/services/table_monitor/result_recorder_test.rb` — Test structure pattern verified
- `test/services/tournament/ranking_calculator_test.rb` — PORO test pattern verified

### Secondary (MEDIUM confidence)
- Caller grep results for all League public methods — verified with ripgrep across full app/ directory

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all patterns already in codebase
- Architecture: HIGH — patterns read from real service files in this project
- Pitfalls: HIGH — identified from direct code inspection of the 821-line method and test files
- Caller map: HIGH — verified with grep across app/ and test/

**Research date:** 2026-04-11
**Valid until:** Stable (internal codebase analysis — does not expire)
