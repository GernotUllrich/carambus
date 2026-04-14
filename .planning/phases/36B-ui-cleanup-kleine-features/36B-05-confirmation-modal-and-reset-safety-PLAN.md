---
phase: 36B
plan: 05
type: execute
wave: 1
depends_on: []
files_modified:
  - app/javascript/controllers/confirmation_modal_controller.js
  - app/views/shared/_confirmation_modal.html.erb
  - app/views/tournaments/show.html.erb
  - app/views/tournaments/finalize_modus.html.erb
  - test/system/tournament_reset_confirmation_test.rb
autonomous: true
requirements: [UI-06]
tags: [stimulus, modal, safety, ui, system-test]

must_haves:
  truths:
    - "A shared Stimulus confirmation_modal controller exists and can be reused by plan 06 (UI-07)"
    - "A shared _confirmation_modal.html.erb partial exists and is rendered once per page that needs it"
    - "All three reset buttons on the tournament show / finalize_modus pages now show the modal before submitting"
    - "The modal names the current AASM state and number of games played inline (D-16)"
    - "The modal is always shown regardless of AASM state (D-16)"
    - "Clicking Cancel does not submit the reset form"
    - "Clicking Confirm submits the reset form through the existing Rails CSRF-protected POST path"
    - "A Capybara system test asserts the full reset-confirmation flow"
    - "The controller supports auto-opening on page load via autoOpenValue (for plan 06's server-side verification failure render)"
    - "The controller supports setting a hidden input to \"1\" before submit via hiddenOverrideNameValue (for plan 06's verified_override flag)"
    - "Cancel restores the hidden input to \"0\" when hiddenOverrideResetOnCancelValue is true"
  artifacts:
    - path: "app/javascript/controllers/confirmation_modal_controller.js"
      provides: "Shared Stimulus modal controller with autoOpen and hiddenOverride support (reusable for UI-06 and UI-07)"
      exports: ["default (Controller)"]
    - path: "app/views/shared/_confirmation_modal.html.erb"
      provides: "Shared modal partial (hidden by default, shown via Stimulus) accepting trigger_id, auto_open, hidden_override_name, hidden_override_reset_on_cancel, form_id, title, body, confirm_label, cancel_label locals"
    - path: "app/views/tournaments/show.html.erb"
      provides: "Reset buttons wired to the shared modal"
    - path: "app/views/tournaments/finalize_modus.html.erb"
      provides: "Force-reset button wired to the shared modal"
    - path: "test/system/tournament_reset_confirmation_test.rb"
      provides: "Capybara system test for the reset-confirmation dialog"
  key_links:
    - from: "app/views/tournaments/show.html.erb reset button"
      to: "app/javascript/controllers/confirmation_modal_controller.js"
      via: "data-action=click->confirmation-modal#open data-confirmation-modal-form-id-param=..."
      pattern: "confirmation-modal#open"
    - from: "app/javascript/controllers/confirmation_modal_controller.js confirm action"
      to: "the underlying <form> element"
      via: "form.requestSubmit() after modal close"
      pattern: "requestSubmit"
---

<objective>
Implement UI-06 (Reset data-loss confirmation dialog) using a shared Stimulus modal + Tailwind partial that plan 06 (UI-07) will also consume. The controller is designed from day one to support BOTH UI-06 (click-driven) and UI-07 (auto-open on server-side verification failure) via additional Stimulus values — plan 06 does NOT have to patch this controller later.

**Scope (D-15, D-16):**
1. Create a new Stimulus controller `confirmation_modal_controller.js` and a new partial `app/views/shared/_confirmation_modal.html.erb`. Both are general-purpose: the partial renders a hidden dialog; the controller shows/hides it and forwards the confirmation to a specific form by id. The controller also supports (a) auto-opening on `connect()` when `autoOpenValue` is true, and (b) flipping a named hidden input on the target form to `"1"` on confirm (reset to `"0"` on cancel) via `hiddenOverrideNameValue` + `hiddenOverrideResetOnCancelValue`. Plan 06 uses these for server-side parameter verification.
2. Wire the three existing reset buttons on the tournament show/finalize_modus pages:
   - `app/views/tournaments/show.html.erb:186` — primary "Zurücksetzen des Turnier-Monitors" button (visible when `!tournament.tournament_started`)
   - `app/views/tournaments/show.html.erb:189` — debug "Force Reset" button (visible only for privileged users)
   - `app/views/tournaments/finalize_modus.html.erb:227` — debug "Force Reset" button on the mode selection page
3. Replace each button's `data: { confirm: "Are you sure?" }` with a form that is NOT auto-submitted by the browser's native confirm dialog, plus a trigger `<button type="button">` that opens the shared modal. The modal names the current AASM state and number of games played so the operator sees the consequences inline.
4. Add the shared `_confirmation_modal.html.erb` partial to `app/views/layouts/application.html.erb` (or the tournament-specific layout) so it is rendered once per page and reused across UI-06 + UI-07 contexts.
5. Add a Capybara system test `test/system/tournament_reset_confirmation_test.rb` per D-20 that asserts: (a) clicking Reset shows the modal, (b) clicking Cancel preserves data, (c) clicking Confirm triggers the reset action.

**Wave-1 rationale:** this plan touches `show.html.erb` and `finalize_modus.html.erb` (not touched by plans 01-04) plus creates new files. No file conflicts → parallel-safe with plans 01 and 04 in wave 1.

**Why UI-06 is merged with the shared-modal foundation:** option (b) from the grouping guidance — keeps every plan REQ-ID-carrying. Plan 06 (UI-07) depends on this plan's modal infrastructure but is a separate wave because it conflicts on `tournament_monitor.html.erb` with plans 02 and 03. Plan 06 consumes the controller's autoOpen + hiddenOverride values WITHOUT touching this controller — it only renders the shared partial with different locals.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/REQUIREMENTS.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@app/views/tournaments/show.html.erb
@app/views/tournaments/finalize_modus.html.erb
@app/javascript/controllers/hello_controller.js
@app/controllers/tournaments_controller.rb
@test/models/tournament_test.rb

<interfaces>
Existing reset controller action (app/controllers/tournaments_controller.rb:47-56):

    def reset
      if params[:force_reset].present?
        @tournament.forced_reset_tournament_monitor!
      elsif !@tournament.tournament_started
        @tournament.reset_tmt_monitor!
      else
        flash[:alert] = "Cannot reset running or finished tournament"
      end
      redirect_to tournament_path(@tournament)
    end

No change is needed to this controller action — this plan only intercepts the button UI; the POST request body is unchanged (still carries optional `force_reset` param, still CSRF-protected via Rails).

Existing reset buttons (app/views/tournaments/show.html.erb:186, 189):

    <%- if !@tournament.tournament_started %>
      <%= button_to I18n.t("tournaments.show.reset_tournament_monitor"),
          reset_tournament_path(@tournament), method: :post,
          class: "btn btn-flat btn-primary",
          data: { confirm: 'Are you sure?' },
          style: "float: left; margin-right: 10px;" %>
    <%- end %>
    <%- if (User::PRIVILEGED + [User.scoreboard.andand.email.andand.downcase]).include? current_user&.email&.downcase %>
      <%= button_to I18n.t("tournaments.show.debugging_force_reset_tournament_monitor"),
          reset_tournament_path(@tournament, force_reset: true), method: :post,
          class: "btn btn-flat btn-primary",
          style: "float: left; margin-right: 10px;" %>
    <% end %>

Existing force-reset button (app/views/tournaments/finalize_modus.html.erb:227):

    <%= button_to I18n.t("tournaments.show.debugging_force_reset_tournament_monitor"),
        reset_tournament_path(@tournament, force_reset: true), method: :post,
        class: "btn btn-flat btn-primary",
        style: "float: left; margin-right: 10px;" %>

Stimulus controllers are auto-registered via app/javascript/controllers/index.js (glob import). A new file confirmation_modal_controller.js becomes available as controller name "confirmation-modal".
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create the shared confirmation_modal Stimulus controller (with autoOpen + hiddenOverride values) and partial</name>
  <files>
    app/javascript/controllers/confirmation_modal_controller.js
    app/views/shared/_confirmation_modal.html.erb
  </files>
  <read_first>
    - app/javascript/controllers/hello_controller.js (minimal Stimulus skeleton)
    - app/javascript/controllers/index.js (auto-registration glob)
    - app/views/shared/_scoreboard_message_modal.html.erb (an existing shared modal partial — mirror its include style)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-15
  </read_first>
  <action>
**A — Create `app/javascript/controllers/confirmation_modal_controller.js`:**

    import { Controller } from "@hotwired/stimulus"

    // Shared Confirmation Modal (D-15)
    // Wird von UI-06 (Reset-Sicherheitsabfrage) und UI-07 (Parameter-Verifikation) wiederverwendet.
    //
    // Markup-Vertrag:
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
    //       <button data-action="click->confirmation-modal#confirm">Confirm</button>
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
        // SECURITY: textContent, not innerHTML. All inputs go through Rails
        // t() in the calling ERB, but we defend in depth.
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

**B — Create `app/views/shared/_confirmation_modal.html.erb`:**

    <%# Shared confirmation modal (UI-06 D-15, reused by UI-07 in Phase 36b plan 06) %>
    <%# Render this partial once per page that needs it (typically from the layout). %>
    <%# Triggers use data-action="click->confirmation-modal#open" with data-*-param attrs. %>
    <%#
        Local parameters (all optional; defaults support the UI-06 click-trigger mode):
          auto_open:                       Boolean (default false). When true, the controller
                                           auto-opens on connect() using the auto_open_* locals.
          auto_open_title:                 String — title shown when auto_open is true.
          auto_open_body:                  String — body text shown when auto_open is true.
          auto_open_confirm_label:         String — Confirm button text when auto_open is true.
          auto_open_form_id:               String — form id to submit when Confirm is clicked.
          hidden_override_name:            String — name of a hidden input on auto_open_form_id
                                           that should be set to "1" on Confirm (and "0" on
                                           Cancel, if hidden_override_reset_on_cancel is true).
          hidden_override_reset_on_cancel: Boolean (default true).
    %>
    <%
      local_auto_open                      = local_assigns.fetch(:auto_open, false)
      local_auto_open_title                = local_assigns.fetch(:auto_open_title, "")
      local_auto_open_body                 = local_assigns.fetch(:auto_open_body, "")
      local_auto_open_confirm_label        = local_assigns.fetch(:auto_open_confirm_label, "")
      local_auto_open_form_id              = local_assigns.fetch(:auto_open_form_id, "")
      local_hidden_override_name           = local_assigns.fetch(:hidden_override_name, "")
      local_hidden_override_reset_on_cancel = local_assigns.fetch(:hidden_override_reset_on_cancel, true)
    %>
    <div data-controller="confirmation-modal"
         data-confirmation-modal-target="root"
         data-confirmation-modal-auto-open-value="<%= local_auto_open %>"
         data-confirmation-modal-auto-open-title-value="<%= local_auto_open_title %>"
         data-confirmation-modal-auto-open-body-value="<%= local_auto_open_body %>"
         data-confirmation-modal-auto-open-confirm-label-value="<%= local_auto_open_confirm_label %>"
         data-confirmation-modal-auto-open-form-id-value="<%= local_auto_open_form_id %>"
         data-confirmation-modal-hidden-override-name-value="<%= local_hidden_override_name %>"
         data-confirmation-modal-hidden-override-reset-on-cancel-value="<%= local_hidden_override_reset_on_cancel %>"
         class="hidden fixed inset-0 z-50 bg-black bg-opacity-50 items-center justify-center"
         role="dialog"
         aria-modal="true"
         aria-labelledby="confirmation-modal-title">
      <div data-confirmation-modal-target="dialog"
           class="bg-white rounded-lg shadow-xl max-w-lg w-full mx-4 p-6">
        <h3 id="confirmation-modal-title"
            data-confirmation-modal-target="title"
            class="text-lg font-bold text-gray-900 mb-3"></h3>
        <div data-confirmation-modal-target="body"
             class="text-sm text-gray-700 mb-5 whitespace-pre-line"></div>
        <div class="flex justify-end gap-3">
          <button type="button"
                  data-action="click->confirmation-modal#cancel"
                  class="btn btn-flat btn-secondary">
            <%= I18n.t("shared.confirmation_modal.cancel", default: "Abbrechen") %>
          </button>
          <button type="button"
                  data-confirmation-modal-target="confirmButton"
                  data-action="click->confirmation-modal#confirm"
                  class="btn btn-flat btn-primary">
            <%= I18n.t("shared.confirmation_modal.confirm", default: "Bestätigen") %>
          </button>
        </div>
      </div>
    </div>

**C — Render the partial from `app/views/layouts/application.html.erb`:** locate the closing `</body>` tag and insert just before it:

    <%= render "shared/confirmation_modal" %>

If `application.html.erb` is not the right layout (grep the existing render calls to confirm), use whichever layout wraps the tournament pages. A `grep -n "yield" app/views/layouts/application.html.erb` confirms it is the main layout. A single render call in the layout means the partial renders once per page — the controller's `targets` selector finds the one `data-controller="confirmation-modal"` element.

**For pages that need auto-open** (plan 06's tournament_monitor.html.erb after a verification failure): the plan 06 view will render an additional `<%= render "shared/confirmation_modal", auto_open: true, auto_open_title: ..., auto_open_body: ..., auto_open_form_id: "start_tournament", hidden_override_name: "parameter_verification_confirmed", ... %>` call INSIDE the view (not in the layout). This produces a second `data-controller="confirmation-modal"` element which Stimulus treats as a separate controller instance with its own auto_open value. Stimulus targets are scoped to their parent controller, so there is no bleed. The layout-rendered instance ignores auto_open (false by default).

Do NOT add the modal to more than one layout — the Stimulus `targets` declaration only finds elements within the controller's own scope, and a single shared layout instance is easier to reason about.

**D — Security note:** the modal content is rendered via `textContent` in the Stimulus controller (mitigation T-36b05-01). The trigger buttons pass title/body as Stimulus `data-*-param` attributes, which Rails HTML-escapes when interpolated via `<%= %>`. Auto-open values pass through the same `<%= %>` escaping. No `raw` / `html_safe` anywhere in this plan.
  </action>
  <verify>
    <automated>ruby -e "src = File.read('app/javascript/controllers/confirmation_modal_controller.js'); raise 'textContent missing' unless src.include?('textContent'); raise 'innerHTML forbidden' if src.include?('innerHTML'); raise 'requestSubmit missing' unless src.include?('requestSubmit'); raise 'Escape handler missing' unless src.include?(%q('Escape')); raise 'autoOpenValue missing' unless src.include?('autoOpenValue'); raise 'hiddenOverrideNameValue missing' unless src.include?('hiddenOverrideNameValue'); raise 'hiddenOverrideResetOnCancelValue missing' unless src.include?('hiddenOverrideResetOnCancelValue'); raise 'setHiddenOverride missing' unless src.include?('setHiddenOverride'); raise 'openWithValues missing' unless src.include?('openWithValues'); puts 'JS OK'; erb = File.read('app/views/shared/_confirmation_modal.html.erb'); raise 'partial missing target=root' unless erb.include?('data-confirmation-modal-target=\"root\"'); raise 'partial missing hidden class' unless erb.include?('hidden'); raise 'aria-modal missing' unless erb.include?('aria-modal'); raise 'auto_open value missing from partial' unless erb.include?('data-confirmation-modal-auto-open-value'); raise 'hidden-override-name value missing from partial' unless erb.include?('data-confirmation-modal-hidden-override-name-value'); puts 'Partial OK'; layout = File.read('app/views/layouts/application.html.erb'); raise 'partial not rendered from layout' unless layout.include?('shared/confirmation_modal'); puts 'Layout OK'"</automated>
  </verify>
  <acceptance_criteria>
    - `app/javascript/controllers/confirmation_modal_controller.js` exists
    - `grep -c "textContent" app/javascript/controllers/confirmation_modal_controller.js` returns a value `>= 6` (title + body + confirm label, each in open() and openWithValues())
    - `grep -c "innerHTML" app/javascript/controllers/confirmation_modal_controller.js` returns `0`
    - `grep -c "requestSubmit" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 1`
    - `grep -c "static targets" app/javascript/controllers/confirmation_modal_controller.js` returns `1`
    - `grep -c "autoOpen:" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 1` (autoOpen declared in static values)
    - `grep -c "hiddenOverrideName:" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 1`
    - `grep -c "hiddenOverrideResetOnCancel:" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 1`
    - `grep -c "setHiddenOverride" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 3` (definition + 2 call sites in cancel/confirm)
    - `grep -c "openWithValues" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 2` (definition + call in connect)
    - `grep -c "this.autoOpenValue" app/javascript/controllers/confirmation_modal_controller.js` returns `>= 1`
    - `app/views/shared/_confirmation_modal.html.erb` exists
    - `grep -c "data-controller=\"confirmation-modal\"" app/views/shared/_confirmation_modal.html.erb` returns `1`
    - `grep -c "aria-modal" app/views/shared/_confirmation_modal.html.erb` returns `1`
    - `grep -c "data-confirmation-modal-auto-open-value" app/views/shared/_confirmation_modal.html.erb` returns `1`
    - `grep -c "data-confirmation-modal-hidden-override-name-value" app/views/shared/_confirmation_modal.html.erb` returns `1`
    - `grep -c "data-confirmation-modal-auto-open-form-id-value" app/views/shared/_confirmation_modal.html.erb` returns `1`
    - `grep -c "local_assigns.fetch(:auto_open" app/views/shared/_confirmation_modal.html.erb` returns `>= 1`
    - `grep -c "shared/confirmation_modal" app/views/layouts/application.html.erb` returns `1`
    - `bundle exec erblint app/views/shared/_confirmation_modal.html.erb app/views/layouts/application.html.erb` exits 0
  </acceptance_criteria>
  <done>
    Shared controller and partial exist, the partial is rendered from the layout exactly once, no innerHTML usage, Escape key and Cancel button close the modal, Confirm forwards to `requestSubmit()`, and the controller supports UI-07's auto-open and hidden-override modes via Stimulus values without inline scripts.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Wire the three reset buttons to the shared modal (show.html.erb + finalize_modus.html.erb)</name>
  <files>
    app/views/tournaments/show.html.erb
    app/views/tournaments/finalize_modus.html.erb
  </files>
  <read_first>
    - app/views/tournaments/show.html.erb lines 180-195 (the two reset buttons)
    - app/views/tournaments/finalize_modus.html.erb lines 220-235 (the force-reset button)
    - app/views/shared/_confirmation_modal.html.erb (from Task 1 — understand the trigger data-* API)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-16
  </read_first>
  <action>
For each of the three reset `button_to` calls, replace the single-button pattern with a pair: (a) a plain Rails `form_with` (WITHOUT a block arg, because the body is empty and `standardrb` Lint/UnusedBlockArgument will complain about `do |f|`), and a visible `<button type="button">` trigger that opens the shared modal with a `data-confirmation-modal-form-id-param` pointing at the form's id.

**Form pattern — use `form_with ... do |_f| %>` with an underscore-prefixed block arg to satisfy Rails' requirement for a block while silencing standardrb. Alternatively use `form_tag` which takes no block arg.** The examples below use `form_tag` to keep it simplest.

**A — `app/views/tournaments/show.html.erb:186` (primary reset — pre-started only):**

Replace:

    <%- if !@tournament.tournament_started %>
      <%= button_to I18n.t("tournaments.show.reset_tournament_monitor"),
          reset_tournament_path(@tournament), method: :post,
          class: "btn btn-flat btn-primary",
          data: { confirm: 'Are you sure?' },
          style: "float: left; margin-right: 10px;" %>
    <%- end %>

with:

    <%- if !@tournament.tournament_started %>
      <%= form_tag reset_tournament_path(@tournament),
                   method: :post,
                   id: "reset-tournament-form-#{@tournament.id}",
                   style: "float: left; margin-right: 10px;" do %>
      <% end %>
      <button type="button"
              class="btn btn-flat btn-primary"
              style="float: left; margin-right: 10px;"
              data-action="click->confirmation-modal#open"
              data-confirmation-modal-form-id-param="reset-tournament-form-<%= @tournament.id %>"
              data-confirmation-modal-title-param="<%= I18n.t('tournaments.show.reset_tournament_modal.title', default: 'Turnier-Monitor zurücksetzen') %>"
              data-confirmation-modal-body-param="<%= I18n.t('tournaments.show.reset_tournament_modal.body',
                    default: 'Achtung: Alle lokalen Setzlisten, Spiele und Ergebnisse dieses Turniers gehen verloren.') + %Q(\n\n) +
                    I18n.t('tournaments.show.reset_tournament_modal.state_line', default: 'Aktueller Status:') + ' ' + (@tournament.state.to_s) + %Q(\n) +
                    I18n.t('tournaments.show.reset_tournament_modal.games_line', default: 'Gespielte Spiele:') + ' ' + (@tournament.games.where.not(result_a: nil).count.to_s) %>"
              data-confirmation-modal-confirm-label-param="<%= I18n.t('tournaments.show.reset_tournament_modal.confirm', default: 'Ja, zurücksetzen') %>">
        <%= I18n.t("tournaments.show.reset_tournament_monitor") %>
      </button>
    <%- end %>

Note: `form_tag ... do` accepts a block WITHOUT yielding a form-builder arg, so there's no unused-arg lint issue. The empty `do ... end` body renders only the form tag and its CSRF hidden input. The submit happens via Stimulus `requestSubmit()` when the user clicks Confirm in the modal. The id embeds `@tournament.id` so multiple forms on the same page can coexist (useful if the force-reset button also renders). The body-param interpolation builds a single string in Ruby before Rails HTML-escapes it.

**B — `app/views/tournaments/show.html.erb:189` (privileged force-reset):**

Replace:

    <%- if (User::PRIVILEGED + [User.scoreboard.andand.email.andand.downcase]).include? current_user&.email&.downcase %>
      <%= button_to I18n.t("tournaments.show.debugging_force_reset_tournament_monitor"),
          reset_tournament_path(@tournament, force_reset: true), method: :post,
          class: "btn btn-flat btn-primary",
          style: "float: left; margin-right: 10px;" %>
    <% end %>

with:

    <%- if (User::PRIVILEGED + [User.scoreboard.andand.email.andand.downcase]).include? current_user&.email&.downcase %>
      <%= form_tag reset_tournament_path(@tournament, force_reset: true),
                   method: :post,
                   id: "force-reset-tournament-form-#{@tournament.id}",
                   style: "float: left; margin-right: 10px;" do %>
      <% end %>
      <button type="button"
              class="btn btn-flat btn-primary"
              style="float: left; margin-right: 10px;"
              data-action="click->confirmation-modal#open"
              data-confirmation-modal-form-id-param="force-reset-tournament-form-<%= @tournament.id %>"
              data-confirmation-modal-title-param="<%= I18n.t('tournaments.show.force_reset_tournament_modal.title', default: 'Turnier-Monitor zwangsweise zurücksetzen') %>"
              data-confirmation-modal-body-param="<%= I18n.t('tournaments.show.force_reset_tournament_modal.body',
                    default: 'DATENVERLUST: Alle lokalen Setzlisten, laufenden Spiele, Ergebnisse und der Turnierstand gehen unwiderruflich verloren.') + %Q(\n\n) +
                    I18n.t('tournaments.show.reset_tournament_modal.state_line', default: 'Aktueller Status:') + ' ' + (@tournament.state.to_s) + %Q(\n) +
                    I18n.t('tournaments.show.reset_tournament_modal.games_line', default: 'Gespielte Spiele:') + ' ' + (@tournament.games.where.not(result_a: nil).count.to_s) %>"
              data-confirmation-modal-confirm-label-param="<%= I18n.t('tournaments.show.force_reset_tournament_modal.confirm', default: 'Ja, zwangsweise zurücksetzen') %>">
        <%= I18n.t("tournaments.show.debugging_force_reset_tournament_monitor") %>
      </button>
    <% end %>

**C — `app/views/tournaments/finalize_modus.html.erb:227` (force-reset on mode selection page):**

Same transformation as B — replace the `button_to` with a `form_tag` (empty body, no block arg) + `<button type="button">` trigger. Use form id `force-reset-tournament-form-finalize-<%= @tournament.id %>` to disambiguate from B (they live on different pages but pick a unique id as a defensive measure).

Use the same i18n keys as B so the user sees the same wording. The `@tournament.games.where.not(result_a: nil).count` interpolation stays the same — pre-mode-selection typically yields 0 games, but the modal honestly reports the current count regardless.

**D — Do NOT add the `shared.confirmation_modal.cancel` / `.confirm` or the `tournaments.show.reset_tournament_modal.*` keys to de.yml / en.yml in this task.** All interpolations use `t('...', default: '...')` with reasonable German defaults so the feature works even before the keys exist. A later i18n-polish task can move the defaults into the YAML file. This keeps plan 05 from touching `de.yml`/`en.yml` and avoids file-conflict with plan 02 (which is wave 2).

Additional safety — the `data: { confirm: 'Are you sure?' }` attribute is GONE from all three buttons. The new `<button type="button">` does not submit the form directly; only Stimulus requestSubmit() via the Confirm callback submits it. If JavaScript fails to load, the button does nothing (fail-safe: the operator cannot accidentally trigger a destructive reset).

**lint note (W-4):** `form_tag ... do ... end` does NOT yield a block argument, so no `|_f|` or `|f|` is needed and `standardrb` cannot complain about an unused block arg. If a future maintainer prefers `form_with`, use `form_with ... do |_f| %>` (underscore-prefixed arg) to satisfy `Lint/UnusedBlockArgument`.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/show.html.erb app/views/tournaments/finalize_modus.html.erb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "data: { confirm: 'Are you sure" app/views/tournaments/show.html.erb` returns `0`
    - `grep -c "data: { confirm: 'Are you sure" app/views/tournaments/finalize_modus.html.erb` returns `0`
    - `grep -c "confirmation-modal#open" app/views/tournaments/show.html.erb` returns `2` (primary + force-reset triggers)
    - `grep -c "confirmation-modal#open" app/views/tournaments/finalize_modus.html.erb` returns `1`
    - `grep -c "reset-tournament-form-" app/views/tournaments/show.html.erb` returns `>= 2`
    - `grep -c "force-reset-tournament-form-" app/views/tournaments/show.html.erb` returns `>= 1`
    - `grep -c "force-reset-tournament-form-finalize-" app/views/tournaments/finalize_modus.html.erb` returns `>= 1`
    - `grep -c "reset_tournament_path" app/views/tournaments/show.html.erb` returns `>= 2` (the two forms still hit the same route)
    - `grep -c "reset_tournament_path" app/views/tournaments/finalize_modus.html.erb` returns `>= 1`
    - `bundle exec erblint app/views/tournaments/show.html.erb app/views/tournaments/finalize_modus.html.erb` exits 0
  </acceptance_criteria>
  <done>
    All three reset paths now flow through the shared modal. No button has a native `data: { confirm: ... }` attribute. The forms still CSRF-protect and still POST to `reset_tournament_path`. Forms use `form_tag ... do` (no unused block arg). erblint is clean.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Capybara system test for reset confirmation dialog</name>
  <files>test/system/tournament_reset_confirmation_test.rb</files>
  <read_first>
    - test/system/admin_access_test.rb (or any existing Capybara system test — mirror its setup, driver config, and sign-in helper)
    - test/test_helper.rb (confirm LocalProtectorTestOverride is active and fixtures/factories are available)
    - app/views/tournaments/show.html.erb (after Task 2 — confirm the button markup the test will drive)
    - app/views/shared/_confirmation_modal.html.erb (after Task 1 — confirm the modal selectors)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-20
  </read_first>
  <behavior>
    Test 1: Visiting a non-started tournament and clicking the reset button shows the shared modal (modal root loses the `hidden` class or becomes visible).
    Test 2: Clicking Cancel in the modal closes the modal AND does not POST to `reset_tournament_path`. The tournament is unchanged.
    Test 3: Clicking Confirm submits the form, redirects back to the tournament page with the reset applied. The tournament's state is `new_tournament` (or whatever the `reset_tmt_monitor!` transition produces).
  </behavior>
  <action>
Create `test/system/tournament_reset_confirmation_test.rb`:

    require "application_system_test_case"

    class TournamentResetConfirmationTest < ApplicationSystemTestCase
      # UI-06 D-20: Capybara system test for the shared confirmation modal (plan 36B-05).
      # Asserts the three beats of the safety dialog:
      #   1. clicking Reset opens the modal
      #   2. Cancel dismisses the modal and does not POST
      #   3. Confirm POSTs to reset_tournament_path and the tournament state rewinds

      setup do
        # Sign in as a privileged user so both the normal and force-reset buttons render.
        @user = users(:admin) rescue User.first
        raise "sign_in helper required — include Devise::Test::IntegrationHelpers in ApplicationSystemTestCase" unless respond_to?(:sign_in)
        sign_in @user

        # Use a tournament that is NOT started so the primary reset button renders.
        @tournament = tournaments(:local) rescue Tournament.where(tournament_started: [nil, false]).first
        skip "no eligible non-started tournament fixture available" unless @tournament
      end

      test "clicking reset opens the confirmation modal" do
        visit tournament_path(@tournament)

        # Before any click, the modal root should carry the `hidden` class.
        assert_selector "[data-controller='confirmation-modal']", visible: :all
        assert_selector "[data-controller='confirmation-modal'].hidden", visible: :all

        # Click the primary reset trigger button.
        find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click

        # Modal is now visible (hidden class gone).
        assert_no_selector "[data-controller='confirmation-modal'].hidden", visible: :all
        assert_text I18n.t("tournaments.show.reset_tournament_modal.title", default: "Turnier-Monitor zurücksetzen")
      end

      test "clicking Cancel dismisses the modal without POSTing" do
        visit tournament_path(@tournament)

        state_before = @tournament.reload.state
        find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click

        find("button[data-action='click->confirmation-modal#cancel']").click

        # Modal is hidden again
        assert_selector "[data-controller='confirmation-modal'].hidden", visible: :all

        # Tournament state is unchanged
        assert_equal state_before, @tournament.reload.state
      end

      test "clicking Confirm submits the reset form" do
        visit tournament_path(@tournament)

        find("button[data-action='click->confirmation-modal#open'][data-confirmation-modal-form-id-param*='reset-tournament-form']", match: :first).click
        find("button[data-action='click->confirmation-modal#confirm']").click

        # Page redirects back to the tournament (Rails redirect_to tournament_path)
        assert_current_path tournament_path(@tournament)

        # After reset_tmt_monitor! the state is :new_tournament
        assert_equal "new_tournament", @tournament.reload.state
      end
    end

Notes:
- If `users(:admin)` fixture does not exist, fall back to `User.first` — the test is best-effort and will `skip` when preconditions are not met rather than hang CI.
- The `sign_in` helper is REQUIRED (not optional) — if it doesn't exist, the setup raises with a clear message pointing at `Devise::Test::IntegrationHelpers` so the failure is loud instead of silent.
- If `application_system_test_case.rb` does not exist under `test/`, this test will not run — pre-flight check by running `ls test/application_system_test_case.rb`. If missing, use the setup pattern from `test/system/admin_access_test.rb` directly.
- D-21 says NO system tests for FIX-01/03/04/UI-01/02/04/05 — this test is scoped to UI-06 only.
  </action>
  <verify>
    <automated>bin/rails test test/system/tournament_reset_confirmation_test.rb</automated>
  </verify>
  <acceptance_criteria>
    - `test/system/tournament_reset_confirmation_test.rb` exists
    - `grep -c 'class TournamentResetConfirmationTest' test/system/tournament_reset_confirmation_test.rb` returns `1`
    - `grep -c '^  test ' test/system/tournament_reset_confirmation_test.rb` returns `3`
    - `grep -c "confirmation-modal#open" test/system/tournament_reset_confirmation_test.rb` returns `>= 1`
    - `grep -c "confirmation-modal#cancel" test/system/tournament_reset_confirmation_test.rb` returns `1`
    - `grep -c "confirmation-modal#confirm" test/system/tournament_reset_confirmation_test.rb` returns `1`
    - `bin/rails test test/system/tournament_reset_confirmation_test.rb` exits 0 (all 3 tests pass OR skip with a clear preconditions message)
  </acceptance_criteria>
  <done>
    System test file exists, has 3 tests (open / cancel / confirm), and the test suite passes or skips with a clear message if fixtures do not support it.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| operator browser → Stimulus controller | Click on reset button triggers a JavaScript-only path before any POST |
| Stimulus controller → Rails form | `form.requestSubmit()` triggers the Rails form submission with CSRF token |
| Rails CSRF layer → TournamentsController#reset | Existing protection continues to apply |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b05-01 | Tampering (T) / XSS | Modal title and body rendered into DOM | mitigate | Stimulus controller uses `textContent` (not `innerHTML`) for all text slots in both `open()` and `openWithValues()` code paths. Rails `t(..., default: ...)` HTML-escapes the string before it lands in the `data-*-param` attribute or the `data-confirmation-modal-auto-open-*-value` attribute. No `raw` / `html_safe` used anywhere in the chain. |
| T-36b05-02 | Repudiation (R) / Tampering (T) | CSRF on the reset POST | mitigate | The form is built with `form_tag`, which inserts the Rails CSRF hidden input automatically. `requestSubmit()` from Stimulus uses the same form element, carrying the token. The existing `TournamentsController#reset` keeps its CSRF protection (no `skip_before_action :verify_authenticity_token`). |
| T-36b05-03 | Denial of service (D) / accidental click | User accidentally triggers a destructive reset | mitigate | The new modal is ALWAYS shown (D-16) even for states where the data loss is minor. The modal labels the current AASM state and the count of played games so the operator sees the consequences inline. Confirm requires an explicit second click; Escape and Cancel both dismiss without POSTing. |
| T-36b05-04 | Elevation of privilege (E) | Unprivileged user discovers force-reset URL and POSTs directly | accept | Force-reset POST is still gated at the view level by the `User::PRIVILEGED` check. This plan does not change authorization on the server-side controller action — the existing model-level AASM guards (`admin_can_reset_tournament?`) still apply. A future hardening pass could move the check into a Pundit policy; out of scope for UI-06. |
| T-36b05-05 | Denial of service (D) | JavaScript fails to load → operator cannot reset | accept | Fail-safe direction: the operator cannot trigger a destructive action without JavaScript, which is safer than failing open. The primary reset is not time-critical; operators can retry after a page reload. The `<button type="button">` explicitly does NOT fall back to submit — by design. |
| T-36b05-06 | Tampering (T) / hidden-input manipulation | UI-07 uses `setHiddenOverride` to flip a named input to "1" on confirm; an attacker could pre-populate it via DOM manipulation | accept | The hidden input is a UX hint, not a security boundary. The authoritative range check runs server-side in plan 06's `TournamentsController#start`. Even if the hidden input is "1" on first submit, the server STILL runs `verify_tournament_start_parameters` and only trusts the override when the failure check passes (plan 06's threat model covers this in detail as T-36b06-01). |
</threat_model>

<verification>
1. `ruby -e "..."` JS sanity check from Task 1 exits 0.
2. `bundle exec erblint app/views/shared/_confirmation_modal.html.erb app/views/layouts/application.html.erb app/views/tournaments/show.html.erb app/views/tournaments/finalize_modus.html.erb` exits 0.
3. `bin/rails test test/system/tournament_reset_confirmation_test.rb` exits 0.
4. All acceptance criteria greps pass.
5. Manual UAT (user runs in carambus_bcw): open a tournament, click Reset → modal appears with German text and the current state name inline; click Cancel → modal closes, no data changes; click Reset again → Confirm → reset applied.
</verification>

<success_criteria>
- UI-06: ✅ Reset confirmation modal always shows (D-16), names current state and game count, Cancel preserves data, Confirm triggers the reset via CSRF-protected form; shared Stimulus controller + partial ready for plan 06 (UI-07) to consume WITHOUT inline scripts (autoOpenValue + hiddenOverrideNameValue + hiddenOverrideResetOnCancelValue baked in); Capybara system test asserts the three beats of the flow
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-05-SUMMARY.md` listing: new Stimulus controller (with autoOpen + hiddenOverride support for plan 06), new shared partial (accepts auto_open/hidden_override_name/hidden_override_reset_on_cancel locals), 3 reset buttons rewired using `form_tag` (no unused block arg), new Capybara system test, layout partial registration, and confirmation that no i18n YAML keys were touched (deferred via `default:` fallbacks).
</output>
</content>
</invoke>