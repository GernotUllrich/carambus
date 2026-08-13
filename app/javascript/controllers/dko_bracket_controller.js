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

  render() {
    const host = this.hostTarget
    const svg = this.svgTarget
    const width = host.scrollWidth
    const height = host.scrollHeight
    if (width === 0 || height === 0) return // Layout noch nicht bereit
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
