# Phase 14: Medium-Risk Extractions - Research

**Researched:** 2026-04-10
**Domain:** Ruby service extraction — Tournament::PublicCcScraper (~700 lines) and TournamentMonitor::RankingResolver (~195 lines)
**Confidence:** HIGH — all findings from direct codebase reading; no external sources needed

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**PublicCcScraper (TEXT-03)**
- D-01: Extract as ApplicationService in `app/services/tournament/public_cc_scraper.rb`. Service receives tournament instance and writes directly to DB (creates Game/GameParticipation/Seeding records via @tournament associations). Faithful extraction — move code as-is with `self` → `@tournament` conversion.
- D-02: Tournament gets a 1-line delegation wrapper for `scrape_single_tournament_public`.
- D-03: Claude determines the cleanest extraction boundary — which methods move and which stay. The goal is maximum line reduction while maintaining behavior preservation. All variant methods, parse helpers, and handle_game are candidates for extraction.

**RankingResolver (TMEX-02)**
- D-04: Extract as PORO in `app/services/tournament_monitor/ranking_resolver.rb`. Service receives the TournamentMonitor instance. Accesses tournament, seedings, data["rankings"] through @tournament_monitor.
- D-05: `group_rank` calls `PlayerGroupDistributor.distribute_to_group` directly (the Phase 13 PORO) — not through the TournamentMonitor delegation wrapper. This is cleaner cross-service communication.
- D-06: TournamentMonitor gets a delegation wrapper for `player_id_from_ranking`. Private methods (`ko_ranking`, `group_rank`, `random_from_group_ranks`, `rank_from_group_ranks`) move entirely to the service.

**Shared Decisions**
- D-07: Follow v1.0/Phase 13 extraction pattern: extract → delegate → test.
- D-08: Services in `app/services/tournament/` and `app/services/tournament_monitor/` (existing directories from Phase 13).
- D-09: New unit tests in `test/services/tournament/` and `test/services/tournament_monitor/`.
- D-10: All Phase 11-12 characterization tests MUST pass without modification after extraction.
- D-11: VCR/WebMock tests for scraper service reuse the approach from Phase 12 `tournament_scraping_test.rb`.

### Claude's Discretion
- Exact extraction boundary for PublicCcScraper (which helpers move, which stay)
- Whether to split PublicCcScraper into sub-classes (unlikely — faithful extraction is the goal)
- Internal method organization within services
- `self` → `@tournament` / `@tournament_monitor` conversion details
- Error handling preservation (rescue blocks move with their methods)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TEXT-03 | Tournament::PublicCcScraper extracted (~700 lines) with VCR-backed tests | Method map below; WebMock stub pattern confirmed; extraction boundary determined |
| TMEX-02 | TournamentMonitor::RankingResolver extracted (regex rule parser) with unit tests | Method map below; caller graph confirmed; cross-service dependency on PlayerGroupDistributor documented |
</phase_requirements>

---

## Summary

Phase 14 extracts two large clusters from Tournament and TournamentMonitor. The scraping cluster (`PublicCcScraper`, ~600+ lines across 20 methods) is the largest single extraction in the milestone. The ranking resolver cluster (`RankingResolver`, ~195 lines across 5 methods) is smaller but more algorithmically complex due to recursive rule resolution. Both extractions follow the identical Phase 13 pattern: extract → delegate → test.

The critical research finding is the exact method boundary for each extraction. `parse_table_td` is **not called anywhere** — it is dead code on Tournament and can be moved with the scraper but is low priority. `fix_location_from_location_text` is also orphaned (no callers found). All active scraping methods (`scrape_single_tournament_public`, `parse_table_tr`, `handle_game`, `variant0-variant8`, `result_with_*`) call each other internally, forming a coherent cluster.

For RankingResolver: `player_id_from_ranking` is public, called by `TournamentMonitorSupport#populate_tables` (lines 656, 724) and `update_ranking` (lines 284, 290), and by `rank_from_group_ranks` recursively. The delegation wrapper on TournamentMonitor preserves all callers without modification.

**Primary recommendation:** Extract both services as faithful code moves with `self` → `@tournament`/`@tournament_monitor` substitution. No redesign. Use WebMock stubs (not VCR cassettes) for scraper tests, matching the Phase 12 `tournament_scraping_test.rb` pattern.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ApplicationService | (project base class) | Base for PublicCcScraper | Phase 13 pattern; TableReservationService uses it |
| PORO | N/A | Base for RankingResolver | Phase 13 pattern; PlayerGroupDistributor uses it |
| Minitest | (Rails bundled) | Unit tests | Project standard; existing test infrastructure |
| WebMock | (Gemfile) | HTTP stub for scraper tests | Phase 12 uses WebMock stubs, not VCR cassettes |
| Nokogiri | 1.12.5+ | HTML parsing | Already used in scraping code; no new dependency |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| TournamentMonitor::PlayerGroupDistributor | Phase 13 extraction | Group distribution for `group_rank` | Called directly by RankingResolver (D-05) |
| Net::HTTP | (Ruby stdlib) | HTTP calls in scraper | Already used in scrape_single_tournament_public |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| ApplicationService for scraper | PORO | ApplicationService is correct — scraper has side effects (DB writes, HTTP calls) |
| PORO for RankingResolver | ApplicationService | PORO is correct — no HTTP calls, no independent DB writes; pure resolution algorithm |
| WebMock stubs | VCR cassettes | WebMock matches Phase 12 pattern and avoids cassette re-recording risk (Pitfall 8) |

**Installation:** No new gems required. All dependencies already in Gemfile.

---

## Architecture Patterns

### Recommended Project Structure

```
app/services/
├── tournament/
│   ├── ranking_calculator.rb          # Phase 13 (exists)
│   ├── table_reservation_service.rb   # Phase 13 (exists)
│   └── public_cc_scraper.rb           # Phase 14 (new)
└── tournament_monitor/
    ├── player_group_distributor.rb    # Phase 13 (exists)
    └── ranking_resolver.rb            # Phase 14 (new)

test/services/
├── tournament/
│   ├── ranking_calculator_test.rb     # Phase 13 (exists)
│   ├── table_reservation_service_test.rb  # Phase 13 (exists)
│   └── public_cc_scraper_test.rb      # Phase 14 (new)
└── tournament_monitor/
    ├── player_group_distributor_test.rb   # Phase 13 (exists)
    └── ranking_resolver_test.rb           # Phase 14 (new)
```

### Pattern 1: ApplicationService with @tournament (PublicCcScraper)

**What:** Faithful move of all scraping methods from Tournament. Constructor receives tournament. All `self.method` → `@tournament.method`. All `self.attribute = ...` → `@tournament.attribute = ...`.
**When to use:** Side-effect services (DB writes, HTTP calls).

```ruby
# Source: app/services/tournament/table_reservation_service.rb (Phase 13 pattern)
class Tournament::PublicCcScraper < ApplicationService
  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
    @opts = kwargs[:opts] || {}
  end

  def call
    # All contents of scrape_single_tournament_public move here
    # self → @tournament throughout
  end

  private

  # parse_table_tr, handle_game, variant0..variant8, result_with_* all move here
end
```

**Delegation wrapper in Tournament:**
```ruby
def scrape_single_tournament_public(opts = {})
  Tournament::PublicCcScraper.call(tournament: self, opts: opts)
end
```

### Pattern 2: PORO with @tournament_monitor (RankingResolver)

**What:** Faithful move of ranking resolution methods. Constructor receives tournament_monitor. All data/tournament access goes through @tournament_monitor.
**When to use:** Pure algorithm services with no independent DB writes or HTTP calls.

```ruby
# Source: app/services/tournament_monitor/player_group_distributor.rb (Phase 13 pattern)
class TournamentMonitor::RankingResolver
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  def player_id_from_ranking(rule_str, opts = {})
    # Move contents from TournamentMonitor#player_id_from_ranking
    # self.something → @tournament_monitor.something
  rescue StandardError => e
    Tournament.logger.info "player_id_from_ranking(#{rule_str}) #{e} #{e.backtrace&.join("\n")}"
    nil
  end

  private

  def ko_ranking(rule_str)
    # data → @tournament_monitor.data
    # tournament → @tournament_monitor.tournament
    # TournamentMonitor.ranking(…) → TournamentMonitor.ranking(…)  # class method stays
  end

  def group_rank(match)
    # TournamentMonitor.distribute_to_group → TournamentMonitor::PlayerGroupDistributor.distribute_to_group
    # per D-05
  end

  def random_from_group_ranks(match, ordered_ranking_nos, rule_str)
    # tournament → @tournament_monitor.tournament
    # data → @tournament_monitor.data
  end

  def rank_from_group_ranks(match, opts = {})
    # Recursive: player_id_from_ranking calls are self-calls within service (no change needed)
    # tournament → @tournament_monitor.tournament
    # data → @tournament_monitor.data
  end
end
```

**Delegation wrapper in TournamentMonitor:**
```ruby
def player_id_from_ranking(rule_str, opts = {})
  TournamentMonitor::RankingResolver.new(self).player_id_from_ranking(rule_str, opts)
end
```

### Pattern 3: Test Structure (matching Phase 13)

```ruby
# Source: test/services/tournament_monitor/player_group_distributor_test.rb
class TournamentMonitor::RankingResolverTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  setup do
    # Build tournament_monitor with data["rankings"] populated
    # No HTTP calls needed
  end

  test "player_id_from_ranking resolves sl.rk1" do
    resolver = TournamentMonitor::RankingResolver.new(@tm)
    assert_equal @players[0].id, resolver.player_id_from_ranking("sl.rk1", executor_params: {})
  end
end
```

### Anti-Patterns to Avoid

- **Calling `save!` twice:** If `@tournament.save!` is inside PublicCcScraper and the delegation wrapper also saves, PaperTrail creates double versions. The scraper's own `save!` calls are the canonical saves — the delegation wrapper must NOT add another.
- **Using `read_attribute` for dynamic attributes:** `sets_to_play`, `timeouts`, `timeout` etc. are dynamically overridden. Always call `@tournament.sets_to_play`, never `@tournament.read_attribute(:sets_to_play)`.
- **Calling `TournamentMonitor.distribute_to_group` from RankingResolver:** Per D-05, call `TournamentMonitor::PlayerGroupDistributor.distribute_to_group` directly. The `TournamentMonitor.distribute_to_group` class method is a delegation wrapper — bypass it for cross-service calls.
- **Adding `rescue` blocks to delegation wrappers:** The scraper's top-level rescue (`rescue StandardError => e` → `reset_tournament`) must move with the method, not stay in the wrapper.

---

## PublicCcScraper — Complete Method Map

### Methods to MOVE to PublicCcScraper

| Method | Location in tournament.rb | Lines | self→@tournament conversions needed |
|--------|--------------------------|-------|-------------------------------------|
| `scrape_single_tournament_public` | 392–810 | ~419 | `self.source_url=`, `self.shortname=`, `self.date=`, `self.location=`, `self.accredation_end=`, `self.discipline_id=`, `self.region_id=`, `self.id` (→ `@tournament.id`), all association calls (`seedings`, `games`, `tournament_cc`, etc.) |
| `parse_table_tr` | 991–1096 | ~106 | No `self` refs — receives explicit params; `handle_game` call becomes private call within service |
| `handle_game` | 1469–1581 | ~113 | `self.id` → `@tournament.id`, `games` → `@tournament.games`, `discipline` → `@tournament.discipline`, `seedings` → `@tournament.seedings` |
| `parse_table_td` | 1280–1467 | ~188 | `self` refs through params (season, region passed explicitly); `id` → `@tournament.id`; **DEAD CODE** — no callers found in codebase |
| `variant0` | 1098–1106 | 9 | No `self` refs |
| `variant8` | 1108–1117 | 10 | No `self` refs |
| `variant7` | 1119–1130 | 12 | No `self` refs |
| `variant6` | 1132–1142 | 11 | No `self` refs |
| `variant5` | 1144–1153 | 10 | No `self` refs |
| `Variant4` | 1155–1166 | 12 | No `self` refs (NOTE: capital V — Ruby treats this as a constant if called without receiver; keep as-is) |
| `variant3` | 1168–1196 | 29 | No `self` refs |
| `variant2` | 1198–1207 | 10 | No `self` refs |
| `result_with_party_variant2` | 1209–1228 | 20 | No `self` refs |
| `result_with_party_variant` | 1230–1250 | 21 | No `self` refs |
| `result_with_party` | 1252–1259 | 8 | No `self` refs |
| `result_with_parties` | 1261–1268 | 8 | No `self` refs |
| `result_with_frames` | 1270–1278 | 9 | No `self` refs |
| `fix_location_from_location_text` | 812–819 | 8 | `location_text` → `@tournament.location_text`, `location` → `@tournament.location`; **DEAD CODE** — no callers found |

**Total lines moving:** ~987 lines (including dead code). Active scraping cluster is ~800 lines.

### Methods that STAY in Tournament

| Method | Reason |
|--------|--------|
| `scrape_single_tournament_public` | Replaced by 1-line delegation wrapper |
| `deep_merge_data!` | Used by reset_tournament, AASM callbacks — unrelated to scraping |
| `reset_tournament` | AASM after_enter callback — must stay on model |
| `calculate_and_cache_rankings` | Already delegated to RankingCalculator — delegation wrapper stays |
| `fix_location_from_location_text` | Could move with scraper (dead code) or be deleted — Claude's discretion |
| `fallback_table_count` | Used by `required_tables_count` — stays in model (TableReservationService has its own copy) |
| `before_all_events` | AASM callback — stays |

### Critical `self` → `@tournament` Conversions in `scrape_single_tournament_public`

All assignments like `self.source_url = ...`, `self.shortname = ...`, `self.date = ...` become `@tournament.source_url = ...` etc.

Attribute reads: `organizer_type`, `organizer`, `tournament_cc`, `season`, `title`, `id`, `discipline_id`, `region_id`, `location`, `data`, `seedings`, `games`, `source_url`, `accredation_end`, `shortname` — all prefixed with `@tournament.`.

Saves: `save!` → `@tournament.save!`, `reload` → `@tournament.reload`, `save` → `@tournament.save`, `changed?` → `@tournament.changed?`.

Rescue block at line 807–809: `reset_tournament` → `@tournament.reset_tournament`. The rescue moves into the service `call` method.

---

## RankingResolver — Complete Method Map

### Methods to MOVE to RankingResolver

| Method | Location in tournament_monitor.rb | Lines | self→@tournament_monitor conversions |
|--------|----------------------------------|-------|--------------------------------------|
| `player_id_from_ranking` (public) | 145–163 | 19 | No direct `self` refs; recursion calls `player_id_from_ranking` (stays as internal call) |
| `ko_ranking` (private) | 181–227 | 47 | `data` → `@tournament_monitor.data`, `tournament.seedings` → `@tournament_monitor.tournament.seedings`, `tournament.handicap_tournier?` → `@tournament_monitor.tournament.handicap_tournier?`, `TournamentMonitor.ranking(...)` → stays as class method call |
| `group_rank` (private) | 229–247 | 19 | `tournament.seedings` → `@tournament_monitor.tournament.seedings`, `tournament.tournament_plan` → `@tournament_monitor.tournament.tournament_plan`, `TournamentMonitor.distribute_to_group(...)` → **`TournamentMonitor::PlayerGroupDistributor.distribute_to_group(...)`** per D-05 |
| `random_from_group_ranks` (private) | 249–291 | 43 | `tournament.gd_has_prio?` → `@tournament_monitor.tournament.gd_has_prio?`, `tournament.handicap_tournier?` → `@tournament_monitor.tournament.handicap_tournier?`, `tournament.seedings` → `@tournament_monitor.tournament.seedings`, `data` → `@tournament_monitor.data`, `TournamentMonitor.ranking(...)` → stays |
| `rank_from_group_ranks` (private) | 293–337 | 45 | Same pattern as `random_from_group_ranks`; recursive call to `player_id_from_ranking` stays as self-call within service |

**Total lines moving:** ~173 lines.

### Methods that STAY in TournamentMonitor

| Method | Reason |
|--------|--------|
| `player_id_from_ranking` | Replaced by delegation wrapper to service |
| `self.ranking` (line 135) | Class method used by ko_ranking/random_from_group_ranks/rank_from_group_ranks — stays as utility on model class |
| `next_seqno` | Used by TournamentMonitorSupport — stays |
| `self.distribute_to_group` | Existing delegation wrapper to PlayerGroupDistributor — stays (still needed by other callers) |
| `self.distribute_with_sizes` | Same — stays |

### Delegation wrapper design

The delegation wrapper for `player_id_from_ranking` must pass `opts` exactly, since callers pass `executor_params:` and `ordered_ranking_nos:` keyword args:

```ruby
def player_id_from_ranking(rule_str, opts = {})
  TournamentMonitor::RankingResolver.new(self).player_id_from_ranking(rule_str, opts)
end
```

---

## Caller Analysis

### scrape_single_tournament_public callers

| Caller | Location | Call Site | Impact After Extraction |
|--------|----------|-----------|------------------------|
| `TournamentsController#reload_from_cc` | `app/controllers/tournaments_controller.rb:140` | `@tournament.scrape_single_tournament_public(reload_game_results: reload_games)` | No change — delegation wrapper preserves interface |
| `VersionsController` | `app/controllers/versions_controller.rb:72` | `@tournament.scrape_single_tournament_public(...)` | No change |
| `Region#scrape_single_tournament_public` | `app/models/region.rb:573, 960` | `tournament.reload.scrape_single_tournament_public(opts...)` | No change |
| `ScrapingMonitor` concern | `app/models/concerns/scraping_monitor.rb:13` | Comment only — no live call | No change |
| `test/scraping/scraping_smoke_test.rb` | Lines 55, 67, 84, 101, 121, 171 | Direct call | No change — wrapper preserves method |
| `test/scraping/tournament_scraper_test.rb` | Line 121 | `club_tournament.scrape_single_tournament_public` | No change |
| `test/models/tournament_scraping_test.rb` | Multiple | Direct call and `send(:parse_table_tr, ...)` | CRITICAL: parse_table_tr tests use `send` on tournament — after extraction, those tests must call `send` on the service or be updated |

**CRITICAL FINDING:** `tournament_scraping_test.rb` calls `@tournament.send(:parse_table_tr, ...)` directly at line 338. After extraction, `parse_table_tr` lives on the service, not on Tournament. The characterization test must be updated (or the service must expose a test helper). This is the only test file that requires updating.

### player_id_from_ranking callers

| Caller | Location | Call Site | Impact After Extraction |
|--------|----------|-----------|------------------------|
| `TournamentMonitorSupport#populate_tables` | `lib/tournament_monitor_support.rb:656` | `player_id_from_ranking(rule_str, ...)` — called as `include`d method on TM instance | No change — delegation wrapper intercepts |
| `TournamentMonitorSupport#populate_tables` | `lib/tournament_monitor_support.rb:724` | Same pattern | No change |
| `TournamentMonitorSupport#update_ranking` | `lib/tournament_monitor_support.rb:284, 290` | `tm.player_id_from_ranking(rule_part, ...)` | No change — delegation wrapper intercepts |
| `rank_from_group_ranks` (recursive) | `app/models/tournament_monitor.rb:329` | `player_id_from_ranking(opts[:executor_params]["rules"][...], opts)` | Moves with the method — becomes self-call in RankingResolver |
| `test/models/tournament_monitor_ko_test.rb:90` | Direct call | `@tm.player_id_from_ranking("sl.rk1", executor_params: {})` | No change — delegation wrapper intercepts |

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP requests in scraper | Custom HTTP client | `Net::HTTP` (already used) | Already works, already stubbed by WebMock in tests |
| HTML parsing | Custom regex parser | `Nokogiri::HTML()` (already used) | Already works, no change needed |
| Cross-service call (group_rank) | Re-implementing distribute_to_group | `TournamentMonitor::PlayerGroupDistributor.distribute_to_group` | Phase 13 extraction exists; D-05 mandates this |
| Class method ranking | Re-implementing TournamentMonitor.ranking | `TournamentMonitor.ranking(...)` | Class method stays on model; call it from service |

**Key insight:** Both extractions are faithful code moves, not redesigns. No hand-rolling of any new algorithm.

---

## Common Pitfalls

### Pitfall 1: tournament_scraping_test.rb calls parse_table_tr via send on Tournament

**What goes wrong:** `tournament_scraping_test.rb` line 338 calls `@tournament.send(:parse_table_tr, ...)`. After extraction, `parse_table_tr` is private on `PublicCcScraper`, not on `Tournament`. The test will raise `NoMethodError`.

**Why it happens:** Characterization tests call private methods directly via `send` to test them in isolation.

**How to avoid:** Two options: (1) Update the test to build a service instance and call `send` on it. (2) In the service, make `parse_table_tr` testable via a public test accessor. Option 1 is cleaner and follows Phase 13 service test patterns.

**Warning signs:** `NoMethodError: undefined method parse_table_tr for Tournament`

### Pitfall 2: Variant4 method name (capital V) is a Ruby constant

**What goes wrong:** `Variant4` begins with a capital letter. In Ruby, identifiers starting with a capital letter are constants. When `parse_table_tr` calls `Variant4(...)`, Ruby may interpret this as a constant dereference rather than a method call, depending on context.

**Why it happens:** The method was defined as `def Variant4(...)` in the original code. Ruby permits this but it is unusual. Inside a class, `Variant4(args)` is interpreted as a method call (not constant), so it works. After extraction, this behavior is preserved as-is.

**How to avoid:** Keep the method name exactly as-is (`def Variant4`). Do not rename it. The characterization tests already verify this dispatch path.

### Pitfall 3: rescue block in scrape_single_tournament_public calls reset_tournament

**What goes wrong:** The rescue block at line 807–809 calls `reset_tournament`. In the service, this must become `@tournament.reset_tournament`. If missed, extraction silently loses error recovery behavior.

**Why it happens:** `reset_tournament` is a model method; the service has no such method.

**How to avoid:** Move the entire rescue block into the service's `call` method. Convert `reset_tournament` to `@tournament.reset_tournament`.

### Pitfall 4: rank_from_group_ranks recursively calls player_id_from_ranking

**What goes wrong:** `rank_from_group_ranks` (line 329) calls `player_id_from_ranking(...)`. Inside the service, this self-referential call is correct (both live in the same object). But if a developer adds explicit `opts` filtering or accidentally routes the call through the delegation wrapper on TournamentMonitor, a stack of double-indirection occurs.

**Why it happens:** The recursive pattern is easy to miss during extraction.

**How to avoid:** After extraction, `rank_from_group_ranks` calls `player_id_from_ranking(...)` — this is a plain method call within the service object, correct with no changes needed.

### Pitfall 5: TournamentMonitor.ranking class method must NOT move

**What goes wrong:** `ko_ranking`, `random_from_group_ranks`, and `rank_from_group_ranks` all call `TournamentMonitor.ranking(hash, opts)`. This is a class method on TournamentMonitor (line 135). It is NOT part of the RankingResolver cluster. Moving it would break all callers outside the service.

**Why it happens:** The method name suggests it belongs with the ranking resolver logic.

**How to avoid:** `TournamentMonitor.ranking` stays on TournamentMonitor. From within RankingResolver, call it as `TournamentMonitor.ranking(...)` (explicitly qualified — works from any context).

### Pitfall 6: PaperTrail double-version risk from scraper saves

**What goes wrong:** `scrape_single_tournament_public` calls `save!` directly on tournament and associated records (`tc.save!`, `seeding.save!`, `game.save!`). If the delegation wrapper also calls `save!`, double PaperTrail versions are created, corrupting sync.

**Why it happens:** Delegation wrappers sometimes add a `save!` at the end "for safety."

**How to avoid:** The delegation wrapper must be exactly 1 line: `Tournament::PublicCcScraper.call(tournament: self, opts: opts)`. No additional saves. Per PITFALLS.md Pitfall 2.

---

## Code Examples

Verified patterns from existing Phase 13 services:

### ApplicationService Pattern (from TableReservationService)

```ruby
# Source: app/services/tournament/table_reservation_service.rb
class Tournament::PublicCcScraper < ApplicationService
  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
    @opts = kwargs[:opts] || {}
  end

  def call
    # scrape_single_tournament_public contents here
    # all self.x → @tournament.x
  rescue StandardError => e
    Tournament.logger.info "===== scrape =====  StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
    @tournament.reset_tournament
  end
end
```

### PORO Pattern (from PlayerGroupDistributor)

```ruby
# Source: app/services/tournament_monitor/player_group_distributor.rb
class TournamentMonitor::RankingResolver
  def initialize(tournament_monitor)
    @tournament_monitor = tournament_monitor
  end

  def player_id_from_ranking(rule_str, opts = {})
    # contents here
  rescue StandardError => e
    Tournament.logger.info "player_id_from_ranking(#{rule_str}) #{e} #{e.backtrace&.join("\n")}"
    nil
  end

  private

  def ko_ranking(rule_str)
    # data["rankings"] → @tournament_monitor.data["rankings"]
    # tournament.seedings → @tournament_monitor.tournament.seedings
    # TournamentMonitor.ranking(...) → TournamentMonitor.ranking(...)  # class method
  end

  def group_rank(match)
    # TournamentMonitor.distribute_to_group → TournamentMonitor::PlayerGroupDistributor.distribute_to_group
  end
end
```

### WebMock Stub Pattern (from tournament_scraping_test.rb Phase 12)

```ruby
# Source: test/models/tournament_scraping_test.rb
def stub_remaining_calls
  stub_request(:get, /ndbv\.de/)
    .to_return(status: 200, body: MELDELISTE_HTML, headers: { "Content-Type" => "text/html" })
end

# In PublicCcScraper test — same pattern, called on the service
test "call returns early when organizer_type is not Region" do
  t = build_tournament_for_club
  result = Tournament::PublicCcScraper.call(tournament: t)
  assert_nil result
end
```

### Test for RankingResolver

```ruby
# Source: test/services/tournament_monitor/player_group_distributor_test.rb (structure)
class TournamentMonitor::RankingResolverTest < ActiveSupport::TestCase
  include KoTournamentTestHelper
  self.use_transactional_tests = true

  setup do
    @test_data = create_ko_tournament_with_seedings(8, { balls_goal: 30 })
    @tournament = @test_data[:tournament]
    @tournament.initialize_tournament_monitor
    @tm = @tournament.tournament_monitor
    @resolver = TournamentMonitor::RankingResolver.new(@tm)
  end

  test "player_id_from_ranking resolves sl.rk1 to first seeded player" do
    result = @resolver.player_id_from_ranking("sl.rk1", executor_params: {})
    assert_equal @test_data[:players][0].id, result
  end

  test "player_id_from_ranking rescues StandardError and returns nil" do
    result = @resolver.player_id_from_ranking("invalid.rule.format", executor_params: {})
    assert_nil result
  end
end
```

---

## Phase 13 Prerequisite Verification

The following Phase 13 services must exist before Phase 14 begins:

| Service | Path | Status |
|---------|------|--------|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | VERIFIED EXISTS [VERIFIED: codebase read] |
| `TournamentMonitor::PlayerGroupDistributor.distribute_to_group` | Method in above | VERIFIED EXISTS |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | VERIFIED EXISTS [VERIFIED: codebase read] |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | VERIFIED EXISTS [VERIFIED: codebase read] |

Phase 13 delegation wrappers on TournamentMonitor (lines 171–177) confirm the extraction pattern works as expected.

---

## Extraction Boundary Decision (Claude's Discretion per D-03)

**Decision: Move ALL scraping methods including parse_table_td and fix_location_from_location_text.**

Rationale:
- `parse_table_td`: dead code (0 callers outside tournament.rb). Moving it with the scraper cluster is cleaner than leaving dead code on the model. Mark in comment.
- `fix_location_from_location_text`: dead code (0 callers). Move with scraper.
- All active scraping methods form a tight dependency cluster. No method from the cluster is called by non-scraping code.
- Moving all of them yields maximum line reduction: ~600–700 lines removed from tournament.rb.

**What does NOT move:** `deep_merge_data!`, `reset_tournament`, `before_all_events`, `fallback_table_count`, `calculate_and_cache_rankings`/`reorder_seedings` (already delegated). These are used by AASM, other non-scraping paths, or the TableReservationService delegation.

---

## Environment Availability Audit

Step 2.6: All dependencies are internal to the codebase. No external tools required for extraction. WebMock is already in Gemfile. Nokogiri already present. `nyquist_validation: false` in config.json — no test framework install needed.

Environment availability: SKIPPED — all dependencies already available in project.

---

## Validation Architecture

`nyquist_validation: false` in `.planning/config.json` — this section is skipped per config.

---

## Security Domain

`security_enforcement` not explicitly set in config — treated as enabled. Assessing:

- PublicCcScraper makes HTTP calls to external URLs (ClubCloud). WebMock blocks these in tests. No new authentication, session management, or access control introduced.
- The extracted service does not expose new endpoints. No ASVS V2/V3/V4 concerns introduced.
- V5 Input Validation: scraper parses untrusted HTML from external sites. The existing code already uses Nokogiri (safe HTML parsing) and pattern matching. No change to security posture — move as-is.
- V6 Cryptography: not applicable.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A — extraction only |
| V3 Session Management | No | N/A |
| V4 Access Control | No | N/A — no new endpoints |
| V5 Input Validation | Partial | Nokogiri already used; move as-is |
| V6 Cryptography | No | N/A |

No new threat surface introduced by either extraction.

---

## Assumptions Log

All findings in this research are VERIFIED via direct codebase reading. No ASSUMED claims.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

**All claims verified by direct codebase reading in this session.**

---

## Open Questions

1. **Should tournament_scraping_test.rb be updated in Phase 14 or was it updated in Phase 12/13?**
   - What we know: The test calls `@tournament.send(:parse_table_tr, ...)` at line 338. After extraction, this call breaks.
   - What's unclear: Whether Phase 12 characterization tests are locked (D-10 says "must pass without modification") or whether the test itself needs to migrate.
   - Recommendation: D-10 says characterization tests must pass "after extraction." The test calls a private method on Tournament that will no longer exist there. The planner must include a task to update `tournament_scraping_test.rb` to call the same method on the service instead, OR verify that the test already passes through the delegation wrapper (it won't — it uses `send`). This is a mandatory task, not optional.

2. **Does `parse_table_td` need to be tested separately?**
   - What we know: It is dead code — no callers. Existing characterization tests do not cover it.
   - What's unclear: Whether it should be deleted or just moved.
   - Recommendation: Move with the scraper cluster. Mark as dead code in a comment. Deletion is a separate cleanup decision.

---

## Sources

### Primary (HIGH confidence — all from direct codebase reading)

- `app/models/tournament.rb` (1594 lines) — all method definitions, line numbers, caller patterns verified
- `app/models/tournament_monitor.rb` (349 lines) — all method definitions, line numbers verified
- `lib/tournament_monitor_support.rb` — caller graph for `player_id_from_ranking` verified
- `app/services/tournament/table_reservation_service.rb` — ApplicationService pattern
- `app/services/tournament/ranking_calculator.rb` — PORO delegation pattern
- `app/services/tournament_monitor/player_group_distributor.rb` — PORO pattern
- `test/models/tournament_scraping_test.rb` — WebMock stub pattern, `send(:parse_table_tr, ...)` finding
- `test/models/tournament_monitor_ko_test.rb` — `player_id_from_ranking` test pattern
- `test/services/tournament/ranking_calculator_test.rb` — service test structure
- `test/services/tournament_monitor/player_group_distributor_test.rb` — service test structure
- `.planning/phases/14-medium-risk-extractions/14-CONTEXT.md` — locked decisions
- `.planning/research/FEATURES.md` — extraction candidate analysis
- `.planning/research/ARCHITECTURE.md` — cluster boundaries
- `.planning/research/PITFALLS.md` — PaperTrail, VCR, rescue block risks

### Grep verification

- `grep scrape_single_tournament_public **/*.rb` — all 13 call sites identified
- `grep player_id_from_ranking **/*.rb` — all 9 call sites identified
- `grep parse_table_td **/*.rb` — 0 callers confirmed (dead code)
- `grep fix_location_from_location_text **/*.rb` — 0 callers confirmed (dead code)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Phase 13 patterns verified in codebase
- Architecture: HIGH — direct code reading, all line numbers verified
- Caller graph: HIGH — grep verified, 0 false negatives expected
- Pitfalls: HIGH — based on existing PITFALLS.md + new finding (parse_table_tr send in test)

**Research date:** 2026-04-10
**Valid until:** Stable — refactoring codebase, no external APIs
