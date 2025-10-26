import ApplicationController from './application_controller'

/* Simplified StimulusReflex controller for TableMonitor - Optimized for Raspberry Pi 3
 * Removes all optimistic updates and accumulated changes for maximum performance
 * Each click goes directly to server
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
  }

  disconnect() {
    super.disconnect()
  }

  /* Direct reflex methods - no client-side logic */

  key_a () {
    const leftPlayer = document.querySelector('#left')
    const playerId = leftPlayer ? leftPlayer.dataset.player || 'playera' : 'playera'
    const activePlayerId = this.getCurrentActivePlayer()

    if (activePlayerId === playerId) {
      this.stimulate('TableMonitor#key_a')
    } else {
      this.stimulate('TableMonitor#next_step')
    }
  }

  key_b () {
    const rightPlayer = document.querySelector('#right')
    const playerId = rightPlayer ? rightPlayer.dataset.player || 'playerb' : 'playerb'
    const activePlayerId = this.getCurrentActivePlayer()

    if (activePlayerId === playerId) {
      this.stimulate('TableMonitor#key_b')
    } else {
      this.stimulate('TableMonitor#next_step')
    }
  }

  key_c () {
    this.stimulate('TableMonitor#key_c')
  }

  key_d () {
    this.stimulate('TableMonitor#key_d')
  }

  add_n () {
    this.stimulate('TableMonitor#add_n')
  }

  minus_n () {
    this.stimulate('TableMonitor#minus_n')
  }

  undo () {
    this.stimulate('TableMonitor#undo')
  }

  next_step () {
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
    this.stimulate('TableMonitor#pause')
  }

  play () {
    this.stimulate('TableMonitor#play')
  }

  // Get current active player by looking at the DOM
  getCurrentActivePlayer() {
    const leftPlayer = document.querySelector('#left')
    const rightPlayer = document.querySelector('#right')

    if (leftPlayer && leftPlayer.classList.contains('border-green-400')) {
      return leftPlayer.dataset.player || 'playera'
    } else if (rightPlayer && rightPlayer.classList.contains('border-green-400')) {
      return rightPlayer.dataset.player || 'playerb'
    }

    return 'playera'
  }
}

