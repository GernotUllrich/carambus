import ApplicationController from './application_controller'

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
      updateHistory: []
    }
    console.log("TableMonitor client state initialized:", this.clientState)
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

  // Check if there is actually an active player with green border
  hasActivePlayerWithGreenBorder() {
    const leftPlayer = document.querySelector('#left')
    const rightPlayer = document.querySelector('#right')
    
    return (leftPlayer && leftPlayer.classList.contains('border-green-400')) ||
           (rightPlayer && rightPlayer.classList.contains('border-green-400'))
  }

  // Optimistic score update - immediate visual feedback
  updateScoreOptimistically(playerId, points, operation = 'add') {
    console.log(`TableMonitor updating score: ${playerId} ${operation} ${points}`)
    
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

    // Store previous scores for potential rollback
    this.clientState.updateHistory.push({
      playerId: playerId,
      previousScore: currentScore,
      previousInnings: currentInnings,
      type: 'score_update'
    })

    // Update both displays immediately
    scoreElement.textContent = newScore
    scoreElement.classList.add('score-updated')
    
    inningsElement.textContent = newInnings
    inningsElement.classList.add('score-updated')
    
    // Remove animation classes after animation completes
    setTimeout(() => {
      scoreElement.classList.remove('score-updated')
      inningsElement.classList.remove('score-updated')
    }, 300)

    console.log(`TableMonitor optimistic update: ${playerId} ${operation} ${points} = ${newScore} (innings: ${newInnings})`)
  }

  key_a () {
    console.log('KEY_A called')
    
    // Get the player ID for the left side
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'
    
    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if there's a green border
    if (this.hasActivePlayerWithGreenBorder()) {
      this.updateScoreOptimistically(playerId, 1, 'add')
    } else {
      console.log("No green border detected - skipping optimistic update for key_a")
    }
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`key_a_${this.element.dataset.id}`)
    
    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#key_a')
  }
  
  key_b () {
    console.log('KEY_B called')
    
    // Get the player ID for the right side
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'
    
    // 🚀 IMMEDIATE OPTIMISTIC UPDATE - only if there's a green border
    if (this.hasActivePlayerWithGreenBorder()) {
      this.updateScoreOptimistically(playerId, 1, 'add')
    } else {
      console.log("No green border detected - skipping optimistic update for key_b")
    }
    
    // Mark as pending update
    this.clientState.pendingUpdates.add(`key_b_${this.element.dataset.id}`)
    
    // Background validation via StimulusReflex
    this.stimulate('TableMonitor#key_b')
  }
  key_c () {
    console.log('KEY_C')
    this.stimulate('TableMonitor#key_c')
  }
  key_d () {
    console.log('KEY_D')
    this.stimulate('TableMonitor#key_d')
  }

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
        setTimeout(() => scoreElement.classList.remove('score-updated'), 300)
      }
      
      if (inningsElement && lastUpdate.previousInnings !== undefined) {
        inningsElement.textContent = lastUpdate.previousInnings
        inningsElement.classList.add('score-updated')
        setTimeout(() => inningsElement.classList.remove('score-updated'), 300)
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
}
