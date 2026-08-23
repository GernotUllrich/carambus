import { Controller } from "@hotwired/stimulus"

// Bundesweiter Vergleich einer Disziplin. Drei Arten von Linien:
//
//   1. Median Deutschland -- dicke graue Bezugslinie, immer sichtbar. Der Abstand einer
//      Spielerlinie zu ihr ist die eigentliche Aussage ("wie weit ueber dem Schnitt").
//      Enthaelt NUR die Landesverbaende (siehe 4.).
//   2. Spieler -- die besten des Landes, durchgezogen, anfangs alle sichtbar.
//   3. Landesverbaende -- deren Mediane, gestrichelt, anfangs ausgeblendet. Zugeschaltet
//      beantworten sie die zweite Frage: wie stehen die Verbaende zueinander?
//   4. Dachverband (DBU) -- eigene violette Bezugslinie, "nationales Niveau". Bewusst NICHT
//      im Median und nicht in der Verbandsliste: Dort spielen die Qualifizierten, nicht der
//      Querschnitt, und viele sind zusaetzlich in ihrem Landesverband gelistet.
//
// Auswahl ist eine Menge (mehrere gleichzeitig moeglich); die Y-Achse richtet sich nach der
// Auswahl, sonst nach allem Sichtbaren -- sonst druecken einzelne Ausreisser alles zusammen.
export default class extends Controller {
  static targets = ["canvas", "playerLegend", "regionLegend", "clearSelection"]
  static values = { payload: Object }

  static PLAYER_PALETTE = [
    "#2563eb", "#dc2626", "#16a34a", "#d97706", "#7c3aed",
    "#0891b2", "#db2777", "#65a30d", "#ea580c", "#4f46e5"
  ]

  static REGION_PALETTE = [
    "#0f766e", "#9f1239", "#4338ca", "#a16207", "#6d28d9",
    "#b91c1c", "#15803d", "#0369a1", "#a21caf", "#c2410c"
  ]

  static MEDIAN_KEY = "median"
  static ROOF_KEY = "roof"

  async connect() {
    // Siehe btg_history_controller: bei Turbo-Navigation ist das Chart.js-Script beim
    // Verbinden noch nicht ausgefuehrt, deshalb warten statt aufgeben.
    if (!(await this.waitForChartJs())) {
      console.warn("[national-history] Chart.js nicht verfuegbar - Diagramm wird uebersprungen")
      return
    }
    if (!this.element.isConnected) return

    this.selected = new Set()
    this.visible = new Set([
      this.constructor.MEDIAN_KEY,
      ...(this.roofMedian ? [this.constructor.ROOF_KEY] : []),
      ...this.players.map((_, i) => `p:${i}`)
    ])

    this.buildChart()
    this.buildLegends()
    this.render()

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

  get seasons() { return this.payloadValue.seasons || [] }
  get players() { return this.payloadValue.players || [] }
  get regions() { return this.payloadValue.regions || [] }
  get nationalMedian() { return this.payloadValue.national_median || [] }
  get roofMedian() { return this.payloadValue.roof_median || null }
  get roofName() { return this.payloadValue.roof_name || "DBU" }

  playerColor(i) {
    const p = this.constructor.PLAYER_PALETTE
    return p[i % p.length]
  }

  regionColor(i) {
    const p = this.constructor.REGION_PALETTE
    return p[i % p.length]
  }

  buildChart() {
    const datasets = [
      {
        key: this.constructor.MEDIAN_KEY,
        label: "Median Deutschland",
        data: this.nationalMedian,
        borderColor: "#6b7280",
        backgroundColor: "#6b7280",
        borderWidth: 3,
        borderDash: [6, 3],
        pointRadius: 0,
        tension: 0.2,
        spanGaps: false
      },
      ...(this.roofMedian ? [{
        key: this.constructor.ROOF_KEY,
        label: `${this.roofName} (Median) — nationales Niveau`,
        data: this.roofMedian,
        borderColor: "#9333ea",
        backgroundColor: "#9333ea",
        borderWidth: 3,
        borderDash: [10, 4],
        pointRadius: 0,
        tension: 0.2,
        spanGaps: false
      }] : []),
      ...this.players.map((player, i) => ({
        key: `p:${i}`,
        label: player.region ? `${player.name} (${player.region})` : player.name,
        data: player.values,
        borderColor: this.playerColor(i),
        backgroundColor: this.playerColor(i),
        borderWidth: 2,
        pointRadius: 2,
        pointHoverRadius: 5,
        tension: 0.2,
        spanGaps: false
      })),
      ...this.regions.map((region, i) => ({
        key: `r:${i}`,
        label: `${region.name} (Median)`,
        data: region.values,
        borderColor: this.regionColor(i),
        backgroundColor: this.regionColor(i),
        borderWidth: 2,
        borderDash: [3, 3],
        pointRadius: 0,
        tension: 0.2,
        spanGaps: false
      }))
    ]

    this.chart = new window.Chart(this.canvasTarget, {
      type: "line",
      data: { labels: this.seasons, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "nearest", intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: { callbacks: { label: (ctx) => `${ctx.dataset.label}: ${ctx.parsed.y}` } }
        },
        scales: {
          x: { ticks: { maxRotation: 60, minRotation: 45, autoSkip: true } },
          y: { beginAtZero: false, title: { display: true, text: "BTG" } }
        }
      }
    })

    this.applyThemeColors()
  }

  buildLegends() {
    this.playerLegendTarget.replaceChildren()
    this.regionLegendTarget.replaceChildren()

    // Der Median steht bei den Spielern vorn -- er ist deren Bezugsgroesse.
    this.playerLegendTarget.appendChild(
      this.legendButton(this.constructor.MEDIAN_KEY, "Median Deutschland", "#6b7280")
    )
    if (this.roofMedian) {
      this.playerLegendTarget.appendChild(
        this.legendButton(this.constructor.ROOF_KEY, `${this.roofName} (Median)`, "#9333ea")
      )
    }
    this.players.forEach((player, i) => {
      const label = player.region ? `${player.name} · ${player.region}` : player.name
      this.playerLegendTarget.appendChild(this.legendButton(`p:${i}`, label, this.playerColor(i)))
    })
    this.regions.forEach((region, i) => {
      this.regionLegendTarget.appendChild(this.legendButton(`r:${i}`, region.name, this.regionColor(i)))
    })
  }

  legendButton(key, text, color) {
    const button = document.createElement("button")
    button.type = "button"
    button.dataset.key = key

    const dot = document.createElement("span")
    dot.className = "inline-block w-2.5 h-2.5 rounded-full shrink-0"
    dot.style.backgroundColor = color
    dot.dataset.role = "dot"

    const label = document.createElement("span")
    label.textContent = text

    button.append(dot, label)
    button.addEventListener("click", () => this.toggle(key))
    return button
  }

  // --- Interaktion --------------------------------------------------------

  toggle(key) {
    if (!this.visible.has(key)) {
      this.visible.add(key)
      this.selected.add(key)
    } else if (this.selected.has(key)) {
      this.selected.delete(key)
      // Der Median bleibt als Bezugslinie stehen, alles andere darf sich ausblenden.
      if (key !== this.constructor.MEDIAN_KEY && key !== this.constructor.ROOF_KEY) {
        this.visible.delete(key)
      }
    } else {
      this.selected.add(key)
    }
    this.render()
  }

  clearSelection() {
    this.selected.clear()
    this.render()
  }

  // --- Darstellung --------------------------------------------------------

  render() {
    this.chart.data.datasets.forEach((dataset) => {
      const shown = this.visible.has(dataset.key)
      const isSelected = this.selected.has(dataset.key)
      const dimmed = shown && this.selected.size > 0 && !isSelected
      const isMedian = dataset.key === this.constructor.MEDIAN_KEY ||
                       dataset.key === this.constructor.ROOF_KEY
      const base = dataset.key === this.constructor.MEDIAN_KEY
        ? "#6b7280"
        : dataset.key === this.constructor.ROOF_KEY
          ? "#9333ea"
          : dataset.key.startsWith("p:")
            ? this.playerColor(Number(dataset.key.slice(2)))
            : this.regionColor(Number(dataset.key.slice(2)))

      dataset.hidden = !shown
      dataset.borderColor = dimmed ? this.fade(base, 0.18) : base
      dataset.backgroundColor = dataset.borderColor
      dataset.borderWidth = isSelected ? 4 : dimmed ? 1 : isMedian ? 3 : 2
      dataset.pointRadius = isSelected && !isMedian ? 4 : dimmed || isMedian ? 0 : 2
      dataset.order = isSelected ? 0 : 1
    })

    this.applyYRange()
    this.chart.update()

    const all = [...this.playerLegendTarget.children, ...this.regionLegendTarget.children]
    all.forEach((button) => {
      const key = button.dataset.key
      const shown = this.visible.has(key)
      const isSelected = this.selected.has(key)
      button.className = this.legendClasses(shown, isSelected)
      button.setAttribute("aria-pressed", isSelected ? "true" : "false")
      const dot = button.querySelector('[data-role="dot"]')
      if (dot) dot.style.opacity = shown ? "1" : "0.35"
    })

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
    return `${base} border-dashed border-gray-300 text-gray-400 hover:bg-gray-100 hover:text-gray-600 dark:border-gray-700 dark:text-gray-500 dark:hover:bg-gray-700 dark:hover:text-gray-300`
  }

  // Ist etwas ausgewaehlt, richtet sich die Skala danach, sonst nach allem Sichtbaren.
  applyYRange() {
    const keys = this.selected.size > 0 ? this.selected : this.visible
    const werte = []
    this.chart.data.datasets.forEach((dataset) => {
      if (!keys.has(dataset.key)) return
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
