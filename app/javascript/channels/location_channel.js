import consumer from "./consumer"
import CableReady from 'cable_ready'

// Performance logging - can be enabled via localStorage
const PERF_LOGGING = localStorage.getItem('debug_cable_performance') === 'true'
const NO_LOGGING = localStorage.getItem('cable_no_logging') === 'true'

// Health Monitor for Location Channel (similar to table_monitor_channel.js)
class LocationChannelHealthMonitor {
  constructor(subscription, locationId) {
    this.subscription = subscription
    this.locationId = locationId
    this.healthCheckInterval = null
    this.reconnectTimeout = null
    this.healthCheckFrequency = 30000 // 30 seconds
    this.maxSilenceTime = 120000 // 2 minutes without any message
    this.reconnectDelay = 5000 // 5 seconds
    this.forceReloadDelay = 10000 // 10 seconds if reconnect fails
  }

  start() {
    if (!NO_LOGGING) {
      console.log("🏥 Location Channel health monitor started for location", this.locationId)
    }
    
    this.healthCheckInterval = setInterval(() => {
      this.checkHealth()
    }, this.healthCheckFrequency)

    // Check on page visibility change (TV wake-from-sleep)
    this.visibilityHandler = () => {
      if (!document.hidden) {
        if (!NO_LOGGING) {
          console.log("📱 Page became visible, checking location channel health...")
        }
        this.checkHealth()
      }
    }
    document.addEventListener('visibilitychange', this.visibilityHandler)
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
    if (this.visibilityHandler) {
      document.removeEventListener('visibilitychange', this.visibilityHandler)
      this.visibilityHandler = null
    }
    if (!NO_LOGGING) {
      console.log("🏥 Location Channel health monitor stopped")
    }
  }

  checkHealth() {
    try {
      const state = consumer.connection.getState()
      const timeSinceLastMessage = Date.now() - this.subscription.lastReceived
      
      if (PERF_LOGGING && !NO_LOGGING) {
        console.log("🏥 Location Channel health check:", {
          connectionState: state,
          timeSinceLastMessage: Math.round(timeSinceLastMessage / 1000) + "s",
          lastReceived: new Date(this.subscription.lastReceived).toISOString()
        })
      }

      // Check 1: Connection not open
      if (state !== "open") {
        console.warn("⚠️ Location Channel connection not open, state:", state)
        this.triggerReconnect("connection_not_open")
        return
      }

      // Check 2: No messages for too long (but only if page is visible)
      if (!document.hidden && timeSinceLastMessage > this.maxSilenceTime) {
        console.warn("⚠️ Location Channel: No messages received for", Math.round(timeSinceLastMessage / 1000), "seconds")
        this.triggerReconnect("message_timeout")
        return
      }

      // Connection looks healthy
      if (PERF_LOGGING && !NO_LOGGING) {
        console.log("✅ Location Channel connection healthy")
      }
      this.updateStatusIndicator('healthy')
    } catch (error) {
      console.error("❌ Location Channel health check failed:", error)
      this.triggerReconnect("health_check_error")
    }
  }

  triggerReconnect(reason) {
    console.warn("🔄 Location Channel triggering reconnection, reason:", reason)
    this.updateStatusIndicator('reconnecting')
    
    // Try to reopen connection
    consumer.connection.reopen()

    // If reconnection doesn't work, reload page
    this.reconnectTimeout = setTimeout(() => {
      const state = consumer.connection.getState()
      if (state !== "open") {
        console.error("🔄 Location Channel reconnection failed, reloading page...")
        this.updateStatusIndicator('reloading')
        window.location.reload()
      } else {
        console.log("✅ Location Channel reconnection successful")
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
      detail: { status, channel: 'location' }
    }))
  }
}

// Get location_id from data attribute
const locationElement = document.querySelector('[data-location-id]')
if (locationElement) {
  const locationId = locationElement.dataset.locationId

  // Create subscription for this location
  const locationSubscription = consumer.subscriptions.create(
    { channel: "LocationChannel", location_id: locationId },
    {
      initialized() {
        if (PERF_LOGGING && !NO_LOGGING) {
          console.log("🏢 Location Channel initialized for location", locationId)
        }
        this.lastReceived = Date.now()
        this.pendingBroadcastTimestamp = null
        this.connectionAttempts = 0
        
        // Initialize health monitor
        this.healthMonitor = new LocationChannelHealthMonitor(this, locationId)
      },

      connected() {
        if (!NO_LOGGING) {
          console.log("🏢 Location Channel connected for location", locationId)
        }
        this.connectionAttempts = 0
        
        // Start health monitoring
        if (this.healthMonitor) {
          this.healthMonitor.start()
        }
        
        // Start periodic heartbeat to server (every 60 seconds)
        this.startHeartbeat()
      },
      
      startHeartbeat() {
        // Clear any existing heartbeat
        if (this.heartbeatInterval) {
          clearInterval(this.heartbeatInterval)
        }
        
        // Send heartbeat every 60 seconds to keep connection alive
        this.heartbeatInterval = setInterval(() => {
          if (!document.hidden) {
            this.sendHeartbeat()
          }
        }, 60000)
        
        if (PERF_LOGGING && !NO_LOGGING) {
          console.log("💓 Heartbeat started (every 60s)")
        }
      },
      
      sendHeartbeat() {
        try {
          this.perform('heartbeat', { timestamp: Date.now() })
          if (PERF_LOGGING && !NO_LOGGING) {
            console.log("💓 Heartbeat sent to server")
          }
        } catch (error) {
          console.error("💔 Failed to send heartbeat:", error)
        }
      },

      disconnected() {
        if (!NO_LOGGING) {
          console.warn("🏢 Location Channel disconnected for location", locationId)
        }
        this.connectionAttempts++
        
        // Stop health monitoring
        if (this.healthMonitor) {
          this.healthMonitor.stop()
        }
        
        // Stop heartbeat
        if (this.heartbeatInterval) {
          clearInterval(this.heartbeatInterval)
          this.heartbeatInterval = null
        }
        
        // If too many disconnects, reload page
        if (this.connectionAttempts > 5) {
          console.error("🔄 Too many disconnects, reloading page...")
          window.location.reload()
        }
      },

      received(data) {
        const receiveTime = Date.now()
        this.lastReceived = receiveTime

        // Handle performance timestamp message
        if (data.type === "performance_timestamp") {
          this.pendingBroadcastTimestamp = data.timestamp
          if (!NO_LOGGING && typeof performance !== 'undefined' && performance.mark) {
            performance.mark('broadcast-start')
          }
          if (PERF_LOGGING && !NO_LOGGING) {
            console.log("⏱️ Received broadcast timestamp:", data.timestamp)
          }
          return
        }

        // Handle heartbeat acknowledgment
        if (data.type === "heartbeat_ack") {
          if (PERF_LOGGING && !NO_LOGGING) {
            console.log("💓 Heartbeat acknowledged by server")
          }
          // Update lastReceived to keep health monitor happy
          this.lastReceived = receiveTime
          return
        }

        // Performance measurement
        let broadcastTimestamp = this.pendingBroadcastTimestamp
        let networkLatency = null

        if (data.cableReady && data.operations?.length > 0) {
          const firstOp = data.operations[0]

          // Use pending broadcast timestamp if available
          if (broadcastTimestamp) {
            networkLatency = receiveTime - broadcastTimestamp
            this.pendingBroadcastTimestamp = null
          }

          // Log incoming data with performance details
          if (PERF_LOGGING && !NO_LOGGING) {
            console.log("📥 Location Channel received:", {
              timestamp: new Date().toISOString(),
              hasCableReady: true,
              operationCount: data.operations.length,
              type: data.type || 'broadcast',
              broadcastTimestamp: broadcastTimestamp,
              networkLatency: networkLatency ? `${networkLatency.toFixed(0)}ms` : 'N/A'
            })
          }

          // Measure CableReady performance
          const performStart = Date.now()
          CableReady.perform(data.operations)
          const performTime = Date.now() - performStart
          const totalLatency = Date.now() - (broadcastTimestamp || receiveTime)

          // Measure post-update rendering
          const selector = firstOp.selector || 'unknown'

          // Simple performance output without requestAnimationFrame (faster)
          if (NO_LOGGING) {
            if (broadcastTimestamp && networkLatency !== null) {
              console.log(`⚡ [${selector}] network:${networkLatency.toFixed(0)}ms dom:${performTime}ms total:${totalLatency}ms`)
            }
          } else {
            requestAnimationFrame(() => {
              const afterRenderTime = Date.now() - performStart
              const totalWithRender = Date.now() - (broadcastTimestamp || receiveTime)

              if (broadcastTimestamp && networkLatency !== null) {
                const perfData = {
                  location_stream: locationId,
                  network: `${networkLatency.toFixed(0)}ms`,
                  innerHTML: `${performTime}ms`,
                  reflow: `${afterRenderTime - performTime}ms`,
                  dom_total: `${afterRenderTime}ms`,
                  total: `${totalWithRender}ms`
                }
                console.log(`⚡ Performance [${selector}]:`, perfData)
              }
            })
          }
        }
      }
    }
  )

  // Export for external access if needed
  window.locationSubscription = locationSubscription
}
