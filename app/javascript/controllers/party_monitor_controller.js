import ApplicationController from './application_controller'

export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log('✅ PartyMonitor controller connected to element:', this.element)
  }
  
  beforeResetPartyMonitor(element, reflex, noop, reflexId) {
    console.log('🔴 Before reset_party_monitor reflex', element, reflex)
    
    // Show confirm dialog
    const message = element.dataset.confirm || "Bist Du sicher das gesammte Party-Monitoring incl. aller Spielerzuordnungen und Ergebnisse zurückzusetzen? Dies kann nicht rückgängig gemacht werden!"
    const confirmed = confirm(message)
    console.log('🔴 Confirm result:', confirmed)
    
    if (!confirmed) {
      console.log('🔴 User cancelled reset - returning false to prevent reflex')
      throw "User cancelled" // Throw to prevent the reflex from executing
    }
    
    console.log('🔴 User confirmed reset - proceeding with reflex')
  }
  
  resetPartyMonitorSuccess(element, reflex, noop, reflexId) {
    console.log('✅ reset_party_monitor succeeded')
  }
  
  resetPartyMonitorError(element, reflex, error, reflexId) {
    console.error('❌ reset_party_monitor failed:', error)
  }
}

