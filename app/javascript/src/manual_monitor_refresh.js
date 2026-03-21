// Manual Monitor Refresh
// Provides admin function to manually trigger monitor refresh
// This replaces the automatic health checks to reduce log spam

// Global function that can be called from browser console
window.forceMonitorRefresh = function() {
  console.log("🔄 Manual monitor refresh triggered...")
  
  // Option 1: Hard reload (clears all caches)
  const hardReload = confirm("Hard reload (clears cache)? Click Cancel for soft reload.")
  
  if (hardReload) {
    console.log("🔄 Performing HARD reload (clearing cache)...")
    window.location.reload(true)
  } else {
    console.log("🔄 Performing soft reload...")
    window.location.reload()
  }
}

// Display help message on console
console.log("📺 Monitor Admin Functions:")
console.log("  forceMonitorRefresh() - Manually refresh monitor display")
console.log("")
