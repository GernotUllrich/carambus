import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

// Connects to data-controller="streaming-overlay"
export default class extends Controller {
  static targets = ["scoreA", "scoreB"]
  static values = { tableId: Number }
  
  connect() {
    console.log("[StreamingOverlay] Connected", this.tableIdValue)
    this.subscribeToTableMonitor()
  }
  
  disconnect() {
    console.log("[StreamingOverlay] Disconnected")
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

