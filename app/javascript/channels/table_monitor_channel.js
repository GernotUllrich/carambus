import consumer from "./consumer"
import CableReady from 'cable_ready'

consumer.subscriptions.create("TableMonitorChannel", {

  // Called once when the subscription is created.
  initialized() {
    console.log("🔌 TableMonitor Channel initialized")
    this.connectionAttempts = 0
    this.lastReceived = Date.now()
  },

  connected() {
    // Called when the subscription is ready for use on the server
    console.log("🔌 TableMonitor Channel connected")
    console.log("🔌 Consumer state:", consumer.connection.getState())
    this.connectionAttempts = 0
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    this.connectionAttempts++
    console.warn("🔌 TableMonitor Channel disconnected (attempt #" + this.connectionAttempts + ")")
    console.warn("🔌 Time since last message:", (Date.now() - this.lastReceived) / 1000, "seconds")
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    this.lastReceived = Date.now()
    
    // Log incoming data with details
    console.log("📥 TableMonitor Channel received:", {
      timestamp: new Date().toISOString(),
      hasCableReady: !!data.cableReady,
      operationCount: data.operations?.length,
      type: data.type || 'broadcast'
    })
    
    if (data.cableReady) {
      // Log each operation before performing
      data.operations.forEach((op, index) => {
        console.log(`📥 CableReady operation #${index + 1}:`, {
          type: op.operation,
          selector: op.selector,
          htmlSize: op.html ? (op.html.length + " chars") : "N/A",
          selectorExists: !!document.querySelector(op.selector)
        })
      })
      
      CableReady.perform(data.operations)
      console.log("✅ CableReady operations performed")
    }
  }
});
