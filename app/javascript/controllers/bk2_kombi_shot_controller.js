import { Controller } from "@hotwired/stimulus"

// Phase 38.2 Plan 04 — BK2-Kombi shot input controller for the new full-width
// bottom-bar layout (D-15 / D-16). Structural rewrite of the 38.1 Plan 04
// controller; target names + dataset key names + reflex endpoint are UNCHANGED
// so TableMonitorReflex#bk2_kombi_submit_shot reads the same keys.
//
// Responsibilities:
//   - Pack all form field values into the submit button's dataset before the
//     StimulusReflex fires (data-reflex reads btn.dataset in the reflex).
//   - Generate a UUID shot_sequence_number per click for AdvanceMatchState
//     idempotency guard (T-38.1-13).
//   - 500ms debounce on submit (T-38.1-13 double-tap protection).
//   - Toggle foul sub-fields visibility when foul checkbox changes.
//   - Toggle band_hit row visibility when foul_code changes to/from
//     "no_object_ball_hit".
//
// Target names MUST stay identical to 38.1 Plan 04 (fallenPins, middlePinOnly,
// fullPinImage, trueCarom, falseCarom, passages, foul, foulCode, bandHit,
// submit) — the reflex reads dataset keys (underscored) that Stimulus derives
// from these camelCase names.

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

  // Phase 38.2: foul sub-fields container lives in the bottom bar (Row 3)
  // rather than a separate vertical block. ID scheme unchanged.
  toggleFoulFields() {
    const foulChecked = this.foulTarget.checked
    const tid = this.resolveTableMonitorId()
    const foulFields =
      (tid && document.getElementById(`bk2_foul_fields_${tid}`)) ||
      this.element.querySelector("[id^='bk2_foul_fields_']")
    if (foulFields) {
      foulFields.classList.toggle("hidden", !foulChecked)
    }
    if (!foulChecked) {
      this.hideBandHitRow()
    }
  }

  toggleBandHit() {
    if (!this.hasFoulCodeTarget) return
    const showBandHit = this.foulCodeTarget.value === "no_object_ball_hit"
    const tid = this.resolveTableMonitorId()
    const bandHitRow =
      (tid && document.getElementById(`bk2_band_hit_row_${tid}`)) ||
      this.element.querySelector("[id^='bk2_band_hit_row_']")
    if (bandHitRow) {
      bandHitRow.classList.toggle("hidden", !showBandHit)
    }
    if (!showBandHit && this.hasBandHitTarget) {
      this.bandHitTarget.checked = false
    }
  }

  hideBandHitRow() {
    const tid = this.resolveTableMonitorId()
    const bandHitRow =
      (tid && document.getElementById(`bk2_band_hit_row_${tid}`)) ||
      this.element.querySelector("[id^='bk2_band_hit_row_']")
    if (bandHitRow) {
      bandHitRow.classList.add("hidden")
    }
    if (this.hasBandHitTarget) {
      this.bandHitTarget.checked = false
    }
  }

  // Phase 38.2: primary lookup via this.element.dataset.tableMonitorId (Task 1
  // emits data-table-monitor-id on the bar root); fallback via closest() for
  // embedded-use robustness.
  resolveTableMonitorId() {
    return this.element.dataset.tableMonitorId
        || this.element.closest("[data-table-monitor-id]")?.dataset.tableMonitorId
        || ""
  }

  // Generate a unique shot sequence number for idempotency guard (T-38.1-13).
  generateSequenceNumber() {
    if (window.crypto && window.crypto.randomUUID) {
      return window.crypto.randomUUID()
    }
    return `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }
}
