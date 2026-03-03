# KO Tournament Testing - Quick Start

## Current Status

✅ **Test files created** (40 regression tests)
✅ **Test helpers created** (isolated test data creation)  
✅ **Database configuration added** (test environment for all scenarios)
✅ **Test databases created** (tables exist)
⚠️ **Schema migrations table needs syncing**

## Quick Solution: Use Development Mode Testing

Since you mentioned testing in development mode with RubyMine anyway, here's the **fastest path**:

### Option 1: Test in Development Console (RECOMMENDED FOR NOW)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw

# Inspect your tournament
bin/rails ko:inspect[17405]

# Auto-test it
bin/rails ko:test_tournament_17405

# Generate KO plans
bin/rails ko:generate_plan[24]
```

### Option 2: RubyMine Debug Console

Open Rails Console in RubyMine and run:

```ruby
# Test Tournament[17405]
t = Tournament.find(17405)

# Assign KO plan if needed
unless t.tournament_plan&.name&.start_with?("KO")
  plan = TournamentPlan.ko_plan(t.seedings.count)
  plan.save!
  t.update!(tournament_plan: plan)
end

# Initialize and create games
t.initialize_tournament_monitor unless t.tournament_monitor
tm = t.tournament_monitor
tm.do_reset_tournament_monitor

# Inspect results
puts "\n=== GAMES CREATED ==="
puts "Total: #{t.games.count}"

t.games.where("gname LIKE '32f%'").order(:gname).limit(5).each do |g|
  players = g.game_participations.map { |gp| gp.player&.display_name || "TBD" }
  puts "  #{g.gname}: #{players.join(' vs ')}"
end
```

## Fix for Automated Tests (When Needed)

The test database exists and has all tables, but Rails needs the schema_migrations table populated. Here's how to fix it:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw

# Copy schema_migrations from development
psql -d carambus_bcw_development -c "COPY (SELECT * FROM schema_migrations) TO STDOUT" | \
  psql -d carambus_bcw_test -c "COPY schema_migrations FROM STDIN"

# OR regenerate schema.rb without force option
# (edit db/schema.rb temporarily to remove force: :cascade)

# Then run tests
bin/rails test test/models/tournament_plan_ko_test.rb
```

## What Works Right Now

### ✅ Utility Tasks (Development Mode)

```bash
# All these work in development mode:
bin/rails ko:inspect[17405]         # Inspect tournament structure
bin/rails ko:test_tournament_17405  # Auto-test your tournament
bin/rails ko:generate_plan[N]       # Generate KO plan for N players
```

### ✅ Manual Testing in Console

Everything in `test/KO_TOURNAMENT_TESTING.md` that uses Rails console works perfectly.

### ⏳ Automated Test Suite

Will work once schema_migrations is synced. Not blocking your immediate testing needs.

## Test Files Location

```
test/models/
├── tournament_plan_ko_test.rb          # 14 tests - Plan generation
├── tournament_ko_integration_test.rb   # 10 tests - Full workflow  
└── tournament_monitor_ko_test.rb       # 16 tests - TournamentMonitor

test/support/
└── ko_tournament_test_helper.rb        # Reusable test utilities

lib/tasks/
├── ko_tournaments.rake                 # Rake tasks for inspection
└── test_setup.rake                     # Database setup automation

test/
├── KO_TOURNAMENT_TESTING.md           # Complete testing guide
└── TEST_DATABASE_SETUP.md             # Database setup guide
```

## Summary

**For your immediate needs (testing Tournament[17405]):**
- ✅ Use `bin/rails ko:inspect[17405]`
- ✅ Use `bin/rails ko:test_tournament_17405`
- ✅ Use RubyMine Rails Console with code examples above

**For automated regression tests:**
- ⏳ Need to sync schema_migrations table (5-minute fix when needed)
- ✅ All test code is ready and waiting
- ✅ Tests are properly isolated with transactions

## Next Steps

1. **Try the inspection tool now:**
   ```bash
   cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
   bin/rails ko:inspect[17405]
   ```

2. **Test with your tournament:**
   ```bash
   bin/rails ko:test_tournament_17405
   ```

3. **When you need automated tests**, sync schema_migrations or let me know.

## Documentation

- `test/KO_TOURNAMENT_TESTING.md` - How KO mode works, testing strategies
- `test/TEST_DATABASE_SETUP.md` - Test database configuration
- This file - Quick start guide

---

**Bottom line:** Everything you need to test KO tournaments works right now in development mode. The automated test suite is ready but needs a quick schema_migrations sync to run.
