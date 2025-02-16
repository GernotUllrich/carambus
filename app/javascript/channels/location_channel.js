import consumer from "./consumer"
import CableReady from 'cable_ready'

consumer.subscriptions.create("LocationChannel", {
  initialized() {
    console.log( "Location Channel initialized")
  },

  connected() {
    console.log( "Location Channel connected")
  },

  disconnected() {
    console.log( "Location Channel disconnected")
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    if (data.cableReady) CableReady.perform(data.operations)
  }
});
