// Version Checker - Forces reload when new JavaScript is deployed
// This ensures all browser tabs get the latest code without manual refresh

const VERSION_KEY = 'app_js_version'
const CURRENT_VERSION = '2026-03-21-15-00' // Update this on each deploy that changes JS

export function checkAndReloadIfNeeded() {
  const storedVersion = localStorage.getItem(VERSION_KEY)
  
  if (!storedVersion) {
    // First load - just store version
    localStorage.setItem(VERSION_KEY, CURRENT_VERSION)
    console.log(`📦 Version ${CURRENT_VERSION} stored (first load)`)
    return
  }
  
  if (storedVersion !== CURRENT_VERSION) {
    console.warn(`🔄 NEW VERSION DETECTED! Stored: ${storedVersion}, Current: ${CURRENT_VERSION}`)
    console.warn(`🔄 Auto-reloading to get latest JavaScript...`)
    
    // Update version BEFORE reload
    localStorage.setItem(VERSION_KEY, CURRENT_VERSION)
    
    // Force hard reload (bypass cache)
    window.location.reload(true)
  } else {
    console.log(`✅ Version ${CURRENT_VERSION} up to date`)
  }
}

// Run check immediately when module loads
checkAndReloadIfNeeded()
