import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["nav", "submenu", "icon", "content", "showButton"]

  connect() {
    console.log("Connecting sidebar controller")
    // Get saved state from localStorage, default to expanded on desktop
    const isSidebarCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    const isMobile = window.innerWidth < 768

    if (isMobile || isSidebarCollapsed || this.element.classList.contains('no-navbar')) {
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
    if (!this.element.classList.contains('no-navbar')) {
      submenu.classList.toggle('hidden')
      event.currentTarget.querySelector('svg').classList.toggle('rotate-180')
    }
  }

  collapse(event, saveState = true) {
    if (!this.element.classList.contains('no-navbar')) {
      console.log("Collapse triggered")
      // Toggle sidebar visibility
      this.navTarget.classList.toggle('-translate-x-full')

      // Toggle hamburger button visibility
      if (this.hasShowButtonTarget) {  // Add safety check
        this.showButtonTarget.classList.toggle('opacity-0')
        this.showButtonTarget.classList.toggle('pointer-events-none')
      }

      // Adjust main content margin
      if (this.hasContentTarget) {
        this.contentTarget.classList.toggle('ml-64')
        this.contentTarget.classList.toggle('ml-0')
      }

      // Save state to localStorage if requested
      if (saveState) {
        const isCollapsed = this.navTarget.classList.contains('-translate-x-full')
        localStorage.setItem('sidebarCollapsed', isCollapsed.toString())
      }
    }
  }

  emptyState() {
    return `
      <div class="text-center py-8 px-4">
        <svg class="mx-auto h-12 w-12 text-gray-400" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 0 0 2.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 0 0-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75 2.25 2.25 0 0 0-.1-.664m-5.8 0A2.251 2.251 0 0 1 13.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V19.5a2.25 2.25 0 0 0 2.25 2.25h.75m0-3.75h3.75" />
        </svg>
        <h3 class="mt-2 text-sm font-medium text-gray-900">No items found</h3>
        <p class="mt-1 text-sm text-gray-500">Get started by creating a new item.</p>
      </div>
    `
  }
}
