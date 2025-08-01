import ApplicationController from './application_controller'

export default class extends ApplicationController {
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
    
    // Load recent selections
    this.loadRecentSelections()
  }

  disconnect() {
    console.log("FilterPopupController disconnected")
    document.removeEventListener('click', this.handleClickOutside.bind(this))
  }

  toggle() {
    console.log("Toggle method called")
    this.popupTarget.classList.toggle('hidden')
    if (!this.popupTarget.classList.contains('hidden')) {
      this.loadRecentSelections()
    }
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
        
        // Check if this is a reference field that should use ID-based filtering
        const isReferenceField = ['region_shortname', 'club_shortname'].includes(name)
        
        if (isReferenceField) {
          // For reference fields, use the selected option's data-id if available
          const selectElement = this.filterFormTarget.querySelector(`[name="${name}"]`)
          if (selectElement) {
            const selectedOption = selectElement.options[selectElement.selectedIndex]
            const dataId = selectedOption.dataset.id || selectedOption.value
            
            if (dataId && dataId !== '') {
              // Use ID-based field name for reference fields
              const idFieldName = name === 'region_shortname' ? 'region_id' : 'club_id'
              if (operator && operator !== 'contains') {
                searchParts.push(`${idFieldName}:${operator}${dataId}`)
              } else {
                searchParts.push(`${idFieldName}:${dataId}`)
              }
            }
          }
        } else {
          // For non-reference fields, use the original logic
          if (operator && operator !== 'contains') {
            searchParts.push(`${name}:${operator}${value}`)
          } else {
            searchParts.push(`${name}:${value}`)
          }
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

  // Recent selections functionality
  saveRecentSelection(event) {
    const fieldKey = event.target.dataset.fieldKey
    const value = event.target.value
    
    if (value && fieldKey) {
      this.addToRecentSelections(fieldKey, value)
    }
  }

  addToRecentSelections(fieldKey, value) {
    const storageKey = `filter_recent_${fieldKey}`
    let recent = JSON.parse(localStorage.getItem(storageKey) || '[]')
    
    // Remove if already exists
    recent = recent.filter(item => item !== value)
    
    // Add to beginning
    recent.unshift(value)
    
    // Keep only last 5
    recent = recent.slice(0, 5)
    
    localStorage.setItem(storageKey, JSON.stringify(recent))
  }

  loadRecentSelections() {
    const fieldElements = this.element.querySelectorAll('[data-field-key]')
    
    fieldElements.forEach(fieldElement => {
      const fieldKey = fieldElement.dataset.fieldKey
      const recentContainer = fieldElement.querySelector('.recent-selections')
      
      if (recentContainer) {
        const storageKey = `filter_recent_${fieldKey}`
        const recent = JSON.parse(localStorage.getItem(storageKey) || '[]')
        
        if (recent.length > 0) {
          const recentList = recentContainer.querySelector('.flex')
          recentList.innerHTML = ''
          
          recent.forEach(value => {
            const chip = document.createElement('span')
            chip.className = 'inline-flex items-center px-2 py-1 rounded-full text-xs bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200 cursor-pointer hover:bg-blue-200 dark:hover:bg-blue-800'
            chip.textContent = value
            chip.dataset.value = value
            chip.dataset.fieldKey = fieldKey
            chip.addEventListener('click', (e) => this.selectRecentValue(e))
            recentList.appendChild(chip)
          })
          
          recentContainer.style.display = 'block'
        } else {
          recentContainer.style.display = 'none'
        }
      }
    })
  }

  selectRecentValue(event) {
    const value = event.target.dataset.value
    const fieldKey = event.target.dataset.fieldKey
    
    // Find the input field for this field key
    const input = this.element.querySelector(`[name="${fieldKey}"]`)
    if (input) {
      input.value = value
      input.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  // Autocomplete functionality
  async handleAutocomplete(event) {
    const input = event.target
    const endpoint = input.dataset.endpoint
    const query = input.value
    
    if (!endpoint || query.length < 2) return
    
    try {
      const response = await fetch(`${endpoint}?q=${encodeURIComponent(query)}`)
      const data = await response.json()
      
      // Create or update autocomplete dropdown
      this.showAutocompleteDropdown(input, data)
    } catch (error) {
      console.error('Autocomplete error:', error)
    }
  }

  showAutocompleteDropdown(input, suggestions) {
    // Remove existing dropdown
    const existingDropdown = this.element.querySelector('.autocomplete-dropdown')
    if (existingDropdown) {
      existingDropdown.remove()
    }
    
    if (suggestions.length === 0) return
    
    // Create dropdown
    const dropdown = document.createElement('div')
    dropdown.className = 'autocomplete-dropdown absolute z-50 w-full bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-md shadow-lg max-h-48 overflow-y-auto'
    
    suggestions.forEach(suggestion => {
      const item = document.createElement('div')
      item.className = 'px-3 py-2 hover:bg-gray-100 dark:hover:bg-gray-700 cursor-pointer'
      item.textContent = suggestion.label || suggestion
      item.addEventListener('click', () => {
        input.value = suggestion.value || suggestion
        input.dispatchEvent(new Event('change', { bubbles: true }))
        dropdown.remove()
      })
      dropdown.appendChild(item)
    })
    
    // Position dropdown
    const rect = input.getBoundingClientRect()
    dropdown.style.top = `${rect.bottom}px`
    dropdown.style.left = `${rect.left}px`
    dropdown.style.width = `${rect.width}px`
    
    input.parentNode.appendChild(dropdown)
    
    // Close dropdown when clicking outside
    document.addEventListener('click', (e) => {
      if (!dropdown.contains(e.target) && !input.contains(e.target)) {
        dropdown.remove()
      }
    }, { once: true })
  }
}
