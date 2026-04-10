# Stack Research: Tournament & TournamentMonitor Refactoring (v2.1)

**Domain:** Rails brownfield model refactoring with ActionCable, StimulusReflex, and ActiveJob coverage
**Researched:** 2026-04-10
**Confidence:** HIGH (codebase read directly; patterns verified from existing v1.0 and v2.0 work)

---

## Decision Summary

This milestone is still a **no-new-framework** refactoring. The question is narrower than v1.0: what testing tools and patterns are needed to test the new surface area — ActionCable channels, StimulusReflex reflexes, controller actions, and ActiveJob jobs — beyond plain model unit tests?

The answer is: **Rails 7.2 ships everything needed natively**. No new gems are required for the core work. One conditional addition (`stimulus_reflex` test adapter, if direct reflex testing is pursued) is discussed below with a recommendation to skip it.

---

## Recommended Stack

### Core Technologies (unchanged from v1.0)

| Technology | Version | Purpose | Status |
|------------|---------|---------|--------|
| Rails | 7.2.2 | Framework | Already installed |
| Ruby | 3.2.1 | Runtime | Already installed |
| PostgreSQL | current | Database | Already installed |
| Minitest | (Rails built-in) | Test runner | Already installed |
| ActiveJob::TestHelper | (Rails built-in) | Job queue assertions | Already in use (table_monitor_char_test.rb) |

### Testing Patterns for New Surface Area

#### ActionCable Channels

Rails 7.2 ships `ActionCable::Channel::TestCase` as a built-in. No gem needed.

```ruby
# test/channels/tournament_channel_test.rb
require "test_helper"

class TournamentChannelTest < ActionCable::Channel::TestCase
  test "subscribes to tournament-specific stream when tournament_id given" do
    subscribe tournament_id: tournaments(:local).id
    assert subscription.confirmed?
    assert_has_stream "tournament-stream-#{tournaments(:local).id}"
  end

  test "subscribes to global tournament stream when no tournament_id" do
    subscribe
    assert subscription.confirmed?
    assert_has_stream "tournament-stream"
  end
end

# test/channels/tournament_monitor_channel_test.rb
class TournamentMonitorChannelTest < ActionCable::Channel::TestCase
  test "rejects subscription on API server" do
    ApplicationRecord.stub(:local_server?, false) do
      subscribe
      assert subscription.rejected?
    end
  end

  test "subscribes on local server" do
    ApplicationRecord.stub(:local_server?, true) do
      subscribe
      assert subscription.confirmed?
      assert_has_stream "tournament-monitor-stream"
    end
  end
end
```

**Key assertions available:**
- `assert subscription.confirmed?` / `assert subscription.rejected?`
- `assert_has_stream "stream-name"` / `assert_no_streams`
- `perform :method_name, args` — call channel actions directly
- `assert_broadcasts "stream", 1` — count broadcasts on a stream

**Confidence: HIGH** — Rails built-in since Rails 5. Verified in Rails 7.2 guides.

---

#### ActiveJob (Jobs)

`ActiveJob::TestHelper` is already in use for `TableMonitorCharTest` and `GameSetupTest`. Same pattern applies to `TournamentStatusUpdateJob` and `TournamentMonitorUpdateResultsJob`.

```ruby
# test/jobs/tournament_status_update_job_test.rb
require "test_helper"

class TournamentStatusUpdateJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  test "discards job when tournament not found" do
    # discard_on ActiveRecord::RecordNotFound is configured in the job
    assert_nothing_raised do
      TournamentStatusUpdateJob.perform_now(nil)
    end
  end

  test "skips broadcast when tournament has no monitor" do
    tournament = tournaments(:local)
    # tournament_monitor is nil by default in fixture
    assert_no_enqueued_jobs do
      TournamentStatusUpdateJob.perform_now(tournament)
    end
  end

  test "skips broadcast on local_server (TournamentMonitorUpdateResultsJob)" do
    ApplicationRecord.stub(:local_server?, false) do
      tm = tournament_monitors(:one)
      assert_nothing_raised do
        TournamentMonitorUpdateResultsJob.perform_now(tm)
      end
    end
  end
end
```

**Key patterns from existing tests to reuse:**
- `include ActiveJob::TestHelper` in the test class
- `assert_enqueued_jobs(N, only: [JobClass])` — count enqueued jobs of specific type
- `ApplicationRecord.stub(:local_server?, true/false)` — flip server context per test
- `Sidekiq::Testing.fake!` is configured in `test_helper.rb` — jobs do not run automatically

**Confidence: HIGH** — Pattern confirmed in `test/characterization/table_monitor_char_test.rb:16`.

---

#### Controllers

Pattern established by `TableMonitorsControllerTest`. Use `ActionDispatch::IntegrationTest` with Devise sign-in helpers. Tournament controller has `ensure_local_server` guards — test both API server (should redirect/fail) and local server contexts.

```ruby
# test/controllers/tournaments_controller_test.rb
require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tournament = tournaments(:local)
    @user = users(:one)
    sign_in @user
  end

  test "GET index returns success" do
    get tournaments_url
    assert_response :success
  end

  test "reset action triggers AASM event and redirects" do
    # Tournament must not be started yet
    @tournament.update_column(:state, "new_tournament")
    post reset_tournament_url(@tournament)
    assert_redirected_to tournament_path(@tournament)
  end

  test "ensure_local_server blocks edit on API server" do
    # API server: local_server? == false
    ApplicationRecord.stub(:local_server?, false) do
      get edit_tournament_url(@tournament)
      assert_redirected_to root_path  # or wherever ensure_local_server redirects
    end
  end
end
```

**Confidence: HIGH** — Existing controller test pattern verified across 10+ controller test files.

---

#### StimulusReflex Reflexes

**Recommendation: Do NOT write direct reflex tests. Skip them as the existing `TableMonitorsControllerTest` does.**

The existing codebase explicitly documents this decision:

```ruby
# test/controllers/table_monitors_controller_test.rb:73-85
test "should handle optimistic score updates" do
  skip "StimulusReflex endpoints are not testable via standard HTTP integration tests"
end
```

**Why reflexes are untestable via standard Minitest:**
- StimulusReflex actions are triggered over WebSocket, not HTTP. There is no HTTP endpoint to hit.
- The `stimulus_reflex` gem (3.5.3) does not ship a test adapter for Rails 7.2 — its testing story relies on system tests (Capybara + Chrome) or manual browser verification.
- Adding `cable_ready` and `stimulus_reflex` mocking layers to unit tests produces brittle, hard-to-maintain tests that test the mocking infrastructure, not the business logic.

**What to test instead:** Extract the business logic out of reflexes into service objects or model methods, then test those directly. The reflex becomes a thin adapter (find record, call service, morph). `TournamentReflex` already demonstrates this — its ATTRIBUTE_METHODS loop delegates to `tournament.send("#{attribute}=", val)` + `tournament.save!`. Test the model setter, not the reflex.

**If reflex coverage is required:** Use system tests (`ApplicationSystemTestCase` + Capybara + Selenium) which exercise the full WebSocket cycle. Scope those to specific high-risk reflex actions only.

**Confidence: HIGH** — Decision documented and verified in existing codebase. StimulusReflex 3.5.3 test adapter absence confirmed.

---

### Service Object Convention (unchanged from v1.0)

Namespace extracted services under the model name:

```
app/services/
  tournament/
    ranking_calculator.rb     # extract from TournamentMonitor#ranking + #player_id_from_ranking
    group_distributor.rb      # extract distribute_to_group + distribute_with_sizes (pure algorithm)
    monitor_initializer.rb    # extract initialize_tournament_monitor
    scraper.rb                # extract scrape_single_tournament_public (optional — risky)
  tournament_monitor/
    game_sequencer.rb         # game sequence logic (next_seqno, ko_ranking resolution)
    player_assigner.rb        # player → game assignment from ranking rules
    table_allocator.rb        # table assignment coordination
    state_broadcaster.rb      # after_update_commit → TournamentStatusUpdateJob
```

PORO with explicit `initialize` dependencies and single `call` method. No new gem needed.

**The `group_distributor` is the highest-value first extraction** — `distribute_to_group` and `distribute_with_sizes` are pure algorithms with no database calls. They have documented edge cases (GROUP_RULES, GROUP_SIZES constants), testable input/output, and are currently tested only implicitly via integration tests.

---

### Static Analysis (unchanged from v1.0)

```ruby
# Gemfile — group :development
gem "reek", "~> 6.5", require: false
```

Run Reek before and after extraction to measure improvement objectively:

```bash
bundle exec reek app/models/tournament.rb
bundle exec reek app/models/tournament_monitor.rb
```

---

## Key Patterns from v1.0/v2.0 to Reuse

### suppress_broadcast Pattern

Tournament and TournamentMonitor have `after_update_commit` callbacks that enqueue jobs. When a service object makes multiple saves, use `suppress_broadcast` to batch:

```ruby
# app/services/tournament/monitor_initializer.rb
class Tournament::MonitorInitializer
  def call
    tournament.suppress_broadcast = true
    # ... multiple saves ...
  ensure
    tournament.suppress_broadcast = false
  end
end
```

Test this by verifying `suppress_broadcast` state inside save callbacks — same approach used in `GameSetupTest` (line 188-203).

### local_server? Stub

Both channels and both jobs gate behavior on `ApplicationRecord.local_server?`. Stub it per test:

```ruby
ApplicationRecord.stub(:local_server?, true) do
  # test local server behavior
end
```

This pattern is confirmed in `table_monitor_char_test.rb` across 6+ tests.

### ApiProtectorTestOverride

`TournamentMonitor` includes `ApiProtector`. The `test_helper.rb` already patches all `ApiProtector`-including classes at boot. No per-test action needed.

### AASM State Tests

Tournament has 8 AASM states with guards. Test state transitions with real fixture data:

```ruby
test "reset_tmt_monitor! fails when tournament already started" do
  @tournament.update_column(:state, "tournament_started")
  assert_raises(AASM::InvalidTransition) do
    @tournament.reset_tmt_monitor!
  end
end
```

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `stimulus_reflex` test adapter / custom WebSocket mocking | Does not exist for SR 3.5.3; any homebrew solution tests the mock, not the reflex | Extract business logic to service methods, test those |
| `test-after-commit` gem | Rails 7.2 fires `after_commit` natively in transactional tests (confirmed in table_monitor_char_test.rb comment) | None needed |
| RSpec or system-test-only coverage for channels | ActionCable::Channel::TestCase handles channel logic without a browser | Use built-in test case |
| VCR cassettes for Tournament scraper tests | Scraper is already smoke-tested; adding VCR cassettes for the 1775-line scraper is out of scope for this milestone (behavior preservation, not scraper coverage) | Stub HTTP with WebMock only |
| FactoryBot factories for Tournament | Project uses fixtures-first, no factory definitions exist, `KoTournamentTestHelper` handles complex setup | Use fixtures + `KoTournamentTestHelper` |

---

## Installation

No new gems required. The only optional addition from v1.0 that may be needed:

```ruby
# Gemfile — group :development (only if not already present from v1.0)
gem "reek", "~> 6.5", require: false
```

```ruby
# Gemfile — only if extracted service objects need transactional after_commit hooks
gem "after_commit_everywhere", "~> 1.6"
```

Both were already recommended in v1.0 STACK.md. Check if `reek` is already in the Gemfile before adding.

---

## Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| ActionCable channel testing | HIGH | Rails 7.2 built-in, pattern verified in Rails guides |
| Job testing (`ActiveJob::TestHelper`) | HIGH | Already in use in `table_monitor_char_test.rb` |
| Controller testing | HIGH | 10+ existing controller test files with identical pattern |
| Reflex testing (skip) | HIGH | Skip rationale documented in existing codebase |
| Service extraction patterns | HIGH | Verified from v1.0 extractions (14 services) |
| suppress_broadcast reuse | HIGH | Pattern in `game_setup_test.rb` lines 188-253 |

---

## Sources

- Rails 7.2 ActionCable Channel test docs — https://api.rubyonrails.org/classes/ActionCable/Channel/TestCase.html
- `test/characterization/table_monitor_char_test.rb` — ActiveJob::TestHelper patterns, suppress_broadcast, local_server? stubs
- `test/controllers/table_monitors_controller_test.rb` — skip rationale for StimulusReflex
- `test/services/table_monitor/game_setup_test.rb` — suppress_broadcast lifecycle test pattern
- `test_helper.rb` — ApiProtectorTestOverride, Sidekiq::Testing.fake! configuration
- `app/channels/tournament_channel.rb`, `tournament_monitor_channel.rb` — channel subscription logic
- `app/jobs/tournament_status_update_job.rb`, `tournament_monitor_update_results_job.rb` — job gating on local_server?
- `app/reflexes/tournament_reflex.rb` — thin-adapter pattern that makes reflex testing unnecessary

---

*Stack research for: Tournament & TournamentMonitor refactoring (v2.1)*
*Researched: 2026-04-10*
