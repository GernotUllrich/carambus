// example_controller.js
import ApplicationController from './application_controller'
export default class extends ApplicationController {

  pageup (event) {
    event.preventDefault()
    this.stimulate("TableMonitor#key_a")
    console.log(this.event)
    event.stopPropagation()
  }
  pagedown () {
    this.stimulate("TableMonitor#key_b")
  }
  b () {
    this.stimulate("TableMonitor#key_c")
  }
  esc () {
    this.stimulate("TableMonitor#key_d")
  }
}
