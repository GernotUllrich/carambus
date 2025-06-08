import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["gametime", "warntime"]
  static values = {
    increment: { type: Number, default: 5 }
  }

  connect() {
    // Initialize values from data attributes
    this.gametime = parseInt(this.gametimeTarget.value) || 30
    this.warntime = parseInt(this.warntimeTarget.value) || 5
  }

  decrementGametime() {
    if (this.gametime <= 200) this.incrementValue = 25
    if (this.gametime <= 100) this.incrementValue = 5
    if (this.gametime <= 10) this.incrementValue = 1
    if (this.gametime > 0) {
      this.gametime = this.gametime - this.incrementValue
      this.gametimeTarget.value = this.gametime
    }
  }

  incrementGametime() {
    if (this.gametime >= 10) this.incrementValue = 5
    if (this.gametime >= 100) this.incrementValue = 25
    if (this.gametime >= 200) this.incrementValue = 100
    if (this.gametime < 99) {
      this.gametime = this.gametime + this.incrementValue
      this.gametimeTarget.value = this.gametime
    }
  }

  decrementWarntime() {
    if (this.warntime <= 200) this.incrementValue = 25
    if (this.warntime <= 100) this.incrementValue = 5
    if (this.warntime <= 10) this.incrementValue = 1
    if (this.warntime > 0) {
      this.warntime = this.warntime - this.incrementValue
      this.warntimeTarget.value = this.warntime
    }
  }

  incrementWarntime() {
    if (this.warntime >= 10) this.incrementValue = 5
    if (this.warntime >= 100) this.incrementValue = 25
    if (this.warntime >= 200) this.incrementValue = 100
    if (this.warntime < 99) {
      this.warntime = this.warntime + this.incrementValue
      this.warntimeTarget.value = this.warntime
    }
  }
} 