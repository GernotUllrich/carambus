# Scoreboard Architecture

**Date**: 2025-11-21  
**Status**: Production  
**Branch**: `master`

---

## Overview

The Carambus scoreboard uses a **simple, server-driven architecture** that prioritizes reliability and performance over complexity. This architecture proved to be fast and stable even on Raspberry Pi 3 hardware.

---

## Architecture Principles

1. **Server-Side Logic**: All game logic (`add_n_balls`, `do_play`, state transitions) runs on the server
2. **Simple Updates**: Full HTML replacement via `innerHTML` (no DOM diffing/morphing)
3. **Direct Reflexes**: User actions directly trigger server reflexes with immediate database updates
4. **Single Stream**: All clients subscribe to one global ActionCable stream
5. **Fresh Data**: Each job reloads data and clears caches to ensure consistency

---

## Key Components

### 1. Client-Side Controller

**File**: `app/javascript/controllers/table_monitor_controller.js` (~135 lines)

```javascript
// Simple Stimulus controller - just triggers reflexes
add_n () {
  const n = this.element.dataset.n
  this.stimulate('TableMonitor#add_n', this.element)  // pass element so reflex reads dataset
}
```

**Purpose**:
- Handles button clicks and user interactions
- Triggers server-side reflexes via StimulusReflex
- No client-side game logic or validation
- No optimistic updates or state management

### 2. ActionCable Channel

**File**: `app/javascript/channels/table_monitor_channel.js` (~672 lines)

```javascript
// Subscription created against the server-side TableMonitorChannel
const tableMonitorSubscription = consumer.subscriptions.create("TableMonitorChannel", {
  received(data) {
    // ... performance timestamp handling, page-context filtering, then:
    if (data.cableReady && data.operations?.length > 0) CableReady.perform(applicableOperations)
  }
})
```

**Purpose**:
- Subscribes to the server-side `TableMonitorChannel` (which `stream_from "table-monitor-stream"`)
- Receives CableReady operations and performs the ones applicable to the current page
- Performs **page-context detection and filtering** (`getPageContext()`) so only relevant operations are applied
- Includes a `ConnectionHealthMonitor` (heartbeat, reconnect, status indicator) and a fast `score:update` optimistic DOM-update path
- This file is NOT a thin pass-through; it is substantially complex (~672 lines)

### 2b. Server-Side ActionCable Channel

**File**: `app/channels/table_monitor_channel.rb`

```ruby
class TableMonitorChannel < ApplicationCable::Channel
  def subscribed
    reject and return unless ApplicationRecord.local_server?  # API server has no scoreboards
    stream_from "table-monitor-stream"
  end
  def heartbeat(data); end          # client liveness ack
  def self.force_reconnect(...); end # broadcast forced reconnect
end
```

**Purpose**:
- Defines the `"table-monitor-stream"` that all jobs broadcast to
- **Rejects subscriptions on the API server** (`unless ApplicationRecord.local_server?`)
- Provides `heartbeat` ack and `force_reconnect` server-push helpers

### 3. Server-Side Reflex

**File**: `app/reflexes/table_monitor_reflex.rb` (~1133 lines)

```ruby
def add_n
  n = element.andand.dataset[:n].to_i
  morph :nothing
  return if remote_request? && !current_user&.admin?  # security guard
  @table_monitor = TableMonitor.find(element.andand.dataset[:id])
  @table_monitor.suppress_broadcast = true
  @table_monitor.reset_timer!
  @table_monitor.add_n_balls(n)  # Full game logic
  @table_monitor.do_play         # State transitions
  @table_monitor.suppress_broadcast = false
  @table_monitor.save!           # Commit to database (triggers after_update_commit)
end
```

**Purpose**:
- Contains all game logic and state transitions
- Updates database immediately with `save!`
- Callbacks (`after_update_commit`) automatically enqueue `TableMonitorJob`
- Guards against unauthorized remote requests and toggles `suppress_broadcast`
- Note: this is one of ~40 reflex methods; the file is ~1133 lines, not a thin handler

### 4. Background Job

**File**: `app/jobs/table_monitor_job.rb` (~401 lines)

```ruby
def perform(*args)
  return unless ApplicationRecord.local_server?   # skip on API server
  table_monitor_id = args[0]
  # CRITICAL: only Integer ID accepted — passing an object causes race
  # conditions where a reused object renders the wrong table's data.
  raise ArgumentError unless table_monitor_id.is_a?(Integer)
  operation_type = args[1]
  options = args[2] || {}

  table_monitor = TableMonitor.find(table_monitor_id) # FRESH instance, never reuse
  table_monitor.clear_options_cache                   # no stale cache

  case operation_type
  when "party_monitor_scores" then ...
  when "teaser"  then cable_ready["table-monitor-stream"].inner_html(selector: "#teaser_#{id}", ...)
  when "table_scores" then ...
  when "score_data" then cable_ready["table-monitor-stream"].dispatch_event(...) # optimistic JSON path
  when "player_score_panel" then ...
  else cable_ready["table-monitor-stream"].inner_html(selector: "#full_screen_table_monitor_#{id}", ...)
  end

  cable_ready.broadcast
end
```

**Purpose**:
- Renders HTML partials on the server and broadcasts via CableReady
- **Accepts only an Integer ID** (`args[0]`) and reloads via `TableMonitor.find` — it does NOT accept an object reference and does NOT call `reload`; passing an object raises `ArgumentError` (race-condition guard)
- Skips entirely on the API server (`ApplicationRecord.local_server?`)
- Multi-branch `case` on `operation_type`: `party_monitor_scores`, `teaser`, `table_scores`, `score_data` (a `dispatch_event` JSON/optimistic path), `player_score_panel`, and the `else` full-screen branch
- Always calls `cable_ready.broadcast` at the end

---

## Update Flow

```
User clicks +10 button
    ↓
Stimulus controller triggers reflex
    ↓
TableMonitor#add_n reflex executes
    ↓
add_n_balls(10) updates game data
    ↓
do_play() handles state transitions
    ↓
save! commits to database
    ↓
after_update_commit enqueues TableMonitorJob
    ↓
Job reloads fresh data
    ↓
Job renders HTML partial
    ↓
CableReady broadcasts innerHTML operation
    ↓
All subscribed clients receive update
    ↓
Channel performs CableReady operation
    ↓
DOM updated with new HTML
```

**Total time on Pi 3**: ~50-100ms

---

## Why This Approach Works

### Advantages

1. **Simple and Reliable**
   - Easy to understand and debug
   - No complex state management
   - No race conditions or timing issues

2. **Fast Performance**
   - `innerHTML` replacement is faster than DOM morphing
   - No client-side computation or validation
   - Minimal JavaScript execution

3. **Data Integrity**
   - Single source of truth (database)
   - `save!` ensures commit before broadcasts
   - Cache invalidation prevents stale data

4. **Easy Maintenance**
   - Game logic concentrated in the reflex and model
   - Standard Rails patterns (reflex → `save!` → `after_update_commit` → job → CableReady)
   - Note: the components have grown well beyond a minimal footprint — the model (~2132 lines), reflex (~1133 lines), client channel (~672 lines), and job (~401 lines) are each substantial

### Trade-offs

- **No Optimistic Updates**: Brief delay before UI updates (50-100ms)
- **Full HTML Replacement**: Entire scoreboard HTML is sent (not just data)
- **Global Stream**: All clients receive all updates (filtered by DOM selector)

These trade-offs are **acceptable** because:
- 50-100ms delay is imperceptible to users
- HTML is small (~5-10KB) and compresses well
- DOM selector filtering is extremely fast

---

## Lessons Learned

### Design Tensions

⚠️ **Optimistic UI**: A `score:update` DOM-update path still exists in the client channel,
and a `score_data` `dispatch_event` broadcast exists in the job. The "innerHTML-only" ideal
described above is the *baseline*; these fast paths were layered on for latency.  
⚠️ **JSON Broadcasting**: Present via `score_data` / `dispatch_event` for the ultra-fast path.  
❌ **Client-Side Validation**: Not used — server remains the single source of truth.  
✅ **Single Global Stream**: One `"table-monitor-stream"`; clients filter by page context.  
❌ **DOM Morphing**: Avoided — updates use `inner_html` replacement (CPU-friendly on Pi 3).

### What Does Work

✅ **Simple Server Reflexes**: Direct database updates, no delays  
✅ **innerHTML Replacement**: Fast, simple, reliable  
✅ **Global Stream**: Single subscription, DOM selector filtering  
✅ **Cache Invalidation**: Explicit clearing after reload  
✅ **Full Game Logic on Server**: Single source of truth

---

## Performance Characteristics

### Payload Sizes

- **Scoreboard Update**: ~5-10KB HTML (gzipped: ~1-2KB)
- **Teaser Update**: ~1-2KB HTML (gzipped: ~300-500 bytes)
- **Table Scores**: ~10-20KB HTML (gzipped: ~2-3KB)

### Latency (Raspberry Pi 3)

- **Button Click → Reflex**: 5-10ms
- **Reflex → Database Save**: 10-20ms
- **Job Enqueue → Execute**: 5-10ms
- **Render HTML**: 10-20ms
- **Broadcast → Receive**: 5-10ms
- **innerHTML Update**: 10-20ms
- **Total**: 50-100ms ✅

### CPU Usage

- **Client-Side**: Minimal (just innerHTML replacement)
- **Server-Side**: Moderate (HTML rendering)
- **Database**: Light (simple updates, good indexing)

---

## Configuration

### Stream Name

The global stream name is the **string literal** `"table-monitor-stream"`, used directly
in the server channel (`stream_from "table-monitor-stream"`) and in every job broadcast
(`cable_ready["table-monitor-stream"]`). There is **no** `STREAM_NAME` constant in the
codebase — the literal is repeated at each call site.

### Callback Settings

```ruby
# app/models/table_monitor.rb
after_update_commit lambda {
  return if suppress_broadcast                 # set during start_game / reflexes
  return unless ApplicationRecord.local_server? # skip on API server

  relevant_keys = (previous_changes.keys - %w[data nnn panel_state pointer_mode current_element updated_at])

  # PartyMonitor scores
  TableMonitorJob.perform_later(id, "party_monitor_scores") if tournament_monitor.is_a?(PartyMonitor) && ...

  # Structural change → table_scores + teaser; score-only change → teaser
  if previous_changes.keys.present? && relevant_keys.present?
    TableMonitorJob.perform_later(id, "table_scores")
    TableMonitorJob.perform_later(id, "teaser")
  elsif @collected_changes.present? || ...
    TableMonitorJob.perform_later(id, "teaser")
  end

  # Fast paths (early return)
  return TableMonitorJob.perform_later(id, "score_data", player: player_key) if ultra_fast_score_update?
  return TableMonitorJob.perform_later(id, "player_score_panel", player: player_key) if simple_score_update?

  # Slow path: full scoreboard ("" triggers the else branch in the job)
  TableMonitorJob.perform_later(id, "")
}
```

Note: the callback passes the **integer `id`** (never `self`), enqueues **multiple jobs**
per update, and includes ultra-fast/simple-score fast paths. There is no `'score_update'`
operation type — the full-screen update is triggered by the empty string `""`.

---

## Maintenance

### Adding New Features

1. Add button/interaction to view
2. Add method to `table_monitor_controller.js` that calls `stimulate()`
3. Add reflex method to `table_monitor_reflex.rb`
4. Update game logic in `table_monitor.rb` model if needed
5. No changes to jobs or channels needed!

### Debugging

1. Check server logs for reflex execution
2. Check browser console for CableReady operations
3. Use `Rails.logger.info` for debugging in reflexes/jobs
4. All updates are synchronous and easy to trace

### Testing

1. Manual testing works well (fast feedback loop)
2. System tests can verify full flow
3. No need for complex timing or mocking

---

## Related Documentation

- `app/reflexes/table_monitor_reflex.rb` - All reflex methods
- `app/jobs/table_monitor_job.rb` - Broadcast job
- `app/models/table_monitor.rb` - Game logic and state machine
- `app/views/table_monitors/_scoreboard.html.erb` - Main scoreboard view

---

**Summary**: The simple server-driven architecture proved to be the most reliable and maintainable solution. By avoiding client-side complexity and sticking to standard Rails patterns, we achieved excellent performance even on slow hardware.



