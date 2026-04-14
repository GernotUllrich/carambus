import { Controller } from "@hotwired/stimulus"

// Shared Confirmation Modal (D-15)
// Wird von UI-06 (Reset-Sicherheitsabfrage) und UI-07 (Parameter-Verifikation) wiederverwendet.
//
// Markup-Vertrag (siehe app/views/shared/_confirmation_modal.html.erb):
//   <div data-controller="confirmation-modal"
//        data-confirmation-modal-target="root"
//        data-confirmation-modal-auto-open-value="false"
//        data-confirmation-modal-hidden-override-name-value=""
//        data-confirmation-modal-hidden-override-reset-on-cancel-value="true"
//        class="hidden fixed inset-0 ...">
//     <div data-confirmation-modal-target="dialog">
//       <h3 data-confirmation-modal-target="title"></h3>
//       <div data-confirmation-modal-target="body"></div>
//       <button data-action="click->confirmation-modal#cancel">Cancel</button>
//       <button data-confirmation-modal-target="confirmButton"
//               data-action="click->confirmation-modal#confirm">Confirm</button>
//     </div>
//   </div>
//
// Click-Trigger (UI-06):
//   <button type="button"
//           data-action="click->confirmation-modal#open"
//           data-confirmation-modal-form-id-param="reset-tournament-form"
//           data-confirmation-modal-title-param="Reset bestätigen"
//           data-confirmation-modal-body-param="Alle lokalen Daten gehen verloren. Fortfahren?"
//           data-confirmation-modal-confirm-label-param="Ja, zurücksetzen">
//     Zurücksetzen
//   </button>
//
// Auto-Open + Hidden-Override Mode (UI-07):
//   Wenn das Partial mit auto_open: true gerendert wird, öffnet connect() das
//   Modal von selbst. Wenn hidden_override_name gesetzt ist, setzt der Confirm-
//   Handler das genannte Hidden-Input-Feld im Ziel-Formular auf "1", bevor
//   requestSubmit() läuft. Cancel setzt es zurück auf "0", wenn
//   hidden_override_reset_on_cancel true ist (Default).
export default class extends Controller {
  static targets = ["root", "dialog", "title", "body", "confirmButton"]

  static values = {
    autoOpen: Boolean,
    autoOpenTitle: String,
    autoOpenBody: String,
    autoOpenConfirmLabel: String,
    autoOpenFormId: String,
    hiddenOverrideName: String,
    hiddenOverrideResetOnCancel: { type: Boolean, default: true }
  }

  connect() {
    this.boundKeydown = this.handleKeydown.bind(this)
    this.pendingFormId = null

    // UI-07: when the server re-renders with a verification failure, the
    // partial is called with auto_open: true. Open the modal on the next
    // microtask tick so the DOM is fully wired before we touch targets.
    if (this.autoOpenValue) {
      queueMicrotask(() => this.openWithValues())
    }
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  // Click-trigger entry point (UI-06). Reads per-click params from the event.
  open(event) {
    const params = (event && event.params) || {}
    this.pendingFormId = params.formId || null
    this.titleTarget.textContent = params.title || "Bestätigen"
    // SECURITY (T-36b05-01): textContent for all text slots (never HTML).
    // All inputs go through Rails t() in the calling ERB, but we defend
    // in depth by using the text-only DOM API.
    this.bodyTarget.textContent = params.body || ""
    if (this.hasConfirmButtonTarget) {
      this.confirmButtonTarget.textContent = params.confirmLabel || "Bestätigen"
    }
    this.showRoot()
  }

  // Auto-open entry point (UI-07). Reads params from the controller's own
  // static values, populated by the partial's auto_open_* locals.
  openWithValues() {
    this.pendingFormId = this.hasAutoOpenFormIdValue ? this.autoOpenFormIdValue : null
    this.titleTarget.textContent = this.hasAutoOpenTitleValue ? this.autoOpenTitleValue : "Bestätigen"
    this.bodyTarget.textContent = this.hasAutoOpenBodyValue ? this.autoOpenBodyValue : ""
    if (this.hasConfirmButtonTarget) {
      this.confirmButtonTarget.textContent = this.hasAutoOpenConfirmLabelValue ? this.autoOpenConfirmLabelValue : "Bestätigen"
    }
    this.showRoot()
  }

  showRoot() {
    this.rootTarget.classList.remove("hidden")
    this.rootTarget.classList.add("flex")
    document.addEventListener("keydown", this.boundKeydown)
  }

  cancel() {
    // UI-07: reset the named hidden input on cancel so repeated cancel/open
    // cycles don't leave a stale "1" in the form.
    if (this.hiddenOverrideResetOnCancelValue && this.hasHiddenOverrideNameValue && this.hiddenOverrideNameValue.length > 0) {
      this.setHiddenOverride("0")
    }
    this.close()
  }

  confirm() {
    const formId = this.pendingFormId

    // UI-07: before submitting, flip the named hidden input to "1" so the
    // server-side verification gate sees the explicit override.
    if (this.hasHiddenOverrideNameValue && this.hiddenOverrideNameValue.length > 0) {
      this.setHiddenOverride("1")
    }

    this.close()
    if (formId) {
      const form = document.getElementById(formId)
      if (form) {
        // Use requestSubmit so Turbo / Rails UJS processes the form.
        // The form still carries its Rails CSRF token and method.
        if (typeof form.requestSubmit === "function") {
          form.requestSubmit()
        } else {
          form.submit()
        }
      }
    }
  }

  // UI-07 helper: find (or create) a hidden input with the configured name
  // on the target form and set its value. If no form id is known yet, try
  // the autoOpenFormIdValue. Silently no-ops if neither is available.
  setHiddenOverride(value) {
    const formId = this.pendingFormId ||
      (this.hasAutoOpenFormIdValue ? this.autoOpenFormIdValue : null)
    if (!formId) return
    const form = document.getElementById(formId)
    if (!form) return
    const name = this.hiddenOverrideNameValue
    let input = form.querySelector(`input[name="${name}"]`)
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      form.appendChild(input)
    }
    input.value = value
  }

  close() {
    this.rootTarget.classList.add("hidden")
    this.rootTarget.classList.remove("flex")
    this.pendingFormId = null
    document.removeEventListener("keydown", this.boundKeydown)
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.cancel()
    }
  }
}
