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
    document.addEventListener('click', this.closePopupOnClickOutside.bind(this))
  }

  disconnect() {
    console.log("FilterPopupController disconnected")
    document.removeEventListener('click', this.closePopupOnClickOutside.bind(this))
  }

  toggle(event) {
    console.log("Toggle method called", event)
    event.preventDefault()
    event.stopPropagation()
    try {
      console.log("Before toggle - popup classes:", this.popupTarget.classList.toString())
      this.popupTarget.classList.toggle('hidden')
      console.log("After toggle - popup classes:", this.popupTarget.classList.toString())
    } catch (error) {
      console.error("Error in toggle method:", error)
    }
  }

  close() {
    try {
      this.popupTarget.classList.add('hidden')
    } catch (error) {
      console.error("Error in close method:", error)
    }
  }

  closePopupOnClickOutside(event) {
    if (this.popupTarget && !this.popupTarget.contains(event.target) &&
      !event.target.closest('[data-action*="filter-popup#toggle"]')) {
      this.close()
    }
  }

  applyFilters(event) {
    event.preventDefault()
    console.log("Applying filters")

    const formData = new FormData(this.filterFormTarget)
    const filters = []
    const fieldData = {}

    // Handle global search separately
    const globalSearch = formData.get('global')
    if (globalSearch && globalSearch.trim() !== '') {
      filters.push(globalSearch.trim())
    }

    // Process field-specific filters
    for (const [key, value] of formData.entries()) {
      if (key === 'global') continue // Skip global search as it's already handled
      if (key.endsWith('_operator')) {
        const fieldName = key.replace('_operator', '')
        if (!fieldData[fieldName]) fieldData[fieldName] = {}
        fieldData[fieldName].operator = value
      } else {
        if (!fieldData[key]) fieldData[key] = {}
        fieldData[key].value = value.replace(/ /g, '%20')
      }
    }

    // Build filter strings
    for (const [key, data] of Object.entries(fieldData)) {
      if (data.value && data.value.trim() !== '') {
        if (data.operator && data.operator !== 'contains') {
          filters.push(`${key}:${data.operator}${data.value.trim()}`)
        } else {
          filters.push(`${key}:${data.value.trim()}`)
        }
      }
    }

    console.log("Generated filters:", filters)

    // Update the search input with the generated filter string
    this.searchInputTarget.value = filters.join(' ')

    // Trigger the search
    const inputEvent = new Event('input', { bubbles: true })
    this.searchInputTarget.dispatchEvent(inputEvent)

    // Close the popup
    this.close()
  }

  clearFilters() {
    console.log("Clearing filters")
    this.filterFormTarget.reset()
    this.searchInputTarget.value = ''

    // Trigger the search to clear results
    const inputEvent = new Event('input', { bubbles: true })
    this.searchInputTarget.dispatchEvent(inputEvent)

    this.close()
  }
}
