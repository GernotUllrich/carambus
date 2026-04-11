# Phase 20: Characterization - Research

**Researched:** 2026-04-11
**Domain:** Minitest characterization tests for League, PartyMonitor, Party, LeagueTeam — behavior pinning before extraction
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** League has NO AASM state machine. CHAR-01 (originally "AASM transitions") should be reinterpreted as "League core behavior pinned by tests" — associations, configuration, computed properties.

**D-02:** Three behavior clusters need characterization:
1. **Standings tables** (~170 LOC): `standings_table_karambol`, `standings_table_snooker`, `standings_table_pool` — verify correct ranking output for known input
2. **Game plan reconstruction** (~240 LOC): `reconstruct_game_plan_from_existing_data`, `analyze_game_plan_structure`, `reconstruct_game_plans_for_season` — 3 existing tests exist, expand coverage
3. **Scraping pipeline** (~400 LOC): `scrape_leagues_from_cc`, `scrape_league_optimized`, `scrape_league_teams_optimized`, `scrape_party_games_optimized` — VCR cassettes needed (follows v1.0 RegionCc pattern)

**D-03:** Full characterization of all 8 AASM states: `seeding_mode` → `table_definition_mode` → `next_round_seeding_mode` → `ready_for_next_round` → `playing_round` → `round_result_checking_mode` → `party_result_checking_mode` → `closed`

**D-04:** Critical paths to pin for PartyMonitor:
1. `do_placement` — complex game-to-table assignment with TableMonitor interaction
2. `report_result` — pessimistic lock preventing race conditions during result write + state transition
3. `initialize_table_monitors` — table monitor setup
4. Round management — `current_round`, `incr/decr_current_round`, `next_seqno`
5. Result pipeline — `finalize_game_result`, `finalize_round`, `accumulate_results`, `update_game_participations`

**D-05:** PartyMonitor includes `ApiProtector` (forbids API access) — tests need `ApiProtectorTestOverride` (already in test_helper.rb from v2.0)

**D-06:** Party has no AASM. Pin: associations (polymorphic games, league_team_a/b, seedings), computed properties (`name`, `party_nr`, `intermediate_result`), and boolean flags (`manual_assignment`, `continuous_placements`, `allow_follow_up`)

**D-07:** LeagueTeam is 63 lines. Pin: associations (league, club, parties_a/b for home/guest), seedings linkage, `cc_id_link`

### Claude's Discretion

- Test file organization (one file per model vs by behavior cluster)
- VCR cassette strategy for League scraping tests
- Fixture design for PartyMonitor AASM tests (production fixture plans vs programmatic)
- How many test methods per behavior cluster
- Whether to include Reek baseline measurement (follows v1.0 pattern)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAR-01 | League core behavior pinned by tests (reinterpreted from "AASM") | standings_table_karambol/snooker/pool are pure computation on party data — testable with in-memory fixtures. No AASM exists. |
| CHAR-02 | League sync operations (schedule, standings, team management) pinned | scrape_* methods use Net::HTTP — must stub with WebMock HTML fixtures per v1.0 pattern. `schedule_by_rounds` and `reconstruct_game_plan_from_existing_data` are pure DB methods. |
| CHAR-03 | PartyMonitor AASM state machine and game sequencing pinned | 9 AASM states (including `party_result_reporting_mode`), 8 events, all transitions are documented. ApiProtectorTestOverride already installed globally. |
| CHAR-04 | PartyMonitor player-to-game assignment and table placement pinned | `do_placement` uses `data["table_ids"]`, `data["placements"]`, TableMonitor.find — needs table + table_monitor fixtures. `report_result` uses `game.with_lock`. |
| CHAR-05 | Party critical paths pinned | party.name, party.party_nr, party.intermediate_result (returns [0,0] — stubbed), boolean flags, and associations testable via in-memory records. |
| CHAR-06 | LeagueTeam critical paths pinned | 63-line model — associations, cc_id_link (requires league.organizer.public_cc_url_base), seedings. Straightforward. |
</phase_requirements>

---

## Summary

Phase 20 writes characterization tests for four models before any extraction work begins. The models have fundamentally different shapes: League (2219 lines, no state machine, three behavior clusters), PartyMonitor (605 lines, 9 AASM states, pessimistic locking), Party (216 lines, stubbed methods, computed properties), and LeagueTeam (63 lines, associations only).

The v2.1 milestone (TournamentMonitor and Tournament characterization) is the canonical reference pattern. Tests live in `test/models/` (model behavior) and can optionally go in `test/characterization/` for scraping tests (VCR-backed). The key infrastructure — `ApiProtectorTestOverride`, `LocalProtectorTestOverride`, `VCR.configure`, and `ScrapingHelpers` — is already installed and tested in production.

The dominant risk is PartyMonitor's `do_placement` and `report_result`, which have deep external dependencies (Table, TableMonitor, Game, GameParticipation). The correct approach, confirmed by the v2.1 pattern, is to use programmatically-created local records (id >= 50_000_000) with DB persistence rather than pure mocking, to get realistic behavior coverage.

**Primary recommendation:** Write tests in this order: LeagueTeam (trivial, zero risk), Party (in-memory, no HTTP), League standings + game plan (in-memory), PartyMonitor AASM (DB, no Table needed), PartyMonitor do_placement + report_result (DB with TableMonitor fixtures), League scraping (WebMock HTML stubs).

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase |
|-----------|----------------|
| Minitest only (not RSpec) | All tests use `ActiveSupport::TestCase`, `assert_*`, `assert_raises`, `assert_nothing_raised` |
| `frozen_string_literal: true` | Required at top of every new test file |
| Fixtures + FactoryBot | Use existing fixtures as base; create local records (id >= 50_000_000) programmatically for test isolation |
| WebMock disables external HTTP | Scraping tests must stub HTTP with `stub_request` or VCR cassettes; no live network allowed |
| VCR cassettes in `test/snapshots/vcr/` | League scraping tests follow `region_cc_char_test.rb` VCR pattern exactly |
| `SAFETY_ASSURED=true bin/rails db:test:prepare` | If schema changes needed during test runs |
| Conventional commit messages | `test(char): ...` prefix for characterization commits |
| German comments for business logic | Inline comments explaining ranking formulas etc. in German |

---

## Standard Stack

### Core (already installed — no new dependencies)

| Component | Version | Purpose | Notes |
|-----------|---------|---------|-------|
| Minitest | Rails built-in | Test framework | `ActiveSupport::TestCase` |
| FactoryBot Rails | installed | Test data factories | Use alongside fixtures |
| WebMock | installed | HTTP stubbing | `stub_request(:get, url)` |
| VCR | installed | Record/replay HTTP | cassettes in `test/snapshots/vcr/` |
| AASM | 5.5.2 | State machine (PartyMonitor) | `AASM::InvalidTransition` for invalid events |

[VERIFIED: codebase grep — all these are in Gemfile.lock and test_helper.rb]

### Test Infrastructure (already operational)

| Component | Path | Purpose |
|-----------|------|---------|
| `ApiProtectorTestOverride` | `test/test_helper.rb:52-66` | Patches all `ApiProtector`-including classes globally |
| `LocalProtectorTestOverride` | `test/test_helper.rb:38-45` | Allows saving any id in tests |
| `VCR.configure` | `test/support/vcr_setup.rb` | Cassette dir, WebMock hook, filter secrets |
| `ScrapingHelpers` | `test/support/scraping_helpers.rb` | `mock_clubcloud_html`, `read_html_fixture` |
| `SnapshotHelpers` | `test/support/snapshot_helpers.rb` | `with_vcr_cassette` pattern |
| HTML fixtures | `test/fixtures/html/` | Static HTML for scraping tests |

[VERIFIED: file reads of test_helper.rb, vcr_setup.rb, scraping_helpers.rb]

---

## Architecture Patterns

### Recommended Test File Organization

```
test/
├── models/
│   ├── league_test.rb                  # EXPAND existing (3 tests → ~20)
│   ├── league_standings_test.rb        # NEW: standings_table_* (CHAR-01)
│   ├── league_scraping_test.rb         # NEW: scrape_* with WebMock (CHAR-02)
│   ├── party_monitor_aasm_test.rb      # NEW: 9 states, 8 events (CHAR-03)
│   ├── party_monitor_placement_test.rb # NEW: do_placement, report_result (CHAR-04)
│   ├── party_test.rb                   # NEW: associations, flags, computed (CHAR-05)
│   └── league_team_test.rb             # NEW: associations, cc_id_link (CHAR-06)
└── support/
    └── party_monitor_test_helper.rb    # NEW: create_party_monitor_with_party, cleanup_*
```

**Alternative (coarser):** One file per model. Acceptable for small models — LeagueTeam and Party should use single files. League and PartyMonitor benefit from cluster-split files.

### Pattern 1: Local Record Creation (for PartyMonitor, Party)

The v2.1 pattern for models with `ApiProtector` or `LocalProtector`:

```ruby
# Source: test/models/tournament_monitor_t04_test.rb (v2.1 reference)
TEST_ID_BASE = 50_000_000

def create_party_monitor_with_party(attrs = {})
  @@counter ||= 0
  @@counter += 1
  base_id = TEST_ID_BASE + 30_000 + (@@counter * 100)

  league = League.create!(
    id: base_id,
    name: "Test League",
    shortname: "TL",
    organizer: regions(:nbv),
    organizer_type: "Region",
    season: seasons(:current),
    discipline: disciplines(:carom_3band)
  )
  party = Party.create!(
    id: base_id + 1,
    league: league,
    sets_to_play: 1,
    sets_to_win: 1,
    team_size: 1
  )
  party_monitor = PartyMonitor.create!(
    id: base_id + 2,
    party: party,
    state: "seeding_mode",
    data: {}
  )
  { party_monitor: party_monitor, party: party, league: league }
end
```

[VERIFIED: matches test_helper.rb ApiProtectorTestOverride pattern; id >= 50_000_000 bypasses both protectors in test env]

### Pattern 2: AASM State Transition Testing

```ruby
# Source: test/models/tournament_monitor_t04_test.rb (v2.1 reference)
test "transitions from seeding_mode to table_definition_mode via prepare_next_round" do
  assert_equal "seeding_mode", @pm.state
  assert @pm.may_prepare_next_round?
  @pm.prepare_next_round!
  assert_equal "table_definition_mode", @pm.reload.state
end

test "cannot close from playing_round directly" do
  @pm.state = "playing_round"
  @pm.save!(validate: false)
  assert_raises(AASM::InvalidTransition) do
    @pm.close_party!
  end
end
```

[VERIFIED: AASM gem convention — `may_EVENT?` predicate, `EVENT!` bang, `AASM::InvalidTransition` on invalid transition]

### Pattern 3: Standings Table Testing (League, pure computation)

```ruby
# Source: app/models/league.rb:1432-1494 — standings_table_karambol reads party.data["result"]
test "standings_table_karambol ranks teams by match points then diff" do
  # Create in-memory records: league + 2 teams + 2 parties with result data
  league = League.new(name: "Test", shortname: "T", discipline: @discipline)
  # ... build minimal object graph without DB ...
  # OR: use create! with local IDs

  # Set party data["result"] = "3:1" for home win
  party.update!(data: { "result" => "3:1" })

  result = league.standings_table_karambol
  assert_equal team_a, result.first[:team]
  assert_equal 1, result.first[:platz]
  assert_equal 2, result.first[:punkte]  # 2 points for win
end
```

[VERIFIED: standings_table_karambol source read — reads party.data["result"], splits ":", sorts by [-punkte, -diff]]

### Pattern 4: WebMock HTML Stub for Scraping Tests

```ruby
# Source: test/characterization/region_cc_char_test.rb (v1.0 reference)
# Source: test/support/scraping_helpers.rb
VCR_RECORD_MODE = ENV["RECORD_VCR"] ? :new_episodes : :none

def cassette_exists?(name)
  File.exist?(Rails.root.join("test", "snapshots", "vcr", "#{name}.yml"))
end

def with_vcr_cassette(name, &block)
  if VCR_RECORD_MODE == :none && !cassette_exists?(name)
    skip "VCR cassette '#{name}.yml' missing. Record with: RECORD_VCR=true bin/rails test ..."
  end
  VCR.use_cassette(name, record: VCR_RECORD_MODE, &block)
end
```

For League scraping tests that don't need real ClubCloud data (structural tests), use direct `stub_request`:

```ruby
# Source: test/support/scraping_helpers.rb — mock_clubcloud_html helper
def mock_clubcloud_html(url, html_content)
  stub_request(:get, url).to_return(status: 200, body: html_content,
                                    headers: { "Content-Type" => "text/html" })
end
```

[VERIFIED: vcr_setup.rb, scraping_helpers.rb, region_cc_char_test.rb all read and confirmed]

### Pattern 5: LeagueTeam cc_id_link Testing

`cc_id_link` requires `league.organizer.public_cc_url_base` — needs a Region with `public_cc_url_base`. Check whether the `nbv` fixture provides this or whether it must be stubbed.

```ruby
# Approach: stub public_cc_url_base on the region fixture
test "cc_id_link returns correct ClubCloud URL" do
  league_team = league_teams(:one)
  # cc_id_link calls league.organizer.public_cc_url_base + parameters
  # Mock or assign public_cc_url_base if not in fixture
  league_team.league.organizer.stubs(:public_cc_url_base).returns("https://example.club-cloud.de/")
  assert_match(/sb_spielplan\.php/, league_team.cc_id_link)
end
```

[ASSUMED — `public_cc_url_base` column presence on Region not verified from code read; planner should check Region fixture]

### Anti-Patterns to Avoid

- **Full mock chains for complex paths:** `do_placement` and `report_result` have 10+ collaborators — use real DB records, not mocks, to get behavior coverage.
- **Skipping teardown reset for cattr_accessor:** `PartyMonitor.allow_change_tables` is a `cattr_accessor` — if set in setup, must be cleared in teardown (learned from v2.1 Pitfall 10).
- **Testing private methods via `send` without documenting why:** League's `reconstruct_game_plan_from_existing_data` is private — document that it's called via `send` because it's a characterization test.
- **Using global fixture IDs for new test records:** Always use id >= 50_000_000 for programmatically created records; fixtures already enforce this in `leagues.yml`, `regions.yml`, etc.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP mocking for scraping tests | Custom HTTP interceptor | WebMock + VCR (already installed) | VCR handles recording, replay, filtering secrets |
| AASM state forcing | Direct SQL UPDATE to bypass callbacks | `record.state = "x"; record.save!(validate: false)` | Safe pattern from v2.1; callbacks only run via events |
| Test DB record creation with protector bypass | Manually toggle protector flags | ApiProtectorTestOverride already globally installed — just use id >= MIN_ID | Already in test_helper.rb:52-66 |
| Fixture association graph for League | Build complex fixture YAML | Create via `League.create!(...)` in helper with local IDs | More readable, avoids yml ordering issues |

---

## Critical Behavioral Inventory

### PartyMonitor AASM — 9 States, 8 Events

| State | Initial? | Entry Callback |
|-------|----------|----------------|
| `seeding_mode` | yes | `reset_party_monitor` |
| `table_definition_mode` | no | none |
| `next_round_seeding_mode` | no | none |
| `ready_for_next_round` | no | none |
| `playing_round` | no | none |
| `round_result_checking_mode` | no | none |
| `party_result_checking_mode` | no | none |
| `party_result_reporting_mode` | no | none |
| `closed` | no | none |

[VERIFIED: party_monitor.rb:52-88 read directly — 9 states confirmed, including `party_result_reporting_mode` which is NOT in the CONTEXT.md D-03 list of 8 states. The CONTEXT.md list omits `party_result_reporting_mode`. Tests must cover all 9.]

| Event | From States | To State |
|-------|-------------|----------|
| `prepare_next_round` | `seeding_mode`, `round_result_checking_mode` | `table_definition_mode` |
| `enter_next_round_seeding` | `table_definition_mode` | `next_round_seeding_mode` |
| `finish_round_seeding_mode` | `next_round_seeding_mode` | `ready_for_next_round` |
| `start_round` | `ready_for_next_round` | `playing_round` |
| `finish_round` | `playing_round` | `round_result_checking_mode` |
| `finish_party` | `round_result_checking_mode` | `party_result_checking_mode` |
| `close_party` | `party_result_checking_mode` | `closed` |
| `end_of_party` | any | `closed` |

[VERIFIED: party_monitor.rb:63-88]

### League — Key Method Locations

| Cluster | Methods | LOC approx | Test Strategy |
|---------|---------|------------|---------------|
| Standings tables | `standings_table_karambol` (L1432), `standings_table_snooker` (L1497), `standings_table_pool` (L1562) | ~170 | DB records: league + league_teams + parties with data["result"] |
| Game plan reconstruction | `reconstruct_game_plan_from_existing_data` (L1794, private), `analyze_game_plan_structure` (L2032), `reconstruct_game_plans_for_season` (L2111) | ~240 | Expand existing 3 tests; use send for private methods |
| Scraping | `scrape_leagues_from_cc` (L303), `scrape_leagues_optimized` (L405), `scrape_league_optimized` (L539), `scrape_league_teams_optimized` (L554), `scrape_party_games_optimized` (L564) | ~400 | WebMock HTML stubs; VCR cassettes for full integration |
| Computed | `name` (L288), `branch` (L292), `schedule_by_rounds` (L1629), `cc_id_link` (L1393) | ~50 | Simple DB or in-memory |

[VERIFIED: grep on league.rb line numbers]

### Party — Behavioral Notes

- `intermediate_result` (L144-175): Returns `[0, 0]` unconditionally — the real implementation is dead code after the `return [0, 0]` on line 147. Test must pin this stub behavior explicitly.
- `name` (L177): `"#{league_team_a.name} - #{league_team_b.name}"` — requires both league_teams to be set.
- `party_nr` (L185): Has a side effect — sets and saves `party_no` if blank; calls `self.unprotected = true` + `save!`. Requires DB-persisted party with league.
- `manual_assignment` (L204): Hardcoded `true` — override of the column value. Test that the method returns true regardless of column.

[VERIFIED: party.rb full read]

### LeagueTeam — Behavioral Notes

- `cc_id_link` (L58): Requires `league.organizer.public_cc_url_base` — if Region fixture lacks `public_cc_url_base`, must stub or add to fixture.
- `scrape_players_from_ba_league_team` (L62): Empty method body — test that it returns nil without raising.
- Associations: `parties_a` (home), `parties_b` (guest), `parties_as_host`, `no_show_parties`, `seedings` — all testable via fixture references.

[VERIFIED: league_team.rb full read]

---

## Common Pitfalls

### Pitfall 1: PartyMonitor `reset_party_monitor` fires on `seeding_mode` entry
**What goes wrong:** The AASM `after_enter: [:reset_party_monitor]` on `seeding_mode` calls `update(...)`, destroys games/seedings, and calls `save!`. Creating a PartyMonitor with `state: "seeding_mode"` directly via `create!` is fine (no AASM callback fires on create). But triggering `end_of_party!` from a non-seeding state will transition to `closed`, not re-enter `seeding_mode`.
**How to avoid:** Use `create!(state: "seeding_mode")` to start in initial state. To test `reset_party_monitor`, call it directly via `send(:reset_party_monitor)` after ensuring `party` is associated.
**Warning signs:** `NoMethodError` on `tournament.andand.sets_to_play` — means `party_monitor.party` is nil.

### Pitfall 2: Party fixture for `party_monitors.yml` uses `party_id: 1` (global record)
**What goes wrong:** The existing `party_monitors.yml` references `party_id: 1` which is a global record (id < 50_000_000). `LocalProtectorTestOverride` handles this but `ApiProtectorTestOverride` blocks saving PartyMonitor if the class-level protector isn't bypassed via id.
**How to avoid:** Create PartyMonitor test records programmatically with id >= 50_000_000. Do not rely on the existing `party_monitors` fixtures for AASM tests.
**Warning signs:** `ActiveRecord::RecordNotSaved` or silent rollback when saving PartyMonitor.

### Pitfall 3: `cattr_accessor :allow_change_tables` pollution across tests
**What goes wrong:** PartyMonitor has `cattr_accessor :allow_change_tables` — if a test sets this and doesn't reset it in teardown, subsequent tests see the mutated value.
**How to avoid:** Always include in teardown:
```ruby
teardown do
  PartyMonitor.allow_change_tables = nil
end
```
**Warning signs:** Tests pass in isolation but fail when run as suite.

### Pitfall 4: League standings methods require DB-persisted parties with `data["result"]`
**What goes wrong:** `standings_table_karambol` iterates `parties.where(league_team_a: team)` — this is an ActiveRecord query, not in-memory. In-memory League objects won't work.
**How to avoid:** Create league, league_teams, and parties as DB records with local IDs. Set `party.data = { "result" => "3:1" }` before calling standings.
**Warning signs:** Empty result array from standings method even though parties were created.

### Pitfall 5: `party_nr` has side effect (saves party record)
**What goes wrong:** `party_nr` calls `self.unprotected = true; self.party_no = ...; save!; self.unprotected = false` if `party_no` is blank. Calling it in a test will modify the record in DB.
**How to avoid:** Either set `party_no` on the fixture before calling `party_nr`, or assert the side effect explicitly and document it as characterization.

### Pitfall 6: League scraping uses `Net::HTTP.get` directly (not a service layer)
**What goes wrong:** `scrape_leagues_from_cc` calls `Net::HTTP.get(uri)` — WebMock blocks this by default. Tests that call scraping methods without stubs will get a `WebMock::NetConnectNotAllowedError`.
**How to avoid:** Use `stub_request(:get, /expected_url_pattern/)` before calling any `scrape_*` method. HTML fixture files exist in `test/fixtures/html/` for tournament scraping — create equivalent for league scraping.

### Pitfall 7: `party_result_reporting_mode` is a 9th state not in CONTEXT.md
**What goes wrong:** CONTEXT.md D-03 lists 8 states but `party_monitor.rb` has 9 — `party_result_reporting_mode` exists as a declared state with no inbound transitions defined in the AASM block. It appears to be a legacy state. Tests for `end_of_party` (transitions to `closed` from any state) will cover entry-from-any-state behavior.
**How to avoid:** Document all 9 states in test comments. Test that `party_result_reporting_mode` is a valid state string via `aasm.states.map(&:name)`.

---

## Code Examples

### ApiProtectorTestOverride Verification (required once per PartyMonitor test file)

```ruby
# Source: test/test_helper.rb:52-66 — ApiProtectorTestOverride pattern
test "ApiProtectorTestOverride allows saving local PartyMonitor" do
  pm = PartyMonitor.create!(state: "seeding_mode", data: {})
  assert pm.persisted?, "PartyMonitor should save with ApiProtectorTestOverride active"
  assert PartyMonitor.ancestors.include?(ApiProtectorTestOverride)
  pm.destroy
end
```

### Standings Table Test Skeleton

```ruby
# Source: app/models/league.rb:1432-1494
test "standings_table_karambol ranks team with win above team with loss" do
  base = 50_100_000
  league = League.create!(id: base, name: "L", shortname: "L",
                           organizer: regions(:nbv), organizer_type: "Region",
                           season: seasons(:current), discipline: disciplines(:carom_3band))
  team_a = LeagueTeam.create!(id: base + 1, league: league, name: "TeamA", cc_id: 1)
  team_b = LeagueTeam.create!(id: base + 2, league: league, name: "TeamB", cc_id: 2)
  # Home win for team_a: result "3:1"
  Party.create!(id: base + 3, league: league,
                league_team_a: team_a, league_team_b: team_b,
                data: { "result" => "3:1" })
  table = league.standings_table_karambol
  assert_equal team_a.id, table.first[:team].id
  assert_equal 2, table.first[:punkte]  # 2 points for win
  assert_equal 0, table.last[:punkte]
end
```

### PartyMonitor AASM Happy Path

```ruby
# Source: app/models/party_monitor.rb:63-88
test "happy path: seeding_mode through table_definition_mode to playing_round" do
  assert_equal "seeding_mode", @pm.state
  @pm.prepare_next_round!
  assert_equal "table_definition_mode", @pm.reload.state
  @pm.enter_next_round_seeding!
  assert_equal "next_round_seeding_mode", @pm.reload.state
  @pm.finish_round_seeding_mode!
  assert_equal "ready_for_next_round", @pm.reload.state
  @pm.start_round!
  assert_equal "playing_round", @pm.reload.state
end
```

---

## Fixtures Available

| Fixture File | Key Records | Usable By |
|-------------|-------------|-----------|
| `leagues.yml` | `one` (id: 50_000_001, organizer: nbv) | League tests as base |
| `regions.yml` | `nbv`, `bbv`, `bbl`, `dbu` | All models via `organizer:` |
| `seasons.yml` | `current`, `previous`, `season_2024` | League, Party |
| `disciplines.yml` | `carom_3band`, `pool_8ball`, `pool_9ball`, `discipline_freie_partie_klein`, `one` | League, Party |
| `table_monitors.yml` | `one`, `two` (id: 50_000_001/2, state: "new") | PartyMonitor do_placement tests |
| `game_plans.yml` | `one`, `two` (minimal) | League game plan tests |
| `party_monitors.yml` | `one`, `two` (stub, state: "MyString") | NOT suitable — create programmatically |

**Missing fixture files** (must create in Wave 0):
- `parties.yml` — needed for Party tests and PartyMonitor associations
- `league_teams.yml` — needed for LeagueTeam tests and standings tests

[VERIFIED: `ls test/fixtures/` — no parties.yml or league_teams.yml exist]

---

## Runtime State Inventory

Step 2.5: SKIPPED — this is a greenfield test-writing phase, not a rename/refactor phase. No runtime state concerns.

---

## Environment Availability

Step 2.6: No external dependencies beyond existing project stack.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| PostgreSQL | All DB tests | Assumed available | Used by entire test suite (751 tests pass) |
| Redis | Action Cable callbacks | Assumed available | Existing suite relies on it |
| VCR gem | League scraping tests | Yes | Confirmed in vcr_setup.rb |
| WebMock gem | All scraping stubs | Yes | Confirmed in test_helper.rb |

[VERIFIED: `bin/rails test` completes successfully — 751 runs, 0 failures]

---

## Validation Architecture

`workflow.nyquist_validation` is explicitly `false` in `.planning/config.json` — this section is skipped.

---

## Security Domain

Tests only — no new production code, no new endpoints, no authentication paths, no user data handling. ASVS review not required for test-only phases.

---

## Open Questions (RESOLVED)

1. **Does Region have `public_cc_url_base` column?** — RESOLVED
   - Resolution: Executor reads `app/models/region.rb` and `test/fixtures/regions.yml` at task time (Plan 20-01 Task 1 read_first includes region.rb). Adapts test setup based on findings.

2. **Should League scraping tests use VCR cassettes or WebMock HTML stubs?** — RESOLVED
   - Resolution: Plan 20-02 Task 2 chose WebMock HTML stubs (Claude's Discretion per CONTEXT.md). Deterministic, no external dependencies.

3. **Does `next_seqno` exist on PartyMonitor?** — RESOLVED
   - Resolution: Executor greps for `def next_seqno` at task time (Plan 20-03 Task 2 read_first). Adapts do_placement tests based on findings.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Region fixture `nbv` has `public_cc_url_base` or can be stubbed for `cc_id_link` tests | Code Examples | LeagueTeam test fails; need to add column to fixture or use `stubs()` |
| A2 | `party_result_reporting_mode` has no inbound transitions defined in AASM — it's a legacy state | Critical Behavioral Inventory | If it has transitions from undiscovered events, test coverage will be incomplete |
| A3 | `next_seqno` method exists on PartyMonitor (called in do_placement) | Open Questions | `do_placement` tests raise `NoMethodError` |

---

## Sources

### Primary (HIGH confidence)
- `app/models/party_monitor.rb` (605 lines) — AASM block, all method signatures, directly read
- `app/models/league.rb` (2219 lines, key sections) — method locations, standings logic, scraping pipeline, directly read
- `app/models/party.rb` (216 lines) — complete file read
- `app/models/league_team.rb` (63 lines) — complete file read
- `test/test_helper.rb` — ApiProtectorTestOverride, LocalProtectorTestOverride, complete read
- `test/support/vcr_setup.rb` — VCR configuration, complete read
- `test/support/scraping_helpers.rb` — mock helpers, complete read
- `test/characterization/region_cc_char_test.rb` — canonical VCR+WebMock pattern, read lines 1-100
- `.planning/milestones/v2.1-phases/11-tournamentmonitor-characterization/11-01-PLAN.md` — v2.1 fixture strategy, TEST_ID_BASE pattern, cattr_accessor teardown
- `test/fixtures/` — inventory of all existing fixture files

### Secondary (MEDIUM confidence)
- `.planning/milestones/v2.1-phases/12-tournament-characterization/12-RESEARCH.md` — prior research for similar characterization phase

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all infrastructure already installed and in production use
- Architecture patterns: HIGH — directly derived from v2.1 plans and codebase reads
- Pitfalls: HIGH — most derived from direct code inspection; Pitfall 1 and 3 confirmed from v2.1 PLAN summaries
- AASM state map: HIGH — read directly from party_monitor.rb
- League method locations: HIGH — verified via grep with line numbers
- Region `public_cc_url_base`: LOW — assumed, not verified

**Research date:** 2026-04-11
**Valid until:** 2026-05-11 (stable codebase, no fast-moving dependencies)
