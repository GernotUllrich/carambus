import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panelState", "previousPanel", "currentElement", "previousElement", "modalConfirmBack", "modalConfirmBackBg"]
  static values = {
    tableMonitorId: String,
    discipline: String,
    tournamentMonitorPresent: Boolean,
    panelNavH: Object,
    panelNavV: Object,
    keyMap: Object
  }

  connect() {
    this.setupPanelNavigation()
    this.setupHotkeys()
    this.startClock()
    this.setupTurboEvents()
    this.initializeFocus()
  }

  setupPanelNavigation() {
    // Initialize panel navigation based on data attributes
    const tabbedElements = this.element.querySelectorAll('a[tabindex="11"]')
    const tabbedKeys = Array.from(tabbedElements).map(el => el.getAttribute("id"))
    
    // Update panel_nav_h with tabbed elements
    tabbedKeys.forEach((key, index) => {
      const nextIndex = index < tabbedKeys.length - 1 ? index + 1 : 0
      this.panelNavHValue[key] = tabbedKeys[nextIndex]
    })
  }

  setupHotkeys() {
    if (!window.hotkeys) return

    window.hotkeys('*', (event, handler) => {
      this.setPreviousElement(this.getCurrentElement())
      this.setPreviousPanel(this.getPanelState())
      event.preventDefault()

      const keyCode = this.keyMapValue[event.keyCode]
      if (!keyCode) return true

      switch (keyCode) {
        case "key_c":
          this.handleKeyC()
          break
        case "key_d":
          this.handleKeyD()
          break
        case "key_b":
          this.handleKeyB()
          break
        case "key_a":
          this.handleKeyA()
          break
      }

      console.log("active panel_state:", this.getPanelState())
      console.log("active current_element:", this.getCurrentElement())
      return true
    })
  }

  startClock() {
    const updateClock = () => {
      const date = new Date()
      const time = date.toLocaleTimeString('en-US', { 
        hour12: false, 
        hour: '2-digit', 
        minute: '2-digit', 
        second: '2-digit' 
      })
      const clockEl = document.getElementById("clock")
      if (clockEl) clockEl.innerText = time
    }

    updateClock()
    setInterval(updateClock, 1000)
  }

  setupTurboEvents() {
    document.addEventListener("cable-ready:after-inner-html", () => {
      this.focusOrResetElement()
    })
  }

  initializeFocus() {
    if (this.getCurrentElement()) {
      this.focusOrResetElement()
    } else {
      this.resetToPointerMode()
    }
  }

  // Panel state management
  getPanelState() {
    return this.panelStateTarget.getAttribute("panel_state")
  }

  setPanelState(state) {
    this.panelStateTarget.setAttribute("panel_state", state)
    this.panelStateTarget.innerHTML = state
  }

  getPreviousPanel() {
    return this.previousPanelTarget.getAttribute("previous_panel")
  }

  setPreviousPanel(panel) {
    this.previousPanelTarget.setAttribute("previous_panel", panel)
    this.previousPanelTarget.innerHTML = panel
  }

  getCurrentElement() {
    return this.currentElementTarget.getAttribute("current_element")
  }

  setCurrentElement(element) {
    this.currentElementTarget.setAttribute("current_element", element)
    this.currentElementTarget.innerHTML = element
    this.currentElementTarget.focus()
  }

  getPreviousElement() {
    return this.previousElementTarget.getAttribute("previous_element")
  }

  setPreviousElement(element) {
    this.previousElementTarget.setAttribute("previous_element", element)
    this.previousElementTarget.innerHTML = element
  }

  // Element focus and interaction
  focusOrResetElement() {
    const el = document.getElementById(this.getCurrentElement())
    if (el) {
      el.focus()
      return true
    }
    return false
  }

  clickOrResetElement() {
    const el = document.getElementById(this.getCurrentElement())
    if (el) {
      el.click()
      return true
    }
    this.resetToPointerMode()
    return false
  }

  isHidden(el) {
    return !el || el.offsetParent === null
  }

  // Navigation and state management
  backout() {
    this.setPanelState(this.getPreviousPanel())
    this.setCurrentElement(this.getPreviousElement())
    this.focusOrResetElement()
  }

  resetToPointerMode() {
    this.setPanelState("pointer_mode")
    this.setCurrentElement("pointer_mode")
    const el = document.getElementById(this.getCurrentElement())
    if (el) el.focus()
  }

  // Modal management
  toggleWarningModal() {
    this.modalConfirmBackTarget.classList.toggle("hidden")
    this.modalConfirmBackBgTarget.classList.toggle("hidden")
    this.modalConfirmBackTarget.classList.toggle("flex")
    this.modalConfirmBackBgTarget.classList.toggle("flex")
  }

  warningMode() {
    this.setPreviousElement(this.getCurrentElement())
    this.setPreviousPanel(this.getPanelState())
    this.setPanelState("warning")
    this.setCurrentElement("ok")
    this.toggleWarningModal()
    if (!this.focusOrResetElement()) {
      this.backout()
    }
  }

  // Key handlers
  handleKeyC() {
    if (this.getPanelState() !== "pointer_mode" && 
        this.getPanelState() !== "warning" && 
        this.getPanelState() !== "setup" && 
        this.getPanelState() !== "shootout") {
      this.setPanelState("pointer_mode")
      this.setCurrentElement("pointer_mode")
      if (!this.focusOrResetElement()) {
        this.backout()
      }
    } else {
      this.warningMode()
    }
  }

  handleKeyD() {
    const state = this.getPanelState()
    switch (state) {
      case "pointer_mode":
        this.handlePointerModeKeyD()
        break
      case "inputs":
      case "warning":
        if (!this.clickOrResetElement()) this.backout()
        break
      case "timer":
        this.handleTimerKeyD()
        break
      case "shootout":
        this.handleShootoutKeyD()
        break
      case "setup":
        this.handleSetupKeyD()
        break
      case "numbers":
        this.handleNumbersKeyD()
        break
    }
  }

  handleKeyB() {
    const state = this.getPanelState()
    if (state === "pointer_mode" || state === "setup") {
      document.getElementById(`key_b_table_monitor_${this.tableMonitorIdValue}`).click()
    } else if (["inputs", "numbers", "warning", "timer"].includes(state)) {
      this.setCurrentElement(this.panelNavHValue[this.getCurrentElement()])
      if (!this.focusOrResetElement()) this.backout()
    } else if (state === "shootout") {
      this.setCurrentElement("change")
      if (!this.clickOrResetElement()) this.backout()
    } else {
      document.getElementById(`key_b_table_monitor_${this.tableMonitorIdValue}`).click()
    }
  }

  handleKeyA() {
    const state = this.getPanelState()
    if (state === "pointer_mode" || state === "setup") {
      document.getElementById(`key_a_table_monitor_${this.tableMonitorIdValue}`).click()
    } else if (state === "timer" || state === "numbers") {
      if (!this.clickOrResetElement()) this.backout()
    } else if (state === "inputs" || state === "warning") {
      this.setCurrentElement(this.previous(this.getCurrentElement()))
      if (!this.focusOrResetElement()) this.backout()
    } else if (state === "shootout") {
      this.setCurrentElement("change")
      if (!this.clickOrResetElement()) this.backout()
    } else {
      document.getElementById(`key_a_table_monitor_${this.tableMonitorIdValue}`).click()
    }
  }

  // Helper methods for key handlers
  previous(current) {
    for (const [key, value] of Object.entries(this.panelNavHValue)) {
      if (value === current) return key
    }
    return current
  }

  handlePointerModeKeyD() {
    this.setPanelState(this.panelNavVValue[this.getPanelState()])
    const timeout = !this.isHidden(document.getElementById("timeout"))
    const play = this.isHidden(document.getElementById("pause"))
    this.setCurrentElement(timeout ? "timeout" : play ? "play" : "pause")
    if (!this.focusOrResetElement()) {
      this.setPanelState(this.panelNavVValue[this.getPanelState()])
      this.setCurrentElement("add_one")
      if (!this.focusOrResetElement()) this.backout()
    }
  }

  handleTimerKeyD() {
    this.setPanelState(this.panelNavVValue[this.getPanelState()])
    this.setCurrentElement("add_one")
    if (!this.focusOrResetElement()) this.backout()
  }

  handleShootoutKeyD() {
    this.setCurrentElement("start_game")
    if (!this.clickOrResetElement()) this.backout()
    this.setPanelState("pointer_mode")
    this.setCurrentElement("pointer_mode")
  }

  handleSetupKeyD() {
    this.setCurrentElement("continue")
    if (!this.clickOrResetElement()) this.backout()
    this.setPanelState("shootout")
    this.setCurrentElement("start_game")
  }

  handleNumbersKeyD() {
    this.setCurrentElement(this.panelNavVValue[this.getCurrentElement()])
    if (!this.focusOrResetElement()) this.backout()
  }
} 