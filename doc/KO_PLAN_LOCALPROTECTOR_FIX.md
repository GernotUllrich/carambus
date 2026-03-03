# KO Plan LocalProtector Fix

## Issue Identified

**Reporter:** User identified that KO TournamentPlans are created on-the-fly during mode selection, and questioned whether LocalProtector would block this on local servers.

**Analysis:** The concern was valid! The `ko_plan` and `dko_plan` methods had a critical flaw.

## The Problem

### Original Code Behavior

```ruby
def self.ko_plan(nplayers)
  plan = TournamentPlan.find_by_name("KO_#{nplayers}")
  plan ||= TournamentPlan.new(name: "KO_#{nplayers}", players: nplayers)
  
  # ... generate bracket structure ...
  
  plan.update(...)  # ← ALWAYS executed, even for existing plans!
  plan
end
```

### Why This Was a Problem

1. **For Existing Plans:**
   - `find_by_name` finds existing plan (e.g., synced from API with ID < 50M)
   - Method builds bracket structure
   - Calls `plan.update(...)` to save changes
   - **LocalProtector blocks update** (ID < 50M, local server, not unprotected)
   - Update fails silently (ActiveRecord::Rollback)
   - Returns potentially stale plan object

2. **For New Plans:**
   - Creates new plan
   - Gets local ID (>= 50M) from sequence
   - Update succeeds (LocalProtector allows local IDs)
   - **Works, but wasteful** (regenerates bracket every time)

### Why It Appeared to Work

In practice, this issue was hidden because:
- Local servers create KO plans with **local IDs** (>= 50M)
- LocalProtector only blocks **global records** (ID < 50M)
- So updates succeeded on local servers

But if global KO plans existed (synced from API), the update would fail!

## The Solution

### Fixed Code

```ruby
def self.ko_plan(nplayers)
  plan = TournamentPlan.find_by_name("KO_#{nplayers}")
  
  # If plan exists and is persisted, return it immediately
  # Don't try to update it (prevents LocalProtector conflicts)
  return plan if plan&.persisted?
  
  plan ||= TournamentPlan.new(name: "KO_#{nplayers}", players: nplayers)
  
  # ... generate bracket structure ...
  
  plan.update(...)  # Only executed for NEW plans
  plan
end
```

### Benefits

1. **LocalProtector Compatible:**
   - Existing plans returned immediately (no update attempted)
   - Works with both global (ID < 50M) and local (ID >= 50M) plans

2. **Idempotent:**
   - Calling `ko_plan(N)` multiple times is safe
   - No unnecessary database updates
   - Plan structure is stable once created

3. **Performance:**
   - Avoids regenerating bracket structure for existing plans
   - Reduces database load

## Verification Tests

### Test 1: Existing Plan (No Update)
```ruby
plan = TournamentPlan.ko_plan(16)  # Existing plan
# Result: ✓ Returned immediately, updated_at unchanged
```

### Test 2: New Plan (Created and Saved)
```ruby
plan = TournamentPlan.ko_plan(20)  # New plan
# Result: ✓ Created with local ID, saved successfully
```

### Test 3: Idempotency
```ruby
plan1 = TournamentPlan.ko_plan(20)
plan2 = TournamentPlan.ko_plan(20)
# Result: ✓ Same plan, no update, updated_at unchanged
```

## Impact

### Before Fix
- ❌ Would fail if global KO plans existed (from API sync)
- ❌ Wastefully regenerated plans on every call
- ❌ Potential for stale data if update silently failed

### After Fix
- ✅ Works with global plans on local servers
- ✅ Efficient - only generates plan once
- ✅ Idempotent - safe to call multiple times
- ✅ No LocalProtector conflicts

## Files Modified

1. **`app/models/tournament_plan.rb`**
   - `ko_plan` method: Added early return for existing plans
   - `dko_plan` method: Added early return for existing plans

## Related Work

This fix complements the earlier regex bugfix (commit bc5bfbb4) which fixed multi-digit rank number support. Together, these fixes make KO tournaments fully functional for any number of players (2-64).

## Date

2026-03-03

## Commit

`3978abed` - "Fix: Prevent ko_plan/dko_plan from trying to update existing plans"
