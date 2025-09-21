import ApplicationController from './application_controller'

// Configuration: Validation delay in milliseconds
const VALIDATION_DELAY_MS = 3000 // Change this to test different delays

/* This is the StimulusReflex controller for the TableMonitor Controls.
 * Handles all the control buttons in the scoreboard controls row.
 * Now includes optimistic updates for immediate user feedback.
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    this.initializeClientState()
  }

  disconnect() {
    // Clean up validation timer when controller disconnects
    if (this.clientState?.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
    }
    super.disconnect()
  }

  initializeClientState() {
    console.log("🔄 Tabmon initializeClientState called")
    
    // 🚀 CRITICAL: Use global storage for accumulated changes to persist across controller reconnections
    if (!window.TabmonGlobalState) {
      window.TabmonGlobalState = {
        accumulatedChanges: {
          playera: { totalIncrement: 0, operations: [] },
          playerb: { totalIncrement: 0, operations: [] }
        },
        pendingPlayerSwitch: null,
        validationTimer: null
      }
      console.log("🆕 Tabmon created new global state")
    }
    
    const existingAccumulatedChanges = window.TabmonGlobalState.accumulatedChanges
    const existingPendingPlayerSwitch = window.TabmonGlobalState.pendingPlayerSwitch
    const existingValidationTimer = window.TabmonGlobalState.validationTimer
    
    console.log("🔄 Tabmon initializing client state")
    console.log("   Global accumulated changes:", existingAccumulatedChanges)
    console.log("   Global pending player switch:", existingPendingPlayerSwitch)
    
    // Initialize client-side state for immediate feedback
    this.clientState = {
      scores: {},
      currentPlayer: 'playera',
      pendingUpdates: new Set(),
      updateHistory: [],
      // NEW: Reference global accumulated changes
      accumulatedChanges: existingAccumulatedChanges,
      validationTimer: existingValidationTimer,
      // NEW: Track if a player switch is pending after validation
      pendingPlayerSwitch: existingPendingPlayerSwitch
    }
    
    console.log("   New client state:", this.clientState)
  }

  // Optimistic score update - immediate visual feedback using accumulated totals
  updateScoreOptimistically(playerId, points, operation = 'add') {
    try {
      console.log(`🎯 Tabmon updating score: ${playerId} ${operation} ${points}`)

      // Look for the main score element with data-player attribute
      const scoreElement = document.querySelector(`.main-score[data-player="${playerId}"]`)
    if (!scoreElement) {
      console.error(`❌ Score element not found for player: ${playerId}`)
      console.log(`Available score elements:`, document.querySelectorAll('.main-score'))
      return
    }

    // Also look for the innings score element
    const inningsElement = document.querySelector(`.inning-score[data-player="${playerId}"]`)
    if (!inningsElement) {
      console.error(`❌ Innings element not found for player: ${playerId}`)
      console.log(`Available innings elements:`, document.querySelectorAll('.inning-score'))
      return
    }

    // Get current DOM values
    const currentDomScore = parseInt(scoreElement.textContent) || 0
    const currentDomInnings = parseInt(inningsElement.textContent) || 0

    // Get the original (server-side) scores - these should be the baseline
    const originalScore = parseInt(scoreElement.dataset.originalScore || scoreElement.textContent) || 0
    const originalInnings = parseInt(inningsElement.dataset.originalInnings || inningsElement.textContent) || 0

    // Calculate the accumulated total for this player
    const playerChanges = this.clientState.accumulatedChanges[playerId]
    const totalIncrement = playerChanges.totalIncrement

    // Calculate new scores based on original + accumulated total
    const newScore = Math.max(0, originalScore + totalIncrement)
    const newInnings = Math.max(0, originalInnings + totalIncrement)

    // Store original values if not already stored
    if (!scoreElement.dataset.originalScore) {
      scoreElement.dataset.originalScore = originalScore.toString()
      console.log(`💾 Tabmon stored original score for ${playerId}: ${originalScore}`)
    }
    if (!inningsElement.dataset.originalInnings) {
      inningsElement.dataset.originalInnings = originalInnings.toString()
      console.log(`💾 Tabmon stored original innings for ${playerId}: ${originalInnings}`)
    }

    console.log(`📊 Tabmon score calculation for ${playerId}:`)
    console.log(`   Current DOM score: ${currentDomScore}`)
    console.log(`   Original score: ${originalScore}`)
    console.log(`   Total increment: ${totalIncrement}`)
    console.log(`   New score: ${originalScore} + ${totalIncrement} = ${newScore}`)
    console.log(`   Current DOM innings: ${currentDomInnings}`)
    console.log(`   Original innings: ${originalInnings}`)
    console.log(`   New innings: ${originalInnings} + ${totalIncrement} = ${newInnings}`)

    // Additional debugging for accumulated changes
    console.log(`🔍 Tabmon accumulated changes debug:`)
    console.log(`   Player changes object:`, playerChanges)
    console.log(`   All accumulated changes:`, this.clientState.accumulatedChanges)
    console.log(`   Score element dataset:`, scoreElement.dataset)
    console.log(`   Innings element dataset:`, inningsElement.dataset)

    // Store update in history for potential rollback
    this.clientState.updateHistory.push({
      playerId,
      previousScore: currentDomScore,
      previousInnings: currentDomInnings,
      newScore,
      newInnings,
      operation,
      timestamp: Date.now()
    })

    // Immediate visual update for both counters
    console.log(`🖥️ Tabmon updating DOM: score ${currentDomScore} → ${newScore}, innings ${currentDomInnings} → ${newInnings}`)
    scoreElement.textContent = newScore
    scoreElement.classList.add('score-updated')

    inningsElement.textContent = newInnings
    inningsElement.classList.add('score-updated')

    // Remove highlight after animation
    setTimeout(() => {
      scoreElement.classList.remove('score-updated')
      inningsElement.classList.remove('score-updated')
    }, 150)

    // Store in client state
    this.clientState.scores[playerId] = newScore

    // Add pending indicator to both elements
    this.addPendingIndicator(scoreElement)
    this.addPendingIndicator(inningsElement)

      console.log(`✅ Tabmon optimistic update complete: ${playerId} display = ${newScore}`)
    } catch (error) {
      console.error(`❌ Tabmon updateScoreOptimistically ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      console.error(`❌ PlayerId: ${playerId}, Points: ${points}, Operation: ${operation}`)
      // Don't rethrow to prevent breaking the UI
    }
  }

  // Optimistic player change - immediate visual feedback
  changePlayerOptimistically() {
    console.log("Tabmon changing player optimistically")

    // Store current state for potential rollback
    this.clientState.updateHistory.push({
      type: 'player_change',
      previousPlayer: this.clientState.currentPlayer,
      timestamp: Date.now()
    })

    // Update current player in client state
    this.clientState.currentPlayer = this.clientState.currentPlayer === 'playera' ? 'playerb' : 'playera'

    // Update display if available
    const currentPlayerSpan = document.getElementById('current-player')
    if (currentPlayerSpan) {
      currentPlayerSpan.textContent = this.clientState.currentPlayer === 'playera' ? 'Player A' : 'Player B'
    }

    // Add pending indicator to center controls
    const centerControls = document.querySelector('.bg-gray-700')
    if (centerControls) {
      this.addPendingIndicator(centerControls)
    }

    console.log(`Tabmon optimistic player change: ${this.clientState.currentPlayer}`)
  }

  // Add visual indicator for pending updates
  addPendingIndicator(element) {
    if (element) {
      element.classList.add('pending-update')
      console.log("Tabmon added pending indicator to:", element)
    }
  }

  // Remove pending indicator
  removePendingIndicator(element) {
    if (element) {
      element.classList.remove('pending-update')
      console.log("Tabmon removed pending indicator from:", element)
    }
  }

  // Get current active player by looking at the DOM
  getCurrentActivePlayer() {
    // Look for the active player by checking which side has the green border
    const leftPlayer = document.querySelector('#left')
    const rightPlayer = document.querySelector('#right')

    if (leftPlayer && leftPlayer.classList.contains('border-green-400')) {
      return leftPlayer.dataset.player || 'playera'
    } else if (rightPlayer && rightPlayer.classList.contains('border-green-400')) {
      return rightPlayer.dataset.player || 'playerb'
    }

    // Fallback to client state
    return this.clientState.currentPlayer || 'playera'
  }

  // NEW: Get the goal for a specific player
  getPlayerGoal(playerId) {
    const goalElement = document.querySelector(`.goal[data-player="${playerId}"]`)
    if (!goalElement) {
      console.log(`⚠️ No goal element found for player ${playerId}`)
      return null
    }
    
    const goalText = goalElement.textContent
    console.log(`🎯 Goal text for ${playerId}: "${goalText}"`)
    
    // Extract number from "Goal: 50" or "Goal: no limit" or "Ziel: 20"
    const match = goalText.match(/(?:Goal|Ziel):\s*(\d+|no limit)/i)
    if (match) {
      if (match[1] === 'no limit') {
        console.log(`🎯 No limit goal for ${playerId}`)
        return null // null means no limit
      } else {
        const goal = parseInt(match[1])
        console.log(`🎯 Goal for ${playerId}: ${goal}`)
        return goal
      }
    }
    
    console.log(`⚠️ Could not parse goal for ${playerId}: "${goalText}"`)
    return null
  }

  // NEW: Check if an increment would be valid (not negative score, not exceeding goal)
  isValidIncrement(playerId, points, operation) {
    console.log(`🔍 Validating increment: ${playerId} ${operation} ${points}`)
    console.log(`🚨 NEW VALIDATION CODE IS RUNNING - BROWSER CACHE CLEARED!`)
    
    // Get current score from DOM
    const scoreElement = document.querySelector(`.main-score[data-player="${playerId}"]`)
    const inningsElement = document.querySelector(`.inning-score[data-player="${playerId}"]`)
    
    if (!scoreElement || !inningsElement) {
      console.log(`⚠️ Missing score or innings element for ${playerId}`)
      return false
    }
    
    const currentScore = parseInt(scoreElement.textContent) || 0
    const currentInnings = parseInt(inningsElement.textContent) || 0
    
    console.log(`📊 Current state for ${playerId}: score=${currentScore}, innings=${currentInnings}`)
    
    // Get accumulated changes
    const accumulated = this.clientState.accumulatedChanges[playerId] || { totalIncrement: 0, operations: [] }
    const totalAccumulated = accumulated.totalIncrement || 0
    
    console.log(`📊 Accumulated changes for ${playerId}: ${totalAccumulated}`)
    
    // Calculate what the new values would be after this increment
    // Note: totalAccumulated does NOT include the current operation being validated
    // We need to calculate from the ORIGINAL score, not the current displayed score
    let originalScore = parseInt(scoreElement.dataset.originalScore) || 0
    let originalInnings = parseInt(inningsElement.dataset.originalInnings) || 0
    
    // If data-original-score doesn't exist yet, use current score minus accumulated changes
    if (originalScore === 0 && totalAccumulated !== 0) {
      originalScore = currentScore - totalAccumulated
      originalInnings = currentInnings - totalAccumulated
      console.log(`🔧 FIXED: Calculated original score from current - accumulated: ${currentScore} - ${totalAccumulated} = ${originalScore}`)
    } else if (originalScore === 0 && totalAccumulated === 0) {
      // No accumulated changes, so current score is the original score
      originalScore = currentScore
      originalInnings = currentInnings
      console.log(`🔧 FIXED: Using current score as original score: ${originalScore}`)
    } else {
      console.log(`🔧 FIXED: Using data-original-score: ${originalScore}`)
    }
    
    console.log(`📊 Original values: score=${originalScore}, innings=${originalInnings}`)
    
    let newScore = originalScore + totalAccumulated
    let newInnings = originalInnings + totalAccumulated
    
    // Then add/subtract the current increment
    if (operation === 'add') {
      newScore += points
      newInnings += points
    } else if (operation === 'subtract') {
      newScore -= points
      newInnings -= points
    }
    
    console.log(`📊 After increment: score=${newScore}, innings=${newInnings}`)
    console.log(`📊 Calculation: ${originalScore} + ${totalAccumulated} ${operation === 'add' ? '+' : '-'} ${points} = ${newScore}`)
    
    // Check if score would be negative
    if (newScore < 0) {
      console.log(`❌ Invalid: Score would be negative (${newScore})`)
      return false
    }
    
    // Check if score would exceed goal
    const goal = this.getPlayerGoal(playerId)
    if (goal !== null && newScore > goal) {
      console.log(`❌ Invalid: Score would exceed goal (${newScore} > ${goal})`)
      return false
    }
    
    console.log(`✅ Valid increment for ${playerId}`)
    
    // 🚀 NEW: Check if this increment reaches the goal - if so, trigger immediate validation
    const goalValue = this.getPlayerGoal(playerId)
    if (goalValue !== null && newScore === goalValue) {
      console.log(`🎯 GOAL REACHED! Score ${newScore} equals goal ${goalValue} - will trigger immediate validation`)
      // Mark this as a goal-reaching increment for immediate validation
      return { valid: true, reachesGoal: true }
    }
    
    return true
  }



  // Revert last score change
  revertLastScoreChange() {
    const lastUpdate = this.clientState.updateHistory.pop()
    if (lastUpdate && lastUpdate.type !== 'player_change') {
      // Revert both main score and innings counter
      const scoreElement = document.querySelector(`.main-score[data-player="${lastUpdate.playerId}"]`)
      const inningsElement = document.querySelector(`.inning-score[data-player="${lastUpdate.playerId}"]`)

      if (scoreElement) {
        scoreElement.textContent = lastUpdate.previousScore
        scoreElement.classList.add('score-updated')
        setTimeout(() => scoreElement.classList.remove('score-updated'), 150)
      }

      if (inningsElement && lastUpdate.previousInnings !== undefined) {
        inningsElement.textContent = lastUpdate.previousInnings
        inningsElement.classList.add('score-updated')
        setTimeout(() => inningsElement.classList.remove('score-updated'), 150)
      }

      console.log(`Tabmon reverted ${lastUpdate.playerId} to ${lastUpdate.previousScore} (innings: ${lastUpdate.previousInnings})`)
    }
  }

  /* Reflex methods for control buttons */


  key_a () {
    console.log('KEY_A called')

    // Get the player ID for the left side
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'

    // Get which player currently has the green border (active player)
    const activePlayerId = this.getCurrentActivePlayer()

    // Check if we're clicking on the active player's side or opposite side
    if (activePlayerId === playerId) {
      console.log(`Clicking on active player (${playerId}) - adding score`)
      // 🚀 NEW: Accumulate change FIRST, then update display
      const accumulated = this.accumulateAndValidateChange(playerId, 1, 'add')

      // Only update display if accumulation was successful
      if (accumulated) {
        // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
        this.updateScoreOptimistically(playerId, 1, 'add')
      }
    } else {
      console.log(`Active player is ${activePlayerId}, clicking LEFT (Key A) should switch to left player`)
      // 🚀 TRIGGER NEXT_STEP when clicking on opposite side of active player
      this.next_step()
    }
  }

  key_b () {
    console.log('KEY_B called')

    // Get the player ID for the right side
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'

    // Get which player currently has the green border (active player)
    const activePlayerId = this.getCurrentActivePlayer()

    console.log(`🔍 Key B Debug:`)
    console.log(`   Right side playerId: ${playerId}`)
    console.log(`   Active player: ${activePlayerId}`)
    console.log(`   Are they equal? ${activePlayerId === playerId}`)

    // Check if we're clicking on the active player's side or opposite side
    if (activePlayerId === playerId) {
      console.log(`✅ Clicking on active player (${playerId}) - adding score`)
      // 🚀 NEW: Accumulate change FIRST, then update display
      const accumulated = this.accumulateAndValidateChange(playerId, 1, 'add')

      // Only update display if accumulation was successful
      if (accumulated) {
        // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
        this.updateScoreOptimistically(playerId, 1, 'add')
      }
    } else {
      console.log(`🔄 Active player is ${activePlayerId}, clicking RIGHT (Key B) should switch to right player`)
      // 🚀 TRIGGER NEXT_STEP when clicking on opposite side of active player
      this.next_step()
    }
  }
  key_c () {
    console.log('KEY_C')
    this.stimulate('TableMonitor#key_c')
  }
  key_d () {
    console.log('KEY_D')
    this.stimulate('TableMonitor#key_d')
  }

  add_n () {
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1

    console.log(`ADD_N called - active player: ${activePlayerId}, adding ${n}`)

    // Always increment the active player (the one with green border)
    console.log(`✅ Adding ${n} to active player (${activePlayerId})`)
    
    // 🚀 NEW: Accumulate change FIRST, then update display
    const accumulated = this.accumulateAndValidateChange(activePlayerId, n, 'add')

    // Only update display if accumulation was successful
    if (accumulated) {
      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(activePlayerId, n, 'add')
    }
  }

  minus_n () {
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1

    console.log(`MINUS_N called - active player: ${activePlayerId}, subtracting ${n}`)

    // Always decrement the active player (the one with green border)
    console.log(`✅ Subtracting ${n} from active player (${activePlayerId})`)
    
    // 🚀 NEW: Accumulate change FIRST, then update display
    const accumulated = this.accumulateAndValidateChange(activePlayerId, n, 'subtract')

    // Only update display if accumulation was successful
    if (accumulated) {
      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(activePlayerId, n, 'subtract')
    }
  }

  undo () {
    const tableMonitorId = this.element.dataset.id

    // 🚀 IMMEDIATE OPTIMISTIC UNDO
    this.revertLastScoreChange()

    // Mark as pending update
    this.clientState.pendingUpdates.add(`undo_${tableMonitorId}`)

    // 🚀 DIRECT SERVER VALIDATION - immediate call
    this.stimulate('TableMonitor#undo')
  }

  next_step () {
    console.log("🚀 Tabmon next_step called - starting debug")
    const tableMonitorId = this.element.dataset.id

    // 🚀 CRITICAL: Validate any pending accumulated changes BEFORE switching players
    console.log("🚀 Tabmon next_step - about to call hasPendingAccumulatedChanges")
    let hasPendingChanges = false
    try {
      hasPendingChanges = this.hasPendingAccumulatedChanges()
      console.log(`🚀 Tabmon next_step - hasPendingAccumulatedChanges returned: ${hasPendingChanges}`)
    } catch (error) {
      console.error("❌ Tabmon next_step - Error calling hasPendingAccumulatedChanges:", error)
      hasPendingChanges = false
    }
    
    if (hasPendingChanges) {
      console.log(`🚨 Tabmon next_step: Found pending accumulated changes - validating immediately before player switch`)
      
      // 🚀 Set flag to trigger player switch after validation completes
      this.clientState.pendingPlayerSwitch = tableMonitorId
      console.log(`📝 Tabmon next_step: Set pendingPlayerSwitch flag to ${tableMonitorId}`)
      
      this.validateAccumulatedChangesImmediately()
      
      // 🚀 IMPORTANT: Don't proceed with switch until validation completes
      // The switch will be handled in the reflexSuccess callback after validation
      console.log(`⏳ Tabmon next_step: Waiting for accumulated validation to complete before switching players`)
      return // Exit early - switch will happen after validation success
    }

    // 🚀 No pending changes - proceed with immediate player switch
    this.performPlayerSwitch(tableMonitorId)
  }

  // 🚀 NEW: Perform the actual player switch (extracted for reuse)
  performPlayerSwitch(tableMonitorId) {
    console.log(`🔄 Tabmon performing player switch`)
    
    // 🚀 IMMEDIATE OPTIMISTIC PLAYER CHANGE
    this.changePlayerOptimistically()

    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)

    // 🚀 DIRECT SERVER VALIDATION - immediate call
    this.stimulate('TableMonitor#next_step')
  }

  numbers () {
    this.stimulate('TableMonitor#numbers')
  }

  force_next_state () {
    this.stimulate('TableMonitor#force_next_state')
  }

  stop () {
    this.stimulate('TableMonitor#stop')
  }

  timeout () {
    this.stimulate('TableMonitor#timeout')
  }

  pause () {
    console.log('Tabmon pause called')
    this.stimulate('TableMonitor#pause')
  }

  play () {
    console.log('Tabmon play called')
    this.stimulate('TableMonitor#play')
  }

  // Lifecycle methods for debugging and error handling
  beforeReflex (element, reflex, noop, id) {
    console.log(`Tabmon beforeReflex: ${reflex}`)
  }

  reflexSuccess (element, reflex, noop, id) {
    console.log(`✅ Tabmon reflexSuccess: ${reflex}`)

    // Remove pending indicators on successful server validation
    this.removeAllPendingIndicators()

    // Clear pending updates for this reflex
    const tableMonitorId = element.dataset.id
    if (reflex.includes('add_n')) {
      this.clientState.pendingUpdates.delete(`add_n_${tableMonitorId}`)
    } else if (reflex.includes('minus_n')) {
      this.clientState.pendingUpdates.delete(`minus_n_${tableMonitorId}`)
    } else if (reflex.includes('undo')) {
      this.clientState.pendingUpdates.delete(`undo_${tableMonitorId}`)
    } else if (reflex.includes('next_step')) {
      this.clientState.pendingUpdates.delete(`next_step_${tableMonitorId}`)
    } else if (reflex.includes('validate_accumulated_changes')) {
      // NEW: Reset original scores after successful accumulated validation
      console.log("🎉 Tabmon accumulated validation successful!")
      console.log("   Server has processed all accumulated changes")
      console.log("   Current DOM state should now match server state")

      // Get current DOM values before resetting
      const scoreElements = document.querySelectorAll('.main-score[data-player]')
      const inningsElements = document.querySelectorAll('.inning-score[data-player]')

      console.log("📊 Current DOM state before reset:")
      scoreElements.forEach(element => {
        console.log(`   ${element.dataset.player} score: ${element.textContent}`)
      })
      inningsElements.forEach(element => {
        console.log(`   ${element.dataset.player} innings: ${element.textContent}`)
      })

      this.resetOriginalScores()
      this.clearAccumulatedChanges()

      console.log("🎉 Tabmon validation cycle complete - ready for new changes")
      
      // 🚀 NEW: Check if there's a pending player switch after validation
      if (this.clientState.pendingPlayerSwitch) {
        const tableMonitorId = this.clientState.pendingPlayerSwitch
        console.log(`🔄 Tabmon validation complete - now performing pending player switch for ${tableMonitorId}`)
        
        // Clear the pending flag
        this.clientState.pendingPlayerSwitch = null
        
        // Perform the player switch
        this.performPlayerSwitch(tableMonitorId)
      }
    }
  }

  reflexError (element, reflex, error, id) {
    console.error(`Tabmon reflexError: ${reflex}`, error)

    // Rollback optimistic changes on server error
    this.rollbackOptimisticChanges(reflex)

    // Show error message to user
    this.showErrorMessage(`Server error: ${error}`)
  }

  // Rollback optimistic changes when server validation fails
  rollbackOptimisticChanges(reflex) {
    console.log(`Tabmon rolling back optimistic changes for: ${reflex}`)

    if (reflex.includes('add_n') || reflex.includes('minus_n')) {
      // Revert last score change
      this.revertLastScoreChange()
    } else if (reflex.includes('next_step')) {
      // Revert player change
      const lastUpdate = this.clientState.updateHistory.pop()
      if (lastUpdate && lastUpdate.type === 'player_change') {
        this.clientState.currentPlayer = lastUpdate.previousPlayer
        const currentPlayerSpan = document.getElementById('current-player')
        if (currentPlayerSpan) {
          currentPlayerSpan.textContent = this.clientState.currentPlayer === 'playera' ? 'Player A' : 'Player B'
        }
      }
    }

    // Remove all pending indicators
    this.removeAllPendingIndicators()
  }

  // Remove all pending indicators
  removeAllPendingIndicators() {
    document.querySelectorAll('.pending-update').forEach(el => {
      this.removePendingIndicator(el)
    })
  }

  // NEW: Accumulate changes and validate with total sum
  accumulateAndValidateChange(playerId, points, operation = 'add') {
    try {
      console.log(`🔄 Tabmon accumulating change: ${playerId} ${operation} ${points}`)

      // 🚀 NEW: Validate before accumulating
      const validationResult = this.isValidIncrement(playerId, points, operation)
      if (!validationResult || validationResult === false) {
        console.log(`❌ Tabmon increment blocked by validation`)
        return false // Block the increment
      }
      
      // Check if this increment reaches the goal
      const reachesGoal = validationResult && typeof validationResult === 'object' && validationResult.reachesGoal

      // Add to accumulated changes
      const playerChanges = this.clientState.accumulatedChanges[playerId]
    const previousTotal = playerChanges.totalIncrement

    if (operation === 'add') {
      playerChanges.totalIncrement += points
      playerChanges.operations.push({ type: 'add', points, timestamp: Date.now() })
    } else if (operation === 'subtract') {
      playerChanges.totalIncrement -= points
      playerChanges.operations.push({ type: 'subtract', points, timestamp: Date.now() })
    }

    console.log(`📊 Tabmon accumulation update: ${playerId}`)
    console.log(`   Previous total: ${previousTotal}`)
    console.log(`   New total: ${playerChanges.totalIncrement}`)
    console.log(`   Operations count: ${playerChanges.operations.length}`)
    console.log(`   All operations:`, playerChanges.operations)

    // Cancel previous validation timer
    if (this.clientState.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
      console.log(`⏰ Tabmon cancelled previous validation timer`)
    }

    // 🚀 NEW: If goal is reached, validate immediately instead of using timer
    if (reachesGoal) {
      console.log(`🎯 GOAL REACHED - triggering immediate validation (bypassing ${VALIDATION_DELAY_MS}ms delay)`)
      this.validateAccumulatedChanges()
    } else {
      // Set new validation timer - validate with total after VALIDATION_DELAY_MS of inactivity
      this.clientState.validationTimer = setTimeout(() => {
        console.log(`⏰ Tabmon validation timer triggered - validating accumulated changes`)
        this.validateAccumulatedChanges()
      }, VALIDATION_DELAY_MS)

      console.log(`⏰ Tabmon set new validation timer (${VALIDATION_DELAY_MS}ms)`)
    }

      return true // Successfully accumulated
    } catch (error) {
      console.error(`❌ Tabmon accumulateAndValidateChange ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Don't rethrow to prevent breaking the UI
      return false
    }
  }

  // NEW: Validate all accumulated changes with total sum
  validateAccumulatedChanges() {
    try {
      console.log("🚀 Tabmon validating accumulated changes:", this.clientState.accumulatedChanges)

    const changes = this.clientState.accumulatedChanges
    let hasChanges = false

    // Check if there are any accumulated changes
    for (const playerId in changes) {
      if (changes[playerId].totalIncrement !== 0) {
        hasChanges = true
        console.log(`📊 Tabmon found changes for ${playerId}: ${changes[playerId].totalIncrement}`)
      }
    }

    if (!hasChanges) {
      console.log("ℹ️ Tabmon no accumulated changes to validate")
      return
    }

    // Create a single validation call with all accumulated changes
    const validationData = {
      accumulatedChanges: {},
      timestamp: Date.now()
    }

    // Prepare validation data for each player
    for (const playerId in changes) {
      const playerChanges = changes[playerId]
      if (playerChanges.totalIncrement !== 0) {
        validationData.accumulatedChanges[playerId] = {
          totalIncrement: playerChanges.totalIncrement,
          operationCount: playerChanges.operations.length,
          operations: playerChanges.operations
        }
        console.log(`📤 Tabmon preparing validation for ${playerId}:`)
        console.log(`   Total increment: ${playerChanges.totalIncrement}`)
        console.log(`   Operations: ${playerChanges.operations.length}`)
        console.log(`   Operations list:`, playerChanges.operations)
      }
    }

    console.log("📡 Tabmon sending validation with accumulated data:", validationData)

    // Send single validation call with accumulated changes
    this.stimulate('TableMonitor#validate_accumulated_changes', this.element, validationData)

    // 🚀 CRITICAL: Don't clear accumulated changes here - wait for server response
    // The changes will be cleared in reflexSuccess after server confirms they were processed
    console.log("📡 Tabmon validation sent - keeping accumulated changes until server confirms")
    } catch (error) {
      console.error(`❌ Tabmon validateAccumulatedChanges ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Clear accumulated changes to prevent stuck state
      this.clearAccumulatedChanges()
    }
  }

  // NEW: Check if there are any pending accumulated changes
  hasPendingAccumulatedChanges() {
    console.log(`🔍 Tabmon hasPendingAccumulatedChanges called`)
    console.log(`   this.clientState:`, this.clientState)
    console.log(`   this.clientState.accumulatedChanges:`, this.clientState.accumulatedChanges)
    
    const changes = this.clientState.accumulatedChanges
    console.log(`🔍 Tabmon checking for pending accumulated changes:`, changes)
    
    for (const playerId in changes) {
      console.log(`   ${playerId}: totalIncrement = ${changes[playerId].totalIncrement}`)
      if (changes[playerId].totalIncrement !== 0) {
        console.log(`📊 Tabmon found pending changes for ${playerId}: ${changes[playerId].totalIncrement}`)
        return true
      }
    }
    console.log(`📊 Tabmon no pending accumulated changes found`)
    return false
  }

  // NEW: Validate accumulated changes immediately (bypass timer)
  validateAccumulatedChangesImmediately() {
    console.log("🚀 Tabmon validating accumulated changes immediately (bypassing timer)")

    // Clear the validation timer since we're validating immediately
    if (this.clientState.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
      this.clientState.validationTimer = null
      console.log(`⏰ Tabmon cleared validation timer for immediate validation`)
    }

    // Call the existing validation method
    this.validateAccumulatedChanges()
  }

  // NEW: Clear accumulated changes after successful validation
  clearAccumulatedChanges() {
    console.log("🧹 Tabmon clearAccumulatedChanges called")
    console.log("   Before clear:", this.clientState.accumulatedChanges)

    // Clear both local and global accumulated changes
    const clearedChanges = {
      playera: { totalIncrement: 0, operations: [] },
      playerb: { totalIncrement: 0, operations: [] }
    }
    
    this.clientState.accumulatedChanges = clearedChanges
    
    // Also clear global state
    if (window.TabmonGlobalState) {
      window.TabmonGlobalState.accumulatedChanges = clearedChanges
      console.log("   Also cleared global accumulated changes")
    }

    console.log("   After clear:", this.clientState.accumulatedChanges)

    // Reset original scores to current values for future calculations
    this.resetOriginalScores()
  }

  // NEW: Reset original scores to current DOM values after successful server validation
  resetOriginalScores() {
    console.log("🔄 Tabmon resetting original scores to current values")

    const scoreElements = document.querySelectorAll('.main-score[data-player]')
    const inningsElements = document.querySelectorAll('.inning-score[data-player]')

    scoreElements.forEach(element => {
      const currentScore = parseInt(element.textContent) || 0
      const previousOriginal = element.dataset.originalScore
      element.dataset.originalScore = currentScore.toString()
      console.log(`🔄 Tabmon reset original score for ${element.dataset.player}: ${previousOriginal} → ${currentScore}`)
    })

    inningsElements.forEach(element => {
      const currentInnings = parseInt(element.textContent) || 0
      const previousOriginal = element.dataset.originalInnings
      element.dataset.originalInnings = currentInnings.toString()
      console.log(`🔄 Tabmon reset original innings for ${element.dataset.player}: ${previousOriginal} → ${currentInnings}`)
    })
  }


  // Show error message to user
  showErrorMessage(message) {
    // Simple error display - could be enhanced with toast notifications
    console.error(`Tabmon Error: ${message}`)

    // Add visual error indicator
    const errorElement = document.createElement('div')
    errorElement.className = 'error-message'
    errorElement.textContent = message
    errorElement.style.cssText = `
      position: fixed;
      top: 20px;
      right: 20px;
      background: #ef4444;
      color: white;
      padding: 10px;
      border-radius: 5px;
      z-index: 9999;
    `
    document.body.appendChild(errorElement)

    // Remove after 3 seconds
    setTimeout(() => {
      if (errorElement.parentNode) {
        errorElement.parentNode.removeChild(errorElement)
      }
    }, 3000)
  }
}
