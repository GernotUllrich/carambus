# KO Tournament Testing Guide

This document describes the regression test suite for Knockout (KO) tournaments in Carambus.

## Overview

The KO tournament test suite validates:
- Tournament plan generation for various player counts (2-64)
- Bracket structure and game creation
- Player assignment from seedings
- Winner advancement through rounds
- TournamentMonitor KO-specific functionality

## Test Files

### 1. `tournament_plan_ko_test.rb`
Tests the `TournamentPlan.ko_plan(nplayers)` method:
- Plan generation for 16, 24, 32 players
- Bracket structure verification
- Seeding references (`sl.rk1`, `sl.rk2`, etc.)
- Game result references (`16f1.rk1`, `qf2.rk1`, etc.)
- Edge cases and error handling

### 2. `tournament_ko_integration_test.rb`
Full integration tests with actual Tournament, Seeding, and Game models:
- Tournament initialization with KO plans
- Game creation from executor_params
- Player assignment to first-round games
- Winner advancement through bracket rounds
- 24-player pre-qualifying rounds
- Bracket view data

### 3. `tournament_monitor_ko_test.rb`
Tests TournamentMonitor-specific KO functionality:
- `ko_ranking()` method for resolving player references
- Game creation flow
- Table assignment
- State transitions
- Error handling

## Running the Tests

### Run All KO Tests

```bash
# Using rake task
cd /Users/gullrich/DEV/carambus/carambus_bcw
bin/rails test:ko_tournaments

# Or directly
ruby test/ko_tournament_test_runner.rb

# Individual test files
bin/rails test test/models/tournament_plan_ko_test.rb
bin/rails test test/models/tournament_ko_integration_test.rb
bin/rails test test/models/tournament_monitor_ko_test.rb
```

### Run with Coverage

```bash
COVERAGE=true bin/rails test:ko_tournaments
```

### Run Specific Test

```bash
# Run one test class
bin/rails test test/models/tournament_plan_ko_test.rb

# Run one specific test
bin/rails test test/models/tournament_plan_ko_test.rb:12
```

## Utility Tasks

### Generate a KO Plan

```bash
bin/rails ko:generate_plan[24]
```

### Inspect Tournament Structure

```bash
bin/rails ko:inspect[17405]
```

This will show:
- Tournament details
- Seedings count
- Tournament plan info
- All games grouped by round
- Player assignments

### Test Your Tournament[17405]

```bash
bin/rails ko:test_tournament_17405
```

This task:
1. Loads Tournament[17405]
2. Assigns correct KO plan if missing
3. Initializes TournamentMonitor
4. Creates all games
5. Shows first round matchups

## Test Strategy

### Unit Tests (tournament_plan_ko_test.rb)
- Fast, isolated tests
- No database dependencies beyond fixtures
- Tests plan generation logic
- Validates data structures

### Integration Tests (tournament_ko_integration_test.rb)
- Tests full workflow
- Creates real database records
- Tests interactions between models
- Validates game flow and winner advancement

### Component Tests (tournament_monitor_ko_test.rb)
- Tests TournamentMonitor behavior
- Smaller than integration tests
- Focuses on KO-specific methods

## Expected Results

For a 24-player KO tournament:
- **23 total games** (single elimination formula: n-1)
- **8 pre-qualifying games** (32f1-32f8): 24→16 players
- **8 round of 16 games** (16f1-16f8): 16→8 players
- **4 quarterfinal games** (qf1-qf4): 8→4 players
- **2 semifinal games** (hf1-hf2): 4→2 players
- **1 final game** (fin): 2→1 winner

### Game Naming Convention

- `32f<n>` = 32-final (pre-qualifying, when needed)
- `16f<n>` = 16-final (round of 16)
- `qf<n>` = Quarterfinal
- `hf<n>` = Semifinal (Halbfinale)
- `fin` = Final

### Player Reference Format

- `sl.rk<n>` = Seeding list rank N (e.g., `sl.rk1` = first seed)
- `<game>.rk1` = Winner of game (e.g., `16f1.rk1`)
- `<game>.rk2` = Loser of game (e.g., `qf2.rk2`)

## Debugging in RubyMine

### Set Breakpoints

1. **TournamentMonitorSupport#do_reset_tournament_monitor** (line ~620)
   - Watch games being created from executor_params
   
2. **TournamentMonitor#ko_ranking** (line ~331)
   - See how player references are resolved
   
3. **TournamentPlan.ko_plan** (line ~81)
   - Understand bracket generation

### Debug Session Example

```ruby
# In RubyMine Debug Console
t = Tournament.find(17405)
tm = t.tournament_monitor

# Set breakpoint in ko_ranking, then:
tm.ko_ranking("sl.rk1")  # Step through

# Or in do_reset_tournament_monitor:
tm.do_reset_tournament_monitor  # Step through game creation
```

## Common Issues & Solutions

### Issue: No games created
**Cause**: Missing tournament_plan
**Solution**: 
```ruby
t.update!(tournament_plan: TournamentPlan.ko_plan(t.seedings.count))
```

### Issue: Games created but no players
**Cause**: Missing seedings or incorrect seeding positions
**Solution**: 
```ruby
t.seedings.order(:position).each_with_index do |s, i|
  s.update!(position: i + 1)
end
```

### Issue: Winner not advancing
**Cause**: Game results not properly recorded
**Solution**: Ensure game.data includes proper results structure

### Issue: Wrong number of games
**Cause**: Tournament plan doesn't match seeding count
**Solution**: Regenerate plan with correct player count

## Continuous Integration

Add to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run KO Tournament Tests
  run: |
    RAILS_ENV=test bin/rails db:test:prepare
    bin/rails test:ko_tournaments
```

## Contributing

When adding new KO features:

1. Add test cases to appropriate test file
2. Run full test suite: `bin/rails test:ko_tournaments`
3. Ensure all tests pass
4. Update this documentation if needed

## Related Files

- `app/models/tournament_plan.rb` - Plan generation
- `app/models/tournament_monitor.rb` - Tournament execution
- `lib/tournament_monitor_support.rb` - Game creation logic
- `lib/tournament_monitor_state.rb` - State management
- `app/views/tournaments/_bracket.html.erb` - Bracket UI

## Test Data Cleanup

All tests use IDs >= 50,000,000 to avoid conflicts with production data.
The `teardown` method in each test ensures cleanup of:
- Games
- Seedings  
- TournamentMonitors
- Players
- Tournaments

## Performance

Typical test run times:
- `tournament_plan_ko_test.rb`: ~2-5 seconds
- `tournament_ko_integration_test.rb`: ~10-15 seconds  
- `tournament_monitor_ko_test.rb`: ~5-10 seconds
- **Total**: ~20-30 seconds

## Next Steps

1. Run the tests: `bin/rails test:ko_tournaments`
2. Inspect your tournament: `bin/rails ko:inspect[17405]`
3. Test with your data: `bin/rails ko:test_tournament_17405`
4. Debug any failures using RubyMine breakpoints

For questions or issues, refer to:
- KO implementation: `app/models/tournament_plan.rb` (line 81+)
- Test examples: Test files in `test/models/*ko*`
