import { Controller } from "@hotwired/stimulus"

// Kalender-Strom: haengt weitere Monatskacheln an.
//
// NACH UNTEN automatisch beim Scrollen. NACH OBEN ueber einen Knopf.
//
// Warum oben nicht automatisch — zwei Gruende, beide beim Bauen aufgefallen:
//   1. Ein Sentinel ueber der ersten Kachel steht beim Seitenaufbau bereits im Bild, loest
//      sofort aus und bringt den naechsten ins Bild: eine Endlosschleife vor der ersten
//      Nutzeraktion.
//   2. Schwerer: automatisches Nachladen nach oben macht den Seitenkopf UNERREICHBAR. Wer
//      hochscrollt, loest Nachschub aus, der oben eingefuegt wird — man kommt nie am Scope-Band
//      und an der Filterleiste an. (Die Filterleiste klebt im Strom deshalb zusaetzlich oben.)
//
// Nach unten haette eine Turbo-Sentinel-Kette (<turbo-frame loading="lazy">) ohne eine Zeile
// JavaScript gereicht. Da der Knopf oben ohnehin einen Controller braucht, traegt dieser beide
// Richtungen — zwei Mechanismen fuer dasselbe Verhalten kosten bei jeder Aenderung doppelt.
//
// Die Erstladung steht serverseitig im HTML; ohne JavaScript bleibt sie sichtbar.
export default class extends Controller {
  static targets = ["tiles", "bottom", "earlier", "topNotice", "bottomNotice"]
  static values = { url: String, batch: { type: Number, default: 6 } }

  connect() {
    this.busy = { top: false, bottom: false }
    this.done = { top: false, bottom: false }
    this.bottomObserver = this.observe(this.bottomTarget, () => this.load("bottom"))
  }

  disconnect() {
    this.bottomObserver?.disconnect()
  }

  // Knopf "frühere Monate laden".
  loadEarlier(event) {
    event.preventDefault()
    this.load("top")
  }

  observe(element, onVisible) {
    const observer = new IntersectionObserver(
      (entries) => entries.forEach((entry) => entry.isIntersecting && onVisible()),
      { rootMargin: "400px" }
    )
    observer.observe(element)
    return observer
  }

  // Aeusserste bzw. unterste Kachel — von dort aus wird weitergezaehlt.
  edgeMonth(direction) {
    const tiles = this.tilesTarget.querySelectorAll("[data-month]")
    if (tiles.length === 0) return null
    const tile = direction === "top" ? tiles[0] : tiles[tiles.length - 1]
    return tile.dataset.month
  }

  async load(direction) {
    if (this.busy[direction] || this.done[direction]) return
    const from = this.edgeMonth(direction)
    if (!from) return

    this.busy[direction] = true
    try {
      const count = direction === "top" ? -this.batchValue : this.batchValue
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("from", from)
      url.searchParams.set("count", String(count))
      // Die Achsen stehen im URL der Seite; der Ausschnitt kommt aus der Session.
      new URLSearchParams(window.location.search).forEach((value, key) => {
        if (["dbu", "kind", "group", "discipline"].includes(key)) url.searchParams.set(key, value)
      })

      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok) return this.finish(direction)

      const html = (await response.text()).trim()
      // ⚠️ NICHT auf einen leeren String pruefen. Rails umschliesst Partials im Development mit
      // Kommentaren (`annotate_rendered_view_with_filenames`) — eine "leere" Antwort ist dort
      // rund 110 Zeichen lang. Ein `html === ""` haette in Production funktioniert und im
      // Development nicht. Geprueft wird deshalb, ob wirklich eine Kachel drin steckt.
      if (!html.includes("data-month=")) return this.finish(direction)

      this.insert(direction, html)
    } catch (error) {
      // Ein fehlgeschlagener Nachschub darf den Strom nicht kaputt lassen: Richtung schliessen,
      // die bereits geladenen Kacheln bleiben stehen.
      console.warn("[calendar-stream] Nachladen fehlgeschlagen:", error)
      this.finish(direction)
    } finally {
      this.busy[direction] = false
    }
  }

  insert(direction, html) {
    if (direction === "bottom") {
      this.tilesTarget.insertAdjacentHTML("beforeend", html)
      return
    }

    // Oben einfuegen. Weil das eine ausdrueckliche Nutzeraktion ist (Knopf), wird das Ergebnis
    // GEZEIGT, statt die Leseposition zu halten — sonst klickt man und scheinbar passiert nichts.
    // Angesteuert wird die erste neue Kachel; von dort laeuft der neue Block nach unten.
    const bisher = this.tilesTarget.querySelector("[data-month]")
    this.tilesTarget.insertAdjacentHTML("afterbegin", html)
    const ersteNeue = this.tilesTarget.querySelector("[data-month]")
    if (ersteNeue && ersteNeue !== bisher) ersteNeue.scrollIntoView({ block: "start" })
  }

  finish(direction) {
    this.done[direction] = true
    if (direction === "top") {
      this.earlierTarget.hidden = true
      this.topNoticeTarget.hidden = false
    } else {
      this.bottomObserver?.disconnect()
      this.bottomNoticeTarget.hidden = false
    }
  }
}
