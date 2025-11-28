# Undo/Redo Implementation for TableMonitor Scoreboards

## Overview

A comprehensive undo/redo system has been implemented for TableMonitor using PaperTrail. This allows users to easily revert mistakes during game entry, including during the initial phases (warmup, shootout, game start) and during score entry.

## Implementation Details

### 1. Model Changes (TableMonitor)

**File:** `app/models/table_monitor.rb`

- **PaperTrail Configuration**: Added explicit PaperTrail configuration with field filtering
  - **Tracked fields**: `state`, `data`, `timer_start_at`, `timer_finish_at`, `timer_halt_at`, `game_id`, `tournament_monitor_id`, `active_timer`, etc.
  - **Ignored fields**: `updated_at`, `panel_state`, `current_element`, `ip_address`, `nnn`, `clock_job_id`, `timer_job_id` (UI-only fields)
  - Only enabled on local servers (when `Carambus.config.carambus_api_url.present?`)

- **New Methods**:
  - `can_undo?` - Checks if undo is available (prevents undoing past the ready state)
  - `can_redo?` - Checks if redo is available (checks if there are future versions)
  - `perform_undo` - Reverts to the previous version using PaperTrail
  - `perform_redo` - Moves forward to the next version using PaperTrail
  - `version_index` - Helper method to track current position in version history

### 2. Reflex Actions (TableMonitorReflex)

**File:** `app/reflexes/table_monitor_reflex.rb`

Added two new reflex methods:
- `undo_version` - Handles undo button clicks, calls `table_monitor.perform_undo`
- `redo_version` - Handles redo button clicks, calls `table_monitor.perform_redo`

Both methods:
- Load the table monitor
- Call the appropriate method
- Trigger UI refresh via `TableMonitorJob` on success
- Log errors on failure

### 3. Stimulus Controller (table_monitor_controller.js)

**File:** `app/javascript/controllers/table_monitor_controller.js`

Added two new actions:
- `undo_version()` - Stimulates `TableMonitor#undo_version` reflex
- `redo_version()` - Stimulates `TableMonitor#redo_version` reflex

### 4. User Interface (_scoreboard.html.erb)

**File:** `app/views/table_monitors/_scoreboard.html.erb`

Added two new buttons after the Protocol button:
- **Undo Button**: Red curved arrow icon (undo-red-400.svg)
  - Only visible during `playing?` state
  - Disabled when `can_undo?` returns false (opacity reduced, pointer events disabled)
  - Tooltip: "Letzte Eingabe rückgängig machen"
  
- **Redo Button**: Red curved arrow icon pointing right (redo-red-400.svg)
  - Only visible during `playing?` state
  - Disabled when `can_redo?` returns false (opacity reduced, pointer events disabled)
  - Tooltip: "Rückgängig gemachte Eingabe wiederholen"

Both buttons are placed right after the Protocol button in the controls row.

### 5. Localization (de.yml)

**File:** `config/locales/de.yml`

Added German translations in the `table_monitor` section:
```yaml
undo: Rückgängig
redo: Wiederholen
undo_tooltip: Letzte Eingabe rückgängig machen
redo_tooltip: Rückgängig gemachte Eingabe wiederholen
```

### 6. Assets

**File:** `app/assets/images/redo-red-400.svg`

Created a red version of the redo icon to match the undo icon styling.

## How It Works

### Version Tracking

1. **PaperTrail automatically tracks changes** to TableMonitor records on local servers
2. **Each save creates a version** in the `versions` table (except when explicitly disabled)
3. **Versions include all tracked fields** with their old and new values

### Undo Process

1. User clicks **Undo button**
2. `undo_version` Stimulus action triggers
3. `undo_version` reflex calls `table_monitor.perform_undo`
4. Method checks `can_undo?` (ensures we don't go past ready state)
5. Retrieves previous version from PaperTrail
6. Restores all tracked attributes from that version
7. Saves the record **without creating a new version** (using `PaperTrail.request(enabled: false)`)
8. UI refreshes via broadcast

### Redo Process

1. User clicks **Redo button**
2. `redo_version` Stimulus action triggers
3. `redo_version` reflex calls `table_monitor.perform_redo`
4. Method checks `can_redo?` (ensures there are future versions)
5. Retrieves next version from PaperTrail
6. Applies the changes from that version
7. Saves the record **without creating a new version**
8. UI refreshes via broadcast

### Limits and Constraints

- **Undo Limit**: Cannot undo past the `ready` state (prevents undoing game setup)
- **Redo Limit**: Can only redo up to the current state
- **State Restriction**: Buttons only visible during `playing?` state
- **Button State**: Buttons are visually disabled (opacity 30%, no pointer events) when not available
- **Redo Stack**: Making new changes after undo clears the redo history

## User Experience

### Typical Use Cases

1. **Wrong Score Entry**: User enters wrong score → clicks Undo → enters correct score
2. **Wrong Player Won Shootout**: User selects wrong player → clicks Undo → selects correct player
3. **Accidental State Change**: User accidentally advances state → clicks Undo → continues normally
4. **Multiple Undos**: User can undo multiple times to get back to a known good state
5. **Change of Mind**: User undoes, then realizes it was correct → clicks Redo

### Visual Feedback

- **Active buttons**: Full color, red icons, visible and clickable
- **Disabled buttons**: Faded (30% opacity), not clickable
- **Tooltips**: Provide clear descriptions of what each button does

## Technical Notes

### Performance Considerations

- PaperTrail creates a version record for each save
- Versions table will grow over time
- Consider periodic cleanup of old versions (e.g., after game is finalized)
- Version queries are indexed and efficient

### Callback Management

- Undo/Redo operations disable PaperTrail temporarily to avoid creating new versions
- This ensures clean version history without undo/redo artifacts
- Normal operations continue to create versions as expected

### Error Handling

- Methods return `{ success: true/false, error: message }` hash
- Errors are logged to Rails logger
- Future enhancement: Show error messages to users via UI

## Files Modified

1. `app/models/table_monitor.rb` - Added PaperTrail config and undo/redo methods
2. `app/reflexes/table_monitor_reflex.rb` - Added undo_version and redo_version reflexes
3. `app/javascript/controllers/table_monitor_controller.js` - Added Stimulus actions
4. `app/views/table_monitors/_scoreboard.html.erb` - Added undo/redo buttons
5. `config/locales/de.yml` - Added German translations
6. `app/assets/images/redo-red-400.svg` - Created red redo icon

## Testing Recommendations

### Manual Testing Checklist

1. Start a new game and verify no undo is available
2. Enter scores and verify undo becomes available
3. Click undo and verify score is reverted
4. Click redo and verify score is restored
5. Make new entry after undo and verify redo is cleared
6. Test undo during warmup phase
7. Test undo after shootout
8. Test multiple consecutive undos
9. Verify buttons are disabled when not available
10. Test with different game types and disciplines

### Edge Cases to Test

- Undo at the very start of playing state
- Undo/redo with timer running
- Undo/redo with different disciplines (4 Ball, Eurokegel, etc.)
- Multiple rapid undo/redo clicks
- Undo/redo with incomplete innings

## Deployment Notes

This implementation is in `carambus_master` and needs to be deployed to other scenarios:

1. **carambus_api** - API server deployment
2. **carambus_bcw** - BCW tournament system
3. **carambus_location_*** - Location-specific deployments

The deployment should happen through the normal workflow:
1. Commit/push from `carambus_master`
2. Other scenarios pull changes via git pull or deploy-scenario scripts
3. No manual file copying needed

## Version Information

- **Implementation Date**: November 28, 2025
- **PaperTrail Version**: 15.2
- **Rails Version**: 7.2.0.beta2
- **Git Branch**: master
- **Last Commit**: 721cd93 (Fix: Use Redis adapter for ActionCable)
