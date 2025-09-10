import consumer from "./consumer"
import CableReady from 'cable_ready'

// Debug infrastructure for scoreboard operations
class ScoreboardDebugger {
  constructor() {
    this.operationStats = {
      total: 0,
      successful: 0,
      failed: 0,
      missingElements: 0,
      errors: []
    }
    this.startTime = Date.now()
  }

  logOperation(type, selector, success, error = null) {
    this.operationStats.total++
    if (success) {
      this.operationStats.successful++
      console.log(`✅ CableReady ${type}: ${selector}`)
    } else {
      this.operationStats.failed++
      if (error && error.message.includes('missing DOM element')) {
        this.operationStats.missingElements++
        console.warn(`⚠️ Missing element: ${selector}`)
      } else {
        console.error(`❌ CableReady ${type} failed: ${selector}`, error)
      }
      this.operationStats.errors.push({
        timestamp: new Date().toISOString(),
        type,
        selector,
        error: error?.message || 'Unknown error'
      })
    }
  }

  getStats() {
    const uptime = Date.now() - this.startTime
    return {
      ...this.operationStats,
      uptime: `${Math.round(uptime / 1000)}s`,
      successRate: this.operationStats.total > 0 ? 
        `${Math.round((this.operationStats.successful / this.operationStats.total) * 100)}%` : '0%'
    }
  }

  checkDOMHealth() {
    const commonSelectors = [
      '#teasers',
      '[id^="teaser_"]',
      '[id^="full_screen_table_monitor_"]',
      '#table_scores',
      '[id^="party_monitor_scores_"]'
    ]
    
    const health = {}
    commonSelectors.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      health[selector] = {
        count: elements.length,
        ids: Array.from(elements).map(el => el.id).filter(id => id)
      }
    })
    
    console.log('🏥 DOM Health Check:', health)
    return health
  }
}

const debugger = new ScoreboardDebugger()

// Expose debugger globally for console access
window.scoreboardDebugger = debugger

consumer.subscriptions.create("TableMonitorChannel", {

  // Called once when the subscription is created.
  initialized() {
    console.log("🔌 TableMonitor Channel initialized")
    debugger.checkDOMHealth()
  },

  connected() {
    // Called when the subscription is ready for use on the server
    console.log("✅ TableMonitor Channel connected")
    debugger.checkDOMHealth()
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    console.log("❌ TableMonitor Channel disconnected")
    console.log("📊 Final Stats:", debugger.getStats())
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    if (data.cableReady) {
      console.log("📡 Received CableReady operations:", data.operations?.length || 0)
      
      try {
        // Pre-check DOM elements before performing operations
        if (data.operations) {
          data.operations.forEach(operation => {
            if (operation.selector) {
              const element = document.querySelector(operation.selector)
              if (!element) {
                console.warn(`⚠️ Target element not found: ${operation.selector}`)
                debugger.logOperation(operation.operation || 'unknown', operation.selector, false, 
                  new Error(`Missing DOM element for selector: ${operation.selector}`))
              }
            }
          })
        }
        
        CableReady.perform(data.operations)
        
        // Log successful operations
        if (data.operations) {
          data.operations.forEach(operation => {
            debugger.logOperation(operation.operation || 'unknown', operation.selector || 'unknown', true)
          })
        }
        
      } catch (error) {
        console.error("💥 CableReady operation failed:", error)
        
        // Log failed operations
        if (data.operations) {
          data.operations.forEach(operation => {
            debugger.logOperation(operation.operation || 'unknown', operation.selector || 'unknown', false, error)
          })
        }
        
        // Attempt to recover or provide helpful information
        console.log("🔍 Current DOM state:")
        debugger.checkDOMHealth()
      }
    }
  }
});
