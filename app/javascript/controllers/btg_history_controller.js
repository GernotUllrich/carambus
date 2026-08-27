import { Controller } from "@hotwired/stimulus"

// Zeichnet den BTG-Verlauf mehrerer Spieler ueber die Saisons und stellt darunter
// eine anklickbare Spielerliste bereit.
//
// Bedienung: Sichtbar sind zunaechst nur die besten VISIBLE_BY_DEFAULT Spieler -- bei 20
// Linien mit vielen Luecken waere das Bild sonst unlesbar. Ein Klick auf einen Spieler
// nimmt ihn dazu und waehlt ihn aus, ein erneuter Klick nimmt ihn wieder zurueck.
// Ein Klick auf einen der voreingestellten Spieler waehlt ihn nur aus -- er bleibt sichtbar.
//
// Die Auswahl ist eine Menge: Mehrere Spieler koennen gleichzeitig ausgewaehlt sein, um sie
// zu vergleichen. Die Y-Achse richtet sich dann nach der Auswahl -- ohne das wuerde ein
// einzelner Ausreisser alle uebrigen Linien an den unteren Rand druecken.
//
// Erwartet payload = { seasons: [...], players: [{ id, name, values: [...] }] },
// players absteigend nach aktuellem BTG sortiert.
// values enthaelt je Saison den BTG oder null -- null unterbricht die Linie (spanGaps: false),
// weil ein fehlender Wert nicht als Verlauf interpoliert werden darf.
export default class extends Controller {
  static targets = ["canvas", "legend", "toggleAll", "clearSelection"]
  static values = { payload: Object }

  // Kategoriale Palette; bewusst gesaettigt, damit die Linien auf hellem wie dunklem
  // Grund unterscheidbar bleiben. Canvas kennt keine CSS-Klassen, daher Farbwerte.
  static PALETTE = [
    "#2563eb", "#dc2626", "#16a34a", "#d97706", "#7c3aed",
    "#0891b2", "#db2777", "#65a30d", "#ea580c", "#4f46e5",
    "#0d9488", "#be123c", "#a16207", "#a21caf", "#1d4ed8",
    "#b45309", "#15803d", "#9f1239", "#6d28d9", "#0369a1"
  ]

  static VISIBLE_BY_DEFAULT = 5

  async connect() {
    // Chart.js kommt per <script> aus der Seite. Bei Turbo-Navigation tauscht Turbo den
    // Body aus und Stimulus verbindet sofort -- das Script ist dann noch nicht ausgefuehrt.
    // Deshalb warten statt aufgeben, sonst bliebe das Diagramm bei jedem Aufruf ueber
    // einen Link leer (beim direkten Seitenaufruf faellt das nicht auf).
    if (!(await this.waitForChartJs())) {
      console.warn("[btg-history] Chart.js nicht verfuegbar - Diagramm wird uebersprungen")
      return
    }
    if (!this.element.isConnected) return // waehrend des Wartens weggeraeumt

    this.selected = new Set()
    this.defaultIds = new Set(
      this.players.slice(0, this.constructor.VISIBLE_BY_DEFAULT).map((p) => p.id)
    )
    this.visible = new Set(this.defaultIds)

    this.buildChart()
    this.buildLegend()
    this.render()

    // Achsen-/Gitterfarben haengen am Theme; auf Umschalten reagieren, ohne Reload.
    this.themeObserver = new MutationObserver(() => this.applyThemeColors())
    this.themeObserver.observe(document.documentElement, {
      attributes: true, attributeFilter: ["class"]
    })
  }

  disconnect() {
    if (this.chartWaitTimer) clearInterval(this.chartWaitTimer)
    this.themeObserver?.disconnect()
    this.chart?.destroy()
    this.chart = null
  }

  // Wartet, bis Chart.js im window steht. Aufloesung mit true/false statt Exception,
  // damit ein fehlendes Script das Diagramm still ueberspringt und die Seite nicht bricht.
  waitForChartJs(timeoutMs = 10000, intervalMs = 50) {
    if (typeof window.Chart !== "undefined") return Promise.resolve(true)

    return new Promise((resolve) => {
      const startedAt = Date.now()
      this.chartWaitTimer = setInterval(() => {
        if (typeof window.Chart !== "undefined") {
          clearInterval(this.chartWaitTimer)
          this.chartWaitTimer = null
          resolve(true)
        } else if (Date.now() - startedAt > timeoutMs) {
          clearInterval(this.chartWaitTimer)
          this.chartWaitTimer = null
          resolve(false)
        }
      }, intervalMs)
    })
  }

  // --- Aufbau -------------------------------------------------------------

  get players() { return this.payloadValue.players || [] }
  get seasons() { return this.payloadValue.seasons || [] }

  colorFor(index) {
    return this.constructor.PALETTE[index % this.constructor.PALETTE.length]
  }

  buildChart() {
    const datasets = this.players.map((player, index) => ({
      label: player.name,
      data: player.values,
      playerId: player.id,
      borderColor: this.colorFor(index),
      backgroundColor: this.colorFor(index),
      borderWidth: 2,
      pointRadius: 2,
      pointHoverRadius: 5,
      tension: 0.2,
      spanGaps: false
    }))

    this.chart = new window.Chart(this.canvasTarget, {
      type: "line",
      data: { labels: this.seasons, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "nearest", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y}`
            }
          }
        },
        scales: {
          x: { ticks: { maxRotation: 60, minRotation: 45, autoSkip: true } },
          y: { beginAtZero: false, title: { display: true, text: "BTG" } }
        }
      }
    })

    this.applyThemeColors()
  }

  buildLegend() {
    this.legendTarget.replaceChildren()

    this.players.forEach((player, index) => {
      const button = document.createElement("button")
      button.type = "button"
      button.dataset.playerId = player.id

      const dot = document.createElement("span")
      dot.className = "inline-block w-2.5 h-2.5 rounded-full shrink-0"
      dot.style.backgroundColor = this.colorFor(index)
      dot.dataset.role = "dot"

      const label = document.createElement("span")
      label.textContent = player.name

      button.append(dot, label)
      button.addEventListener("click", () => this.toggle(player.id))
      this.legendTarget.appendChild(button)
    })
  }

  // --- Interaktion --------------------------------------------------------

  // Ein Klick bedeutet je nach Zustand: dazunehmen (und auswaehlen), auswaehlen,
  // oder zurueck in den Ausgangszustand. Mehrere Spieler koennen gleichzeitig
  // ausgewaehlt sein -- das ist der Vergleichsfall.
  toggle(playerId) {
    if (!this.visible.has(playerId)) {
      this.visible.add(playerId)
      this.selected.add(playerId)
    } else if (this.selected.has(playerId)) {
      this.selected.delete(playerId)
      if (!this.defaultIds.has(playerId)) this.visible.delete(playerId)
    } else {
      this.selected.add(playerId)
    }
    this.render()
  }

  clearSelection() {
    this.selected.clear()
    this.render()
  }

  // Umschalter im Kopf: alle Spieler zeigen bzw. auf die Voreinstellung zuruecksetzen.
  toggleAll() {
    if (this.visible.size === this.players.length) {
      this.visible = new Set(this.defaultIds)
      this.selected = new Set([...this.selected].filter((id) => this.visible.has(id)))
    } else {
      this.visible = new Set(this.players.map((p) => p.id))
    }
    this.render()
  }

  // --- Darstellung --------------------------------------------------------

  render() {
    this.chart.data.datasets.forEach((dataset, index) => {
      const base = this.colorFor(index)
      const shown = this.visible.has(dataset.playerId)
      const isSelected = this.selected.has(dataset.playerId)
      const dimmed = shown && this.selected.size > 0 && !isSelected

      dataset.hidden = !shown
      dataset.borderColor = dimmed ? this.fade(base, 0.2) : base
      dataset.backgroundColor = dataset.borderColor
      dataset.borderWidth = isSelected ? 4 : dimmed ? 1 : 2
      dataset.pointRadius = isSelected ? 4 : dimmed ? 0 : 2
      dataset.order = isSelected ? 0 : 1
    })

    this.applyYRange()
    this.chart.update()

    this.legendTarget.querySelectorAll("button").forEach((button) => {
      const id = Number(button.dataset.playerId)
      const shown = this.visible.has(id)
      const isSelected = this.selected.has(id)
      button.className = this.legendClasses(shown, isSelected)
      button.setAttribute("aria-pressed", isSelected ? "true" : "false")
      const dot = button.querySelector('[data-role="dot"]')
      if (dot) dot.style.opacity = shown ? "1" : "0.35"
    })

    if (this.hasToggleAllTarget) {
      this.toggleAllTarget.textContent =
        this.visible.size === this.players.length ? "Nur die besten 5" : "Alle anzeigen"
    }
    if (this.hasClearSelectionTarget) {
      this.clearSelectionTarget.classList.toggle("hidden", this.selected.size === 0)
      this.clearSelectionTarget.textContent =
        this.selected.size > 1 ? `Auswahl aufheben (${this.selected.size})` : "Auswahl aufheben"
    }
  }

  legendClasses(shown, selected) {
    const base = "inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs border transition-colors"
    if (selected) {
      return `${base} border-primary-500 bg-primary-50 text-primary-900 dark:bg-primary-900 dark:text-primary-100 font-semibold`
    }
    if (shown) {
      return `${base} border-gray-300 text-gray-700 hover:bg-gray-100 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700`
    }
    // Nicht gezeichnet: zurueckgenommen, aber weiterhin anklickbar.
    return `${base} border-dashed border-gray-300 text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:border-gray-700 dark:text-gray-500 dark:hover:bg-gray-700 dark:hover:text-gray-300`
  }

  // Ein einzelner Ausreisser staucht sonst alle uebrigen Linien an den unteren Rand.
  // Ist etwas ausgewaehlt, richtet sich die Skala nach der Auswahl, sonst nach allem
  // Sichtbaren. Ohne Werte bleibt die Automatik von Chart.js zustaendig.
  applyYRange() {
    const ids = this.selected.size > 0 ? this.selected : this.visible
    const werte = []
    this.chart.data.datasets.forEach((dataset) => {
      if (!ids.has(dataset.playerId)) return
      dataset.data.forEach((value) => {
        if (value !== null && value !== undefined) werte.push(value)
      })
    })

    const scale = this.chart.options.scales.y
    if (werte.length === 0) {
      delete scale.min
      delete scale.max
      return
    }

    const min = Math.min(...werte)
    const max = Math.max(...werte)
    const padding = (max - min) * 0.1 || Math.abs(max) * 0.1 || 1
    scale.min = Math.max(0, min - padding)
    scale.max = max + padding
  }

  fade(hex, alpha) {
    const value = parseInt(hex.slice(1), 16)
    const r = (value >> 16) & 255
    const g = (value >> 8) & 255
    const b = value & 255
    return `rgba(${r}, ${g}, ${b}, ${alpha})`
  }

  applyThemeColors() {
    if (!this.chart) return

    const dark = document.documentElement.classList.contains("dark")
    const tick = dark ? "#9ca3af" : "#4b5563"
    const grid = dark ? "rgba(156, 163, 175, 0.2)" : "rgba(107, 114, 128, 0.2)"

    const { scales } = this.chart.options
    for (const axis of [scales.x, scales.y]) {
      axis.ticks = { ...axis.ticks, color: tick }
      axis.grid = { ...axis.grid, color: grid }
    }
    scales.y.title.color = tick
    this.chart.update("none")
  }
}
