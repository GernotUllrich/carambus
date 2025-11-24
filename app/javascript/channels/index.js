// Load all the channels within this directory and all subdirectories.
// Channel files must be named *_channel.js.

// Explicit imports for esbuild compatibility
// Using side-effect imports to ensure code is included
import './location_channel'
import tableMonitorChannel from './table_monitor_channel'
import './test_channel'
import './tournament_channel'
import './tournament_monitor_channel'

// Reference the export to prevent tree-shaking
if (tableMonitorChannel) {
  // Channel is loaded and active
}
