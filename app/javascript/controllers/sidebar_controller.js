import { Controller } from "@hotwired/stimulus"

console.log('🔧 Sidebar Controller FILE LOADED')

export default class extends Controller {
  static targets = ["nav", "submenu", "icon", "content", "showButton"]

  connect() {
    console.log('🔧 Sidebar Controller CONNECT')
    // Apply state immediately on connect
    this.applySidebarState()
    
    // Set up Turbo listeners only once per controller instance
    if (!this.turboListenersSet) {
      console.log('🔧 Setting up Turbo listeners')
      this.boundApplySidebarState = this.applySidebarState.bind(this)
      this.boundHandleResize = this.handleResize.bind(this)
      
      document.addEventListener('turbo:before-render', this.boundApplySidebarState)
      window.addEventListener('resize', this.boundHandleResize)
      this.turboListenersSet = true
    }
  }

  disconnect() {
    console.log('🔧 Sidebar Controller DISCONNECT')
    // Clean up event listeners
    if (this.turboListenersSet) {
      document.removeEventListener('turbo:before-render', this.boundApplySidebarState)
      window.removeEventListener('resize', this.boundHandleResize)
      this.turboListenersSet = false
    }
  }

  handleResize() {
    const isMobile = window.innerWidth <= 768
    if (isMobile) {
      document.documentElement.classList.add('sidebar-collapsed')
    } else if (localStorage.getItem('sidebarCollapsed') !== 'true') {
      document.documentElement.classList.remove('sidebar-collapsed')
    }
  }

  applySidebarState() {
    // Note: For scoreboard URLs with sb_state, sidebar-collapsed is already set by server
    // For all other pages, use normal localStorage behavior
    const isMobile = window.innerWidth < 768
    const isScoreboard = document.body.dataset.userEmail === 'scoreboard@carambus.de'
    const hasSbState = window.location.search.includes('sb_state=')
    const isScoreboardUrl = document.documentElement.dataset.scoreboardUrl === 'true'
    
    console.log('🔧 Sidebar Controller applySidebarState:', {
      isScoreboard,
      hasSbState,
      isScoreboardUrl,
      url: window.location.href,
      localStorage: localStorage.getItem('sidebarCollapsed'),
      currentClasses: document.documentElement.className
    })

    // PRIORITY 1: For scoreboard URLs (checked by server), ALWAYS force collapsed
    // This takes precedence over everything else
    if (isScoreboardUrl || (isScoreboard && hasSbState)) {
      console.log('🔧 Scoreboard URL detected - forcing collapsed (HIGHEST PRIORITY)')
      // Set localStorage to 'true' so it stays collapsed on navigation
      localStorage.setItem('sidebarCollapsed', 'true')
      // ALWAYS ensure sidebar-collapsed class is present
      document.documentElement.classList.add('sidebar-collapsed')
      return // Exit early - don't run any other logic
    }
    
    // PRIORITY 2: For all other cases, use localStorage behavior
    const isSidebarCollapsed = localStorage.getItem('sidebarCollapsed') === 'true'
    console.log('🔧 Normal navigation - isSidebarCollapsed:', isSidebarCollapsed)
    if (isMobile || isSidebarCollapsed) {
      console.log('🔧 Adding sidebar-collapsed class')
      document.documentElement.classList.add('sidebar-collapsed')
    } else {
      console.log('🔧 Removing sidebar-collapsed class')
      document.documentElement.classList.remove('sidebar-collapsed')
    }
    
    console.log('🔧 Final classes:', document.documentElement.className)
  }

  toggle(event) {
    const submenu = event.currentTarget.nextElementSibling
    submenu.classList.toggle('hidden')
    event.currentTarget.querySelector('svg').classList.toggle('rotate-180')
  }

  collapse(event) {
    console.log('🔧 SidebarController collapse called!', event.currentTarget)
    // Force a reflow before making changes
    void this.navTarget.offsetHeight

    // Toggle nav with requestAnimationFrame to ensure changes are batched
    requestAnimationFrame(() => {
      // Toggle collapsed state on html element
      document.documentElement.classList.toggle('sidebar-collapsed')

      // Save state (but scoreboard users will get reset on next page load)
      const isCollapsed = document.documentElement.classList.contains('sidebar-collapsed')
      localStorage.setItem('sidebarCollapsed', isCollapsed.toString())
      console.log('🔧 Sidebar collapsed state:', isCollapsed)
      console.log('🔧 HTML classes:', document.documentElement.className)
      console.log('🔧 Nav element:', this.navTarget)
      console.log('🔧 Nav element classes:', this.navTarget.className)
      console.log('🔧 Content element:', this.hasContentTarget ? this.contentTarget : 'No content target')
    })
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
