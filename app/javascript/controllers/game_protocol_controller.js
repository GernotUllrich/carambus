import { Controller } from "@hotwired/stimulus"

/**
 * Game Protocol Modal Controller
 * 
 * Manages the game protocol modal that displays and allows editing of innings history.
 * Replaces the confusing "Undo" button with a comprehensive table view.
 */
export default class extends Controller {
  static targets = [
    "modal",
    "tbody",
    "editButton",
    "cancelButton",
    "viewActions",
    "editActions",
    "warningBanner"
  ]

  static values = {
    tableMonitorId: Number
  }

  connect() {
    this.editMode = false
    this.originalData = null
  }

  // Open the modal
  open(event) {
    event?.preventDefault()
    
    // Check if there are pending updates
    const hasPending = this.checkPendingUpdates()
    
    if (hasPending) {
      // Wait for updates to complete
      this.waitForUpdatesAndOpen()
    } else {
      // No pending updates, open immediately
      this.loadProtocolData()
    }
  }
  
  // Check if there are pending updates
  checkPendingUpdates() {
    // Check for pending-update class in DOM
    const hasPendingUpdates = document.querySelectorAll('.pending-update').length > 0
    
    // Also check parent controller
    const parentController = this.element.closest('[data-controller*="table-monitor"]')
    let hasParentPending = false
    if (parentController) {
      const stimulusController = this.application.getControllerForElementAndIdentifier(
        parentController, 
        'table-monitor'
      ) || this.application.getControllerForElementAndIdentifier(
        parentController, 
        'tabmon'
      )
      if (stimulusController?.clientState?.pendingUpdates) {
        hasParentPending = stimulusController.clientState.pendingUpdates.size > 0
      }
    }
    
    return hasPendingUpdates || hasParentPending
  }
  
  // Wait for updates to complete and then open
  async waitForUpdatesAndOpen() {
    const maxWaitTime = 2000 // Maximum 2 seconds
    const checkInterval = 50 // Check every 50ms
    const startTime = Date.now()
    
    while (Date.now() - startTime < maxWaitTime) {
      if (!this.checkPendingUpdates()) {
        this.loadProtocolData()
        return
      }
      
      await new Promise(resolve => setTimeout(resolve, checkInterval))
    }
    
    // Timeout reached
    console.warn('⚠️ Timeout waiting for updates, opening protocol modal anyway')
    this.loadProtocolData()
  }

  // Load protocol data from server and render tbody
  async loadProtocolData() {
    try {
      // Fetch JSON data for player info
      const jsonResponse = await fetch(`/table_monitors/${this.tableMonitorIdValue}/game_protocol.json`)
      if (!jsonResponse.ok) {
        throw new Error(`HTTP error! status: ${jsonResponse.status}`)
      }
      const data = await jsonResponse.json()
      this.protocolData = data
      this.updatePlayerInfo()
      
      // Fetch HTML partial for tbody (view mode)
      const htmlResponse = await fetch(`/table_monitors/${this.tableMonitorIdValue}/game_protocol_tbody`)
      if (!htmlResponse.ok) {
        throw new Error(`HTTP error! status: ${htmlResponse.status}`)
      }
      const html = await htmlResponse.text()
      this.tbodyTarget.innerHTML = html
      
      // Show modal and ensure view mode actions are visible
      this.editMode = false
      if (this.hasViewActionsTarget) this.viewActionsTarget.classList.remove('hidden')
      if (this.hasEditActionsTarget) this.editActionsTarget.classList.add('hidden')
      if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.add('hidden')
      this.modalTarget.classList.remove('hidden')
    } catch (error) {
      console.error('Error loading protocol data:', error)
      this.showError(`Fehler beim Laden des Spielprotokolls: ${error.message}`)
    }
  }

  // Update player information in the modal header
  updatePlayerInfo() {
    const playerAName = document.getElementById('player-a-name')
    const playerBName = document.getElementById('player-b-name')
    const disciplineInfo = document.getElementById('discipline-info')
    const goalInfo = document.getElementById('goal-info')
    
    if (playerAName) playerAName.textContent = this.protocolData.player_a.shortname || this.protocolData.player_a.name
    if (playerBName) playerBName.textContent = this.protocolData.player_b.shortname || this.protocolData.player_b.name
    if (disciplineInfo) disciplineInfo.textContent = this.protocolData.discipline || 'Freie Partie'
    if (goalInfo) {
      const goal = this.protocolData.balls_goal || 0
      goalInfo.textContent = goal > 0 ? `Ziel: ${goal} Punkte` : 'Ziel: kein Limit'
    }
  }

  // Close the modal
  close(event) {
    event?.preventDefault()
    
    if (this.editMode) {
      if (confirm('Ungespeicherte Änderungen verwerfen?')) {
        this.cancelEdit()
      } else {
        return
      }
    }
    
    this.modalTarget.classList.add('hidden')
  }

  // Switch to edit mode
  async edit(event) {
    event?.preventDefault()
    
    try {
      // Fetch HTML partial for tbody (edit mode)
      const htmlResponse = await fetch(`/table_monitors/${this.tableMonitorIdValue}/game_protocol_tbody_edit`)
      if (!htmlResponse.ok) {
        throw new Error(`HTTP error! status: ${htmlResponse.status}`)
      }
      const html = await htmlResponse.text()
      this.tbodyTarget.innerHTML = html
      
      // Switch to edit mode UI
      this.editMode = true
      if (this.hasViewActionsTarget) this.viewActionsTarget.classList.add('hidden')
      if (this.hasEditActionsTarget) this.editActionsTarget.classList.remove('hidden')
      if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.remove('hidden')
    } catch (error) {
      console.error('Error switching to edit mode:', error)
      this.showError(`Fehler beim Wechseln in den Bearbeitungsmodus: ${error.message}`)
    }
  }

  // Cancel edit mode
  async cancelEdit(event) {
    event?.preventDefault()
    
    // In Reflex mode, just reload the view mode tbody
    // (no unsaved changes since every action saves immediately)
    try {
      // Fetch HTML partial for tbody (view mode)
      const htmlResponse = await fetch(`/table_monitors/${this.tableMonitorIdValue}/game_protocol_tbody`)
      if (!htmlResponse.ok) {
        throw new Error(`HTTP error! status: ${htmlResponse.status}`)
      }
      const html = await htmlResponse.text()
      this.tbodyTarget.innerHTML = html
      
      // Switch back to view mode UI
      this.editMode = false
      if (this.hasViewActionsTarget) this.viewActionsTarget.classList.remove('hidden')
      if (this.hasEditActionsTarget) this.editActionsTarget.classList.add('hidden')
      if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.add('hidden')
    } catch (error) {
      console.error('Error canceling edit mode:', error)
      this.showError(`Fehler beim Verlassen des Bearbeitungsmodus: ${error.message}`)
    }
  }

  // Print the protocol
  print(event) {
    event?.preventDefault()
    window.print()
  }

  // Show error message
  showError(message) {
    alert(message)
  }
}

