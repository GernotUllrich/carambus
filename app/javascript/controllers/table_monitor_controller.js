import ApplicationController from './application_controller'
import { Controller } from "@hotwired/stimulus"

/* This is the custom StimulusReflex controller for the Example Reflex.
 * Learn more at: https://docs.stimulusreflex.com
 */
export default class extends ApplicationController {
  static targets = ["modal", "modalBg"]

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
    // add your code here, if applicable
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
  key_a () {
    console.log('KEY_A')
    this.stimulate('TableMonitor#key_a')
  }
  key_b () {
    console.log('KEY_B')
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

  warningMode(event) {
    event.preventDefault()
    this.showWarningModal()
  }

  unsetWarningModal(event) {
    event.preventDefault()
    this.hideWarningModal()
  }

  showWarningModal() {
    const modal = document.getElementById("modal-confirm-back")
    const modalBg = document.getElementById("modal-confirm-back-bg")
    if (modal && modalBg) {
      modal.classList.remove("hidden")
      modalBg.classList.remove("hidden")
    }
  }

  hideWarningModal() {
    const modal = document.getElementById("modal-confirm-back")
    const modalBg = document.getElementById("modal-confirm-back-bg")
    if (modal && modalBg) {
      modal.classList.add("hidden")
      modalBg.classList.add("hidden")
    }
  }
}
