import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="scoreboard-message"
export default class extends Controller {
  static targets = ["messageText", "expiryText", "countdown", "closeButton", "acknowledgeButton"]
  static values = {
    messageId: Number,
    tableMonitorId: Number
  }

  connect() {
    console.log('[ScoreboardMessage] Controller connected')
    this.countdownInterval = null
    this.closeButtonTimeout = null
    
    // Listen for ActionCable messages
    this.setupActionCableListener()
  }

  disconnect() {
    console.log('[ScoreboardMessage] Controller disconnected')
    this.clearTimers()
  }

  setupActionCableListener() {
    // Check if we have access to the consumer (from table_monitor_channel)
    if (window.tableMonitorChannel) {
      console.log('[ScoreboardMessage] Using existing tableMonitorChannel')
    } else {
      console.warn('[ScoreboardMessage] No tableMonitorChannel found, messages will not be received')
    }
  }

  // Called from external code when a message is received via ActionCable
  showMessage(data) {
    console.log('[ScoreboardMessage] Showing message:', data)
    
    // Store message ID
    this.messageIdValue = data.message_id
    
    // Update modal content
    this.messageTextTarget.textContent = data.message
    
    // Calculate time until expiry
    const expiresAt = new Date(data.expires_at)
    const now = new Date()
    const minutesUntilExpiry = Math.round((expiresAt - now) / 1000 / 60)
    
    this.expiryTextTarget.textContent = `This message will expire in ${minutesUntilExpiry} minutes`
    
    // Show modal
    this.element.classList.remove('hidden')
    
    // Start countdown
    this.startCountdown(expiresAt)
    
    // Show close button after 3 seconds (to ensure message is read)
    this.closeButtonTimeout = setTimeout(() => {
      if (this.hasCloseButtonTarget) {
        this.closeButtonTarget.classList.remove('hidden')
      }
    }, 3000)
    
    // Auto-dismiss at expiry time
    const timeUntilExpiry = expiresAt - now
    setTimeout(() => {
      this.hideModal()
    }, timeUntilExpiry)
  }

  // Called from external code when a message is acknowledged elsewhere
  hideMessageIfMatches(messageId) {
    if (this.messageIdValue === messageId) {
      console.log('[ScoreboardMessage] Message acknowledged elsewhere, hiding')
      this.hideModal()
    }
  }

  startCountdown(expiresAt) {
    this.clearCountdown()
    
    const updateCountdown = () => {
      const now = new Date()
      const secondsRemaining = Math.max(0, Math.round((expiresAt - now) / 1000))
      
      if (this.hasCountdownTarget) {
        const minutes = Math.floor(secondsRemaining / 60)
        const seconds = secondsRemaining % 60
        this.countdownTarget.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`
      }
      
      if (secondsRemaining <= 0) {
        this.clearCountdown()
      }
    }
    
    updateCountdown()
    this.countdownInterval = setInterval(updateCountdown, 1000)
  }

  clearCountdown() {
    if (this.countdownInterval) {
      clearInterval(this.countdownInterval)
      this.countdownInterval = null
    }
  }

  clearTimers() {
    this.clearCountdown()
    if (this.closeButtonTimeout) {
      clearTimeout(this.closeButtonTimeout)
      this.closeButtonTimeout = null
    }
  }

  acknowledge() {
    console.log('[ScoreboardMessage] Acknowledging message:', this.messageIdValue)
    
    // Disable button to prevent double-clicks
    if (this.hasAcknowledgeButtonTarget) {
      this.acknowledgeButtonTarget.disabled = true
      this.acknowledgeButtonTarget.textContent = 'Sending...'
    }
    
    // Send acknowledgement to server
    fetch(`/scoreboard_messages/${this.messageIdValue}/acknowledge`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      console.log('[ScoreboardMessage] Acknowledgement response:', data)
      if (data.success) {
        // Hide modal immediately
        this.hideModal()
      } else {
        console.error('[ScoreboardMessage] Failed to acknowledge:', data.message)
        // Re-enable button
        if (this.hasAcknowledgeButtonTarget) {
          this.acknowledgeButtonTarget.disabled = false
          this.acknowledgeButtonTarget.textContent = 'OK - I understand'
        }
      }
    })
    .catch(error => {
      console.error('[ScoreboardMessage] Error acknowledging message:', error)
      // Re-enable button
      if (this.hasAcknowledgeButtonTarget) {
        this.acknowledgeButtonTarget.disabled = false
        this.acknowledgeButtonTarget.textContent = 'OK - I understand'
      }
    })
  }

  hideModal() {
    console.log('[ScoreboardMessage] Hiding modal')
    this.element.classList.add('hidden')
    this.clearTimers()
    
    // Reset button state
    if (this.hasAcknowledgeButtonTarget) {
      this.acknowledgeButtonTarget.disabled = false
      this.acknowledgeButtonTarget.textContent = 'OK - I understand'
    }
    
    // Hide close button again
    if (this.hasCloseButtonTarget) {
      this.closeButtonTarget.classList.add('hidden')
    }
  }
}

// Make controller accessible globally for ActionCable callbacks
window.ScoreboardMessageController = {
  showMessage: (data) => {
    const controller = document.querySelector('[data-controller="scoreboard-message"]')
    if (controller && controller.scoreboardMessage) {
      controller.scoreboardMessage.showMessage(data)
    } else {
      console.warn('[ScoreboardMessage] Controller not found or not initialized')
    }
  },
  
  hideMessage: (messageId) => {
    const controller = document.querySelector('[data-controller="scoreboard-message"]')
    if (controller && controller.scoreboardMessage) {
      controller.scoreboardMessage.hideMessageIfMatches(messageId)
    }
  }
}
