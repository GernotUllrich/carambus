import ApplicationController from './application_controller'

// Configuration: Validation delay in milliseconds
const VALIDATION_DELAY_MS = 3000 // Change this to test different delays

/* This is the custom StimulusReflex controller for the Example Reflex.
 * Learn more at: https://docs.stimulusreflex.com
 */
export default class extends ApplicationController {
  /*
   * Regular Stimulus lifecycle methods
   * Learn more at: https://stimulusjs.org/reference/lifecycle-callbacks
   *
   * If you intend to use this controller as a regular stimulus controller as well,
   * make sure any Stimulus lifecycle methods overridden in ApplicationController call super.
   *
   * Important:
   * By default, StimulusReflex overrides the -connect- method so make sure you
   * call super if you intend to do anything else when this controller connects.
  */

  connect () {
    super.connect()
    // Initialize client state for optimistic updates
    this.clientState = {
      scores: {},
      currentPlayer: 'playera',
      pendingUpdates: new Set(),
      updateHistory: [],
      accumulatedChanges: {
        playera: { totalIncrement: 0, operations: [] },
        playerb: { totalIncrement: 0, operations: [] }
      },
      validationTimer: null
    }
  }

  /* Reflex specific lifecycle methods.
   *
   * For every method defined in your Reflex class, a matching set of lifecycle methods become available
   * in this javascript controller. These are optional, so feel free to delete these stubs if you don't
   * need them.
   *
   * Important:
   * Make sure to add data-controller="example" to your markup alongside
   * data-reflex="Example#dance" for the lifecycle methods to fire properly.
   *
   * Example:
   *
   *   <a href="#" data-reflex="click->Example#dance" data-controller="example">Dance!</a>
   *
   * Arguments:
   *
   *   element - the element that triggered the reflex
   *             may be different than the Stimulus controller's this.element
   *
   *   reflex - the name of the reflex e.g. "Example#dance"
   *
   *   error/noop - the error message (for reflexError), otherwise null
   *
   *   reflexId - a UUID4 or developer-provided unique identifier for each Reflex
   */
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

  // Check if the specific player has a green border
  hasActivePlayerWithGreenBorder(playerId) {
    const leftPlayer = document.querySelector('#left')
    const rightPlayer = document.querySelector('#right')

    // Check if the left player is active and matches the playerId
    if (leftPlayer && leftPlayer.classList.contains('border-green-400') &&
        (leftPlayer.dataset.player === playerId || (!leftPlayer.dataset.player && playerId === 'playera'))) {
      return true
    }

    // Check if the right player is active and matches the playerId
    if (rightPlayer && rightPlayer.classList.contains('border-green-400') &&
        (rightPlayer.dataset.player === playerId || (!rightPlayer.dataset.player && playerId === 'playerb'))) {
      return true
    }

    return false
  }

  // Optimistic score update - immediate visual feedback
  updateScoreOptimistically(playerId, points, operation = 'add') {
    try {
      console.log(`🎯 TableMonitor updating score: ${playerId} ${operation} ${points}`)

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

      // Store original scores if not already stored
      if (!scoreElement.dataset.originalScore) {
        const currentScore = parseInt(scoreElement.textContent) || 0
        scoreElement.dataset.originalScore = currentScore
        console.log(`💾 TableMonitor stored original score for ${playerId}: ${currentScore}`)
      }

      if (!inningsElement.dataset.originalInnings) {
        const currentInnings = parseInt(inningsElement.textContent) || 0
        inningsElement.dataset.originalInnings = currentInnings
        console.log(`💾 TableMonitor stored original innings for ${playerId}: ${currentInnings}`)
      }

      // Get accumulated changes for this player
      const playerChanges = this.clientState.accumulatedChanges[playerId]
      const totalIncrement = playerChanges.totalIncrement

      // Calculate new scores using original + total accumulated increment
      const originalScore = parseInt(scoreElement.dataset.originalScore) || 0
      const originalInnings = parseInt(inningsElement.dataset.originalInnings) || 0

      const newScore = originalScore + totalIncrement
      const newInnings = originalInnings + totalIncrement

      console.log(`📊 TableMonitor score calculation for ${playerId}:`)
      console.log(`   Current DOM score: ${scoreElement.textContent}`)
      console.log(`   Original score: ${originalScore}`)
      console.log(`   Total increment: ${totalIncrement}`)
      console.log(`   New score: ${originalScore} + ${totalIncrement} = ${newScore}`)
      console.log(`   Current DOM innings: ${inningsElement.textContent}`)
      console.log(`   Original innings: ${originalInnings}`)
      console.log(`   New innings: ${originalInnings} + ${totalIncrement} = ${newInnings}`)

      // Update both displays immediately
      scoreElement.textContent = newScore
      inningsElement.textContent = newInnings

      console.log(`🖥️ TableMonitor updating DOM: score ${scoreElement.textContent} → ${newScore}, innings ${inningsElement.textContent} → ${newInnings}`)

      // Add pending indicator
      this.addPendingIndicator(scoreElement)
      this.addPendingIndicator(inningsElement)

    } catch (error) {
      console.error(`❌ TableMonitor updateScoreOptimistically ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
    }
  }

  // Helper method to add pending indicator
  addPendingIndicator(element) {
    if (!element.classList.contains('pending-update')) {
      element.classList.add('pending-update')
      console.log(`TableMonitor added pending indicator to:`, element)
    }
  }

  // Helper method to remove pending indicator
  removePendingIndicator(element) {
    if (element.classList.contains('pending-update')) {
      element.classList.remove('pending-update')
      console.log(`TableMonitor removed pending indicator from:`, element)
    }
  }

/*
  key_a () {
    console.log('KEY_A called')

    // Get the player ID for the left side
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'

    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if this specific player has a green border
    if (this.hasActivePlayerWithGreenBorder(playerId)) {
      // 🚀 NEW: Accumulate change FIRST, then update display
      this.accumulateAndValidateChange(playerId, 1, 'add')

      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(playerId, 1, 'add')
    } else {
      console.log(`Player ${playerId} does not have green border - triggering next_step`)
      // 🚀 TRIGGER NEXT_STEP when clicking in non-green area
      this.next_step()
    }
  }

  key_b () {
    console.log('KEY_B called')

    // Get the player ID for the right side
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'

    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if this specific player has a green border
    if (this.hasActivePlayerWithGreenBorder(playerId)) {
      // 🚀 NEW: Accumulate change FIRST, then update display
      this.accumulateAndValidateChange(playerId, 1, 'add')

      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(playerId, 1, 'add')
    } else {
      console.log(`Player ${playerId} does not have green border - triggering next_step`)
      // 🚀 TRIGGER NEXT_STEP when clicking in non-green area
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
  }*/

  back () {
    window.history.back();
  }

  home () {
    this.stimulate('TableMonitor#home')
  }

  // StimulusReflex lifecycle methods for optimistic updates
  key_aSuccess(element, reflex, noop, reflexId) {
    console.log(`TableMonitor key_aSuccess: ${reflex}`)
    // Remove pending indicators on successful server validation
    this.clientState.pendingUpdates.delete(`key_a_${element.dataset.id}`)
  }

  key_aError(element, reflex, error, reflexId) {
    console.error(`TableMonitor key_aError: ${reflex}`, error)
    // Rollback optimistic changes on server error
    this.rollbackLastScoreChange()
    this.showErrorMessage(`Server error: ${error}`)
  }

  key_bSuccess(element, reflex, noop, reflexId) {
    console.log(`TableMonitor key_bSuccess: ${reflex}`)
    // Remove pending indicators on successful server validation
    this.clientState.pendingUpdates.delete(`key_b_${element.dataset.id}`)
  }

  key_bError(element, reflex, error, reflexId) {
    console.error(`TableMonitor key_bError: ${reflex}`, error)
    // Rollback optimistic changes on server error
    this.rollbackLastScoreChange()
    this.showErrorMessage(`Server error: ${error}`)
  }

  // NEW: Handle successful accumulated validation
  validate_accumulated_changesSuccess(element, reflex, noop, reflexId) {
    console.log(`✅ TableMonitor validate_accumulated_changesSuccess: ${reflex}`)

    // Remove pending indicators on successful server validation
    document.querySelectorAll('.pending-update').forEach(el => {
      this.removePendingIndicator(el)
    })

    console.log("🎉 TableMonitor accumulated validation successful!")
    console.log("   Server has processed all accumulated changes")
    console.log("   Current DOM state should now match server state")

    // Reset original scores to current values for future calculations
    this.resetOriginalScores()
    this.clearAccumulatedChanges()

    console.log("🎉 TableMonitor validation cycle complete - ready for new changes")
  }

  // Rollback last score change
  rollbackLastScoreChange() {
    const lastUpdate = this.clientState.updateHistory.pop()
    if (lastUpdate && lastUpdate.type === 'score_update') {
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

      console.log(`TableMonitor reverted ${lastUpdate.playerId} to ${lastUpdate.previousScore} (innings: ${lastUpdate.previousInnings})`)
    }
  }

  // Show error message to user
  showErrorMessage(message) {
    // Create a temporary error message
    const errorDiv = document.createElement('div')
    errorDiv.className = 'fixed top-4 right-4 bg-red-500 text-white p-4 rounded shadow-lg z-50'
    errorDiv.textContent = message
    document.body.appendChild(errorDiv)

    // Remove after 3 seconds
    setTimeout(() => {
      document.body.removeChild(errorDiv)
    }, 3000)
  }

  // Assuming you create a "Example#dance" action in your Reflex class
  // you'll be able to use the following lifecycle methods:

  // beforeDance(element, reflex, noop, reflexId) {
  //  element.innerText = 'Putting dance shoes on...'
  // }

  // danceSuccess(element, reflex, noop, reflexId) {
  //   element.innerText = 'Danced like no one was watching! Was someone watching?'
  // }

  // danceError(element, reflex, error, reflexId) {
  //   console.error('danceError', error);
  //   element.innerText = "Couldn't dance!"
  // }

  // NEW: Accumulate changes and validate with total sum
  accumulateAndValidateChange(playerId, points, operation = 'add') {
    try {
      console.log(`🔄 TableMonitor accumulating change: ${playerId} ${operation} ${points}`)

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

      console.log(`📊 TableMonitor accumulation update: ${playerId}`)
      console.log(`   Previous total: ${previousTotal}`)
      console.log(`   New total: ${playerChanges.totalIncrement}`)
      console.log(`   Operations count: ${playerChanges.operations.length}`)
      console.log(`   All operations:`, playerChanges.operations)

      // Cancel previous validation timer
      if (this.clientState.validationTimer) {
        clearTimeout(this.clientState.validationTimer)
        console.log(`⏰ TableMonitor cancelled previous validation timer`)
      }

      // Set new validation timer - validate with total after VALIDATION_DELAY_MS of inactivity
      this.clientState.validationTimer = setTimeout(() => {
        console.log(`⏰ TableMonitor validation timer triggered - validating accumulated changes`)
        this.validateAccumulatedChanges()
      }, VALIDATION_DELAY_MS)

      console.log(`⏰ TableMonitor set new validation timer (${VALIDATION_DELAY_MS}ms)`)
    } catch (error) {
      console.error(`❌ TableMonitor accumulateAndValidateChange ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Don't rethrow to prevent breaking the UI
    }
  }

  // NEW: Validate all accumulated changes with total sum
  validateAccumulatedChanges() {
    try {
      console.log("🚀 TableMonitor validating accumulated changes:", this.clientState.accumulatedChanges)

      const changes = this.clientState.accumulatedChanges
      let hasChanges = false

      // Check if there are any accumulated changes
      for (const playerId in changes) {
        if (changes[playerId].totalIncrement !== 0) {
          hasChanges = true
          console.log(`📊 TableMonitor found changes for ${playerId}: ${changes[playerId].totalIncrement}`)
        }
      }

      if (!hasChanges) {
        console.log("ℹ️ TableMonitor no accumulated changes to validate")
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
          console.log(`📤 TableMonitor preparing validation for ${playerId}:`)
          console.log(`   Total increment: ${playerChanges.totalIncrement}`)
          console.log(`   Operations: ${playerChanges.operations.length}`)
          console.log(`   Operations list:`, playerChanges.operations)
        }
      }

      console.log("📡 TableMonitor sending validation with accumulated data:", validationData)

      // Send single validation call with accumulated changes
      this.stimulate('TableMonitor#validate_accumulated_changes', this.element, validationData)

      // Clear accumulated changes after sending validation
      this.clearAccumulatedChanges()
    } catch (error) {
      console.error(`❌ TableMonitor validateAccumulatedChanges ERROR:`, error)
      console.error(`❌ Error stack:`, error.stack)
      // Clear accumulated changes to prevent stuck state
      this.clearAccumulatedChanges()
    }
  }

  // NEW: Clear accumulated changes after successful validation
  clearAccumulatedChanges() {
    console.log("🧹 TableMonitor clearing accumulated changes")
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
    console.log("🔄 TableMonitor resetting original scores to current values")

    const scoreElements = document.querySelectorAll('.main-score[data-player]')
    const inningsElements = document.querySelectorAll('.inning-score[data-player]')

    scoreElements.forEach(element => {
      const currentScore = parseInt(element.textContent) || 0
      element.dataset.originalScore = currentScore
      console.log(`🔄 TableMonitor reset original score for ${element.dataset.player}: ${currentScore} → ${currentScore}`)
    })

    inningsElements.forEach(element => {
      const currentInnings = parseInt(element.textContent) || 0
      element.dataset.originalInnings = currentInnings
      console.log(`🔄 TableMonitor reset original innings for ${element.dataset.player}: ${currentInnings} → ${currentInnings}`)
    })
  }

  // NEW: Optimistic player change - immediate visual feedback
  changePlayerOptimistically() {

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
      centerControls.classList.add('pending-update')
    }

  }

  // NEW: Next step method for player switching
  next_step() {
    const tableMonitorId = this.element.dataset.id

    // 🚀 IMMEDIATE OPTIMISTIC PLAYER CHANGE
    this.changePlayerOptimistically()

    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)

    // 🚀 DIRECT SERVER VALIDATION - immediate call
    this.stimulate('TableMonitor#next_step')
  }

  disconnect() {
    // Clear validation timer when controller disconnects
    if (this.clientState && this.clientState.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
      console.log("TableMonitor controller disconnected and timers cleared")
    }
    super.disconnect()
  }
}
