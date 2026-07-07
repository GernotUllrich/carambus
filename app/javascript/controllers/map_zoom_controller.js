import { Controller } from "@hotwired/stimulus"

// 08-06: Zoom/Pan fuer die regionale Club-Karte (regions/show). Manipuliert die SVG-viewBox
// (Wheel = Zoom um den Cursor, Drag = Pan), self-contained, KEIN externer Lib. Ab einer
// Zoom-Schwelle werden die Kreis-Marker aus- und die Logo-Ebene eingeblendet (Klassen-Toggle).
// Controller sitzt auf dem <svg>; markers/logos sind Targets darin.
export default class extends Controller {
  static targets = ["markers", "logos"]
  static values = {
    max: { type: Number, default: 8 },       // maximaler Zoom-Faktor gegenueber Ausgangs-viewBox
    threshold: { type: Number, default: 2.2 } // ab diesem Faktor: Kreise -> Logos
  }

  connect() {
    const [x, y, w, h] = this.element.getAttribute("viewBox").split(/[\s,]+/).map(Number)
    this.base = { x, y, w, h }
    this.vb = { x, y, w, h }
    this.dragging = false

    // Handler-Referenzen fuer sauberes Entfernen im disconnect.
    this._onWheel = this.onWheel.bind(this)
    this._onDown = this.onPointerDown.bind(this)
    this._onMove = this.onPointerMove.bind(this)
    this._onUp = this.onPointerUp.bind(this)
    this._onKey = this.onKeydown.bind(this)
    this._onClick = this.onClick.bind(this)

    this.element.addEventListener("wheel", this._onWheel, { passive: false })
    this.element.addEventListener("pointerdown", this._onDown)
    this.element.addEventListener("pointermove", this._onMove)
    this.element.addEventListener("pointerup", this._onUp)
    this.element.addEventListener("pointercancel", this._onUp)
    this.element.addEventListener("pointerleave", this._onUp)
    this.element.addEventListener("keydown", this._onKey)
    this.element.addEventListener("click", this._onClick, true)

    // Logo-Kacheln, die in konstanter Bildschirmgroesse gehalten werden (Gegen-Skalierung).
    this.logoMarkers = this.hasLogosTarget
      ? Array.from(this.logosTarget.querySelectorAll(".js-logo-marker"))
      : []

    this.apply()
  }

  disconnect() {
    this.element.removeEventListener("wheel", this._onWheel)
    this.element.removeEventListener("pointerdown", this._onDown)
    this.element.removeEventListener("pointermove", this._onMove)
    this.element.removeEventListener("pointerup", this._onUp)
    this.element.removeEventListener("pointercancel", this._onUp)
    this.element.removeEventListener("pointerleave", this._onUp)
    this.element.removeEventListener("keydown", this._onKey)
    this.element.removeEventListener("click", this._onClick, true)
  }

  onWheel(e) {
    e.preventDefault()
    const rect = this.element.getBoundingClientRect()
    const mx = rect.width ? (e.clientX - rect.left) / rect.width : 0.5
    const my = rect.height ? (e.clientY - rect.top) / rect.height : 0.5
    this.zoomBy(e.deltaY < 0 ? 1 / 1.15 : 1.15, mx, my)
  }

  // factor < 1 = hineinzoomen (viewBox schrumpft). Ankerpunkt (mx,my) in [0..1] bleibt fix.
  zoomBy(factor, mx = 0.5, my = 0.5) {
    const minW = this.base.w / this.maxValue
    let newW = this.vb.w * factor
    let newH = this.vb.h * factor

    if (newW > this.base.w) { newW = this.base.w; newH = this.base.h }
    else if (newW < minW) { const k = minW / this.vb.w; newW = this.vb.w * k; newH = this.vb.h * k }

    const pointX = this.vb.x + mx * this.vb.w
    const pointY = this.vb.y + my * this.vb.h
    this.vb.x = pointX - mx * newW
    this.vb.y = pointY - my * newH
    this.vb.w = newW
    this.vb.h = newH
    this.apply()
  }

  // Kein sofortiges Pointer-Capture: erst ab einer Bewegungs-Schwelle wird gepannt. Ein reiner
  // Klick (ohne Bewegung) bleibt ein Klick und navigiert zum Club — ein Drag unterdrueckt ihn.
  onPointerDown(e) {
    if (e.button != null && e.button !== 0) return
    this.pointerId = e.pointerId
    this.moved = false
    this.start = { cx: e.clientX, cy: e.clientY, vb: { ...this.vb } }
  }

  onPointerMove(e) {
    if (!this.start || (this.pointerId != null && e.pointerId !== this.pointerId)) return
    const dxRaw = e.clientX - this.start.cx
    const dyRaw = e.clientY - this.start.cy
    if (!this.moved) {
      if (Math.hypot(dxRaw, dyRaw) < 3) return // Schwelle: noch kein Drag
      this.moved = true
      if (this.element.setPointerCapture) this.element.setPointerCapture(this.pointerId)
      this.element.classList.add("cursor-grabbing")
    }
    const rect = this.element.getBoundingClientRect()
    if (!rect.width || !rect.height) return
    const dx = dxRaw / rect.width * this.start.vb.w
    const dy = dyRaw / rect.height * this.start.vb.h
    this.vb.x = this.start.vb.x - dx
    this.vb.y = this.start.vb.y - dy
    this.apply()
  }

  onPointerUp() {
    if (this.pointerId != null && this.element.releasePointerCapture) {
      try { this.element.releasePointerCapture(this.pointerId) } catch (_) { /* ignore */ }
    }
    this.suppressClick = this.moved // war es ein Drag, den folgenden Klick verwerfen
    this.start = null
    this.moved = false
    this.pointerId = null
    this.element.classList.remove("cursor-grabbing")
  }

  // Faengt den Klick NUR nach einem Drag ab (Capture-Phase, vor dem Anchor/Turbo).
  onClick(e) {
    if (this.suppressClick) {
      e.preventDefault()
      e.stopPropagation()
      this.suppressClick = false
    }
  }

  onKeydown(e) {
    if (e.key === "+" || e.key === "=") { e.preventDefault(); this.zoomBy(1 / 1.3) }
    else if (e.key === "-" || e.key === "_") { e.preventDefault(); this.zoomBy(1.3) }
    else if (e.key === "0") { e.preventDefault(); this.reset() }
  }

  // Aktion fuer optionale Buttons (data-action="map-zoom#zoomIn" etc.).
  zoomIn() { this.zoomBy(1 / 1.3) }
  zoomOut() { this.zoomBy(1.3) }
  reset() { this.vb = { ...this.base }; this.apply() }

  apply() {
    const v = this.vb
    this.element.setAttribute(
      "viewBox",
      `${v.x.toFixed(1)} ${v.y.toFixed(1)} ${v.w.toFixed(1)} ${v.h.toFixed(1)}`
    )
    const zoomed = this.base.w / v.w >= this.thresholdValue
    if (this.hasMarkersTarget) this.markersTarget.classList.toggle("hidden", zoomed)
    if (this.hasLogosTarget) this.logosTarget.classList.toggle("hidden", !zoomed)

    // Logo-Kacheln in konstanter Bildschirmgroesse halten: Gegen-Skalierung mit v.w/base.w
    // (beim Reinzoomen schrumpfen sie in Nutzerkoordinaten, bleiben also auf dem Schirm gleich
    // gross -> die auseinanderdriftenden Standorte separieren sich, die Kacheln nicht).
    if (this.logoMarkers && this.logoMarkers.length) {
      const k = (v.w / this.base.w).toFixed(4)
      this.logoMarkers.forEach((g) => {
        g.setAttribute("transform", `translate(${g.dataset.cx} ${g.dataset.cy}) scale(${k})`)
      })
    }
  }
}
