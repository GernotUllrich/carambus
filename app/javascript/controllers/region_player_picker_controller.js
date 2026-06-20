import { Controller } from "@hotwired/stimulus"

// 2026-06-20: Dreistufige Kaskade Region -> Verein -> Spieler fuer Server OHNE festen
// Region-Context (carambus.de, Authority). Bei fixem Region-Context uebernimmt der
// dependent-select-Controller die Verein->Spieler-Stufe (Region ist dort implizit).
export default class extends Controller {
  static targets = ["region", "club", "player"]
  static values = {
    clubsUrl: String,
    playersUrl: String,
    clubPlaceholder: { type: String, default: "— Verein wählen —" },
    playerPlaceholder: { type: String, default: "— Spieler wählen —" }
  }

  connect() {
    // Vorbelegung (verknuepfter Spieler): Region gesetzt -> Vereine laden (Verein/Spieler behalten).
    if (this.hasRegionTarget && this.regionTarget.value) {
      this.loadClubs(true)
    } else if (this.hasClubTarget && this.clubTarget.value) {
      this.loadPlayers()
    }
  }

  // arg === true nur aus connect() (Vorauswahl behalten); aus dem Action-Event ist arg das Event.
  async loadClubs(arg) {
    const keepClub = arg === true
    const regionId = this.regionTarget.value
    const previousClub = keepClub ? this.clubTarget.value : ""
    if (!regionId) {
      this.reset(this.clubTarget, this.clubPlaceholderValue)
      this.reset(this.playerTarget, this.playerPlaceholderValue)
      return
    }
    const rows = await this.fetchJson(this.clubsUrlValue, "region_id", regionId)
    this.populate(this.clubTarget, rows, previousClub, this.clubPlaceholderValue)
    if (previousClub && this.clubTarget.value) {
      this.loadPlayers()
    } else {
      this.reset(this.playerTarget, this.playerPlaceholderValue)
    }
  }

  async loadPlayers() {
    const clubId = this.clubTarget.value
    const previousPlayer = this.playerTarget.value
    if (!clubId) {
      this.reset(this.playerTarget, this.playerPlaceholderValue)
      return
    }
    const rows = await this.fetchJson(this.playersUrlValue, "club_id", clubId)
    this.populate(this.playerTarget, rows, previousPlayer, this.playerPlaceholderValue)
  }

  async fetchJson(url, key, val) {
    try {
      const resp = await fetch(`${url}?${key}=${encodeURIComponent(val)}`, {
        headers: { Accept: "application/json" }
      })
      if (!resp.ok) return []
      return await resp.json()
    } catch (e) {
      return []
    }
  }

  populate(select, rows, previous, placeholder) {
    this.reset(select, placeholder)
    rows.forEach((r) => {
      const opt = document.createElement("option")
      opt.value = r.id
      opt.textContent = r.label
      if (String(r.id) === String(previous)) opt.selected = true
      select.appendChild(opt)
    })
  }

  reset(select, placeholder) {
    select.innerHTML = ""
    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = placeholder
    select.appendChild(blank)
  }
}
