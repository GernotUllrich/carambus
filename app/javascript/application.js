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
window.hotkeys = hotkeys;
