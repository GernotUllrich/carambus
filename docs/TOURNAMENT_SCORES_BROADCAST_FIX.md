# Tournament Scores Broadcast Fix

## Problem

Tournament scores page (`?sb_state=tournament_scores`) was not receiving updates when table monitors had structural changes (game state changes, etc.). The teasers (individual game cards) were not updating in real-time.

## Root Cause

The issue was in `app/models/table_monitor.rb` in the `after_update_commit` callback (lines 95-105).

### Original Logic (BROKEN for tournament_scores)

```ruby
# Update table_scores overview (if structural changes) OR individual teaser (if score changes only)
if previous_changes.keys.present? && relevant_keys.present?
  Rails.logger.info "🔔 Enqueuing: table_scores job (relevant_keys present)"
  TableMonitorJob.perform_later(self, "table_scores")
else
  Rails.logger.info "🔔 Enqueuing: teaser job (no relevant_keys)"
  TableMonitorJob.perform_later(self, "teaser")
end
```

**The logic was correct for `table_scores` page but missing tournament_scores support**: 
- When structural changes occurred (relevant_keys present), it sent `table_scores` but **NOT teasers**
  - ✅ Works for `table_scores` page (has `#table_scores` container with embedded teasers)
  - ❌ Fails for `tournament_scores` page (only has individual `#teaser_*` elements, no `#table_scores`)
- When only score changes occurred (no relevant_keys), it sent `teaser` 
  - ✅ Works for both pages

### Page Architecture Differences

**table_scores page** (`?sb_state=table_scores`):
- Has `#table_scores` container that includes all teasers
- When `#table_scores` updates, all teasers update together
- Also has individual `#teaser_*` elements for granular updates

**tournament_scores page** (`?sb_state=tournament_scores`):
- Has `turbo-frame id="teasers"` containing individual `#teaser_*` elements
- Does NOT have `#table_scores` container
- Requires individual `#teaser_*` updates

### Client-Side Filtering Behavior

The client-side filtering in `table_monitor_channel.js` works as follows:

**tournament_scores page** (lines 143-153):
```javascript
case 'tournament_scores':
  // Accept teaser updates
  if (selector.startsWith('#teaser_')) {
    return !!document.querySelector(selector)
  }
  // Reject table_scores and full_screen updates
  if (selector === '#table_scores' || fullScreenMatch) {
    return false  // #table_scores doesn't exist on this page
  }
```
- ✅ Accepts: `#teaser_*` selectors
- ❌ Rejects: `#table_scores` selector (doesn't exist on page)

**table_scores page** (lines 131-142):
```javascript
case 'table_scores':
  // Accept table_scores and teaser updates
  if (selector === '#table_scores' || selector.startsWith('#teaser_')) {
    return !!document.querySelector(selector)
  }
  // Reject full_screen updates
  if (fullScreenMatch) {
    return false
  }
```
- ✅ Accepts: `#table_scores` AND `#teaser_*` selectors

### Why It Failed

When a structural change happened (e.g., game state change):
1. Server sent **only** `table_scores` broadcast (selector: `#table_scores`)
2. `table_scores` page: ✅ Accepted and updated (has `#table_scores`)
3. `tournament_scores` page: ❌ Rejected `#table_scores` (doesn't exist on page)
4. Result: **No updates visible** on tournament_scores page

## Solution

Added teaser broadcasts for structural changes so that `tournament_scores` page receives updates. The key insight is that both page types need to receive updates, but they have different DOM structures.

### New Logic (FIXED)

```ruby
# Update table_scores overview (if structural changes) OR individual teaser (if score changes only)
if previous_changes.keys.present? && relevant_keys.present?
  Rails.logger.info "🔔 Enqueuing: table_scores job (relevant_keys present)"
  TableMonitorJob.perform_later(self, "table_scores")
  # Also send teaser for tournament_scores page (which doesn't have #table_scores container)
  Rails.logger.info "🔔 Enqueuing: teaser job (for tournament_scores page)"
  TableMonitorJob.perform_later(self, "teaser")
else
  Rails.logger.info "🔔 Enqueuing: teaser job (no relevant_keys)"
  TableMonitorJob.perform_later(self, "teaser")
end
```

**Now the behavior is:**
- **Structural changes** (relevant_keys present): 
  - Send `table_scores` (for table_scores page with `#table_scores` container)
  - **AND** send `teaser` (for tournament_scores page with individual `#teaser_*` elements)
- **Score-only changes** (no relevant_keys): 
  - Send `teaser` only (works for both pages)

### Client Behavior After Fix

**On tournament_scores page:**
- **Before**: Received only `table_scores` broadcast → Rejected → No update ❌
- **After**: Receives both `table_scores` and `teaser` broadcasts
  - Rejects `#table_scores` (doesn't exist on page)
  - Accepts `#teaser_*` ✅ → **Updates work!**

**On table_scores page:**
- **Before**: Received `table_scores` broadcast → Accepted → Updated ✅
- **After**: Receives both `table_scores` and `teaser` broadcasts
  - Accepts `#table_scores` ✅ → Full container updates
  - Accepts `#teaser_*` ✅ → Individual teasers also update
  - Result: Same as before (both work fine)

## Testing

To verify the fix works:

1. Open `http://localhost:3000/locations/1?sb_state=tournament_scores` in one browser
2. Open a scoreboard in another browser/tab
3. Make score changes on the scoreboard
4. Verify teasers update in real-time on the tournament_scores page

Expected behavior:
- ✅ Individual game teasers update when scores change
- ✅ Teasers update when game state changes
- ✅ No rejected broadcasts in console logs (check with `localStorage.setItem('debug_cable_performance', 'true')`)

## Files Changed

- `app/models/table_monitor.rb` (lines 95-103)

## Related Documentation

- `docs/CLIENT_CONSOLE_CAPTURE.md` - Client-side filtering architecture
- `app/javascript/channels/table_monitor_channel.js` - Client filtering implementation
- `app/jobs/table_monitor_job.rb` - Broadcast generation

## Date

November 28, 2025

