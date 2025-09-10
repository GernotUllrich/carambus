/* eslint no-console:0 */

import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.debug = true
require("@rails/activestorage").start()
require("local-time").start()

import "./channels"
import "./controllers"
import hotkeys from "./src/hotkeys"
import consumer from "./channels/consumer"
import "@stimulus_reflex/polyfills"
import "./scoreboard_utils"
import "./utilities/scoreboard_debugger"

// Expose hotkeys to global window object
window.hotkeys = hotkeys;

console.log('ActionCable Consumer:', consumer)
console.log('StimulusReflex Version:', StimulusReflex.version)

// Manuelles Polyfill für hasAttribute hinzufügen
if (!Element.prototype.hasAttribute) {
  Element.prototype.hasAttribute = function(name) {
    return this.attributes.getNamedItem(name) !== null
  }
}
