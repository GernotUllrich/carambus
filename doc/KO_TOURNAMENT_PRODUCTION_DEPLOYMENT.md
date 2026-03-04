# KO Tournament Fix - Production Deployment Checklist

## Problem Summary

Pure KO tournaments (KO_2 to KO_64) had all games assigned to round "r1" instead of using separate round numbers (r1, r2, r3, etc.). This caused all games to compete for the same placement slots, preventing proper tournament progression.

## Fix Summary

**Commits:**
- `3fdeb92b` - Initial fix for executor_params generation
- `1968b869` - Corrected round number formula: `round_no = cl - lev + 2`
- `c41b75cc` - Added production regeneration script

**Files changed:**
- `app/models/tournament_plan.rb` - Fixed `ko_plan` and `dko_plan` methods

## Production Deployment Steps

### 1. Deploy Code Changes

On your production server:

```bash
# Pull latest code
git pull origin master

# Restart application (depending on your setup)
systemctl restart puma    # or whatever your app server is
# OR
touch tmp/restart.txt     # for Passenger
```

### 2. Clean Up Orphaned PaperTrail Versions (API Server Only)

**⚠️ CRITICAL:** If old plans were deleted with `.delete` (bypassing PaperTrail), you need to clean up orphaned version records first.

```bash
# SSH to production API server
ssh production-api-server

# Navigate to app directory
cd /path/to/carambus

# Run cleanup script to remove orphaned versions
RAILS_ENV=production bin/rails runner db/seeds/cleanup_ko_plans_versions.rb
```

This script:
- Finds PaperTrail versions for KO/DKO plans that no longer exist
- Deletes those orphaned versions
- Has confirmation prompts for safety

### 3. Regenerate TournamentPlans on Production API Server

**⚠️ IMPORTANT:** This must be run on the **API server** (the master database where TournamentPlans are stored).

**✅ NOTE:** The script uses `.destroy` (not `.delete`) to ensure:
- PaperTrail versioning is preserved
- Synchronization to local servers works correctly
- Audit trail is maintained

```bash
# Still on production API server
cd /path/to/carambus

# Run the regeneration script
RAILS_ENV=production bin/rails runner db/seeds/regenerate_ko_plans_production.rb
```

The script will:
1. Show a confirmation prompt (press ENTER to continue)
2. Delete all existing KO/DKO plans (KO_2 through KO_64, plus 10 DKO configurations)
3. Regenerate 73 tournament plans with correct round numbers
4. Verify that the plans are correct

**Expected output:**
```
✓ Deleted 73 old plans
✓ Created 63 KO plans
✓ Created 10 DKO plans

KO_31 Round distribution:
  Round 1: 15 games
  Round 2:  8 games
  Round 3:  4 games
  Round 4:  2 games
  Round 5:  1 games

✅ VERIFICATION PASSED!
```

### 4. Clean Up Local Servers (BCW, PHAT, etc.)

If local servers have already synced the old (incorrect) plans, they need manual cleanup:

```bash
# SSH to each local server (BCW, PHAT, etc.)
ssh bcw-server

cd /path/to/carambus

# Run local cleanup script
RAILS_ENV=production bin/rails runner db/seeds/cleanup_local_ko_plans.rb
```

**Why .delete is OK here:**
- Local servers have copies, not authoritative records
- They're already out of sync due to original .delete on API
- We don't want local versions conflicting with API
- New plans will sync from API automatically

**Alternative:** Regenerate plans locally (same as API server):

```bash
# On local server
RAILS_ENV=production bin/rails runner db/seeds/regenerate_ko_plans_production.rb
```

### 5. Impact on Active Tournaments

**⚠️ CRITICAL:** Any tournaments currently using KO/DKO plans will need to be **re-initialized**:

1. Tournament monitor must be reset
2. Tournament must be re-initialized (this will use the new plan)
3. Players will need to be re-added
4. Games will be regenerated with correct round numbers

**Alternative:** If you have active tournaments that cannot be interrupted:
- Old tournaments will continue to work with the old (incorrect) logic
- Only **NEW** KO tournaments created after this deployment will use the corrected plans

### 6. Verification Checklist

After deployment, verify on production:

```bash
# Check a sample plan
RAILS_ENV=production bin/rails runner '
plan = TournamentPlan.find_by(name: "KO_31")
params = JSON.parse(plan.executor_params)
puts "8f1 round: #{params["8f1"].keys.first}"
puts "qf1 round: #{params["qf1"].keys.first}"
'

# Expected output:
# 8f1 round: r2
# qf1 round: r3
```

✅ If you see `r2` and `r3`, the fix is working correctly!  
❌ If you see `r1` and `r1`, something went wrong.

## What Changed

### Before (Incorrect):
```ruby
16f, 8f, qf, hf, fin → ALL used "r1"
→ All games compete for placements["round1"] slots
→ Tournament progression blocked
```

### After (Correct):
```ruby
16f → r1  (first round - played first)
8f  → r2  (second round)
qf  → r3  (third round)
hf  → r4  (fourth round)
fin → r5  (final round)

→ Each round has separate placement slots
→ Tournament progression works automatically
→ Matches behavior of group tournaments with finals
```

## Rollback Plan

If issues occur and you need to rollback:

1. Revert the code commits:
   ```bash
   git revert c41b75cc 1968b869 3fdeb92b
   git push origin master
   ```

2. Regenerate plans with old logic:
   ```bash
   # Old plans will be restored from git history
   # Re-run seeds if needed
   ```

3. Note: Any tournaments created with the NEW plans will need to be reset

## Testing

After deployment, create a test KO tournament:

1. Create tournament with 8-16 players, mode KO
2. Initialize tournament
3. Play first round games (verify they get placed)
4. Complete first round games
5. **Verify:** Second round games should automatically appear on tables
6. **Expected:** Winners flow automatically to next round

## Support

If issues occur during deployment:
- Check application logs for errors
- Verify database connectivity between servers
- Ensure TournamentPlan IDs are synchronized across servers
- Contact development team if verification fails

## Related Documentation

- `doc/KO_TOURNAMENT_COMPLETE_SOLUTION.md` - Full technical details
- `db/seeds/knockout_tournament_plans.rb` - Original seed script (development)
- `db/seeds/README_KNOCKOUT_PLANS.md` - Seed script documentation
