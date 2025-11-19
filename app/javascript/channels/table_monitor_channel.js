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
    
    // ========================================================================
    // FAST JSON UPDATES - Route to specific handlers based on update type
    // ========================================================================
    
    if (data.type === "score_update") {
      // Häufigster Fall: Nur Scores geändert
      console.log('⚡ Score update:', data.data)
      this.handleScoreUpdate(data.table_monitor_id, data.data)
      return
    }
    
    if (data.type === "player_switch") {
      // Spielerwechsel
      console.log('🔄 Player switch:', data.data)
      this.handlePlayerSwitch(data.table_monitor_id, data.data)
      return
    }
    
    if (data.type === "state_change") {
      // Spielzustand geändert
      console.log('🎮 State change:', data.data)
      this.handleStateChange(data.table_monitor_id, data.data)
      return
    }
    
    // Handle CableReady operations (full_screen mit inner_html)
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
  },
  
  // ========================================================================
  // JSON UPDATE HANDLERS - Direkte DOM-Updates (kein Morphing!)
  // ========================================================================
  
  handleScoreUpdate(tableMonitorId, data) {
    // Filter: Nur Updates für dieses Scoreboard verarbeiten
    if (!this.isForThisMonitor(tableMonitorId)) {
      console.log(`⏭️ Skipping score update for TM ${tableMonitorId} (not for this monitor)`)
      return
    }
    
    // Nur Zahlen ändern - super schnell, kein Layout-Shift
    this.updatePlayerScores('playera', data.playera)
    this.updatePlayerScores('playerb', data.playerb)
  },
  
  handlePlayerSwitch(tableMonitorId, data) {
    // Filter: Nur Updates für dieses Scoreboard verarbeiten
    if (!this.isForThisMonitor(tableMonitorId)) {
      console.log(`⏭️ Skipping player switch for TM ${tableMonitorId} (not for this monitor)`)
      return
    }
    
    // Scores + aktiver Spieler + Border-Farben
    this.updatePlayerScores('playera', data.playera)
    this.updatePlayerScores('playerb', data.playerb)
    
    // Active borders aktualisieren
    this.updateActiveBorders(data.playera.active, data.playerb.active)
    
    // Layout (left/right) könnte sich geändert haben
    // Aber wir morphen NICHT - wir akzeptieren kleine Verzögerungen
    // bis zum nächsten full_screen refresh
  },
  
  handleStateChange(tableMonitorId, data) {
    // Filter: Nur Updates für dieses Scoreboard verarbeiten
    if (!this.isForThisMonitor(tableMonitorId)) {
      console.log(`⏭️ Skipping state change for TM ${tableMonitorId} (not for this monitor)`)
      return
    }
    
    // Komplettere Updates: Scores + Spieler + State
    this.updatePlayerScores('playera', data.playera)
    this.updatePlayerScores('playerb', data.playerb)
    this.updateActiveBorders(data.playera.active, data.playerb.active)
    
    // State display aktualisieren
    const stateEl = document.querySelector('.state-display')
    if (stateEl && data.state_display) {
      stateEl.textContent = data.state_display
      this.flashElement(stateEl)
    }
  },
  
  // ========================================================================
  // FILTER HELPER - Nur Updates für dieses Scoreboard verarbeiten
  // ========================================================================
  
  isForThisMonitor(tableMonitorId) {
    // Finde das Scoreboard-Element auf dieser Seite
    const scoreboardEl = document.querySelector('[id^="full_screen_table_monitor_"]')
    
    if (!scoreboardEl) {
      console.warn('⚠️ No scoreboard element found on this page')
      return false
    }
    
    // Extrahiere die table_monitor_id aus der Element-ID
    const match = scoreboardEl.id.match(/full_screen_table_monitor_(\d+)/)
    if (!match) {
      console.warn('⚠️ Could not extract table_monitor_id from element', scoreboardEl.id)
      return false
    }
    
    const thisMonitorId = parseInt(match[1])
    const incomingMonitorId = parseInt(tableMonitorId)
    
    // Nur Updates für dieses Scoreboard verarbeiten
    return thisMonitorId === incomingMonitorId
  },
  
  // ========================================================================
  // DOM UPDATE HELPERS
  // ========================================================================
  
  updatePlayerScores(playerId, playerData) {
    // Direktes textContent-Update - kein innerHTML, kein Morphing!
    // Strategie: Nur die KRITISCHEN Werte aktualisieren (Score + Inning Score)
    // HS/GD/Innings werden beim nächsten full_screen aktualisiert
    
    // Main score (Gesamtpunktzahl) - findet das Element mit data-player attribute
    const scoreEl = document.querySelector(`.main-score[data-player="${playerId}"]`)
    if (scoreEl && playerData.score !== undefined) {
      const newDisplayScore = playerData.score + (playerData.inning_score || 0)
      const oldScore = parseInt(scoreEl.textContent) || 0
      if (oldScore !== newDisplayScore) {
        scoreEl.textContent = newDisplayScore
        this.flashElement(scoreEl)
      }
    }
    
    // Current inning score (aktueller Aufnahme-Score)
    const inningScoreEl = document.querySelector(`.inning-score[data-player="${playerId}"]`)
    if (inningScoreEl && playerData.inning_score !== undefined) {
      inningScoreEl.textContent = playerData.inning_score
    }
    
    // Note: HS, GD, Innings werden NICHT hier aktualisiert
    // Diese ändern sich selten und werden beim nächsten full_screen refresh aktualisiert
    // Das spart CPU-Zeit und reduziert DOM-Manipulationen
  },
  
  updateActiveBorders(playeraActive, playerbActive) {
    // Border-Styles für aktiven Spieler
    const playeraEl = document.querySelector('[data-player="playera"]')
    const playerbEl = document.querySelector('[data-player="playerb"]')
    
    if (playeraEl) {
      if (playeraActive) {
        playeraEl.classList.remove('border-4', 'border-gray-500')
        playeraEl.classList.add('border-8', 'border-green-400')
      } else {
        playeraEl.classList.remove('border-8', 'border-green-400')
        playeraEl.classList.add('border-4', 'border-gray-500')
      }
    }
    
    if (playerbEl) {
      if (playerbActive) {
        playerbEl.classList.remove('border-4', 'border-gray-500')
        playerbEl.classList.add('border-8', 'border-green-400')
      } else {
        playerbEl.classList.remove('border-8', 'border-green-400')
        playerbEl.classList.add('border-4', 'border-gray-500')
      }
    }
  },
  
  flashElement(element) {
    // Kurzes visuelles Feedback für geänderte Werte
    element.classList.add('bg-yellow-200')
    setTimeout(() => {
      element.classList.remove('bg-yellow-200')
    }, 150)
  }
});