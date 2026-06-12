import { Controller } from "@hotwired/stimulus"

// Phase 37-01: Auf-/zuklappbarer Disziplin-Baum im Admin-User-Formular.
// Jeder Knoten MIT Kindern ist ein eigener Controller-Scope; toggle() blendet
// ausschliesslich die direkten Kinder dieses Knotens ein/aus (Targets sind auf den
// naechsten Controller gleicher Identitaet gescoped — verschachtelte Baeume funktionieren).
export default class extends Controller {
  static targets = ["children"]

  toggle(event) {
    event.preventDefault()
    if (!this.hasChildrenTarget) return
    const isHidden = this.childrenTarget.classList.toggle("hidden")
    const btn = event.currentTarget
    if (btn) {
      btn.textContent = isHidden ? "▶" : "▼" // ▶ / ▼
      btn.setAttribute("aria-expanded", isHidden ? "false" : "true")
    }
  }
}
