import { Controller } from "@hotwired/stimulus"

// Stimulus-Tooltip für die Parameter-Form im Turnier-Monitor (UI-01).
// Zeigt eine Tailwind-Hovercard mit erklärendem Text, wenn der Nutzer das
// Label-Element mit der Maus berührt oder per Tab anfokussiert.
export default class extends Controller {
  static values = { content: String }

  connect() {
    this.element.addEventListener("mouseenter", this.show)
    this.element.addEventListener("mouseleave", this.hide)
    this.element.addEventListener("focusin", this.show)
    this.element.addEventListener("focusout", this.hide)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.show)
    this.element.removeEventListener("mouseleave", this.hide)
    this.element.removeEventListener("focusin", this.show)
    this.element.removeEventListener("focusout", this.hide)
    this.hide()
  }

  show = () => {
    if (!this.contentValue || this.card) return
    // Position the element relatively so absolute child anchors to it
    if (getComputedStyle(this.element).position === "static") {
      this.element.style.position = "relative"
    }
    const card = document.createElement("div")
    card.className = "absolute z-50 bg-gray-800 text-white text-sm px-3 py-2 rounded shadow-lg max-w-xs bottom-full left-0 mb-2 whitespace-normal pointer-events-none"
    // SECURITY: use textContent only (no HTML injection) — content is static
    // i18n text, but this guards against future misuse that could pipe user
    // input through here.
    card.textContent = this.contentValue
    this.card = card
    this.element.appendChild(card)
  }

  hide = () => {
    if (this.card) {
      this.card.remove()
      this.card = null
    }
  }
}
