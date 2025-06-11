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

StimulusReflex.initialize(application, { 
  consumer, 
  controller, 
  debug: true 
})
