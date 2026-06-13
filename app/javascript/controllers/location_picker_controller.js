import { Controller } from "@hotwired/stimulus"

// Phase 37-01: Spielort-Picker ohne Cmd-Klick.
// Klick auf einen verfuegbaren Spielort -> Chip im "Ausgewaehlt"-Block (mit hidden
// input user[sportwart_location_ids][]); Klick auf das "x" am Chip entfernt ihn wieder.
// Quelle der Wahrheit sind die hidden inputs in den Chips; ein leeres Fallback-Input
// im Partial sorgt dafuer, dass "alle entfernt" die Zuordnung auch wirklich leert.
export default class extends Controller {
  static targets = ["selected", "available", "group", "empty"]
  static values = { field: { type: String, default: "user[sportwart_location_ids][]" } }

  connect() {
    this.updateEmpty()
  }

  add(event) {
    const item = event.currentTarget
    const id = item.dataset.id
    if (this.selectedTarget.querySelector(`[data-chip-id="${CSS.escape(id)}"]`)) return
    this.selectedTarget.insertAdjacentHTML("beforeend", this.chipHtml(id, item.dataset.name))
    item.hidden = true
    this.refreshGroups()
    this.updateEmpty()
  }

  remove(event) {
    const chip = event.currentTarget.closest("[data-chip-id]")
    if (!chip) return
    const id = chip.dataset.chipId
    chip.remove()
    const item = this.availableTargets.find((el) => el.dataset.id === id)
    if (item) item.hidden = false
    this.refreshGroups()
    this.updateEmpty()
  }

  chipHtml(id, name) {
    const span = document.createElement("span")
    span.textContent = name
    const safeName = span.innerHTML
    return `<span class="lp-chip" data-chip-id="${id}" style="display:inline-flex;align-items:center;gap:4px;padding:3px 8px;margin:2px;border:1px solid #2563eb;border-radius:12px;background:#eff6ff;font-size:0.9em;">
      <input type="hidden" name="${this.fieldValue}" value="${id}">
      <span>${safeName}</span>
      <button type="button" data-action="location-picker#remove" style="border:0;background:transparent;cursor:pointer;color:#2563eb;font-weight:bold;line-height:1;">&times;</button>
    </span>`
  }

  refreshGroups() {
    if (!this.hasGroupTarget) return
    this.groupTargets.forEach((group) => {
      const visible = group.querySelectorAll("[data-location-picker-target='available']:not([hidden])").length
      group.hidden = visible === 0
    })
  }

  updateEmpty() {
    if (!this.hasEmptyTarget) return
    this.emptyTarget.hidden = this.selectedTarget.querySelector("[data-chip-id]") !== null
  }
}
