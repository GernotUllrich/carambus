import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("PagyUrlController connected")
    
    // Event-Listener für StimulusReflex
    document.addEventListener("stimulus-reflex:after", this.updateUrl)
    
    // Event-Listener für Turbo-Frame-Updates
    document.addEventListener("turbo:frame-load", this.updateUrl)
    
    // Event-Listener für normale Link-Klicks in der Pagination
    this.element.addEventListener("click", this.handlePaginationClick)
    
    // Event-Listener für MutationObserver (falls DOM-Änderungen nicht erkannt werden)
    this.setupMutationObserver()
  }

  disconnect() {
    document.removeEventListener("stimulus-reflex:after", this.updateUrl)
    document.removeEventListener("turbo:frame-load", this.updateUrl)
    this.element.removeEventListener("click", this.handlePaginationClick)
    
    if (this.mutationObserver) {
      this.mutationObserver.disconnect()
    }
  }

  setupMutationObserver() {
    this.mutationObserver = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
          // Prüfe, ob Pagination-Links hinzugefügt wurden
          const hasPaginationLinks = Array.from(mutation.addedNodes).some(node => 
            node.nodeType === Node.ELEMENT_NODE && 
            (node.classList?.contains('pagy') || node.querySelector?.('nav.pagy'))
          )
          
          if (hasPaginationLinks) {
            console.log("Pagination links detected, updating URL")
            this.updateUrl()
          }
        }
      })
    })
    
    this.mutationObserver.observe(this.element, {
      childList: true,
      subtree: true
    })
  }

  handlePaginationClick = (event) => {
    console.log("Click detected:", event.target)
    
    // Prüfe, ob es ein Pagination-Link ist
    const paginationLink = event.target.closest('nav.pagy a')
    if (paginationLink) {
      console.log("Pagination link clicked:", paginationLink.href)
      const url = new URL(paginationLink.href)
      
      // Aktualisiere die URL sofort beim Klick
      console.log("Updating URL on click to:", url.toString())
      window.history.pushState({}, '', url.toString())
    }
  }

  updateUrl = (event) => {
    console.log("Updating URL after frame/reflex update")
    
    // Warte kurz, bis das DOM aktualisiert wurde
    setTimeout(() => {
      console.log("Looking for pagination elements...")
      
      // Debug: Zeige alle Pagination-Elemente
      const pagyElements = this.element.querySelectorAll('nav.pagy')
      console.log("Found pagy elements:", pagyElements.length)
      
      // Methode 1: Suche nach dem aktuellen Seiten-Element
      const currentPage = this.element.querySelector("nav.pagy .current")
      if (currentPage && currentPage.textContent) {
        const pageNumber = currentPage.textContent.trim()
        const currentUrl = new URL(window.location)
        currentUrl.searchParams.set('page', pageNumber)
        console.log("Method 1 - Updating URL to:", currentUrl.toString())
        window.history.pushState({}, '', currentUrl.toString())
        return
      }
      
      // Methode 2: Suche nach einem Link mit aria-current
      const activeLink = this.element.querySelector("nav.pagy a[aria-current='page']")
      if (activeLink) {
        console.log("Method 2 - Updating URL to:", activeLink.href)
        window.history.pushState({}, '', activeLink.href)
        return
      }
      
      // Methode 3: Suche nach dem ersten Link in der Pagination (falls nur eine Seite sichtbar ist)
      const firstLink = this.element.querySelector("nav.pagy a")
      if (firstLink) {
        const url = new URL(firstLink.href)
        // Entferne den page Parameter, um zur ersten Seite zu gehen
        url.searchParams.delete('page')
        console.log("Method 3 - Updating URL to:", url.toString())
        window.history.pushState({}, '', url.toString())
      }
      
      console.log("No pagination elements found for URL update")
    }, 100) // Kurze Verzögerung für DOM-Update
  }
} 