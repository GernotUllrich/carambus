import { Controller } from "@hotwired/stimulus"

// AI-powered search controller
// Handles natural language search queries via OpenAI
export default class extends Controller {
  static targets = ["panel", "backdrop", "input", "submitButton", "loading", "message", 
                    "searchTab", "docsTab", "label", "searchExamples", "docsExamples"]
  static values = {
    answerLabel: String,
    docsLabel: String,
    confidenceLabel: String,
    errorGeneric: String,
    errorNoDocs: String
  }

  connect() {
    // Initialize CSRF token for POST requests
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    
    // Get current locale from HTML lang attribute
    this.locale = document.documentElement.lang || 'de'
    
    // Initialize mode (default: search)
    this.mode = 'search'
    
    // Restore last query from localStorage
    this.restoreLastQuery()
    
    // Check if panel should be open (after navigation from search)
    this.checkPanelState()
    
    // Listen for ESC key globally
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.escapeHandler)
    
    // Listen for custom event from button in navbar
    this.toggleHandler = this.toggle.bind(this)
    window.addEventListener('ai-search:toggle', this.toggleHandler)
    
    console.log('✅ AI Search Controller connected')
  }

  // Toggle search panel visibility
  toggle(event) {
    if (event && event.preventDefault) {
      event.preventDefault()
    }
    
    const isHidden = this.panelTarget.classList.contains("hidden")
    
    console.log('🔄 Toggle called, panel hidden:', isHidden)
    
    if (isHidden) {
      // Open panel
      this.open()
    } else {
      // Close panel
      this.close()
    }
  }
  
  // Open panel
  open() {
    this.panelTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    
    // Focus and select input
    setTimeout(() => {
      this.inputTarget.focus()
      this.inputTarget.select()
    }, 100)
    
    // Prevent body scroll when panel is open
    document.body.style.overflow = 'hidden'
  }
  
  // Close panel
  close(event) {
    if (event) event.preventDefault()
    
    this.panelTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    
    // Restore body scroll
    document.body.style.overflow = ''
  }

  // Set search mode (search or docs)
  setMode(event) {
    const mode = event.currentTarget.dataset.mode
    this.mode = mode
    
    console.log('🔄 Switching to mode:', mode)
    
    // Update tab styling
    if (mode === 'search') {
      this.searchTabTarget.classList.remove('bg-gray-200', 'dark:bg-gray-600', 'text-gray-700', 'dark:text-gray-200')
      this.searchTabTarget.classList.add('bg-blue-600', 'text-white')
      this.docsTabTarget.classList.add('bg-gray-200', 'dark:bg-gray-600', 'text-gray-700', 'dark:text-gray-200')
      this.docsTabTarget.classList.remove('bg-purple-600', 'text-white')
      
      // Update label and placeholder from data attributes (i18n)
      this.labelTarget.textContent = this.labelTarget.dataset.searchText
      this.inputTarget.placeholder = this.inputTarget.dataset.searchPlaceholder
      this.searchExamplesTarget.classList.remove('hidden')
      this.docsExamplesTarget.classList.add('hidden')
    } else {
      this.docsTabTarget.classList.remove('bg-gray-200', 'dark:bg-gray-600', 'text-gray-700', 'dark:text-gray-200')
      this.docsTabTarget.classList.add('bg-purple-600', 'text-white')
      this.searchTabTarget.classList.add('bg-gray-200', 'dark:bg-gray-600', 'text-gray-700', 'dark:text-gray-200')
      this.searchTabTarget.classList.remove('bg-blue-600', 'text-white')
      
      // Update label and placeholder from data attributes (i18n)
      this.labelTarget.textContent = this.labelTarget.dataset.docsText
      this.inputTarget.placeholder = this.inputTarget.dataset.docsPlaceholder
      this.docsExamplesTarget.classList.remove('hidden')
      this.searchExamplesTarget.classList.add('hidden')
    }
    
    // Clear messages
    this.hideMessage()
  }

  // Handle search form submission
  async search(event) {
    event.preventDefault()
    
    const query = this.inputTarget.value.trim()
    if (!query) {
      this.showMessage(
        this.mode === 'docs' 
          ? "Bitte stellen Sie eine Frage." 
          : "Bitte geben Sie eine Suchanfrage ein.", 
        "error"
      )
      return
    }

    // Show loading state
    this.showLoading()
    
    try {
      // Different endpoint based on mode
      const endpoint = this.mode === 'docs' ? '/api/ai_docs' : '/api/ai_search'
      
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken,
          "Accept": "application/json"
        },
        body: JSON.stringify({ query, locale: this.locale })
      })

      const data = await response.json()

      if (this.mode === 'docs') {
        this.handleDocsResponse(data, query)
      } else {
        this.handleSearchResponse(data, query)
      }
    } catch (error) {
      console.error("AI error:", error)
      this.showMessage(
        this.errorGenericValue || "An error occurred. Please try again.",
        "error"
      )
    } finally {
      this.hideLoading()
    }
  }

  // Handle documentation search response
  handleDocsResponse(data, query) {
    if (data.success) {
      console.log('✅ AI Docs successful:', data)
      
      // Save query
      this.saveLastQuery(query)
      
      // Show formatted documentation answer
      this.showDocsResult(data)
    } else {
      this.showMessage(
        data.error || this.errorNoDocsValue || "No answer found in documentation.",
        "error"
      )
    }
  }

  // Handle data search response
  handleSearchResponse(data, query) {
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
  }

  // Show documentation search results
  showDocsResult(data) {
    let html = '<div class="text-sm space-y-3">'
    
    // AI Answer (use localized label)
    const answerLabel = this.answerLabelValue || "💡 Answer:"
    html += `<div class="bg-blue-50 dark:bg-blue-900/20 p-3 rounded-md">`
    html += `<div class="font-medium text-blue-900 dark:text-blue-200 mb-2">${answerLabel}</div>`
    html += `<div class="text-gray-700 dark:text-gray-300">${this.escapeHtml(data.answer)}</div>`
    html += `</div>`
    
    // Documentation Links (use localized label)
    if (data.docs_links && data.docs_links.length > 0) {
      const docsLabel = this.docsLabelValue || "📚 Relevant Documentation:"
      html += `<div class="border-t border-gray-200 dark:border-gray-600 pt-3">`
      html += `<div class="font-medium text-gray-700 dark:text-gray-300 mb-2">${docsLabel}</div>`
      html += `<ul class="space-y-1">`
      data.docs_links.forEach(link => {
        html += `<li><a href="${link.url}" target="_blank" class="text-blue-600 dark:text-blue-400 hover:underline">→ ${this.escapeHtml(link.title)}</a></li>`
      })
      html += `</ul></div>`
    }
    
    // Confidence indicator (use localized label)
    if (data.confidence) {
      const confidenceLabel = this.confidenceLabelValue || "Relevance:"
      const confidenceColor = data.confidence >= 80 ? 'green' : data.confidence >= 60 ? 'yellow' : 'red'
      html += `<div class="text-xs text-gray-500 dark:text-gray-400 mt-2">`
      html += `${confidenceLabel} ${data.confidence}%`
      html += `</div>`
    }
    
    html += '</div>'
    
    this.messageTarget.innerHTML = html
    this.messageTarget.classList.remove('hidden', 'bg-red-100', 'bg-green-100', 'text-red-700', 'text-green-700')
    this.messageTarget.classList.add('bg-white', 'dark:bg-gray-800')
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
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
            // Open panel using new open() method
            this.open()
            
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
  
  // Handle ESC key to close panel
  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
  
  disconnect() {
    // Cleanup: restore body scroll on disconnect
    document.body.style.overflow = ''
    
    // Remove ESC key listener
    if (this.escapeHandler) {
      document.removeEventListener('keydown', this.escapeHandler)
    }
    
    // Remove custom event listener
    if (this.toggleHandler) {
      window.removeEventListener('ai-search:toggle', this.toggleHandler)
    }
  }
}

