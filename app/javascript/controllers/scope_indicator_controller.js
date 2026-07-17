import { Controller } from "@hotwired/stimulus"

// Region-Indikator im Sidebar-Kopf: reine Anzeige. Klick scrollt zum Scope-Band (#scope-band)
// und hebt es kurz hervor. Kein State, kein Fetch, keine Navigation — der einzige Umschalter
// bleibt das Band selbst (Single Source = ScopeResolver/session[:scope]).
export default class extends Controller {
  focus(event) {
    event.preventDefault()

    const band = document.getElementById("scope-band")
    if (!band) return

    band.scrollIntoView({ behavior: "smooth", block: "start" })

    // Transienter Highlight (idempotent: laufenden Timer clearen).
    const flash = ["ring-2", "ring-inset", "ring-primary-500"]
    band.classList.add(...flash)
    if (this.flashTimer) clearTimeout(this.flashTimer)
    this.flashTimer = setTimeout(() => band.classList.remove(...flash), 1500)
  }

  disconnect() {
    if (this.flashTimer) clearTimeout(this.flashTimer)
  }
}
