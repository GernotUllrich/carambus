// Table Scores Monitor Controller
// Handles auto-refresh and wake-from-sleep detection for table_scores display page
// This is specifically designed for TV/Display browsers that go into standby mode
//
// Purpose:
// - Detect when TV browser wakes up from sleep/standby
// - Force page reload if display was asleep for more than a threshold
// - Prevent frozen/stale table_scores views on TV displays

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    // How long the page must be hidden before we force reload on visibility (ms)
    // Default: 5 minutes (TV typically sleeps longer than this)
    sleepThreshold: { type: Number, default: 300000 }, // 5 minutes
    
    // Enable debug logging
    debug: { type: Boolean, default: false }
  }

  connect() {
    this.log("🖥️ Table Scores Monitor connected")
    
    // Track when page becomes hidden
    this.hiddenAt = null
    
    // Track last activity time
    this.lastActivityAt = Date.now()
    
    // Listen for visibility changes (TV wake/sleep)
    this.visibilityChangeHandler = this.handleVisibilityChange.bind(this)
    document.addEventListener('visibilitychange', this.visibilityChangeHandler)
    
    // Listen for connection health issues
    this.connectionStatusHandler = this.handleConnectionStatus.bind(this)
    window.addEventListener('connection-status-change', this.connectionStatusHandler)
    
    // Optional: Periodic heartbeat check (every 30 seconds)
    this.heartbeatInterval = setInterval(() => {
      this.checkHeartbeat()
    }, 30000)
    
    this.log("✅ Monitoring started", {
      sleepThreshold: `${this.sleepThresholdValue / 1000}s`,
      currentlyHidden: document.hidden
    })
  }

  disconnect() {
    this.log("🔌 Table Scores Monitor disconnecting")
    
    // Clean up event listeners
    document.removeEventListener('visibilitychange', this.visibilityChangeHandler)
    window.removeEventListener('connection-status-change', this.connectionStatusHandler)
    
    // Clear heartbeat interval
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval)
      this.heartbeatInterval = null
    }
  }

  handleVisibilityChange() {
    if (document.hidden) {
      // Page became hidden (TV went to standby)
      this.hiddenAt = Date.now()
      this.log("😴 Page hidden (TV standby?)", {
        hiddenAt: new Date(this.hiddenAt).toISOString()
      })
    } else {
      // Page became visible (TV woke up)
      const now = Date.now()
      const hiddenDuration = this.hiddenAt ? (now - this.hiddenAt) : 0
      
      this.log("👁️ Page visible (TV wake?)", {
        hiddenDuration: `${Math.round(hiddenDuration / 1000)}s`,
        threshold: `${this.sleepThresholdValue / 1000}s`
      })
      
      // If page was hidden longer than threshold, force reload
      if (hiddenDuration > this.sleepThresholdValue) {
        this.log("🔄 Sleep threshold exceeded, forcing reload...", {
          hiddenFor: `${Math.round(hiddenDuration / 1000)}s`
        })
        
        // Show brief message before reload (optional, can be removed)
        this.showReloadMessage()
        
        // Force full page reload after brief delay
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        // Short hide duration, just reset hidden timestamp
        this.hiddenAt = null
        this.lastActivityAt = now
      }
    }
  }

  handleConnectionStatus(event) {
    const { status } = event.detail
    
    this.log("📡 Connection status changed", { status })
    
    // If connection is reloading, that means ActionCable gave up
    // This can happen if TV was asleep for too long
    if (status === 'reloading') {
      this.log("⚠️ ActionCable triggered reload")
      // Let ActionCable handle the reload (already in progress)
    }
  }

  checkHeartbeat() {
    const now = Date.now()
    const timeSinceActivity = now - this.lastActivityAt
    
    // If no activity for longer than threshold and page is visible, something is wrong
    if (!document.hidden && timeSinceActivity > this.sleepThresholdValue) {
      this.log("💔 Heartbeat failed - no activity for too long", {
        timeSinceActivity: `${Math.round(timeSinceActivity / 1000)}s`
      })
      
      // Force reload
      this.log("🔄 Forcing reload due to heartbeat failure")
      window.location.reload()
    } else {
      // Update activity timestamp (we're still alive)
      this.lastActivityAt = now
    }
  }

  showReloadMessage() {
    // Create a simple overlay message (optional)
    const overlay = document.createElement('div')
    overlay.style.cssText = `
      position: fixed;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: rgba(0, 0, 0, 0.9);
      color: white;
      padding: 2rem 3rem;
      border-radius: 1rem;
      font-size: 2rem;
      z-index: 9999;
      text-align: center;
    `
    overlay.textContent = 'Aktualisiere Anzeige...'
    document.body.appendChild(overlay)
  }

  log(message, data = null) {
    if (this.debugValue) {
      if (data) {
        console.log(`[TableScoresMonitor] ${message}`, data)
      } else {
        console.log(`[TableScoresMonitor] ${message}`)
      }
    }
  }
}
