import ApplicationController from './application_controller'

export default class extends ApplicationController {
  static targets = ["popup", "searchInput", "filterForm"]

  connect() {
    console.log("🔧 FilterPopupController connected - DEBUG VERSION")
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
    console.log("🎯 Toggle method called - DEBUG")
    const wasHidden = this.popupTarget.classList.contains('hidden')
    this.popupTarget.classList.toggle('hidden')
    
    if (!this.popupTarget.classList.contains('hidden')) {
      console.log("🎯 Popup is now visible, loading recent selections...")
      this.loadRecentSelections()
      console.log("🎯 About to call restoreCurrentSearchState...")
      this.restoreCurrentSearchState()
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
    console.log('Debug: All form fields:')
    for (const [name, value] of formData.entries()) {
      console.log(`  ${name} = ${value}`)
    }
    console.log('Debug: Processing fields with values:')
    for (const [name, value] of formData.entries()) {
      console.log(`Debug: Processing form field: ${name} = ${value}`)
      if (name !== 'global' && !name.endsWith('_operator') && value) {
        const operator = formData.get(`${name}_operator`) || ''
        
        // Check if this is a reference field that should use ID-based filtering
        const isReferenceField = ['region_shortname', 'season_name', 'club_shortname', 'league_shortname', 'party_shortname'].includes(name)
        console.log(`Debug: Field ${name}, isReferenceField: ${isReferenceField}`)
        
        if (isReferenceField) {
          // For reference fields, use the selected option's data-id if available
          const selectElement = this.filterFormTarget.querySelector(`[name="${name}"]`)
          console.log(`Debug: Found select element for ${name}:`, selectElement)
          if (selectElement) {
            const selectedOption = selectElement.options[selectElement.selectedIndex]
            const dataId = selectedOption.dataset.id || selectedOption.value
            
            console.log(`Debug: Field ${name}, selected value: ${selectedOption.value}, data-id: ${dataId}`)
            
            if (dataId && dataId !== '') {
              // Use ID-based field name for reference fields
              let idFieldName
              if (name === 'region_shortname') {
                idFieldName = 'region_id'
              } else if (name === 'club_shortname') {
                idFieldName = 'club_id'
                                        } else if (name === 'season_name') {
                idFieldName = 'season_id'
            } else if (name === 'league_shortname') {
              idFieldName = 'league_id'
            } else if (name === 'party_shortname') {
              idFieldName = 'party_id'
            } else {
              idFieldName = name
            }
              const searchPart = `${idFieldName}:${dataId}`
              console.log(`Debug: Adding search part: ${searchPart}`)
              searchParts.push(searchPart)
            } else {
              console.log(`Debug: No data-id found for ${name}, falling back to text search`)
              // Fall back to text-based search if no data-id
              if (operator && operator !== 'contains') {
                searchParts.push(`${name}:${operator}${value}`)
              } else {
                searchParts.push(`${name}:${value}`)
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

    // Update the URL first
    window.history.replaceState({}, '', url.toString())

    // Wait a moment for URL update to complete, then trigger the search reflex
    setTimeout(() => {
      // Create a new event with the search string
      const event = new Event('input', {
        bubbles: true,
        cancelable: true
      })
      
      // Then trigger the search reflex
      this.searchInputTarget.dispatchEvent(event)
    }, 100)
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

  restoreCurrentSearchState() {
    console.log('🔍 restoreCurrentSearchState method called')
    
    // Get current search from URL or search input
    const currentSearch = this.searchInputTarget.value || this.getSearchFromURL()
    console.log('Current search input value:', currentSearch)
    
    if (!currentSearch || currentSearch.trim() === '') {
      console.log('No current search, returning early')
      return
    }
    
    console.log('Restoring search state from:', currentSearch)
    
    // Parse the search string to extract region_id, season_id, club_id, league_id, party_id
    const searchParts = currentSearch.split(' ')
    let regionId = null
    let seasonId = null
    let clubId = null
    let leagueId = null
    let partyId = null
    
    searchParts.forEach(part => {
      if (part.startsWith('region_id:')) {
        regionId = part.split(':')[1]
      } else if (part.startsWith('season_id:')) {
        seasonId = part.split(':')[1]
      } else if (part.startsWith('club_id:')) {
        clubId = part.split(':')[1]
      } else if (part.startsWith('league_id:')) {
        leagueId = part.split(':')[1]
      } else if (part.startsWith('party_id:')) {
        partyId = part.split(':')[1]
      }
    })
    
    console.log('Found regionId:', regionId, 'seasonId:', seasonId, 'clubId:', clubId, 'leagueId:', leagueId, 'partyId:', partyId)
    
    if (regionId) {
      console.log('Found region select, temporarily disabling StimulusReflex')
      
      // Temporarily remove StimulusReflex attributes to prevent interference
      const regionSelect = this.filterFormTarget.querySelector('select[name="region_shortname"]')
      if (regionSelect) {
        regionSelect.removeAttribute('data-reflex')
        regionSelect.removeAttribute('data-action')
      }
      
      // Restore region selection
      this.restoreSelectValue('region_shortname', regionId, 'region_id')
      
      // Re-enable StimulusReflex and trigger club update
      setTimeout(() => {
        if (regionSelect) {
          // Determine the correct reflex name based on current page
          const currentPath = window.location.pathname
          let reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_players'
          
                                if (currentPath.includes('/party_games')) {
            reflexName = 'change->FilterPopupReflex#filter_seasons_by_region_for_party_games'
          } else if (currentPath.includes('/locations')) {
              reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_locations'
            } else if (currentPath.includes('/clubs')) {
              reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_clubs'
            }
          
          regionSelect.setAttribute('data-reflex', reflexName)
          regionSelect.setAttribute('data-action', 'change->filter-popup#saveRecentSelection change->stimulus-reflex#__perform')
          regionSelect.dispatchEvent(new Event('change', { bubbles: true }))
        }
        
        // Restore club selection after a delay to allow club dropdown to update
        setTimeout(() => {
          if (clubId) {
            console.log('Restoring club selection')
            this.restoreSelectValue('club_shortname', clubId, 'club_id')
          }
          
          // For PartyGame, restore season, league and party selections with proper cascading
          if (seasonId) {
            console.log('Restoring season selection')
            this.restoreSelectValue('season_name', seasonId, 'season_id')
            
            // Wait for season to trigger league update, then restore league
            setTimeout(() => {
              if (leagueId) {
                console.log('Restoring league selection')
                this.restoreSelectValue('league_shortname', leagueId, 'league_id')
                
                // Wait for league to trigger party update, then restore party
                setTimeout(() => {
                  if (partyId) {
                    console.log('Restoring party selection')
                    this.restoreSelectValue('party_shortname', partyId, 'party_id')
                  }
                }, 300)
              }
            }, 300)
          }
        }, 300)
      }, 100)
    } else if (clubId) {
      // If only club_id is present (no region), restore club directly
      this.restoreSelectValue('club_shortname', clubId, 'club_id')
    }
  }

  restoreSelectValue(selectName, targetId, idFieldName) {
    console.log(`Looking for select element: [name="${selectName}"]`)
    console.log(`Looking for id field: [name="${idFieldName}"]`)
    
    const selectElement = this.filterFormTarget.querySelector(`[name="${selectName}"]`)
    const idField = this.filterFormTarget.querySelector(`[name="${idFieldName}"]`)
    
    console.log('Found select element:', selectElement)
    console.log('Found id field:', idField)
    
    if (!selectElement) {
      console.error(`❌ Could not find select element for ${selectName} or id field for ${idFieldName}`)
      
      // Debug: List all form elements
      const allElements = this.filterFormTarget.querySelectorAll('*')
      console.log('All form elements:', allElements.length)
      allElements.forEach((el, index) => {
        if (el.name) {
          console.log(`Element ${index}: name="${el.name}", tag="${el.tagName}"`)
        }
      })
      
      // Debug: List all select elements
      const allSelects = this.filterFormTarget.querySelectorAll('select')
      console.log('All select elements:', allSelects.length)
      allSelects.forEach((select, index) => {
        console.log(`Select ${index}: name="${select.name}", id="${select.id}"`)
      })
      return
    }
    
    // Find the option with matching data-id
    console.log(`Attempting to restore ${selectName} with data-id: ${targetId}`)
    console.log('Available options:', selectElement.options.length)
    
    for (let i = 0; i < selectElement.options.length; i++) {
      const option = selectElement.options[i]
      const dataId = option.dataset.id || option.value
      console.log(`Option ${i}: value="${option.value}", data-id="${dataId}"`)
      
      if (dataId == targetId) {
        console.log(`✅ Found matching option for ${selectName}: ${option.value}`)
        selectElement.selectedIndex = i
        selectElement.dispatchEvent(new Event('change', { bubbles: true }))
        return
      }
    }
    
    console.log(`❌ No matching option found for ${selectName} with data-id: ${targetId}`)
  }

  getSearchFromURL() {
    const urlParams = new URLSearchParams(window.location.search)
    return urlParams.get('sSearch') || ''
  }
}
