# API Server Cable Optimization

## Overview

This document describes the optimization made to prevent unnecessary ActionCable broadcasts on the API Server.

## Problem

The Carambus codebase is shared between two types of servers:

- **API Server**: Central data source for scraping and data distribution. Does NOT run scoreboards.
- **Local Servers**: Run on Raspberry Pi devices at clubs. DO run scoreboards and tournament displays via ActionCable.

Previously, both server types would enqueue broadcast jobs and send ActionCable messages even when no clients were subscribed (API Server), causing unnecessary processing overhead.

## Solution

Added dynamic guards based on server type detection using `ApplicationRecord.local_server?`, which checks if `Carambus.config.carambus_api_url.present?`:

- **Local Server**: Has `carambus_api_url` configured → broadcasts ARE needed
- **API Server**: Does NOT have `carambus_api_url` configured → broadcasts are SKIPPED

## Changes Made

### 1. Model Callbacks

**File**: `app/models/table_monitor.rb`

Added guard at the beginning of `after_update_commit` callback:

```ruby
unless ApplicationRecord.local_server?
  Rails.logger.info "🔔 Skipping callbacks (API Server - no scoreboards)"
  return
end
```

This prevents enqueuing of broadcast jobs when table monitors are updated on the API Server.

### 2. Broadcast Jobs

Added guards to all jobs that broadcast to ActionCable channels:

**Files Modified:**
- `app/jobs/table_monitor_job.rb`
- `app/jobs/table_monitor_clock_job.rb`
- `app/jobs/tournament_monitor_update_results_job.rb`

Each job now exits early on API Server:

```ruby
def perform(*args)
  unless ApplicationRecord.local_server?
    Rails.logger.info "📡 [JobName] skipped (API Server - no scoreboards)"
    return
  end
  # ... rest of job logic
end
```

### 3. Reflexes

**File**: `app/reflexes/table_monitor_reflex.rb`

Added guard to the `key` method that broadcasts number pad input:

```ruby
unless ApplicationRecord.local_server?
  Rails.logger.info "🔔 TableMonitorReflex skipped (API Server - no scoreboards)"
  morph :nothing
  return
end
```

### 4. Channels

**No Changes Required**

The channel files themselves (`TableMonitorChannel`, `TournamentMonitorChannel`) do NOT need modification:
- Channels are just WebSocket endpoints
- They're harmless if no clients subscribe
- Keeping them allows the shared codebase to work on both server types

## Benefits

1. **Reduced CPU Usage**: API Server no longer renders HTML partials for non-existent scoreboards
2. **Reduced Redis Load**: No unnecessary ActionCable messages in Redis queues
3. **Cleaner Logs**: API Server logs don't fill up with scoreboard broadcast messages
4. **No Breaking Changes**: Local servers continue to work exactly as before
5. **Shared Codebase**: Both server types can still use the same code

## Server Type Detection

The detection is based on the existing `ApplicationRecord.local_server?` method:

```ruby
def self.local_server?
  Carambus.config.carambus_api_url.present?
end
```

- Returns `true` when server has an API URL configured (= is a Local Server)
- Returns `false` when server has NO API URL configured (= is the API Server)

## Testing

To verify the optimization is working:

### On API Server

```ruby
# In Rails console
ApplicationRecord.local_server?
# => false

# Trigger a table monitor update
tm = TableMonitor.first
tm.touch

# Check logs - should see:
# "🔔 Skipping callbacks (API Server - no scoreboards)"
```

### On Local Server

```ruby
# In Rails console
ApplicationRecord.local_server?
# => true

# Trigger a table monitor update
tm = TableMonitor.first
tm.touch

# Check logs - should see:
# "🔔 ========== after_update_commit TRIGGERED =========="
# "📡 ========== TableMonitorJob START =========="
```

## Related Files

- `app/models/application_record.rb` - Contains `local_server?` method
- `app/models/table_monitor.rb` - Model with guarded callbacks
- `app/jobs/table_monitor_job.rb` - Main broadcast job
- `app/jobs/table_monitor_clock_job.rb` - Timer broadcast job
- `app/jobs/tournament_monitor_update_results_job.rb` - Tournament results job
- `app/reflexes/table_monitor_reflex.rb` - Interactive number pad reflex
- `app/channels/table_monitor_channel.rb` - WebSocket channel (unchanged)
- `app/channels/tournament_monitor_channel.rb` - WebSocket channel (unchanged)

## Future Considerations

If additional broadcast jobs are added in the future, remember to add the same guard:

```ruby
def perform(*args)
  unless ApplicationRecord.local_server?
    Rails.logger.info "📡 [JobName] skipped (API Server - no broadcasts needed)"
    return
  end
  # ... job logic
end
```

## Rollback

If this optimization needs to be reverted, simply remove the guard clauses added in this change. The channels and jobs will work as they did before.

---

**Version:** 1.0  
**Date:** December 2024  
**Status:** Implemented
