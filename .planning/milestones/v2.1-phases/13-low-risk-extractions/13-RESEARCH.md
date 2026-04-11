# Phase 13: Low-Risk Extractions - Research

**Researched:** 2026-04-10
**Domain:** Rails service extraction (PORO and ApplicationService patterns)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Follow v1.0 extraction pattern: extract to service class, delegate from model via thin wrapper methods.
- **D-02:** RankingCalculator and PlayerGroupDistributor as POROs — pure algorithm classes with no database writes. TableReservationService as ApplicationService — it orchestrates Google Calendar API calls and has side effects.
- **D-03:** Service files go in `app/services/tournament/` and `app/services/tournament_monitor/` (new directories, following existing `app/services/table_monitor/` pattern).
- **D-04:** Extract `calculate_and_cache_rankings` and `reorder_seedings` methods. The AASM `after_enter` callback on `tournament_seeding_finished` stays on the model — it calls the service.
- **D-05:** The service receives the tournament instance as a parameter (not injected via constructor). Returns the computed rankings hash.
- **D-06:** Extract `create_table_reservation`, `create_google_calendar_event`, `calculate_start_time`, `calculate_end_time`, `fallback_table_count`, `format_table_list`, `build_event_summary`. The public entry point is `create_table_reservation`.
- **D-07:** `required_tables_count` and `available_tables_with_heaters` stay on the model — they are query methods used by views/controllers beyond just calendar reservation.
- **D-08:** Extract `distribute_to_group`, `distribute_with_sizes` class methods and `DIST_RULES`, `GROUP_RULES`, `GROUP_SIZES` constants. The `self.ranking` class method stays on TournamentMonitor.
- **D-09:** TournamentMonitor delegates `distribute_to_group` to `PlayerGroupDistributor.distribute_to_group` with identical signature. TournamentPlan.group_sizes_from also calls this — update that reference too.
- **D-10:** New service unit tests go in `test/services/tournament/` and `test/services/tournament_monitor/`.
- **D-11:** All existing characterization tests from Phases 11-12 MUST pass without modification after extraction.
- **D-12:** Each service gets focused unit tests. The existing characterization tests provide integration-level coverage through the delegation wrappers.

### Claude's Discretion

- Exact method signatures for service constructors/call methods
- Whether to use lazy accessor pattern (like ScoreEngine) or direct instantiation
- Internal organization of service files (constants placement, private helpers)
- Whether `frozen_string_literal: true` goes at top of new files (yes — project convention)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

## Summary

Phase 13 extracts three well-bounded service clusters that have been fully characterized by Phases 11-12 tests. All three extraction targets are self-contained: no circular dependencies on other model methods being extracted, no shared mutable state, and no AASM or CableReady coupling.

The key planning risk is `distribute_to_group` — the CONTEXT.md mentions only two callers (TournamentMonitor model method `group_rank` and `TournamentPlan.group_sizes_from`), but the actual codebase has **seven distinct callers**: one model method, one TournamentPlan method, two controller actions, one helper, and three ERB views. All callers use `TournamentMonitor.distribute_to_group(...)` by class name. The delegation wrapper on TournamentMonitor handles all of them transparently — no caller updates needed beyond TournamentPlan if the delegation is placed on TournamentMonitor itself.

For RankingCalculator, `calculate_and_cache_rankings` is also called directly from `TournamentsController` at lines 112 and 961 (not only via AASM). The delegation wrapper on Tournament handles these transparently.

**Primary recommendation:** Extract in this order — PlayerGroupDistributor first (pure PORO, no DB writes, simplest), RankingCalculator second (PORO with DB write via `save!`, needs tournament instance), TableReservationService last (ApplicationService with external API side effects, most complex to test).

---

## Standard Stack

### Core (already installed — no new gems needed)

| Library | Already Used | Purpose | Why Standard |
|---------|-------------|---------|--------------|
| Rails ApplicationService | `app/services/application_service.rb` | Base class with `.call` pattern | Established project pattern |
| Minitest | `bin/rails test` | Unit tests for extracted services | Project standard (not RSpec) |
| WebMock | `test/test_helper.rb` | Block external HTTP in tests | Already configured project-wide |

**No new gems required.** [VERIFIED: grep of Gemfile and existing service files]

---

## Architecture Patterns

### Actual v1.0 Service Patterns (verified from codebase)

Note: CONTEXT.md references `ScoreEngine` as a PORO example. `score_engine.rb` does not exist — only `game_setup.rb` and `result_recorder.rb` are implemented. Both are ApplicationService subclasses. The "PORO vs ApplicationService" distinction in D-02 is still valid as a design decision, but there is no existing PORO service in `app/services/table_monitor/` to copy from. The pattern described below must be freshly established.

[VERIFIED: `ls app/services/table_monitor/` — only `game_setup.rb` and `result_recorder.rb`]

### Pattern 1: PORO Service (for RankingCalculator and PlayerGroupDistributor)

RankingCalculator and PlayerGroupDistributor are pure algorithm classes. The CONTEXT.md (D-02) mandates PORO pattern — no inheritance from ApplicationService, no `.call` class method. Use module-function style or plain class methods.

**Recommended structure for PlayerGroupDistributor (pure class methods):**

```ruby
# frozen_string_literal: true
# app/services/tournament_monitor/player_group_distributor.rb

class TournamentMonitor::PlayerGroupDistributor
  DIST_RULES = { ... }.freeze
  GROUP_RULES = { ... }.freeze
  GROUP_SIZES = { ... }.freeze

  def self.distribute_to_group(players, ngroups, group_sizes = nil)
    # ... exact body from TournamentMonitor.distribute_to_group
  end

  def self.distribute_with_sizes(players, ngroups, group_sizes)
    # ... exact body from TournamentMonitor.distribute_with_sizes
  end
end
```

**Delegation wrapper on TournamentMonitor:**

```ruby
# In TournamentMonitor (replaces the old class methods)
def self.distribute_to_group(players, ngroups, group_sizes = nil)
  TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups, group_sizes)
end
```

The constants DIST_RULES, GROUP_RULES, GROUP_SIZES move out of TournamentMonitor entirely and live in the new service. No references to these constants were found outside of the two methods being extracted. [VERIFIED: grep for DIST_RULES, GROUP_RULES, GROUP_SIZES in app/]

**RankingCalculator structure (PORO receiving tournament instance):**

```ruby
# frozen_string_literal: true
# app/services/tournament/ranking_calculator.rb

class Tournament::RankingCalculator
  def initialize(tournament)
    @tournament = tournament
  end

  def calculate_and_cache_rankings
    # ... exact body from Tournament#calculate_and_cache_rankings
    # Uses @tournament throughout (replaces `self`)
  end

  def reorder_seedings
    # ... exact body from Tournament#reorder_seedings
  end
end
```

**Delegation wrapper on Tournament:**

```ruby
def calculate_and_cache_rankings
  Tournament::RankingCalculator.new(self).calculate_and_cache_rankings
end

def reorder_seedings
  Tournament::RankingCalculator.new(self).reorder_seedings
end
```

The AASM callback `after_enter: [:calculate_and_cache_rankings]` stays on Tournament and calls the wrapper method — no AASM change needed.

### Pattern 2: ApplicationService (for TableReservationService)

TableReservationService orchestrates external API calls. It follows the same pattern as `TableMonitor::GameSetup` and `TableMonitor::ResultRecorder`.

```ruby
# frozen_string_literal: true
# app/services/tournament/table_reservation_service.rb

class Tournament::TableReservationService < ApplicationService
  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
  end

  # Public entry point — called from Tournament#create_table_reservation delegation wrapper
  def call
    perform_create_table_reservation
  end

  # Additional class-method entry points can be added later if needed
  private

  def perform_create_table_reservation
    # ... exact body of create_table_reservation
    # Calls private methods below
  end

  def create_google_calendar_event(summary, start_time, end_time)
    # ... moved from Tournament private
  end

  def calculate_start_time
    # ... moved from Tournament private
  end

  def calculate_end_time
    # ... moved from Tournament private
  end

  def fallback_table_count(participant_count)
    # ... moved from Tournament private
  end

  def format_table_list(table_names)
    # ... moved from Tournament private
  end

  def build_event_summary(table_string)
    # ... moved from Tournament private
  end
end
```

**Delegation wrapper on Tournament:**

```ruby
def create_table_reservation
  Tournament::TableReservationService.call(tournament: self)
end
```

Note: `required_tables_count` and `available_tables_with_heaters` stay on Tournament (D-07). The service calls them via `@tournament.required_tables_count` and `@tournament.available_tables_with_heaters(limit: ...)`.

### Recommended Project Structure (new directories)

```
app/services/
├── tournament/
│   ├── ranking_calculator.rb       # PORO (TEXT-01)
│   └── table_reservation_service.rb # ApplicationService (TEXT-02)
├── tournament_monitor/
│   └── player_group_distributor.rb  # PORO (TMEX-01)
└── table_monitor/
    ├── game_setup.rb               # Existing
    └── result_recorder.rb          # Existing

test/services/
├── tournament/
│   ├── ranking_calculator_test.rb
│   └── table_reservation_service_test.rb
├── tournament_monitor/
│   └── player_group_distributor_test.rb
└── table_monitor/
    ├── game_setup_test.rb          # Existing
    └── result_recorder_test.rb     # Existing
```

### Anti-Patterns to Avoid

- **Moving `required_tables_count` or `available_tables_with_heaters` to the service:** These are AR query methods called from views and controllers independently of the reservation flow. Keep on model.
- **Removing the delegation wrapper from TournamentMonitor:** All seven callers (`group_rank` method, `TournamentPlan.group_sizes_from`, two controller actions, one helper, three ERB views) use `TournamentMonitor.distribute_to_group`. The delegation wrapper is the only safe change.
- **Updating TournamentPlan.group_sizes_from to call the service directly (bypassing delegation):** The CONTEXT.md (D-09) says to "update that reference too." However, since the delegation wrapper preserves the existing call site, updating TournamentPlan is optional — the wrapper will forward correctly. If the update is made, it changes `TournamentMonitor.distribute_to_group` to `TournamentMonitor::PlayerGroupDistributor.distribute_to_group` in one place.
- **Changing method signatures:** All extracted methods must accept exactly the same parameters as their originals. The AASM callback, characterization tests, and all callers depend on the current signatures.
- **Instantiating RankingCalculator with a lazy accessor pattern:** D-05 says the service receives tournament as a parameter. Direct instantiation `Tournament::RankingCalculator.new(self)` in the delegation wrapper is the prescribed approach.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Google Calendar API auth | Custom OAuth flow | `GoogleCalendarService.calendar_service` | Already implemented, already tested |
| Constants lookup tables | Re-implement DIST_RULES/GROUP_RULES/GROUP_SIZES | Move them verbatim to the service | They are exact, tested lookup tables |
| Test isolation for Google API | Real HTTP calls | WebMock (already configured) + stub pattern from `tournament_calendar_test.rb` | WebMock blocks all HTTP project-wide; Google API calls must be stubbed exactly as in existing tests |

---

## Complete Caller Map

### `calculate_and_cache_rankings` callers [VERIFIED: grep app/]

| Caller | Location | After extraction |
|--------|----------|-----------------|
| AASM `after_enter` callback | `tournament.rb:274` | Stays — calls Tournament#calculate_and_cache_rankings delegation wrapper |
| TournamentsController | `tournaments_controller.rb:112` | Stays — calls delegation wrapper transparently |
| TournamentsController | `tournaments_controller.rb:961` | Stays — calls delegation wrapper transparently |

### `reorder_seedings` callers [VERIFIED: grep app/]

| Caller | Location | After extraction |
|--------|----------|-----------------|
| Commented-out code only | `tournament.rb:870` | No active callers — wrapper still needed as the method is public |

### `create_table_reservation` callers [VERIFIED: grep app/ and lib/]

| Caller | Location | After extraction |
|--------|----------|-----------------|
| TournamentsController (implicit) | Referenced in `carambus.rake:1099` | Calls delegation wrapper transparently |
| `tournament_calendar_test.rb` | Direct test of model method | Calls delegation wrapper transparently |

### `distribute_to_group` callers [VERIFIED: grep app/]

| Caller | Location | After extraction |
|--------|----------|-----------------|
| `TournamentMonitor#group_rank` | `tournament_monitor.rb:390` | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `TournamentPlan.group_sizes_from` | `tournament_plan.rb:393` | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `TournamentsController#define_participants` | `tournaments_controller.rb:199` | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `TournamentsController#finalize_modus` | `tournaments_controller.rb:527` | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `TournamentsHelper` | `tournaments_helper.rb:40` | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `finalize_modus.html.erb` (line 190) | ERB view | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `finalize_modus.html.erb` (line 216) | ERB view | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `tournament_monitor.html.erb` (line 126) | ERB view | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `define_participants.html.erb` (lines 321, 360) | ERB view | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |
| `show.html.erb` (line 109) | ERB view | Calls `TournamentMonitor.distribute_to_group` — delegation wrapper handles |

**Key insight:** The delegation wrapper on TournamentMonitor makes all caller updates transparent. Only TournamentPlan.group_sizes_from is mentioned in D-09 as a candidate for a direct reference update, but even that is optional if the delegation wrapper is in place.

---

## Method Signatures (exact, from source)

### RankingCalculator targets

```ruby
# Source: app/models/tournament.rb:886
def calculate_and_cache_rankings
  # No parameters. Reads: organizer, discipline, id, Season, PlayerRanking, seedings.
  # Writes: data['player_rankings'] via save! on self
  # Returns: nil (implicit)

# Source: app/models/tournament.rb:934
def reorder_seedings
  # No parameters. Reads: seeding_ids.
  # Writes: Seeding.update_columns, then reload
  # Returns: nil (implicit)
```

After extraction, these are instance methods on `Tournament::RankingCalculator` using `@tournament` instead of `self`. The delegation wrappers on Tournament are zero-arg instance methods calling `Tournament::RankingCalculator.new(self).calculate_and_cache_rankings`.

### TableReservationService targets

```ruby
# Source: app/models/tournament.rb:1035 (public)
def create_table_reservation
  # No parameters. Reads: location, discipline, date, required_tables_count,
  # available_tables_with_heaters. Calls: format_table_list, build_event_summary,
  # calculate_start_time, calculate_end_time, create_google_calendar_event
  # Returns: Google API response or nil

# Source: app/models/tournament.rb:1746 (private)
def create_google_calendar_event(summary, start_time, end_time)
  # Reads: Rails credentials. Calls GoogleCalendarService.calendar_service/.calendar_id
  # Returns: API response or nil on error

# Source: app/models/tournament.rb:1709 (private)
def calculate_start_time
  # Reads: date, tournament_cc. Returns: ISO8601 UTC string

# Source: app/models/tournament.rb:1732 (private)
def calculate_end_time
  # Reads: date. Returns: ISO8601 UTC string (always 20:00 UTC)

# Source: app/models/tournament.rb:1659 (private)
def fallback_table_count(participant_count)
  # Pure math. Returns: Integer

# Source: app/models/tournament.rb:1665 (private)
def format_table_list(table_names)
  # Pure string formatting. Returns: String

# Source: app/models/tournament.rb:1684 (private)
def build_event_summary(table_string)
  # Reads: shortname, title, discipline, player_class on tournament. Returns: String
```

After extraction, the service receives `@tournament` via constructor. The private helper methods become private instance methods using `@tournament.shortname` etc. instead of bare `shortname`.

### PlayerGroupDistributor targets

```ruby
# Source: app/models/tournament_monitor.rb:211 (class method)
def self.distribute_to_group(players, ngroups, group_sizes = nil)
  # Calls: distribute_with_sizes. References: GROUP_SIZES.
  # Returns: Hash or {} on error

# Source: app/models/tournament_monitor.rb:269 (class method)
def self.distribute_with_sizes(players, ngroups, group_sizes)
  # References: GROUP_SIZES, GROUP_RULES.
  # Returns: Hash
```

After extraction, these become class methods on `TournamentMonitor::PlayerGroupDistributor`. The error-rescue in `distribute_to_group` logs to `Tournament.logger` — this stays unchanged (same logger reference, still accessible).

---

## Common Pitfalls

### Pitfall 1: `self` reference inside extracted methods

**What goes wrong:** Methods that call `self.something` or use bare method names (e.g., `discipline`, `shortname`, `date`) need to be rewritten to `@tournament.discipline` etc. in the service. Missing any one reference causes a NoMethodError at runtime.

**Prevention:** For each extracted method, enumerate every bare method call and attribute reference. For Tournament::RankingCalculator: `organizer`, `discipline`, `discipline_id`, `id`, `data`, `data_will_change!`, `save!`, `seedings`, `seeding_ids`, `reload`. For TableReservationService: `location`, `discipline`, `discipline_id`, `date`, `tournament_cc`, `shortname`, `title`, `player_class`, `required_tables_count`, `available_tables_with_heaters`, `id`.

**Warning signs:** `NoMethodError: undefined method 'organizer' for #<Tournament::RankingCalculator>` in tests.

### Pitfall 2: `Tournament.logger` reference in `distribute_to_group`

**What goes wrong:** The rescue block in `distribute_to_group` calls `Tournament.logger.info(...)`. This works fine after extraction because the Tournament model is still loaded, but if this is inadvertent coupling, it could confuse future readers.

**Prevention:** Leave the reference as-is for now (behavior-preserving extraction). The characterization tests don't test the rescue branch. Document the coupling in the service file's comment.

### Pitfall 3: Missing delegation wrapper means seven callers break

**What goes wrong:** If the `TournamentMonitor.distribute_to_group` class method is removed rather than replaced with a delegation wrapper, all seven callers (controllers, helpers, views) raise `NoMethodError`.

**Prevention:** The delegation wrapper MUST be added to TournamentMonitor before removing the original implementation.

### Pitfall 4: Characterization tests call model methods, not service methods

**What goes wrong:** `tournament_calendar_test.rb` calls `@tournament.create_table_reservation`. If the delegation wrapper is missing, or if the service raises an unexpected error, the characterization test fails.

**Prevention:** The delegation wrapper must delegate correctly. Run the characterization tests immediately after each extraction before moving to the next.

### Pitfall 5: `GoogleCalendarService` stub setup in new service tests

**What goes wrong:** Tests for `Tournament::TableReservationService` need to stub `GoogleCalendarService.calendar_service` and Rails credentials. If not stubbed correctly, WebMock will block the HTTP attempt and raise an error.

**Prevention:** Copy the exact stub pattern from `test/models/tournament_calendar_test.rb` lines 167-194. The credentials stub is `Rails.application.credentials.stub(:dig, ->(*args) { args == [:google_service, :private_key] ? "fake-key" : nil }) do ... end`.

### Pitfall 6: `calculate_and_cache_rankings` has a `data_will_change!` call

**What goes wrong:** ActiveRecord dirty tracking `data_will_change!` must be called on the tournament instance. In the service, this becomes `@tournament.data_will_change!` — easy to miss when converting `self` references.

**Prevention:** Include `data_will_change!` in the list of self-references to rewrite.

---

## Code Examples

### Delegation wrapper pattern (from existing GameSetup)

```ruby
# Source: app/models/table_monitor.rb (delegate to GameSetup)
def start_game(options = {})
  TableMonitor::GameSetup.call(table_monitor: self, options: options)
end
```

Apply same pattern for Tournament delegation:

```ruby
# In Tournament model (replaces original method body)
def create_table_reservation
  Tournament::TableReservationService.call(tournament: self)
end
```

### PORO class method pattern (no ApplicationService inheritance)

```ruby
# frozen_string_literal: true

class Tournament::RankingCalculator
  def initialize(tournament)
    @tournament = tournament
  end

  def calculate_and_cache_rankings
    return unless @tournament.organizer.is_a?(Region) && @tournament.discipline.present?
    return unless @tournament.id.present? && @tournament.id >= Tournament::MIN_ID
    # ... rest of implementation
    @tournament.data_will_change!
    @tournament.data["player_rankings"] = player_rank
    @tournament.save!
  end

  def reorder_seedings
    l_seeding_ids = @tournament.seeding_ids
    l_seeding_ids.each_with_index do |seeding_id, ix|
      Seeding.find_by_id(seeding_id).update_columns(position: ix + 1)
    end
    @tournament.reload
  end
end
```

### Service test pattern (from game_setup_test.rb)

```ruby
# frozen_string_literal: true

require "test_helper"

class Tournament::RankingCalculatorTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  setup do
    @tournament = Tournament.create!(
      id: 50_200_001,
      title: "Ranking Test",
      season: seasons(:current),
      organizer: regions(:nbv),
      organizer_type: "Region",
      discipline: disciplines(:carom_3band),
      date: 2.weeks.from_now
    )
  end

  test "calculate_and_cache_rankings returns early when no discipline" do
    @tournament.discipline = nil
    calculator = Tournament::RankingCalculator.new(@tournament)
    result = calculator.calculate_and_cache_rankings
    assert_nil result
  end
end
```

---

## State of the Art

| Old Approach | Current Approach | Context |
|--------------|------------------|---------|
| Fat model methods (1775 lines) | Service extraction with delegation wrappers | This phase |
| ScoreEngine PORO (cited in CONTEXT.md) | Only ApplicationService subclasses exist | ScoreEngine does not exist in codebase — PORO pattern must be established fresh |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | ScoreEngine is cited in CONTEXT.md as a reference PORO pattern but does not exist in the codebase | Architecture Patterns | LOW — the decision to use PORO is locked (D-02), the pattern just needs to be established fresh rather than copied |
| A2 | TournamentPlan.group_sizes_from update (D-09) is optional if delegation wrapper is in place | Caller Map | LOW — both approaches work; making TournamentPlan call the distributor directly is cleaner but not required |

**Most claims in this research were verified directly from the codebase.**

---

## Open Questions

1. **Should `distribute_to_group` stay as a class method or become an instance method on the distributor?**
   - What we know: All callers use `TournamentMonitor.distribute_to_group(...)` — a class method call.
   - The delegation wrapper must be a class method: `def self.distribute_to_group(...)`.
   - Recommendation: Keep as class methods on the service (`def self.distribute_to_group`) to match the delegation pattern.

2. **Does the `distribute_to_group` error rescue need to log to `Tournament.logger` or can it use `Rails.logger`?**
   - What we know: Current code uses `Tournament.logger.info(...)` in the rescue block. This is defined as a custom logger on the Tournament model. This is a cross-domain coupling (TournamentMonitor using Tournament's logger).
   - Recommendation: Keep the `Tournament.logger` reference verbatim for behavior preservation. Note it in a TODO comment.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely code changes (model refactoring + new service files). No external tools, CLI utilities, or new services are required beyond what is already running.

---

## Validation Architecture

`nyquist_validation` is `false` in `.planning/config.json`. This section is omitted per config.

---

## Security Domain

No new external interfaces, authentication flows, or data handling changes. All extracted methods handle the same data with the same access patterns. Security posture unchanged — omitted.

---

## Sources

### Primary (HIGH confidence)

- `app/models/tournament.rb` (lines 274, 886-941, 1035-1057, 1657-1774) — VERIFIED by direct read
- `app/models/tournament_monitor.rb` (lines 135-327) — VERIFIED by direct read
- `app/models/tournament_plan.rb` (lines 389-404) — VERIFIED by direct read
- `app/services/table_monitor/game_setup.rb` — VERIFIED by direct read (ApplicationService pattern)
- `app/services/table_monitor/result_recorder.rb` — VERIFIED by direct read
- `app/services/application_service.rb` — VERIFIED by direct read
- `app/services/google_calendar_service.rb` — VERIFIED by direct read
- `test/models/tournament_calendar_test.rb` — VERIFIED by direct read (stub pattern for Google API)
- `test/services/table_monitor/game_setup_test.rb` — VERIFIED by direct read (test pattern)
- Grep for `distribute_to_group` across all of `app/` — VERIFIED: 11 unique call sites identified
- Grep for `calculate_and_cache_rankings` across `app/` — VERIFIED: 3 call sites in tournament.rb and tournaments_controller.rb
- `.planning/config.json` — VERIFIED: `nyquist_validation: false`

---

## Metadata

**Confidence breakdown:**
- Extraction boundaries: HIGH — read from source files directly
- Caller maps: HIGH — verified by grep across full app/ directory
- Service class design: HIGH — follows exact patterns from existing GameSetup and ResultRecorder
- Test patterns: HIGH — copied from existing game_setup_test.rb and tournament_calendar_test.rb
- ScoreEngine non-existence: HIGH — verified by directory listing

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable codebase, no external moving parts)
