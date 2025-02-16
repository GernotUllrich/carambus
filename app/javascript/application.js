/* eslint no-console:0 */

import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.session.debug = true
require("@rails/activestorage").start()
require("local-time").start()
import Rails from "@rails/ujs"
Rails.start()

import "./channels"
import "./controllers"
import hotkeys from "./src/hotkeys"

// Expose hotkeys to global window object
console.log('Hotkeys library loaded:', hotkeys);
window.hotkeys = hotkeys;
console.log('Window.hotkeys initialized:', window.hotkeys);

// After initializing hotkeys
setTimeout(() => {
  console.log('Delayed hotkeys check:', window.hotkeys);
}, 1000);
