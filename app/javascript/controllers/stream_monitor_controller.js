import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["status", "error", "uptime", "healthButton"]
  static values = {
    streamId: Number,
    autoRefresh: { type: Boolean, default: true },
    refreshInterval: { type: Number, default: 30000 } // 30 seconds
  }

  connect() {
    console.log("StreamMonitor connected for stream", this.streamIdValue)
    
    // Subscribe to stream status updates
    this.subscription = consumer.subscriptions.create(
      { channel: "StreamStatusChannel" },
      {
        received: (data) => {
          if (data.stream_id === this.streamIdValue) {
            this.updateStatus(data)
          }
        }
      }
    )

    // Start auto-refresh if enabled
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    }
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    this.stopAutoRefresh()
  }

  startAutoRefresh() {
    this.stopAutoRefresh() // Clear any existing interval
    
    this.refreshTimer = setInterval(() => {
      this.checkHealth()
    }, this.refreshIntervalValue)
    
    console.log(`Auto-refresh started (every ${this.refreshIntervalValue/1000}s)`)
  }

  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
  }

  checkHealth() {
    if (!this.streamIdValue) return

    // Send health check request via ActionCable
    if (this.subscription) {
      this.subscription.perform('check_health', {
        stream_id: this.streamIdValue
      })
    }

    // Also trigger HTTP health check for immediate feedback
    fetch(`/admin/stream_configurations/${this.streamIdValue}/health_check`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(response => response.json())
    .then(data => {
      this.updateStatus(data)
    })
    .catch(error => {
      console.error('Health check failed:', error)
    })
  }

  updateStatus(data) {
    // Update status badge
    if (this.hasStatusTarget) {
      const statusBadge = this.statusTarget
      statusBadge.className = this.getStatusClass(data.status)
      statusBadge.textContent = this.getStatusText(data.status)
    }

    // Update error message
    if (this.hasErrorTarget) {
      if (data.error_message) {
        this.errorTarget.textContent = data.error_message
        this.errorTarget.classList.remove('hidden')
      } else {
        this.errorTarget.classList.add('hidden')
      }
    }

    // Update uptime
    if (this.hasUptimeTarget && data.last_started_at) {
      const uptime = this.calculateUptime(data.last_started_at)
      this.uptimeTarget.textContent = uptime
    }

    // Update page title with status indicator
    this.updatePageTitle(data.status)
  }

  getStatusClass(status) {
    const baseClasses = "px-3 py-1 rounded-full text-sm font-semibold"
    const statusClasses = {
      'active': 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200',
      'starting': 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200',
      'stopping': 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200',
      'error': 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200',
      'inactive': 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
    }
    
    return `${baseClasses} ${statusClasses[status] || statusClasses['inactive']}`
  }

  getStatusText(status) {
    const icons = {
      'active': '🟢',
      'starting': '🟡',
      'stopping': '🟠',
      'error': '🔴',
      'inactive': '⚪'
    }
    
    const icon = icons[status] || icons['inactive']
    return `${icon} ${status.charAt(0).toUpperCase() + status.slice(1)}`
  }

  calculateUptime(startedAt) {
    const start = new Date(startedAt)
    const now = new Date()
    const diff = now - start
    
    const hours = Math.floor(diff / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
    
    return `${hours}h ${minutes}m`
  }

  updatePageTitle(status) {
    const icon = {
      'active': '🟢',
      'error': '🔴',
      'starting': '🟡'
    }[status]
    
    if (icon) {
      document.title = `${icon} Stream Status - Carambus`
    }
  }

  // Manual health check button click
  manualHealthCheck(event) {
    event.preventDefault()
    
    if (this.hasHealthButtonTarget) {
      const button = this.healthButtonTarget
      button.disabled = true
      button.textContent = 'Checking...'
      
      setTimeout(() => {
        button.disabled = false
        button.textContent = '❤️'
      }, 2000)
    }
    
    this.checkHealth()
  }

  // Toggle auto-refresh
  toggleAutoRefresh() {
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
    } else {
      this.stopAutoRefresh()
    }
  }
}



