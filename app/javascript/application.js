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

// Expose hotkeys to global window object
window.hotkeys = hotkeys;

console.log('ActionCable Consumer:', consumer)
console.log('StimulusReflex Version:', StimulusReflex.version)
