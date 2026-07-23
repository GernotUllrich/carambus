# Phase 36b: UI Cleanup & Kleine Features - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

UI polish and two small safety features for the tournament management happy path. In scope: FIX-01 (wizard help-block expansion), FIX-03 (step names not numbers), FIX-04 (AASM state badge prominence), UI-01 (parameter field tooltips), UI-02 (German labels for the start form), UI-03 (remove `admin_controlled` manual round-change feature), UI-04 (remove dead-code manual input UI from the "Aktuelle Spiele" table), UI-05 (delete the unused `_wizard_steps.html.erb` / `_wizard_step.html.erb` partials), UI-06 (Reset-confirmation modal), UI-07 (parameter-verification modal before `start_tournament!`).

**Out of scope:** any AASM state machine changes (Tier 3 findings from Phase 33 stay gated — no new states, no new transitions, no removals of states); any changes to scoreboard/TableMonitor code paths; the larger ClubCloud upload model rework (tracked as v7.1 via Phase 36c's PREP-01); Shootout support (tracked separately via Phase 36c's PREP-02); Match-Abbruch / Freilos handling (backlog via PREP-03); Endrangliste automatic calculation (tracked as v7.1 feature work). Also out of scope: FIX-02 (closed as verified-aligned 2026-04-14 — code and docs already agree on auto_upload_to_cc checkbox location).

</domain>

<decisions>
## Implementation Decisions

### Wizard header rewrite (FIX-03 + FIX-04)
- **D-01:** The wizard header drops the bare `Schritt N von 6` progress text AND the per-step `1.`/`2.` number prefixes. Instead, it shows the **6 bucket names as chips/pills** with the active one highlighted. Bucket names come from `wizard_status_text`'s existing 6-case mapping (`Vorbereitung`, `Setzliste konfigurieren`, `Modus-Auswahl`, `Bereit zum Start`, `Turnier läuft`, `Abgeschlossen`). Rationale: aligns with Phase 36a F-36-15 meta-finding that `Schritt 1..14` is a doc artifact, not UI reality; also resolves the `wizard_current_step` helper's existing inconsistency (8 internal states mapped to 6 buckets, divisor `/6.0` in `wizard_progress_percent`).
- **D-02:** The AASM state badge becomes visually dominant in the wizard header. Exact treatment is **Claude's discretion** with the explicit goal: a 2×/year volunteer's eye lands on the current state before anything else. Expected direction: large colored badge row at the top with a color-per-state mapping (e.g., orange for `new_tournament`, blue for seeding/mode states, green for `tournament_started`+, gray for `results_published`). Progress bar may remain as a thin secondary indicator or be removed entirely (planner decides). A new `wizard_state_badge_class` helper in `TournamentWizardHelper` is acceptable.
- **D-03:** FIX-03 "conditional on organizer type" is interpreted as: the 6 bucket chips render for all organizer types, but per-step visibility (the `if tournament.organizer.is_a?(Region)` blocks already in `_wizard_steps_v2.html.erb`) stays as-is — step 1 (ClubCloud sync) shows only for Region organizers. No dual layout; no new organizer-type branches beyond what the canonical partial already has.

### FIX-01 (active help block expanded by default)
- **D-04:** Single ERB change in `_wizard_steps_v2.html.erb`: the `<details>` inside each `step-help` block gets an `open` attribute when the step's status is `:active`. Non-active steps stay collapsed. Use the existing `wizard_step_status(tournament, N)` helper. No other behavior changes.

### Parameter form tooltips (UI-01)
- **D-05:** Tooltips are delivered via a new **Stimulus controller + Tailwind hover card**, NOT native HTML `title` attributes. Create `app/javascript/controllers/tooltip_controller.js`. Each parameter field wraps its label in a trigger element with `data-controller="tooltip" data-tooltip-content-value="..."`. The controller renders a styled hover card on mouseenter/focus, hides on mouseleave/blur. Fits the project's existing StimulusReflex + importmap pattern and enables future richer help content (markdown, links to docs).
- **D-06:** Tooltip content comes from **i18n keys** under `tournaments.monitor_form.tooltips.{field_name}` in both `config/locales/de.yml` and `config/locales/en.yml`. First pass writes tooltips for all ~13 parameter fields in `tournament_monitor.html.erb` (excluding the `admin_controlled` checkbox, which UI-03 removes entirely). Tooltip text explains purpose, typical range, and when to deviate from default.

### Parameter form label localization (UI-02)
- **D-07:** **Full i18n conversion** for every label in `tournament_monitor.html.erb`. Create `tournaments.monitor_form.labels.*` keys in both `config/locales/de.yml` and `config/locales/en.yml`. Every `label_tag "literal"` becomes `label_tag t('tournaments.monitor_form.labels.field_name')`. Hardcoded English literals ("Timeout (Sek.)", "GD has prio on inter-group-comparisons", "WarmUp New Table (Min.)", "Assign Games as Tables become available", "Der Anstoß wechselt...", "Darstellung linksseitig", "Zahl der Sätze", "Gewinnsätze") all get German i18n text in `de.yml` and English equivalents in `en.yml`. The existing `t('tournaments.show.balls_goal')` / `innings_goal` / `auto_upload_to_cc` keys stay as-is (Phase 34 already uses them).
- **D-08:** Label-key naming convention: `tournaments.monitor_form.labels.{snake_case_field_name}` for the label; `tournaments.monitor_form.tooltips.{snake_case_field_name}` for the matching UI-01 tooltip. One canonical namespace prevents drift.

### UI-03 admin_controlled removal (UI-only + gate simplification)
- **D-09:** **Remove the editable `admin_controlled` checkbox** from `tournament_monitor.html.erb`. Remove the corresponding Reflex handler in `app/reflexes/tournament_reflex.rb`. Default the tournament behavior to **automatic (non-admin-controlled)** — round advance happens automatically when the last game of a round is confirmed at the scoreboard.
- **D-10:** The load-bearing gate at `app/models/tournament.rb:382-384` (`!admin_controlled?`) is replaced so the method **always returns `true`** (auto-advance always happens). This is the only behavioral change — every downstream caller that reads `admin_controlled?` effectively sees the "automatic" default.
- **D-11:** The `admin_controlled` **column stays in the schema** — no migration. Global records (`id < 50_000_000`) may still have the column populated from external sources; leaving it preserves read-compatibility. Attribute-list entries at `tournament.rb:239,321` and `safe_attributes` at line 254 stay too (null-safe). Only the UI input, the Reflex handler, and the behavioral gate are removed.
- **D-12:** Test fixtures that set `admin_controlled: true` can be left alone — the new always-true gate ignores the column value. If any existing test asserts on the pre-change gate behavior (admin_controlled blocks auto-advance), update it to the new expectation (auto-advance always runs).

### UI-04 dead-code manual input removal
- **D-13:** Remove the dead-code manual input UI from the "Aktuelle Spiele" table on the Turnier-Monitor (per Phase 36a F-36-28). The table becomes read-only: it shows the current round's matches but no Spielbeginn buttons, no result input fields, no inline Reflex handlers for those inputs. Keep only the read-only display rows.

### UI-05 unused partial deletion
- **D-14:** `git rm app/views/tournaments/_wizard_steps.html.erb` AND `git rm app/views/tournaments/_wizard_step.html.erb`. Both are confirmed unused by Phase 33 scout (only `_wizard_steps_v2.html.erb` is rendered from `show.html.erb:35`; `_wizard_step.html.erb` is NOT used by `_wizard_steps_v2.html.erb` despite Phase 33's earlier note — re-verify via `grep -rn "_wizard_step\b" app/` before deletion; if any remaining reference exists, keep the file and flag as a deviation).

### Safety features: UI-06 Reset modal + UI-07 parameter verification modal
- **D-15:** Both UI-06 and UI-07 use a **shared Stimulus-controlled Tailwind modal**. Create one controller `app/javascript/controllers/confirmation_modal_controller.js` and one partial `app/views/shared/_confirmation_modal.html.erb` that both features reuse. The modal accepts title, body, confirm-button text, and cancel-button text via data attributes or Turbo Stream. Rationale: both features are safety confirmations; sharing the pattern keeps the UI consistent and halves the implementation work.
- **D-16:** UI-06 reset confirmation is **always shown** regardless of AASM state, not only for `tournament_started+`. The modal explains what resets (all local seedings, all local matches, all local results) and names the current AASM state + number of games played so the user sees the consequences inline. Rationale: the user explicitly chose "always shown" — matches the "2×/year volunteer" persona where explicit beats terse.
- **D-17:** UI-07 parameter verification uses a **threshold map on the Discipline model**. Add `Discipline#parameter_ranges` returning a hash like `{balls_goal: 50..200, innings_goal: 20..80, timeout: 30..90}` per discipline. First-pass implementation can hardcode the ranges per discipline in the Discipline model (constant or method body); future refinement may move to a database column or config. On form submit (before `start_tournament!`), a controller-side check compares the submitted values against the range; deviations trigger the shared confirmation modal with a list like "Ballziel = 250 (üblich: 50–200)". Only after explicit confirmation does `start_tournament!` run.
- **D-18:** UI-07 triggers on these fields only (first pass): `balls_goal`, `innings_goal`, `timeout`, `time_out_warm_up_first_min`, `time_out_warm_up_follow_up_min`, `sets_to_play`, `sets_to_win`. Other fields (boolean checkboxes, select dropdowns) don't need range checks because they're closed-option sets.

### Test strategy (Phase 36b)
- **D-19:** **Minitest unit tests** for the two model-layer changes:
  - `test/models/tournament_test.rb` — assert the round-advance gate at `tournament.rb:382-384` always returns the auto-advance default (`admin_controlled?` no longer blocks)
  - `test/models/discipline_test.rb` — assert `Discipline#parameter_ranges` returns the expected ranges per discipline and handles unknown disciplines gracefully (default ranges or empty hash)
- **D-20:** **Capybara system tests** for the two safety dialogs (load-bearing features):
  - `test/system/tournament_reset_confirmation_test.rb` — Reset link shows the modal, Cancel preserves data, Confirm triggers the reset action
  - `test/system/tournament_parameter_verification_test.rb` — submitting the start form with out-of-range values shows the modal; in-range values go straight through
- **D-21:** No system tests for FIX-01 (trivial ERB change), FIX-03 (visual regression hard to assert — UAT only), FIX-04 (visual regression — UAT only), UI-01 (tooltip trigger — UAT only), UI-02 (i18n resolution — manual spot-check in carambus_bcw), UI-04 (dead-code removal — grep-verified), UI-05 (file deletion — git status verified). Manual UAT in carambus_bcw covers all visual items.

### Claude's Discretion
- Exact color palette for AASM state badges (D-02) — Tailwind classes, contrast-safe.
- Step-chip visual treatment (underline? background fill? border?) — D-01 leaves this open.
- Tooltip card styling (rounded corners, drop shadow, arrow pointer) — Tailwind defaults acceptable.
- Modal animation (fade, slide, none) — project has no existing modal pattern, so pick something minimal.
- The exact Ruby idiom for the shared Stimulus modal API (data-attributes-only vs Turbo Stream vs Reflex-triggered) — whatever fits the existing `TournamentReflex` patterns.
- Discipline parameter range values (the numeric thresholds themselves) — first pass uses reasonable defaults; user will validate during UAT.
- i18n English translations for UI-02 labels — mirror the German meaning faithfully, don't invent new terminology.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` §Phase 36b (lines ~105-128) — Goal, success criteria, 10 requirement IDs
- `.planning/REQUIREMENTS.md` §Phase 36b (lines 42-56) — FIX-01/03/04 + UI-01..07 with acceptance prose
- `.planning/v7.0-scope-evolution.md` — rationale for the 36→36a/36b/36c split
- `.planning/PROJECT.md` — v7.0 Manager Experience framing (2×/year volunteer persona)

### Upstream phase artifacts (read these before planning)
- `.planning/phases/33-ux-review-wizard-audit/33-CONTEXT.md` — Phase 33 decisions (D-11 tier rules, D-09 retirement scope) that gate UI-05
- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — F-14 (English labels), F-19 (transient state feedback), F-24 (unused partial), tier classification for every finding
- `.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md` — F-36-15 meta-finding (Doc-Schritte ≠ UI-Screens ≠ AASM-States), F-36-28 (UI-04 dead-code), F-36-29 (UI-03 manual round-change removal), F-36-32 (UI-06 Reset safety), F-36-55 (UI-07 parameter verification)
- `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md` — 57/58 findings addressed, F-36-55 explicitly mapped to Phase 36b UI-07

### Code touched by this phase
- `app/views/tournaments/_wizard_steps_v2.html.erb` (386 lines) — canonical wizard partial; FIX-01, FIX-03, FIX-04 land here
- `app/views/tournaments/tournament_monitor.html.erb` (131 lines) — start-form with 13+ parameter fields; UI-01, UI-02, UI-03 (checkbox removal), UI-07 (form submit check) all land here
- `app/views/tournaments/_wizard_steps.html.erb` — UI-05 deletion target
- `app/views/tournaments/_wizard_step.html.erb` — UI-05 deletion target (re-verify no references before `git rm`)
- `app/helpers/tournament_wizard_helper.rb` (162 lines) — wizard_current_step, wizard_status_text, wizard_progress_percent, step_class, step_icon; FIX-03 + FIX-04 may add new helpers here (`wizard_state_badge_class`, `wizard_bucket_chips`)
- `app/models/tournament.rb` §lines 238-260 (attribute lists), §line 254 (safe_attributes), §lines 382-384 (`players_advance_without_referee?` gate) — UI-03 simplification target
- `app/models/discipline.rb` — UI-07 `Discipline#parameter_ranges` method lives here (new method)
- `app/reflexes/tournament_reflex.rb` — UI-03 removes the `admin_controlled` handler; UI-01/UI-02 do not touch this file
- `config/locales/de.yml` + `config/locales/en.yml` — new `tournaments.monitor_form.labels.*` and `tournaments.monitor_form.tooltips.*` namespaces for UI-01 + UI-02
- `app/javascript/controllers/tooltip_controller.js` — NEW file for UI-01
- `app/javascript/controllers/confirmation_modal_controller.js` — NEW file, shared by UI-06 + UI-07
- `app/views/shared/_confirmation_modal.html.erb` — NEW partial, shared by UI-06 + UI-07

### Test files
- `test/models/tournament_test.rb` — extend with UI-03 gate-behavior assertions
- `test/models/discipline_test.rb` — extend (or create if missing) with UI-07 `parameter_ranges` assertions
- `test/system/tournament_reset_confirmation_test.rb` — NEW (UI-06)
- `test/system/tournament_parameter_verification_test.rb` — NEW (UI-07)

### Scenario note
- `.agents/skills/scenario-management/SKILL.md` — edits stay in `carambus_api` only; never touch `../carambus_master`. Manual UAT runs against `carambus_bcw` (LOCAL context) since `carambus_api` is API-mode in dev.

### No separate external specs
The v7.0 scope is fully captured in ROADMAP + REQUIREMENTS + Phase 33/36a artifacts. No ADRs, no external design specs.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`TournamentWizardHelper`** (`app/helpers/tournament_wizard_helper.rb`) — already provides `wizard_current_step`, `wizard_status_text` (6-bucket mapping), `wizard_progress_percent`, `step_class`, `step_icon`. FIX-03/FIX-04 will extend this helper rather than writing ad-hoc logic in the ERB.
- **`TournamentReflex`** (`app/reflexes/tournament_reflex.rb`) — handles live updates for all 13 parameter fields via `change->TournamentReflex#field_name`. UI-03 removes only the `admin_controlled` handler; the rest stay untouched.
- **Existing `data: { confirm: ... }` pattern** — used at `_wizard_steps_v2.html.erb:89` for the "Ergebnisse von ClubCloud laden" button. Not being reused for UI-06/UI-07 because the user chose Stimulus modal (D-15) for better UX consistency, but the pattern is available as a fallback if modal implementation hits blockers.
- **Existing i18n conventions** — `config/locales/de.yml` already has `tournaments.show.balls_goal` / `innings_goal` / `auto_upload_to_cc` keys (Phase 34 work). UI-02 extends this under a new `tournaments.monitor_form.*` namespace to keep form-specific keys separate from display keys.
- **`LocalProtector` concern** — protects records with `id < 50_000_000` from modification on local servers. Relevant to UI-03: global Tournament records must continue to be readable even after the gate is removed; D-11 keeps the column precisely to avoid breaking this contract.

### Established Patterns
- **Canonical wizard partial:** `_wizard_steps_v2.html.erb` is the single wizard render target, proven by Phase 33 grep audit. Non-canonical partials are UI-05 deletion candidates.
- **Organizer-type branching:** the canonical partial already uses `if tournament.organizer.is_a?(Region)` to conditionally show the ClubCloud sync step. FIX-03 "conditional on organizer type" respects this existing pattern; no new branching logic.
- **StimulusReflex + Turbo + importmap:** the project's JS stack. New Stimulus controllers register via importmap-rails; no bundler. Any new controller (tooltip, confirmation_modal) must be importmap-compatible.
- **Tailwind CSS** — the project's styling layer. All new UI additions (state badges, hover cards, modals) use Tailwind utility classes; no new CSS files.
- **Minitest + Capybara** — test framework. System tests live in `test/system/`; use `test_helper.rb` which already disables `LocalProtector` via `LocalProtectorTestOverride`.

### Integration Points
- **`show.html.erb:35`** — the one render call that sets `_wizard_steps_v2.html.erb` as canonical. Don't touch (Phase 33 D-09).
- **`start_tournament_path(@tournament)`** form submit at `tournament_monitor.html.erb:39` — UI-07 intercepts this submit to run the parameter verification modal before `start_tournament!` actually fires.
- **`reset_tournament_monitor_path`** (or equivalent) — UI-06 intercepts the reset link to show the confirmation modal.
- **Phase 36c dependency direction:** 36c depends on 36a AND 36b (per ROADMAP). 36b does NOT wait for anything from 36c. PREP-04 (CC admin appendix) flows 36c → 36a, not 36c → 36b.

</code_context>

<specifics>
## Specific Ideas

- User's framing of UI-03: "default to automatic — not admin controlled, remove editable field from parameters form". This is the load-bearing sentence for D-09/D-10/D-11. The intent is explicit: the manual-round-change feature is being retired, not paused. New tournaments behave as if `admin_controlled: false` regardless of what the column says.
- The shared confirmation modal (D-15) is deliberately chosen to serve both UI-06 and UI-07 from the same controller + partial. This is a small investment in UI consistency that pays off in future safety-feature work (backlog: Reset-safety for other AASM transitions, pre-finalize confirmation, etc.).
- The 2×/year volunteer persona drives several "always-shown" defaults — UI-06 is always shown regardless of state, UI-01 tooltips are on every field not just non-obvious ones. Better to over-explain to an infrequent user than to optimize for power users.
- i18n label namespace (`tournaments.monitor_form.labels.*`) is a deliberate split from `tournaments.show.*`. The monitor_form is editable parameters; show is display. Keeping them separate prevents drift and makes Phase 37 doc-link work easier (anchors map cleanly to i18n namespaces).

</specifics>

<deferred>
## Deferred Ideas

- **Reset-safety for other AASM transitions** (e.g., confirm before `finish_seeding`) — the shared modal pattern enables this, but it's out of scope for 36b. Capture as a seed item for Phase 36c PREP-03 backlog.
- **Richer tooltip content** (markdown, doc links, discipline-specific examples) — the Stimulus controller foundation from D-05 supports this, but first pass uses plain-text tooltips. Revisit when Phase 37 in-app doc links land.
- **Full `Discipline#parameter_ranges` sourced from database** — D-17 first pass uses hardcoded constants in the model. Moving to a database-backed `discipline_parameter_ranges` table is a future refinement if the hardcoded values prove too rigid.
- **`admin_controlled` column drop via migration** — D-11 deliberately keeps the column. A future cleanup phase (post-v7.0) can drop it once we're certain no global records are being read into local context with this field set.
- **System tests for wizard visual regression** (FIX-03, FIX-04, UI-01, UI-02) — D-21 defers to manual UAT. If regression becomes a problem in later phases, consider adding Capybara snapshot tests or a screenshot diff tool.
- **i18n English translations for doc content** — UI-02 covers form labels; the full walkthrough DE/EN sync is already done by Phase 36a.
- **F-36-55 coverage confirmation** — F-36-55 (parameter verification dialog) is the same feature as UI-07. Phase 36a's coverage matrix explicitly maps it here. No standalone work needed.
- **No todos folded** — `gsd-tools todo match-phase` returned 0 matches at the time of discussion (cross-reference step was skipped because no backlog items matched this phase's scope keywords).

</deferred>

---

*Phase: 36B-ui-cleanup-kleine-features*
*Context gathered: 2026-04-14*
