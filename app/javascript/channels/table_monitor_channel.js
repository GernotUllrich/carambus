import consumer from "./consumer"
import CableReady from 'cable_ready'

consumer.subscriptions.create("TableMonitorChannel", {

  // Called once when the subscription is created.
  initialized() {
    console.log( "TableMonitor Channel initialized")
  },

  connected() {
    // Called when the subscription is ready for use on the server
    console.log( "TableMonitor Channel connected")
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log( "TableMonitor Channel disconnected")
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    if (data.cableReady) CableReady.perform(data.operations)
  }
});
