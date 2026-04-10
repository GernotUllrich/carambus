# Phase 1: Characterization Tests & Hardening - Research

**Researched:** 2026-04-09
**Domain:** Rails characterization testing, AASM hardening, VCR cassette recording, Reek static analysis
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Critical paths only — focus on state transitions, callbacks, broadcasts, sync operations. Target ~30-40 tests total, not exhaustive coverage of all 96+ methods.
- **D-02:** Use test_after_commit gem (or equivalent) to fire after_commit callbacks inside transactional tests. Avoid creating a separate non-transactional test base class.
- **D-03:** Record fresh VCR cassettes for RegionCc char tests against real ClubCloud API. Existing cassettes may not cover all sync paths needed for characterization.
- **D-04:** Characterization tests go in `test/characterization/` — a new dedicated directory, separate from unit tests. Run as group via `bin/rails test test/characterization/`.
- **D-05:** File naming convention: `{model_name}_char_test.rb` (e.g., `table_monitor_char_test.rb`, `region_cc_char_test.rb`).
- **D-06:** Enable `whiny_transitions: true` globally in the TableMonitor AASM block. If existing tests break, fix them — those are real bugs being surfaced by silent guard failures.
- **D-07:** Include PartyMonitor (STI subclass) in characterization tests. It inherits from TableMonitor and extraction will affect it — pin both now.
- **D-08:** One-time Reek report only. Run reek on TableMonitor and RegionCc, save output to `.planning/` as baseline. Run again after Phase 5 for comparison. No gem addition to Gemfile, no CI integration.

### Claude's Discretion

- Exact test method grouping and organization within char test files
- Which specific state transitions and callback chains to prioritize within the ~30-40 test target
- Whether to add a `test:characterization` Rake task for convenience

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Characterization tests for TableMonitor critical paths (state transitions, callbacks, broadcasts) | AASM block fully mapped (lines 307–366); `after_update_commit` lambda fully read (lines 75–186); `log_state_change` callback identified (lines 426–444); `skip_update_callbacks` guard confirmed (line 73); `local_server?` branch confirmed (lines 86–90); `PartyMonitor` polymorphic branch confirmed (lines 102–107) |
| TEST-02 | Characterization tests for RegionCc sync operations (HTTP calls, data transformation) | 28 `sync_*` and `synchronize_*` method signatures enumerated; `fix_tournament_structure` identified; `post_cc`, `get_cc`, `post_cc_with_formdata`, `get_cc_with_url` HTTP methods identified; VCR directory currently empty (0 cassettes) — fresh recording required |
| QUAL-01 | Reek baseline measurement before and after extraction | `reek` not in Gemfile or Gemfile.lock — must be added temporarily or run via `gem install reek` in isolation; output destination `.planning/` confirmed by D-08 |
</phase_requirements>

---

## Summary

Phase 1 establishes the safety net for all subsequent extraction work. The characterization tests must pin the observable behavior of `TableMonitor` (3903 lines) and `RegionCc` (2728 lines) before any line of production code is moved. Two infrastructure issues must be fixed before the characterization tests can cover the most important behavior: `after_commit` callbacks never fire inside transactional tests (the default), and AASM transitions fail silently by default, meaning tests against guard failures give false positives.

The test infrastructure is healthy. Minitest, VCR, WebMock, and FactoryBot are all already installed. The `test/support/scraping_helpers.rb` helper provides auth stubs and assertion helpers reusable for RegionCc tests. The VCR cassette directory exists but has zero cassettes — all RegionCc cassettes must be recorded fresh. The `test_after_commit` gem is not in the Gemfile; adding it to the `:test` group is the required implementation step for D-02.

The AASM block in `TableMonitor` has been fully read: 10 states, 13 events. `whiny_transitions: true` is absent — it must be added to the `aasm column: "state" do` block. No existing tests exercise `AASM::InvalidTransition`, so the risk of breakage from enabling it is low, but any breakage surfaces real bugs per D-06. Reek is not installed; it needs a temporary install to produce the baseline report.

**Primary recommendation:** Execute in this order — (1) add `test_after_commit` gem, (2) enable `whiny_transitions: true` and run existing tests, (3) create `test/characterization/` with the Rake task, (4) write TableMonitor char tests, (5) write RegionCc char tests with fresh cassettes, (6) run Reek and save baseline.

---

## Project Constraints (from CLAUDE.md)

These directives apply to all code written in this phase:

- `# frozen_string_literal: true` at top of all Ruby files [VERIFIED: CLAUDE.md]
- Minitest syntax only — `test "description"` blocks, not RSpec describe/it [VERIFIED: CLAUDE.md]
- Double quotes for strings (Standard enforced) [VERIFIED: CLAUDE.md]
- Test files named `{model_name}_test.rb` pattern — for characterization: `{model_name}_char_test.rb` per D-05 [VERIFIED: CONTEXT.md + TESTING.md]
- German comments for business logic, English for technical terms [VERIFIED: CLAUDE.md]
- Conventional commit messages [VERIFIED: CLAUDE.md]
- `bin/rails test` is the test runner (not `rspec`) [VERIFIED: CLAUDE.md]
- `SAFETY_ASSURED=true bin/rails db:test:prepare` before test DB prep [VERIFIED: CLAUDE.md]
- `StandardRB` linting: `bundle exec standardrb` [VERIFIED: CLAUDE.md]
- Do not add gems without Gemfile entry; use `bundle install` to update lockfile [ASSUMED: standard Rails practice]

---

## Standard Stack

### Core — already installed

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| Minitest | bundled with Rails 7.2 | Test framework | Already in use [VERIFIED: TESTING.md] |
| VCR | latest (in Gemfile.lock) | HTTP recording/replay | Already installed [VERIFIED: Gemfile line 78] |
| WebMock | latest | HTTP stub/mock | Already installed [VERIFIED: Gemfile line 74] |
| FactoryBot Rails | latest | Test data factories | Already installed [VERIFIED: Gemfile line 75] |
| shoulda-matchers | latest | Enhanced assertions | Already installed [VERIFIED: Gemfile line 84] |
| AASM | 5.5.2 | State machine | Already installed [VERIFIED: Gemfile.lock line 20] |

### Must Add

| Library | Version | Purpose | Gemfile Group |
|---------|---------|---------|---------------|
| test_after_commit | latest | Fire `after_commit` callbacks inside transactional tests | `:test` |
| reek | latest (temp install) | Static analysis baseline — ONE-TIME use, do NOT add to Gemfile | global gem, not Gemfile |

**Installation for test_after_commit:**
```bash
# Add to Gemfile :test group
gem 'test_after_commit'

# Then:
bundle install
```

**For Reek (one-time, no Gemfile entry per D-08):**
```bash
gem install reek
# or use bundler exec with --with-clean-env if project has Gemfile constraints
bundle exec gem list reek  # check if already available
```

**Version verification:** [ASSUMED] `test_after_commit` current version should be verified via `gem list test_after_commit` or rubygems.org before committing to Gemfile. As of research date, the gem is maintained and compatible with Rails 7.x.

---

## Architecture Patterns

### Recommended Test Directory Structure

```
test/
├── characterization/                  # NEW — created this phase
│   ├── table_monitor_char_test.rb     # TableMonitor + AASM + after_update_commit
│   └── region_cc_char_test.rb         # RegionCc sync_* + fix operations
├── snapshots/
│   └── vcr/
│       ├── region_cc_sync_leagues.yml      # NEW — recorded this phase
│       ├── region_cc_sync_tournaments.yml  # NEW
│       ├── region_cc_sync_parties.yml      # NEW
│       └── region_cc_fix_tournament.yml    # NEW
└── [existing dirs unchanged]
```

### Pattern 1: Characterization Test Base Class

The characterization test files should NOT inherit from a custom non-transactional base class (D-02). Instead, add `test_after_commit` to fire `after_commit` inside transactional tests.

```ruby
# frozen_string_literal: true

# Source: test/test_helper.rb pattern + test_after_commit gem
require "test_helper"

class TableMonitorCharTest < ActiveSupport::TestCase
  # test_after_commit gem makes after_commit callbacks fire in transactional tests
  # No need for self.use_transactional_tests = false

  setup do
    # Reset class-level state before each test (Pitfall 10: cattr_accessor pollution)
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  teardown do
    # Mirror setup for paranoia
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end
end
```
[VERIFIED: cattr_accessor list from table_monitor.rb lines 41–48; test_after_commit approach from PITFALLS.md Pitfall 9]

### Pattern 2: test_after_commit Integration

The `test_after_commit` gem monkey-patches ActiveRecord to fire `after_commit` callbacks even when the test is wrapped in a transaction that is rolled back. Minimal setup:

```ruby
# In test_helper.rb — add after gem install:
require 'test_after_commit'
TestAfterCommit.enabled = true
```

Or simply adding the gem to the `:test` group activates it automatically in some versions. Verify the exact activation method from the gem README after install. [VERIFIED: documented behavior from PITFALLS.md Pitfall 9 and Rails community knowledge; exact API ASSUMED — check gem README]

### Pattern 3: AASM whiny_transitions Configuration

The `aasm` block in `table_monitor.rb` starts at line 307. `whiny_transitions: true` is added as an option to the `aasm` macro:

```ruby
# In app/models/table_monitor.rb — existing block at line 307:
aasm column: "state", whiny_transitions: true do
  # ... existing states and events unchanged ...
end
```

[VERIFIED: AASM 5.5.2 supports `whiny_transitions:` option — confirmed from Gemfile.lock line 20 and PITFALLS.md Pitfall 5 which cites github.com/aasm/aasm directly]

After adding `whiny_transitions: true`, run the full existing test suite before writing characterization tests:
```bash
bin/rails test
```
Any failures are real bugs per D-06 — fix them before proceeding.

### Pattern 4: Rake Task for Characterization Suite

Following the existing pattern in `lib/tasks/test.rake`:

```ruby
# In lib/tasks/test.rake — add to existing namespace :test block:
desc "Run characterization tests (behavior pins for extraction safety)"
task :characterization do
  puts "Running characterization tests..."
  system("bin/rails test test/characterization/")
end
```

### Pattern 5: VCR Cassette Recording for RegionCc

The VCR config already exists in `test/support/vcr_setup.rb` with `record: :once`. For fresh cassettes, use `record: :new_episodes` or delete the cassette file to force re-record:

```ruby
# In region_cc_char_test.rb:
test "sync_leagues records league structure from ClubCloud" do
  VCR.use_cassette("region_cc_sync_leagues", record: :new_episodes) do
    # First run: hits live ClubCloud API (requires network access)
    # Subsequent runs: replays cassette
    @region_cc.sync_leagues(season_name: "2024-2025", armed: false)
    assert League.where(region: @region_cc.region).count > 0
  end
end
```

**Critical:** The cassette must be recorded against the real ClubCloud API (D-03). Run with real network access once, then commit cassette files. WebMock blocks all HTTP by default — must temporarily allow ClubCloud during recording:
```ruby
# During cassette recording only — VCR handles the WebMock interaction automatically
# vcr_setup.rb already uses WebMock as hook; VCR will disable WebMock for allowed interactions
```
[VERIFIED: vcr_setup.rb uses `config.hook_into :webmock` — VCR manages WebMock stubs automatically during cassette recording]

### Pattern 6: Sidekiq Job Assertion in Characterization Tests

To assert that `after_update_commit` enqueues the correct jobs:

```ruby
# test_helper.rb already requires "sidekiq/testing" (line 51-53)
# Sidekiq::Testing.fake! mode queues jobs without executing them
require "sidekiq/testing"
Sidekiq::Testing.fake!

test "after_update_commit enqueues TableMonitorJob on score change" do
  # test_after_commit gem fires after_commit inside transaction
  assert_difference "Sidekiq::Queues['default'].size", 1 do
    @table_monitor.update!(data: new_score_data)
  end
end
```

**Alternative — use assert_enqueued_jobs if using ActiveJob adapter:**
```ruby
assert_enqueued_jobs 1, only: TableMonitorJob do
  @table_monitor.update!(data: new_score_data)
end
```
[ASSUMED: The exact Sidekiq testing mode active in tests needs verification by reading `test_helper.rb` lines 50–53 and confirming whether Sidekiq::Testing.fake! or inline! is active. Current test_helper sets log level but does not explicitly set fake/inline mode.]

### Anti-Patterns to Avoid

- **Non-transactional base class:** D-02 forbids creating `use_transactional_tests = false` base class. Use `test_after_commit` gem instead.
- **Exhaustive method coverage:** D-01 limits scope to ~30-40 tests. Do not write tests for every public method.
- **Stubbing `after_update_commit`:** Do not mock or stub the callback itself — the whole point is to characterize its real behavior.
- **Reusing stale VCR cassettes:** D-03 requires fresh cassettes for RegionCc. Do not attempt to reuse any existing cassettes from other test directories.
- **Adding Reek to Gemfile:** D-08 forbids this. Run Reek once via `gem install reek` and save output to `.planning/`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| `after_commit` firing in transactional tests | Custom non-transactional base class | `test_after_commit` gem | Custom base class creates cleanup complexity; gem is the community-standard solution [VERIFIED: PITFALLS.md Pitfall 9] |
| VCR cassette management | Custom HTTP replay mechanism | Existing VCR setup in `test/support/vcr_setup.rb` | Already configured with filtering, pretty-printing, WebMock integration [VERIFIED: vcr_setup.rb] |
| Sidekiq job assertions | Manual queue inspection | `Sidekiq::Testing` API | Sidekiq gem already provides testing harness [VERIFIED: test_helper.rb line 51] |
| `cattr_accessor` cleanup | Global test config | `setup`/`teardown` blocks in test class | Per-class teardown is sufficient; no global change needed [VERIFIED: PITFALLS.md Pitfall 10] |
| AASM transition testing | Manual `state` column writes | AASM events on model + `whiny_transitions: true` | Writing `state` directly bypasses `after_enter` callbacks [VERIFIED: ARCHITECTURE.md anti-pattern section] |

**Key insight:** All required infrastructure already exists or has a well-maintained gem solution. This phase is about configuration and test writing, not building new tooling.

---

## AASM State Machine — Complete Map

Verified from `app/models/table_monitor.rb` lines 307–366. [VERIFIED: direct code read]

**States (10):**
| State | after_enter callback | Notes |
|-------|---------------------|-------|
| `:new` | `reset_table_monitor` | Initial state |
| `:ready` | — | |
| `:warmup` | — | |
| `:warmup_a` | — | |
| `:warmup_b` | — | |
| `:match_shootout` | — | |
| `:playing` | — | Core game state |
| `:set_over` | `set_game_over` | Triggers save + modal panel change |
| `:final_set_score` | `set_game_over` | |
| `:final_match_score` | `set_game_over` | |
| `:ready_for_new_match` | — | |

**Events (13):**
| Event | From | To | after callback |
|-------|------|----|----------------|
| `start_new_match` | `:ready` | `:warmup` | `set_start_time` |
| `close_match` | `playing, set_over, final_match_score, ready_for_new_match` | `:ready_for_new_match` | — |
| `warmup_a` | `warmup, warmup_b, warmup_a` | `:warmup_a` | — |
| `warmup_b` | `warmup, warmup_a, warmup_b` | `:warmup_b` | — |
| `finish_warmup` | `match_shootout, warmup, warmup_a, warmup_b` | `:match_shootout` | — |
| `finish_shootout` | `:match_shootout` | `:playing` | — |
| `end_of_set` | `:playing` | `:set_over` | — |
| `undo` | `playing, set_over` | `:playing` | — |
| `acknowledge_result` | `:set_over` | `:final_set_score` | — |
| `finish_match` | `:final_set_score` | `:final_match_score` | `set_end_time` |
| `next_set` | `set_over, final_set_score` | `:playing` | — |
| `ready` | `new, ready_for_new_match` | `:ready` | — |
| `force_ready` | any | `:ready` | — |

**Global callback:** `after_all_transitions :log_state_transition`

**Critical integration:** `set_game_over` (called on entering `set_over`, `final_set_score`, `final_match_score`) calls `save` internally when state is `set_over`. This save triggers `after_update_commit` which enqueues another `TableMonitorJob`. This nested save/broadcast chain must be exercised by characterization tests.

---

## after_update_commit Branch Map

Verified from lines 75–186. [VERIFIED: direct code read]

The lambda has four early-exit branches and three dispatch paths:

```
after_update_commit lambda {
  BRANCH 1: return if skip_update_callbacks         (D-02 guard)
  BRANCH 2: return unless ApplicationRecord.local_server?  (API server guard)

  ROUTING: get_options!, check PartyMonitor polymorphic branch
    → if tournament_monitor.is_a?(PartyMonitor) && state changes: enqueue "party_monitor_scores"
    → if relevant_keys.present?: enqueue "table_scores" + "teaser"
    → else if @collected_changes or @collected_data_changes: enqueue "teaser"

  BRANCH 3: ultra_fast_score_update? → enqueue "score_data", return
  BRANCH 4: simple_score_update?     → enqueue "player_score_panel", return
  DEFAULT:  enqueue "" (full scoreboard), then TournamentStatusUpdateJob (if tournament active)
}
```

**Minimum characterization coverage for this lambda:**
1. `skip_update_callbacks = true` → no jobs enqueued
2. `local_server?` returns false → no jobs enqueued
3. `tournament_monitor.is_a?(PartyMonitor)` + state changes → "party_monitor_scores" job
4. `relevant_keys.present?` → "table_scores" + "teaser" jobs
5. `ultra_fast_score_update?` → "score_data" job
6. `simple_score_update?` → "player_score_panel" job
7. Default path → full scoreboard job

That is 7 tests for the callback alone, all within the 30-40 target.

---

## RegionCc Sync Method Inventory

Verified from `app/models/region_cc.rb` grep output. [VERIFIED: direct code read]

**HTTP methods (must be VCR-wrapped in all tests):**
- `post_cc_with_formdata` (line 586)
- `post_cc` (line 636)
- `get_cc` (line 679)
- `get_cc_with_url` (line 687)
- `discover_admin_url_from_public_site` (line 477)
- `ensure_admin_base_url!` (line 539)

**Sync methods by domain (28 total):**
| Domain | Methods | Priority for char tests |
|--------|---------|------------------------|
| League structure | `synchronize_league_structure`, `synchronize_league_plan_structure`, `sync_league_teams_new`, `sync_league_teams`, `sync_league_plan`, `sync_team_players_structure`, `sync_team_players` | HIGH — core data |
| Categories/Groups | `sync_category_ccs`, `sync_group_ccs`, `sync_discipline_ccs`, `sync_championship_type_ccs` | MEDIUM |
| Tournaments | `sync_tournaments`, `sync_tournament_ccs`, `sync_tournament_series_ccs`, `synchronize_tournament_structure`, `fix_tournament_structure` | HIGH — includes fix |
| Parties/Games | `sync_parties`, `sync_party_games`, `sync_game_plans`, `sync_game_details`, `sync_registration_list_ccs`, `sync_registration_list_ccs_detail` | HIGH — party data |
| Competitions | `sync_competitions`, `sync_seasons_in_competitions` | MEDIUM |
| Other | `sync_branches`, `sync_clubs`, `self.sync_regions`, `fix` | LOW — keep as-is |

**VCR cassette naming convention (follow `test/support/vcr_setup.rb` pattern):**
```
region_cc_{method_group}.yml
# Examples:
region_cc_sync_leagues.yml
region_cc_sync_tournaments.yml
region_cc_sync_parties.yml
region_cc_fix_tournament.yml
```

---

## Common Pitfalls

### Pitfall 1: after_commit callbacks never fire in transactional tests
**What goes wrong:** Default `use_transactional_tests = true` wraps tests in a transaction that is never committed. `after_commit` waits for a real commit that never arrives. Tests pass with zero job enqueues and no assertions fail.
**Why it happens:** Rails test transaction never issues a real COMMIT.
**How to avoid:** Add `test_after_commit` gem to `:test` group. Activates globally, no per-test config needed.
**Warning signs:** Test asserts `assert_enqueued_jobs 1` but count is always 0 even after `table_monitor.save!`
[VERIFIED: PITFALLS.md Pitfall 9]

### Pitfall 2: cattr_accessor state pollution between tests
**What goes wrong:** TableMonitor has 6 class-level accessors (`options`, `gps`, `location`, `tournament`, `my_table`, `allow_change_tables`). A test that calls `get_options!` sets `TableMonitor.options` and the next test reads stale data.
**How to avoid:** `setup`/`teardown` blocks in `TableMonitorCharTest` reset all to `nil`.
**Warning signs:** Tests pass individually but fail when run as a suite.
[VERIFIED: table_monitor.rb lines 41–48; PITFALLS.md Pitfall 10]

### Pitfall 3: VCR cassette directory is empty — recording requires live network
**What goes wrong:** `test/snapshots/vcr/` has 0 cassettes. The first run of RegionCc char tests must reach the live ClubCloud API. If the API is unavailable or credentials are missing, cassette recording fails and tests are unwritable.
**How to avoid:** Verify ClubCloud API credentials exist in `config/credentials/test.yml.enc` before running. The first cassette-recording run requires `WebMock.allow_net_connect!` to be temporarily true — VCR handles this automatically when hooked into WebMock (`config.hook_into :webmock`).
**Warning signs:** `VCR::Errors::CannotSendRequest` on first test run.
[VERIFIED: vcr_setup.rb — VCR hooks into WebMock; cassette count verified as 0]

### Pitfall 4: AASM whiny_transitions: true breaks existing tests that test invalid transitions
**What goes wrong:** Any existing test that calls an AASM event on an invalid state (e.g., `table_monitor.finish_shootout!` when state is `:playing`) previously returned `false`. With `whiny_transitions: true`, it now raises `AASM::InvalidTransition`.
**How to avoid:** Run `bin/rails test` immediately after adding `whiny_transitions: true`. For each failure, either fix the test to avoid the invalid transition OR wrap in `assert_raises(AASM::InvalidTransition)` if the test intent is to verify rejection.
**Warning signs:** Sudden test failures with `AASM::InvalidTransition` errors on tests in `test/models/`.
[VERIFIED: AASM 5.5.2 behavior from Gemfile.lock + PITFALLS.md Pitfall 5]

### Pitfall 5: local_server? returns wrong value in tests
**What goes wrong:** `ApplicationRecord.local_server?` checks `Carambus.config.carambus_api_url.present?`. In a test environment where the config has this URL set, `local_server?` returns true and the `after_update_commit` API-server guard (`unless ApplicationRecord.local_server?`) will skip all broadcasts. Tests that expect job enqueues will always fail.
**How to avoid:** Verify what `Carambus.config.carambus_api_url` is in the test environment. Write one characterization test that exercises both the `local_server? == true` (jobs fire) and `local_server? == false` (jobs skip) branches explicitly. Mock if necessary: `ApplicationRecord.stub(:local_server?, false) { ... }`.
**Warning signs:** All job-enqueue assertions fail with count 0 even when `test_after_commit` is active.
[VERIFIED: application_record.rb lines 54–56; after_update_commit lines 86–90]

### Pitfall 6: Reek command not available via bundle exec
**What goes wrong:** `reek` is not in the Gemfile. Running `bundle exec reek` fails with "Could not find gem 'reek'". The one-time baseline cannot be generated.
**How to avoid:** Install globally via `gem install reek` outside of Bundler. Use `reek app/models/table_monitor.rb > .planning/reek_baseline_table_monitor.txt`.
**Warning signs:** `bundle exec reek` fails; use `gem install reek` + plain `reek` command.
[VERIFIED: Gemfile and Gemfile.lock — reek is absent from both]

---

## Code Examples

### Minimal TableMonitor char test structure

```ruby
# frozen_string_literal: true
# test/characterization/table_monitor_char_test.rb

require "test_helper"

# Characterization tests for TableMonitor state machine and after_update_commit behavior.
# Purpose: Pin current behavior before extraction. Do NOT change behavior here.
class TableMonitorCharTest < ActiveSupport::TestCase
  setup do
    # Reset class-level state (prevents cattr_accessor pollution between tests)
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil

    @table_monitor = TableMonitor.create!(state: "ready")
  end

  teardown do
    TableMonitor.options = nil
    TableMonitor.gps = nil
    TableMonitor.location = nil
    TableMonitor.tournament = nil
    TableMonitor.my_table = nil
    TableMonitor.allow_change_tables = nil
  end

  # --- State transition tests ---

  test "start_new_match transitions from ready to warmup" do
    @table_monitor.start_new_match!
    assert_equal "warmup", @table_monitor.state
  end

  test "finish_warmup transitions through match_shootout" do
    @table_monitor.start_new_match!
    @table_monitor.finish_warmup!
    assert_equal "match_shootout", @table_monitor.state
  end

  test "invalid transition raises AASM::InvalidTransition with whiny_transitions: true" do
    assert_raises(AASM::InvalidTransition) do
      @table_monitor.finish_shootout!  # invalid from :ready
    end
  end

  # --- after_update_commit branch tests (require test_after_commit gem) ---

  test "after_update_commit skips jobs when skip_update_callbacks is true" do
    @table_monitor.skip_update_callbacks = true
    assert_no_enqueued_jobs do
      @table_monitor.update!(state: "warmup")
    end
  end

  test "after_update_commit skips jobs when not local_server" do
    ApplicationRecord.stub(:local_server?, false) do
      assert_no_enqueued_jobs do
        @table_monitor.update!(state: "warmup")
      end
    end
  end
end
```
[Source: direct code reading; patterns from TESTING.md and PITFALLS.md]

### Minimal RegionCc char test structure

```ruby
# frozen_string_literal: true
# test/characterization/region_cc_char_test.rb

require "test_helper"

# Characterization tests for RegionCc sync operations.
# VCR cassettes record real ClubCloud API responses.
# Run with live network ONCE to record, then run offline from cassettes.
class RegionCcCharTest < ActiveSupport::TestCase
  setup do
    @region_cc = RegionCc.find_or_create_by!(region: regions(:bbl)) do |r|
      r.base_url = "https://test.clubcloud.example.com"
    end
  end

  test "sync_leagues creates league records from ClubCloud" do
    VCR.use_cassette("region_cc_sync_leagues") do
      assert_difference "League.count" do
        @region_cc.sync_leagues(season_name: "2024-2025", armed: true)
      end
    end
  end

  test "sync_tournaments creates tournament records from ClubCloud" do
    VCR.use_cassette("region_cc_sync_tournaments") do
      assert_difference "Tournament.count" do
        @region_cc.sync_tournaments(season_name: "2024-2025", armed: true)
      end
    end
  end

  test "fix_tournament_structure runs without raising" do
    VCR.use_cassette("region_cc_fix_tournament") do
      assert_nothing_raised do
        @region_cc.fix_tournament_structure
      end
    end
  end
end
```
[Source: TESTING.md VCR patterns; CONTEXT.md D-03; vcr_setup.rb]

### Reek baseline command

```bash
# Run from project root — reek must be installed globally (not via bundle)
gem install reek

# Generate baseline reports
reek app/models/table_monitor.rb > .planning/reek_baseline_table_monitor.txt
reek app/models/region_cc.rb > .planning/reek_baseline_region_cc.txt

# Check smell counts
wc -l .planning/reek_baseline_*.txt
```
[Source: D-08; reek gem CLI documentation — ASSUMED command syntax is standard]

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `use_transactional_tests = false` for callback tests | `test_after_commit` gem | Cleaner isolation; no manual cleanup needed [VERIFIED: PITFALLS.md Pitfall 9] |
| `aasm whiny_transitions: false` (default) | `aasm whiny_transitions: true` | Silent guard failures become visible exceptions [VERIFIED: PITFALLS.md Pitfall 5] |
| Testing `after_commit` by disabling transactions | `test_after_commit` fires callbacks in wrapped transaction | Tests remain transactionally isolated [ASSUMED: gem documentation] |

**Current codebase state:**
- `whiny_transitions:` is **absent** from the AASM block — must be added [VERIFIED: table_monitor.rb line 307]
- `test_after_commit` is **absent** from Gemfile — must be added [VERIFIED: Gemfile lines 70–85]
- `test/characterization/` directory does **not exist** — must be created [VERIFIED: bash ls output]
- VCR cassettes directory is **empty** — 0 cassettes exist [VERIFIED: bash ls output]

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `test_after_commit` gem activates automatically in `:test` group or needs explicit `TestAfterCommit.enabled = true` in test_helper | Standard Stack / Code Examples | Misactivation means `after_commit` still doesn't fire; all job-enqueue tests give false positives |
| A2 | `reek` CLI accepts `reek path/to/file.rb > output.txt` syntax | Code Examples | Minor — check `reek --help` on first run |
| A3 | Sidekiq::Testing mode in test suite defaults to `:fake!` or `:inline!` | Code Examples / job assertion pattern | If `:inline!` is active, `assert_enqueued_jobs` won't work correctly; must check test_helper behavior |
| A4 | ClubCloud API credentials exist in `config/credentials/test.yml.enc` for cassette recording | RegionCc VCR pattern | VCR recording impossible without credentials; must verify before planning RegionCc test wave |
| A5 | `test_after_commit` gem is compatible with Rails 7.2.0.beta2 | Standard Stack | Incompatibility blocks D-02 entirely; alternative is `self.use_transactional_tests = false` with manual cleanup |

---

## Open Questions

1. **Is `test_after_commit` compatible with Rails 7.2.0.beta2?**
   - What we know: The gem is listed as Rails 5.x+ compatible. Rails 7.2 ships with `after_commit` behavior improvements.
   - What's unclear: Whether the beta introduces any callback timing changes that break the gem.
   - Recommendation: Add gem to Gemfile, run `bin/rails test test/characterization/` with a single smoke test and observe whether `after_commit` fires. If it does not, fall back to `self.use_transactional_tests = false` in the char test class only (overriding D-02 with a noted exception).

2. **What Sidekiq testing mode is active?**
   - What we know: `test_helper.rb` requires `sidekiq/testing` and sets log level to WARN. It does NOT call `Sidekiq::Testing.fake!` or `Sidekiq::Testing.inline!`.
   - What's unclear: What the default mode is when only `require "sidekiq/testing"` is called without explicit mode selection.
   - Recommendation: Add `Sidekiq::Testing.fake!` call to `test_helper.rb` before characterization tests, or at the top of the char test file, to ensure deterministic job queue behavior.

3. **Do ClubCloud API credentials exist for cassette recording?**
   - What we know: `test/support/scraping_helpers.rb` has `stub_clubcloud_auth` which stubs login. VCR cassette directory is empty.
   - What's unclear: Whether real API credentials are in `config/credentials/test.yml.enc` for the cassette-recording run.
   - Recommendation: Before planning the RegionCc test wave, verify credentials exist: `bin/rails runner "puts Carambus.config.clubcloud_username.present?"`. If absent, the cassette-recording plan task needs an additional step.

4. **Does ApplicationRecord.local_server? return true in the test environment?**
   - What we know: `local_server?` checks `Carambus.config.carambus_api_url.present?`. This is config-dependent.
   - What's unclear: What value this has in the test environment config.
   - Recommendation: Add a characterization test that explicitly exercises both branches by stubbing `local_server?`, regardless of the environment value. This makes the tests environment-independent.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Ruby 3.2 | All tests | Assumed available (project runs) | 3.2.x | — |
| PostgreSQL | All tests with DB writes | Assumed available | — | — |
| `bundle exec rails` | Test runner | Assumed available | Rails 7.2.0.beta2 | — |
| `reek` gem | QUAL-01 Reek baseline | NOT installed (absent from Gemfile/lock) | — | `gem install reek` globally |
| `test_after_commit` gem | D-02 after_commit testing | NOT installed (absent from Gemfile/lock) | — | `self.use_transactional_tests = false` in char test class only |
| ClubCloud API (live) | D-03 VCR cassette recording | Unknown — requires credential check | — | Cannot record cassettes without it |
| Redis | Action Cable / Sidekiq | Assumed available | — | — |

**Missing dependencies with no fallback:**
- ClubCloud API (live) — VCR cassette recording requires live access exactly once. Cannot be substituted. Needs credential verification before starting RegionCc test wave.

**Missing dependencies with fallback:**
- `test_after_commit` gem — fallback is `use_transactional_tests = false` in the char test class with manual DB cleanup in `teardown`. Less clean but functional.
- `reek` gem — globally installed via `gem install reek` outside Bundler. Not a blocker.

---

## Sources

### Primary (HIGH confidence)

- `app/models/table_monitor.rb` — AASM block (lines 307–366), `after_update_commit` lambda (lines 75–186), `cattr_accessor` list (lines 41–48), `skip_update_callbacks` (line 73), `log_state_change` (lines 426–444) — direct code read
- `app/models/application_record.rb` — `local_server?` implementation (lines 54–56) — direct code read
- `app/models/party_monitor.rb` — STI subclass confirmation, own AASM block — direct code read
- `app/models/region_cc.rb` — all 28+ sync/fix/HTTP method signatures enumerated — direct code read
- `test/test_helper.rb` — WebMock setup, Sidekiq require, fixture loading pattern — direct code read
- `test/support/vcr_setup.rb` — VCR configuration, cassette dir, match options — direct code read
- `test/support/scraping_helpers.rb` — available helper methods including `stub_clubcloud_auth` — direct code read
- `Gemfile` + `Gemfile.lock` — installed gems verified; `test_after_commit` and `reek` confirmed absent — direct code read
- `.planning/research/PITFALLS.md` — Pitfalls 5, 7, 9, 10 directly applicable to this phase
- `.planning/research/ARCHITECTURE.md` — AASM integration pattern, component communication map
- `.planning/codebase/TESTING.md` — test structure, VCR patterns, fixture patterns
- `.planning/phases/01-characterization-tests-hardening/01-CONTEXT.md` — locked decisions

### Secondary (MEDIUM confidence)

- AASM 5.5.2 `whiny_transitions:` option — cited in PITFALLS.md Pitfall 5 with github.com/aasm/aasm reference; not re-verified via web search in this session
- `test_after_commit` gem community-standard status — cited in PITFALLS.md Pitfall 9; gem exists on RubyGems

### Tertiary (LOW confidence)

- `test_after_commit` gem activation API in Rails 7.2 — training knowledge only; verify from gem README on install

---

## Metadata

**Confidence breakdown:**
- Standard stack (installed gems): HIGH — verified from Gemfile and Gemfile.lock
- AASM state machine map: HIGH — verified from direct code read
- `after_update_commit` branch map: HIGH — verified from direct code read
- RegionCc sync method inventory: HIGH — verified from direct grep on source file
- `test_after_commit` gem behavior: MEDIUM — gem is well-known; Rails 7.2 beta compatibility ASSUMED
- Reek CLI syntax: MEDIUM — standard gem CLI; not re-verified this session

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (stable gems; RegionCc API endpoint could drift sooner)
