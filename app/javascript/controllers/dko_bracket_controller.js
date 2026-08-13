import { Controller } from "@hotwired/stimulus"

// Zeichnet die Bracket-Verbindungslinien eines Doppel-K.-o.-Diagramms als SVG-Overlay.
// Die Kanten kommen aus dem Server (regional_dko_bracket → dko_edges): [{from, to, kind}].
// Positionen werden aus den DOM-Boxen der Match-Zellen ([data-game-id]) gemessen, damit
// das Layout (Flex-Spalten) frei bleibt und die Linien den echten Spielerfluss abbilden.
export default class extends Controller {
  static targets = ["svg", "host"]
  static values = { edges: Array }

  connect() {
    this.render = this.render.bind(this)
    this.resizeObserver = new ResizeObserver(this.render)
    this.resizeObserver.observe(this.hostTarget)
    window.addEventListener("resize", this.render)
    document.addEventListener("turbo:load", this.render)
    // Mehrfach anstoßen: sofort, nach dem Layout, und als Fallback verzögert —
    // rAF/ResizeObserver können verzögern, wenn die Seite beim connect noch nicht sichtbar ist.
    this.render()
    requestAnimationFrame(this.render)
    this.retryTimer = setTimeout(this.render, 200)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    window.removeEventListener("resize", this.render)
    document.removeEventListener("turbo:load", this.render)
    clearTimeout(this.retryTimer)
  }

  // Positioniert jede Runde vertikal zentriert zwischen ihren Speisern (klassische
  // Bracket-Optik). Y einer Runde = Mittel der Speiser-Y aus den Kanten desselben Bandes;
  // die erste Runde stapelt gleichmäßig. Getrennt je Band (Gewinner/Verlierer), damit die
  // Verliererrunden ihrer eigenen Kette folgen (nicht dem Abstieg aus dem Gewinnerbaum).
  layout() {
    const GAP = 16
    const node = {} // gameId -> { h }
    const parentsByChild = {} // gameId -> [parentGameId] (nur gleiches Band)

    // Bänder + Spalten einlesen, Höhen messen
    const bands = [...this.hostTarget.querySelectorAll("[data-band]")].map((band) => {
      const bandKey = band.dataset.band
      const cols = [...band.querySelectorAll("[data-dko-col]")].map((col) => {
        const wrap = col.querySelector("[data-dko-matches]") || col
        const matches = [...wrap.querySelectorAll("[data-game-id]")]
        matches.forEach((el) => {
          node[el.dataset.gameId] = { h: el.offsetHeight, band: bandKey }
        })
        return { wrap, matches }
      })
      return { cols }
    })

    // Kanten desselben Bandes als Layout-Eltern
    for (const edge of this.edgesValue) {
      const from = node[edge.from]
      const to = node[edge.to]
      if (!from || !to || from.band !== to.band) continue
      ;(parentsByChild[edge.to] ||= []).push(edge.from)
    }

    // je Band: Spalten links→rechts, Zentren zuweisen, Überlappungen auflösen
    const center = {}
    for (const band of bands) {
      for (const { wrap, matches } of band.cols) {
        const desired = matches.map((el) => {
          const ps = (parentsByChild[el.dataset.gameId] || [])
            .map((pid) => center[pid])
            .filter((v) => v != null)
          return ps.length ? ps.reduce((a, b) => a + b, 0) / ps.length : null
        })

        // fehlende (erste Runde / Freilose) gleichmäßig stapeln
        let cursor = 0
        matches.forEach((el, i) => {
          const h = node[el.dataset.gameId].h
          if (desired[i] == null) desired[i] = cursor + h / 2
          cursor = Math.max(cursor, desired[i] + h / 2) + GAP
        })

        // Überlappungen in Reihenfolge auflösen (nach unten schieben)
        const order = matches.map((_, i) => i).sort((a, b) => desired[a] - desired[b])
        let prevBottom = -Infinity
        for (const i of order) {
          const h = node[matches[i].dataset.gameId].h
          if (desired[i] - h / 2 < prevBottom + GAP) desired[i] = prevBottom + GAP + h / 2
          prevBottom = desired[i] + h / 2
        }

        // anwenden
        let colHeight = 0
        matches.forEach((el, i) => {
          const h = node[el.dataset.gameId].h
          el.style.position = "absolute"
          el.style.left = "0"
          el.style.right = "0"
          el.style.top = `${desired[i] - h / 2}px`
          center[el.dataset.gameId] = desired[i]
          colHeight = Math.max(colHeight, desired[i] + h / 2)
        })
        wrap.style.position = "relative"
        wrap.style.height = `${colHeight}px`
      }
    }
  }

  render() {
    const host = this.hostTarget
    const svg = this.svgTarget
    if (host.offsetWidth === 0) return // Layout noch nicht bereit

    this.layout()

    const width = host.scrollWidth
    const height = host.scrollHeight
    if (width === 0 || height === 0) return
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
    svg.setAttribute("width", width)
    svg.setAttribute("height", height)

    const origin = host.getBoundingClientRect()
    const pos = {}
    host.querySelectorAll("[data-game-id]").forEach((el) => {
      const box = el.getBoundingClientRect()
      pos[el.dataset.gameId] = {
        left: box.left - origin.left,
        right: box.right - origin.left,
        midY: box.top - origin.top + box.height / 2
      }
    })

    const ns = "http://www.w3.org/2000/svg"
    while (svg.firstChild) svg.removeChild(svg.firstChild)

    for (const edge of this.edgesValue) {
      const a = pos[edge.from]
      const b = pos[edge.to]
      if (!a || !b) continue

      const x1 = a.right
      const y1 = a.midY
      const x2 = b.left
      const y2 = b.midY
      const mx = x1 + (x2 - x1) / 2

      const path = document.createElementNS(ns, "path")
      path.setAttribute("d", `M ${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`)
      path.setAttribute("fill", "none")
      path.setAttribute("stroke", "currentColor")
      path.setAttribute("stroke-width", "1.5")
      if (edge.kind === "loss") {
        path.setAttribute("stroke-dasharray", "4 3")
        path.setAttribute("opacity", "0.45")
      } else {
        path.setAttribute("opacity", "0.8")
      }
      svg.appendChild(path)
    }
  }
}
