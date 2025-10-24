import { Controller } from "@hotwired/stimulus"

// AI-powered search controller
// Handles natural language search queries via OpenAI
export default class extends Controller {
  static targets = ["panel", "input", "submitButton", "loading", "message"]

  connect() {
    // Initialize CSRF token for POST requests
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    
    // Restore last query from localStorage
    this.restoreLastQuery()
    
    // Check if panel should be open (after navigation from search)
    this.checkPanelState()
  }

  // Toggle search panel visibility
  toggle(event) {
    event.preventDefault()
    this.panelTarget.classList.toggle("hidden")
    
    // Focus input when opening
    if (!this.panelTarget.classList.contains("hidden")) {
      this.inputTarget.focus()
      // Select text for easy editing
      this.inputTarget.select()
    }
  }

  // Handle search form submission
  async search(event) {
    event.preventDefault()
    
    const query = this.inputTarget.value.trim()
    if (!query) {
      this.showMessage("Bitte geben Sie eine Suchanfrage ein.", "error")
      return
    }

    // Show loading state
    this.showLoading()
    
    try {
      const response = await fetch("/api/ai_search", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ query })
      })

      const data = await response.json()

      if (data.success && data.path) {
        console.log('✅ AI Search successful:', data)
        
        // Save query to localStorage for reference
        this.saveLastQuery(query)
        
        // Prepare success message
        const successMessage = `✓ "${query}"<br>${data.explanation} (${data.confidence}% Sicherheit)`
        
        // Save message for display after navigation
        try {
          localStorage.setItem('carambus_ai_last_message', successMessage)
          console.log('💾 Saved success message')
        } catch (e) {
          console.error('❌ Could not save message:', e)
        }
        
        // Mark that panel should stay open after navigation
        console.log('📍 About to call setPanelShouldBeOpen()')
        this.setPanelShouldBeOpen()
        
        // Show success message with query and explanation
        this.showMessage(successMessage, "success")
        
        console.log('🚀 Will navigate to:', data.path, 'in 1 second')
        
        // Keep panel open and navigate after delay
        setTimeout(() => {
          console.log('⏰ Navigation timeout fired, navigating now...')
          window.location.href = data.path
        }, 1000)
      } else {
        // Show error message
        this.showMessage(
          data.error || "Die KI konnte Ihre Anfrage nicht verstehen. Bitte versuchen Sie es anders zu formulieren.",
          "error"
        )
      }
    } catch (error) {
      console.error("AI Search error:", error)
      this.showMessage(
        "Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.",
        "error"
      )
    } finally {
      this.hideLoading()
    }
  }

  // Clear input and messages
  clear(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.hideMessage()
    this.inputTarget.focus()
  }

  // Show loading indicator
  showLoading() {
    this.submitButtonTarget.disabled = true
    this.loadingTarget.classList.remove("hidden")
    this.hideMessage()
  }

  // Hide loading indicator
  hideLoading() {
    this.submitButtonTarget.disabled = false
    this.loadingTarget.classList.add("hidden")
  }

  // Show message (success or error)
  showMessage(text, type) {
    // Support newlines in messages
    this.messageTarget.innerHTML = text.replace(/\n/g, '<br>')
    this.messageTarget.classList.remove("hidden", "bg-red-100", "bg-green-100", "text-red-700", "text-green-700", "dark:bg-red-900", "dark:bg-green-900", "dark:text-red-200", "dark:text-green-200")
    
    if (type === "error") {
      this.messageTarget.classList.add("bg-red-100", "text-red-700", "dark:bg-red-900", "dark:text-red-200")
    } else {
      this.messageTarget.classList.add("bg-green-100", "text-green-700", "dark:bg-green-900", "dark:text-green-200")
    }
  }

  // Hide message
  hideMessage() {
    if (this.hasMessageTarget) {
      this.messageTarget.classList.add("hidden")
    }
  }

  // Handle Enter key in textarea (submit form)
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.search(event)
    }
  }

  // Save query to localStorage
  saveLastQuery(query) {
    try {
      localStorage.setItem('carambus_last_ai_query', query)
      localStorage.setItem('carambus_last_ai_query_time', Date.now())
    } catch (e) {
      // Ignore localStorage errors
      console.warn('Could not save query to localStorage:', e)
    }
  }

  // Restore last query from localStorage
  restoreLastQuery() {
    try {
      const lastQuery = localStorage.getItem('carambus_last_ai_query')
      const lastTime = localStorage.getItem('carambus_last_ai_query_time')
      
      // Only restore if query is less than 1 hour old
      if (lastQuery && lastTime) {
        const ageMinutes = (Date.now() - parseInt(lastTime)) / 1000 / 60
        if (ageMinutes < 60) {
          this.inputTarget.value = lastQuery
        }
      }
    } catch (e) {
      // Ignore localStorage errors
      console.warn('Could not restore query from localStorage:', e)
    }
  }

  // Mark that panel should be open after navigation
  setPanelShouldBeOpen() {
    try {
      console.log('💾 Setting panel open flag')
      localStorage.setItem('carambus_ai_panel_open', 'true')
      localStorage.setItem('carambus_ai_panel_open_time', Date.now().toString())
      
      // Verify it was saved
      const saved = localStorage.getItem('carambus_ai_panel_open')
      console.log('✓ Panel flag saved:', saved)
    } catch (e) {
      console.error('❌ Could not save panel state:', e)
    }
  }

  // Check if panel should be open and open it
  checkPanelState() {
    // Use setTimeout to ensure DOM is fully loaded
    setTimeout(() => {
      try {
        const shouldBeOpen = localStorage.getItem('carambus_ai_panel_open')
        const openTime = localStorage.getItem('carambus_ai_panel_open_time')
        
        console.log('🔍 Checking panel state:', { shouldBeOpen, openTime })
        
        if (shouldBeOpen === 'true' && openTime) {
          // Only open if navigation happened within last 10 seconds
          const ageSeconds = (Date.now() - parseInt(openTime)) / 1000
          console.log('⏱️ Panel open age:', ageSeconds, 'seconds')
          
          if (ageSeconds < 10) {
            console.log('✅ Opening panel')
            // Open panel
            this.panelTarget.classList.remove('hidden')
            // Also show last success message if available
            const lastMessage = localStorage.getItem('carambus_ai_last_message')
            if (lastMessage && this.hasMessageTarget) {
              this.messageTarget.innerHTML = lastMessage
              this.messageTarget.classList.remove('hidden')
              this.messageTarget.classList.add('bg-green-100', 'text-green-700', 'dark:bg-green-900', 'dark:text-green-200')
            }
            // Clear the flags
            localStorage.removeItem('carambus_ai_panel_open')
            localStorage.removeItem('carambus_ai_panel_open_time')
          } else {
            console.log('⏰ Panel open time expired')
          }
        } else {
          console.log('❌ No panel open flag found')
        }
      } catch (e) {
        console.error('Could not check panel state:', e)
      }
    }, 100)
  }
}

