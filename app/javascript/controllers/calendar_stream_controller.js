import { Controller } from "@hotwired/stimulus"

// Kalender-Strom: haengt beim Scrollen weitere Monatskacheln an — nach unten spaetere, nach
// oben fruehere.
//
// ⚠️ Nach OBEN ist das eine Falle, die schon einmal zugeschnappt ist: das Nachladen haelt die
// Leseposition, also schiebt jeder Hochscroll-Versuch neuen Inhalt davor. Der Seitenkopf mit
// Scope-Band und Filterleiste ist dadurch NICHT mehr durch Scrollen erreichbar. Das ist der
// Preis dafuer, dass man ueberhaupt in die Vergangenheit scrollen kann — der Betreiber hat ihn
// am 2026-08-27 bewusst gewaehlt. Der Ausweg ist der feste "Anfang"-Knopf oben rechts, der
// die Seite neu laedt; ohne ihn waere dieser Controller eine Sackgasse.
//
// Zwei Fallstricke, beide beim Bauen aufgetreten:
//   1. Ein Sentinel ueber der ersten Kachel steht beim Seitenaufbau bereits im Bild und loest
//      sofort aus — er wird deshalb erst nach der ersten Scrollbewegung scharf.
//   2. Oben eingefuegter Inhalt verschiebt alles darunter. Gemessen wird die GESAMTHOEHE des
//      Dokuments vor und nach dem Einfuegen, nicht die Hoehe des Fragments: das Grid fliesst
//      beim Einfuegen um. Ohne diese Korrektur sprang der gelesene Monat 11736 px weg.
//
// Die Erstladung steht serverseitig im HTML; ohne JavaScript bleibt sie sichtbar.
export default class extends Controller {
  static targets = ["tiles", "top", "bottom", "topNotice", "bottomNotice", "back"]
  static values = { url: String, batch: { type: Number, default: 6 }, backAfter: { type: Number, default: 200 } }

  connect() {
    this.busy = { top: false, bottom: false }
    this.done = { top: false, bottom: false }

    this.bottomObserver = this.observe(this.bottomTarget, () => this.load("bottom"))

    // Der obere Sentinel wird ERST nach der ersten Scrollbewegung scharf (Fallstrick 1).
    this.armTop = () => {
      window.removeEventListener("scroll", this.armTop)
      this.topObserver = this.observe(this.topTarget, () => this.load("top"))
    }
    window.addEventListener("scroll", this.armTop, { once: true, passive: true })

    // Der feste Knopf erscheint erst, wenn die Leisten oben weggescrollt sind — davor waere er
    // nur im Weg, er laege ueber dem Scope-Band.
    this.toggleBack = () => {
      if (this.hasBackTarget) this.backTarget.hidden = window.scrollY < this.backAfterValue
    }
    this.toggleBack()
    window.addEventListener("scroll", this.toggleBack, { passive: true })
  }

  disconnect() {
    this.bottomObserver?.disconnect()
    this.topObserver?.disconnect()
    window.removeEventListener("scroll", this.armTop)
    window.removeEventListener("scroll", this.toggleBack)
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

    // Fallstrick 2: ueber die Gesamthoehe messen, nicht ueber die Fragmenthoehe.
    const before = document.documentElement.scrollHeight
    this.tilesTarget.insertAdjacentHTML("afterbegin", html)
    window.scrollBy(0, document.documentElement.scrollHeight - before)
  }

  finish(direction) {
    this.done[direction] = true
    if (direction === "top") {
      this.topObserver?.disconnect()
      this.topNoticeTarget.hidden = false
    } else {
      this.bottomObserver?.disconnect()
      this.bottomNoticeTarget.hidden = false
    }
  }
}
