import { application } from "./application"

// Debug the import system
console.log('Importing controllers...')

// Explicitly import all controllers
import TestController from './test_controller'
import KarambolGameController from './karambol_game_controller'
import KarambolSettingsController from './karambol_settings_controller'
import GameSettingsController from './game_settings_controller'
import TableMonitorShowController from './table_monitor_show_controller'
import ScoreboardStartController from './scoreboard_start_controller'
import ScoreboardWelcomeController from './scoreboard_welcome_controller'
import TableMonitorController from './table_monitor_controller'
import TournamentHotkeysController from './tournament_hotkeys_controller'
import SearchParserController from './search_parser_controller'
import TippyController from './tippy_controller'
import FilterPopupController from './filter_popup_controller'
import DropdownController from './dropdown_controller'
import MarkdownEditorController from './markdown_editor_controller'
import SidebarController from './sidebar_controller'
import ApplicationController from './application_controller'
import DarkModeController from './dark_mode_controller'
import HelloController from './hello_controller'
import PartyController from './party_controller'
import TabmonController from './tabmon_controller'
import TransitionController from './transition_controller'

// Register all controllers with explicit debugging
const registerController = (name, controller) => {
  console.log(`Registering controller "${name}":`, controller)
  try {
    application.register(name, controller)
    console.log(`Successfully registered controller "${name}"`)
  } catch (error) {
    console.error(`Failed to register controller "${name}":`, error)
  }
}

// Register test controller first for debugging
console.log('Registering test controller...')
registerController('test', TestController)

// Register other controllers
const controllers = {
  'karambol-game': KarambolGameController,
  'karambol-settings': KarambolSettingsController,
  'game-settings': GameSettingsController,
  'table-monitor-show': TableMonitorShowController,
  'scoreboard-start': ScoreboardStartController,
  'scoreboard-welcome': ScoreboardWelcomeController,
  'table-monitor': TableMonitorController,
  'tournament-hotkeys': TournamentHotkeysController,
  'search-parser': SearchParserController,
  'tippy': TippyController,
  'filter-popup': FilterPopupController,
  'dropdown': DropdownController,
  'markdown-editor': MarkdownEditorController,
  'sidebar': SidebarController,
  'application': ApplicationController,
  'dark-mode': DarkModeController,
  'hello': HelloController,
  'party': PartyController,
  'tabmon': TabmonController,
  'transition': TransitionController
}

// Register remaining controllers
Object.entries(controllers).forEach(([name, controller]) => {
  registerController(name, controller)
})

import { Dropdown } from "tailwindcss-stimulus-components"
application.register('dropdown', Dropdown)

import "@stimulus_reflex/polyfills"
import StimulusReflex from 'stimulus_reflex'
import consumer from '../channels/consumer'

// Set the consumer on the application object as recommended
application.consumer = consumer

// Initialize StimulusReflex with only the essential options
// Note: isolation mode will be the default in the next version
StimulusReflex.initialize(application, { 
  controller: ApplicationController, 
  debug: true 
})

// If you need to broadcast updates to other tabs, use CableReady operations
// Example:
// CableReady.perform({
//   operations: [
//     { broadcast: { channel: "YourChannel", data: { message: "Update" } } }
//   ]
// })
