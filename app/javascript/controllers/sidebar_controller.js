import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "submenu", "icon", "content", "showButton"]

  connect() {
    console.log("Connecting sidebar controller")
    // Get saved state from localStorage, default to expanded on desktop
    const isSidebarCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    const isMobile = window.innerWidth < 768

    if (isMobile || isSidebarCollapsed) {
      this.collapse(null, false) // Collapse without saving state
    } else {
      // Ensure correct margin on desktop initial load
      if (this.hasContentTarget) {
        this.contentTarget.classList.add('ml-64')
        this.contentTarget.classList.remove('ml-0')
      }
    }
  }

  toggle(event) {
    const submenu = event.currentTarget.nextElementSibling
    submenu.classList.toggle('hidden')
    event.currentTarget.querySelector('svg').classList.toggle('rotate-180')
  }

  collapse(event, saveState = true) {
    console.log("Collapse triggered")
    // Toggle sidebar visibility
    this.navTarget.classList.toggle('-translate-x-full')

    // Toggle hamburger button visibility
    this.showButtonTarget.classList.toggle('opacity-0')
    this.showButtonTarget.classList.toggle('pointer-events-none')

    // Adjust main content margin
    if (this.hasContentTarget) {
      if (this.navTarget.classList.contains('-translate-x-full')) {
        // Sidebar is hidden
        this.contentTarget.classList.remove('ml-64')
        this.contentTarget.classList.add('ml-0')
      } else {
        // Sidebar is visible
        this.contentTarget.classList.add('ml-64')
        this.contentTarget.classList.remove('ml-0')
      }
    }

    // Save state to localStorage if requested
    if (saveState) {
      const isCollapsed = this.navTarget.classList.contains('-translate-x-full')
      localStorage.setItem('sidebarCollapsed', isCollapsed)
    }
  }
}
