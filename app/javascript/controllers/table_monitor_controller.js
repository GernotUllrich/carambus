import ApplicationController from './application_controller'

/* 🚀 SIMPLIFIED StimulusReflex controller for TableMonitor
 * 
 * NEW SIMPLE APPROACH (no delays, no locks, no accumulation):
 * - Click button → send immediately to server via add_score reflex
 * - Server validates and broadcasts JSON update (~50-100ms)
 * - All clients receive JSON and update their DOM
 * 
 * REMOVED COMPLEXITY:
 * - No validation delays
 * - No click accumulation/batching  
 * - No validation locks
 * - No request IDs / idempotency (server handles this)
 * - No optimistic updates (JSON is fast enough!)
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    this.tableMonitorId = this.resolveTableMonitorId()
    
    // Listen for JSON data updates from server
    this.handleDataUpdateBound = this.handleDataUpdate.bind(this)
    this.element.addEventListener('scoreboard:data_update', this.handleDataUpdateBound)
    console.log('🎮 Tabmon controller connected - listening for JSON updates')
  }

  disconnect() {
    // Clean up JSON event listener
    if (this.handleDataUpdateBound) {
      this.element.removeEventListener('scoreboard:data_update', this.handleDataUpdateBound)
    }
    super.disconnect()
    console.log('🎮 Tabmon controller disconnected')
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

    console.warn('⚠️ Could not resolve table monitor ID')
    return null
  }

  findRootElement() {
    return this.element?.closest('[data-tabmon-root]') || 
           document.querySelector('[data-tabmon-root]')
  }

  getCurrentActivePlayer() {
    const root = this.findRootElement()
    if (!root) return 'playera'

    const activePlayerEl = root.querySelector('[data-player-active="true"]')
    return activePlayerEl?.dataset?.player || 'playera'
  }

  getDisciplineIncrement(playerId) {
    const root = this.findRootElement()
    if (!root) return 1

    const playerEl = root.querySelector(`[data-player="${playerId}"]`)
    const discipline = playerEl?.dataset?.discipline || ''
    
    // Eurokegel uses increment of 2, all others use 1
    return discipline.toLowerCase().includes('eurokegel') ? 2 : 1
  }

  // 🎯 SIMPLIFIED: Handle JSON updates from server
  handleDataUpdate(event) {
    const data = event.detail
    if (!data || data.table_monitor_id != this.tableMonitorId) return
    
    console.log('📊 Received JSON update:', data)

    // Update both players' scores
    this.updatePlayerScore('playera', data.playera, data.inning_score_playera)
    this.updatePlayerScore('playerb', data.playerb, data.inning_score_playerb)

    // Update state display if present
    if (data.state_display) {
      const stateEl = document.querySelector('.state-display')
      if (stateEl && stateEl.textContent != data.state_display) {
        stateEl.textContent = data.state_display
        this.flashElement(stateEl)
      }
    }
  }

  updatePlayerScore(playerId, playerData, inningScore) {
    const root = this.findRootElement()
    if (!root) { 
      console.warn('⚠️ Root element not found for score update')
      return 
    }

    // Update main score (result + current inning)
    const mainScoreEl = root.querySelector(`.main-score[data-player="${playerId}"]`)
    if (mainScoreEl) {
      const newTotal = playerData.score + inningScore
      if (mainScoreEl.textContent != newTotal) {
        mainScoreEl.textContent = newTotal
        this.flashElement(mainScoreEl)
      }
    }

    // Update inning score
    const inningScoreEl = root.querySelector(`.inning-score[data-player="${playerId}"]`)
    if (inningScoreEl) {
      if (playerData.active && inningScore > 0) {
        if (inningScoreEl.textContent != inningScore) {
          inningScoreEl.textContent = inningScore
          this.flashElement(inningScoreEl)
        }
      } else {
        inningScoreEl.textContent = ""
      }
    }

    // Update goal/remaining balls
    const goalEl = root.querySelector(`.goal[data-player="${playerId}"]`)
    if (goalEl && playerData.balls_goal > 0) {
      const currentText = goalEl.textContent
      const newGoalValue = playerData.balls_goal - playerData.score
      if (currentText.includes('Rest:')) {
        const newText = currentText.replace(/\d+/, newGoalValue)
        if (goalEl.textContent != newText) {
          goalEl.textContent = newText
        }
      }
    }

    // Update innings count
    const inningsEl = root.querySelector(`.innings[data-player="${playerId}"]`)
    if (inningsEl && inningsEl.textContent != playerData.innings) {
      inningsEl.textContent = playerData.innings
    }

    // Update HS (high score)
    const hsEl = root.querySelector(`.hs[data-player="${playerId}"]`)
    if (hsEl && playerData.hs > 0 && hsEl.textContent != playerData.hs) {
      hsEl.textContent = playerData.hs
    }

    // Update GD (general durchschnitt)
    const gdEl = root.querySelector(`.gd[data-player="${playerId}"]`)
    if (gdEl && playerData.gd > 0) {
      const gdText = playerData.gd.toFixed(2)
      if (gdEl.textContent != gdText) {
        gdEl.textContent = gdText
      }
    }
  }

  flashElement(element) {
    if (!element) return
    element.classList.add('flash-update')
    setTimeout(() => element.classList.remove('flash-update'), 300)
  }

  // ========================================================================
  // SCORE BUTTONS - Click on player's score area
  // ========================================================================
  
  key_a () {
    // Click on left player score
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'
    const activePlayerId = this.getCurrentActivePlayer()

    if (activePlayerId === playerId) {
      // Clicking on active player = add score
      const increment = this.getDisciplineIncrement(playerId)
      this.stimulate('TableMonitor#add_score', playerId, increment)
    } else {
      // Clicking on opposite side = player switch
      this.next_step()
    }
  }

  key_b () {
    // Click on right player score
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'
    const activePlayerId = this.getCurrentActivePlayer()

    if (activePlayerId === playerId) {
      // Clicking on active player = add score
      const increment = this.getDisciplineIncrement(playerId)
      this.stimulate('TableMonitor#add_score', playerId, increment)
    } else {
      // Clicking on opposite side = player switch
      this.next_step()
    }
  }

  // ========================================================================
  // +/- BUTTONS - Add or subtract points
  // ========================================================================
  
  add_n () {
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1
    
    // Send immediately to server (JSON response is fast enough - no optimistic update needed!)
    this.stimulate('TableMonitor#add_score', activePlayerId, n)
  }

  minus_n () {
    const activePlayerId = this.getCurrentActivePlayer()
    const n = parseInt(this.element.dataset.n) || 1
    
    // Send immediately to server (JSON response is fast enough - no optimistic update needed!)
    this.stimulate('TableMonitor#add_score', activePlayerId, -n)
  }

  // ========================================================================
  // PLAYER SWITCH / NEXT STEP
  // ========================================================================
  
  next_step () {
    this.stimulate('TableMonitor#next_step')
  }

  // ========================================================================
  // OTHER CONTROL BUTTONS (unchanged - just pass through to server)
  // ========================================================================
  
  select_game () {
    this.stimulate('TableMonitor#select_game')
  }

  select_sets () {
    this.stimulate('TableMonitor#select_sets')
  }

  start_game () {
    this.stimulate('TableMonitor#start_game')
  }

  switch_players_and_start_game () {
    this.stimulate('TableMonitor#switch_players_and_start_game')
  }

  select_players () {
    this.stimulate('TableMonitor#select_players')
  }

  end_of_game () {
    this.stimulate('TableMonitor#end_of_game')
  }

  end_of_set () {
    this.stimulate('TableMonitor#end_of_set')
  }

  enter () {
    this.stimulate('TableMonitor#enter')
  }

  show_protocol () {
    this.stimulate('TableMonitor#show_protocol')
  }

  show_player_result () {
    this.stimulate('TableMonitor#show_player_result')
  }

  show_game_data () {
    this.stimulate('TableMonitor#show_game_data')
  }

  next () {
    this.stimulate('TableMonitor#next')
  }

  back () {
    this.stimulate('TableMonitor#back')
  }

  undo_last () {
    this.stimulate('TableMonitor#undo_last')
  }

  redo_last () {
    this.stimulate('TableMonitor#redo_last')
  }

  refresh () {
    this.stimulate('TableMonitor#refresh')
  }

  do_logout () {
    this.stimulate('TableMonitor#do_logout')
  }

  increment_a () {
    this.stimulate('TableMonitor#increment_a')
  }

  increment_b () {
    this.stimulate('TableMonitor#increment_b')
  }

  decrement_a () {
    this.stimulate('TableMonitor#decrement_a')
  }

  decrement_b () {
    this.stimulate('TableMonitor#decrement_b')
  }

  timer_mode () {
    this.stimulate('TableMonitor#timer_mode')
  }

  pointer_mode () {
    this.stimulate('TableMonitor#pointer_mode')
  }

  fullscreen_mode () {
    this.stimulate('TableMonitor#fullscreen_mode')
  }

  remote_mode () {
    this.stimulate('TableMonitor#remote_mode')
  }

  keyboard_mode () {
    this.stimulate('TableMonitor#keyboard_mode')
  }

  ballcounter_mode () {
    this.stimulate('TableMonitor#ballcounter_mode')
  }

  table_display_mode () {
    this.stimulate('TableMonitor#table_display_mode')
  }

  toggle_timer_visibility () {
    this.stimulate('TableMonitor#toggle_timer_visibility')
  }

  do_toggle_help_menu () {
    this.stimulate('TableMonitor#do_toggle_help_menu')
  }

  do_start_timer () {
    this.stimulate('TableMonitor#do_start_timer')
  }

  do_stop_timer () {
    this.stimulate('TableMonitor#do_stop_timer')
  }

  do_reset_timer () {
    this.stimulate('TableMonitor#do_reset_timer')
  }

  do_toggle_menu () {
    this.stimulate('TableMonitor#do_toggle_menu')
  }
}
