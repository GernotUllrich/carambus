import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "multiset", "discipline", "ballsGoal", "innings", "sets", "games",
    "multisetHeader", "disciplineHeader", "ballsGoalHeader", "inningsHeader", "setsHeader", "gamesHeader",
    "multisetContainer", "disciplineContainer", "ballsGoalContainer", "inningsContainer", "setsContainer", "gamesContainer",
    "multisetOption", "disciplineOption", "ballsGoalOption", "inningsOption", "setsOption", "gamesOption",
    "multisetCounter", "disciplineCounter", "ballsGoalCounter", "inningsCounter", "setsCounter", "gamesCounter",
    "multisetInput", "disciplineInput", "ballsGoalInput", "inningsInput", "setsInput", "gamesInput"
  ]

  static values = {
    multiset: { type: Number, default: 0 },
    parameters: { type: Number, default: 0 },
    discipline: { type: Number, default: 0 },
    ballsGoal: { type: Number, default: 0 },
    tableKind: { type: String, default: "" }
  }

  connect() {
    // Initialize values from data attributes
    this.multisetValue = parseInt(this.element.dataset.multiset || 0)
    this.parametersValue = parseInt(this.element.dataset.parameters || 0)
    this.disciplineValue = parseInt(this.element.dataset.discipline || 0)
    this.ballsGoalValue = parseInt(this.element.dataset.ballsGoal || 0)
    this.tableKindValue = this.element.dataset.tableKind || ""

    // Initialize increment values
    this.incrementValues = {
      multiset: 1,
      discipline: 1,
      ballsGoal: 1,
      innings: 1,
      sets: 1,
      games: 1
    }

    // Initialize last direction
    this.lastDirection = null

    // Set up radio button change handlers
    this.setupRadioHandlers()
  }

  setupRadioHandlers() {
    // Set up change handlers for all radio options
    const optionTargets = [
      "multisetOption", "disciplineOption", "ballsGoalOption",
      "inningsOption", "setsOption", "gamesOption"
    ]

    optionTargets.forEach(targetName => {
      const options = this[`${targetName}Targets`]
      options.forEach(option => {
        const input = option.querySelector('input[type="radio"]')
        if (input) {
          input.addEventListener('change', () => {
            const varname = targetName.replace('Option', '').toLowerCase()
            const value = parseInt(option.dataset.value)
            this.handleRadioChange(varname, value)
          })
        }
      })
    })
  }

  handleRadioChange(varname, value) {
    // Update the corresponding value
    this[`${varname}Value`] = value

    // Handle special cases
    if (varname === 'discipline') {
      this.disciplineAValue = value
      this.disciplineBValue = value
    }
    if (varname === 'ballsGoal') {
      this.ballsGoalAValue = value
      this.ballsGoalBValue = value
    }

    // Update increment value
    if (value !== 3) {
      this.incrementValues[varname] = Math.round(value / 2)
    }

    // Handle games and sets relationship
    if (varname === 'games' && value > 0) {
      this.setsValue = 0
    }
    if (varname === 'sets' && value > 0) {
      this.gamesValue = 0
    }

    // Update multiset based on games and sets
    if (varname !== 'multiset' && this.setsValue === 0 && this.gamesValue === 0) {
      this.multisetValue = 0
    }

    // Update all related values
    this.updateRelatedValues(varname, value)
  }

  updateRelatedValues(varname, value) {
    if (!varname.endsWith('_a') && !varname.endsWith('_b')) {
      const baseValue = value
      this[`${varname}AValue`] = baseValue
      this[`${varname}BValue`] = baseValue
      this[`${varname}2Value`] = baseValue
      this[`${varname}A2Value`] = baseValue
      this[`${varname}B2Value`] = baseValue
    } else {
      this[`${varname}2Value`] = value
    }
  }

  decrement(varname) {
    const target = this[`${varname}InputTarget`]
    if (!target) return

    let increment = this.incrementValues[varname]
    if (increment === 0) {
      increment = parseInt(target.value)
    }
    if (this.lastDirection === 'r') {
      increment = Math.round(increment / 2)
    }

    let newValue = parseInt(target.value) - increment
    this.lastDirection = 'l'

    if (increment < 1) increment = 1
    if (newValue < 0) newValue = 0

    target.value = newValue
    this.incrementValues[varname] = increment
    this.handleRadioChange(varname, newValue)
  }

  increment(varname) {
    const target = this[`${varname}InputTarget`]
    if (!target) return

    let increment = this.incrementValues[varname]
    if (increment === 0) {
      increment = parseInt(target.value)
    }
    if (this.lastDirection === 'l') {
      increment = Math.round(increment / 2)
    }

    let newValue = parseInt(target.value) + increment
    this.lastDirection = 'r'

    const maxValue = this.getMaxValue(varname)
    if (newValue > maxValue) newValue = maxValue

    target.value = newValue
    this.incrementValues[varname] = increment
    this.handleRadioChange(varname, newValue)
  }

  getMaxValue(varname) {
    // Define maximum values for each setting
    const maxValues = {
      multiset: 1,
      discipline: 3,
      ballsGoal: 100,
      innings: 100,
      sets: 100,
      games: 100
    }
    return maxValues[varname] || 100
  }

  // Computed properties for visibility
  get showMultiset() {
    return true // Always show multiset
  }

  get showDiscipline() {
    return true // Always show discipline
  }

  get showBallsGoal() {
    return this.disciplineValue !== 0
  }

  get showInnings() {
    return this.disciplineValue !== 0
  }

  get showSets() {
    return this.multisetValue === 1
  }

  get showGames() {
    return this.multisetValue === 1
  }

  // Helper methods for specific settings
  toggleMultiset() {
    this.multisetValue = this.multisetValue === 0 ? 1 : 0
    if (this.multisetValue === 0) {
      this.setsValue = 0
      this.gamesValue = 0
    }
  }

  updateParameters() {
    this.parametersValue = this.parametersValue === 0 ? 1 : 0
  }

  updateDiscipline(value) {
    this.disciplineValue = value
    this.disciplineAValue = value
    this.disciplineBValue = value
  }

  updateBallsGoal(value) {
    this.ballsGoalValue = value
    this.ballsGoalAValue = value
    this.ballsGoalBValue = value
  }

  updateInnings(value) {
    this.inningsValue = value
    this.inningsAValue = value
    this.inningsBValue = value
  }

  updateSets(value) {
    this.setsValue = value
    this.setsAValue = value
    this.setsBValue = value
    if (value > 0) {
      this.gamesValue = 0
    }
  }

  updateGames(value) {
    this.gamesValue = value
    this.gamesAValue = value
    this.gamesBValue = value
    if (value > 0) {
      this.setsValue = 0
    }
  }

  updateNextBreakRules(value) {
    this.nextBreakRulesValue = value
  }
} 