import ApplicationController from './application_controller'

/* This is the StimulusReflex controller for the TableMonitor Controls.
 * Handles all the control buttons in the scoreboard controls row.
 * Now includes optimistic updates for immediate user feedback.
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log("🚀 Tabmon controller connected!")
    console.log("Tabmon element:", this.element)
    console.log("Tabmon element actions:", this.element.dataset.action)
    
    // Add multiple event listeners for debugging
    this.element.addEventListener('click', (event) => {
      console.log("🖱️ Click event detected on:", event.target)
      console.log("🖱️ Click event dataset:", event.target.dataset)
      console.log("🖱️ Click event action:", event.target.dataset.action)
    }, true) // Use capture phase
    
    this.element.addEventListener('mousedown', (event) => {
      console.log("🖱️ Mouse down detected on:", event.target)
    })
    
    this.element.addEventListener('mouseup', (event) => {
      console.log("🖱️ Mouse up detected on:", event.target)
    })
    
    // Add document-level click listener to see if clicks are being detected at all
    document.addEventListener('click', (event) => {
      if (event.target.closest('[data-controller="tabmon"]')) {
        console.log("📄 Document click detected on tabmon element:", event.target)
        console.log("📄 Document click dataset:", event.target.dataset)
      }
    })
    
    this.initializeClientState()
    
    // Add global error handler for this controller
    this.errorHandler = (event) => {
      console.error(`❌ Tabmon GLOBAL ERROR:`, event.error)
      console.error(`❌ Error stack:`, event.error?.stack)
      console.error(`❌ Event:`, event)
    }
    window.addEventListener('error', this.errorHandler)
  }

  disconnect() {
    // Clean up validation timer when controller disconnects
    if (this.clientState?.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
    }
    
    // Remove global error handler
    if (this.errorHandler) {
      window.removeEventListener('error', this.errorHandler)
    }
    
    console.log("Tabmon controller disconnected and timers cleared")
  }

  initializeClientState() {
    // Initialize client-side state for immediate feedback
    this.clientState = {
      scores: {},
      currentPlayer: 'playera',
      pendingUpdates: new Set(),
      updateHistory: [],
      // NEW: Accumulated changes tracking
      accumulatedChanges: {
        playera: { totalIncrement: 0, operations: [] },
        playerb: { totalIncrement: 0, operations: [] }
      },
      validationTimer: null
    }
    
    console.log("Tabmon client state initialized:", this.clientState)
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

  // Check if there is actually an active player with green border
  hasActivePlayerWithGreenBorder() {
    const leftPlayer = document.querySelector('#left')
    const rightPlayer = document.querySelector('#right')
    
    return (leftPlayer && leftPlayer.classList.contains('border-green-400')) ||
           (rightPlayer && rightPlayer.classList.contains('border-green-400'))
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

  add_n () {
    console.log("🎯 add_n method called!")
    console.log("Element:", this.element)
    console.log("Element dataset:", this.element.dataset)
    
    const n = parseInt(this.element.dataset.n) || 1
    const tableMonitorId = this.element.dataset.id
    console.log(`Tabmon add_n called with n=${n}, tableMonitorId=${tableMonitorId}`)

    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if there's a green border
    if (this.hasActivePlayerWithGreenBorder()) {
      const currentPlayer = this.getCurrentActivePlayer()
      this.updateScoreOptimistically(currentPlayer, n, 'add')
      
      // 🚀 NEW: Accumulate change and validate with total sum
      this.accumulateAndValidateChange(currentPlayer, n, 'add')
    } else {
      console.log("No green border detected - skipping optimistic update")
    }
  }

  minus_n () {
    const n = parseInt(this.element.dataset.n) || 1
    const tableMonitorId = this.element.dataset.id
    console.log(`Tabmon minus_n called with n=${n}`)
    
    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if there's a green border
    if (this.hasActivePlayerWithGreenBorder()) {
      const currentPlayer = this.getCurrentActivePlayer()
      this.updateScoreOptimistically(currentPlayer, n, 'subtract')
      
      // 🚀 NEW: Accumulate change and validate with total sum
      this.accumulateAndValidateChange(currentPlayer, n, 'subtract')
    } else {
      console.log("No green border detected - skipping optimistic update")
    }
  }

  undo () {
    const tableMonitorId = this.element.dataset.id
    console.log('Tabmon undo called')
    
    // 🚀 IMMEDIATE OPTIMISTIC UNDO
    this.revertLastScoreChange()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`undo_${tableMonitorId}`)
    
    // 🚀 DEBOUNCED SERVER VALIDATION - wait 500ms after last click
    this.debouncedServerCall('undo', this.element, 500)
  }

  next_step () {
    const tableMonitorId = this.element.dataset.id
    console.log('Tabmon next_step called')
    
    // 🚀 IMMEDIATE OPTIMISTIC PLAYER CHANGE
    this.changePlayerOptimistically()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)
    
    // 🚀 DEBOUNCED SERVER VALIDATION - wait 500ms after last click
    this.debouncedServerCall('next_step', this.element, 500)
  }

  numbers () {
    console.log('Tabmon numbers called')
    this.stimulate('TableMonitor#numbers')
  }

  force_next_state () {
    console.log('Tabmon force_next_state called')
    this.stimulate('TableMonitor#force_next_state')
  }

  stop () {
    console.log('Tabmon stop called')
    this.stimulate('TableMonitor#stop')
  }

  timeout () {
    console.log('Tabmon timeout called')
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
    
    // Set new validation timer - validate with total after 500ms of inactivity
    this.clientState.validationTimer = setTimeout(() => {
      console.log(`⏰ Tabmon validation timer triggered - validating accumulated changes`)
      this.validateAccumulatedChanges()
    }, 500)
    
      console.log(`⏰ Tabmon set new validation timer (500ms)`)
    } catch (error) {
      console.error(`❌ Tabmon accumulateAndValidateChange ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Don't rethrow to prevent breaking the UI
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
    
    // Clear accumulated changes after sending validation
    this.clearAccumulatedChanges()
    } catch (error) {
      console.error(`❌ Tabmon validateAccumulatedChanges ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Clear accumulated changes to prevent stuck state
      this.clearAccumulatedChanges()
    }
  }

  // NEW: Clear accumulated changes after successful validation
  clearAccumulatedChanges() {
    console.log("🧹 Tabmon clearing accumulated changes")
    console.log("   Before clear:", this.clientState.accumulatedChanges)
    
    this.clientState.accumulatedChanges = {
      playera: { totalIncrement: 0, operations: [] },
      playerb: { totalIncrement: 0, operations: [] }
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
