// Load all the controllers within this directory and all subdirectories.
// Controller files must be named *_controller.js.

import { Application } from "stimulus"
import Hotkeys from 'stimulus-hotkeys'
import { definitionsFromContext } from "stimulus/webpack-helpers"

const application = Application.start()
const context = require.context("controllers", true, /_controller\.js$/)
application.load(definitionsFromContext(context))

import { Dropdown, Modal, Tabs } from "tailwindcss-stimulus-components"
application.register('dropdown', Dropdown)
application.register('modal', Modal)
application.register('tabs', Tabs)

// Manually register Hotkeys as a Stimulus controller
application.register('hotkeys', Hotkeys)

import Flatpickr from 'stimulus-flatpickr'
import StimulusReflex from 'stimulus_reflex'
import consumer from '../channels/consumer'
import controller from './application_controller'
application.register('flatpickr', Flatpickr)
StimulusReflex.initialize(application, { consumer, controller, debug: true })
