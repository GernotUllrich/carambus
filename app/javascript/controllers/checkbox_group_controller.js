import { Controller } from "@hotwired/stimulus"

// Mehrfachauswahl in einer Liste: alle an / alle aus, mit laufender Anzahl.
//
// Erwartet:
//   data-controller="checkbox-group"
//   data-checkbox-group-target="checkbox" an jeder Checkbox
//   data-checkbox-group-target="count"    (optional) Element fuer die Anzahl
//   data-checkbox-group-target="submit"   (optional) Button, der bei 0 Auswahl deaktiviert wird
export default class extends Controller {
  static targets = ["checkbox", "count", "submit"]

  connect() {
    this.refresh()
  }

  selectAll() {
    this.enabledCheckboxes.forEach((cb) => (cb.checked = true))
    this.refresh()
  }

  selectNone() {
    this.enabledCheckboxes.forEach((cb) => (cb.checked = false))
    this.refresh()
  }

  refresh() {
    const selected = this.enabledCheckboxes.filter((cb) => cb.checked).length

    if (this.hasCountTarget) {
      this.countTarget.textContent = selected
    }
    // Ein Submit ohne Auswahl waere serverseitig ohnehin abgewiesen — hier schon sichtbar machen,
    // statt den Anwender auf eine Fehlermeldung laufen zu lassen.
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = selected === 0
    }
  }

  // Bereits kopierte Turniere sind disabled — sie duerfen von "alle auswaehlen" nicht erfasst werden.
  get enabledCheckboxes() {
    return this.checkboxTargets.filter((cb) => !cb.disabled)
  }
}
