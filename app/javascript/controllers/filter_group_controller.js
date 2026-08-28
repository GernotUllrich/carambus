import { Controller } from "@hotwired/stimulus"

// Eine einklappbare Filtergruppe: eingeklappt steht nur der GEWAEHLTE Wert da, aufgeklappt alle.
//
// Warum ueberhaupt: die Leiste traegt inzwischen fuenf Achsen. Der Gruppen-Selektor kommt im NBV
// auf zehn Werte, der Orts-Selektor im BVNR auf ueber siebzig — ausgeschrieben fuellte die Leiste
// den halben Bildschirm. Eingeklappt bleibt sichtbar, WORAUF gefiltert ist; das ist die
// Information, die man beim Lesen braucht.
//
// Ohne JavaScript bleibt alles aufgeklappt und damit bedienbar: `connect` klappt ein, nicht das
// Markup.
export default class extends Controller {
  static targets = ["options", "summary", "toggle"]
  static values = { open: Boolean }

  connect() {
    // Immer eingeklappt starten: sichtbar bleibt Beschriftung + gewaehlter Wert. Ein erster
    // Entwurf liess Gruppen OHNE Auswahl offen — dann stand die Leiste im Regelfall (nichts
    // gefiltert) weiter ueber vier Zeilen, also genau das, was eingeklappt werden sollte.
    this.openValue = false
    this.render()
  }

  toggle(event) {
    event.preventDefault()
    this.openValue = !this.openValue
    this.render()
  }

  render() {
    // ⚠️ NICHT ueber das `hidden`-Attribut: das Options-Span traegt `inline-flex`, und eine
    // Display-Utility schlaegt die `[hidden]`-Regel aus Tailwinds Preflight — die Optionen
    // blieben sichtbar, obwohl `hidden` gesetzt war. Ein inline `display` gewinnt gegen beides.
    this.optionsTarget.style.display = this.openValue ? "" : "none"
    if (this.hasSummaryTarget) this.summaryTarget.style.display = this.openValue ? "none" : ""
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", String(this.openValue))
  }
}
