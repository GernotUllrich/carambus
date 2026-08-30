import { Controller } from "@hotwired/stimulus"

// Ziffernblock fuer die Anmeldung im Spielerkontext (Plan 02.1-01).
//
// Der eingegebene PIN steht in einem hidden field; die Anzeige zeigt nur Punkte.
// Kein Auto-Absenden: der PIN darf 4 bis 8 Ziffern haben, die Laenge ist also nicht bekannt.
export default class extends Controller {
  static targets = ["display", "value"]

  static MAX = 8

  push(event) {
    const digit = event.currentTarget.dataset.digit
    if (this.valueTarget.value.length >= this.constructor.MAX) return
    this.valueTarget.value += digit
    this.render()
  }

  back() {
    this.valueTarget.value = this.valueTarget.value.slice(0, -1)
    this.render()
  }

  clear() {
    this.valueTarget.value = ""
    this.render()
  }

  render() {
    this.displayTarget.textContent = "•".repeat(this.valueTarget.value.length)
  }
}
