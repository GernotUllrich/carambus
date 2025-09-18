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
  }

  initializeClientState() {
    // Initialize client-side state for immediate feedback
    this.clientState = {
      scores: {},
      currentPlayer: 'playera',
      pendingUpdates: new Set(),
      updateHistory: []
    }
    console.log("Tabmon client state initialized:", this.clientState)
  }

  // Optimistic score update - immediate visual feedback
  updateScoreOptimistically(playerId, points, operation = 'add') {
    console.log(`Tabmon updating score: ${playerId} ${operation} ${points}`)
    
    // Look for the main score element with data-player attribute
    const scoreElement = document.querySelector(`.main-score[data-player="${playerId}"]`)
    if (!scoreElement) {
      console.error(`Score element not found for player: ${playerId}`)
      console.log(`Available score elements:`, document.querySelectorAll('.main-score'))
      return
    }

    // Also look for the innings score element
    const inningsElement = document.querySelector(`.inning-score[data-player="${playerId}"]`)
    if (!inningsElement) {
      console.error(`Innings element not found for player: ${playerId}`)
      console.log(`Available innings elements:`, document.querySelectorAll('.inning-score'))
      return
    }

    const currentScore = parseInt(scoreElement.textContent) || 0
    const currentInnings = parseInt(inningsElement.textContent) || 0
    let newScore, newInnings
    
    if (operation === 'add') {
      newScore = currentScore + points
      newInnings = currentInnings + points
    } else if (operation === 'subtract') {
      newScore = Math.max(0, currentScore - points)
      newInnings = Math.max(0, currentInnings - points)
    } else if (operation === 'set') {
      newScore = points
      newInnings = points
    }

    console.log(`Tabmon score change: ${currentScore} -> ${newScore} (innings: ${currentInnings} -> ${newInnings})`)

    // Store update in history for potential rollback
    this.clientState.updateHistory.push({
      playerId,
      previousScore: currentScore,
      previousInnings: currentInnings,
      newScore,
      newInnings,
      operation,
      timestamp: Date.now()
    })

    // Immediate visual update for both counters
    scoreElement.textContent = newScore
    scoreElement.classList.add('score-updated')
    
    inningsElement.textContent = newInnings
    inningsElement.classList.add('score-updated')
    
    // Remove highlight after animation
    setTimeout(() => {
      scoreElement.classList.remove('score-updated')
      inningsElement.classList.remove('score-updated')
    }, 250)

    // Store in client state
    this.clientState.scores[playerId] = newScore
    
    // Add pending indicator to both elements
    this.addPendingIndicator(scoreElement)
    this.addPendingIndicator(inningsElement)
    
    console.log(`Tabmon optimistic update: ${playerId} ${operation} ${points} = ${newScore}`)
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
        setTimeout(() => scoreElement.classList.remove('score-updated'), 250)
      }
      
      if (inningsElement && lastUpdate.previousInnings !== undefined) {
        inningsElement.textContent = lastUpdate.previousInnings
        inningsElement.classList.add('score-updated')
        setTimeout(() => inningsElement.classList.remove('score-updated'), 250)
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
      this.updateScoreOptimistically(this.getCurrentActivePlayer(), n, 'add')
    } else {
      console.log("No green border detected - skipping optimistic update")
    }

    // Mark as pending update
    this.clientState.pendingUpdates.add(`add_n_${tableMonitorId}`)

    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#add_n', this.element)
  }

  minus_n () {
    const n = parseInt(this.element.dataset.n) || 1
    const tableMonitorId = this.element.dataset.id
    console.log(`Tabmon minus_n called with n=${n}`)
    
    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if there's a green border
    if (this.hasActivePlayerWithGreenBorder()) {
      this.updateScoreOptimistically(this.getCurrentActivePlayer(), n, 'subtract')
    } else {
      console.log("No green border detected - skipping optimistic update")
    }
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`minus_n_${tableMonitorId}`)
    
    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#minus_n', this.element)
  }

  undo () {
    const tableMonitorId = this.element.dataset.id
    console.log('Tabmon undo called')
    
    // 🚀 IMMEDIATE OPTIMISTIC UNDO
    this.revertLastScoreChange()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`undo_${tableMonitorId}`)
    
    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#undo')
  }

  next_step () {
    const tableMonitorId = this.element.dataset.id
    console.log('Tabmon next_step called')
    
    // 🚀 IMMEDIATE OPTIMISTIC PLAYER CHANGE
    this.changePlayerOptimistically()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)
    
    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#next_step')
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
    console.log(`Tabmon reflexSuccess: ${reflex}`)
    
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
