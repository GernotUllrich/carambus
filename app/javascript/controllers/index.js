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

// Note: Most controllers are auto-registered by the eager loader above (lines 3-7)
// Only register manually if there's a specific reason (e.g., non-standard naming)

// Set the consumer on the Stimulus application object first
application.consumer = consumer

// Initialize StimulusReflex
StimulusReflex.initialize(application, { 
  controller, 
  consumer: consumer,
  debug: false  // Set to true only for debugging
})
