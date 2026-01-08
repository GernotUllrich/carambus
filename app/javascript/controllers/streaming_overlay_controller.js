import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Connects to data-controller="streaming-overlay"
export default class extends Controller {
  static targets = ["scoreA", "scoreB"]
  static values = { tableId: Number }
  
  connect() {
    console.log("[StreamingOverlay] Connected", this.tableIdValue)
    
    // PHASE 1: Simple polling approach for OBS Browser Source
    // Reload page every 3 seconds to fetch fresh scores
    // This is simple, reliable, and works great for streaming overlays
    this.pollInterval = setInterval(() => {
      console.log("[StreamingOverlay] Reloading for fresh data...")
      window.location.reload()
    }, 3000) // 3 seconds
    
    // PHASE 2: Real-time updates via CableReady (future optimization)
    // Uncomment this when implementing event-driven updates
    // this.subscribeToTableMonitor()
  }
  
  disconnect() {
    console.log("[StreamingOverlay] Disconnected")
    
    // Clear polling interval
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
    
    // Unsubscribe from ActionCable (when using Phase 2)
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }
  
  subscribeToTableMonitor() {
    // Subscribe to table monitor channel for real-time score updates
    this.subscription = consumer.subscriptions.create(
      { channel: "TableMonitorChannel" },
      {
        connected: () => {
          console.log("[StreamingOverlay] WebSocket connected")
        },
        
        disconnected: () => {
          console.log("[StreamingOverlay] WebSocket disconnected")
        },
        
        received: (data) => {
          console.log("[StreamingOverlay] Received data:", data)
          this.handleUpdate(data)
        }
      }
    )
  }
  
  handleUpdate(data) {
    // Trigger overlay PNG update when CableReady operations contain teaser updates
    if (data.cableReady && data.operations) {
      data.operations.forEach(op => {
        // Trigger PNG update on any teaser inner_html update
        if (op.operation === 'innerHtml' && op.selector && op.selector.includes('teaser')) {
          this.triggerOverlayUpdate()
        }
        // Also trigger on explicit overlay-png-update events
        if (op.operation === 'dispatchEvent' && op.name === 'overlay-png-update') {
          this.triggerOverlayUpdate()
        }
      })
    }
    
    // Handle different types of updates
    switch(data.type) {
      case "score_update":
        this.updateScores(data)
        break
      case "game_start":
        // Reload page to show new game
        window.location.reload()
        break
      case "game_end":
        // Reload page to show "no game" state
        window.location.reload()
        break
      case "heartbeat_ack":
        // Ignore heartbeat responses
        break
      default:
        console.log("[StreamingOverlay] Unknown message type:", data.type)
    }
  }
  
  triggerOverlayUpdate() {
    // Trigger local overlay updater service to fetch latest PNG
    // The updater service listens on localhost:8888 and fetches from server
    fetch('http://localhost:8888/update', { 
      method: 'GET',
      mode: 'no-cors' // Avoid CORS preflight for simple GET
    }).catch(err => {
      // Silently ignore errors (updater might not be running on non-streaming clients)
      console.debug("[StreamingOverlay] Overlay update trigger:", err.message)
    })
  }
  
  updateScores(data) {
    // Only update if this is for our table
    if (data.table_id && data.table_id !== this.tableIdValue) {
      return
    }
    
    // Update score displays with animation
    if (data.score_a !== undefined && this.hasScoreATarget) {
      this.animateScoreChange(this.scoreATarget, data.score_a)
    }
    
    if (data.score_b !== undefined && this.hasScoreBTarget) {
      this.animateScoreChange(this.scoreBTarget, data.score_b)
    }
  }
  
  animateScoreChange(element, newScore) {
    const currentScore = parseInt(element.textContent) || 0
    
    if (currentScore === newScore) {
      return // No change
    }
    
    // Flash animation
    element.style.transition = "transform 0.3s ease, color 0.3s ease"
    element.style.transform = "scale(1.2)"
    element.style.color = "#FFD700" // Gold
    
    // Update score
    element.textContent = newScore
    
    // Reset after animation
    setTimeout(() => {
      element.style.transform = "scale(1)"
      element.style.color = "#4CAF50"
    }, 300)
  }
}


