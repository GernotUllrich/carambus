import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="stream-destination"
export default class extends Controller {
  static targets = ["youtubeFields", "localFields", "customFields"]
  
  connect() {
    console.log("[StreamDestination] Controller connected")
    // Trigger initial state
    this.toggle()
  }
  
  toggle() {
    const select = this.element.querySelector('select[name*="stream_destination"]')
    if (!select) {
      console.warn("[StreamDestination] Select element not found")
      return
    }
    
    const destination = select.value
    console.log("[StreamDestination] Selected destination:", destination)
    
    // Hide all sections first
    if (this.hasYoutubeFieldsTarget) this.youtubeFieldsTarget.style.display = 'none'
    if (this.hasLocalFieldsTarget) this.localFieldsTarget.style.display = 'none'
    if (this.hasCustomFieldsTarget) this.customFieldsTarget.style.display = 'none'
    
    // Show the selected section
    switch(destination) {
      case 'youtube':
        if (this.hasYoutubeFieldsTarget) {
          this.youtubeFieldsTarget.style.display = 'block'
        }
        break
      case 'local':
        if (this.hasLocalFieldsTarget) {
          this.localFieldsTarget.style.display = 'block'
        }
        break
      case 'custom':
        if (this.hasCustomFieldsTarget) {
          this.customFieldsTarget.style.display = 'block'
        }
        break
    }
  }
}

