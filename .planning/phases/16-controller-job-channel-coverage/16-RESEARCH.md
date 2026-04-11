# Phase 16: Controller, Job & Channel Coverage — Research

**Researched:** 2026-04-10
**Domain:** Rails controller testing, Action Cable channel testing, ActiveJob testing
**Confidence:** HIGH

## Summary

Phase 16 adds test coverage for controllers, jobs, and channels that touch Tournament and TournamentMonitor. All six targets have been mapped: `TournamentsController` (1047 lines, 20 public actions), `TournamentMonitorsController` (214 lines, 7 public actions), `TournamentMonitorChannel` and `TournamentChannel` (both minimal, ~20 lines each), `TournamentStatusUpdateJob` (101 lines, renders partial + CableReady broadcast), and `TournamentMonitorUpdateResultsJob` (32 lines, renders two partials + broadcast).

The test suite is currently green at 677 runs, 0 failures, 0 errors, 13 skips. Tournament model is at 575 lines (well under the 1000-line QUAL-01 target). TournamentMonitor is at 218 lines. The hardest problem in this phase is the `ensure_local_server` before_action guard: almost every write action in both controllers redirects if `Carambus.config.carambus_api_url` is blank. In the default test environment, `carambus_api_url` is blank (API server context), so write actions redirect immediately. Tests must either set `Carambus.config.carambus_api_url` to a non-blank value or stub `local_server?` per action.

**Primary recommendation:** Use `ActionDispatch::IntegrationTest` with `Devise::Test::IntegrationHelpers` (already globally included in `test_helper.rb`). Control `local_server?` per test by temporarily setting `Carambus.config.carambus_api_url = "http://local.test"` in setup and restoring it in teardown. Use `ActiveJob::TestHelper` for job tests and `ActionCable::Channel::TestCase` for channel tests.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COV-01 | TournamentsController test coverage (1047 lines, 20+ actions) | Controller mapped below — 20 public methods identified, before_action auth pattern documented |
| COV-02 | TournamentMonitorsController test coverage (214 lines, game pipeline actions) | All 7 public actions mapped; `update_games` is the complex pipeline action |
| COV-03 | TournamentMonitorChannel test coverage | Channel code is 19 lines; `local_server?` guard tested via stub |
| COV-04 | TournamentChannel test coverage | Channel code is 17 lines; two subscription branches (with/without tournament_id) |
| COV-05 | TournamentStatusUpdateJob test coverage | Job renders partial + broadcasts; use `perform_now` + assert model state |
| COV-06 | TournamentMonitorUpdateResultsJob test coverage | Job guards on `local_server?`; test both skip and execute paths |
| QUAL-01 | Tournament model line count under 1000 lines | Already at 575 lines — verified by `wc -l` |
| QUAL-02 | All existing tests remain green | Suite is green: 677 runs, 0 failures, 0 errors |
| QUAL-03 | PaperTrail version counts unchanged per operation | Phase 12 baselines in `test/models/tournament_papertrail_test.rb` — re-run to verify |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Test framework:** Minitest only (not RSpec)
- **Frozen string literals:** `# frozen_string_literal: true` in all Ruby files
- **Fixture-based:** `fixtures :all` loaded globally; use `fixtures(:name)` accessor pattern
- **Authentication:** Devise; `Devise::Test::IntegrationHelpers` already included globally in `ActionDispatch::IntegrationTest` via `test_helper.rb`
- **Assertion style:** `assert`/`refute` (standard Minitest)
- **Test file naming:** `{class_name_snake_case}_test.rb` in corresponding directory under `test/`
- **Controller tests:** Use `ActionDispatch::IntegrationTest` (not `ActionController::TestCase`)
- **No RSpec matchers** except `shoulda-matchers` where already in use

## Target Inventory

### TournamentsController (1047 lines)

**File:** `app/controllers/tournaments_controller.rb`
**Existing test:** None
**Auth guard:** `before_action :ensure_local_server` on all write actions; `ensure_rankings_cached` + `load_clubcloud_seedings` on `show`

**Public actions (20 total):**

| Action | HTTP | Local-Server Required | Description |
|--------|------|-----------------------|-------------|
| `index` | GET | No | Search + paginate tournaments |
| `show` | GET | No | Show tournament (calls ranking cache + CC seedings loaders) |
| `edit_games` | GET | Yes | Edit games modus flag |
| `reset` | POST/GET | Yes | Force or soft reset tournament monitor |
| `test_tournament_status_update` | POST/GET | No | Enqueues TournamentStatusUpdateJob immediately |
| `order_by_ranking_or_handicap` | POST | Yes | Sort seedings by ranking or handicap |
| `finish_seeding` | POST | Yes | AASM: transition to seeded state |
| `reload_from_cc` | POST | Conditional | Local: reset seedings; API: triggers scraping |
| `finalize_modus` | GET | Yes | Complex: calculates proposed tournament plan + groups |
| `select_modus` | POST | Yes | Assigns tournament plan |
| `tournament_monitor` | GET | No | Redirects to tournament_monitor_path |
| `placement` | POST | Yes | Places game on table monitor |
| `start` | POST | Yes | Starts tournament (AASM + creates TournamentMonitor) |
| `new` | GET | Yes | New tournament form |
| `edit` | GET | Yes | Edit tournament form |
| `create` | POST | Yes | Create tournament |
| `update` | PATCH | Yes | Update tournament |
| `destroy` | DELETE | Yes | Destroy tournament |
| `define_participants` | GET | Yes | Seeding/participant management |
| `new_team` | GET | Yes | New team form |
| `add_team` | POST | Yes | Add team to tournament |
| `compare_seedings` | GET | Yes | Compare CC vs local seedings |
| `upload_invitation` | POST | Yes | Upload PDF invitation |
| `parse_invitation` | POST | Yes | Parse uploaded PDF |
| `recalculate_groups` | POST | Yes | Recalculate group assignments |
| `add_player_by_dbu` | POST | Yes | Add player by DBU id |
| `apply_seeding_order` | POST | Yes | Apply new seeding positions |
| `use_clubcloud_as_participants` | POST | Yes | Overwrite seedings from CC |
| `update_seeding_position` | PATCH | Yes | Update single seeding position |

**`ensure_local_server` implementation** (line 1027-1046): redirects to `tournaments_path` if `Carambus.config.carambus_api_url.blank?`. Also blocks write if `@tournament.has_clubcloud_results?` (unless system_admin with `reload_games=true`).

### TournamentMonitorsController (214 lines)

**File:** `app/controllers/tournament_monitors_controller.rb`
**Existing test:** None
**Auth guards:**
- `before_action :set_tournament_monitor` on: show, edit, update, destroy, update_games, switch_players, start_round_games
- `before_action :ensure_tournament_director` on: show, edit, update, destroy, update_games, switch_players, start_round_games — requires `current_user.club_admin? || current_user.system_admin?`
- `before_action :ensure_local_server` on: show, edit, update, destroy, update_games, switch_players, start_round_games

**Public actions (7 total):**

| Action | HTTP | Auth | Description |
|--------|------|------|-------------|
| `switch_players` | POST | director+local | Swaps game_participation roles for a game |
| `start_round_games` | POST | director+local | Transitions all table monitors in ready/warmup to playing state |
| `update_games` | POST | director+local | Bulk manual game result entry with validation |
| `index` | GET | none | Paginated list |
| `show` | GET | director+local | Show tournament monitor |
| `new` | GET | none | New form |
| `edit` | GET | director+local | Edit form |
| `create` | POST | none | Create tournament monitor |
| `update` | PATCH | director+local | Update tournament monitor |
| `destroy` | DELETE | director+local | Destroy |

**`update_games` pipeline** (the complex action, lines 34-138): iterates over submitted game results, validates bounds against `balls_goal`/`innings_goal`, transitions table_monitor AASM state, writes result data to `table_monitor.data`, calls `evaluate_result`, optionally triggers ClubCloud upload.

**`ensure_tournament_director` implementation** (line 200-205): redirects to `root_path` if user is not `club_admin?` or `system_admin?`. The `club_admin` fixture in `users.yml` has `role: club_admin`.

### TournamentMonitorChannel (19 lines)

**File:** `app/channels/tournament_monitor_channel.rb`
**Key behavior:**
- `subscribed`: rejects on API server (`ApplicationRecord.local_server?` false → `reject`); else streams from `"tournament-monitor-stream"`
- `unsubscribed`: logs only

**Test approach:** `ActionCable::Channel::TestCase`. Stub `ApplicationRecord.local_server?` to control rejection vs subscription path.

### TournamentChannel (17 lines)

**File:** `app/channels/tournament_channel.rb`
**Key behavior:**
- `subscribed` with `params[:tournament_id]`: streams from `"tournament-stream-#{tournament_id}"`
- `subscribed` without `params[:tournament_id]`: streams from `"tournament-stream"`
- `unsubscribed`: logs only

**Test approach:** `ActionCable::Channel::TestCase`. Test both branches.

### TournamentStatusUpdateJob (101 lines)

**File:** `app/jobs/tournament_status_update_job.rb`
**Key behavior:**
- `discard_on ActiveRecord::RecordNotFound`
- Guards: returns early if no tournament_monitor or tournament not started
- Renders `tournaments/tournament_status` partial via `ApplicationController.renderer`
- Broadcasts via `cable_ready["tournament-stream-#{id}"].inner_html(...)`
- Falls back to `render_with_fallback` on render failure

**Test approach:** `ActiveSupport::TestCase` + `include ActiveJob::TestHelper`. Call `perform_now(tournament)`. Assert via guard paths (early return) and state checks. CableReady broadcast can be asserted via `assert_broadcasts` or by checking the channel payload.

### TournamentMonitorUpdateResultsJob (32 lines)

**File:** `app/jobs/tournament_monitor_update_results_job.rb`
**Key behavior:**
- Guards: returns early on API server (`ApplicationRecord.local_server?` false)
- Renders two partials: `tournament_monitors/game_results` and `tournament_monitors/rankings`
- Broadcasts via `cable_ready["tournament-monitor-stream"].inner_html(...)`

**Test approach:** `ActiveSupport::TestCase` + `include ActiveJob::TestHelper`. Test skip path (API server) and execute path (local server).

## Architecture Patterns

### Controller Test Pattern

**Established pattern** from `table_monitors_controller_test.rb` and `club_locations_controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  # Devise::Test::IntegrationHelpers is globally included via test_helper.rb
  # No need to include it again.

  setup do
    @tournament = tournaments(:local)  # id >= 50M, writeable in tests
    @user = users(:one)               # Basic user for read-only actions
    @club_admin = users(:club_admin)  # For club_admin-gated actions
    sign_in @user
  end
end
```

**`Devise::Test::IntegrationHelpers` is globally available** — `test_helper.rb` includes it for all `ActionDispatch::IntegrationTest` via:
```ruby
module ActionDispatch
  class IntegrationTest
    include Devise::Test::IntegrationHelpers
  end
end
```

### Local Server Context Pattern

The test environment has `Carambus.config.carambus_api_url` blank (API server context by default). Tests for local-server-only actions must set it temporarily:

```ruby
# VERIFIED via test/models/tournament_scraping_test.rb pattern:
setup do
  @original_api_url = Carambus.config.carambus_api_url
  Carambus.config.carambus_api_url = "http://local.test"
end

teardown do
  Carambus.config.carambus_api_url = @original_api_url
end
```

Alternatively, stub at model level (used in characterization tests):
```ruby
# Source: test/characterization/table_monitor_char_test.rb
ApplicationRecord.stub(:local_server?, true) do
  # test body
end
```

For controller tests, the `local_server?` method lives in `ApplicationController` and calls `Carambus.config.carambus_api_url.present?`, so setting the config value is the cleaner approach (no stub overhead).

### Channel Test Pattern (Rails built-in)

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentChannelTest < ActionCable::Channel::TestCase
  test "subscribes to tournament-specific stream with tournament_id" do
    subscribe(tournament_id: 42)
    assert subscription.confirmed?
    assert_has_stream "tournament-stream-42"
  end

  test "subscribes to generic stream without tournament_id" do
    subscribe
    assert subscription.confirmed?
    assert_has_stream "tournament-stream"
  end
end
```

For `TournamentMonitorChannel` (which rejects on API server):
```ruby
test "rejects subscription on API server" do
  ApplicationRecord.stub(:local_server?, false) do
    subscribe
    assert subscription.rejected?
  end
end

test "confirms subscription on local server" do
  ApplicationRecord.stub(:local_server?, true) do
    subscribe
    assert subscription.confirmed?
    assert_has_stream "tournament-monitor-stream"
  end
end
```

**`ActionCable::Channel::TestCase`** is built into Rails — no extra gems needed. [VERIFIED: Rails 7.2 ActionCable test helpers docs]

### Job Test Pattern

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentStatusUpdateJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "returns early when no tournament_monitor" do
    tournament = tournaments(:local)
    # tournament fixture has no tournament_monitor
    assert_nothing_raised { TournamentStatusUpdateJob.perform_now(tournament) }
  end

  test "returns early when tournament not started" do
    tournament = tournaments(:local)
    # state: "registration" — not in the started states list
    assert_nothing_raised { TournamentStatusUpdateJob.perform_now(tournament) }
  end
end
```

For `TournamentMonitorUpdateResultsJob` (guards on `local_server?`):
```ruby
test "skips on API server" do
  # Default test environment is API server (carambus_api_url blank)
  assert_nothing_raised { TournamentMonitorUpdateResultsJob.perform_now(tournament_monitor) }
end
```

**Pattern source:** `test/characterization/table_monitor_char_test.rb` uses `include ActiveJob::TestHelper` + `assert_enqueued_jobs`. [VERIFIED: grep of test files]

### Fixture Baseline

**Available fixtures relevant to this phase:**

| Fixture | Key | Id | Notes |
|---------|-----|----|-------|
| `tournaments(:local)` | `local` | 50_000_001 | state: "registration", writeable |
| `tournaments(:imported)` | `imported` | 1000 | state: "tournament_started", global (read-only via LocalProtector, but overridden in tests) |
| `users(:one)` | `one` | — | Basic user |
| `users(:club_admin)` | `club_admin` | — | role: club_admin — needed for `ensure_tournament_director` |
| `users(:system_admin)` | `system_admin` | — | role: system_admin |

**No `tournament_monitors` fixture exists.** The TournamentMonitor tests (Phases 11-15) use test helpers to create TournamentMonitors via `@tournament.initialize_tournament_monitor`. Controller tests for `TournamentMonitorsController` that need a TournamentMonitor record must create one in setup.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Minitest | Bundled with Rails | Test framework | Project standard; enforced in CLAUDE.md |
| ActionDispatch::IntegrationTest | Bundled | HTTP controller tests | Rails standard for controller testing |
| ActionCable::Channel::TestCase | Bundled | Channel unit tests | Rails built-in, no extra gems |
| ActiveJob::TestHelper | Bundled | Job assertion helpers | Rails built-in, already used in project |
| Devise::Test::IntegrationHelpers | Bundled with Devise | Auth in controller tests | Already globally included in test_helper |

### No Additional Gems Needed

All required test infrastructure exists. No new gems required for this phase. [VERIFIED: existing test files use the same helpers]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Channel subscription assertions | Custom assertion helpers | `assert_has_stream`, `assert subscription.confirmed?` | ActionCable::Channel::TestCase provides these |
| Job execution in tests | `Thread.new` or manual queue draining | `perform_now` or `perform_enqueued_jobs` | ActiveJob::TestHelper handles queue adapter |
| Auth helpers | Manual session manipulation | `sign_in`/`sign_out` from Devise::Test::IntegrationHelpers | Already globally available |
| CableReady broadcast assertions | Inspect broadcast internals | Assert model state changes instead | CableReady broadcasts are side effects; test observable state |

## Common Pitfalls

### Pitfall 1: `ensure_local_server` redirect silently blocks test
**What goes wrong:** Test posts to a write action, gets a 302 redirect to `tournaments_path`, test passes because it checks `assert_response :redirect` — but never actually tested the action logic.
**Why it happens:** `carambus_api_url` is blank in default test environment (API server context).
**How to avoid:** In `setup`, set `Carambus.config.carambus_api_url = "http://local.test"`. In `teardown`, restore original value. Document this per test class.
**Warning signs:** All write-action tests return 302 to tournaments_path.

### Pitfall 2: `ensure_tournament_director` redirect when using wrong user fixture
**What goes wrong:** Test signs in as `users(:one)` (basic user) and tries to hit a director-gated action; gets redirected to `root_path`.
**Why it happens:** `ensure_tournament_director` requires `club_admin?` or `system_admin?`.
**How to avoid:** Use `users(:club_admin)` for all TournamentMonitorsController actions that require the guard.

### Pitfall 3: Missing TournamentMonitor fixture breaks controller tests
**What goes wrong:** `set_tournament_monitor` calls `TournamentMonitor.find(params[:id])` — raises `ActiveRecord::RecordNotFound` if no fixture.
**Why it happens:** No `tournament_monitors.yml` fixture file exists.
**How to avoid:** Create TournamentMonitor in setup via `@tournament.initialize_tournament_monitor` pattern used in Phase 11-15 tests; or create a fixture file.

### Pitfall 4: `TournamentStatusUpdateJob` render failure in test environment
**What goes wrong:** `ApplicationController.renderer.new(...)` + `render(partial: ...)` may fail if view templates or helpers are unavailable in test context.
**Why it happens:** The job renders real ERB partials; the test environment may not have all view dependencies mocked.
**How to avoid:** Use `assert_nothing_raised` for basic execution tests. For broadcast assertion, test the guard paths (early return cases) rather than the full render path unless the view works cleanly.

### Pitfall 5: PaperTrail version count drift
**What goes wrong:** Controller tests that save Tournament records generate PaperTrail versions, and if not using transactional tests properly, they pollute baseline counts.
**Why it happens:** PaperTrail is active in test environment (no `carambus_api_url` present in default context = API server = no versions... wait, PaperTrail runs on all saves in test).
**How to avoid:** Wrap controller tests in transactions (default for Minitest integration tests). Check `tournament_papertrail_test.rb` baselines still pass after adding controller tests.

### Pitfall 6: `update_games` action requires existing games with valid table_monitors
**What goes wrong:** The `update_games` action iterates over `params["game_id"]` and calls `@tournament_monitor.tournament.games.where(...)` — needs real game records with table_monitors.
**Why it happens:** Complex fixture dependency chain: tournament → tournament_monitor → games → table_monitors.
**How to avoid:** For `update_games` tests, either use existing characterization test helpers (`T04TournamentTestHelper`) to build the full graph, or test the redirect behavior with empty params only.

## Code Examples

### Controller Test with Local Server Context

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    @user = users(:one)
    @club_admin = users(:club_admin)
    @original_api_url = Carambus.config.carambus_api_url
    sign_in @user
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  test "should get index" do
    get tournaments_url
    assert_response :success
  end

  test "should get show" do
    get tournament_url(@tournament)
    assert_response :success
  end

  test "should get new on local server" do
    Carambus.config.carambus_api_url = "http://local.test"
    get new_tournament_url
    assert_response :success
  end

  test "new redirects on API server" do
    # Default test env is API server (carambus_api_url blank)
    get new_tournament_url
    assert_redirected_to tournaments_path
  end
end
```

### Channel Test

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentChannelTest < ActionCable::Channel::TestCase
  test "subscribes with tournament_id and streams from specific stream" do
    subscribe(tournament_id: 42)
    assert subscription.confirmed?
    assert_has_stream "tournament-stream-42"
  end

  test "subscribes without tournament_id and streams from generic stream" do
    subscribe
    assert subscription.confirmed?
    assert_has_stream "tournament-stream"
  end
end

class TournamentMonitorChannelTest < ActionCable::Channel::TestCase
  test "rejects subscription on API server" do
    ApplicationRecord.stub(:local_server?, false) do
      subscribe
      assert subscription.rejected?
    end
  end

  test "confirms subscription on local server" do
    ApplicationRecord.stub(:local_server?, true) do
      subscribe
      assert subscription.confirmed?
      assert_has_stream "tournament-monitor-stream"
    end
  end
end
```

### Job Test

```ruby
# frozen_string_literal: true

require "test_helper"

class TournamentStatusUpdateJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @tournament = tournaments(:local)  # state: "registration"
  end

  test "returns early when tournament has no tournament_monitor" do
    assert_nil @tournament.tournament_monitor
    assert_nothing_raised { TournamentStatusUpdateJob.perform_now(@tournament) }
  end

  test "returns early when tournament is not started (registration state)" do
    assert_equal "registration", @tournament.state
    assert_nothing_raised { TournamentStatusUpdateJob.perform_now(@tournament) }
  end
end

class TournamentMonitorUpdateResultsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "skips on API server (carambus_api_url blank)" do
    # Default test env: carambus_api_url is blank (API server context)
    # Job should return early without error
    tm = TournamentMonitor.new  # stub-level check — no real record needed
    assert_nothing_raised do
      TournamentMonitorUpdateResultsJob.perform_now(tm)
    end
  end
end
```

## QUAL-01 Verification

Tournament model is currently **575 lines**. [VERIFIED: `wc -l app/models/tournament.rb`]

This is already under the 1000-line target set by QUAL-01. No further extraction is required in Phase 16 to meet this requirement. The plan should include a final `wc -l` check as a pass/fail gate.

## QUAL-02 Verification

Test suite is currently green. [VERIFIED: `bin/rails test` output — 677 runs, 0 failures, 0 errors, 13 skips]

Phase 16 adds new test files; existing tests must remain green. The plan should run the full suite as a final gate.

## QUAL-03 Verification

PaperTrail version count baselines were established in Phase 12. Test file: `test/models/tournament_papertrail_test.rb`. This file already passes. The plan should re-run this specific file after Phase 16 work is complete to confirm no regressions.

## Open Questions

1. **TournamentStatusUpdateJob render path in tests**
   - What we know: The job calls `ApplicationController.renderer.new(...)` and renders `tournaments/tournament_status` partial
   - What's unclear: Whether ERB partial rendering succeeds in the test environment without a full request context (Warden mock, fixtures, etc.)
   - Recommendation: Write tests for the guard paths first (early returns). If the render path is needed, use `assert_nothing_raised` rather than asserting broadcast content, and document the limitation.

2. **TournamentMonitorsController `update_games` testability**
   - What we know: Requires a chain: tournament → tournament_monitor → games with game_participations → table_monitors with valid data hashes
   - What's unclear: Whether the fixture chain can be set up cleanly without the T04/T06 test helpers
   - Recommendation: Reuse `T04TournamentTestHelper` (already in `test/support/`) to build the fixture graph. Test with empty `params["game_id"]` for the skip-all-validations path, and one valid game for the happy path.

3. **Channel test authentication (ApplicationCable::Connection)**
   - What we know: `Connection#connect` calls `find_verified_user` which returns `User.first || reject_unauthorized_connection`
   - What's unclear: Whether channel tests need a specific user signed in or if `User.first` from fixtures is sufficient
   - Recommendation: Since `find_verified_user` returns `User.first` (fixtures load users), channel tests should connect without explicit auth setup. Verify by running a channel test first.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies — this phase only adds test files using the existing Rails test stack)

## Validation Architecture

Step 4: SKIPPED — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

## Security Domain

No new security surface introduced — this phase only adds tests. Existing ASVS patterns are unchanged.

## Sources

### Primary (HIGH confidence)
- Codebase: `app/controllers/tournaments_controller.rb` — complete action inventory via grep + read [VERIFIED]
- Codebase: `app/controllers/tournament_monitors_controller.rb` — complete file read [VERIFIED]
- Codebase: `app/channels/tournament_channel.rb` + `tournament_monitor_channel.rb` — complete file reads [VERIFIED]
- Codebase: `app/jobs/tournament_status_update_job.rb` + `tournament_monitor_update_results_job.rb` — complete file reads [VERIFIED]
- Codebase: `test/test_helper.rb` — Devise::Test::IntegrationHelpers global inclusion, LocalProtectorTestOverride [VERIFIED]
- Codebase: `test/controllers/table_monitors_controller_test.rb` — established controller test pattern [VERIFIED]
- Codebase: `test/characterization/table_monitor_char_test.rb` — ActiveJob::TestHelper usage, local_server? stub pattern [VERIFIED]
- Codebase: `test/models/tournament_scraping_test.rb` — `Carambus.config.carambus_api_url` assignment pattern [VERIFIED]
- Codebase: `config/carambus.yml` — confirmed `carambus_api_url` is blank in default/development environments [VERIFIED]
- Bash: `wc -l app/models/tournament.rb` → 575 lines [VERIFIED]
- Bash: `wc -l app/models/tournament_monitor.rb` → 218 lines [VERIFIED]
- Bash: `bin/rails test` → 677 runs, 0 failures, 0 errors, 13 skips [VERIFIED]

### Secondary (MEDIUM confidence)
- Rails ActionCable::Channel::TestCase API — channel test class, `assert_has_stream`, `subscription.confirmed?`, `subscription.rejected?` [ASSUMED — based on Rails docs knowledge, not verified via Context7 in this session]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `ActionCable::Channel::TestCase` provides `assert_has_stream`, `subscription.confirmed?`, `subscription.rejected?` | Channel test pattern | Low — these are core Rails 7.x Channel test helpers; would require adjusting assertion method names |
| A2 | `ApplicationController.renderer` works in test environment for the job's render path | Job testing / pitfall 4 | Medium — if render fails, tests for the broadcast path cannot be written as simple assertions; use early-return guard paths instead |

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all test infrastructure verified in existing test files
- Architecture patterns: HIGH — controller and job patterns confirmed by existing tests
- Channel patterns: MEDIUM — channel test class not yet used in project; Rails built-in but not verified for this codebase
- Pitfalls: HIGH — identified from actual code paths and existing test workarounds

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (stable Rails test infrastructure — no near-term changes expected)
