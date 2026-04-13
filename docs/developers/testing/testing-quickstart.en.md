# Testing Carambus - Quick Start

This document shows how to use and extend the tests for Carambus.

## Get Started Immediately

```bash
# 1. Install dependencies
bundle install

# 2. Validate test setup
bin/rails test:validate

# 3. Run tests
bin/rails test

# 4. Only critical tests (fast)
bin/rails test:critical
```

## What is Tested?

### Already Implemented

1. **LocalProtector** - Data protection for API data
   - Prevents accidental overwriting of API server data
   - Critical for multi-tenant architecture

2. **SourceHandler** - Sync-Date Tracking
   - Tracks when data was last fetched from ClubCloud
   - Foundation for change detection

3. **Change Detection** - Framework in place
   - Tests ready for ClubCloud HTML fixtures
   - VCR configured for HTTP recording

### Next Steps

1. **Collect ClubCloud HTML Fixtures**
   ```bash
   # Use browser DevTools or:
   curl "https://nbv.clubcloud.de/..." > test/fixtures/html/nbv_tournament.html
   ```

2. **Fill scraping tests with fixtures**
   - Tests are prepared (with `skip`)
   - Add HTML fixtures
   - Remove `skip` and make tests green

3. **Integration Tests**
   - Test complete workflows
   - Tournament creation through result upload

## Test Types

### Model Tests (Unit Tests)

Test individual models and concerns:

```bash
# All model tests
bin/rails test:models

# Only concerns
bin/rails test:concerns
```

**Example:**
```ruby
test "LocalProtector prevents saving API records" do
  tournament = Tournament.new(id: 1000) # API record
  
  # Should not save in production (allowed in test env)
  assert_equal true, tournament.disallow_saving_global_records
end
```

### Scraping Tests

Test ClubCloud scraping with VCR:

```bash
bin/rails test:scraping
```

**Example:**
```ruby
test "scraping extracts tournament details" do
  VCR.use_cassette("nbv_tournament") do
    tournament.scrape_single_tournament_public
    
    assert_not_nil tournament.title
    assert_not_nil tournament.date
  end
end
```

### Integration Tests

Test complete workflows:

```bash
bin/rails test test/integration/
```

## Useful Commands

```bash
# With coverage
COVERAGE=true bin/rails test
open coverage/index.html

# Only critical tests (fast)
bin/rails test:critical

# Test statistics
bin/rails test:stats

# Single test
bin/rails test test/concerns/local_protector_test.rb

# Test by name
bin/rails test test/concerns/local_protector_test.rb -n test_prevents_modification

# Verbose
bin/rails test --verbose

# Re-record VCR cassettes
bin/rails test:rerecord_vcr
```

## Writing a New Test

### 1. Create test file

```bash
# Model test
touch test/models/my_model_test.rb

# Scraping test
touch test/scraping/my_scraper_test.rb
```

### 2. Test template

```ruby
# frozen_string_literal: true

require "test_helper"

class MyModelTest < ActiveSupport::TestCase
  setup do
    @model = my_models(:fixture_name)
  end
  
  test "descriptive name of what is tested" do
    # Arrange - Setup
    expected_value = "something"
    
    # Act - Execute
    result = @model.some_method
    
    # Assert - Verify
    assert_equal expected_value, result,
                 "Helpful message if assertion fails"
  end
end
```

### 3. Create fixtures (if needed)

```yaml
# test/fixtures/my_models.yml
fixture_name:
  id: 50_000_001  # Local ID (>= 50M)
  name: "Test Name"
  created_at: <%= 1.day.ago %>
```

### 4. Run test

```bash
bin/rails test test/models/my_model_test.rb
```

## VCR for Scraping Tests

VCR records and replays HTTP requests:

### Creating a cassette

```ruby
test "scraping works" do
  VCR.use_cassette("descriptive_name") do
    # First run: Real HTTP request is recorded
    # Subsequent runs: Stored response is used
    result = some_http_request
    
    assert_something(result)
  end
end
```

### Updating a cassette

```bash
# Delete cassette
rm test/snapshots/vcr/descriptive_name.yml

# Re-run test - records new response
bin/rails test test/scraping/...
```

### Sensitive data

VCR automatically filters:
- Usernames → `<CC_USERNAME>`
- Passwords → `<CC_PASSWORD>`

Configuration in `test/support/vcr_setup.rb`.

## Coverage Reports

```bash
# Tests with coverage
COVERAGE=true bin/rails test

# Open report
open coverage/index.html
```

**Coverage goals:**
- 60%+ overall coverage (realistic target)
- 90%+ for critical concerns (LocalProtector, SourceHandler)
- 70%+ for scraping code
- Coverage is informational, not dogma!

## Debugging

### Using Pry

```ruby
test "complex scenario" do
  require 'pry'; binding.pry
  # Test pauses here, interactive shell
end
```

### Activating Logger

```ruby
test "with logging" do
  Rails.logger.level = :debug
  # ... test code
end
```

### Inspecting test DB

```bash
# Test DB console
rails db -e test

# View schema
bin/rails db:schema:dump RAILS_ENV=test
```

## CI/CD

Tests run automatically on GitHub:

- **Push to main/develop** → All tests
- **Pull Request** → All tests
- **Lint Check** → Standard & Brakeman

Badge in README:
```markdown
![Tests](https://github.com/USER/REPO/actions/workflows/tests.yml/badge.svg)
```

## Further Documentation

- **Test README** - Detailed guide
- **Testing Strategy** - Concept & philosophy
- **Snapshots README** - VCR & snapshots

## FAQ

### Q: Why do tests fail because of migrations?

```bash
# Prepare test DB
bin/rails db:test:prepare

# Or with StrongMigrations
SAFETY_ASSURED=true bin/rails db:test:prepare
```

### Q: How do I test with the real API database?

The test strategy uses the API database as inspiration for fixtures.
For tests, we use isolated test data (ID >= 50M).

### Q: Why are many scraping tests marked with `skip`?

The tests are prepared, but we still need:
1. Real ClubCloud HTML fixtures
2. VCR cassettes from real requests

**You can help:**
1. Save ClubCloud HTML
2. Place in `test/fixtures/html/`
3. Remove `skip`
4. Make test green

### Q: Do I need to write tests for every small change?

**No!** Pragmatic approach:
- Tests for new critical features
- Tests when a bug is found (regression prevention)
- Tests for scraping (external dependencies)
- Not for every getter/setter

### Q: How do I update tests when ClubCloud changes?

1. Tests fail (good!)
2. Delete VCR cassettes: `bin/rails test:rerecord_vcr`
3. Re-run tests
4. Adapt scraping code if needed
5. Commit with description of the ClubCloud change

## Best Practices

1. **One test, one concept**
   - Test one thing per test
   - Descriptive names

2. **Arrange-Act-Assert**
   - Setup → Execution → Verification
   - Clearly separated phases

3. **Realistic fixtures**
   - IDs >= 50M for local data
   - Valid relationships

4. **Snapshots for external APIs**
   - VCR for HTTP requests
   - Tests run offline & fast

5. **Skip instead of delete**
   - Mark incomplete tests with `skip`
   - Don't simply delete them

## Next Steps

1. Validate setup: `bin/rails test:validate`
2. Run existing tests: `bin/rails test`
3. Collect ClubCloud HTML fixtures
4. Complete scraping tests
5. Write integration tests

---

**Questions?** See test/README.md or Testing Strategy

**Contributing?** Pull requests for tests are very welcome!
