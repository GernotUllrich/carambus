import { Controller } from "stimulus"

export default class extends Controller {
  connect() {
    console.log("Scoreboard controller connected!")
    this.initializeClientState()
    this.isDemo = this.element.classList.contains('demo-scoreboard')
    console.log("Demo mode:", this.isDemo)
  }

  initializeClientState() {
    // Initialize client-side state for immediate feedback
    this.clientState = {
      scores: {},
      currentPlayer: 'playera',
      pendingUpdates: new Set(),
      updateHistory: []
    }
    console.log("Client state initialized:", this.clientState)
  }

  // Optimistic score update - immediate visual feedback
  updateScoreOptimistically(playerId, points, operation = 'add') {
    console.log(`Updating score: ${playerId} ${operation} ${points}`)
    const scoreElement = document.querySelector(`[data-player="${playerId}"] .score-display`)
    if (!scoreElement) {
      console.error(`Score element not found for player: ${playerId}`)
      return
    }

    const currentScore = parseInt(scoreElement.textContent) || 0
    let newScore
    
    if (operation === 'add') {
      newScore = currentScore + points
    } else if (operation === 'subtract') {
      newScore = Math.max(0, currentScore - points)
    } else if (operation === 'set') {
      newScore = points
    }

    console.log(`Score change: ${currentScore} -> ${newScore}`)

    // Store update in history for potential rollback
    this.clientState.updateHistory.push({
      playerId,
      previousScore: currentScore,
      newScore,
      operation,
      timestamp: Date.now()
    })

    // Immediate visual update
    scoreElement.textContent = newScore
    scoreElement.classList.add('score-updated')
    
    // Remove highlight after animation
    setTimeout(() => {
      scoreElement.classList.remove('score-updated')
    }, 500)

    // Store in client state
    this.clientState.scores[playerId] = newScore
    
    // Add pending indicator
    this.addPendingIndicator(scoreElement)
    
    // Demo mode: simulate server response after delay
    if (this.isDemo) {
      setTimeout(() => {
        this.removePendingIndicator(scoreElement)
        this.clientState.pendingUpdates.delete(`demo_${playerId}`)
      }, 1000 + Math.random() * 2000) // Random delay 1-3 seconds
    }
    
    console.log(`Optimistic update: ${playerId} ${operation} ${points} = ${newScore}`)
  }

  // Optimistic player change - immediate visual feedback
  changePlayerOptimistically() {
    console.log("Changing player optimistically")
    
    // Store current state for potential rollback
    this.clientState.updateHistory.push({
      type: 'player_change',
      previousPlayer: this.clientState.currentPlayer,
      timestamp: Date.now()
    })
    
    // Update current player in client state
    this.clientState.currentPlayer = this.clientState.currentPlayer === 'playera' ? 'playerb' : 'playera'
    
    // Update demo display if available
    const currentPlayerSpan = document.getElementById('current-player')
    if (currentPlayerSpan) {
      currentPlayerSpan.textContent = this.clientState.currentPlayer === 'playera' ? 'Player A' : 'Player B'
    }
    
    // Add pending indicator to center controls
    const centerControls = document.querySelector('.bg-gray-700')
    if (centerControls) {
      this.addPendingIndicator(centerControls)
    }
    
    // Demo mode: simulate server response after delay
    if (this.isDemo) {
      setTimeout(() => {
        this.removeAllPendingIndicators()
        this.clientState.pendingUpdates.delete('demo_player_change')
      }, 1000 + Math.random() * 2000) // Random delay 1-3 seconds
    }
    
    console.log(`Optimistic player change: ${this.clientState.currentPlayer}`)
  }

  // Add visual indicator for pending updates
  addPendingIndicator(element) {
    if (element) {
      element.classList.add('pending-update')
      console.log("Added pending indicator to:", element)
    }
  }

  // Remove pending indicator
  removePendingIndicator(element) {
    if (element) {
      element.classList.remove('pending-update')
      console.log("Removed pending indicator from:", element)
    }
  }

  key_a(event) {
    console.log("key_a triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    
    // Optimistic update
    this.updateScoreOptimistically('playera', 1, 'add')
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`key_a_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log('Demo: key_a triggered with optimistic update!')
    } else {
      console.log('Real scoreboard: key_a triggered!')
    }
  }

  key_b(event) {
    console.log("key_b triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    
    // Optimistic update
    this.updateScoreOptimistically('playerb', 1, 'add')
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`key_b_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log('Demo: key_b triggered with optimistic update!')
    } else {
      console.log('Real scoreboard: key_b triggered!')
    }
  }

  undo(event) {
    console.log("undo triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    
    // Optimistic undo (revert last score change)
    this.revertLastScoreChange()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`undo_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log('Demo: undo triggered with optimistic update!')
    } else {
      console.log('Real scoreboard: undo triggered!')
    }
  }

  add_n(event) {
    console.log("add_n triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    const points = parseInt(event.currentTarget.dataset.n) || 1
    
    // Optimistic update
    this.updateScoreOptimistically(this.getCurrentActivePlayer(), points, 'add')
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`add_n_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log(`Demo: add_n(${points}) triggered with optimistic update!`)
    } else {
      console.log(`Real scoreboard: add_n(${points}) triggered!`)
    }
  }

  minus_n(event) {
    console.log("minus_n triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    const points = parseInt(event.currentTarget.dataset.n) || 1
    
    // Optimistic update
    this.updateScoreOptimistically(this.getCurrentActivePlayer(), points, 'subtract')
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`minus_n_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log(`Demo: minus_n(${points}) triggered with optimistic update!`)
    } else {
      console.log(`Real scoreboard: minus_n(${points}) triggered!`)
    }
  }

  next_step(event) {
    console.log("next_step triggered!")
    event.preventDefault()
    const tableMonitorId = event.currentTarget.dataset.id
    
    // Optimistic player change
    this.changePlayerOptimistically()
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)
    
    if (this.isDemo) {
      console.log('Demo: next_step triggered with optimistic update!')
    } else {
      console.log('Real scoreboard: next_step triggered!')
    }
  }

  numbers(event) {
    console.log("numbers triggered!")
    event.preventDefault()
    if (this.isDemo) {
      console.log('Demo: numbers triggered!')
    } else {
      console.log('Real scoreboard: numbers triggered!')
    }
  }

  // Helper methods
  getCurrentActivePlayer() {
    return this.clientState.currentPlayer || 'playera'
  }

  revertLastScoreChange() {
    const lastUpdate = this.clientState.updateHistory.pop()
    if (lastUpdate && lastUpdate.type !== 'player_change') {
      this.updateScoreOptimistically(lastUpdate.playerId, lastUpdate.previousScore, 'set')
      console.log(`Reverted ${lastUpdate.playerId} to ${lastUpdate.previousScore}`)
    }
  }

  removeAllPendingIndicators() {
    document.querySelectorAll('.pending-update').forEach(el => {
      this.removePendingIndicator(el)
    })
  }
}
