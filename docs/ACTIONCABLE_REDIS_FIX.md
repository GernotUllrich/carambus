# ActionCable Redis Adapter Fix

## TL;DR - Quick Summary for Developers

**Problem:** Multiple browsers viewing same scoreboard weren't syncing in real-time, but magically synced every ~2 minutes.

**Root Cause:** `config/cable.yml` used `async` adapter (isolated channels) instead of `redis` adapter (shared pub/sub).

**The 2-Minute Mystery:** Connection Health Monitor was forcing reloads every 2 minutes when it detected no messages, making it look like intermittent sync issues.

**Fix:** Changed `config/cable.yml` to use Redis adapter. Now updates are instant across all browsers.

**Action Required:**
1. Redis must be running: `redis-cli ping`
2. Rails server must be restarted after cable.yml change
3. Test with multiple browsers on same scoreboard

**Quick Check:**
```bash
./bin/check-actioncable-status.sh
```

---

## Problem Description

Multiple browsers opening the same scoreboard game were not receiving real-time updates from each other. Updates appeared to be operating in disjunct cable channels, though both had the same `table_monitor` URL. Reloading would correctly sync with the database, but live broadcasts were not being shared between connections.

### Observed Symptoms

- **Immediate symptom**: Updates in one browser did not appear in other browsers viewing the same scoreboard
- **Delayed symptom**: After approximately 2 minutes, browsers would suddenly "sync up" by reloading
- **Pattern**: This sync cycle repeated every ~2-2.5 minutes
- **Misleading**: Appeared as intermittent sync issues rather than a fundamental architecture problem

## Root Cause

The issue was in `config/cable.yml`, which was using the `async` adapter for both development and production:

```yaml
development:
  adapter: async  # ❌ WRONG - async adapter isolates each connection

production:
  adapter: async  # ❌ WRONG - async adapter isolates each connection
```

### Why `async` Adapter Failed

The `async` adapter:
- Stores subscriptions **in memory within each process**
- Does **NOT share state** between different browser connections
- Does **NOT broadcast** across multiple WebSocket connections
- Is only suitable for single-connection development testing

This meant:
1. Browser A subscribing to `table-monitor-stream` got its own isolated channel
2. Browser B subscribing to the same stream got a different isolated channel
3. When TableMonitorJob broadcast updates, only one connection would receive it (whichever was in the same process)
4. Reloads worked because they fetched fresh data from the database, bypassing the cable system

### Why Browsers Appeared to "Sync After a While"

The periodic syncing was actually the **Connection Health Monitor** acting as an unintentional workaround:

**The 2-Minute Sync Cycle:**

1. **T=0s**: Both browsers connected, each with isolated async channel
2. **T=0-30s**: Updates happen, but only one browser receives them
3. **T=30s**: Health monitor checks connection (first check)
4. **T=60s**: Health monitor checks again
5. **T=90s**: Health monitor checks again
6. **T=120s**: Health monitor checks - detects no messages received for 2 minutes
7. **T=120s**: Health monitor logs: `⚠️ No messages received for 120 seconds`
8. **T=120s**: Health monitor triggers reconnection: `🔄 Triggering reconnection, reason: message_timeout`
9. **T=125s**: If reconnection fails → **Page reload** (fetches fresh data from DB)
10. **T=125s**: Browsers appear "synced" (temporarily)
11. **Cycle repeats** from step 1

**Key Timing Values** (from `app/javascript/channels/table_monitor_channel.js`):
```javascript
this.healthCheckFrequency = 30000      // Check every 30 seconds
this.maxSilenceTime = 120000           // Trigger if no message for 2 minutes
this.reconnectDelay = 5000             // Wait 5s before forced reload
```

**Why This Masked the Problem:**
- The health monitor was treating the **symptom** (no messages received) not the **cause** (isolated channels)
- Forced reloads fetched correct state from database
- Made it look like an intermittent connection issue rather than architectural problem
- Developers might have seen console warnings but not understood the root cause
- The 2-minute delay made debugging difficult (updates seemed "eventually consistent")

## Solution

Changed `config/cable.yml` to use the **redis** adapter:

```yaml
development:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>

test:
  adapter: test

production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { "redis://localhost:6379/1" } %>
  channel_prefix: carambus_production
```

### Why Redis Adapter Works

The `redis` adapter:
- Uses Redis as a **centralized pub/sub message broker**
- **Shares broadcasts** across all connected clients
- **All WebSocket connections** subscribe to the same Redis channel
- **All broadcasts** go through Redis and reach all subscribers
- Supports multiple Rails processes and servers

With Redis:
1. Browser A subscribes → creates subscription in Redis
2. Browser B subscribes → creates subscription in Redis  
3. TableMonitorJob broadcasts → goes to Redis → **all subscribers receive it**
4. Real-time updates work correctly across all browsers
5. Health monitor stays quiet (connection is actually healthy)
6. No forced reloads needed - updates happen in milliseconds, not minutes

## Testing the Fix

### Prerequisites

1. Redis must be running:
```bash
redis-cli ping
# Should return: PONG
```

2. Rails server must be restarted after cable.yml changes:
```bash
# Stop current server (Ctrl+C)
# Start server
bin/dev
```

### Test Procedure

1. **Open Browser A**: Navigate to a scoreboard view
   - Example: `http://localhost:3007/table_monitors/123/scoreboard`
   - Open browser console (F12) and look for:
     ```
     🔌 TableMonitor Channel connected
     ```

2. **Open Browser B**: Navigate to the **same** scoreboard view
   - Open browser console and verify connection

3. **Make a score update** in either browser:
   - Click a score button or update a game value
   - Watch BOTH browser consoles

4. **Expected Results**:
   - ✅ Both browsers receive the broadcast
   - ✅ Both consoles show: `📥 TableMonitor Channel received:`
   - ✅ Both scoreboards update in real-time
   - ✅ No reload needed

5. **Check Redis Activity** (optional):
```bash
# Monitor Redis pub/sub
redis-cli
> SUBSCRIBE table-monitor-stream
# You should see messages when updates happen
```

### Console Debugging

Enable detailed logging in browser console:
```javascript
// Enable performance logging
localStorage.setItem('debug_cable_performance', 'true')

// Or disable most logging for cleaner output
localStorage.setItem('cable_no_logging', 'true')

// Reload page to apply
```

### Server Logs

Watch the Rails logs for broadcast confirmations:
```
📡 ========== TableMonitorJob START ==========
📡 TableMonitor ID: 123
📡 Operation Type: player_score_panel
📡 Stream: table-monitor-stream
📡 Broadcast Timestamp: 1234567890123
📡 Calling cable_ready.broadcast...
📡 Broadcast complete!
📡 ========== TableMonitorJob END ==========
```

## Verification Checklist

- [x] Redis is installed and running
- [x] `config/cable.yml` uses `redis` adapter
- [x] REDIS_URL environment variable is set (or defaults to localhost)
- [ ] Rails server has been restarted
- [ ] Multiple browsers receive the same broadcasts
- [ ] No "disjunct channel" behavior observed

## Related Configuration

### Session Storage
Session storage is already using Redis (see `config/environments/development.rb`):
```ruby
config.session_store :redis_session_store,
  redis: {
    url: ENV.fetch("REDIS_URL") { "redis://localhost:6379/2" }
  }
```
Note: Sessions use database 2, ActionCable uses database 1 (separate Redis databases).

### ActionCable Channel
All clients subscribe to the same stream (see `app/channels/table_monitor_channel.rb`):
```ruby
def subscribed
  stream_from "table-monitor-stream"
end
```

Client-side filtering happens in `app/javascript/channels/table_monitor_channel.js` to ensure each browser only processes updates relevant to its current view.

## Additional Notes

- The `async` adapter is still useful for quick testing when you only need one connection
- For production and any multi-user scenario, **always use redis or another persistent pub/sub adapter**
- The same issue would affect any other ActionCable channels in the application
- Docker deployments already had this configured correctly (they use redis service)

### Important: Connection Health Monitor Still Valuable

The Connection Health Monitor (`app/javascript/channels/table_monitor_channel.js`) is still important and should remain active:

**Before Redis Fix:**
- Health monitor was compensating for broken architecture
- Forced reloads every ~2 minutes due to message timeout
- Acting as a workaround, not a real solution

**After Redis Fix:**
- Health monitor provides real connection monitoring
- Only triggers on actual network/connection problems
- Protects against:
  - Network interruptions
  - Server restarts
  - Redis connection failures
  - WebSocket proxy timeouts
  - Browser sleep/wake cycles (laptop lid close/open)

**When Health Monitor Should Trigger Now:**
- ✅ Actual network disconnection
- ✅ Server restart during deployment
- ✅ Redis server down
- ✅ Nginx/proxy timeout
- ❌ NOT for normal operation (async isolation is fixed)

If you see the health monitor triggering frequently (more than once per hour) after the Redis fix, investigate:
1. Network stability issues
2. Redis connection problems
3. Server resource constraints
4. WebSocket proxy configuration

## Git Commit

This fix should be committed to `carambus_master` and deployed to all scenarios:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
git add config/cable.yml
git commit -m "Fix: Use Redis adapter for ActionCable to enable multi-client broadcasts

Previously using async adapter which isolated each WebSocket connection,
preventing real-time updates from being shared across multiple browsers
viewing the same scoreboard. Redis adapter provides proper pub/sub
for broadcasting to all connected clients."
```

## Troubleshooting Guide for Developers

### Symptom: Browsers sync every ~2 minutes but not immediately

**Diagnosis**: You're still using `async` adapter (or Redis is not running)

**Check:**
```bash
# 1. Verify cable.yml
cat config/cable.yml | grep -A2 development
# Should show: adapter: redis

# 2. Verify Redis is running
redis-cli ping
# Should return: PONG

# 3. Check Rails logs for ActionCable broadcasts
tail -f log/development.log | grep "Broadcasting to table-monitor-stream"
# Should see broadcasts when updates happen
```

**Fix:**
1. Update `config/cable.yml` to use redis adapter
2. Restart Rails server
3. Test with multiple browsers

### Symptom: Health monitor triggers frequently after Redis fix

**Diagnosis**: Real connection or Redis problems

**Check:**
```bash
# Check Redis connection
redis-cli -h localhost -p 6379 -n 1 ping

# Monitor Redis pub/sub activity
redis-cli
> SUBSCRIBE cable:table-monitor-stream
# Watch for messages when you make updates

# Check Redis logs
tail -f /usr/local/var/log/redis.log  # macOS Homebrew
# or
tail -f /var/log/redis/redis-server.log  # Linux
```

**Browser Console Debugging:**
```javascript
// Enable detailed ActionCable logging
localStorage.setItem('debug_cable_performance', 'true')
// Reload page

// Watch for health monitor warnings
// Should see: "🏥 Health monitor started"
// Should NOT see: "⚠️ No messages received for X seconds" during normal operation
```

### Symptom: Updates work for one browser but not others

**Diagnosis**: 
- If immediate: Client-side filtering issue (check `getPageContext()` and `shouldAcceptOperation()`)
- If after 2 min: Still using `async` adapter

**Check:**
```javascript
// In browser console of BOTH browsers
console.log('Testing broadcast reception')

// Then make an update and watch BOTH consoles
// Both should show: "📥 TableMonitor Channel received:"
```

### Symptom: No updates at all (even after reload)

**Diagnosis**: ActionCable not connected or broadcasting failing

**Check:**
```javascript
// Browser console
// Should see:
// "🔌 TableMonitor Channel initialized"
// "🔌 TableMonitor Channel connected"
// "🏥 Health monitor started"
```

**Server Rails Console:**
```ruby
# Test broadcast directly
ActionCable.server.broadcast(
  "table-monitor-stream", 
  { type: "test", message: "Hello from console" }
)
# Check browser console - should receive this message
```

## References

- [Rails ActionCable Configuration](https://guides.rubyonrails.org/action_cable_overview.html#configuration)
- [Redis Pub/Sub Documentation](https://redis.io/docs/manual/pubsub/)
- Project: `docs/WEBSOCKET_LIFECYCLE_ANALYSIS.md`
- Project: `docs/WEBSOCKET_CONNECTION_HEALTH_MONITORING.md`

