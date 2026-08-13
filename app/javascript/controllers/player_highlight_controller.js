import { Controller } from "@hotwired/stimulus"

// Hebt beim Klick auf einen Spielernamen alle Spiele dieses Spielers im K.-o.-Diagramm hervor.
// Erneuter Klick auf denselben Namen (oder Klick auf einen anderen) schaltet um. Arbeitet per
// Event-Delegation über [data-player-id]-Namenszellen — nutzbar in Einzel- und Doppel-K.-o.
export default class extends Controller {
  connect() {
    this.onClick = this.onClick.bind(this)
    this.element.addEventListener("click", this.onClick)
    this.activeId = null
  }

  disconnect() {
    this.element.removeEventListener("click", this.onClick)
  }

  onClick(event) {
    const nameEl = event.target.closest("[data-player-id]")
    if (!nameEl || !this.element.contains(nameEl)) return
    const playerId = nameEl.dataset.playerId
    if (!playerId) return
    this.highlight(playerId === this.activeId ? null : playerId)
  }

  highlight(playerId) {
    this.activeId = playerId
    this.element.querySelectorAll("[data-player-id]").forEach((el) => {
      el.classList.toggle("ko-hl-name", playerId != null && el.dataset.playerId === playerId)
    })
  }
}
