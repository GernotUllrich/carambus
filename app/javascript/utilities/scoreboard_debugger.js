// Scoreboard Debugging Utilities
// Provides comprehensive debugging tools for scoreboard operations

class ScoreboardDebugger {
  constructor() {
    this.operationStats = {
      total: 0,
      successful: 0,
      failed: 0,
      missingElements: 0,
      urlMismatches: 0,
      errors: []
    }
    this.startTime = Date.now()
    this.domSnapshots = []
    this.reflexHistory = []
    this.enabled = true // Debug logging enabled by default
    this.snapshotInterval = null // Store interval reference

    // Bind methods to preserve context
    this.logOperation = this.logOperation.bind(this)
    this.checkDOMHealth = this.checkDOMHealth.bind(this)
    this.getStats = this.getStats.bind(this)
    this.createSnapshot = this.createSnapshot.bind(this)
    this.analyzeIssues = this.analyzeIssues.bind(this)
  }

  logOperation(type, selector, success, error = null) {
    this.operationStats.total++
    if (success) {
      this.operationStats.successful++
      if (this.enabled) console.log(`✅ CableReady ${type}: ${selector}`)
    } else {
      this.operationStats.failed++
      if (error && error.message.includes('missing DOM element')) {
        this.operationStats.missingElements++
        if (this.enabled) console.warn(`⚠️ Missing element: ${selector}`)
      } else if (error && error.message.includes('mismatched URL')) {
        this.operationStats.urlMismatches++
        if (this.enabled) console.warn(`⚠️ URL mismatch: ${selector}`)
      } else {
        if (this.enabled) console.error(`❌ CableReady ${type} failed: ${selector}`, error)
      }
      this.operationStats.errors.push({
        timestamp: new Date().toISOString(),
        type,
        selector,
        error: error?.message || 'Unknown error'
      })
    }
  }

  logReflex(method, success, error = null) {
    const reflexLog = {
      timestamp: new Date().toISOString(),
      method,
      success,
      error: error?.message || null,
      url: window.location.href
    }
    
    this.reflexHistory.push(reflexLog)
    
    // Keep only last 50 reflex calls
    if (this.reflexHistory.length > 50) {
      this.reflexHistory = this.reflexHistory.slice(-50)
    }
    
    if (success) {
      console.log(`🎯 Reflex ${method}: SUCCESS`)
    } else {
      console.error(`🎯 Reflex ${method}: FAILED`, error)
    }
  }

  checkDOMHealth() {
    const commonSelectors = [
      '#teasers',
      '[id^="teaser_"]',
      '[id^="full_screen_table_monitor_"]',
      '#table_scores',
      '[id^="party_monitor_scores_"]',
      '[id^="table_monitor_"]',
      '.table_monitor',
      '.scoreboard'
    ]
    
    const health = {}
    const issues = []
    
    commonSelectors.forEach(selector => {
      const elements = document.querySelectorAll(selector)
      const ids = Array.from(elements).map(el => el.id).filter(id => id)
      
      health[selector] = {
        count: elements.length,
        ids: ids,
        visible: Array.from(elements).filter(el => el.offsetParent !== null).length
      }
      
      // Check for common issues
      if (selector.includes('teaser_') && elements.length === 0) {
        issues.push(`No elements found for ${selector}`)
      }
      
      if (elements.length > 0 && health[selector].visible === 0) {
        issues.push(`Elements exist but are not visible for ${selector}`)
      }
    })
    
    // Check for ActionCable connection
    const cableStatus = this.checkActionCableStatus()
    health.actionCable = cableStatus
    
    // Check for StimulusReflex
    const reflexStatus = this.checkStimulusReflexStatus()
    health.stimulusReflex = reflexStatus
    
    // Debug messages removed - no more console spam
    
    return { health, issues }
  }

  checkActionCableStatus() {
    try {
      // Check if ActionCable consumer exists
      const consumer = window.App?.cable || window.Cable?.consumer
      if (!consumer) {
        return { connected: false, error: 'No ActionCable consumer found' }
      }
      
      // Check connection state
      const connection = consumer.connection
      if (!connection) {
        return { connected: false, error: 'No connection object' }
      }
      
      return {
        connected: connection.isOpen(),
        state: connection.getState(),
        url: connection.getURL()
      }
    } catch (error) {
      return { connected: false, error: error.message }
    }
  }

  checkStimulusReflexStatus() {
    try {
      // Check if StimulusReflex is available
      if (typeof window.StimulusReflex === 'undefined') {
        return { available: false, error: 'StimulusReflex not loaded' }
      }
      
      // Check reflex queue
      const queue = window.StimulusReflex.reflexQueue || []
      
      return {
        available: true,
        queueLength: queue.length,
        version: window.StimulusReflex.version || 'unknown'
      }
    } catch (error) {
      return { available: false, error: error.message }
    }
  }

  createSnapshot() {
    const snapshot = {
      timestamp: new Date().toISOString(),
      url: window.location.href,
      domHealth: this.checkDOMHealth(),
      stats: this.getStats(),
      reflexHistory: this.reflexHistory.slice(-10), // Last 10 reflexes
      userAgent: navigator.userAgent,
      viewport: {
        width: window.innerWidth,
        height: window.innerHeight
      }
    }
    
    this.domSnapshots.push(snapshot)
    
    // Keep only last 10 snapshots
    if (this.domSnapshots.length > 10) {
      this.domSnapshots = this.domSnapshots.slice(-10)
    }
    
    // Debug messages removed - no more console spam
    return snapshot
  }

  getStats() {
    const uptime = Date.now() - this.startTime
    return {
      ...this.operationStats,
      uptime: `${Math.round(uptime / 1000)}s`,
      successRate: this.operationStats.total > 0 ? 
        `${Math.round((this.operationStats.successful / this.operationStats.total) * 100)}%` : '0%',
      snapshots: this.domSnapshots.length,
      reflexCalls: this.reflexHistory.length
    }
  }

  analyzeIssues() {
    const analysis = {
      timestamp: new Date().toISOString(),
      criticalIssues: [],
      warnings: [],
      recommendations: []
    }
    
    // Analyze operation stats
    if (this.operationStats.failed > 0) {
      const failureRate = (this.operationStats.failed / this.operationStats.total) * 100
      if (failureRate > 50) {
        analysis.criticalIssues.push(`High failure rate: ${failureRate.toFixed(1)}%`)
      } else if (failureRate > 20) {
        analysis.warnings.push(`Elevated failure rate: ${failureRate.toFixed(1)}%`)
      }
    }
    
    // Analyze missing elements
    if (this.operationStats.missingElements > 0) {
      analysis.criticalIssues.push(`${this.operationStats.missingElements} missing DOM elements`)
      analysis.recommendations.push('Check if elements are created before CableReady operations')
    }
    
    // Analyze URL mismatches
    if (this.operationStats.urlMismatches > 0) {
      analysis.criticalIssues.push(`${this.operationStats.urlMismatches} URL mismatches detected`)
      analysis.recommendations.push('Ensure page navigation is handled properly in StimulusReflex')
    }
    
    // Analyze recent errors
    const recentErrors = this.operationStats.errors.slice(-5)
    if (recentErrors.length > 0) {
      analysis.warnings.push(`${recentErrors.length} recent errors`)
      analysis.recommendations.push('Check browser console for detailed error information')
    }
    
    console.log('🔍 Issue Analysis:', analysis)
    return analysis
  }

  // Generate a comprehensive debug report
  generateReport() {
    const report = {
      timestamp: new Date().toISOString(),
      url: window.location.href,
      stats: this.getStats(),
      domHealth: this.checkDOMHealth(),
      issueAnalysis: this.analyzeIssues(),
      recentSnapshots: this.domSnapshots.slice(-3),
      recentReflexes: this.reflexHistory.slice(-10)
    }
    
    console.log('📊 Comprehensive Debug Report:', report)
    
    // Copy to clipboard if possible
    if (navigator.clipboard) {
      navigator.clipboard.writeText(JSON.stringify(report, null, 2))
        .then(() => console.log('📋 Report copied to clipboard'))
        .catch(() => console.log('📋 Could not copy to clipboard'))
    }
    
    return report
  }

  // Reset all statistics
  reset() {
    this.operationStats = {
      total: 0,
      successful: 0,
      failed: 0,
      missingElements: 0,
      urlMismatches: 0,
      errors: []
    }
    this.startTime = Date.now()
    this.domSnapshots = []
    this.reflexHistory = []
    if (this.enabled) console.log('🔄 Debug statistics reset')
  }

  // Toggle debug logging
  toggle() {
    this.enabled = !this.enabled
    console.log(`🔧 Debug logging ${this.enabled ? 'enabled' : 'disabled'}`)
    return this.enabled
  }

  // Enable debug logging
  enable() {
    this.enabled = true
    // Restart the auto-snapshot interval
    if (!this.snapshotInterval) {
      this.snapshotInterval = setInterval(() => {
        if (this.enabled) {
          this.createSnapshot()
        }
      }, 30000)
    }
    console.log('🔧 Debug logging enabled')
  }

  // Disable debug logging
  disable() {
    this.enabled = false
    // Clear the auto-snapshot interval
    if (this.snapshotInterval) {
      clearInterval(this.snapshotInterval)
      this.snapshotInterval = null
    }
    console.log('🔧 Debug logging disabled')
  }
}

// Create global instance
window.scoreboardDebugger = new ScoreboardDebugger()

// Add convenience methods to window
window.debugScoreboard = () => {
  window.scoreboardDebugger.generateReport()
}

window.checkScoreboardHealth = () => {
  return window.scoreboardDebugger.checkDOMHealth()
}

window.resetScoreboardDebug = () => {
  window.scoreboardDebugger.reset()
}

window.toggleScoreboardDebug = () => {
  return window.scoreboardDebugger.toggle()
}

window.enableScoreboardDebug = () => {
  window.scoreboardDebugger.enable()
}

window.disableScoreboardDebug = () => {
  window.scoreboardDebugger.disable()
}

// Auto-snapshots disabled - no more console spam

console.log('🛠️ Scoreboard Debugger initialized. Use debugScoreboard() for full report.')


