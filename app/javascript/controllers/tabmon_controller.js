import ApplicationController from './application_controller'

// Configuration: Validation delay in milliseconds
const VALIDATION_DELAY_MS = 1000
const VALIDATION_LOCK_FAILSAFE_MS = 5000

/* This is the StimulusReflex controller for the TableMonitor Controls.
 * Handles all the control buttons in the scoreboard controls row.
 * Now includes optimistic updates for immediate user feedback.
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    this.initializeClientState()
    this.tableMonitorId = this.resolveTableMonitorId()
    this.syncValidationLockState()
  }

  disconnect() {
    // Clean up validation timer when controller disconnects
    if (this.clientState?.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
    }
    super.disconnect()
  }

  initializeClientState() {

    // 🚀 CRITICAL: Use global storage for accumulated changes to persist across controller reconnections
    if (!window.TabmonGlobalState) {
      window.TabmonGlobalState = {
        accumulatedChanges: {
          playera: { totalIncrement: 0, operations: [] },
          playerb: { totalIncrement: 0, operations: [] }
        },
        pendingPlayerSwitch: null,
        validationTimer: null,
        validationLocks: {},
        validationLockTimeouts: {}
      }
    }
    if (!window.TabmonGlobalState.validationLocks) {
      window.TabmonGlobalState.validationLocks = {}
    }
    if (!window.TabmonGlobalState.validationLockTimeouts) {
      window.TabmonGlobalState.validationLockTimeouts = {}
    }

    const existingAccumulatedChanges = window.TabmonGlobalState.accumulatedChanges
    const existingPendingPlayerSwitch = window.TabmonGlobalState.pendingPlayerSwitch
    const existingValidationTimer = window.TabmonGlobalState.validationTimer


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
    };
  }

  resolveTableMonitorId() {
    if (this.element?.dataset?.id) {
      return this.element.dataset.id
    }

    const rootElement = this.findRootElement()
    if (rootElement?.dataset?.tableMonitorId) {
      return rootElement.dataset.tableMonitorId
    }

    const parentWithId = this.element?.closest('[data-id]')
    if (parentWithId?.dataset?.id) {
      return parentWithId.dataset.id
    }

    return null
  }

  findRootElement() {
    if (this.element) {
      const root = this.element.closest('[data-tabmon-root]')
      if (root) {
        return root
      }
    }
    if (this.tableMonitorId) {
      return document.querySelector(`[data-tabmon-root][data-table-monitor-id="${this.tableMonitorId}"]`)
    }
    return null
  }

  syncValidationLockState() {
    const id = this.tableMonitorId
    if (!id) {
      return
    }
    const isLocked = Boolean(window.TabmonGlobalState?.validationLocks?.[id])
    this.applyValidationOverlay(isLocked, id)
  }

  isValidationLocked() {
    const id = this.tableMonitorId || this.resolveTableMonitorId()
    if (!id || !window.TabmonGlobalState) {
      return false
    }
    return Boolean(window.TabmonGlobalState.validationLocks?.[id])
  }

  setValidationLock(isLocked) {
    const id = this.tableMonitorId || this.resolveTableMonitorId()
    if (!id) {
      return
    }

    if (!window.TabmonGlobalState) {
      window.TabmonGlobalState = { validationLocks: {}, validationLockTimeouts: {} }
    } else if (!window.TabmonGlobalState.validationLocks) {
      window.TabmonGlobalState.validationLocks = {}
    }
    if (!window.TabmonGlobalState.validationLockTimeouts) {
      window.TabmonGlobalState.validationLockTimeouts = {}
    }

    if (isLocked) {
      window.TabmonGlobalState.validationLocks[id] = true

      // Clear existing failsafe for this table
      const existingTimeout = window.TabmonGlobalState.validationLockTimeouts[id]
      if (existingTimeout) {
        clearTimeout(existingTimeout)
      }

      // Register new failsafe timeout
      window.TabmonGlobalState.validationLockTimeouts[id] = setTimeout(() => {
        if (window.TabmonGlobalState?.validationLocks?.[id]) {
          console.warn(`Tabmon validation lock auto-release triggered for table ${id}`)
          this.forceReleaseValidationLock(id)
        }
      }, VALIDATION_LOCK_FAILSAFE_MS)
    } else {
      window.TabmonGlobalState.validationLocks[id] = false

      const existingTimeout = window.TabmonGlobalState.validationLockTimeouts[id]
      if (existingTimeout) {
        clearTimeout(existingTimeout)
        delete window.TabmonGlobalState.validationLockTimeouts[id]
      }
    }

    this.applyValidationOverlay(isLocked, id)
  }

  forceReleaseValidationLock(targetId = null) {
    const id = targetId || this.tableMonitorId || this.resolveTableMonitorId()
    if (!id) {
      return
    }

    if (!window.TabmonGlobalState) {
      window.TabmonGlobalState = { validationLocks: {}, validationLockTimeouts: {} }
    }

    if (!window.TabmonGlobalState.validationLocks) {
      window.TabmonGlobalState.validationLocks = {}
    }

    if (!window.TabmonGlobalState.validationLockTimeouts) {
      window.TabmonGlobalState.validationLockTimeouts = {}
    }

    const timeoutHandle = window.TabmonGlobalState.validationLockTimeouts[id]
    if (timeoutHandle) {
      clearTimeout(timeoutHandle)
      delete window.TabmonGlobalState.validationLockTimeouts[id]
    }

    window.TabmonGlobalState.validationLocks[id] = false
    this.applyValidationOverlay(false, id)
  }

  applyValidationOverlay(isLocked, targetId = null) {
    const id = targetId || this.tableMonitorId
    if (!id) {
      return
    }
    const rootElements = document.querySelectorAll(`[data-tabmon-root][data-table-monitor-id="${id}"]`)
    rootElements.forEach(root => {
      if (isLocked) {
        root.classList.add('tabmon-validating')
        root.setAttribute('aria-busy', 'true')
      } else {
        root.classList.remove('tabmon-validating')
        root.removeAttribute('aria-busy')
      }
    })
  }

  blockIfValidationLocked() {
    if (!this.isValidationLocked()) {
      return false
    }
    this.flashValidationOverlay()
    return true
  }

  flashValidationOverlay() {
    const id = this.tableMonitorId || this.resolveTableMonitorId()
    if (!id) {
      return
    }
    const rootElements = document.querySelectorAll(`[data-tabmon-root][data-table-monitor-id="${id}"]`)
    rootElements.forEach(root => {
      root.classList.add('tabmon-validating-pulse')
      setTimeout(() => root.classList.remove('tabmon-validating-pulse'), 200)
    })
  }

  stimulateGuarded(reflex, ...args) {
    if (this.blockIfValidationLocked()) {
      return
    }
    this.stimulate(reflex, ...args)
  }

  // Optimistic score update - immediate visual feedback using accumulated totals
  updateScoreOptimistically(playerId, points, operation = 'add') {
    try {
      // Look for the main score element with data-player attribute
      const scoreElement = document.querySelector(`.main-score[data-player="${playerId}"]`)
    if (!scoreElement) {
      return
    }

    // Also look for the innings score element
    const inningsElement = document.querySelector(`.inning-score[data-player="${playerId}"]`)
    if (!inningsElement) {
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
    }
    if (!inningsElement.dataset.originalInnings) {
      inningsElement.dataset.originalInnings = originalInnings.toString()
    }


    // Additional debugging for accumulated changes

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

    } catch (error) {
      // Don't rethrow to prevent breaking the UI
    }
  }

  // Optimistic player change - immediate visual feedback
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
      this.addPendingIndicator(centerControls)
    }

  }

  // Add visual indicator for pending updates
  addPendingIndicator(element) {
    if (element) {
      element.classList.add('pending-update')
    }
  }

  // Remove pending indicator
  removePendingIndicator(element) {
    if (element) {
      element.classList.remove('pending-update')
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

  getDisciplineIncrement(playerId) {
    // For Eurokegel, each pin is worth 2 points (only even numbers allowed)
    const playerSide = playerId === 'playera' ? '#left' : '#right'
    const sideElement = document.querySelector(playerSide)
    
    if (!sideElement) return 1
    
    // Check discipline from data attribute or text content
    const disciplineText = sideElement.dataset.discipline || 
                          sideElement.querySelector('.discipline, [class*="discipline"]')?.textContent || ''
    
    // Eurokegel uses 2-point increments (each pin = 2 points)
    if (disciplineText.toLowerCase().includes('eurokegel')) {
      return 2
    }
    
    return 1
  }

  // NEW: Get the goal for a specific player
  getPlayerGoal(playerId) {
    const goalElement = document.querySelector(`.goal[data-player="${playerId}"]`)
    if (!goalElement) {
      return null
    }

    const goalText = goalElement.textContent

    // Extract number from "Goal: 50" or "Goal: no limit" or "Ziel: 20"
    const match = goalText.match(/(?:Goal|Ziel):\s*(\d+|no limit)/i)
    if (match) {
      if (match[1] === 'no limit') {
        return null // null means no limit
      } else {
        const goal = parseInt(match[1])
        return goal
      }
    }

    return null
  }

  // NEW: Check if an increment would be valid (not negative score, not exceeding goal)
  isValidIncrement(playerId, points, operation) {

    // Get current score from DOM
    const scoreElement = document.querySelector(`.main-score[data-player="${playerId}"]`)
    const inningsElement = document.querySelector(`.inning-score[data-player="${playerId}"]`)

    if (!scoreElement || !inningsElement) {
      return false
    }

    const currentScore = parseInt(scoreElement.textContent) || 0
    const currentInnings = parseInt(inningsElement.textContent) || 0


    // Get accumulated changes
    const accumulated = this.clientState.accumulatedChanges[playerId] || { totalIncrement: 0, operations: [] }
    const totalAccumulated = accumulated.totalIncrement || 0


    // Calculate what the new values would be after this increment
    // Note: totalAccumulated does NOT include the current operation being validated
    // We need to calculate from the ORIGINAL score, not the current displayed score
    let originalScore = parseInt(scoreElement.dataset.originalScore) || 0
    let originalInnings = parseInt(inningsElement.dataset.originalInnings) || 0

    // If data-original-score doesn't exist yet, use current score minus accumulated changes
    if (originalScore === 0 && totalAccumulated !== 0) {
      originalScore = currentScore - totalAccumulated
      originalInnings = currentInnings - totalAccumulated
    } else if (originalScore === 0 && totalAccumulated === 0) {
      // No accumulated changes, so current score is the original score
      originalScore = currentScore
      originalInnings = currentInnings
    } else {
    }


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


    // Check if score would be negative
    if (newScore < 0) {
      return false
    }

    // Check if score would exceed goal
    const goal = this.getPlayerGoal(playerId)
    if (goal !== null && newScore > goal) {
      return false
    }


    // 🚀 NEW: Check if this increment reaches the goal - if so, trigger immediate validation
    const goalValue = this.getPlayerGoal(playerId)
    if (goalValue !== null && newScore === goalValue) {
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

    }
  }

  /* Reflex methods for control buttons */


  key_a () {

    if (this.blockIfValidationLocked()) {
      return
    }

    // Get the player ID for the left side
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'

    // Get which player currently has the green border (active player)
    const activePlayerId = this.getCurrentActivePlayer()

    // Check if we're clicking on the active player's side or opposite side
    if (activePlayerId === playerId) {
      // Get increment based on discipline (Eurokegel = 2, others = 1)
      const increment = this.getDisciplineIncrement(playerId)
      
      // 🚀 NEW: Accumulate change FIRST, then update display
      const accumulated = this.accumulateAndValidateChange(playerId, increment, 'add')

      // Only update display if accumulation was successful
      if (accumulated) {
        // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
        this.updateScoreOptimistically(playerId, increment, 'add')
      }
    } else {
      // 🚀 TRIGGER NEXT_STEP when clicking on opposite side of active player
      this.next_step()
    }
  }

  key_b () {

    if (this.blockIfValidationLocked()) {
      return
    }

    // Get the player ID for the right side
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'

    // Get which player currently has the green border (active player)
    const activePlayerId = this.getCurrentActivePlayer()


    // Check if we're clicking on the active player's side or opposite side
    if (activePlayerId === playerId) {
      // Get increment based on discipline (Eurokegel = 2, others = 1)
      const increment = this.getDisciplineIncrement(playerId)
      
      // 🚀 NEW: Accumulate change FIRST, then update display
      const accumulated = this.accumulateAndValidateChange(playerId, increment, 'add')

      // Only update display if accumulation was successful
      if (accumulated) {
        // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
        this.updateScoreOptimistically(playerId, increment, 'add')
      }
    } else {
      // 🚀 TRIGGER NEXT_STEP when clicking on opposite side of active player
      this.next_step()
    }
  }
  key_c () {
    this.stimulateGuarded('TableMonitor#key_c')
  }
  key_d () {
    this.stimulateGuarded('TableMonitor#key_d')
  }

  add_n () {
    if (this.blockIfValidationLocked()) {
      return
    }
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1


    // Always increment the active player (the one with green border)

    // 🚀 NEW: Accumulate change FIRST, then update display
    const accumulated = this.accumulateAndValidateChange(activePlayerId, n, 'add')

    // Only update display if accumulation was successful
    if (accumulated) {
      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(activePlayerId, n, 'add')
    }
  }

  minus_n () {
    if (this.blockIfValidationLocked()) {
      return
    }
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1


    // Always decrement the active player (the one with green border)

    // 🚀 NEW: Accumulate change FIRST, then update display
    const accumulated = this.accumulateAndValidateChange(activePlayerId, n, 'subtract')

    // Only update display if accumulation was successful
    if (accumulated) {
      // 🚀 IMMEDIATE OPTIMISTIC UPDATE using accumulated totals
      this.updateScoreOptimistically(activePlayerId, n, 'subtract')
    }
  }

  undo () {
    if (this.blockIfValidationLocked()) {
      return
    }
    const tableMonitorId = this.element.dataset.id

    // 🚀 IMMEDIATE OPTIMISTIC UNDO
    this.revertLastScoreChange()

    // Mark as pending update
    this.clientState.pendingUpdates.add(`undo_${tableMonitorId}`)

    // 🚀 DIRECT SERVER VALIDATION - immediate call
    this.stimulate('TableMonitor#undo')
  }

  next_step () {
    if (this.blockIfValidationLocked()) {
      return
    }
    const tableMonitorId = this.element.dataset.id

    // 🚀 CRITICAL: Validate any pending accumulated changes BEFORE switching players
    let hasPendingChanges = false
    try {
      hasPendingChanges = this.hasPendingAccumulatedChanges()
    } catch (error) {
      hasPendingChanges = false
    }

    if (hasPendingChanges) {

      // 🚀 Set flag to trigger player switch after validation completes
      this.clientState.pendingPlayerSwitch = tableMonitorId

      this.validateAccumulatedChangesImmediately()

      // 🚀 IMPORTANT: Don't proceed with switch until validation completes
      // The switch will be handled in the reflexSuccess callback after validation
      return // Exit early - switch will happen after validation success
    }

    // 🚀 No pending changes - proceed with immediate player switch
    this.performPlayerSwitch(tableMonitorId)
  }

  // 🚀 NEW: Perform the actual player switch (extracted for reuse)
  performPlayerSwitch(tableMonitorId) {

    // 🚀 IMMEDIATE OPTIMISTIC PLAYER CHANGE
    this.changePlayerOptimistically()

    // Mark as pending update
    this.clientState.pendingUpdates.add(`next_step_${tableMonitorId}`)

    // 🚀 DIRECT SERVER VALIDATION - immediate call
    this.stimulate('TableMonitor#next_step')
  }

  numbers () {
    this.stimulateGuarded('TableMonitor#numbers')
  }

  balls_left () {
    if (this.blockIfValidationLocked()) {
      return
    }
    const ballNo = parseInt(this.element.dataset.ballNo)
    if (Number.isNaN(ballNo)) {
      return
    }
    this.stimulate('TableMonitor#balls_left', this.element)
  }

  foul_one () {
    this.stimulateGuarded('TableMonitor#foul_one', this.element)
  }

  foul_two () {
    this.stimulateGuarded('TableMonitor#foul_two', this.element)
  }

  force_next_state () {
    this.stimulateGuarded('TableMonitor#force_next_state')
  }

  stop () {
    this.stimulateGuarded('TableMonitor#stop')
  }

  timeout () {
    this.stimulateGuarded('TableMonitor#timeout')
  }

  pause () {
    this.stimulateGuarded('TableMonitor#pause')
  }

  play () {
    this.stimulateGuarded('TableMonitor#play')
  }

  // Lifecycle methods for debugging and error handling
  beforeReflex (element, reflex, noop, id) {
  }

  reflexSuccess (element, reflex, noop, id) {

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

      // Get current DOM values before resetting
      const scoreElements = document.querySelectorAll('.main-score[data-player]')
      const inningsElements = document.querySelectorAll('.inning-score[data-player]')

      scoreElements.forEach(element => {
      })
      inningsElements.forEach(element => {
      })

      this.resetOriginalScores()
      this.clearAccumulatedChanges()
      this.setValidationLock(false)


      // 🚀 NEW: Check if there's a pending player switch after validation
      if (this.clientState.pendingPlayerSwitch) {
        const tableMonitorId = this.clientState.pendingPlayerSwitch

        // Clear the pending flag
        this.clientState.pendingPlayerSwitch = null

        // Perform the player switch
        this.performPlayerSwitch(tableMonitorId)
      }
    }
  }

  reflexError (element, reflex, error, id) {

    // Rollback optimistic changes on server error
    this.rollbackOptimisticChanges(reflex)

    if (reflex.includes('validate_accumulated_changes')) {
      this.setValidationLock(false)
    }

    // Show error message to user
    this.showErrorMessage(`Server error: ${error}`)
  }

  // Rollback optimistic changes when server validation fails
  rollbackOptimisticChanges(reflex) {

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
      if (this.blockIfValidationLocked()) {
        return false
      }

      // 🚀 NEW: Validate before accumulating
      const validationResult = this.isValidIncrement(playerId, points, operation)
      if (!validationResult || validationResult === false) {
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


    // Cancel previous validation timer
    if (this.clientState.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
    }

    // 🚀 NEW: If goal is reached, validate immediately instead of using timer
    if (reachesGoal) {
      this.validateAccumulatedChanges()
    } else {
      // Set new validation timer - validate with total after VALIDATION_DELAY_MS of inactivity
      this.clientState.validationTimer = setTimeout(() => {
        this.validateAccumulatedChanges()
      }, VALIDATION_DELAY_MS)

    }

      return true // Successfully accumulated
    } catch (error) {
      // Don't rethrow to prevent breaking the UI
      return false
    }
  }

  // NEW: Validate all accumulated changes with total sum
  validateAccumulatedChanges() {
    try {

    const changes = this.clientState.accumulatedChanges
    let hasChanges = false

    // Check if there are any accumulated changes
    for (const playerId in changes) {
      if (changes[playerId].totalIncrement !== 0) {
        hasChanges = true
      }
    }

    if (!hasChanges) {
      return
    }

    this.setValidationLock(true)

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
      }
    }


    // Send single validation call with accumulated changes
    this.stimulate('TableMonitor#validate_accumulated_changes', this.element, validationData)

    // 🚀 CRITICAL: Don't clear accumulated changes here - wait for server response
    // The changes will be cleared in reflexSuccess after server confirms they were processed
    } catch (error) {
      this.setValidationLock(false)
      // Clear accumulated changes to prevent stuck state
      this.clearAccumulatedChanges()
    }
  }

  // NEW: Check if there are any pending accumulated changes
  hasPendingAccumulatedChanges() {

    const changes = this.clientState.accumulatedChanges

    for (const playerId in changes) {
      if (changes[playerId].totalIncrement !== 0) {
        return true
      }
    }
    return false
  }

  // NEW: Validate accumulated changes immediately (bypass timer)
  validateAccumulatedChangesImmediately() {

    // Clear the validation timer since we're validating immediately
    if (this.clientState.validationTimer) {
      clearTimeout(this.clientState.validationTimer)
      this.clientState.validationTimer = null
    }

    // Call the existing validation method
    this.validateAccumulatedChanges()
  }

  // NEW: Clear accumulated changes after successful validation
  clearAccumulatedChanges() {

    // Clear both local and global accumulated changes
    const clearedChanges = {
      playera: { totalIncrement: 0, operations: [] },
      playerb: { totalIncrement: 0, operations: [] }
    }

    this.clientState.accumulatedChanges = clearedChanges

    // Also clear global state
    if (window.TabmonGlobalState) {
      window.TabmonGlobalState.accumulatedChanges = clearedChanges
    }


    // Reset original scores to current values for future calculations
    this.resetOriginalScores()
  }

  // NEW: Reset original scores to current DOM values after successful server validation
  resetOriginalScores() {

    const scoreElements = document.querySelectorAll('.main-score[data-player]')
    const inningsElements = document.querySelectorAll('.inning-score[data-player]')

    scoreElements.forEach(element => {
      const currentScore = parseInt(element.textContent) || 0
      const previousOriginal = element.dataset.originalScore
      element.dataset.originalScore = currentScore.toString()
    })

    inningsElements.forEach(element => {
      const currentInnings = parseInt(element.textContent) || 0
      const previousOriginal = element.dataset.originalInnings
      element.dataset.originalInnings = currentInnings.toString()
    })
  }


  // Show error message to user
  showErrorMessage(message) {
    // Simple error display - could be enhanced with toast notifications

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
