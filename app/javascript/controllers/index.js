import { application } from "./application"

import controllers from "./**/*_controller.js"

controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

import controller from '../controllers/application_controller'

import { Dropdown } from "tailwindcss-stimulus-components"
application.register('dropdown', Dropdown)

import "@stimulus_reflex/polyfills"
import StimulusReflex from 'stimulus_reflex'
import consumer from '../channels/consumer'

import FilterPopupController from "./filter_popup_controller"
application.register("filter-popup", FilterPopupController)

import ClipboardController from "./clipboard_controller"
application.register("clipboard", ClipboardController)

import PagyUrlController from "./pagy_url_controller"
application.register("pagy-url", PagyUrlController)

// Set the consumer on the Stimulus application object first
application.consumer = consumer

console.log("🔌 Setting up StimulusReflex with consumer:", consumer)
console.log("🔌 Application consumer:", application.consumer)
console.log("🔌 StimulusReflex available:", typeof StimulusReflex)

StimulusReflex.initialize(application, { 
  controller, 
  debug: true 
})

console.log("✅ StimulusReflex initialized")
console.log("✅ StimulusReflex consumer:", StimulusReflex.consumer)
