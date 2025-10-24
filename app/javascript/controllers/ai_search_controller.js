import { Controller } from "@hotwired/stimulus"

// AI-powered search controller
// Handles natural language search queries via OpenAI
export default class extends Controller {
  static targets = ["panel", "input", "submitButton", "loading", "message"]

  connect() {
    // Initialize CSRF token for POST requests
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
  }

  // Toggle search panel visibility
  toggle(event) {
    event.preventDefault()
    this.panelTarget.classList.toggle("hidden")
    
    // Focus input when opening
    if (!this.panelTarget.classList.contains("hidden")) {
      this.inputTarget.focus()
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
        // Show success message with explanation
        this.showMessage(
          `✓ ${data.explanation} (${data.confidence}% Sicherheit)`,
          "success"
        )
        
        // Navigate to results after short delay
        setTimeout(() => {
          window.location.href = data.path
        }, 800)
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
    this.messageTarget.textContent = text
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
}

