import { Controller } from "stimulus"
import StimulusReflex from 'stimulus_reflex'

export default class extends Controller {
  connect() {
    StimulusReflex.register(this)
  }

  key_a(event) {
    this.stimulate('TableMonitor#key_a', event.currentTarget)
    console.log('keyA was triggered!');  // for testing
  }

  force_next_state(event) {
    this.stimulate('TableMonitor#force_next_state', event.currentTarget)
    console.log('force_next_state was triggered!');  // for testing
  }

  stop(event) {
    this.stimulate('TableMonitor#stop', event.currentTarget)
    console.log('stop was triggered!');  // for testing
  }

  timeout(event) {
    this.stimulate('TableMonitor#timeout', event.currentTarget)
    console.log('timeout was triggered!');  // for testing
  }

  pause(event) {
    this.stimulate('TableMonitor#pause', event.currentTarget)
    console.log('pause was triggered!');  // for testing
  }

  play(event) {
    this.stimulate('TableMonitor#play', event.currentTarget)
    console.log('play was triggered!');  // for testing
  }

  key_b(event) {
    this.stimulate('TableMonitor#key_b', event.currentTarget)
    console.log('key_b was triggered!');  // for testing
  }

  undo(event) {
    this.stimulate('TableMonitor#undo', event.currentTarget)
    console.log('undo was triggered!');  // for testing
  }

  add_n(event) {
    this.stimulate('TableMonitor#add_n', event.currentTarget)
    console.log('add_n was triggered!');  // for testing
  }

  minus_n(event) {
    this.stimulate('TableMonitor#minus_n', event.currentTarget)
    console.log('minus_n was triggered!');  // for testing
  }

  next_step(event) {
    this.stimulate('TableMonitor#next_step', event.currentTarget)
    console.log('next_step was triggered!');  // for testing
  }

  numbers(event) {
    this.stimulate('TableMonitor#numbers', event.currentTarget)
    console.log('numbers was triggered!');  // for testing
  }
}
