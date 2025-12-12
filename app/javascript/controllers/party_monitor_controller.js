import ApplicationController from './application_controller'

/* This is the StimulusReflex controller for PartyMonitor.
 * Handles all party monitor interactions:
 * - Player assignment (assign_player_a, assign_player_b)
 * - Player removal (remove_player_a, remove_player_b)
 * - Parameter editing
 * - Round management
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log("PartyMonitor controller connected!")
  }

  /* Reflex specific lifecycle methods */
  
  beforeAssignPlayerA(element, reflex, noop, reflexId) {
    console.log('Before assign_player_a', element, reflex)
  }

  assignPlayerASuccess(element, reflex, noop, reflexId) {
    console.log('assign_player_a succeeded')
  }

  assignPlayerAError(element, reflex, error, reflexId) {
    console.error('assign_player_a failed:', error)
  }
}

