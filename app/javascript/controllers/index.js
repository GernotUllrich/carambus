import { application } from "./application"

// Import StimulusReflex BEFORE controllers to ensure reflexes work immediately
import "@stimulus_reflex/polyfills"
import StimulusReflex from 'stimulus_reflex'
import consumer from '../channels/consumer'
import controller from '../controllers/application_controller'

// Set the consumer on the Stimulus application object first
application.consumer = consumer

// Initialize StimulusReflex BEFORE registering controllers
StimulusReflex.initialize(application, { 
  controller, 
  consumer: consumer,
  debug: false  // Set to true only for debugging
})

// Now import and register controllers AFTER StimulusReflex is ready
import controllers from "./**/*_controller.js"

controllers.forEach((controller) => {
  application.register(controller.name, controller.module.default)
})

import { Dropdown } from "tailwindcss-stimulus-components"
application.register('dropdown', Dropdown)
