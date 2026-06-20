import { Controller } from "@hotwired/stimulus"

// Phase 37-01: Spielort-Picker ohne Cmd-Klick.
// Klick auf einen verfuegbaren Spielort -> Chip im "Ausgewaehlt"-Block (mit hidden
// input user[sportwart_location_ids][]); Klick auf das "x" am Chip entfernt ihn wieder.
// Quelle der Wahrheit sind die hidden inputs in den Chips; ein leeres Fallback-Input
// im Partial sorgt dafuer, dass "alle entfernt" die Zuordnung auch wirklich leert.
export default class extends Controller {
  static targets = ["selected", "available", "group", "empty", "region", "availableList"]
  static values = {
    field: { type: String, default: "user[sportwart_location_ids][]" },
    locationsUrl: String // nur gesetzt auf Servern OHNE Region-Context (Region-Stufe davor)
  }

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

  // 2026-06-20: Region-Stufe fuer Server OHNE festen Region-Context (carambus.de, Authority).
  // Bei Region-Wechsel die Verfuegbar-Liste (Spielorte gruppiert nach Verein) per JSON nachladen.
  // Bereits gewaehlte Chips bleiben erhalten (additiv ueber Regionen).
  async loadRegion() {
    if (!this.hasRegionTarget || !this.hasAvailableListTarget) return
    const regionId = this.regionTarget.value
    const selectedIds = Array.from(this.selectedTarget.querySelectorAll("[data-chip-id]"))
      .map((c) => c.dataset.chipId)
    if (!regionId) {
      this.availableListTarget.innerHTML = ""
      return
    }
    let groups = []
    try {
      const resp = await fetch(`${this.locationsUrlValue}?region_id=${encodeURIComponent(regionId)}`, {
        headers: { Accept: "application/json" }
      })
      if (resp.ok) groups = await resp.json()
    } catch (e) {
      groups = []
    }
    this.renderAvailable(groups, selectedIds)
  }

  renderAvailable(groups, selectedIds) {
    const esc = (s) =>
      String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
    const html = groups.map((g) => {
      const items = g.locations.map((l) => {
        const hidden = selectedIds.includes(String(l.id)) ? "hidden" : ""
        return `<button type="button" class="lp-available-item" data-location-picker-target="available" ` +
          `data-id="${l.id}" data-name="${esc(l.name)}" data-action="location-picker#add" ${hidden} ` +
          `style="display:block;width:100%;text-align:left;border:0;background:transparent;cursor:pointer;padding:3px 8px;border-radius:4px;font-size:0.9em;">+ ${esc(l.name)}</button>`
      }).join("")
      return `<div data-location-picker-target="group" style="margin-bottom:6px;">` +
        `<div style="font-weight:600;font-size:0.8em;color:#6b7280;padding:2px 4px;">${esc(g.club)}</div>${items}</div>`
    }).join("")
    this.availableListTarget.innerHTML = html
    this.refreshGroups()
  }
}
