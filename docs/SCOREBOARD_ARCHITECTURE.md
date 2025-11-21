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

**File**: `app/javascript/controllers/table_monitor_controller.js` (118 lines)

```javascript
// Simple Stimulus controller - just triggers reflexes
add_n() {
  const n = this.element.dataset.n
  this.stimulate('TableMonitor#add_n', this.element)
}
```

**Purpose**:
- Handles button clicks and user interactions
- Triggers server-side reflexes via StimulusReflex
- No client-side game logic or validation
- No optimistic updates or state management

### 2. ActionCable Channel

**File**: `app/javascript/channels/table_monitor_channel.js` (25 lines)

```javascript
// Simple channel - just performs CableReady operations
received(data) {
  if (data.cableReady) CableReady.perform(data.operations)
}
```

**Purpose**:
- Subscribes to global `"table-monitor-stream"`
- Receives and performs CableReady operations
- No filtering, no context awareness, no complex logic

### 3. Server-Side Reflex

**File**: `app/reflexes/table_monitor_reflex.rb` (674 lines)

```ruby
def add_n
  n = element.andand.dataset[:n].to_i
  @table_monitor = TableMonitor.find(element.andand.dataset[:id])
  @table_monitor.add_n_balls(n)  # Full game logic
  @table_monitor.do_play         # State transitions
  @table_monitor.save!           # Commit to database
end
```

**Purpose**:
- Contains all game logic and state transitions
- Updates database immediately with `save!`
- Callbacks automatically enqueue `TableMonitorJob`
- No complex timing, no delays, no locks

### 4. Background Job

**File**: `app/jobs/table_monitor_job.rb` (115 lines)

```ruby
def perform(table_monitor, operation_type)
  table_monitor.reload              # Fresh data
  table_monitor.clear_options_cache # No stale cache
  
  case operation_type
  when "teaser"
    cable_ready["table-monitor-stream"].inner_html(
      selector: "#teaser_#{table_monitor.id}",
      html: ApplicationController.render(...)
    )
  else
    cable_ready["table-monitor-stream"].inner_html(
      selector: "#full_screen_table_monitor_#{table_monitor.id}",
      html: ApplicationController.render(...)
    )
  end
  
  cable_ready.broadcast
end
```

**Purpose**:
- Renders HTML partials on the server
- Broadcasts `innerHTML` replacement operations via CableReady
- Simple case statement for different update types
- Always calls `broadcast` at the end

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
   - ~258 lines of core code (vs ~1,500+ in complex version)
   - All game logic in one place (reflex)
   - Standard Rails patterns

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

### What Didn't Work

❌ **Optimistic UI**: Added complexity, validation delays, and duplicate scores  
❌ **JSON Broadcasting**: Required complex client-side rendering logic  
❌ **Client-Side Validation**: Duplicated server logic, led to inconsistencies  
❌ **Dynamic Streams**: Complex filtering, subscription management issues  
❌ **DOM Morphing**: CPU-intensive on slow hardware (Pi 3)

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

```ruby
# Global stream used for all TableMonitor updates
STREAM_NAME = "table-monitor-stream"
```

### Callback Settings

```ruby
# app/models/table_monitor.rb
after_update_commit lambda {
  relevant_keys = (previous_changes.keys - %w[
    data nnn panel_state pointer_mode current_element updated_at
  ])
  
  if relevant_keys.any?
    TableMonitorJob.perform_later(self, 'table_scores')
  else
    TableMonitorJob.perform_later(self, 'score_update')
  end
}
```

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

