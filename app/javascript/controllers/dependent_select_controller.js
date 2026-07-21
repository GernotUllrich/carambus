import { Controller } from "@hotwired/stimulus"

// Phase 37-01: Gestaffelter Selektor — Club (source) -> Spieler (dest).
// Bei Club-Wechsel laedt load() die Spieler des Clubs (aktuelle Saison) via JSON nach.
// Eine bestehende Auswahl (verknuepfter Spieler) bleibt erhalten, falls weiterhin in der Liste.
export default class extends Controller {
  static targets = ["source", "dest"]
  // Plan 26-01: valueKey erlaubt es, ein anderes Feld als `id` als option-value zu nutzen
  // (Meldeliste: `dbu_nr`, damit das Select direkt das add_player_by_dbu-Formular speist).
  // Default "id" = bisheriges Verhalten — der Admin-Konsument bleibt unberührt.
  static values = {
    url: String,
    placeholder: { type: String, default: "— Spieler wählen —" },
    valueKey: { type: String, default: "id" }
  }

  connect() {
    // Bei bereits vorausgewaehltem Verein die volle Spielerliste laden (verknuepfter
    // Spieler bleibt selektiert), damit der Admin auch einen anderen Spieler waehlen kann.
    if (this.hasSourceTarget && this.sourceTarget.value) {
      this.load()
    }
  }

  async load() {
    const clubId = this.sourceTarget.value
    const previous = this.destTarget.value
    if (!clubId) {
      this.resetDest()
      return
    }
    try {
      const resp = await fetch(`${this.urlValue}?club_id=${encodeURIComponent(clubId)}`, {
        headers: { Accept: "application/json" }
      })
      if (!resp.ok) {
        this.resetDest()
        return
      }
      const players = await resp.json()
      this.populate(players, previous)
    } catch (e) {
      this.resetDest()
    }
  }

  populate(players, previous) {
    this.resetDest()
    players.forEach((p) => {
      const opt = document.createElement("option")
      const value = p[this.valueKeyValue] ?? p.id
      opt.value = value
      opt.textContent = p.label
      if (String(value) === String(previous)) opt.selected = true
      this.destTarget.appendChild(opt)
    })
  }

  resetDest() {
    this.destTarget.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = this.placeholderValue
    this.destTarget.appendChild(blank)
  }
}
