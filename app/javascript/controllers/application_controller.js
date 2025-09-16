import { Controller } from '@hotwired/stimulus'
import StimulusReflex from 'stimulus_reflex'

/* This is your ApplicationController.
 * All StimulusReflex controllers should inherit from this class.
 *
 * Example:
 *
 *   import ApplicationController from './application_controller'
 *
 *   export default class extends ApplicationController { ... }
 *
 * Learn more at: https://docs.stimulusreflex.com
 */
export default class extends Controller {
  connect () {
    console.log("🚀 ApplicationController connected and registering StimulusReflex")
    StimulusReflex.register(this)
  }

  /* Application-wide lifecycle methods
   *
   * Use these methods to handle lifecycle concerns for the entire application.
   * Using the lifecycle is optional, so feel free to delete these stubs if you don't need them.
   *
   * Arguments:
   *
   *   element - the element that triggered the reflex
   *             may be different than the Stimulus controller's this.element
   *
   *   reflex - the name of the reflex e.g. "Example#demo"
   *
   *   error/noop - the error message (for reflexError), otherwise null
   *
   *   id - a UUID4 or developer-provided unique identifier for each Reflex
   */

  beforeReflex (element, reflex, noop, id) {
    console.log("🚀 ApplicationController beforeReflex:", reflex)
    console.log("🚀 Element:", element)
    console.log("🚀 Element dataset:", element?.dataset)
    console.log("🚀 Element data-id:", element?.dataset?.id)
    // document.body.classList.add('wait')
  }

  reflexQueued (element, reflex, noop, id) {
    // Reflex will be delivered to server upon reconnection
  }

  reflexDelivered (element, reflex, noop, id) {
    // Reflex has been delivered to the server
  }

  reflexSuccess (element, reflex, noop, id) {
    console.log("✅ ApplicationController reflexSuccess:", reflex)
    // show success message
    if (reflex.includes('TableMonitor#key_a')) {
      console.timeEnd('key_a_click')
    } else if (reflex.includes('TableMonitor#key_b')) {
      console.timeEnd('key_b_click')
    }
  }

  reflexError (element, reflex, error, id) {
    // show error message
  }

  reflexForbidden (element, reflex, noop, id) {
    // Reflex action did not have permission to run
    // window.location = '/'
  }

  reflexHalted (element, reflex, noop, id) {
    // handle aborted Reflex action
  }

  afterReflex (element, reflex, noop, id) {
    // document.body.classList.remove('wait')
  }

  finalizeReflex (element, reflex, noop, id) {
    // all operations have completed, animation etc is now safe
  }
}
