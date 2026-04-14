---
phase: 36B
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/views/tournaments/_wizard_steps_v2.html.erb
  - app/helpers/tournament_wizard_helper.rb
autonomous: true
requirements: [FIX-01, FIX-03, FIX-04]
tags: [ui, wizard, helper, erb]

must_haves:
  truths:
    - "The 2×/year volunteer's eye lands on the current AASM state before anything else in the wizard header"
    - "Bare 'Schritt N von 6' progress text no longer appears in the wizard header"
    - "The six wizard buckets appear as chips/pills with the active one visually highlighted"
    - "Per-step number prefixes (e.g., '1.', '2.') no longer render inside any step card"
    - "When the active step's help block is rendered, its <details> is open by default"
    - "Non-active steps' help <details> remain collapsed"
  artifacts:
    - path: "app/views/tournaments/_wizard_steps_v2.html.erb"
      provides: "Rewritten wizard header + open=:active help blocks"
    - path: "app/helpers/tournament_wizard_helper.rb"
      provides: "wizard_state_badge_class, wizard_state_badge_label, wizard_bucket_chips helpers"
  key_links:
    - from: "app/views/tournaments/_wizard_steps_v2.html.erb"
      to: "app/helpers/tournament_wizard_helper.rb"
      via: "wizard_state_badge_class(tournament) + wizard_bucket_chips(tournament)"
      pattern: "wizard_state_badge_class|wizard_bucket_chips"
    - from: "app/views/tournaments/_wizard_steps_v2.html.erb"
      to: "wizard_step_status helper"
      via: "<details open=\"...\"> when status == :active"
      pattern: "wizard_step_status.*:active"
---

<objective>
Rewrite the wizard header in `_wizard_steps_v2.html.erb` so that:
1. FIX-04 — the AASM state becomes the dominant visual element (large colored badge row), not the thin progress bar.
2. FIX-03 — the six wizard buckets render as chips/pills (using the existing `wizard_status_text` 6-bucket mapping), replacing bare `Schritt N von 6` text and per-step `1.`/`2.` number prefixes. Per D-03, the existing `if tournament.organizer.is_a?(Region)` branching stays untouched.
3. FIX-01 — the active step's help `<details>` block opens by default; non-active steps stay collapsed.

Helper logic moves into `TournamentWizardHelper` (`wizard_state_badge_class`, `wizard_state_badge_label`, `wizard_bucket_chips`) to keep the ERB declarative.

Purpose: A 2×/year volunteer sees the current state and the six buckets at a glance, and the relevant help is already open.

Output: One rewritten partial + one extended helper. No controller or model changes. No new files. No test changes (D-21: manual UAT only).

**Baseline facts (verified by reading the source file before writing this plan):**
- `app/views/tournaments/_wizard_steps_v2.html.erb` currently contains **6** occurrences of `organizer.is_a?(Region)` (lines 28, 147, 248, 269, 287, 310)
- Task 2 step B removes 2 of those (lines 147 and 310 — the two `step-number` span expressions)
- Expected post-task count: **4** `organizer.is_a?(Region)` occurrences
- `<details>` currently appears 4 times (lines 62, 103, 178, 325). Task 3 converts 3 of them (62, 178, 325) to `<details<%= ' open' if ... %>>`, leaving exactly 1 literal `<details>` (line 103, the troubleshooting block)
- `if wizard_step_status` currently appears 5 times in `_wizard_steps_v2.html.erb` (lines 38, 170, 317, 350, 355). Plan 01 adds 3 more inside `<details<%= ' open' if wizard_step_status ... %>>`, so the post-task count is **8**.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/REQUIREMENTS.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@app/views/tournaments/_wizard_steps_v2.html.erb
@app/helpers/tournament_wizard_helper.rb

<interfaces>
<!-- From app/helpers/tournament_wizard_helper.rb -->
<!-- Existing helpers that the new code must keep calling -->

def wizard_current_step(tournament) -> Integer (1..8)
def wizard_step_status(tournament, step_number) -> Symbol (:completed|:active|:pending)
def wizard_progress_percent(tournament) -> Integer (0..100)
def wizard_status_text(tournament) -> String (one of "Vorbereitung", "Setzliste konfigurieren", "Modus-Auswahl", "Bereit zum Start", "Turnier läuft", "Abgeschlossen")
def step_icon(status) -> String (emoji)
def step_class(status) -> String (CSS class name)

<!-- AASM states (from app/models/tournament.rb) that the badge must handle -->
new_tournament, accreditation_finished, tournament_seeding_finished,
tournament_mode_defined, tournament_started_waiting_for_monitors,
tournament_started, tournament_finished, results_published, closed
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Add wizard_state_badge_class, wizard_state_badge_label, and wizard_bucket_chips helpers</name>
  <files>app/helpers/tournament_wizard_helper.rb</files>
  <read_first>
    - app/helpers/tournament_wizard_helper.rb (full file — mirror the existing helper style)
    - app/models/tournament.rb lines 271-311 (full AASM state list, including tournament_started_waiting_for_monitors, tournament_finished, closed)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-01, §D-02, §D-03
  </read_first>
  <action>
Extend `app/helpers/tournament_wizard_helper.rb` with three new public helper methods.

1. `wizard_state_badge_class(tournament)` returns a single Tailwind class string for the state badge background/text. Use this exact mapping (keys are `tournament.state` / `aasm_state` strings):

```ruby
def wizard_state_badge_class(tournament)
  case tournament.state.to_s
  when "new_tournament"                         then "bg-orange-500 text-white"
  when "accreditation_finished",
       "tournament_seeding_finished"            then "bg-blue-500 text-white"
  when "tournament_mode_defined"                then "bg-indigo-500 text-white"
  when "tournament_started_waiting_for_monitors" then "bg-yellow-500 text-gray-900"
  when "tournament_started"                     then "bg-green-600 text-white"
  when "tournament_finished"                    then "bg-green-800 text-white"
  when "results_published"                      then "bg-gray-700 text-white"
  when "closed"                                 then "bg-gray-500 text-white"
  else                                               "bg-gray-400 text-white"
  end
end
```

2. `wizard_state_badge_label(tournament)` returns the localized human label for the badge. Use the existing `tournament.state` keys from `de.yml` if they exist, otherwise fall back to a humanized string. The goal is a short German noun-phrase ("Vorbereitung", "Teilnehmer finalisiert", "Modus gewählt", "Wartet auf Tische", "Turnier läuft", "Turnier beendet", "Veröffentlicht", "Geschlossen").

```ruby
def wizard_state_badge_label(tournament)
  case tournament.state.to_s
  when "new_tournament"                         then "Vorbereitung"
  when "accreditation_finished"                 then "Teilnehmer abgeschlossen"
  when "tournament_seeding_finished"            then "Setzliste finalisiert"
  when "tournament_mode_defined"                then "Modus gewählt"
  when "tournament_started_waiting_for_monitors" then "Wartet auf Tische"
  when "tournament_started"                     then "Turnier läuft"
  when "tournament_finished"                    then "Turnier beendet"
  when "results_published"                      then "Ergebnisse veröffentlicht"
  when "closed"                                 then "Geschlossen"
  else                                               tournament.state.to_s.humanize
  end
end
```

3. `wizard_bucket_chips(tournament)` returns an array of hashes describing the six buckets for the ERB to render. Each hash has `:label` (String) and `:active` (Boolean). The active bucket is determined by `wizard_status_text(tournament)` — the existing helper already maps the 8 internal steps down to 6 bucket labels.

```ruby
WIZARD_BUCKETS = [
  "Vorbereitung",
  "Setzliste konfigurieren",
  "Modus-Auswahl",
  "Bereit zum Start",
  "Turnier läuft",
  "Abgeschlossen"
].freeze

def wizard_bucket_chips(tournament)
  current_label = wizard_status_text(tournament)
  WIZARD_BUCKETS.map { |label| { label: label, active: label == current_label } }
end
```

Add `WIZARD_BUCKETS` as a frozen constant at the top of the module (after `module TournamentWizardHelper`). Keep every existing helper intact — add, do not replace. Follow the project convention of German business comments + `# frozen_string_literal: true` at top.
  </action>
  <verify>
    <automated>bundle exec standardrb app/helpers/tournament_wizard_helper.rb && ruby -c app/helpers/tournament_wizard_helper.rb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "def wizard_state_badge_class" app/helpers/tournament_wizard_helper.rb` returns `1`
    - `grep -c "def wizard_state_badge_label" app/helpers/tournament_wizard_helper.rb` returns `1`
    - `grep -c "def wizard_bucket_chips" app/helpers/tournament_wizard_helper.rb` returns `1`
    - `grep -c "WIZARD_BUCKETS" app/helpers/tournament_wizard_helper.rb` returns `2` (constant definition + use)
    - `grep -c "def wizard_status_text" app/helpers/tournament_wizard_helper.rb` returns `1` (existing helper NOT removed)
    - `grep -c "def wizard_current_step" app/helpers/tournament_wizard_helper.rb` returns `1` (existing helper NOT removed)
    - `bundle exec standardrb app/helpers/tournament_wizard_helper.rb` exits 0
  </acceptance_criteria>
  <done>
    New helpers exist, return correct values for each AASM state, constant is frozen, and no existing helper was removed or renamed. standardrb is clean.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Rewrite wizard header (bucket chips + dominant state badge)</name>
  <files>app/views/tournaments/_wizard_steps_v2.html.erb</files>
  <read_first>
    - app/views/tournaments/_wizard_steps_v2.html.erb lines 1-30 (current header markup) and lines 140-250 (per-step headers with `<span class="step-number">`)
    - app/helpers/tournament_wizard_helper.rb (to see the new helpers from Task 1)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-01, §D-02, §D-03
  </read_first>
  <action>
Rewrite ONLY the wizard header block (currently lines 5-22 of `_wizard_steps_v2.html.erb`) and remove the per-step number prefixes from the cards below. Do NOT touch anything inside step bodies other than the span.step-number elements and the per-step active help block (covered by Task 3).

**A — Replace the header block.** Replace the existing `<div class="wizard-header">...</div>` block (lines 5-22) with:

```erb
<!-- Wizard Header: State badge + bucket chips (FIX-03, FIX-04) -->
<div class="wizard-header">
  <h2 class="wizard-title">
    <span class="tournament-icon">🎯</span>
    Turnier-Setup: <%= tournament.title %>
  </h2>

  <!-- Dominant AASM state badge (FIX-04) -->
  <div class="flex items-center justify-center my-4">
    <span class="<%= wizard_state_badge_class(tournament) %> inline-block px-6 py-3 rounded-lg text-2xl font-bold shadow-md tracking-wide">
      <%= wizard_state_badge_label(tournament) %>
    </span>
  </div>

  <!-- Bucket chips (FIX-03, D-01) -->
  <div class="flex flex-wrap justify-center gap-2 mb-2">
    <% wizard_bucket_chips(tournament).each do |chip| %>
      <span class="px-3 py-1 rounded-full text-sm font-medium border <%= chip[:active] ? 'bg-blue-600 text-white border-blue-700 shadow' : 'bg-gray-100 text-gray-600 border-gray-300' %>">
        <%= chip[:label] %>
      </span>
    <% end %>
  </div>
</div>
```

Intentional omissions vs. the original:
- NO `Schritt N von 6` text (D-01)
- NO `progress-bar` / `progress-bar-container` / `progress-text` divs — the badge replaces the progress bar (D-02, "may be removed entirely")
- NO call to `wizard_progress_percent` from the header (the helper stays defined for possible future use)
- NO call to `wizard_status_text` from the header (label now comes from `wizard_state_badge_label`; the bucket highlight uses `wizard_bucket_chips`)

**B — Remove per-step number prefixes from the three inline step cards.** The `_wizard_steps_v2.html.erb` partial has three step cards that directly render their header (not via `_wizard_step.html.erb` render calls). Remove the `<span class="step-number">...</span>` line from each:

1. Line ~36: Schritt 1 (Meldeliste von ClubCloud laden) — remove `<span class="step-number">1.</span>` (this one does NOT use `organizer.is_a?(Region)`)
2. Line ~147: Schritt 2 (Setzliste aus Einladung) — remove `<span class="step-number"><%= tournament.organizer.is_a?(Region) ? 2 : 1 %>.</span>` (removes 1 `organizer.is_a?(Region)` occurrence)
3. Line ~310: Schritt 6 (Verwaltung der Turnierspiele) — remove `<span class="step-number"><%= tournament.organizer.is_a?(Region) ? 6 : 5 %>.</span>` (removes 1 `organizer.is_a?(Region)` occurrence)

Total: **2** `organizer.is_a?(Region)` occurrences are removed by this step. Baseline was 6 → post-task count is exactly **4** (lines 28, 248, 269, 287 remain unchanged).

Keep the `<h4 class="step-title">` elements — chip-based orientation replaces the numeric prefix, but the per-step title stays (D-01 removes NUMBERS, not titles).

**C — Leave the rendered `wizard_step` partial calls untouched in this task.** The `_wizard_step.html.erb` partial at line 30 of that file also has `<span class="step-number"><%= number %>.</span>` — per D-14 that file stays (it's still used for steps 3, 4, 5). Update it too:

In `app/views/tournaments/_wizard_step.html.erb` line ~30, replace:
```erb
<span class="step-number"><%= number %>.</span>
<h4 class="step-title"><%= title %></h4>
```
with:
```erb
<h4 class="step-title"><%= title %></h4>
```

Do NOT remove the `number:` local parameter from the partial signature or from the render calls — some future refactor may want it. Just drop the visible prefix. Do NOT delete the partial (that's plan 04's decision point for `_wizard_steps.html.erb`, and `_wizard_step.html.erb` stays).

**D — Do NOT remove or rename existing CSS classes.** The `wizard-header`, `wizard-steps`, `wizard-step`, `step-title`, `step-info`, etc. class names may be styled in external CSS; keeping them preserves styling continuity. The new markup ADDS Tailwind utility classes alongside existing classes, it does not rename them.

Organizer-type branching (D-03): do NOT introduce any new `if tournament.organizer.is_a?(Region)` branches. The existing branches at lines 28, 248, 269, 287 stay as-is; only the two branches inside removed `step-number` spans (lines 147, 310) go away.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb app/views/tournaments/_wizard_step.html.erb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c 'wizard_state_badge_class' app/views/tournaments/_wizard_steps_v2.html.erb` returns `1`
    - `grep -c 'wizard_bucket_chips' app/views/tournaments/_wizard_steps_v2.html.erb` returns `1`
    - `grep -c 'Schritt .* von 6' app/views/tournaments/_wizard_steps_v2.html.erb` returns `0`
    - `grep -c 'step-number' app/views/tournaments/_wizard_steps_v2.html.erb` returns `0`
    - `grep -c 'step-number' app/views/tournaments/_wizard_step.html.erb` returns `0`
    - `grep -c 'progress-bar' app/views/tournaments/_wizard_steps_v2.html.erb` returns `0`
    - `grep -c 'step-title' app/views/tournaments/_wizard_steps_v2.html.erb` returns a positive number (titles stay)
    - `grep -c 'organizer.is_a?(Region)' app/views/tournaments/_wizard_steps_v2.html.erb` returns **exactly `4`** (baseline 6 minus the 2 removed `step-number` expressions)
    - `bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb` exits 0
    - `bundle exec erblint app/views/tournaments/_wizard_step.html.erb` exits 0
  </acceptance_criteria>
  <done>
    Header renders the state badge as the dominant element with the six bucket chips below it. No number prefixes anywhere inside step cards. Existing Region-organizer branches at lines 28, 248, 269, 287 are preserved. erblint is clean on both modified files.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: FIX-01 — open active step's help <details> by default</name>
  <files>
    app/views/tournaments/_wizard_steps_v2.html.erb
    app/views/tournaments/_wizard_step.html.erb
  </files>
  <read_first>
    - app/views/tournaments/_wizard_steps_v2.html.erb lines 61-74 (Schritt 1 step-help block), lines 177-193 (Schritt 2 step-help block), lines 324-339 (Schritt 6 step-help block)
    - app/views/tournaments/_wizard_step.html.erb lines 47-54 (shared step-help block used for steps 3, 4, 5)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-04
  </read_first>
  <action>
Make the `<details>` block inside every step-help section render with the `open` attribute when the step is the active step.

**Baseline fact (verified):** `_wizard_steps_v2.html.erb` currently has 4 literal `<details>` tags at lines 62, 103, 178, 325. This task converts 3 of them (62, 178, 325) to `<details<%= ' open' if wizard_step_status(tournament, N) == :active %>>`, leaving exactly **1** literal `<details>` (line 103, the "Turnier nicht gefunden?" troubleshooting block that must stay closed by default).

**A — `_wizard_steps_v2.html.erb`, Schritt 1 help block (~line 62):**
Replace:
```erb
<div class="step-help">
  <details>
    <summary>💡 Was ist die Meldeliste?</summary>
```
with:
```erb
<div class="step-help">
  <details<%= ' open' if wizard_step_status(tournament, 1) == :active %>>
    <summary>💡 Was ist die Meldeliste?</summary>
```

**B — `_wizard_steps_v2.html.erb`, Schritt 2 help block (~line 178):**
Replace the existing `<details>` with `<details<%= ' open' if wizard_step_status(tournament, 2) == :active %>>`.

**C — `_wizard_steps_v2.html.erb`, Schritt 6 help block (~line 325):**
Replace the existing `<details>` with `<details<%= ' open' if wizard_step_status(tournament, 6) == :active %>>`.

**D — `_wizard_step.html.erb` shared partial (~line 49):**
This partial is rendered for steps 3, 4, 5. The step number is already available as the `number` local. Replace:
```erb
<% if help.present? %>
  <div class="step-help">
    <details>
      <summary>💡 Was macht dieser Schritt?</summary>
```
with:
```erb
<% if help.present? %>
  <div class="step-help">
    <details<%= ' open' if status == :active %>>
      <summary>💡 Was macht dieser Schritt?</summary>
```

Note: the partial already receives `status` as a local (see lines 30-36 of the render calls in `_wizard_steps_v2.html.erb`). No need to plumb `wizard_step_status` through — `status` already equals `wizard_step_status(tournament, N)` at the call site.

Do NOT touch the troubleshooting `<details>` at line 103 (the "⚠️ Turnier nicht gefunden?" block) — that's not a step-help block and should stay closed by default.

Do NOT touch the top-level `<dl>` Begriffserklärung box at the bottom (not a `<details>` — not affected).
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb app/views/tournaments/_wizard_step.html.erb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "wizard_step_status(tournament, 1) == :active" app/views/tournaments/_wizard_steps_v2.html.erb` returns `>= 1` (Schritt 1 conditional open added; existing line 38 may also match, which is fine)
    - `grep -c "wizard_step_status(tournament, 2) == :active" app/views/tournaments/_wizard_steps_v2.html.erb` returns `>= 1` (Schritt 2 conditional open added)
    - `grep -c "wizard_step_status(tournament, 6) == :active" app/views/tournaments/_wizard_steps_v2.html.erb` returns `>= 1` (Schritt 6 conditional open added; note that existing lines 317, 350, 355 use different conditions)
    - `grep -c "status == :active" app/views/tournaments/_wizard_step.html.erb` returns `1` (shared partial used by steps 3, 4, 5)
    - `grep -c '<details>' app/views/tournaments/_wizard_steps_v2.html.erb` returns **exactly `1`** (only the troubleshooting block at line 103 remains as a literal `<details>`; the three step-help ones now carry `<details<%= ... %>>`)
    - `grep -c "if wizard_step_status" app/views/tournaments/_wizard_steps_v2.html.erb` returns **exactly `8`** (baseline 5 at lines 38, 170, 317, 350, 355 plus 3 new ones added by this task)
    - `bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb` exits 0
    - `bundle exec erblint app/views/tournaments/_wizard_step.html.erb` exits 0
  </acceptance_criteria>
  <done>
    Active step's help section is open; other steps' help sections are collapsed; troubleshooting and non-step `<details>` blocks are unchanged. erblint clean.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| browser → server | tournament.id in the URL; rendered view contains no user-supplied data in the new header |
| i18n/helper → DOM | new helpers render tournament.state and tournament.title via Rails `<%= %>` which HTML-escapes by default |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b01-01 | Information disclosure (I) | wizard_state_badge_label exposes internal AASM state name to any user who can view the tournament page | accept | The AASM state is already publicly readable elsewhere on the tournament show page (e.g., the existing `Status:` row); no new information is exposed. |
| T-36b01-02 | Tampering (T) / XSS | `tournament.title` rendered in `<h2 class="wizard-title">` | accept-with-mitigation | Title comes from the Tournament model, which is ActiveRecord-managed. Rails `<%= %>` escapes HTML by default (we use `<%= tournament.title %>`, not `raw` or `html_safe`). No change from current behavior — the existing header already renders `<%= tournament.title %>` the same way. |
| T-36b01-03 | Tampering (T) / XSS | Bucket chip labels (strings from `WIZARD_BUCKETS` constant) | mitigate | All six bucket labels are hard-coded Ruby constants. They never contain user input. Rendered via `<%= chip[:label] %>` which HTML-escapes. No interpolation of params. |
| T-36b01-04 | Tampering (T) / class injection | `wizard_state_badge_class(tournament)` returns a string used in a `class="..."` attribute | mitigate | Return value is hard-coded per `tournament.state` case/when. No user input reaches the class string. If `tournament.state` is an unexpected value, fallback returns `"bg-gray-400 text-white"` (still hard-coded). |
</threat_model>

<verification>
1. Run `bundle exec standardrb app/helpers/tournament_wizard_helper.rb` — exits 0.
2. Run `bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb app/views/tournaments/_wizard_step.html.erb` — exits 0.
3. Acceptance-criteria grep checks above all pass.
4. Manual UAT (user runs in carambus_bcw, D-21): open any tournament in `new_tournament` state → state badge is orange and visually dominant, six bucket chips show with "Vorbereitung" highlighted, the active step's help is already open.
</verification>

<success_criteria>
- FIX-01: ✅ active wizard step's `<details>` renders `open`; non-active steps' help remains closed
- FIX-03: ✅ bare "Schritt N von 6" text gone; per-step number prefixes gone; six bucket chips render
- FIX-04: ✅ AASM state badge is the dominant visual element in the header; progress bar removed
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-01-SUMMARY.md` summarizing: helper additions (3 methods + 1 constant), ERB surgery (header rewrite, step-number removal in 4 locations, `<details open=...>` in 4 locations), and any deviations noted.
</output>
</content>
</invoke>