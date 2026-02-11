import consumer from "./consumer"
import CableReady from 'cable_ready'

// Performance logging - can be enabled via localStorage
const PERF_LOGGING = localStorage.getItem('debug_cable_performance') === 'true'
const NO_LOGGING = localStorage.getItem('cable_no_logging') === 'true'

// Ultra-fast score update handler
// Note: CableReady dispatch_event creates events on document with camelCase keys
document.addEventListener('score:update', (event) => {
  const { tableMonitorId, playerKey, score, inning } = event.detail
  
  // Get the current page's table monitor ID from the DOM
  const scoreboardRoot = document.querySelector('[data-table-monitor-root="scoreboard"]')
  const currentTableMonitorId = scoreboardRoot?.dataset?.tableMonitorId
  
  // Only process updates for THIS specific table monitor
  // If no scoreboard root exists (e.g., on table_scores page), ignore the update
  if (!currentTableMonitorId || parseInt(currentTableMonitorId) !== parseInt(tableMonitorId)) {
    return
  }
  
  // Update main score
  const scoreElements = document.querySelectorAll(`.main-score[data-player="${playerKey}"]`)
  scoreElements.forEach(el => {
    el.textContent = score
  })
  
  // Update score-display data attribute
  const scoreDisplays = document.querySelectorAll(`.score-display[data-player="${playerKey}"]`)
  scoreDisplays.forEach(el => {
    el.dataset.score = score
  })
  
  // Update inning score
  const inningElements = document.querySelectorAll(`.inning-score[data-player="${playerKey}"]`)
  inningElements.forEach(el => {
    el.textContent = inning
  })
})

// Page Context Detection and Filtering
function getPageContext() {
  // IMPORTANT: Check page type FIRST before using meta tag
  // Meta tag is present on all pages within location context, but should only
  // be used for actual scoreboard pages
  
  // Detect table_scores overview page FIRST
  if (document.querySelector('#table_scores')) {
    return { type: 'table_scores' }
  }
  
  // Detect tournament_scores view FIRST
  if (document.querySelector('turbo-frame#teasers')) {
    return { type: 'tournament_scores' }
  }
  
  // Now we know we're NOT on table_scores or tournament_scores
  // Check if we're on an actual scoreboard page
  
  // PRIORITY 1: Check data attribute (most reliable for scoreboard detection)
  const scoreboardRoot = document.querySelector('[data-table-monitor-root="scoreboard"]')
  if (scoreboardRoot) {
    const tableMonitorId = scoreboardRoot.dataset.tableMonitorId
    if (tableMonitorId) {
      return { 
        type: 'scoreboard', 
        tableMonitorId: parseInt(tableMonitorId),
        source: 'data-attribute'
      }
    }
  }
  
  // PRIORITY 2: Check meta tag (reliable if scoreboard root is loading/transitioning)
  const metaTableMonitorId = document.querySelector('meta[name="scoreboard-table-monitor-id"]')
  if (metaTableMonitorId) {
    const tableMonitorId = parseInt(metaTableMonitorId.content)
    if (tableMonitorId) {
      if (PERF_LOGGING && !NO_LOGGING) {
        console.log('🎯 Table Monitor ID from meta tag:', tableMonitorId)
      }
      return { 
        type: 'scoreboard', 
        tableMonitorId: tableMonitorId,
        source: 'meta-tag'
      }
    }
  }
  
  // PRIORITY 3: Fallback - try to detect by ID if data attribute is missing
  const scoreboardEl = document.querySelector('[id^="full_screen_table_monitor_"]')
  if (scoreboardEl) {
    const idMatch = scoreboardEl.id.match(/full_screen_table_monitor_(\d+)/)
    const tableMonitorId = idMatch ? parseInt(idMatch[1]) : null
    if (tableMonitorId) {
      return { 
        type: 'scoreboard', 
        tableMonitorId: tableMonitorId,
        source: 'dom-id'
      }
    }
  }
  
  return { type: 'unknown' }
}

function shouldAcceptOperation(operation, pageContext) {
  if (!operation.selector) {
    // Operations without selectors are accepted (e.g., dispatch_event)
    return true
  }
  
  const selector = operation.selector
  
  // Extract table monitor ID from full_screen selectors
  const fullScreenMatch = selector.match(/^#full_screen_table_monitor_(\d+)$/)
  
  switch (pageContext.type) {
    case 'scoreboard':
      // Only accept full_screen updates for THIS specific table monitor
      if (fullScreenMatch) {
        const selectorTableMonitorId = parseInt(fullScreenMatch[1])
        const isMatch = selectorTableMonitorId === pageContext.tableMonitorId
        if (!isMatch) {
          // CRITICAL: Log rejected scoreboard updates for debugging mix-ups
          console.warn(`🚫 SCOREBOARD MIX-UP PREVENTED: Selector ${selector} (TM_ID: ${selectorTableMonitorId}) rejected for current scoreboard (TM_ID: ${pageContext.tableMonitorId}, source: ${pageContext.source})`)
          console.warn(`🚫 Context:`, {
            rejectedTableMonitorId: selectorTableMonitorId,
            currentTableMonitorId: pageContext.tableMonitorId,
            detectionSource: pageContext.source,
            timestamp: new Date().toISOString(),
            url: window.location.href
          })
        }
        return isMatch
      }
      // Reject teaser and table_scores updates on scoreboard pages
      if (selector.startsWith('#teaser_') || selector === '#table_scores') {
        return false
      }
      // For unknown selectors on scoreboard pages, be strict - only accept if it's for this monitor
      // Check if it's a full_screen selector we didn't catch
      if (selector.includes('full_screen_table_monitor')) {
        const idMatch = selector.match(/full_screen_table_monitor_(\d+)/)
        if (idMatch) {
          const selectorId = parseInt(idMatch[1])
          return selectorId === pageContext.tableMonitorId
        }
      }
      // For other selectors, check if element exists AND is within this scoreboard's context
      const element = document.querySelector(selector)
      if (element) {
        // Verify the element is within the current scoreboard's DOM
        const currentScoreboard = document.querySelector(`#full_screen_table_monitor_${pageContext.tableMonitorId}`)
        if (currentScoreboard && currentScoreboard.contains(element)) {
          return true
        }
      }
      return false
      
    case 'table_scores':
      // Accept table_scores and teaser updates
      if (selector === '#table_scores' || selector.startsWith('#teaser_')) {
        return !!document.querySelector(selector)
      }
      // Reject full_screen updates
      if (fullScreenMatch) {
        return false
      }
      // For unknown selectors, check if element exists
      return !!document.querySelector(selector)
      
    case 'tournament_scores':
      // Accept teaser updates
      if (selector.startsWith('#teaser_')) {
        return !!document.querySelector(selector)
      }
      // Reject table_scores and full_screen updates
      if (selector === '#table_scores' || fullScreenMatch) {
        return false
      }
      // For unknown selectors, check if element exists
      return !!document.querySelector(selector)
      
    case 'unknown':
    default:
      // For unknown context, be very conservative
      // Only accept if it's clearly not a full_screen update
      if (fullScreenMatch) {
        // Don't accept full_screen updates if we don't know the context
        return false
      }
      // For other selectors, check if element exists
      return !!document.querySelector(selector)
  }
}

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
      
      if (PERF_LOGGING && !NO_LOGGING) {
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
      if (PERF_LOGGING && !NO_LOGGING) {
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
    if (PERF_LOGGING && !NO_LOGGING) {
      console.log("🔌 TableMonitor Channel initialized")
    }
    this.connectionAttempts = 0
    this.lastReceived = Date.now()
    this.healthMonitor = new ConnectionHealthMonitor(this)
    this.pendingBroadcastTimestamp = null // Store timestamp from performance_timestamp message
  },

  connected() {
    // Called when the subscription is ready for use on the server
    if (!NO_LOGGING) {
      console.log("🔌 TableMonitor Channel connected")
    }
    if (PERF_LOGGING && !NO_LOGGING) {
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
    if (!NO_LOGGING) {
      console.warn("🔌 TableMonitor Channel disconnected (attempt #" + this.connectionAttempts + ")")
      console.warn("🔌 Time since last message:", (Date.now() - this.lastReceived) / 1000, "seconds")
    }
    
    // Stop health monitoring
    this.healthMonitor.stop()
    this.healthMonitor.updateStatusIndicator('disconnected')
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    const receiveTime = Date.now()
    this.lastReceived = receiveTime
    
    // Handle performance timestamp message (sent before CableReady operations)
    if (data.type === "performance_timestamp") {
      this.pendingBroadcastTimestamp = data.timestamp
      // Mark start for user perception measurement
      if (!NO_LOGGING && typeof performance !== 'undefined' && performance.mark) {
        performance.mark('broadcast-start')
      }
      if (PERF_LOGGING && !NO_LOGGING) {
        console.log("⏱️ Received broadcast timestamp:", data.timestamp)
      }
      return
    }
    
    // Handle force reconnect
    if (data.type === "force_reconnect") {
      if (!NO_LOGGING) {
        console.warn("🔄 Server requested forced reconnect:", data.reason)
      }
      this.healthMonitor.updateStatusIndicator('reconnecting')
      setTimeout(() => {
        window.location.reload()
      }, 2000)
      return
    }

    // Handle heartbeat acknowledgment
    if (data.type === "heartbeat_ack") {
      if (PERF_LOGGING && !NO_LOGGING) {
        console.log("💓 Heartbeat acknowledged by server")
      }
      return
    }

    // Handle scoreboard messages (admin messages to scoreboards)
    if (data.type === "scoreboard_message") {
      if (!NO_LOGGING) {
        console.log("📨 Scoreboard message received:", data)
      }
      // Use global helper function to show message
      if (window.ScoreboardMessageController) {
        window.ScoreboardMessageController.showMessage(data)
      } else {
        console.warn("⚠️ ScoreboardMessageController global not found")
      }
      return
    }

    // Handle scoreboard message acknowledgement (hide message on all scoreboards)
    if (data.type === "scoreboard_message_acknowledged") {
      if (!NO_LOGGING) {
        console.log("✅ Scoreboard message acknowledged:", data.message_id)
      }
      // Use global helper function to hide message
      if (window.ScoreboardMessageController) {
        window.ScoreboardMessageController.hideMessage(data.message_id)
      }
      return
    }
    
    // Handle dispatch_event operations (they have a different structure)
    // Note: dispatch_event operations create DOM events that are handled by event listeners
    // The event listeners themselves filter by tableMonitorId, so we can allow these through
    // However, we should still check if we're on the right page type
    if (data.cableReady && data.operations?.length > 0) {
      const firstOp = data.operations[0]
      if (firstOp.operation === 'dispatchEvent') {
        // For score:update events, the event listener will filter by tableMonitorId
        // For other dispatch events, allow them through (they'll be handled by their listeners)
        // But skip if we're on a page type that shouldn't receive these
        const pageContext = getPageContext()
        if (firstOp.name === 'score:update' && pageContext.type === 'scoreboard') {
          // score:update events are filtered by the event listener, so allow through
          CableReady.perform(data.operations)
          return
        } else if (firstOp.name === 'score:update') {
          // Don't dispatch score:update on non-scoreboard pages
          return
        }
        // For other dispatch events, allow through
        CableReady.perform(data.operations)
        return
      }
    }
    
    // Performance measurement
    let broadcastTimestamp = this.pendingBroadcastTimestamp
    let networkLatency = null
    
    if (data.cableReady && data.operations?.length > 0) {
      const firstOp = data.operations[0]
      
      // Use pending broadcast timestamp if available
      if (broadcastTimestamp) {
        networkLatency = receiveTime - broadcastTimestamp
        // Clear it so it's not reused
        this.pendingBroadcastTimestamp = null
      }
      
      // Log incoming data with performance details
      if (PERF_LOGGING && !NO_LOGGING) {
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
      
      // Context-aware filtering: only process operations relevant to this page
      const pageContext = getPageContext()
      
      // Debug logging to diagnose filtering issues
      if (PERF_LOGGING || !NO_LOGGING) {
        console.log('🔍 Filtering operations:', {
          pageContext,
          operationCount: data.operations.length,
          operations: data.operations.map(op => ({
            operation: op.operation,
            selector: op.selector
          }))
        })
      }
      
      // CRITICAL: Log if we're on a scoreboard page but context detection failed
      if (pageContext.type === 'unknown' && document.querySelector('[data-table-monitor-root="scoreboard"]')) {
        console.error('⚠️ SCOREBOARD CONTEXT DETECTION FAILED:', {
          detectedType: pageContext.type,
          hasScoreboardRoot: true,
          metaTag: document.querySelector('meta[name="scoreboard-table-monitor-id"]')?.content,
          dataAttribute: document.querySelector('[data-table-monitor-root="scoreboard"]')?.dataset?.tableMonitorId,
          timestamp: new Date().toISOString(),
          url: window.location.href
        })
      }
      
      const applicableOperations = data.operations.filter(op => {
        const accepted = shouldAcceptOperation(op, pageContext)
        if (PERF_LOGGING || !NO_LOGGING) {
          console.log(`${accepted ? '✅' : '🚫'} ${op.selector || 'no selector'}: ${accepted ? 'ACCEPTED' : 'REJECTED'}`)
        }
        return accepted
      })
      
      // If no operations are applicable, skip processing
      if (applicableOperations.length === 0) {
        return
      }
      
      // Check if first operation's selector exists (for logging purposes)
      const selectorExists = document.querySelector(firstOp.selector)
      
      // Measure CableReady performance
      const performStart = Date.now()
      // Only perform filtered operations
      CableReady.perform(applicableOperations)
      const performTime = Date.now() - performStart
      const totalLatency = Date.now() - (broadcastTimestamp || receiveTime)
      
      // Skip logging if element doesn't exist (update was filtered out)
      if (!selectorExists) {
        return
      }
      
      // Measure post-update rendering (requestAnimationFrame = after browser repaint)
      const selector = firstOp.selector || 'unknown'
      
      // Simple performance output without requestAnimationFrame (faster)
      if (NO_LOGGING) {
        // Minimal logging for NO_LOGGING mode
        if (broadcastTimestamp && networkLatency !== null) {
          console.log(`⚡ [${selector}] network:${networkLatency.toFixed(0)}ms dom:${performTime}ms total:${totalLatency}ms`)
        }
      } else {
        // Full performance measurement with reflow timing
        requestAnimationFrame(() => {
          const afterRenderTime = Date.now() - performStart
          const totalWithRender = Date.now() - (broadcastTimestamp || receiveTime)
          
          // Mark end and measure total perceived time
          let perceivedTime = null
          if (typeof performance !== 'undefined' && performance.mark && performance.measure) {
            try {
              performance.mark('broadcast-end')
              performance.measure('broadcast-perceived', 'broadcast-start', 'broadcast-end')
              const measure = performance.getEntriesByName('broadcast-perceived')[0]
              perceivedTime = Math.round(measure.duration)
              // Clean up marks
              performance.clearMarks('broadcast-start')
              performance.clearMarks('broadcast-end')
              performance.clearMeasures('broadcast-perceived')
            } catch (e) {
              // Ignore timing errors
            }
          }
          
          // Always log performance summary for significant operations
          if (broadcastTimestamp && networkLatency !== null) {
            const perfData = {
              server_timestamp: new Date(broadcastTimestamp).toISOString(),
              network: `${networkLatency.toFixed(0)}ms`,
              innerHTML: `${performTime}ms`,
              reflow: `${afterRenderTime - performTime}ms`,
              dom_total: `${afterRenderTime}ms`,
              total: `${totalWithRender}ms`
            }
            if (perceivedTime !== null) {
              perfData.perceived = `${perceivedTime}ms`
            }
            console.log(`⚡ Performance [${selector}]:`, perfData)
          } else {
            // Fallback without network timing
            if (firstOp && firstOp.selector) {
              console.log(`⚡ Performance [${selector}]: innerHTML=${performTime}ms, reflow=${afterRenderTime - performTime}ms, total=${afterRenderTime}ms`)
            } else if (PERF_LOGGING) {
              console.log("✅ CableReady operations performed in", performTime + "ms")
            }
          }
        })
      }
    } else if (PERF_LOGGING && !NO_LOGGING) {
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

