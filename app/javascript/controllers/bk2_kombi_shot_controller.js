import { Controller } from "@hotwired/stimulus"

// BK2-Kombi shot input controller.
//
// Responsibilities:
//   - Packs all form field values into the submit button's dataset before the
//     StimulusReflex fires (data-reflex reads from button.dataset in the reflex)
//   - Generates a UUID shot_sequence_number per click for AdvanceMatchState
//     idempotency guard (T-38.1-13)
//   - 500ms debounce on submit (first-layer T-38.1-13 double-tap protection)
//   - Toggles foul sub-fields visibility when foul checkbox changes
//   - Toggles band_hit row visibility when foul_code changes to/from no_object_ball_hit
//
// B2 FIX: fullPinImage target drives the D-15 `middle_pin_only_from_full_image=2`
//   scoring path. Without this Stimulus target writing btn.dataset.full_pin_image,
//   the reflex always reads "false" and the 2-point rule is unreachable.

export default class extends Controller {
  static targets = [
    "fallenPins",
    "middlePinOnly",
    "fullPinImage",
    "trueCarom",
    "falseCarom",
    "passages",
    "foul",
    "foulCode",
    "bandHit",
    "submit"
  ]

  connect() {
    this.lastSubmitAt = 0
  }

  // Pack all field values into the submit button dataset, then let the
  // data-reflex attribute fire the StimulusReflex action.
  submit(event) {
    const now = Date.now()
    if (now - this.lastSubmitAt < 500) {
      event.preventDefault()
      return
    }
    this.lastSubmitAt = now

    const btn = this.submitTarget

    btn.dataset.fallen_pins = this.fallenPinsTarget.value
    btn.dataset.middle_pin_only = this.middlePinOnlyTarget.checked

    // B2 FIX — populate full_pin_image from the dedicated fullPinImage checkbox
    // target. This field represents the pre-shot table state (all 5 pins standing).
    // Without this assignment the reflex always reads element.dataset["full_pin_image"]
    // as "false", making the D-15 2-point rule completely unreachable.
    btn.dataset.full_pin_image = this.hasFullPinImageTarget
      ? this.fullPinImageTarget.checked
      : false

    btn.dataset.true_carom = this.trueCaromTarget.checked
    btn.dataset.false_carom = this.falseCaromTarget.checked
    btn.dataset.passages = this.passagesTarget.value
    btn.dataset.foul = this.foulTarget.checked
    btn.dataset.foul_code = this.foulTarget.checked && this.hasFoulCodeTarget
      ? this.foulCodeTarget.value
      : ""
    btn.dataset.band_hit = this.hasBandHitTarget ? this.bandHitTarget.checked : false
    btn.dataset.shot_sequence_number = this.generateSequenceNumber()
  }

  // Toggle visibility of foul sub-fields when the foul master checkbox changes.
  toggleFoulFields() {
    const foulChecked = this.foulTarget.checked
    const foulFieldsId = `bk2_foul_fields_${this.element.closest("[data-table-monitor-id]")?.dataset.tableMonitorId || ""}`
    const foulFields = document.getElementById(foulFieldsId) ||
      this.element.querySelector("[id^='bk2_foul_fields_']")
    if (foulFields) {
      foulFields.classList.toggle("hidden", !foulChecked)
    }
    // Reset band_hit row visibility when foul is unchecked
    if (!foulChecked) {
      this.hideBandHitRow()
    }
  }

  // Toggle band_hit row visibility based on foul_code selection.
  toggleBandHit() {
    if (!this.hasFoulCodeTarget) return
    const showBandHit = this.foulCodeTarget.value === "no_object_ball_hit"
    const bandHitRowId = `bk2_band_hit_row_${this.element.closest("[data-table-monitor-id]")?.dataset.tableMonitorId || ""}`
    const bandHitRow = document.getElementById(bandHitRowId) ||
      this.element.querySelector("[id^='bk2_band_hit_row_']")
    if (bandHitRow) {
      bandHitRow.classList.toggle("hidden", !showBandHit)
    }
    // Uncheck band_hit if it becomes hidden
    if (!showBandHit && this.hasBandHitTarget) {
      this.bandHitTarget.checked = false
    }
  }

  hideBandHitRow() {
    const bandHitRowId = `bk2_band_hit_row_${this.element.closest("[data-table-monitor-id]")?.dataset.tableMonitorId || ""}`
    const bandHitRow = document.getElementById(bandHitRowId) ||
      this.element.querySelector("[id^='bk2_band_hit_row_']")
    if (bandHitRow) {
      bandHitRow.classList.add("hidden")
    }
    if (this.hasBandHitTarget) {
      this.bandHitTarget.checked = false
    }
  }

  // Generate a unique shot sequence number for idempotency guard (T-38.1-13).
  // Uses crypto.randomUUID() when available (all modern browsers), otherwise
  // falls back to a timestamp + random suffix.
  generateSequenceNumber() {
    if (window.crypto && window.crypto.randomUUID) {
      return window.crypto.randomUUID()
    }
    return `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }
}
