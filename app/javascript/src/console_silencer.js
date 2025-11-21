// Console Silencer for Production/Kiosk Mode
// Reduces console spam on slow devices (Raspi 3)
// Can be toggled via localStorage

const SILENT_MODE = localStorage.getItem('cable_silent_console') === 'true'

if (SILENT_MODE) {
  // Save original console methods
  const originalLog = console.log
  const originalWarn = console.warn
  const originalError = console.error

  // Whitelist: Only allow performance measurements and critical errors
  const ALLOWED_PATTERNS = [
    /^⚡/,  // Performance measurements
    /^🔌.*connected$/,  // Connection status (important)
    /^❌.*[Cc]ritical/  // Critical errors only
  ]

  function shouldLog(args) {
    const firstArg = args[0]
    if (typeof firstArg !== 'string') return false
    return ALLOWED_PATTERNS.some(pattern => pattern.test(firstArg))
  }

  // Override console methods
  console.log = function(...args) {
    if (shouldLog(args)) {
      originalLog.apply(console, args)
    }
  }

  console.warn = function(...args) {
    if (shouldLog(args)) {
      originalWarn.apply(console, args)
    }
  }

  console.error = function(...args) {
    // Always log actual JavaScript errors
    if (args[0] instanceof Error) {
      originalError.apply(console, args)
    } else if (shouldLog(args)) {
      originalError.apply(console, args)
    }
  }

  // Expose method to temporarily enable logging for debugging
  window.enableConsole = function(duration = 30000) {
    console.log = originalLog
    console.warn = originalWarn
    console.error = originalError
    originalLog('✅ Console enabled for', duration / 1000, 'seconds')
    
    setTimeout(() => {
      console.log = SILENT_MODE ? function(...args) {
        if (shouldLog(args)) originalLog.apply(console, args)
      } : originalLog
      console.warn = SILENT_MODE ? function(...args) {
        if (shouldLog(args)) originalWarn.apply(console, args)
      } : originalWarn
      console.error = SILENT_MODE ? function(...args) {
        if (args[0] instanceof Error || shouldLog(args)) originalError.apply(console, args)
      } : originalError
      originalLog('🔇 Console silenced again')
    }, duration)
  }

  originalLog('🔇 Silent console mode active. Performance measurements will still be shown.')
  originalLog('   To enable all logs: window.enableConsole() or window.enableConsole(60000)')
  originalLog('   To disable: localStorage.removeItem("cable_silent_console"); location.reload()')
}

export default SILENT_MODE

