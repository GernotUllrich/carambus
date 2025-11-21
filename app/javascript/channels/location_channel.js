import consumer from "./consumer"
import CableReady from 'cable_ready'

// Performance logging - can be enabled via localStorage
const PERF_LOGGING = localStorage.getItem('debug_cable_performance') === 'true'
const NO_LOGGING = localStorage.getItem('cable_no_logging') === 'true'

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
      },

      connected() {
        if (!NO_LOGGING) {
          console.log("🏢 Location Channel connected for location", locationId)
        }
      },

      disconnected() {
        if (!NO_LOGGING) {
          console.warn("🏢 Location Channel disconnected for location", locationId)
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
