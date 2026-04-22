# Test Database Setup Guide

This guide explains how to configure and run tests in complete isolation from your development database.

> **Ergänzend:** [SCENARIO_TESTING.md](SCENARIO_TESTING.md) erklärt die scenario-
> spezifischen Fallen (cable.yml, skip_unless_api_server, Config-Pollution).

## Overview

The test suite uses **separate test databases** that are:
- ✅ Completely isolated from development/production data
- ✅ Reset before each test run
- ✅ Use fixtures for predictable test data
- ✅ Automatically rolled back after each test

## Test Database Names

Each scenario has its own test database:

- `carambus_master_test`
- `carambus_bcw_test`
- `carambus_api_test`
- `carambus_phat_test`

## Initial Setup

### 1. Setup All Test Databases

```bash
# From any scenario directory
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
bin/rails test:setup_all
```

This will:
- Create test databases for all scenarios
- Load the schema
- Be ready for testing

### 2. Setup Single Scenario

```bash
# For a specific scenario
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
RAILS_ENV=test bin/rails db:create db:schema:load
```

## Running Tests

### Run All KO Tests

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
bin/rails test:ko_tournaments
```

### Run Individual Test Files

```bash
bin/rails test test/models/tournament_plan_ko_test.rb
bin/rails test test/models/tournament_ko_integration_test.rb
bin/rails test test/models/tournament_monitor_ko_test.rb
```

### Run Specific Test

```bash
# Run a single test by line number
bin/rails test test/models/tournament_plan_ko_test.rb:12
```

### Run with Coverage

```bash
COVERAGE=true bin/rails test:ko_tournaments
```

## Test Data Isolation

### ID Ranges

All test data uses IDs >= **50,000,000** to avoid conflicts:

```ruby
TEST_ID_BASE = 50_000_000

# Example:
Tournament.create!(id: 50_000_100, ...)  # Test data
Player.create!(id: 50_001_001, ...)      # Test data
```

### Transactional Tests

All tests use `use_transactional_tests = true` (Rails default), which means:

1. **Before each test**: Database transaction starts
2. **Test runs**: Creates/modifies data
3. **After test**: Transaction rolls back (all changes discarded)
4. **Result**: Clean slate for next test

### Helper Module

Tests use `KoTournamentTestHelper` for common operations:

```ruby
class MyTest < ActiveSupport::TestCase
  include KoTournamentTestHelper
  
  setup do
    @test_data = create_ko_tournament_with_seedings(16)
    @tournament = @test_data[:tournament]
  end
  
  teardown do
    cleanup_ko_tournament(@test_data)
  end
end
```

## Fixtures

Fixtures provide baseline test data in `test/fixtures/*.yml`:

- `seasons.yml` - Test seasons
- `disciplines.yml` - Test disciplines
- `regions.yml` - Test regions
- `tournaments.yml` - Sample tournaments

Fixtures use IDs >= 50,000,000 and are loaded before tests.

## Database Maintenance

### Reset Test Database

```bash
# Drop and recreate (fresh start)
RAILS_ENV=test bin/rails test:reset
```

### Clean Test Data

```bash
# Remove test data but keep schema
RAILS_ENV=test bin/rails test:clean
```

### Verify Setup

```bash
# Check database is properly configured
RAILS_ENV=test bin/rails test:verify
```

## Troubleshooting

### Error: "test database is not configured"

**Solution**: Add test configuration to `config/database.yml`:

```yaml
test:
  <<: *default
  database: carambus_<scenario>_test
```

Then run:
```bash
RAILS_ENV=test bin/rails db:create db:schema:load
```

### Error: "Database does not exist"

**Solution**:
```bash
RAILS_ENV=test bin/rails db:create
RAILS_ENV=test bin/rails db:schema:load
```

### Tests Interfere With Each Other

**Cause**: Transactional tests disabled or fixtures have ID conflicts

**Solution**:
1. Ensure `self.use_transactional_tests = true` in test class
2. Check fixture IDs don't overlap
3. Use helper methods to generate unique IDs

### Slow Test Performance

**Cause**: Creating too much test data

**Solution**:
1. Use smaller player counts in tests (8 instead of 24)
2. Reuse fixtures where possible
3. Mock external dependencies
4. Use `bin/rails test:ko_tournaments` instead of full suite

### Foreign Key Violations

**Cause**: Deleting records in wrong order

**Solution**: Use `cleanup_ko_tournament()` helper which deletes in correct order:
1. Games
2. Seedings
3. TournamentMonitor
4. Tournament
5. Players

## Best Practices

### ✅ DO

- Use fixtures for static data (seasons, regions, disciplines)
- Create test data dynamically for entities under test
- Use helper methods (`create_ko_tournament_with_seedings`)
- Use transactional tests
- Use IDs >= 50,000,000 for test data
- Clean up in teardown (even though transaction rollback handles it)

### ❌ DON'T

- Hard-code IDs that might conflict
- Depend on database state from previous tests
- Modify fixture data
- Create data outside transactions
- Use development database for tests

## CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
test:
  steps:
    - name: Setup Database
      run: RAILS_ENV=test bin/rails db:create db:schema:load
    
    - name: Run KO Tests
      run: bin/rails test:ko_tournaments
```

## Configuration Files

### database.yml

```yaml
test:
  <<: *default
  database: carambus_<scenario>_test
```

### test_helper.rb

```ruby
# Loads test support files
Dir[Rails.root.join('test', 'support', '**', '*.rb')].each { |f| require f }
```

## Example: Complete Test Run

```bash
# 1. Setup (once)
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
RAILS_ENV=test bin/rails db:create db:schema:load

# 2. Run tests (repeatable)
bin/rails test:ko_tournaments

# 3. Verify everything works
RAILS_ENV=test bin/rails test:verify
```

Expected output:
```
Running 40 tests in parallel...

✓ tournament_plan_ko_test.rb (14 tests)
✓ tournament_ko_integration_test.rb (10 tests)
✓ tournament_monitor_ko_test.rb (16 tests)

40 tests, 0 failures, 0 errors
```

## Summary

- **Test databases are separate** - No interference with development
- **Transactions provide isolation** - Each test starts clean
- **Fixtures provide baseline** - Consistent test data
- **Helpers reduce boilerplate** - Reusable test code
- **IDs >= 50M avoid conflicts** - Safe ID range

For questions, see `test/KO_TOURNAMENT_TESTING.md` or the test files themselves.
