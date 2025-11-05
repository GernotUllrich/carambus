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
    "saveButton",
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
      // Show a brief message and wait for updates to complete
      console.log('⏳ Waiting for updates to complete...')
      // Set up a listener to open when updates complete
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
        console.log('✅ Updates complete, opening protocol modal')
        this.loadProtocolData()
        return
      }
      
      await new Promise(resolve => setTimeout(resolve, checkInterval))
    }
    
    // Timeout reached
    console.warn('⚠️ Timeout waiting for updates, opening protocol modal anyway')
    this.loadProtocolData()
  }

  // Load protocol data from server
  async loadProtocolData() {
    try {
      const response = await fetch(`/table_monitors/${this.tableMonitorIdValue}/game_protocol.json`)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      
      this.protocolData = data
      this.updatePlayerInfo()
      this.renderViewMode()
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
  edit(event) {
    event?.preventDefault()
    
    this.editMode = true
    this.originalData = JSON.parse(JSON.stringify(this.getCurrentData()))
    this.renderEditMode()
  }

  // Save changes
  async save(event) {
    event?.preventDefault()
    
    const data = this.getCurrentData()
    
    // Validate: no negative values
    const hasNegative = data.playera.some(v => v < 0) || data.playerb.some(v => v < 0)
    if (hasNegative) {
      this.showError('Negative Punktzahlen sind nicht erlaubt')
      return
    }
    
    try {
      const response = await fetch(`/table_monitors/${this.tableMonitorIdValue}/update_innings`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ innings: data })
      })
      
      const result = await response.json()
      
      if (result.success) {
        this.editMode = false
        // Reload the page to show updated scores
        window.location.reload()
      } else {
        this.showError(`Fehler beim Speichern: ${result.error}`)
      }
    } catch (error) {
      console.error('Error saving innings:', error)
      this.showError('Fehler beim Speichern der Änderungen')
    }
  }

  // Cancel edit mode
  cancelEdit(event) {
    event?.preventDefault()
    
    // Ask for confirmation if changes might be lost
    if (this.editMode && !confirm('Ungespeicherte Änderungen verwerfen?')) {
      return
    }
    
    this.editMode = false
    this.restoreOriginalData()
    this.renderViewMode()
  }

  // Increment points for a specific inning
  incrementPoints(event) {
    event.preventDefault()
    const button = event.currentTarget
    const input = button.closest('td').querySelector('input')
    const currentValue = parseInt(input.value) || 0
    input.value = currentValue + 1
    this.recalculateTotals()
  }

  // Decrement points for a specific inning
  decrementPoints(event) {
    event.preventDefault()
    const button = event.currentTarget
    const input = button.closest('td').querySelector('input')
    const currentValue = parseInt(input.value) || 0
    const newValue = Math.max(0, currentValue - 1)
    input.value = newValue
    this.recalculateTotals()
  }

  // Delete an inning
  deleteInning(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const row = button.closest('tr[data-inning-row]')
    if (!row) return
    
    // Check if button is disabled
    if (button.disabled) {
      alert('Löschen ist nur erlaubt, wenn beide Spieler 0 Punkte haben.')
      return
    }
    
    // Get the inning values from the input fields
    const inputs = row.querySelectorAll('input[type="number"]')
    const inningA = parseInt(inputs[0]?.value) || 0
    const inningB = parseInt(inputs[1]?.value) || 0
    
    // Only allow delete if both are 0
    if (inningA !== 0 || inningB !== 0) {
      alert('Löschen ist nur erlaubt, wenn beide Spieler 0 Punkte haben.')
      return
    }
    
    if (!confirm('Diese Aufnahme wirklich löschen (0:0)?')) {
      return
    }
    
    row.remove()
    this.renumberInnings()
    this.recalculateTotals()
  }

  // Insert a new inning
  insertInning(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const clickedRow = button.closest('tr')
    const newRow = this.createEmptyInningRow()
    
    // Check if this is the "add at end" button or an inline button
    const isInDataRow = clickedRow.querySelector('[data-inning-row]') !== null || clickedRow.hasAttribute('data-inning-row')
    
    if (isInDataRow) {
      // Insert BEFORE this row (user clicked the + button in a data row)
      clickedRow.parentNode.insertBefore(newRow, clickedRow)
    } else {
      // Insert at end (user clicked the "+ Neu" button at bottom)
      // Find the last data row
      const lastDataRow = this.tbodyTarget.querySelector('tr[data-inning-row]:last-of-type')
      if (lastDataRow) {
        lastDataRow.parentNode.insertBefore(newRow, lastDataRow.nextSibling)
      } else {
        // No data rows yet, insert as first row
        clickedRow.parentNode.insertBefore(newRow, clickedRow)
      }
    }
    
    this.renumberInnings()
    this.recalculateTotals()  // This already calls updateDeleteButtons
  }

  // Handle manual input changes
  handleInputChange(event) {
    this.recalculateTotals()
  }

  // Recalculate running totals for both players
  recalculateTotals() {
    this.recalculatePlayerTotals('playera')
    this.recalculatePlayerTotals('playerb')
    this.updateDeleteButtons()
  }

  // Recalculate totals for a specific player
  recalculatePlayerTotals(playerId) {
    const inputs = this.tbodyTarget.querySelectorAll(`input[data-player="${playerId}"]`)
    let total = 0
    
    inputs.forEach(input => {
      const points = parseInt(input.value) || 0
      total += points
      const row = input.closest('tr')
      const totalCell = row.querySelector(`[data-total="${playerId}"]`)
      if (totalCell) {
        totalCell.textContent = total
      }
    })
  }

  // Renumber innings after insert/delete
  renumberInnings() {
    const rows = this.tbodyTarget.querySelectorAll('tr[data-inning-row]')
    rows.forEach((row, index) => {
      const inningNumber = index + 1
      const numberCell = row.querySelector('[data-inning-number]')
      if (numberCell) {
        // Update the span inside the number cell
        const span = numberCell.querySelector('span')
        if (span) {
          span.textContent = inningNumber
        }
      }
    })
  }

  // Update delete button states based on current values
  updateDeleteButtons() {
    const rows = this.tbodyTarget.querySelectorAll('tr[data-inning-row]')
    
    rows.forEach(row => {
      const inputs = row.querySelectorAll('input[type="number"]')
      const deleteButton = row.querySelector('button[data-action*="deleteInning"]')
      
      if (!deleteButton || inputs.length < 2) return
      
      const inningA = parseInt(inputs[0]?.value) || 0
      const inningB = parseInt(inputs[1]?.value) || 0
      
      // Enable delete button only if both values are 0
      const canDelete = (inningA === 0 && inningB === 0)
      
      deleteButton.disabled = !canDelete
      deleteButton.title = canDelete ? 'Zeile löschen' : 'Löschen nur bei 0:0 erlaubt'
      
      if (canDelete) {
        deleteButton.className = "px-2 py-1 bg-red-500 hover:bg-red-600 text-white rounded text-sm font-bold text-lg"
      } else {
        deleteButton.className = "px-2 py-1 bg-gray-400 cursor-not-allowed text-white rounded text-sm opacity-50 font-bold text-lg"
      }
    })
  }

  // Create an empty inning row for insertion
  createEmptyInningRow() {
    const maxInnings = Math.max(
      this.tbodyTarget.querySelectorAll('tr[data-inning-row]').length,
      0
    )
    const inningNumber = maxInnings + 1
    
    const row = document.createElement('tr')
    row.dataset.inningRow = 'true'
    row.className = 'border-b border-gray-200 dark:border-gray-700'
    row.innerHTML = `
      <td class="py-2 px-2 text-center bg-gray-50 dark:bg-gray-800" data-inning-number>
        <div class="flex flex-col gap-1">
          <span class="font-semibold">${inningNumber}</span>
          <button data-action="click->game-protocol#insertInning" 
                  title="Aufnahme davor einfügen"
                  class="text-xs px-1 py-0.5 bg-green-500 hover:bg-green-600 text-white rounded">
            +
          </button>
        </div>
      </td>
      <td class="py-2 px-4 text-center bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20">
        <div class="flex items-center justify-center gap-1">
          <button data-action="click->game-protocol#decrementPoints" 
                  class="px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-sm font-bold">−</button>
          <input type="number" 
                 value="0" 
                 min="0"
                 data-player="playera"
                 data-action="input->game-protocol#handleInputChange"
                 class="w-16 px-2 py-1 text-center border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800 dark:text-gray-100">
          <button data-action="click->game-protocol#incrementPoints" 
                  class="px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-sm font-bold">+</button>
        </div>
      </td>
      <td class="py-2 px-4 text-center font-bold bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20" data-total="playera">0</td>
      <td class="py-2 px-4 text-center bg-green-50 dark:bg-green-900 dark:bg-opacity-20">
        <div class="flex items-center justify-center gap-1">
          <button data-action="click->game-protocol#decrementPoints" 
                  class="px-2 py-1 bg-green-500 hover:bg-green-600 text-white rounded text-sm font-bold">−</button>
          <input type="number" 
                 value="0" 
                 min="0"
                 data-player="playerb"
                 data-action="input->game-protocol#handleInputChange"
                 class="w-16 px-2 py-1 text-center border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800 dark:text-gray-100">
          <button data-action="click->game-protocol#incrementPoints" 
                  class="px-2 py-1 bg-green-500 hover:bg-green-600 text-white rounded text-sm font-bold">+</button>
        </div>
      </td>
      <td class="py-2 px-4 text-center font-bold bg-green-50 dark:bg-green-900 dark:bg-opacity-20" data-total="playerb">0</td>
      <td class="py-2 px-2 text-center">
        <button data-action="click->game-protocol#deleteInning" 
                title="Zeile löschen"
                class="px-2 py-1 bg-red-500 hover:bg-red-600 text-white rounded text-sm font-bold text-lg">
          ✗
        </button>
      </td>
    `
    
    return row
  }

  // Print the protocol
  print(event) {
    event?.preventDefault()
    window.print()
  }

  // Get current innings data from the table
  getCurrentData() {
    const playera = []
    const playerb = []
    
    const rows = this.tbodyTarget.querySelectorAll('tr[data-inning-row]')
    rows.forEach(row => {
      const inputA = row.querySelector('input[data-player="playera"]')
      const inputB = row.querySelector('input[data-player="playerb"]')
      
      // Always add value - even if input doesn't exist (0 for empty cells)
      playera.push(inputA ? (parseInt(inputA.value) || 0) : 0)
      playerb.push(inputB ? (parseInt(inputB.value) || 0) : 0)
    })
    
    return { playera, playerb }
  }

  // Restore original data before edit
  restoreOriginalData() {
    if (this.originalData) {
      this.protocolData.player_a.innings = this.originalData.playera
      this.protocolData.player_b.innings = this.originalData.playerb
      this.protocolData.player_a.totals = this.calculateTotals(this.originalData.playera)
      this.protocolData.player_b.totals = this.calculateTotals(this.originalData.playerb)
    }
  }

  // Calculate totals from innings array
  calculateTotals(innings) {
    const totals = []
    let sum = 0
    innings.forEach(points => {
      sum += points
      totals.push(sum)
    })
    return totals
  }

  // Render view mode (readonly)
  renderViewMode() {
    const data = this.protocolData
    
    // Safety check for undefined data
    const inningsA = data.player_a?.innings || []
    const inningsB = data.player_b?.innings || []
    const maxInnings = Math.max(inningsA.length, inningsB.length)
    
    let html = ''
    
    // Handle empty game (no innings yet)
    if (maxInnings === 0) {
      html = `
        <tr>
          <td colspan="6" class="py-8 px-4 text-center text-gray-500 dark:text-gray-400">
            Noch keine Aufnahmen vorhanden. Das Spiel hat noch nicht begonnen.
          </td>
        </tr>
      `
      this.tbodyTarget.innerHTML = html
      
      // Show view actions, hide edit actions and warning
      if (this.hasViewActionsTarget) this.viewActionsTarget.classList.remove('hidden')
      if (this.hasEditActionsTarget) this.editActionsTarget.classList.add('hidden')
      if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.add('hidden')
      return
    }
    
    const activePlayer = data.current_inning?.active_player || 'playera'
    
    // Get totals arrays with safety checks
    const totalsA = data.player_a?.totals || []
    const totalsB = data.player_b?.totals || []
    
    for (let i = 0; i < maxInnings; i++) {
      // SIMPLE RULE: Last row is always the current/active inning
      const isLastInning = (i === maxInnings - 1)
      
      // Get values from data with safety checks
      const inningAValue = inningsA[i]
      const totalAValue = totalsA[i]
      const inningBValue = inningsB[i]
      const totalBValue = totalsB[i]
      
      // Active player in last inning gets red highlighting
      const isPlayerAActive = isLastInning && activePlayer === 'playera'
      const isPlayerBActive = isLastInning && activePlayer === 'playerb'
      
      // Show value if:
      // 1. Active player in last inning, OR
      // 2. Non-zero value, OR
      // 3. NOT last inning (= completed inning, show even 0)
      const hasInningA = isPlayerAActive || inningAValue > 0 || !isLastInning
      const hasInningB = isPlayerBActive || inningBValue > 0 || !isLastInning
      
      // Show values:
      // - Has played: show value (even 0)
      // - Not played: show empty
      const inningA = hasInningA ? inningAValue : ''
      const totalA = hasInningA ? totalAValue : ''
      const inningB = hasInningB ? inningBValue : ''
      const totalB = hasInningB ? totalBValue : ''
      
      const rowClass = 'border-b border-gray-200 dark:border-gray-700'
      
      // Styling for innings - red if active
      const inningAClass = isPlayerAActive ? 'text-red-600 dark:text-red-400 font-bold text-lg' : ''
      const inningBClass = isPlayerBActive ? 'text-red-600 dark:text-red-400 font-bold text-lg' : ''
      
      // Styling for totals - also red if active
      const totalAClass = isPlayerAActive ? 'text-red-600 dark:text-red-400 font-bold text-lg' : ''
      const totalBClass = isPlayerBActive ? 'text-red-600 dark:text-red-400 font-bold text-lg' : ''
      
      // Apply yellow background only to the active player's cell
      const cellClassA = isPlayerAActive 
        ? 'py-2 px-4 text-center bg-yellow-100 dark:bg-yellow-900 dark:bg-opacity-30' 
        : 'py-2 px-4 text-center bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20'
      const cellClassB = isPlayerBActive 
        ? 'py-2 px-4 text-center bg-yellow-100 dark:bg-yellow-900 dark:bg-opacity-30' 
        : 'py-2 px-4 text-center bg-green-50 dark:bg-green-900 dark:bg-opacity-20'
      
      // Arrow only for the active player with a value
      const arrow = isPlayerBActive ? ' <span class="text-red-500">◄──</span>' : ''
      
      html += `
        <tr class="${rowClass}" data-inning-row>
          <td class="py-2 px-2 text-center bg-gray-50 dark:bg-gray-800 font-semibold" data-inning-number>${i + 1}</td>
          <td class="${cellClassA} ${inningAClass}">${inningA}</td>
          <td class="py-2 px-4 text-center font-bold bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20 ${totalAClass}">${totalA}</td>
          <td class="${cellClassB} ${inningBClass}">${inningB}</td>
          <td class="py-2 px-4 text-center font-bold bg-green-50 dark:bg-green-900 dark:bg-opacity-20 ${totalBClass}">${totalB}${arrow}</td>
          <td class="py-2 px-2 text-center"></td>
        </tr>
      `
    }
    
    this.tbodyTarget.innerHTML = html
    
    // Show view actions, hide edit actions and warning
    if (this.hasViewActionsTarget) this.viewActionsTarget.classList.remove('hidden')
    if (this.hasEditActionsTarget) this.editActionsTarget.classList.add('hidden')
    if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.add('hidden')
  }

  // Render edit mode (with input fields)
  renderEditMode() {
    const data = this.protocolData
    
    // Safety checks for undefined data
    const inningsA = data.player_a?.innings || []
    const inningsB = data.player_b?.innings || []
    const totalsA = data.player_a?.totals || []
    const totalsB = data.player_b?.totals || []
    
    const maxInnings = Math.max(inningsA.length, inningsB.length)
    const activePlayer = data.current_inning?.active_player || 'playera'
    
    let html = ''
    
    for (let i = 0; i < maxInnings; i++) {
      // SIMPLE RULE: Last row is always the current/active inning
      const isLastInning = (i === maxInnings - 1)
      
      // Get values from data with safety checks
      const inningAValue = inningsA[i]
      const totalAValue = totalsA[i]
      const inningBValue = inningsB[i]
      const totalBValue = totalsB[i]
      
      // Active player in last inning gets red highlighting
      const isPlayerAActive = isLastInning && activePlayer === 'playera'
      const isPlayerBActive = isLastInning && activePlayer === 'playerb'
      
      // Show value if:
      // 1. Active player in last inning, OR
      // 2. Non-zero value, OR
      // 3. NOT last inning (= completed inning, show even 0)
      const showInningA = isPlayerAActive || inningAValue > 0 || !isLastInning
      const showInningB = isPlayerBActive || inningBValue > 0 || !isLastInning
      
      const inningA = showInningA ? (inningAValue !== undefined ? inningAValue : 0) : ''
      const totalA = showInningA ? (totalAValue !== undefined ? totalAValue : 0) : ''
      const inningB = showInningB ? (inningBValue !== undefined ? inningBValue : 0) : ''
      const totalB = showInningB ? (totalBValue !== undefined ? totalBValue : 0) : ''
      
      // Check if both innings are 0 or empty (only then allow delete)
      const canDelete = (!showInningA || inningA === 0) && (!showInningB || inningB === 0)
      const deleteButtonClass = canDelete 
        ? "px-2 py-1 bg-red-500 hover:bg-red-600 text-white rounded text-sm font-bold" 
        : "px-2 py-1 bg-gray-400 cursor-not-allowed text-white rounded text-sm opacity-50 font-bold"
      
      const inputClassA = isPlayerAActive 
        ? "w-16 px-2 py-1 text-center border-2 border-red-500 rounded bg-yellow-50 dark:bg-yellow-900 text-red-600 dark:text-red-400 font-bold text-lg"
        : "w-16 px-2 py-1 text-center border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800 dark:text-gray-100"
      const inputClassB = isPlayerBActive 
        ? "w-16 px-2 py-1 text-center border-2 border-red-500 rounded bg-yellow-50 dark:bg-yellow-900 text-red-600 dark:text-red-400 font-bold text-lg"
        : "w-16 px-2 py-1 text-center border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-800 dark:text-gray-100"
      
      html += `
        <tr class="border-b border-gray-200 dark:border-gray-700" data-inning-row>
          <td class="py-2 px-2 text-center bg-gray-50 dark:bg-gray-800" data-inning-number>
            <div class="flex flex-col gap-1">
              <span class="font-semibold">${i + 1}</span>
              <button data-action="click->game-protocol#insertInning" 
                      title="Aufnahme davor einfügen"
                      class="text-xs px-1 py-0.5 bg-green-500 hover:bg-green-600 text-white rounded">
                +
              </button>
            </div>
          </td>
          <td class="py-2 px-4 text-center bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20">
            ${showInningA ? `
            <div class="flex items-center justify-center gap-1">
              <button data-action="click->game-protocol#decrementPoints" 
                      class="px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-sm font-bold">−</button>
              <input type="number" 
                     value="${inningA}" 
                     min="0"
                     data-player="playera"
                     data-action="input->game-protocol#handleInputChange"
                     class="${inputClassA}">
              <button data-action="click->game-protocol#incrementPoints" 
                      class="px-2 py-1 bg-blue-500 hover:bg-blue-600 text-white rounded text-sm font-bold">+</button>
            </div>
            ` : ''}
          </td>
          <td class="py-2 px-4 text-center font-bold bg-blue-50 dark:bg-blue-900 dark:bg-opacity-20 ${isPlayerAActive ? 'text-red-600 dark:text-red-400 text-lg' : ''}" data-total="playera">${totalA}</td>
          <td class="py-2 px-4 text-center bg-green-50 dark:bg-green-900 dark:bg-opacity-20">
            ${showInningB ? `
            <div class="flex items-center justify-center gap-1">
              <button data-action="click->game-protocol#decrementPoints" 
                      class="px-2 py-1 bg-green-500 hover:bg-green-600 text-white rounded text-sm font-bold">−</button>
              <input type="number" 
                     value="${inningB}" 
                     min="0"
                     data-player="playerb"
                     data-action="input->game-protocol#handleInputChange"
                     class="${inputClassB}">
              <button data-action="click->game-protocol#incrementPoints" 
                      class="px-2 py-1 bg-green-500 hover:bg-green-600 text-white rounded text-sm font-bold">+</button>
            </div>
            ` : ''}
          </td>
          <td class="py-2 px-4 text-center font-bold bg-green-50 dark:bg-green-900 dark:bg-opacity-20 ${isPlayerBActive ? 'text-red-600 dark:text-red-400 text-lg' : ''}" data-total="playerb">${totalB}</td>
          <td class="py-2 px-2 text-center">
            <button data-action="click->game-protocol#deleteInning" 
                    ${canDelete ? '' : 'disabled'}
                    title="${canDelete ? 'Zeile löschen' : 'Löschen nur bei 0:0 erlaubt'}"
                    class="${deleteButtonClass} text-lg">
              ✗
            </button>
          </td>
        </tr>
      `
    }
    
    // Add one more insert button at the end
    html += `
      <tr>
        <td class="py-2 px-2 text-center bg-gray-50 dark:bg-gray-800">
          <button data-action="click->game-protocol#insertInning" 
                  title="Aufnahme am Ende einfügen"
                  class="text-xs px-2 py-1 bg-green-500 hover:bg-green-600 text-white rounded">
            + Neu
          </button>
        </td>
        <td colspan="5" class="py-2 px-4 text-center text-gray-500 dark:text-gray-400 text-sm">
          Am Ende Aufnahme hinzufügen
        </td>
      </tr>
    `
    
    this.tbodyTarget.innerHTML = html
    
    // Update delete button states
    this.updateDeleteButtons()
    
    // Hide view actions, show edit actions and warning
    if (this.hasViewActionsTarget) this.viewActionsTarget.classList.add('hidden')
    if (this.hasEditActionsTarget) this.editActionsTarget.classList.remove('hidden')
    if (this.hasWarningBannerTarget) this.warningBannerTarget.classList.remove('hidden')
  }

  // Show error message
  showError(message) {
    alert(message)
  }
}

