import consumer from "./consumer"
import CableReady from 'cable_ready'

consumer.subscriptions.create("TournamentChannel", {
  initialized() {
    console.log( "Tournament Channel initialized")
  },

  connected() {
    console.log( "Tournament Channel connected")
  },

  disconnected() {
    console.log( "Tournament Channel disconnected")
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    if (data.cableReady) CableReady.perform(data.operations)
  }
});
