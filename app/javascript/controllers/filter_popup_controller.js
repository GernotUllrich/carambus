import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["popup", "searchInput", "filterForm"]
  
  connect() {
    // Close popup when clicking outside
    document.addEventListener('click', this.closePopupOnClickOutside.bind(this))
  }
  
  disconnect() {
    document.removeEventListener('click', this.closePopupOnClickOutside.bind(this))
  }
  
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.popupTarget.classList.toggle('hidden')
  }
  
  close() {
    this.popupTarget.classList.add('hidden')
  }
  
  closePopupOnClickOutside(event) {
    if (this.popupTarget && !this.popupTarget.contains(event.target) && 
        !event.target.closest('[data-action*="filter-popup#toggle"]')) {
      this.close()
    }
  }
  
  applyFilters(event) {
    event.preventDefault()
    
    const formData = new FormData(this.filterFormTarget)
    const filters = []
    
    for (const [key, value] of formData.entries()) {
      if (value.trim() !== '') {
        // Handle comparison operators
        const operator = formData.get(`${key}_operator`)
        if (operator && operator !== 'contains') {
          filters.push(`${key}:${operator}${value}`)
        } else {
          filters.push(`${key}:${value}`)
        }
      }
    }
    
    // Update the search input with the generated filter string
    this.searchInputTarget.value = filters.join(' ')
    
    // Trigger the search
    const event = new Event('input', { bubbles: true })
    this.searchInputTarget.dispatchEvent(event)
    
    // Close the popup
    this.close()
  }
  
  clearFilters() {
    this.filterFormTarget.reset()
    this.searchInputTarget.value = ''
    
    // Trigger the search to clear results
    const event = new Event('input', { bubbles: true })
    this.searchInputTarget.dispatchEvent(event)
    
    this.close()
  }
} 