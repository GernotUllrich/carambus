import consumer from "./consumer"
import CableReady from 'cable_ready'

// Use the global scoreboard debugger from utilities with safety check
// Always use the global debugger instance - create fallback if needed
if (!window.scoreboardDebugger) {
  window.scoreboardDebugger = {
    enabled: true, // Default to enabled for fallback
    checkDOMHealth: () => {
      console.log('🏥 DOM Health Check: ScoreboardDebugger not yet loaded')
      return {}
    },
    logOperation: (type, selector, success, error) => {
      if (success) {
        console.log(`✅ CableReady ${type}: ${selector}`)
      }
      // Skip error logging for missing elements - they're handled by filtering
    },
    getStats: () => ({ total: 0, successful: 0, failed: 0 })
  }
}

const scoreboardDebugger = window.scoreboardDebugger

// Debug: Log which debugger we're using
console.log('🔧 Using debugger:', scoreboardDebugger === window.scoreboardDebugger ? 'main' : 'fallback')
console.log('🔧 Debugger enabled:', scoreboardDebugger.enabled)
console.log('🔧 CACHE BUST TIMESTAMP:', new Date().toISOString())
console.log('🔧 UNIQUE ID:', Math.random().toString(36).substr(2, 9))
console.log('🔧 FORCE CACHE BUST:', Date.now())

consumer.subscriptions.create("TableMonitorChannel", {

  // Called once when the subscription is created.
  initialized() {
    if (scoreboardDebugger.enabled) {
      console.log("🔌 TableMonitor Channel initialized")
    }
    scoreboardDebugger.checkDOMHealth()
  },

  connected() {
    // Called when the subscription is ready for use on the server
    if (scoreboardDebugger.enabled) {
      console.log("✅ TableMonitor Channel connected")
    }
    scoreboardDebugger.checkDOMHealth()
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
    if (scoreboardDebugger.enabled) {
      console.log("❌ TableMonitor Channel disconnected")
      console.log("📊 Final Stats:", scoreboardDebugger.getStats())
    }
  },

  received(data) {
    // Called when there's incoming data on the websocket for this channel
    
    // Handle custom JSON updates (new approach for fast scoreboard updates)
    if (data.type === "scoreboard_update" && data.data) {
      console.log('📊 Received scoreboard update:', data.data)
      
      // Dispatch custom event that the tabmon controller listens for
      const event = new CustomEvent('scoreboard:data_update', {
        detail: data.data,
        bubbles: true
      })
      document.dispatchEvent(event)
      return
    }
    
    // Handle CableReady operations (old approach)
    if (data.cableReady) {
      // Debug messages removed - no more console spam
      
      try {
        // Filter out operations for elements that don't exist on current page
        const applicableOperations = data.operations?.filter(operation => {
          if (operation.selector) {
            const element = document.querySelector(operation.selector)
            if (!element) {
              // Debug messages removed - no more console spam
              return false
            }
          }
          return true
        }) || []
        
        if (applicableOperations.length === 0) {
          // Debug messages removed - no more console spam
          return
        }
        
        // Debug messages removed - no more console spam
        
        CableReady.perform(applicableOperations)
        
        // Log successful operations
        applicableOperations.forEach(operation => {
          scoreboardDebugger.logOperation(operation.operation || 'unknown', operation.selector || 'unknown', true)
        })
        
      } catch (error) {
        // Debug messages removed - no more console spam
      }
    }
  }
});