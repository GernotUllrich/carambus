import ApplicationController from './application_controller'

/* This is the StimulusReflex controller for the TableMonitor Controls.
 * Handles all the control buttons in the scoreboard controls row.
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log("Tabmon controller connected!")
  }

  /* Reflex methods for control buttons */

  add_n () {
    const n = this.element.dataset.n
    console.log(`Tabmon add_n called with n=${n}`)
    // Pass the element so the reflex can read the dataset
    this.stimulate('TableMonitor#add_n', this.element)
  }

  minus_n () {
    const n = this.element.dataset.n
    console.log(`Tabmon minus_n called with n=${n}`)
    // Pass the element so the reflex can read the dataset
    this.stimulate('TableMonitor#minus_n', this.element)
  }

  undo () {
    console.log('Tabmon undo called')
    this.stimulate('TableMonitor#undo')
  }

  next_step () {
    console.log('Tabmon next_step called')
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

  // Lifecycle methods for debugging
  beforeReflex (element, reflex, noop, id) {
    console.log(`Tabmon beforeReflex: ${reflex}`)
  }

  reflexSuccess (element, reflex, noop, id) {
    console.log(`Tabmon reflexSuccess: ${reflex}`)
  }

  reflexError (element, reflex, error, id) {
    console.error(`Tabmon reflexError: ${reflex}`, error)
  }
}
