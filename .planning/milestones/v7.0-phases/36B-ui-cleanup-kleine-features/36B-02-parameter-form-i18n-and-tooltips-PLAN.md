---
phase: 36B
plan: 02
type: execute
wave: 1
depends_on: []
files_modified:
  - app/views/tournaments/tournament_monitor.html.erb
  - config/locales/de.yml
  - config/locales/en.yml
  - app/javascript/controllers/tooltip_controller.js
autonomous: true
requirements: [UI-01, UI-02]
tags: [i18n, stimulus, ui, tooltip]

must_haves:
  truths:
    - "Every parameter label in tournament_monitor.html.erb is fetched from an i18n key under tournaments.monitor_form.labels.*"
    - "No hardcoded English literals remain in tournament_monitor.html.erb parameter labels"
    - "Every parameter field EXCEPT admin_controlled has a tooltip that appears on hover/focus"
    - "The admin_controlled row is NOT wrapped in a tooltip (plan 03 deletes the row entirely; wrapping it would create brittle inter-plan coupling)"
    - "Tooltip text comes from tournaments.monitor_form.tooltips.* i18n keys"
    - "de.yml and en.yml both contain the full labels.* and tooltips.* namespaces (all 17 keys in each namespace, including admin_controlled — D-11 preserves reversibility)"
  artifacts:
    - path: "app/javascript/controllers/tooltip_controller.js"
      provides: "Stimulus controller rendering a Tailwind hover card on mouseenter/focus"
      exports: ["default (Controller)"]
    - path: "config/locales/de.yml"
      provides: "tournaments.monitor_form.labels.* and tournaments.monitor_form.tooltips.* keys (German)"
      contains: "monitor_form:"
    - path: "config/locales/en.yml"
      provides: "tournaments.monitor_form.labels.* and tournaments.monitor_form.tooltips.* keys (English)"
      contains: "monitor_form:"
    - path: "app/views/tournaments/tournament_monitor.html.erb"
      provides: "16 tooltip-wrapped localized labels + 1 untooltipped admin_controlled label (row removed by plan 03)"
  key_links:
    - from: "app/views/tournaments/tournament_monitor.html.erb"
      to: "config/locales/*.yml"
      via: "t('tournaments.monitor_form.labels.*') and t('tournaments.monitor_form.tooltips.*')"
      pattern: "tournaments\\.monitor_form\\.(labels|tooltips)"
    - from: "app/views/tournaments/tournament_monitor.html.erb"
      to: "app/javascript/controllers/tooltip_controller.js"
      via: "data-controller=\"tooltip\" data-tooltip-content-value=\"...\""
      pattern: "data-controller=\"tooltip\""
---

<objective>
Deliver UI-01 (parameter field tooltips) and UI-02 (full i18n of parameter form labels) together in one plan because they share the same file (`tournament_monitor.html.erb`) and the same i18n namespace (`tournaments.monitor_form.*`).

D-05: tooltips are a new Stimulus controller with Tailwind hover card, NOT native HTML `title`.
D-06: tooltip content lives under `tournaments.monitor_form.tooltips.{field}` in DE and EN.
D-07: every label in the file becomes `t('tournaments.monitor_form.labels.{field}')`.
D-08: canonical namespace is `tournaments.monitor_form.labels.*` / `tournaments.monitor_form.tooltips.*`.

**Scope limit:** do NOT remove the `admin_controlled` checkbox here — that is plan 03's job. This plan still adds a `labels.admin_controlled` key (and tooltip key for YAML symmetry, preserving D-11 reversibility) so the checkbox remains renderable until plan 03 removes it. **But this plan does NOT wrap the admin_controlled label span in a tooltip trigger**, because plan 03 deletes that entire row and the tooltip wrapper would create inter-plan coupling and a dead key usage. The admin_controlled label still uses `t('tournaments.monitor_form.labels.admin_controlled')`.

Post-plan-02 counts:
- 17 localized labels under `tournaments.monitor_form.labels.*` (16 wrapped in tooltip trigger + 1 admin_controlled plain)
- 16 tooltip triggers (`data-controller="tooltip"` count = 16)
- 16 `data-tooltip-content-value` attributes
- The `tournaments.monitor_form.tooltips.admin_controlled` key exists in YAML but is unused (acceptable — D-11 keeps it for reversibility, and removing the key would churn YAML for no benefit)
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md
@.planning/REQUIREMENTS.md
@app/views/tournaments/tournament_monitor.html.erb
@config/locales/de.yml
@config/locales/en.yml
@app/javascript/controllers/hello_controller.js

<interfaces>
<!-- Existing Stimulus controller pattern (from hello_controller.js) -->
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  static targets = [ "name" ]
  // methods are auto-bound to data-action attributes
}

<!-- Controllers auto-register via app/javascript/controllers/index.js glob: -->
//   import controllers from "./**/*_controller.js"
//   controllers.forEach((c) => application.register(c.name, c.module.default))
// So a new file app/javascript/controllers/tooltip_controller.js is picked up
// with controller name "tooltip" (filename minus "_controller" suffix).

<!-- Existing i18n keys already used by the file -->
t('tournaments.show.balls_goal')    -> "Bälle Ziel"       (de.yml line 1042)
t('tournaments.show.innings_goal')  -> "Aufnahme-begrenzung" (de.yml line 1055)
t('tournaments.show.auto_upload_to_cc') -> "Ergebnisse automatisch in ClubCloud hochladen" (de.yml line 1043)

<!-- NEW namespace this plan creates (D-08) -->
tournaments.monitor_form.labels.{field_name}   # short label text
tournaments.monitor_form.tooltips.{field_name} # explanatory tooltip text
</interfaces>
</context>

<tasks>

<task type="auto" tdd="false">
  <name>Task 1: Create tooltip_controller.js</name>
  <files>app/javascript/controllers/tooltip_controller.js</files>
  <read_first>
    - app/javascript/controllers/hello_controller.js (minimal Stimulus controller pattern)
    - app/javascript/controllers/index.js (auto-registration glob)
    - app/javascript/controllers/dropdown_controller.js (or any existing controller with connect()/disconnect() — mirror the lifecycle)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-05
  </read_first>
  <action>
Create `app/javascript/controllers/tooltip_controller.js` with the exact content below. The controller:
- Reads its tooltip text from `data-tooltip-content-value` (Stimulus value convention).
- On `mouseenter`/`focusin` it creates a `<div>` child positioned absolutely just above the element, populated via `textContent` (NOT `innerHTML` — threat mitigation T-36b02-01).
- On `mouseleave`/`focusout` it removes the `<div>`.
- Uses only Tailwind utility classes on the hover card (`absolute z-50 bg-gray-800 text-white text-sm px-3 py-2 rounded shadow-lg max-w-xs`).
- Registers under the Stimulus name "tooltip" automatically via the index.js glob.

```javascript
import { Controller } from "@hotwired/stimulus"

// Stimulus-Tooltip für die Parameter-Form im Turnier-Monitor (UI-01).
// Zeigt eine Tailwind-Hovercard mit erklärendem Text, wenn der Nutzer das
// Label-Element mit der Maus berührt oder per Tab anfokussiert.
export default class extends Controller {
  static values = { content: String }

  connect() {
    this.element.addEventListener("mouseenter", this.show)
    this.element.addEventListener("mouseleave", this.hide)
    this.element.addEventListener("focusin", this.show)
    this.element.addEventListener("focusout", this.hide)
  }

  disconnect() {
    this.element.removeEventListener("mouseenter", this.show)
    this.element.removeEventListener("mouseleave", this.hide)
    this.element.removeEventListener("focusin", this.show)
    this.element.removeEventListener("focusout", this.hide)
    this.hide()
  }

  show = () => {
    if (!this.contentValue || this.card) return
    // Position the element relatively so absolute child anchors to it
    if (getComputedStyle(this.element).position === "static") {
      this.element.style.position = "relative"
    }
    const card = document.createElement("div")
    card.className = "absolute z-50 bg-gray-800 text-white text-sm px-3 py-2 rounded shadow-lg max-w-xs bottom-full left-0 mb-2 whitespace-normal pointer-events-none"
    // SECURITY: textContent (not innerHTML) — content is static i18n text, but
    // guarding against future misuse that could pipe user input through here.
    card.textContent = this.contentValue
    this.card = card
    this.element.appendChild(card)
  }

  hide = () => {
    if (this.card) {
      this.card.remove()
      this.card = null
    }
  }
}
```

No other files are modified. The controllers/index.js glob auto-registers it.
  </action>
  <verify>
    <automated>node -e "const fs=require('fs'); const src=fs.readFileSync('app/javascript/controllers/tooltip_controller.js','utf8'); if(!src.includes('textContent')) {console.error('MISSING textContent (XSS mitigation)'); process.exit(1)}; if(src.includes('innerHTML')) {console.error('innerHTML is forbidden'); process.exit(1)}; if(!src.includes('static values = { content: String }')) {console.error('MISSING Stimulus value declaration'); process.exit(1)}; console.log('OK');"</automated>
  </verify>
  <acceptance_criteria>
    - `app/javascript/controllers/tooltip_controller.js` exists
    - `grep -c "textContent" app/javascript/controllers/tooltip_controller.js` returns `>= 1`
    - `grep -c "innerHTML" app/javascript/controllers/tooltip_controller.js` returns `0`
    - `grep -c "static values = { content: String }" app/javascript/controllers/tooltip_controller.js` returns `1`
    - `grep -c '@hotwired/stimulus' app/javascript/controllers/tooltip_controller.js` returns `1`
  </acceptance_criteria>
  <done>
    File exists, imports from `@hotwired/stimulus`, declares the `content` value, uses `textContent` only, and auto-registers via the glob in index.js.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 2: Add tournaments.monitor_form.labels.* and tooltips.* keys to de.yml and en.yml</name>
  <files>
    config/locales/de.yml
    config/locales/en.yml
  </files>
  <read_first>
    - config/locales/de.yml lines 1036-1092 (existing `tournaments.show.*` block — the new `tournaments.monitor_form:` block must be a sibling under `tournaments:`)
    - config/locales/en.yml (find the parallel `tournaments:` block — use grep to locate: `grep -n "^  tournaments:" config/locales/en.yml`)
    - app/views/tournaments/tournament_monitor.html.erb lines 60-113 (17 parameter fields that need labels; 16 also need tooltips)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-06, §D-07, §D-08, §D-11
  </read_first>
  <action>
Add a new sub-namespace `monitor_form:` under `tournaments:` in BOTH locale files (`config/locales/de.yml` and `config/locales/en.yml`).

Use YAML indentation that matches the existing `tournaments:` block in each file. In `de.yml` the existing `tournaments.show:` block sits at 4-space indentation under `de:` → `tournaments:` → `show:`. Mirror that: add `monitor_form:` as a sibling of `show:` inside `tournaments:`.

Include **all 17 labels and all 17 tooltip keys** — including `admin_controlled` (even though plan 03 removes the row, D-11 keeps the YAML key for reversibility and the tooltip key stays as symmetric dead data).

**DE keys to add (`config/locales/de.yml`, inside `de:` → `tournaments:`):**

```yaml
    monitor_form:
      labels:
        balls_goal: "Bälle-Ziel"
        innings_goal: "Aufnahmen-Limit"
        timeout: "Timeout (Sek.)"
        timeouts: "Timeouts"
        admin_controlled: "Rundenwechsel manuell bestätigen"
        auto_upload_to_cc: "Ergebnisse automatisch in ClubCloud hochladen"
        continuous_placements: "Spiele zuordnen, sobald Tische frei werden"
        gd_has_prio: "GD priorisiert bei Gruppen-übergreifenden Vergleichen"
        time_out_warm_up_first_min: "Warmup neuer Tisch (Min.)"
        time_out_warm_up_follow_up_min: "Warmup gleicher Tisch (Min.)"
        kickoff_switches_with: "Anstoß wechselt zwischen den Sätzen"
        allow_follow_up: "Nachstoß erlaubt"
        color_remains_with_set: "Ballfarbe bleibt zwischen den Sätzen"
        allow_overflow: "Kein exaktes Erreichen des Ballziels notwendig"
        fixed_display_left: "Darstellung linksseitig"
        sets_to_play: "Zahl der Sätze"
        sets_to_win: "Gewinnsätze"
      tooltips:
        balls_goal: "Zielanzahl der Bälle pro Partie (übliche Werte: 50–200 für Freie Partie, 20–100 für Cadre)."
        innings_goal: "Maximale Aufnahmen pro Partie. 0 = kein Limit. Übliche Werte: 20–80."
        timeout: "Shot-Clock pro Stoß in Sekunden. 0 = ausgeschaltet. Üblich: 30–90 Sekunden."
        timeouts: "Anzahl der verfügbaren Auszeiten pro Spieler und Partie."
        admin_controlled: "Veraltet — wird in Phase 36b entfernt. Der Rundenwechsel läuft künftig immer automatisch."
        auto_upload_to_cc: "Ergebnisse werden nach jedem Spiel automatisch zur ClubCloud hochgeladen. Benötigt gültige ClubCloud-Zugangsdaten."
        continuous_placements: "Neue Spiele werden automatisch freien Tischen zugeordnet, sobald ein Tisch frei wird."
        gd_has_prio: "Bei Gleichstand zwischen Gruppensiegern entscheidet der General-Durchschnitt (GD) vor anderen Kriterien."
        time_out_warm_up_first_min: "Aufwärmzeit in Minuten, wenn ein Spieler an einen neuen Tisch wechselt."
        time_out_warm_up_follow_up_min: "Aufwärmzeit in Minuten, wenn der Spieler am selben Tisch bleibt (kürzer)."
        kickoff_switches_with: "'set' = Anstoß wechselt pro Satz; 'winner' = Verlierer stößt an; leer = kein Wechsel."
        allow_follow_up: "Spieler darf nach einem erfolgreichen Stoß direkt weiterspielen."
        color_remains_with_set: "Die zugewiesene Ballfarbe bleibt über Satzgrenzen hinweg konstant."
        allow_overflow: "Das Ballziel muss nicht exakt erreicht werden — Überschreiten ist erlaubt."
        fixed_display_left: "Welcher Spieler wird im Scoreboard immer links angezeigt? Kick-Off Left = Anstoßender links."
        sets_to_play: "Anzahl der zu spielenden Sätze. 0 = kein Limit."
        sets_to_win: "Anzahl der Sätze, die zum Sieg benötigt werden. 0 = nicht verwendet."
```

**EN keys to add (`config/locales/en.yml`, inside `en:` → `tournaments:`):**

```yaml
    monitor_form:
      labels:
        balls_goal: "Balls goal"
        innings_goal: "Innings limit"
        timeout: "Timeout (sec.)"
        timeouts: "Timeouts per game"
        admin_controlled: "Manual round-change confirmation"
        auto_upload_to_cc: "Automatically upload results to ClubCloud"
        continuous_placements: "Assign games as tables become available"
        gd_has_prio: "GD has priority on inter-group tiebreaks"
        time_out_warm_up_first_min: "Warm-up new table (min.)"
        time_out_warm_up_follow_up_min: "Warm-up same table (min.)"
        kickoff_switches_with: "Kick-off switches between sets"
        allow_follow_up: "Allow a follow-up shot"
        color_remains_with_set: "Ball color persists across sets"
        allow_overflow: "Balls goal does not need to be hit exactly"
        fixed_display_left: "Left-side display fixed"
        sets_to_play: "Sets to play"
        sets_to_win: "Sets to win"
      tooltips:
        balls_goal: "Target ball count per game (typical: 50–200 for straight carom, 20–100 for cadre)."
        innings_goal: "Maximum innings per game. 0 = no limit. Typical: 20–80."
        timeout: "Shot clock per shot in seconds. 0 = disabled. Typical: 30–90."
        timeouts: "Number of timeouts available per player per game."
        admin_controlled: "Deprecated — removed in Phase 36b. Round advance is now always automatic."
        auto_upload_to_cc: "Results are uploaded to ClubCloud automatically after each game. Requires valid ClubCloud credentials."
        continuous_placements: "New games are auto-assigned to tables as tables become free."
        gd_has_prio: "When group winners are tied, general average (GD) takes priority over other tiebreakers."
        time_out_warm_up_first_min: "Warm-up minutes when a player moves to a new table."
        time_out_warm_up_follow_up_min: "Warm-up minutes when a player stays at the same table (shorter)."
        kickoff_switches_with: "'set' = kick-off alternates per set; 'winner' = loser breaks; empty = no switch."
        allow_follow_up: "A player may take a follow-up shot after a successful stroke."
        color_remains_with_set: "The assigned ball color stays constant across set boundaries."
        allow_overflow: "The balls goal need not be hit exactly — exceeding it is allowed."
        fixed_display_left: "Which player is always shown on the left of the scoreboard? Kick-Off Left = breaker on left."
        sets_to_play: "Number of sets to play. 0 = no limit."
        sets_to_win: "Number of sets required to win. 0 = not used."
```

**Important insertion point:** insert the `monitor_form:` block at the same indent level as `show:` under `tournaments:`. Use the Read tool first to locate the exact line number of `show:` under `tournaments:` in each file, then use Edit to insert the new block immediately before or after.

Do NOT remove or modify existing `tournaments.show.balls_goal`, `tournaments.show.innings_goal`, or `tournaments.show.auto_upload_to_cc` — they are used elsewhere (Phase 34 walkthrough docs, other views). This plan ADDS a parallel `monitor_form` namespace.

Ensure both files still parse as valid YAML.
  </action>
  <verify>
    <automated>ruby -r yaml -e "YAML.load_file('config/locales/de.yml'); YAML.load_file('config/locales/en.yml'); puts 'OK'" && ruby -r yaml -e "de = YAML.load_file('config/locales/de.yml'); en = YAML.load_file('config/locales/en.yml'); raise 'DE monitor_form missing' unless de.dig('de','tournaments','monitor_form','labels','balls_goal'); raise 'EN monitor_form missing' unless en.dig('en','tournaments','monitor_form','labels','balls_goal'); raise 'DE tooltip missing' unless de.dig('de','tournaments','monitor_form','tooltips','balls_goal'); raise 'EN tooltip missing' unless en.dig('en','tournaments','monitor_form','tooltips','balls_goal'); puts 'STRUCTURE OK'"</automated>
  </verify>
  <acceptance_criteria>
    - `ruby -r yaml -e "YAML.load_file('config/locales/de.yml')"` exits 0
    - `ruby -r yaml -e "YAML.load_file('config/locales/en.yml')"` exits 0
    - DE file contains keys `tournaments.monitor_form.labels.balls_goal`, `.innings_goal`, `.timeout`, `.timeouts`, `.admin_controlled`, `.auto_upload_to_cc`, `.continuous_placements`, `.gd_has_prio`, `.time_out_warm_up_first_min`, `.time_out_warm_up_follow_up_min`, `.kickoff_switches_with`, `.allow_follow_up`, `.color_remains_with_set`, `.allow_overflow`, `.fixed_display_left`, `.sets_to_play`, `.sets_to_win` (17 keys) AND the parallel 17 tooltip keys
    - EN file contains the same 17 labels + 17 tooltip keys
    - `grep -c "tournaments.show.balls_goal" config/locales/de.yml` still returns `>= 1` (existing key preserved)
  </acceptance_criteria>
  <done>
    Both locale files parse as valid YAML, the new `monitor_form:` sub-namespace exists with 17 labels and 17 tooltips in each language, and the pre-existing `tournaments.show.*` keys are untouched.
  </done>
</task>

<task type="auto" tdd="false">
  <name>Task 3: Rewrite tournament_monitor.html.erb labels to i18n + wrap 16 of 17 labels in tooltip trigger (NOT admin_controlled)</name>
  <files>app/views/tournaments/tournament_monitor.html.erb</files>
  <read_first>
    - app/views/tournaments/tournament_monitor.html.erb (full file — 131 lines)
    - config/locales/de.yml (to confirm the keys from Task 2 exist)
    - .planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md §D-05, §D-07, §D-08, §D-11
  </read_first>
  <action>
For every parameter row in the `<h4>Turnier Parameter</h4>` block (lines 60-113), replace the hardcoded label with an i18n call. For **16 of the 17** rows, also wrap the label span in a tooltip trigger. The `admin_controlled` row gets the i18n label but **NO** tooltip wrapper, because plan 03 deletes that entire row and wrapping it would create inter-plan coupling.

The 17 parameter rows are (in file order):

| Field | Current label source | New i18n key | Wrap in tooltip? |
|---|---|---|---|
| balls_goal | `t('tournaments.show.balls_goal')` | `tournaments.monitor_form.labels.balls_goal` | YES |
| innings_goal | `t('tournaments.show.innings_goal')` | `tournaments.monitor_form.labels.innings_goal` | YES |
| timeout | `"Timeout (Sek.)"` | `tournaments.monitor_form.labels.timeout` | YES |
| timeouts | `"Timeouts"` | `tournaments.monitor_form.labels.timeouts` | YES |
| **admin_controlled** | `"Tournament Manager checks results before acceptance"` | `tournaments.monitor_form.labels.admin_controlled` | **NO — plan 03 removes this row** |
| auto_upload_to_cc | `t('tournaments.show.auto_upload_to_cc', default: ...)` | `tournaments.monitor_form.labels.auto_upload_to_cc` | YES |
| continuous_placements | `"Assign Games as Tables become available"` | `tournaments.monitor_form.labels.continuous_placements` | YES |
| gd_has_prio | `"GD has prio on inter-group-comparisons"` | `tournaments.monitor_form.labels.gd_has_prio` | YES |
| time_out_warm_up_first_min | `"WarmUp New Table (Min.)"` | `tournaments.monitor_form.labels.time_out_warm_up_first_min` | YES |
| time_out_warm_up_follow_up_min | `"WarmUp Same Table (Min.)"` | `tournaments.monitor_form.labels.time_out_warm_up_follow_up_min` | YES |
| kickoff_switches_with | `"Der Anstoß wechselt zwischen den Sätzen"` | `tournaments.monitor_form.labels.kickoff_switches_with` | YES |
| allow_follow_up | `"Erlaube einen Nachstoß"` | `tournaments.monitor_form.labels.allow_follow_up` | YES |
| color_remains_with_set | `"Die Ballfarbe bleibt zwischen den Sätzen"` | `tournaments.monitor_form.labels.color_remains_with_set` | YES |
| allow_overflow | `"Kein exaktes Erreichen des Ballzieles notwendig"` | `tournaments.monitor_form.labels.allow_overflow` | YES |
| fixed_display_left | `"Darstellung linksseitig"` | `tournaments.monitor_form.labels.fixed_display_left` | YES |
| sets_to_play | `"Zahl der Sätze"` | `tournaments.monitor_form.labels.sets_to_play` | YES |
| sets_to_win | `"Gewinnsätze"` | `tournaments.monitor_form.labels.sets_to_win` | YES |

**Wrapper pattern for the 16 YES rows:** replace the current label span:
```erb
<span class="w-1/2 text-right text-sm"><%= label_tag "Some Literal" %></span>
```
with the tooltip-wrapped version:
```erb
<span class="w-1/2 text-right text-sm" data-controller="tooltip" data-tooltip-content-value="<%= t('tournaments.monitor_form.tooltips.FIELD') %>">
  <%= label_tag t('tournaments.monitor_form.labels.FIELD') %>
</span>
```

where `FIELD` is the table entry above.

**Concrete example** — line 63 (balls_goal) changes from:
```erb
<span class="w-1/2 text-right text-sm"><%= label_tag t('tournaments.show.balls_goal') %></span>
```
to:
```erb
<span class="w-1/2 text-right text-sm" data-controller="tooltip" data-tooltip-content-value="<%= t('tournaments.monitor_form.tooltips.balls_goal') %>">
  <%= label_tag t('tournaments.monitor_form.labels.balls_goal') %>
</span>
```

**Admin_controlled row (the ONE NO row):** the label still becomes `t('tournaments.monitor_form.labels.admin_controlled')` but the span is NOT wrapped in a tooltip. The row before transformation looks like:
```erb
<span class="w-1/2 text-right text-sm"><%= label_tag "Tournament Manager checks results before acceptance" %></span>
```
After transformation:
```erb
<span class="w-1/2 text-right text-sm"><%= label_tag t('tournaments.monitor_form.labels.admin_controlled') %></span>
```
No `data-controller="tooltip"`, no `data-tooltip-content-value`. This avoids churning inter-plan state — plan 03 will delete the entire `<div class="flex flex-row space-x-4 items-center">...</div>` row including this span.

**Do NOT remove** the `admin_controlled` row in this plan — plan 03 (wave 2) removes the checkbox entirely. Leaving it here with the new label (but without the tooltip wrapper) avoids file conflicts.

**Do NOT modify** any `<%= number_field_tag ... %>`, `<%= check_box_tag ... %>`, or `<%= select_tag ... %>` element — the input elements and their Reflex `data:` attributes stay as-is. Only the label spans change.

**Do NOT modify** anything outside the `<h4 class="mb-4">Turnier Parameter</h4>` block (lines 60-113). The `<h4 class="mb-2">Zuordnung der Tische</h4>` section above (table-assignment loop) and the `<%= submit_tag ... %>` below are untouched.
  </action>
  <verify>
    <automated>bundle exec erblint app/views/tournaments/tournament_monitor.html.erb</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "data-controller=\"tooltip\"" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `16`**
    - `grep -c "data-tooltip-content-value" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `16`**
    - `grep -c "tournaments.monitor_form.labels" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `17`** (all 17 rows use the new label namespace, including admin_controlled)
    - `grep -c "tournaments.monitor_form.tooltips" app/views/tournaments/tournament_monitor.html.erb` returns **exactly `16`**
    - `grep -c 'tournaments.monitor_form.tooltips.admin_controlled' app/views/tournaments/tournament_monitor.html.erb` returns **`0`** (admin_controlled row is NOT tooltip-wrapped)
    - `grep -c 'label_tag "Timeout (Sek.)"' app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c 'label_tag "GD has prio' app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c 'label_tag "Assign Games as Tables' app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c 'label_tag "Der Anstoß wechselt' app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c 'label_tag "Tournament Manager checks' app/views/tournaments/tournament_monitor.html.erb` returns `0`
    - `grep -c "admin_controlled" app/views/tournaments/tournament_monitor.html.erb` returns `>= 1` (checkbox row still present — plan 03 removes it later)
    - `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0
  </acceptance_criteria>
  <done>
    All 17 parameter labels use i18n keys from `tournaments.monitor_form.labels.*`. 16 of them are wrapped in a `data-controller="tooltip"` trigger with content from `tournaments.monitor_form.tooltips.*`. The `admin_controlled` row gets the i18n label but NO tooltip wrapper (plan 03 deletes the row). No hardcoded English literals remain. erblint is clean.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| i18n YAML → DOM | Tooltip text passes through Rails `t()` and is written into a `data-*` attribute |
| Stimulus controller → DOM | `tooltip_controller.js` injects a `<div>` with tooltip text |

## STRIDE Threat Register (ASVS L1)

| Threat ID | Category | Component | Disposition | Mitigation |
|-----------|----------|-----------|-------------|------------|
| T-36b02-01 | Tampering (T) / XSS | `tooltip_controller.js` rendering tooltip content into the DOM | mitigate | Controller uses `card.textContent = this.contentValue`, NEVER `innerHTML`. Even if `contentValue` were somehow user-controlled in the future, textContent prevents HTML injection. Additionally, Rails `<%= t(...) %>` HTML-escapes the string before it lands in the `data-tooltip-content-value` attribute. |
| T-36b02-02 | Tampering (T) | i18n key content | accept | All label and tooltip strings come from static YAML files checked into the repository. No user input path exists. Contributor code review is the primary safeguard. |
| T-36b02-03 | Information disclosure (I) | Tooltip content reveals parameter ranges | accept | Parameter ranges are not secrets — they describe typical values for a public-facing tournament-management UI. No PII, no credentials, no security-relevant data. |
</threat_model>

<verification>
1. `ruby -r yaml -e "YAML.load_file('config/locales/de.yml'); YAML.load_file('config/locales/en.yml')"` exits 0.
2. `bundle exec erblint app/views/tournaments/tournament_monitor.html.erb` exits 0.
3. All acceptance-criteria greps pass.
4. Manual UAT (user runs in carambus_bcw): open a tournament's parameter form — every label is German (or EN per locale), hovering any label (except admin_controlled, which plan 03 removes entirely) shows a dark tooltip card, no English literals remain.
</verification>

<success_criteria>
- UI-01: ✅ 16 parameter fields have tooltips via Stimulus controller with i18n content (admin_controlled row excluded by design — plan 03 deletes that row)
- UI-02: ✅ 17 parameter labels localized into `tournaments.monitor_form.labels.*` namespace, both DE and EN keys present (17 labels + 17 tooltips in each locale for symmetry and D-11 reversibility), no hardcoded literals remain
</success_criteria>

<output>
After completion, create `.planning/phases/36B-ui-cleanup-kleine-features/36B-02-SUMMARY.md` listing: 1 new Stimulus controller, 34 new DE keys + 34 new EN keys (17 labels + 17 tooltips each), 17 ERB label rewrites (16 tooltip-wrapped + 1 admin_controlled plain), and a note that the `tooltips.admin_controlled` key is intentionally unused for D-11 reversibility.
</output>
</content>
</invoke>