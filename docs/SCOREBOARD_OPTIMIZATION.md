# Scoreboard Optimization for Immediate Feedback

## Overview

This document describes the optimization implemented for the Carambus scoreboard to provide immediate feedback for score increments and player changes, while maintaining data integrity through client-side validation and batched server synchronization.

## 2025-11-17 – Idempotency Fix for Raspberry Pi 3

**Branch:** `feature/scoreboard-idempotency`

### Problem
On slow Raspberry Pi 3 scoreboards, duplicate scores were being recorded because:
- Validation lock timeout (5s) was shorter than actual processing time (6-8s) on slow hardware
- Failsafe released lock while server was still processing
- Users could click again, sending duplicate requests
- Server applied the same score twice

### Solution: Request ID Idempotency
- **Unique Request IDs**: Each validation batch gets a UUID (e.g., `abc-def-123`)
- **Server-Side Deduplication**: Server checks Redis cache for duplicate request IDs
- **Automatic Ignore**: Duplicate requests are silently ignored (idempotent!)
- **Longer Timeout**: Increased failsafe from 5s to 15s for slow hardware
- **Stale Lock Detection**: Automatically resets locks older than 20 seconds on reconnection

### Implementation
- `app/javascript/controllers/tabmon_controller.js`:
  - Added `generateRequestId()` method using `crypto.randomUUID()`
  - Increased `VALIDATION_LOCK_FAILSAFE_MS` from 5000 to 15000
  - Added `lockTimestamps` tracking
  - Added `checkAndResetStaleLock()` method
- `app/reflexes/table_monitor_reflex.rb`:
  - Check Redis cache for request ID before processing
  - Mark request ID as processed (1-hour TTL)
  - Skip duplicate requests silently

### Testing
- Rapid clicking: +10, +1, +1, +1 should increase score by exactly 13
- Slow network: Duplicates should be prevented by request ID check
- Controller reconnection: Stale locks should be automatically reset

**See:** `/carambus_data/SCOREBOARD_IDEMPOTENCY_IMPLEMENTATION.md` for full details

## 2025-11-11 – Protocol Modal Rendering & Isolation

- **Gezielte CableReady-Updates**: Die Game-Protocol-Reflexe liefern jetzt nur noch die betroffenen DOM-Bereiche (`#protocol-modal-container<ID>` und `#protocol-tbody<ID>`) anstatt den kompletten Scoreboard-Screen zu ersetzen. Dadurch entfällt jedes Flackern – auch auf schwacher Pi-Hardware.
- **Per-Tab ActionCable-Verbindung**: `ApplicationCable::Connection` weist jeder Verbindung ein eigenes `connection_token` zu. StimulusReflex-Antworten landen damit ausschließlich in dem Fenster, das die Aktion ausgelöst hat; andere TableMonitors bleiben unberührt.
- **Gezielte Synchronisation**: Nur beim Schließen des Protokolls wird weiterhin ein vollständiger `TableMonitorJob` ausgelöst, damit der Scoreboard-Screen den finalen Stand übernimmt. Alle anderen Aktionen bleiben auf Teil-Updates beschränkt.
- **Kompatibel mit Mehrfensterbetrieb**: Zwei Browserfenster, die denselben TableMonitor anzeigen, erhalten weiterhin identische Modal-Updates, bleiben aber sauber isoliert von anderen Tischen.
- **Dokumentierte Endpunkte**:
  - `app/channels/application_cable/connection.rb` – Generiert das neue `connection_token`.
  - `app/reflexes/game_protocol_reflex.rb` – Rendert Modal/Table-Body und verteilt die CableReady-Updates.

## Problem Statement

The original scoreboard implementation had several issues:

1. **Lost Increments**: When player switches occurred during delayed validation, accumulated increments were lost
2. **No Client-Side Validation**: Invalid operations (negative scores, exceeding goals) were only caught server-side
3. **Poor User Experience**: No immediate feedback for score changes
4. **Controller Reconnection Issues**: CableReady updates caused state loss when controllers reconnected
5. **Inconsistent Player Switching**: Key A/B logic was incorrect for determining when to switch players

## Solution Architecture

### Accumulation and Validation Approach

1. **Immediate Optimistic Updates**: Client-side score updates with visual feedback
2. **Accumulated Changes**: Batch multiple increments before server validation
3. **Client-Side Validation**: Prevent invalid operations before they occur
4. **Delayed Server Sync**: Validate accumulated changes after user inactivity
5. **Goal-Reaching Detection**: Immediate validation when score reaches goal

### Components

#### 1. Enhanced Stimulus Controller (`tabmon_controller.js`)

- **Optimistic Updates**: Immediate visual feedback for score changes
- **Accumulated Changes**: Batching system for multiple increments
- **Client-Side Validation**: Prevents negative scores and goal violations
- **Global State Management**: Persists state across controller reconnections
- **Player Switch Logic**: Correct handling of Key A/B player switching

#### 2. Validation System

- **Pre-Validation**: Checks operations before applying them
- **Goal Detection**: Identifies when score reaches target goal
- **Immediate Processing**: Bypasses delay when goal is reached
- **State Persistence**: Maintains accumulated changes across reconnections

## Implementation Details

### Client-Side Validation

#### Score Validation

```javascript
// Check if increment would be valid before applying
isValidIncrement(playerId, points, operation) {
  const originalScore = parseInt(scoreElement.dataset.originalScore) || 0
  const newScore = originalScore + totalAccumulated + points
  
  // Prevent negative scores
  if (newScore < 0) return false
  
  // Prevent exceeding goal
  const goal = this.getPlayerGoal(playerId)
  if (goal !== null && newScore > goal) return false
  
  return true
}
```

#### Goal Detection

```javascript
// Immediate validation when goal is reached
if (newScore === goal) {
  console.log('🎯 GOAL REACHED - triggering immediate validation')
  this.validateAccumulatedChanges() // Bypass delay
}
```

### Accumulated Changes System

#### Batching Logic

```javascript
// Accumulate multiple increments
accumulateAndValidateChange(playerId, points, operation) {
  // Validate first
  if (!this.isValidIncrement(playerId, points, operation)) {
    return false // Block invalid operations
  }
  
  // Add to accumulated changes
  playerChanges.totalIncrement += points
  playerChanges.operations.push({ type: operation, points, timestamp: Date.now() })
  
  // Set timer for delayed validation (unless goal reached)
  if (!reachesGoal) {
    this.clientState.validationTimer = setTimeout(() => {
      this.validateAccumulatedChanges()
    }, VALIDATION_DELAY_MS)
  }
}
```

#### Global State Persistence

```javascript
// Persist state across controller reconnections
initializeClientState() {
  if (!window.TabmonGlobalState) {
    window.TabmonGlobalState = {
      accumulatedChanges: { playera: { totalIncrement: 0, operations: [] }, 
                           playerb: { totalIncrement: 0, operations: [] } },
      pendingPlayerSwitch: null,
      validationTimer: null
    }
  }
  
  // Reference global state to prevent loss on reconnection
  this.clientState.accumulatedChanges = window.TabmonGlobalState.accumulatedChanges
}
```

### Player Switch Logic

#### Corrected Key A/B Logic

```javascript
key_a() {
  const activePlayerId = this.getCurrentActivePlayer()
  const playerId = 'playera' // Left side
  
  if (activePlayerId === playerId) {
    // Clicking on active player - add score
    this.accumulateAndValidateChange(playerId, 1, 'add')
  } else {
    // Clicking on opposite side - switch player
    this.next_step()
  }
}
```

#### Player Switch with Pending Changes

```javascript
next_step() {
  // Check for pending accumulated changes
  if (this.hasPendingAccumulatedChanges()) {
    // Validate accumulated changes first, then switch
    this.clientState.pendingPlayerSwitch = tableMonitorId
    this.validateAccumulatedChangesImmediately()
    return // Switch happens after validation success
  }
  
  // No pending changes - switch immediately
  this.performPlayerSwitch(tableMonitorId)
}
```

### Goal Parsing

#### Multi-Language Support

```javascript
getPlayerGoal(playerId) {
  const goalElement = document.querySelector(`.goal[data-player="${playerId}"]`)
  const goalText = goalElement.textContent
  
  // Parse both "Goal: 50" and "Ziel: 20"
  const match = goalText.match(/(?:Goal|Ziel):\s*(\d+|no limit)/i)
  if (match) {
    return match[1] === 'no limit' ? null : parseInt(match[1])
  }
  return null
}
```

## Performance Improvements

### Before Optimization

- **Lost Data**: Accumulated increments lost during player switches
- **No Validation**: Invalid operations only caught server-side
- **Poor UX**: No immediate feedback for score changes
- **State Loss**: Controller reconnections reset accumulated changes

### After Optimization

- **Data Integrity**: No lost increments, all changes preserved
- **Client Validation**: Invalid operations blocked immediately
- **Instant Feedback**: Immediate visual updates for all score changes
- **State Persistence**: Global state survives controller reconnections
- **Smart Batching**: Efficient server communication with 3-second delays
- **Goal Detection**: Immediate processing when goal is reached

## Error Handling

### Validation Failures

```javascript
// Block invalid operations before they occur
if (!this.isValidIncrement(playerId, points, operation)) {
  console.log('❌ Tabmon increment blocked by validation')
  return false // No visual update, no server call
}
```

### State Recovery

- **Global State Backup**: State persists across controller reconnections
- **Graceful Degradation**: Falls back to server-only validation if needed
- **Error Logging**: Comprehensive debug output for troubleshooting

## Testing

### Manual Testing Scenarios

#### Client-Side Validation

1. **Negative Score Prevention**: Try subtracting more points than current score
2. **Goal Limit Enforcement**: Try adding points that would exceed the goal
3. **Goal Reaching**: Add points that exactly reach the goal (should trigger immediate validation)

#### Player Switching

1. **Active Player Click**: Click on player with green border (should add score)
2. **Opposite Player Click**: Click on player without green border (should switch)
3. **Pending Changes**: Add score, then immediately switch (should validate first)

#### State Persistence

1. **Controller Reconnection**: Trigger CableReady updates and verify accumulated changes persist
2. **Multiple Operations**: Add several increments quickly, verify all are batched
3. **Goal Detection**: Verify immediate validation when goal is reached

## Configuration

### Validation Settings

```javascript
// Validation delay in milliseconds
const VALIDATION_DELAY_MS = 3000

// Goal parsing regex (supports multiple languages)
const GOAL_REGEX = /(?:Goal|Ziel):\s*(\d+|no limit)/i
```

### Template Updates

```erb
<!-- Add goal class to goal elements -->
<div class="flex-1 mb-1 goal" data-player="<%= left_player_id %>">
  <%= t('goal') %>: <%= s = left_player[:balls_goal].to_i; s > 0 ? s : "no limit" %>
</div>
```

## Monitoring and Debugging

### Debug Logging

```javascript
// Comprehensive debug output
console.log('🔍 Validating increment:', playerId, operation, points)
console.log('📊 Current state:', currentScore, currentInnings)
console.log('📊 After increment:', newScore, newInnings)
console.log('✅ Valid increment' | '❌ Invalid: reason')
```

### Key Debug Messages

- `🎯 GOAL REACHED - triggering immediate validation`
- `❌ Tabmon increment blocked by validation`
- `🔄 Tabmon accumulating change`
- `📊 Tabmon found changes for playera: X`

## Future Enhancements

### Planned Improvements

1. **Advanced Validation**: More complex game rule validation
2. **Real-time Sync**: WebSocket-based live updates for multiple clients
3. **Offline Support**: Local state persistence when connection is lost
4. **Conflict Resolution**: Handle concurrent updates from multiple clients

### Scalability Considerations

- **State Caching**: Redis-based global state storage
- **Validation Optimization**: Server-side validation improvements
- **Load Balancing**: Distribute validation load across multiple servers

## Troubleshooting

### Common Issues

#### Validation Not Working

1. Check browser console for `🔧 FIXED:` debug messages
2. Verify goal elements have `goal` class in template
3. Check if `data-original-score` attributes are set correctly

#### State Loss on Reconnection

1. Verify `window.TabmonGlobalState` exists in browser console
2. Check if `initializeClientState()` is preserving global state
3. Look for controller reconnection debug messages

#### Goal Detection Not Working

1. Check goal parsing: `🎯 Goal for playera: X`
2. Verify goal text format matches regex pattern
3. Test with both "Goal:" and "Ziel:" formats

### Debug Mode

```javascript
// Enable comprehensive debug logging
// All debug messages are already enabled in production
// Look for emoji-prefixed messages in browser console
```

## Conclusion

The scoreboard optimization successfully addresses all the original issues:

- ✅ **No Lost Increments**: Global state persistence prevents data loss during player switches
- ✅ **Client-Side Validation**: Invalid operations are blocked before they occur
- ✅ **Immediate Feedback**: Users see score changes instantly
- ✅ **Correct Player Switching**: Key A/B logic now works as expected
- ✅ **Goal Detection**: Immediate validation when goals are reached

The implementation uses a sophisticated accumulation and validation system that provides the best user experience while maintaining data integrity. The client-side validation duplicates critical server logic to prevent invalid operations, while the global state management ensures no data is lost during controller reconnections.

The system efficiently batches multiple operations and provides immediate processing when goals are reached, creating a responsive and reliable scoreboard experience.
