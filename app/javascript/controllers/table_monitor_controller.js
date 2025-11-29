import ApplicationController from './application_controller'

/* This is the StimulusReflex controller for TableMonitor.
 * Handles all scoreboard interactions:
 * - Player area clicks (key_a, key_b, key_c, key_d)
 * - Control buttons (add_n, minus_n, undo, next_step, etc.)
 * - Timer controls (play, pause, stop, timeout)
 * - Navigation (home, back)
 */
export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log("TableMonitor controller connected!")
  }

  /* Player area actions (clicking on left/right player areas) */
  
  key_a () {
    console.log('KEY_A called')
    this.stimulate('TableMonitor#key_a')
  }
  
  key_b () {
    console.log('KEY_B called')
    this.stimulate('TableMonitor#key_b')
  }
  
  key_c () {
    console.log('KEY_C called')
    this.stimulate('TableMonitor#key_c')
  }
  
  key_d () {
    console.log('KEY_D called')
    this.stimulate('TableMonitor#key_d')
  }

  /* Score control buttons */

  add_n () {
    const n = this.element.dataset.n
    console.log(`TableMonitor add_n called with n=${n}`)
    // Pass the element so the reflex can read the dataset
    this.stimulate('TableMonitor#add_n', this.element)
  }

  minus_n () {
    const n = this.element.dataset.n
    console.log(`TableMonitor minus_n called with n=${n}`)
    // Pass the element so the reflex can read the dataset
    this.stimulate('TableMonitor#minus_n', this.element)
  }

  undo () {
    console.log('TableMonitor undo called')
    this.stimulate('TableMonitor#undo')
  }

  redo () {
    console.log('TableMonitor redo called')
    this.stimulate('TableMonitor#redo')
  }

  next_step () {
    console.log('TableMonitor next_step called')
    this.stimulate('TableMonitor#next_step')
  }

  numbers () {
    console.log('TableMonitor numbers called')
    this.stimulate('TableMonitor#numbers')
  }

  force_next_state () {
    console.log('TableMonitor force_next_state called')
    this.stimulate('TableMonitor#force_next_state')
  }

  /* Timer controls */

  stop () {
    console.log('TableMonitor stop called')
    this.stimulate('TableMonitor#stop')
  }

  timeout () {
    console.log('TableMonitor timeout called')
    this.stimulate('TableMonitor#timeout')
  }

  pause () {
    console.log('TableMonitor pause called')
    this.stimulate('TableMonitor#pause')
  }

  play () {
    console.log('TableMonitor play called')
    this.stimulate('TableMonitor#play')
  }

  /* Navigation */

  home () {
    this.stimulate('TableMonitor#home')
  }

  back () {
    window.history.back()
  }

  // Lifecycle methods for debugging
  beforeReflex (element, reflex, noop, id) {
    console.log(`TableMonitor beforeReflex: ${reflex}`)
  }

  reflexSuccess (element, reflex, noop, id) {
    console.log(`TableMonitor reflexSuccess: ${reflex}`)
  }

  reflexError (element, reflex, error, id) {
    console.error(`TableMonitor reflexError: ${reflex}`, error)
  }
}
