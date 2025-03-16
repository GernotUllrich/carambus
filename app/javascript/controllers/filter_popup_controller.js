import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup", "searchInput", "filterForm"]

  connect() {
    console.log("FilterPopupController connected")
    console.log("Targets:", {
      popup: this.hasPopupTarget,
      searchInput: this.hasSearchInputTarget,
      filterForm: this.hasFilterFormTarget
    })
    if (!this.hasPopupTarget) {
      console.error("Missing popup target")
    }
    if (!this.hasSearchInputTarget) {
      console.error("Missing searchInput target")
    }
    if (!this.hasFilterFormTarget) {
      console.error("Missing filterForm target")
    }
    // Close popup when clicking outside
    document.addEventListener('click', this.handleClickOutside.bind(this))
  }

  disconnect() {
    console.log("FilterPopupController disconnected")
    document.removeEventListener('click', this.handleClickOutside.bind(this))
  }

  toggle() {
    console.log("Toggle method called")
    this.popupTarget.classList.toggle('hidden')
  }

  close() {
    try {
      this.popupTarget.classList.add('hidden')
    } catch (error) {
      console.error("Error in close method:", error)
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  clearFilters(event) {
    event.preventDefault()
    console.log("Clearing filters")
    this.filterFormTarget.reset()
    this.searchInputTarget.value = ''
    this.updateSearchAndRefresh('')
  }

  applyFilters(event) {
    event.preventDefault()
    console.log("Applying filters")

    const formData = new FormData(this.filterFormTarget)
    const searchParts = []
    
    // Handle global search
    const globalSearch = formData.get('global')
    if (globalSearch) {
      searchParts.push(globalSearch)
    }

    // Handle field-specific searches
    for (const [name, value] of formData.entries()) {
      if (name !== 'global' && !name.endsWith('_operator') && value) {
        const operator = formData.get(`${name}_operator`) || ''
        if (operator && operator !== 'contains') {
          searchParts.push(`${name}:${operator}${value}`)
        } else {
          searchParts.push(`${name}:${value}`)
        }
      }
    }

    const searchString = searchParts.join(' ')
    this.updateSearchAndRefresh(searchString)
    this.close()
  }

  updateSearchAndRefresh(searchString) {
    // Update the search input
    this.searchInputTarget.value = searchString

    // Create a new URL with current parameters
    const url = new URL(window.location.href)
    
    // Update or remove search parameter
    if (searchString) {
      url.searchParams.set('sSearch', searchString)
    } else {
      url.searchParams.delete('sSearch')
    }

    // Create a new event with the search string
    const event = new Event('input', {
      bubbles: true,
      cancelable: true
    })

    // Update the URL first
    window.history.replaceState({}, '', url.toString())

    // Then trigger the search reflex
    this.searchInputTarget.dispatchEvent(event)
  }
}
