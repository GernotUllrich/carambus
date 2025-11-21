import consumer from "./consumer"
import CableReady from 'cable_ready'

// Performance logging - can be enabled via localStorage
const PERF_LOGGING = localStorage.getItem('debug_cable_performance') === 'true'

// Connection Health Monitor
class ConnectionHealthMonitor {
  constructor(subscription) {
    this.subscription = subscription
    this.healthCheckInterval = null
    this.reconnectTimeout = null
    this.healthCheckFrequency = 30000 // 30 seconds
    this.maxSilenceTime = 120000 // 2 minutes without any message
    this.reconnectDelay = 5000 // 5 seconds
    this.forceReloadDelay = 10000 // 10 seconds if reconnect fails
  }

  start() {
    console.log("🏥 Health monitor started")
    this.healthCheckInterval = setInterval(() => {
      this.checkHealth()
    }, this.healthCheckFrequency)

    // Also check on page visibility change
    document.addEventListener('visibilitychange', () => {
      if (!document.hidden) {
        console.log("📱 Page became visible, checking health...")
        this.checkHealth()
      }
    })
  }

  stop() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval)
      this.healthCheckInterval = null
    }
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout)
      this.reconnectTimeout = null
    }
    console.log("🏥 Health monitor stopped")
  }

  checkHealth() {
    try {
      const state = consumer.connection.getState()
      const timeSinceLastMessage = Date.now() - this.subscription.lastReceived
      
      if (PERF_LOGGING) {
        console.log("🏥 Health check:", {
          connectionState: state,
          timeSinceLastMessage: Math.round(timeSinceLastMessage / 1000) + "s",
          lastReceived: new Date(this.subscription.lastReceived).toISOString()
        })
      }

      // Check 1: Connection not open
      if (state !== "open") {
        console.warn("⚠️ Connection not open, state:", state)
        this.triggerReconnect("connection_not_open")
        return
      }

      // Check 2: No messages for too long
      if (timeSinceLastMessage > this.maxSilenceTime) {
        console.warn("⚠️ No messages received for", Math.round(timeSinceLastMessage / 1000), "seconds")
        this.triggerReconnect("message_timeout")
        return
      }

      // Connection looks healthy
      if (PERF_LOGGING) {
        console.log("✅ Connection healthy")
      }
      this.updateStatusIndicator('healthy')
    } catch (error) {
      console.error("❌ Health check failed:", error)
      this.triggerReconnect("health_check_error")
    }
  }

  triggerReconnect(reason) {
    console.warn("🔄 Triggering reconnection, reason:", reason)
    this.updateStatusIndicator('reconnecting')
    
    // Try to reopen connection
    consumer.connection.reopen()

    // If reconnection doesn't work, reload page
    this.reconnectTimeout = setTimeout(() => {
      const state = consumer.connection.getState()
      if (state !== "open") {
        console.error("🔄 Reconnection failed, reloading page...")
        this.updateStatusIndicator('reloading')
        window.location.reload()
      } else {
        console.log("✅ Reconnection successful")
        this.updateStatusIndicator('healthy')
      }
    }, this.reconnectDelay)
  }

  updateStatusIndicator(status) {
    // Update visual indicator if it exists
    const indicator = document.getElementById('connection-status-indicator')
    if (indicator) {
      indicator.className = `connection-status connection-status-${status}`
      indicator.title = `Connection: ${status}`
    }

    // Dispatch custom event for other parts of the app
    window.dispatchEvent(new CustomEvent('connection-status-change', {
      detail: { status }
    }))
  }
}

// Create subscription
const tableMonitorSubscription = consumer.subscriptions.create("TableMonitorChannel", {

  // Called once when the subscription is created.
  initialized() {
    if (PERF_LOGGING) {
      console.log("🔌 TableMonitor Channel initialized")
    }
    this.connectionAttempts = 0
    this.lastReceived = Date.now()
    this.healthMonitor = new ConnectionHealthMonitor(this)
  },

  connected() {
    // Called when the subscription is ready for use on the server
    console.log("🔌 TableMonitor Channel connected")
    if (PERF_LOGGING) {
      console.log("🔌 Consumer state:", consumer.connection.getState())
    }
    this.connectionAttempts = 0
    
    // Start health monitoring
    this.healthMonitor.start()
    this.healthMonitor.updateStatusIndicator('healthy')
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    this.connectionAttempts++
    console.warn("🔌 TableMonitor Channel disconnected (attempt #" + this.connectionAttempts + ")")
    console.warn("🔌 Time since last message:", (Date.now() - this.lastReceived) / 1000, "seconds")
    
    // Stop health monitoring
    this.healthMonitor.stop()
    this.healthMonitor.updateStatusIndicator('disconnected')
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    const receiveTime = Date.now()
    this.lastReceived = receiveTime
    
    // Handle force reconnect
    if (data.type === "force_reconnect") {
      console.warn("🔄 Server requested forced reconnect:", data.reason)
      this.healthMonitor.updateStatusIndicator('reconnecting')
      setTimeout(() => {
        window.location.reload()
      }, 2000)
      return
    }

    // Handle heartbeat acknowledgment
    if (data.type === "heartbeat_ack") {
      if (PERF_LOGGING) {
        console.log("💓 Heartbeat acknowledged by server")
      }
      return
    }
    
    // Performance measurement
    let broadcastTimestamp = null
    let networkLatency = null
    
    if (data.cableReady && data.operations?.length > 0) {
      // Extract broadcast_timestamp from first operation
      const firstOp = data.operations[0]
      if (firstOp.broadcast_timestamp) {
        broadcastTimestamp = firstOp.broadcast_timestamp
        networkLatency = receiveTime - broadcastTimestamp
      }
      
      // Log incoming data with performance details
      if (PERF_LOGGING) {
        console.log("📥 TableMonitor Channel received:", {
          timestamp: new Date().toISOString(),
          hasCableReady: true,
          operationCount: data.operations.length,
          type: data.type || 'broadcast',
          broadcastTimestamp: broadcastTimestamp,
          networkLatency: networkLatency ? `${networkLatency.toFixed(0)}ms` : 'N/A'
        })
        
        // Log each operation before performing
        data.operations.forEach((op, index) => {
          console.log(`📥 CableReady operation #${index + 1}:`, {
            type: op.operation,
            selector: op.selector,
            htmlSize: op.html ? (op.html.length + " chars") : "N/A",
            selectorExists: !!document.querySelector(op.selector)
          })
        })
      }
      
      // Measure CableReady performance
      const performStart = Date.now()
      CableReady.perform(data.operations)
      const performTime = Date.now() - performStart
      const totalLatency = Date.now() - (broadcastTimestamp || receiveTime)
      
      // Always log performance summary for significant operations
      if (broadcastTimestamp) {
        console.log(`⚡ Performance [${firstOp.selector}]:`, {
          network: `${networkLatency.toFixed(0)}ms`,
          dom: `${performTime}ms`,
          total: `${totalLatency}ms`
        })
      } else if (PERF_LOGGING) {
        console.log("✅ CableReady operations performed in", performTime + "ms")
      }
    } else if (PERF_LOGGING) {
      console.log("📥 TableMonitor Channel received:", {
        timestamp: new Date().toISOString(),
        hasCableReady: !!data.cableReady,
        operationCount: data.operations?.length,
        type: data.type || 'broadcast'
      })
    }
  },

  // Send heartbeat to server
  sendHeartbeat() {
    this.perform('heartbeat', { timestamp: Date.now() })
  }
});

// Export for external access if needed
export default tableMonitorSubscription;
