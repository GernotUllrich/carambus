# Scoreboard Debugging Infrastructure

This document describes the comprehensive debugging infrastructure implemented for the scoreboard application to help identify and resolve issues with StimulusReflex, CableReady, and DOM synchronization.

## Overview

The debugging infrastructure consists of several components:

1. **Enhanced CableReady Operations** - Better error handling and logging
2. **StimulusReflex Debugging** - URL mismatch detection and performance monitoring
3. **DOM Health Monitoring** - Real-time DOM state validation
4. **Debug Dashboard** - Visual debugging interface
5. **Server-side Debug API** - Backend debugging endpoints

## Components

### 1. Enhanced CableReady Operations (`table_monitor_channel.js`)

**Features:**
- Pre-operation DOM element validation
- Comprehensive error logging with emojis for easy identification
- Operation statistics tracking
- Automatic DOM health checks on errors
- Global debugger access via `window.scoreboardDebugger`

**Usage:**
```javascript
// Access debugger
window.scoreboardDebugger.getStats()
window.scoreboardDebugger.checkDOMHealth()

// Check specific elements
document.querySelector('#teaser_23') // Returns null if missing
```

### 2. StimulusReflex Debugging (`table_monitor_reflex.rb`)

**Features:**
- URL mismatch detection and logging
- Element validation before reflex execution
- Performance timing for all reflex operations
- Comprehensive error logging with backtraces
- Reflex lifecycle monitoring

**Log Output Examples:**
```
🎯 [14:23:45.123] REFLEX START: add_n
   URL: http://localhost:3000/locations/abc123/sb_state/table_monitor/23
   Element: {"id": "23", "n": "1"}
✅ REFLEX SUCCESS: add_n (45ms)
```

### 3. DOM Health Monitoring (`scoreboard_debugger.js`)

**Features:**
- Real-time DOM element counting and validation
- ActionCable connection status monitoring
- StimulusReflex availability checking
- Automatic snapshot creation every 30 seconds
- Issue analysis and recommendations

**Console Commands:**
```javascript
debugScoreboard()           // Generate comprehensive report
checkScoreboardHealth()     // Check DOM health
resetScoreboardDebug()      // Reset all statistics
```

### 4. Debug Dashboard (`_debug_dashboard.html.erb`)

**Features:**
- Visual debugging interface (toggle with 🛠️ button)
- Real-time statistics display
- DOM health monitoring
- Recent error display
- Quick action buttons
- Console command reference

**Access:**
- Click the red 🛠️ button in bottom-right corner
- Dashboard appears in top-right corner

### 5. Server-side Debug API (`debug_controller.rb`)

**Endpoints:**
- `GET /debug/scoreboard_status` - Current system status
- `GET /debug/dom_health` - Server-side DOM validation
- `DELETE /debug/clear_logs` - Clear debug cache

**Usage:**
```bash
curl http://localhost:3000/debug/scoreboard_status
```

## Common Issues and Solutions

### Issue 1: "Missing DOM element for selector: '#teaser_23'"

**Symptoms:**
- CableReady operations fail
- Console shows missing element warnings
- Scoreboard updates don't appear

**Debugging Steps:**
1. Check DOM health: `checkScoreboardHealth()`
2. Verify element exists: `document.querySelector('#teaser_23')`
3. Check if element is created in the correct view
4. Verify table monitor ID 23 exists in database

**Solutions:**
- Ensure teaser elements are created before CableReady operations
- Check view rendering logic in `_table_scores.html.erb`
- Verify table monitor data integrity

### Issue 2: "Reflex failed due to mismatched URL"

**Symptoms:**
- StimulusReflex operations fail
- URL mismatch warnings in console
- Page navigation issues

**Debugging Steps:**
1. Check reflex history: `window.scoreboardDebugger.reflexHistory`
2. Verify current URL vs reflex URL
3. Check for page navigation during reflex execution

**Solutions:**
- Ensure page doesn't navigate during reflex execution
- Add proper error handling for navigation scenarios
- Check for multiple browser tabs with different URLs

### Issue 3: High Operation Failure Rate

**Symptoms:**
- Many failed CableReady operations
- Low success rate in debug statistics
- Inconsistent scoreboard updates

**Debugging Steps:**
1. Generate full report: `debugScoreboard()`
2. Check issue analysis in report
3. Review recent errors and patterns

**Solutions:**
- Implement proper element existence checks
- Add retry logic for failed operations
- Improve error handling and recovery

## Debugging Workflow

### 1. Initial Assessment
```javascript
// Check overall health
checkScoreboardHealth()

// Get current statistics
window.scoreboardDebugger.getStats()
```

### 2. Issue Investigation
```javascript
// Generate comprehensive report
debugScoreboard()

// Check specific elements
document.querySelectorAll('[id^="teaser_"]')
```

### 3. Server-side Validation
```bash
# Check server status
curl http://localhost:3000/debug/scoreboard_status

# Validate DOM expectations
curl http://localhost:3000/debug/dom_health?table_monitor_ids[]=23
```

### 4. Continuous Monitoring
- Enable debug dashboard for real-time monitoring
- Watch console for automatic health checks
- Monitor operation statistics

## Performance Considerations

- Debug logging is only active in development/test environments
- Statistics are kept in memory and reset on page reload
- DOM health checks are throttled to prevent performance impact
- Debug dashboard auto-refreshes every 5 seconds when visible

## Integration with Existing Code

The debugging infrastructure integrates seamlessly with existing code:

- **No breaking changes** to existing functionality
- **Backward compatible** with current implementations
- **Optional activation** - can be disabled in production
- **Minimal performance impact** when not actively debugging

## Future Enhancements

Potential improvements for the debugging infrastructure:

1. **Persistent Logging** - Store debug logs in database
2. **Alert System** - Notify when critical issues occur
3. **Performance Metrics** - Track operation timing trends
4. **Automated Testing** - Integration with test suite
5. **Production Monitoring** - Safe production debugging options


