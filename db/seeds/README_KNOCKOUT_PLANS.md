# Knockout Tournament Plans Seeding

## Overview

This seed script pre-generates all possible KO (Knockout) and DKO (Double Knockout) tournament plans for the Carambus system.

## Why Pre-Generate?

### Before (On-the-fly generation)
- Plans generated dynamically when requested
- LocalProtector conflicts on local servers
- Wasteful regeneration of same brackets
- Performance overhead

### After (Pre-seeded plans)
- All plans exist on API server
- Synced to local servers via normal sync
- No LocalProtector conflicts
- Instant lookup, no generation needed
- Consistent plan IDs across all servers

## Plans Created

### KO Plans
- **Count:** 63 plans
- **Range:** 2-64 players
- **Examples:** KO_2, KO_4, KO_8, KO_16, KO_24, KO_32, KO_64
- **Use case:** Single elimination tournaments

### DKO Plans  
- **Count:** 9 plans
- **Range:** Powers of 2 from 8-64 players
- **Cut points:** 4, 8, 16, 32 (where applicable)
- **Examples:** DKO_8_4, DKO_16_8, DKO_32_16
- **Use case:** Double elimination tournaments

**Total:** 72 pre-generated plans

## Usage

### On API Server (carambus_api)

**One-time setup:**
```bash
cd /path/to/carambus_api
RAILS_ENV=production bin/rails runner db/seeds/knockout_tournament_plans.rb
```

**Or include in main seeds:**
Add to `db/seeds.rb`:
```ruby
load Rails.root.join('db/seeds/knockout_tournament_plans.rb')
```

Then run:
```bash
RAILS_ENV=production bin/rails db:seed
```

### On Local Servers (carambus_bcw, carambus_phat)

**No action needed!** Plans will be automatically synced from API server through the normal sync process.

## Verification

### Check if plans exist:
```bash
bin/rails runner '
  ko_count = TournamentPlan.where("name LIKE ?", "KO_%").where.not("name LIKE ?", "DKO_%").count
  dko_count = TournamentPlan.where("name LIKE ?", "DKO_%").count
  
  puts "KO Plans: #{ko_count}/63"
  puts "DKO Plans: #{dko_count}/9"
  puts "Total: #{ko_count + dko_count}/72"
  
  if ko_count == 63 && dko_count == 9
    puts "✅ All plans present!"
  else
    puts "⚠ Missing plans - run seed script"
  end
'
```

### Test plan lookup:
```bash
bin/rails runner '
  plan = TournamentPlan.ko_plan(24)
  puts "KO_24: #{plan.persisted? ? "✓ Found [#{plan.id}]" : "✗ Missing"}"
  
  plan = TournamentPlan.dko_plan(16, cut_to_sko: 8)
  puts "DKO_16_8: #{plan.persisted? ? "✓ Found [#{plan.id}]" : "✗ Missing"}"
'
```

## Benefits

1. **Performance:** Instant lookup vs generation time
2. **Reliability:** No LocalProtector conflicts
3. **Consistency:** Same plan IDs across all servers
4. **Predictability:** All plans available upfront
5. **Testing:** Easier to write tests with known plan IDs

## Maintenance

### Adding New Plan Types

If you need additional DKO configurations:

1. Edit `db/seeds/knockout_tournament_plans.rb`
2. Add configurations to `dko_configs` array
3. Run the seed script on API server
4. Plans will sync to local servers

### Regenerating Plans

If plan generation logic changes:

1. **Delete existing plans** (API server):
   ```bash
   bin/rails runner '
     TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%").destroy_all
   '
   ```

2. **Run seed script** (API server):
   ```bash
   RAILS_ENV=production bin/rails runner db/seeds/knockout_tournament_plans.rb
   ```

3. **Sync to local servers:** Plans will sync automatically

## Architecture Notes

### Plan Generation Still Available

The `ko_plan` and `dko_plan` methods still support on-the-fly generation as a fallback. However, with seeding:

- **First call:** Returns existing plan (fast lookup)
- **No generation** unless plan doesn't exist
- **Idempotent:** Safe to call multiple times

### LocalProtector Compatibility

With the recent fix (commit 3978abed), the methods now:

1. Check if plan exists
2. Return immediately if persisted (no update attempt)
3. Only generate/save if plan doesn't exist

This prevents LocalProtector conflicts even if plans aren't seeded, but seeding is still recommended for performance and consistency.

## Migration Path

### For Existing Deployments

1. **Run seed script on API server** (production)
2. **Wait for sync** to propagate plans to local servers
3. **Verify** plans on each server
4. **Done!** Existing tournaments continue to work

No downtime or data migration required.

## Date

2026-03-03

## Author

AI Assistant based on user suggestion
