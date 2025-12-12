import ApplicationController from './application_controller'

export default class extends ApplicationController {
  connect () {
    super.connect()
    console.log('✅ PartyMonitor controller connected to element:', this.element)
  }
  
  beforeResetPartyMonitor(element, reflex, noop, reflexId) {
    console.log('🔴 Before reset_party_monitor reflex', element, reflex)
  }
  
  resetPartyMonitorSuccess(element, reflex, noop, reflexId) {
    console.log('✅ reset_party_monitor succeeded')
  }
  
  resetPartyMonitorError(element, reflex, error, reflexId) {
    console.error('❌ reset_party_monitor failed:', error)
  }
}

