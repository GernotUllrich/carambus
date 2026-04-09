# Testing Patterns

**Analysis Date:** 2026-04-09

## Test Framework

**Runner:**
- Rails testing framework (built-in, no external test runner needed)
- MiniTest for unit/integration tests
- System tests via Capybara/Selenium for browser automation
- Config: `test/test_helper.rb` is main entry point

**Assertion Library:**
- MiniTest assertions (standard Rails)
- Additional: `shoulda-matchers` gem for enhanced assertions (model validations, associations)

**Run Commands:**
```bash
bin/rails test                      # Run all tests
bin/rails test:models              # Run model tests only
bin/rails test:system              # Run system tests
COVERAGE=true bin/rails test       # Run with coverage reporting (SimpleCov)
bin/rails test test/models/player_test.rb  # Run specific test file
```

**Test Environment:**
- `Rails.env` set to "test" in `test/test_helper.rb`
- Fixtures loaded: `fixtures :all` loads all YAML fixtures in `test/fixtures/`
- FactoryBot integrated: `include FactoryBot::Syntax::Methods` available in all tests
- Devise integration: `include Devise::Test::IntegrationHelpers` for authentication helpers
- Paper Trail integration: `set_paper_trail_whodunnit` callback tracks who changes records

## Test File Organization

**Location:**
- Unit tests co-located with models: `test/models/*.rb`
- Controller tests: `test/controllers/`
- Integration tests: `test/integration/`
- System tests (Capybara): `test/system/`
- Task tests: `test/tasks/`
- Scraping tests: `test/scraping/`
- Support files (helpers): `test/support/*.rb`
- Fixtures: `test/fixtures/*.yml`
- Snapshots (VCR cassettes): `test/snapshots/vcr/`

**Naming:**
- Test files: `{model_name}_test.rb` or `{description}_test.rb`
- Test classes: `{ClassUnderTest}Test < ActiveSupport::TestCase`
- Test methods: `test "description of what is tested"` or `def test_method_name`

**Directory Structure:**
```
test/
├── concerns/           # Concern/mixin tests
├── controllers/        # Controller/API endpoint tests
├── fixtures/          # YAML test data (divided by type)
│   ├── users.yml
│   ├── tournaments.yml
│   ├── html/          # HTML fixtures for scraping
│   └── ...
├── helpers/           # Helper method tests
├── integration/       # Integration/workflow tests
├── models/            # Unit tests for models
├── scraping/          # Scraping-specific tests
├── snapshots/         # Recorded HTTP responses (VCR)
├── support/           # Test helper modules
│   ├── vcr_setup.rb
│   ├── scraping_helpers.rb
│   ├── snapshot_helpers.rb
│   └── ko_tournament_test_helper.rb
├── system/            # System tests (Capybara/Selenium)
├── tasks/             # Rake task tests
├── test_helper.rb     # Main test configuration
└── system_test_helper.rb
```

## Test Structure

**Base Test Class:**
```ruby
require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  # Fixtures loaded automatically
  
  def setup
    # Setup before each test
    @player = players(:one)  # Load from fixtures/players.yml
  end
  
  test "should do something" do
    # Arrange
    expected = "value"
    
    # Act
    result = @player.some_method
    
    # Assert
    assert_equal expected, result
  end
  
  teardown do
    # Optional cleanup after each test
  end
end
```

**Integration Test (HTTP):**
```ruby
require "test_helper"

class UserAuthenticationTest < ActionDispatch::IntegrationTest
  test "user can delete their account" do
    sign_in users(:one)  # Devise helper
    assert_difference "User.count", -1 do
      delete "/users"
    end
    assert_redirected_to root_path
  end
end
```

**System Test (Capybara):**
```ruby
require "test_helper"

class PreferencesTest < ApplicationSystemTestCase
  test "user can update preferences" do
    login_as users(:one)  # Capybara helper
    visit preferences_path
    fill_in "email", with: "new@example.com"
    click_button "Save"
    assert_text "Preferences updated"
  end
end
```

**KO Tournament Complex Test with Helper:**
```ruby
require "test_helper"

class TournamentKoIntegrationTest < ActiveSupport::TestCase
  include KoTournamentTestHelper
  
  self.use_transactional_tests = true  # Wrap in DB transaction for cleanup
  
  setup do
    @test_data = create_ko_tournament_with_seedings(16)
    @tournament = @test_data[:tournament]
    @players = @test_data[:players]
  end
  
  teardown do
    cleanup_ko_tournament(@test_data) if @test_data
  end
  
  test "initializing KO tournament creates tournament monitor" do
    @tournament.initialize_tournament_monitor
    assert_not_nil @tournament.tournament_monitor
  end
end
```

## Mocking

**Framework:** WebMock for HTTP mocking

**HTTP Mocking Patterns:**
```ruby
# Stub a single request
stub_request(:get, "https://example.com/api")
  .to_return(status: 200, body: "response", headers: { 'Content-Type' => 'application/json' })

# Stub with regex matching
stub_request(:any, /.*clubcloud.*/)
  .to_return(status: 200, body: "")

# Simulate error
stub_request(:get, /.*/).to_raise(SocketError.new("Network error"))
stub_request(:get, /.*/).to_timeout
stub_request(:get, /.*/).to_return(status: 500, body: "Server Error")
```

**Recording HTTP Responses:**
- VCR gem configured in `test/support/vcr_setup.rb`
- Records first HTTP interaction, replays on subsequent runs
- Cassettes stored in `test/snapshots/vcr/`
- Config: `record: :once`, `match_requests_on: [:method, :uri]`
- Sensitive data filtered automatically (passwords, usernames)
- Allows repeated playback: `allow_playback_repeats: true`

**VCR Usage in Tests:**
```ruby
def test_scraping_with_real_request
  VCR.use_cassette('tournament_cc_response') do
    # First run: records HTTP interaction
    # Subsequent runs: replays from cassette
    result = TournamentCc.scrape
    assert_not_nil result
  end
end
```

**Database Mocking:**
- Fixtures (YAML) provide test data
- FactoryBot for programmatic object creation
- Transactions (`use_transactional_tests = true`) for test isolation

**What to Mock:**
- External HTTP APIs (ClubCloud, Google Calendar, OpenAI, etc.)
- Network timeouts and errors (to test error handling)
- File operations (for image processing tests)
- Sidekiq/job queues in tests (`Sidekiq.logger.level = Logger::WARN`)

**What NOT to Mock:**
- Database operations (use fixtures/factories instead)
- Model validations (test real Rails validation)
- ActiveRecord associations (test actual relations)
- Local/internal business logic

## Fixtures and Factories

**Fixtures (YAML):**
- Located in `test/fixtures/`
- One file per model: `players.yml`, `tournaments.yml`, `users.yml`, etc.
- Access in tests: `players(:one)`, `tournaments(:imported)`
- Auto-loaded by `fixtures :all` in test_helper

**Fixture Example:** (`test/fixtures/users.yml`)
```yaml
one:
  email: user@example.com
  password: "password123"
  encrypted_password: <%= Devise.password_hash_strategy.hash_password(User.new, 'password123') %>
  confirmed_at: <%= Time.current %>

club_admin:
  email: admin@example.com
  admin: false
  ...
```

**FactoryBot Factories:**
- No separate `spec/factories/` directory found
- FactoryBot included but minimal usage evident
- Alternative to factories: create objects in test setup via `Model.create!(...)`

**Example fixture-based test:**
```ruby
def setup
  @region = regions(:bbl)
  @player = players(:one)
  @season = seasons(:current)
end
```

**Example direct creation:**
```ruby
def setup
  @player = Player.create!(
    firstname: "Hans",
    lastname: "Meyer",
    cc_id: 12345,
    region: regions(:bbl)
  )
end
```

## Coverage

**Requirements:** Informational only (60% minimum target, not enforced)

**Configuration:** `SimpleCov` gem configured in `.simplecov`
- Focused on `app/` code, excludes tests/config/vendor
- Groups coverage by type: Models, Controllers, Services, Concerns, Helpers, Mailers, Jobs, Channels
- Custom groups for critical code: "ClubCloud Integration", "Critical Concerns"
- Coverage report: HTML generated to `coverage/`

**View Coverage:**
```bash
COVERAGE=true bin/rails test    # Generate coverage report
open coverage/index.html        # View HTML report
```

**Coverage Output:**
- HTML coverage report in `coverage/index.html`
- Shows line-by-line coverage status
- Groups by category for easy navigation
- No CI enforcement; used for visibility only

## Test Types

**Unit Tests (Model Tests):**
- Location: `test/models/*.rb`
- Focus: Model methods, validations, associations, scopes
- Setup: Fixtures + direct object creation
- Example: `test/models/player_test.rb` tests Player search configuration
- Scope: Single class in isolation

**Integration Tests (Workflow Tests):**
- Location: `test/integration/*.rb`
- Focus: HTTP workflows (sign in, delete account, etc.)
- Framework: `ActionDispatch::IntegrationTest` with HTTP verbs
- Helpers: Devise authentication helpers (`sign_in`, `assert_redirected_to`)
- Example: `test/integration/users_test.rb` tests user delete flow
- Scope: Multiple classes across HTTP boundary

**System Tests (Browser Tests):**
- Location: `test/system/*.rb`
- Framework: Capybara + Selenium WebDriver
- Focus: Full user workflows in browser
- Helpers: `login_as`, `visit`, `fill_in`, `click_button`, `assert_text`
- Example: `test/system/preferences_test.rb` tests UI interactions
- Scope: Full application flow including JavaScript/Turbo

**Scraping Tests:**
- Location: `test/scraping/*.rb`
- Focus: Web scraping error handling and data extraction
- Philosophy: Smoke tests verify graceful error handling, not detailed HTML parsing
- Mocking: WebMock stubs HTTP responses; VCR records complex interactions
- Pattern: Assert code doesn't crash on bad input, timeouts, network errors
- Example: `test/scraping/scraping_smoke_test.rb` tests ~20 error scenarios

**Task Tests:**
- Location: `test/tasks/*.rb`
- Focus: Rake task execution
- Example: `test/tasks/auto_reserve_tables_test.rb`

## Common Patterns

**Async Testing (Sidekiq):**
- Configured in test_helper: `Sidekiq.logger.level = Logger::WARN`
- Jobs execute immediately in test (not queued)
- No explicit async test patterns visible; jobs tested as synchronous

**Error Testing:**
```ruby
test "handles missing tournament_cc gracefully" do
  tournament = create_scrapable_tournament
  assert_nil tournament.tournament_cc
  
  assert_nothing_raised do
    tournament.scrape_single_tournament_public
  end
end
```

**Database State Testing:**
```ruby
test "creates game plan from existing data" do
  result = @league.reconstruct_game_plan_from_existing_data
  assert result.nil? || result.is_a?(GamePlan)
end
```

**Assertion Pattern for Search:**
```ruby
test "search filters by text field" do
  params = { sSearch: "firstname:Hans" }
  result = SearchService.call(Player.search_hash(params))
  
  assert_includes result, @player
end
```

**Setup/Teardown in Complex Tests:**
```ruby
setup do
  @test_data = create_ko_tournament_with_seedings(16)
  @tournament = @test_data[:tournament]
  @players = @test_data[:players]
end

teardown do
  cleanup_ko_tournament(@test_data) if @test_data
end
```

**HTTP Behavior Testing:**
```ruby
test "user can delete account" do
  sign_in users(:one)
  assert_difference "User.count", -1 do
    delete "/users"
  end
  assert_redirected_to root_path
end
```

**Time-Based Testing:**
```ruby
test "sync_date is updated" do
  record.update!(source_url: "https://...")
  
  assert record.sync_date.present?
  assert record.sync_date >= Time.current - 5.seconds
end
```

## LocalProtector Override in Tests

Special test configuration in `test/test_helper.rb`:
```ruby
# Disable LocalProtector for all test records
module LocalProtectorTestOverride
  def disallow_saving_global_records
    # Skip protection in test environment
    true
  end
end

LocalProtector.prepend(LocalProtectorTestOverride)
```
This allows tests to create "global" (non-region-specific) records freely.

## Custom Test Helpers

**Location:** `test/support/`

**KoTournamentTestHelper** (`test/support/ko_tournament_test_helper.rb`):
- `create_ko_tournament_with_seedings(num_players, attrs)`
- `cleanup_ko_tournament(test_data)`
- Handles complex tournament setup with seedings and players

**ScrapingHelpers** (`test/support/scraping_helpers.rb`):
- `snapshot_name(prefix, *args)` - generate cassette names
- `mock_clubcloud_html(url, html)` - stub HTTP responses
- `read_html_fixture(filename)` - load HTML test data
- `assert_sync_date_updated(record, since:, tolerance:)` - time-based assertions
- `create_scrapable_tournament(attrs)` - tournament factory
- `stub_clubcloud_auth(region_cc)` - auth mocking

**SnapshotHelpers** (`test/support/snapshot_helpers.rb`):
- Helpers for working with VCR snapshots/cassettes
- Enables snapshot-based testing of scraping

**VcrSetup** (`test/support/vcr_setup.rb`):
- Configures VCR for HTTP recording/playback
- Filters sensitive data (passwords, usernames)
- Pretty-prints JSON responses in cassettes

---

*Testing analysis: 2026-04-09*
