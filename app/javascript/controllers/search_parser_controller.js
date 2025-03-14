import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  
  connect() {
    if (this.hasFieldTargets) {
      this.parseInitialSearch()
    }
  }
  
  parseInitialSearch() {
    const searchInput = this.element.value
    if (!searchInput) return
    
    // Parse the search string
    const components = {}
    const regex = /(\w+):(\S+)|(\S+)/g
    let match
    
    while ((match = regex.exec(searchInput)) !== null) {
      const [, field, value, plainText] = match
      if (field && value) {
        // Handle field:value pairs
        const fieldInput = this.fieldTargets.find(target => 
          target.dataset.fieldName === field.toLowerCase()
        )
        if (fieldInput) {
          fieldInput.value = value
        }
      } else if (plainText) {
        // Handle plain text search
        const generalInput = this.fieldTargets.find(target => 
          target.dataset.fieldName === 'general'
        )
        if (generalInput) {
          generalInput.value = plainText
        }
      }
    }
  }
  
  parseInput(event) {
    // Handle real-time parsing if needed
    // This could be used to update the filter fields as the user types
  }
} 