---
phase: 38-ux-polish-i18n-debt
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - app/views/tournaments/_wizard_steps_v2.html.erb
  - app/assets/stylesheets/tournament_wizard.css
  - app/assets/stylesheets/components/tooltip.css
  - app/assets/stylesheets/application.tailwind.css
  - config/locales/en.yml
  - .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
autonomous: false
requirements:
  - UX-POL-01
  - UX-POL-02
  - UX-POL-03
  - I18N-01
tags:
  - ui
  - css
  - i18n
  - tailwind
  - darkmode
  - uat

must_haves:
  truths:
    - "A volunteer running the wizard in dark mode can read every <details> help block and every inline-styled info banner without switching to light mode (UX-POL-01 / G-01)"
    - "All 16 tooltipped labels on tournament_monitor.html.erb display a visible affordance (dashed underline + cursor: help) so a first-time volunteer knows the label is hoverable (UX-POL-02 / G-03)"
    - "An English-locale admin sees 'Warm-up / Warm-up Player A / Warm-up Player B' on the scoreboard warm-up screen instead of 'Training' (I18N-01 / G-05)"
    - "Phase 36B Wizard Header Test 1 criteria (dominant AASM state badge, 6 bucket chips, no 'Schritt N von 6' text, no numeric step prefixes) are explicitly reconfirmed by a fresh manual UAT pass after G-01 ships (UX-POL-03)"
    - "en.yml:387 training: Training remains untouched (different semantic — practice tournament concept)"
  artifacts:
    - path: "app/views/tournaments/_wizard_steps_v2.html.erb"
      provides: "Dark-mode-safe inline info banner via Tailwind dark: variants (no inline style= background)"
      contains: "bg-green-50 dark:bg-green-900/30"
    - path: "app/assets/stylesheets/components/tooltip.css"
      provides: "Global tooltip affordance rule (new file, imported via application.tailwind.css)"
      contains: "cursor: help"
    - path: "app/assets/stylesheets/application.tailwind.css"
      provides: "@import registration for the new components/tooltip.css"
      contains: "@import \"components/tooltip.css\""
    - path: "config/locales/en.yml"
      provides: "Corrected EN warmup translations (Warm-up / Warm-up Player A / Warm-up Player B)"
      contains: "warmup: Warm-up"
    - path: ".planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md"
      provides: "Manual UAT evidence artifact for Phase 36B Test 1 retest + G-01 contrast confirmation"
      contains: "UX-POL-03"
  key_links:
    - from: "app/views/tournaments/_wizard_steps_v2.html.erb"
      to: "Tailwind dark: variant system"
      via: "dark:bg-green-900/30 dark:border-green-500 dark:text-green-100 class utilities"
      pattern: "dark:bg-green-900"
    - from: "app/assets/stylesheets/application.tailwind.css"
      to: "app/assets/stylesheets/components/tooltip.css"
      via: "@import directive alongside other components/*.css imports"
      pattern: "@import \"components/tooltip.css\""
    - from: "app/views/tournaments/tournament_monitor.html.erb"
      to: "app/assets/stylesheets/components/tooltip.css"
      via: "[data-controller~=\"tooltip\"] CSS attribute selector auto-matching the 16 existing tooltip sites"
      pattern: "data-controller=\"tooltip\""
    - from: "config/locales/en.yml"
      to: "table_monitor.status.warmup / warmup_a / warmup_b translation keys rendered on scoreboard"
      via: "Rails I18n lookup under en.table_monitor.status"
      pattern: "warmup: Warm-up"
---

<objective>
Ship the Phase 38 "quick wins bundle": four small, independent fixes + one manual UAT retest that collectively close UX-POL-01, UX-POL-02, UX-POL-03, and I18N-01.

Purpose: Close the four smallest Phase 36B UAT follow-up gaps (G-01 dark-mode contrast, G-03 tooltip affordance, G-05 warm-up EN translation) plus the UX-POL-03 Phase 36B Test 1 retest that was blocked on G-01 landing first. All four touch different files and are logically independent, but they share the same "polish the volunteer-facing wizard + scoreboard surface" theme and ship as a single commit-coherent plan.

Output:
- `_wizard_steps_v2.html.erb` lines 167, 215, 268 converted from inline `style="background: ..."` to Tailwind `dark:*` variants
- `tournament_wizard.css:287-295` specificity verified via DevTools; bumped or converted to `@apply` if clobbered
- New file `app/assets/stylesheets/components/tooltip.css` containing one CSS rule on `[data-controller~="tooltip"]`
- `application.tailwind.css` registers the new tooltip.css via `@import`
- `config/locales/en.yml:844-846` 3-line edit (Warm-up / Warm-up Player A / Warm-up Player B)
- `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` written by a human after visually confirming the 5 criteria from CONTEXT.md D-17
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md
@.planning/seeds/v71-ux-polish-i18n-debt.md
@.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md

<!-- Target source files for in-plan modifications -->
@app/views/tournaments/_wizard_steps_v2.html.erb
@app/assets/stylesheets/tournament_wizard.css
@app/assets/stylesheets/application.tailwind.css
@config/locales/en.yml

<interfaces>
<!-- Current state snippets the executor MUST verify against the live files before editing. -->
<!-- If these differ in the live file, STOP and read the file fresh — CONTEXT.md line numbers are authoritative. -->

From app/views/tournaments/_wizard_steps_v2.html.erb:170 (CONTEXT.md D-03 calls this "line 167" but the actual <div> opens at line 170 in the live file — the canonical_refs "line 167" refers to the ERB comment that begins the block):
```erb
<%# Zeige Info wenn bereits Spieler manuell hinzugefügt wurden %>
<% non_local_seedings_count = tournament.seedings.where("seedings.id < #{Seeding::MIN_ID}").count %>
<% if non_local_seedings_count > 0 && wizard_step_status(tournament, 2) == :active %>
  <div class="step-info mt-2" style="background: #dff0d8; padding: 8px; border-radius: 4px; border: 1px solid #3c763d;">
    ℹ️ <strong>Es sind bereits #{non_local_seedings_count} Spieler vorhanden</strong>
    <br>Sie können diese direkt übernehmen (siehe unten)
  </div>
<% end %>
```

From app/views/tournaments/_wizard_steps_v2.html.erb:221 (the "line 215" site — already partially Tailwind'd; a gradient block that DOES use dark: variants — verify it's already OK and does not need touching):
```erb
<div class="mt-3 p-3 bg-gradient-to-r from-blue-50 to-green-50 dark:from-blue-900/20 dark:to-green-900/20 border-2 border-blue-300 dark:border-blue-600 rounded-lg shadow-sm">
```
NOTE: This block ALREADY has dark: variants. CONTEXT.md D-03 says "Planner verifies all three lines use a compatible green scheme; lines with different source colors get matching Tailwind variants." This site already conforms — likely no change needed. The executor must READ the file and confirm, then record "no change" in the task log if correct.

From app/views/tournaments/_wizard_steps_v2.html.erb:268 (the "line 268" site — a `help:` heredoc-like string containing embedded Tailwind classes `text-blue-600 dark:text-blue-400 underline`):
```erb
<strong>Für Tests:</strong> #{link_to '📝 Direkt zur Teilnehmerliste (für manuelle Eingabe)', define_participants_tournament_path(tournament), class: 'text-blue-600 dark:text-blue-400 underline'}
```
NOTE: This is inside a `help:` parameter string passed to `render 'wizard_step'`. The link itself already has `dark:text-blue-400`. The surrounding `<p class="step-help-p">` styling comes from `tournament_wizard.css .step-help p` (lines 287-295) — the CSS specificity audit in T2 covers this site.

From app/assets/stylesheets/tournament_wizard.css:287-295 (the rule under DevTools audit):
```css
.step-help p {
  margin-top: 0.5rem;
  padding-left: 1rem;
  color: #4b5563;
}

html.dark .step-help p {
  color: #d1d5db;
}
```

From app/assets/stylesheets/application.tailwind.css:11-36 (the @import section for components):
```css
@import "components/base.css";
@import "components/alert.css";
@import "components/animation.css";
@import "components/carambus.css";
@import "components/avatars.css";
@import "components/buttons.css";
@import "components/code.css";
@import "components/direct_uploads.css";
@import "components/docs.css";
@import "components/forms.css";
@import "tournament_wizard.css";
@import "components/icons.css";
@import "components/iframe.css";
@import "components/modal.css";
@import "components/game_protocol_modal.css";
@import "components/game_protocol_print.css";
@import "components/nav.css";
@import "components/notifications.css";
@import "components/pagination.css";
@import "components/virt_keyboard.css";
@import "components/strada.css";
@import "components/tabs.css";
@import "components/trix.css";
@import "components/typography.css";
@import "components/util.css";
@import "components/braintree.css";
```

From config/locales/en.yml:843-846 (current values — BUG):
```yaml
      wait_check: "-OK?"
      warmup: Training
      warmup_a: Training Player A
      warmup_b: Training Player B
```

From config/locales/en.yml:387 (DO NOT TOUCH — different semantic):
```yaml
        training: Training
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Replace inline dark-mode-broken info banner with Tailwind dark: variants (G-01 primary site)</name>
  <files>app/views/tournaments/_wizard_steps_v2.html.erb</files>
  <read_first>
    - app/views/tournaments/_wizard_steps_v2.html.erb (full file — the CONTEXT.md D-03 line numbers 167/215/268 are approximate; the actual `<div class="step-info mt-2" style="background: #dff0d8; ...">` site is the "line 167" reference in canonical_refs)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-03, §D-04, §D-05 (dark-mode decisions + scope boundary)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-01: Dark-mode contrast" (full gap with root-cause analysis — the light-gray-on-light-green WCAG fail)
    - app/assets/stylesheets/tournament_wizard.css:287-295 (the .step-help p rule that T2 audits — read to understand what's already in place)
  </read_first>
  <action>
    Edit `app/views/tournaments/_wizard_steps_v2.html.erb` to fix the three inline-style sites called out in CONTEXT.md D-03:

    **Site 1 (CONTEXT.md "line 167" — the primary G-01 site):** Locate the `<div class="step-info mt-2" style="background: #dff0d8; padding: 8px; border-radius: 4px; border: 1px solid #3c763d;">` element (the "Es sind bereits N Spieler vorhanden" banner under the Schritt 2 active-state branch). Replace the entire `class="..."` + `style="..."` attribute pair with:

    ```
    class="step-info mt-2 bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100 p-2 rounded"
    ```

    Rationale: CONTEXT.md D-03 mandates this exact Tailwind class set verbatim. The `p-2 rounded` replaces the inline `padding: 8px; border-radius: 4px;`. Keep `step-info mt-2` for the existing layout spacing hook.

    **Site 2 (CONTEXT.md "line 215"):** Locate the `<div class="mt-3 p-3 bg-gradient-to-r from-blue-50 to-green-50 dark:from-blue-900/20 dark:to-green-900/20 border-2 border-blue-300 dark:border-blue-600 rounded-lg shadow-sm">` element (the "Es sind bereits N Spieler vorhanden" action block with the "Weiter zu Schritt 3" button). Read the current class list. This block **already has `dark:*` variants** on every color utility — CONTEXT.md D-03 says "lines with different source colors get matching Tailwind variants" and this site ALREADY conforms. Verify the dark: variants are present (they should be: `dark:from-blue-900/20`, `dark:to-green-900/20`, `dark:border-blue-600`, and the inner `<p>` elements use `dark:text-blue-200` / `dark:text-gray-300`). If ALL dark: variants are already present, make NO change at this site and record "no change" in the verification log. If any dark: variant is missing, add the matching `dark:*` class following the same blue/green palette.

    **Site 3 (CONTEXT.md "line 268"):** Locate the `help:` heredoc-like string containing the `#{link_to '📝 Direkt zur Teilnehmerliste ...', ..., class: 'text-blue-600 dark:text-blue-400 underline'}`. This is inside a `render 'wizard_step'` call. The link already has `dark:text-blue-400`. The surrounding `<p>` element styling comes from `.step-help p` in `tournament_wizard.css:287-295` — that CSS rule is audited in Task 2, NOT touched here. Make NO ERB change at this site unless the read reveals a hardcoded `style="..."` attribute (the seed fix sketch lists "line 268" only in connection with the `.step-help p` CSS audit, not an inline-style replacement).

    **Final sanity check (mandatory):** After edits, re-read the file and verify no `style="background:` attribute remains anywhere in the file. The single remaining `style="..."` attribute (if any) must be justified and documented.

    Preserve all other attributes, ERB logic, and indentation. Use German business-logic comments if adding any (but no new comments are required — this is a class-attribute swap).
  </action>
  <verify>
    <automated>
      grep -c 'dark:bg-green-900/30' app/views/tournaments/_wizard_steps_v2.html.erb     # must be ≥ 1
      grep -c 'style="background: #dff0d8' app/views/tournaments/_wizard_steps_v2.html.erb  # must be 0
      grep -n 'style="background:' app/views/tournaments/_wizard_steps_v2.html.erb        # must print nothing (zero remaining inline background styles)
      bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb                  # exit 0
    </automated>
  </verify>
  <acceptance_criteria>
    - `grep -c 'dark:bg-green-900/30' app/views/tournaments/_wizard_steps_v2.html.erb` returns ≥ 1
    - `grep -c 'bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100' app/views/tournaments/_wizard_steps_v2.html.erb` returns ≥ 1 (the full class set from D-03)
    - `grep -n 'style="background:' app/views/tournaments/_wizard_steps_v2.html.erb` returns zero lines (no remaining inline background styles)
    - `grep -c 'dff0d8' app/views/tournaments/_wizard_steps_v2.html.erb` returns 0
    - `bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb` exits 0
    - Manual note in task log: confirmed whether Site 2 (line 215) and Site 3 (line 268) already had adequate dark: variants (expected: yes, no change made at those sites)
  </acceptance_criteria>
  <done>
    Primary G-01 inline-style site on `_wizard_steps_v2.html.erb` has been replaced with the exact Tailwind class set from CONTEXT.md D-03. Sites 2 and 3 audited and either left as-is (already conforming) or updated with matching dark: variants. No `style="background: ..."` attributes remain in the file.
  </done>
</task>

<task type="auto">
  <name>Task 2: Audit tournament_wizard.css:287-295 specificity and fix if clobbered by Tailwind reset</name>
  <files>app/assets/stylesheets/tournament_wizard.css</files>
  <read_first>
    - app/assets/stylesheets/tournament_wizard.css (full file — the `.step-help p` rule is at lines 287-295; need surrounding context to understand existing patterns)
    - app/assets/stylesheets/application.tailwind.css (to see @import order — `tournament_wizard.css` is imported at line 21, BEFORE `@import "tailwindcss/utilities"` at line 38, meaning utility classes win by source order for equal-specificity conflicts)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-04 (the specificity-audit decision — bump specificity or convert to @apply if clobbered)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-01" root_cause_candidates block 2 (the .step-help p specificity hypothesis)
    - app/views/tournaments/_wizard_steps_v2.html.erb (to confirm the `.step-help p` selector targets the actual `<details><p>` structure inside the help blocks)
  </read_first>
  <action>
    Audit the existing dark-mode rule at `app/assets/stylesheets/tournament_wizard.css:287-295`:

    ```css
    .step-help p {
      margin-top: 0.5rem;
      padding-left: 1rem;
      color: #4b5563;
    }

    html.dark .step-help p {
      color: #d1d5db;
    }
    ```

    **Step 1 — source-order analysis:** Read `application.tailwind.css:1-40` and confirm the `@import` order. `tournament_wizard.css` is imported at line 21, BEFORE `@import "tailwindcss/utilities"` at line 38. This means any Tailwind utility class on the `<p>` element (e.g., `text-gray-600`) will load LATER in the cascade and win for equal-specificity conflicts. The `.step-help p` plain-CSS rule has specificity (0,1,1); `html.dark .step-help p` has specificity (0,1,2) + the `html.dark` ancestor. A single Tailwind utility `text-gray-300` has specificity (0,1,0) and comes later in source — but an `html.dark + dark:*` variant like `dark:text-gray-300` compiles to `.dark .dark\\:text-gray-300` with specificity (0,2,0) + source-later, which DOES win over `.step-help p` (0,1,1).

    **Step 2 — concrete fix decision:** Since the `<details><p>` inside `.step-help` does NOT currently carry any Tailwind text-color utility (verified by reading `_wizard_steps_v2.html.erb` — the `.step-help <details><p>` elements are plain `<p>` with no class attribute), the `html.dark .step-help p` rule at (0,1,2) with the `html.dark` ancestor SHOULD win. The 36B UAT root-cause block 2 says the screenshot "suggests something is overriding" but could not confirm — the audit is the executor's job here.

    **Step 3 — execute the audit:**
    - Run `bundle exec rails assets:precompile RAILS_ENV=development 2>&1 | tail -20` (or equivalent) to confirm the CSS compiles without errors.
    - Grep `app/views/tournaments/_wizard_steps_v2.html.erb` for `class=` attributes on any `<p>` inside a `<details>` block under `.step-help`: `grep -n 'step-help' app/views/tournaments/_wizard_steps_v2.html.erb` — if any `<p class="text-gray-*">` or `<p class="dark:text-*">` appears, THAT is the override. Document it.
    - If no override exists in the ERB, BUMP specificity defensively by changing the rule to `html.dark .step-help details p` (specificity 0,1,3) — still targets only the help-block body paragraphs, no unintended bleed.

    **Step 4 — apply the fix:**
    - If Step 3 found an override: add `!important` to `html.dark .step-help p { color: #d1d5db !important; }` OR (preferred) convert the rule to Tailwind `@apply` form by adding a utility class to the ERB: `class="step-help-body"` on the `<p>` and defining `.step-help-body { @apply text-gray-600 dark:text-gray-300; }` in tournament_wizard.css.
    - If Step 3 found NO override: bump specificity to `html.dark .step-help details p { color: #d1d5db; }` as a defensive measure. Also add the light-mode companion: `.step-help details p { color: #4b5563; }` (keeping the existing margin/padding on the broader `.step-help p`).

    **Critical:** Do NOT remove the existing `.step-help p { margin-top: 0.5rem; padding-left: 1rem; ... }` rule — only add or modify the color/specificity aspects. The margin and padding must persist.

    German comment added above the bumped rule explaining WHY (example): `/* Spezifität erhöht wegen Tailwind dark:text-* Konflikt (G-01 Audit) */`.
  </action>
  <verify>
    <automated>
      grep -n 'step-help' app/assets/stylesheets/tournament_wizard.css                   # prints the rule block
      grep -c 'html.dark .step-help' app/assets/stylesheets/tournament_wizard.css        # must be ≥ 1 (rule still present)
      # Compile smoke (any stylesheet loader or the Rails asset pipeline) — detects CSS syntax errors:
      ruby -e 'require "tempfile"; s = File.read("app/assets/stylesheets/tournament_wizard.css"); abort "unbalanced braces" if s.count("{") != s.count("}")'
    </automated>
  </verify>
  <acceptance_criteria>
    - `grep -c 'html.dark .step-help' app/assets/stylesheets/tournament_wizard.css` returns ≥ 1
    - `grep -c 'margin-top: 0.5rem' app/assets/stylesheets/tournament_wizard.css` returns ≥ 1 (margin rule preserved)
    - CSS brace count balanced (no syntax error introduced)
    - Task log documents audit finding: either "no override found, specificity bumped defensively to `.step-help details p`" OR "override found in ERB line X, fixed via [!important | @apply]"
    - File modification count minimal — only the `.step-help p` / `html.dark .step-help p` rule block is touched, surrounding rules unchanged
  </acceptance_criteria>
  <done>
    CSS specificity audit complete. Rule at `tournament_wizard.css:287-295` either verified as winning via existing specificity (with defensive bump) or fixed via !important / @apply to survive Tailwind utility override. Task log records the audit finding.
  </done>
</task>

<task type="auto">
  <name>Task 3: Create components/tooltip.css with affordance rule, audit 16 tooltip sites, register via @import (G-03)</name>
  <files>app/assets/stylesheets/components/tooltip.css, app/assets/stylesheets/application.tailwind.css</files>
  <read_first>
    - app/assets/stylesheets/components/ (directory listing — to pick a file to model the new tooltip.css after; e.g., components/modal.css or components/icons.css are small single-concern files)
    - app/assets/stylesheets/components/modal.css (pattern reference for a small component file)
    - app/assets/stylesheets/application.tailwind.css (the @import section at lines 11-36 — insertion point for the new @import directive)
    - app/views/tournaments/tournament_monitor.html.erb (MANDATORY — to audit all 16 `[data-controller~="tooltip"]` / `data-controller="tooltip"` occurrences and check whether the broad rule would bleed into form controls)
    - app/javascript/controllers/tooltip_controller.js (reference only — to confirm the controller sets `data-controller="tooltip"` on target elements)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-06, §D-07, §D-08 (exact rule text + audit requirement + CSS-only scope)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-03: Tooltip-carrying labels" fix_sketch Option A (the recommended approach)
  </read_first>
  <action>
    **Step 1 — audit 16 tooltip sites in `tournament_monitor.html.erb` (CONTEXT.md D-07 mandate):**

    Run `grep -n 'data-controller="tooltip"\|data-controller=".*tooltip' app/views/tournaments/tournament_monitor.html.erb` and record the full element tags at each match. Expected count: ≈16 (per CONTEXT.md). Classify each as one of:
    - **Label-only:** the attribute is on a `<label>`, `<span>`, or text wrapper — the broad rule is safe.
    - **Form control:** the attribute is on an `<input>`, `<select>`, or `<textarea>` — the broad rule would add a dashed underline and `cursor: help` to the input itself, which is wrong.
    - **Wrapper containing form control:** the attribute is on a `<div>` or `<label>` that wraps form controls — a dashed underline on the wrapper could bleed into the inputs via `currentColor`.

    **Step 2 — decide final selector (CONTEXT.md D-07 authorizes narrowing):**

    - If ALL 16 sites are label-only or wrapper-of-span: use the broad rule `[data-controller~="tooltip"]` as-is.
    - If ANY site is a form control or a wrapper containing form controls: narrow the selector to `[data-controller~="tooltip"]:not(input):not(select):not(textarea)` OR scope explicitly as `[data-controller~="tooltip"] > span, label[data-controller~="tooltip"], span[data-controller~="tooltip"]` — whichever form most cleanly matches the audit findings.

    Document the decision in a comment at the top of the new file.

    **Step 3 — create `app/assets/stylesheets/components/tooltip.css`** with this content (using the broad form unless the audit in Step 2 demands narrowing):

    ```css
    /*
     * Tooltip affordance (G-03 / UX-POL-02)
     *
     * Adds a visible hint (dashed underline + cursor: help) to elements that
     * carry the Stimulus tooltip controller, so a first-time volunteer knows
     * the label is hoverable without trial-and-error.
     *
     * Applies automatically to all [data-controller~="tooltip"] sites on
     * tournament_monitor.html.erb (16 labels) and any future ones.
     *
     * Audit (CONTEXT.md D-07): {EXECUTOR RECORDS FINDING HERE — e.g. "all 16
     * sites are <label> or <span>, broad rule safe" OR "narrowed to
     * :not(input):not(select):not(textarea) because site X is on an <input>".}
     */

    [data-controller~="tooltip"] {
      cursor: help;
      border-bottom: 1px dashed currentColor;
      padding-bottom: 1px;
    }
    ```

    If narrowing is required, replace the bare `[data-controller~="tooltip"]` selector with the narrowed form from Step 2. Keep the three declarations (`cursor`, `border-bottom`, `padding-bottom`) verbatim from CONTEXT.md D-07.

    **Step 4 — register in `application.tailwind.css`:** Insert a new `@import "components/tooltip.css";` line into the component @import block (lines 11-36). Insertion location: alphabetical order — between `@import "components/tabs.css";` and `@import "components/trix.css";` OR (if alphabetical ordering is not strictly followed in the existing file) immediately after `@import "tournament_wizard.css";` at line 21 to colocate with the other wizard/monitor styling. Pick whichever matches the existing pattern — read the file to decide.

    **Critical constraints:**
    - CONTEXT.md D-08: zero ERB changes in this task. The CSS rule auto-applies via the attribute selector.
    - Do NOT create the file in `app/assets/stylesheets/` root — it MUST live under `app/assets/stylesheets/components/` per CONTEXT.md D-06 and the established pattern.
    - Do NOT touch `tournament_wizard.css` or any other existing file besides `application.tailwind.css`.
  </action>
  <verify>
    <automated>
      test -f app/assets/stylesheets/components/tooltip.css && echo "file exists"
      grep -q 'cursor: help' app/assets/stylesheets/components/tooltip.css && echo "cursor rule present"
      grep -q 'border-bottom: 1px dashed currentColor' app/assets/stylesheets/components/tooltip.css && echo "border rule present"
      grep -q 'padding-bottom: 1px' app/assets/stylesheets/components/tooltip.css && echo "padding rule present"
      grep -q 'data-controller~="tooltip"' app/assets/stylesheets/components/tooltip.css && echo "selector present"
      grep -q '@import "components/tooltip.css"' app/assets/stylesheets/application.tailwind.css && echo "import registered"
      # Confirm the 16-site audit was executed (the file-level comment should mention the audit finding):
      grep -q 'Audit' app/assets/stylesheets/components/tooltip.css && echo "audit documented"
    </automated>
  </verify>
  <acceptance_criteria>
    - `test -f app/assets/stylesheets/components/tooltip.css` exits 0
    - `grep -c 'cursor: help' app/assets/stylesheets/components/tooltip.css` returns ≥ 1
    - `grep -c 'border-bottom: 1px dashed currentColor' app/assets/stylesheets/components/tooltip.css` returns exactly 1
    - `grep -c 'padding-bottom: 1px' app/assets/stylesheets/components/tooltip.css` returns ≥ 1
    - `grep -c 'data-controller~="tooltip"' app/assets/stylesheets/components/tooltip.css` returns ≥ 1
    - `grep -c '@import "components/tooltip.css"' app/assets/stylesheets/application.tailwind.css` returns exactly 1
    - Comment at top of tooltip.css records the audit finding per CONTEXT.md D-07 (mentions "Audit" and either "broad rule safe" or "narrowed")
    - `grep -c 'data-controller="tooltip"\|data-controller=".*tooltip' app/views/tournaments/tournament_monitor.html.erb` returns ≥ 10 (sanity check that target sites exist — exact count ≈16)
    - `app/views/tournaments/tournament_monitor.html.erb` is UNCHANGED (no ERB modifications — confirmed via `git diff --stat app/views/tournaments/tournament_monitor.html.erb` returns empty)
    - `app/assets/stylesheets/tournament_wizard.css` is UNCHANGED in this task (its modification belongs to Task 2)
  </acceptance_criteria>
  <done>
    New file `components/tooltip.css` exists with the exact G-03 rule from CONTEXT.md D-07 (narrowed if the 16-site audit required it). Registered via `@import` in `application.tailwind.css`. Zero ERB changes. All 16 tooltip-decorated labels on `tournament_monitor.html.erb` will display the dashed underline + `cursor: help` affordance when the next asset compile runs.
  </done>
</task>

<task type="auto">
  <name>Task 4: Fix en.yml warmup translations (I18N-01 / G-05)</name>
  <files>config/locales/en.yml</files>
  <read_first>
    - config/locales/en.yml (full region around lines 384-395 AND lines 840-850 — executor must confirm BOTH the 387 "training: Training" key to avoid-touch AND the 844-846 warmup keys to fix)
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-09, §D-10 (exact 3-line values + DO-NOT-TOUCH warning for en.yml:387)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-05" full gap (evidence screenshots + user quote + root cause + the different-semantic distinction between 387:training and 844:warmup)
    - config/locales/de.yml:864-866 (the German equivalents — for traceability that DE is already correct: `warmup: Spielbeginn`, `warmup_a: Einstoßen Spieler A`, `warmup_b: Einstoßen Spieler B`. The DE values are NOT touched — only EN is edited.)
  </read_first>
  <action>
    Edit `config/locales/en.yml` lines 844-846 ONLY. Change the three values under `en.table_monitor.status`:

    **Before:**
    ```yaml
          warmup: Training
          warmup_a: Training Player A
          warmup_b: Training Player B
    ```

    **After (exact values from CONTEXT.md D-09):**
    ```yaml
          warmup: Warm-up
          warmup_a: Warm-up Player A
          warmup_b: Warm-up Player B
    ```

    Preserve existing indentation (6-space YAML indent — the keys are nested under `en > table_monitor > status`). Do NOT change the key names, only the values. Do NOT add or remove any other lines in this region.

    **CRITICAL — DO NOT TOUCH** (CONTEXT.md D-10):
    - `config/locales/en.yml:387` currently reads `        training: Training` under `en.activerecord.attributes.game.state.training`. This is a DIFFERENT semantic — it represents the "Training Game" (practice-tournament) concept, not the scoreboard warm-up phase. It is CORRECT as-is and MUST remain untouched.
    - Before saving, re-read line 387 and confirm the line still reads `        training: Training` (or similar — exact column depends on the file's current state). Record in the task log.

    **Smoke test** (mandatory):
    Run `bundle exec rails runner "I18n.locale = :en; puts I18n.t('table_monitor.status.warmup'); puts I18n.t('table_monitor.status.warmup_a'); puts I18n.t('table_monitor.status.warmup_b')"` and confirm the output is three lines reading exactly "Warm-up", "Warm-up Player A", "Warm-up Player B". Also run `puts I18n.t('activerecord.attributes.game.state.training')` with `I18n.locale = :en` and confirm it still returns "Training" (the untouched line 387 key).
  </action>
  <verify>
    <automated>
      grep -A1 -B0 'warmup:' config/locales/en.yml | grep -c 'Warm-up'                    # must be ≥ 3 (warmup + warmup_a + warmup_b)
      grep -c 'warmup: Warm-up' config/locales/en.yml                                     # exactly 1
      grep -c 'warmup_a: Warm-up Player A' config/locales/en.yml                          # exactly 1
      grep -c 'warmup_b: Warm-up Player B' config/locales/en.yml                          # exactly 1
      grep -c 'warmup: Training' config/locales/en.yml                                    # must be 0 (bug removed)
      grep -c 'training: Training' config/locales/en.yml                                  # must be ≥ 1 (line 387 untouched — different semantic)
      bundle exec rails runner 'I18n.locale = :en; puts I18n.t("table_monitor.status.warmup")'  # must print "Warm-up"
      bundle exec rails runner 'I18n.locale = :en; puts I18n.t("activerecord.attributes.game.state.training")'  # must print "Training" (untouched)
    </automated>
  </verify>
  <acceptance_criteria>
    - `grep -c 'warmup: Warm-up' config/locales/en.yml` returns exactly 1
    - `grep -c 'warmup_a: Warm-up Player A' config/locales/en.yml` returns exactly 1
    - `grep -c 'warmup_b: Warm-up Player B' config/locales/en.yml` returns exactly 1
    - `grep -c 'warmup: Training' config/locales/en.yml` returns 0
    - `grep -c 'training: Training' config/locales/en.yml` returns ≥ 1 (line 387 preserved)
    - `git diff --stat config/locales/en.yml` shows exactly 3 line modifications (no additions, no deletions) — verified via `git diff config/locales/en.yml | grep -c '^+' == 3+1` (header) and `grep -c '^-' == 3+1`
    - Rails runner smoke test prints "Warm-up", "Warm-up Player A", "Warm-up Player B" under `I18n.locale = :en`
    - Rails runner smoke test prints "Training" for `activerecord.attributes.game.state.training` under `I18n.locale = :en` (untouched line 387 key)
  </acceptance_criteria>
  <done>
    `config/locales/en.yml:844-846` reads the exact three values from CONTEXT.md D-09. `en.yml:387 training: Training` is verified untouched. Rails I18n lookup returns the new strings under the `:en` locale.
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <name>Task 5: Manual UAT — Phase 36B Wizard Header Test 1 retest + G-01 contrast confirmation (UX-POL-03)</name>
  <files>.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md</files>
  <read_first>
    - .planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md §D-16, §D-17, §D-18 (manual UAT mandate + 5 criteria + Plan 38-01 final-task position)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"1. Wizard header visual check (FIX-04 + FIX-03)" (original Phase 36B Test 1 expected criteria — the retest baseline)
    - .planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md §"G-01: Dark-mode contrast" (the gap this retest confirms closed, especially the `impact_on_phase_37` note — fixing G-01 is a prerequisite for Phase 37 doc links being readable in dark mode)
  </read_first>
  <what-built>
    Tasks 1-4 shipped: G-01 dark-mode Tailwind class replacement on `_wizard_steps_v2.html.erb`, `tournament_wizard.css:287-295` specificity audit, new `components/tooltip.css` with affordance rule + `@import` registration, `en.yml:844-846` warmup translations. The wizard should now be readable in dark mode, tooltips should have visible affordance, and the scoreboard should read "Warm-up" in EN locale.
  </what-built>
  <action>
    This is a **human verification task** — no code changes. The human runs the procedure in `<how-to-verify>` below in a real browser against `carambus_bcw` (NOT `carambus_api` — see the setup note) and writes the UAT artifact `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` recording pass/fail on the 5 criteria from CONTEXT.md D-17. The executor's job is to present the procedure clearly, wait for the human, and on resume create/validate the artifact based on the human's report. If the human reports failure, the executor escalates to plan revision — Tasks 1-2 must be revisited before Plan 38-01 can close.
  </action>
  <how-to-verify>
    **Setup (CRITICAL — run against carambus_bcw, NOT carambus_api):**

    Per CLAUDE.md and the `scenario-management` skill: `carambus_api` runs in API-mode in dev; manual tournament walkthroughs must run against `carambus_bcw` (LOCAL context). Before running this UAT:

    1. Switch to the `carambus_bcw` checkout (the sibling directory at the same level as `carambus_api`).
    2. Pull the latest Plan 38-01 commit into `carambus_bcw` (the code in `_wizard_steps_v2.html.erb`, `tournament_wizard.css`, `components/tooltip.css`, `application.tailwind.css`, and `en.yml` must all be present there).
    3. Start the `carambus_bcw` dev server (`foreman start -f Procfile.dev` or `bin/rails server`).
    4. Open the browser and navigate to any tournament that is in `new_tournament` or `accreditation_finished` AASM state (so the wizard is visible on the show page).

    **The 5 criteria to confirm (from CONTEXT.md D-17 — 4 required + 1 bonus):**

    1. **Dominant AASM state badge:** The wizard header displays a large colored state badge (orange for `new_tournament`, blue for `accreditation_finished`, green for `tournament_started`) as the visually dominant element at the top of the header. The badge is clearly the focal point.

    2. **6 bucket chips:** Six wizard bucket chips render below the badge, with the chip corresponding to the current AASM state highlighted/active. All 6 chips are present (not 5, not 7).

    3. **NO "Schritt N von 6" text:** The phrase `Schritt N von 6` (or `Step N of 6`) does NOT appear anywhere in the wizard header. Use browser Ctrl-F / Cmd-F to search the page source.

    4. **NO numeric step prefixes on step labels:** The wizard step cards (Schritt 1..6) do NOT have numeric prefixes like "1.", "2.", "3." in their step heading. The label is the action (e.g., "Meldeliste importieren") not "1. Meldeliste importieren".

    5. **(Bonus — G-01 confirmation):** Switch the browser to dark mode (system dark mode or via the app's dark-mode toggle if one exists). Open the wizard Schritt 2 "Setzliste aus Einladung übernehmen" step. The `<details>` help block auto-opens (per Phase 36B FIX-01). The help body text (`<p>` with `<strong>` tags describing what the step does) IS readable — sufficient contrast, no light-gray-on-light-green WCAG fail. If a "Es sind bereits N Spieler vorhanden" info banner appears, it ALSO has readable text (green text on dark green background, not clobbered).

    **Additional sanity checks (while you're here):**

    - Hover a parameter label on `tournament_monitor.html.erb` (any of the 16 tooltipped labels). Confirm the label now shows a dashed underline + `cursor: help` affordance BEFORE the tooltip opens. (G-03 check)
    - Switch the browser locale to English (either via a `?locale=en` URL param or the app's locale switcher). Navigate to the scoreboard view for a running game. Confirm the warm-up state renders as "Warm-up" (NOT "Training"). (G-05 / I18N-01 check)

    **Write the UAT artifact:**

    Create `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` following the Phase 36B UAT template (`.planning/milestones/v7.0-phases/36B-ui-cleanup-kleine-features/36B-HUMAN-UAT.md`). Include:

    - Frontmatter: `status: complete`, `phase: 38-ux-polish-i18n-debt`, `source: [38-01-quick-wins-bundle-PLAN.md]`, `completed: YYYY-MM-DDTHH:MM:SSZ`
    - Section "Test 1 retest: Wizard header visual check (Phase 36B UAT carryover — UX-POL-03)" with `result: pass` and a short note per each of the 5 criteria (1-4 required, 5 bonus).
    - Evidence: paste browser-DevTools screenshot paths OR a textual observation for each criterion. Screenshots are optional but preferred — if you take any, save them to `/Users/gullrich/Desktop/` following the Phase 36B convention (`Bildschirmfoto YYYY-MM-DD um HH.MM.SS.png`) and reference the absolute paths.
    - Section "G-03 sanity check" + "G-05 sanity check" — short pass/fail notes for the two ad-hoc extras.
    - Summary: `total: 1 (+2 sanity)`, `passed: 1`, `issues: 0`, `pending: 0`.

    If ANY of criteria 1-4 fail: STOP, do NOT write a pass-result UAT. Instead, write a `result: fail` UAT documenting the specific criterion that failed + a screenshot, and escalate to the user. Plan 38-01 cannot close until all 4 required criteria pass.

    If criterion 5 (bonus G-01 contrast) fails: the G-01 fix did not land correctly. Revisit Tasks 1 and 2 — likely the CSS specificity audit in Task 2 needs a stronger fix (e.g., `!important` or `@apply` instead of a defensive specificity bump).
  </how-to-verify>
  <acceptance_criteria>
    - File `.planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` exists
    - File contains all 5 criteria from CONTEXT.md D-17 (grep finds "badge", "bucket chips", "Schritt N von 6", "numeric prefixes", "dark mode")
    - File frontmatter has `status: complete` and `result: pass` (OR `result: fail` with explicit blockers — in which case Plan 38-01 is not complete)
    - File references either a screenshot path OR a textual observation for each required criterion
    - `grep -c 'UX-POL-03' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` returns ≥ 1
    - `grep -c '38-01-quick-wins-bundle-PLAN.md' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md` returns ≥ 1 (traceability to this plan)
  </acceptance_criteria>
  <verify>
    <automated>
      test -f .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
      grep -c 'UX-POL-03' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
      grep -cE 'badge|bucket chip|Schritt N|numeric prefix|dark mode' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
      grep -c 'result: pass' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
    </automated>
  </verify>
  <done>
    Human has visually confirmed all 4 required Phase 36B Test 1 criteria (dominant AASM badge, 6 bucket chips, no "Schritt N von 6" text, no numeric step prefixes) plus the bonus G-01 dark-mode contrast fix. UAT artifact `38-UX-POL-03-UAT.md` exists in the phase directory with `result: pass`, traceability back to this plan, and a note per each criterion. Plan 38-01 is ready to close.
  </done>
  <resume-signal>Type "approved" if all 4 required criteria passed (the bonus G-01 check should also pass, since it's the reason for this retest). Describe any issues otherwise, and we will revisit Tasks 1-2 before closing Plan 38-01.</resume-signal>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Browser → Rails view rendering | ERB template rendered to HTML; new Tailwind classes replace inline `style=` attributes |
| Client CSS cascade | New `components/tooltip.css` imported into `application.tailwind.css` global scope |
| Rails I18n lookup | `t('table_monitor.status.warmup')` fetches value from `en.yml` under the `:en` locale |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-38-01-01 | Tampering / Injection | ERB class-attribute swap on `_wizard_steps_v2.html.erb` | accept | Pure static class-attribute replacement with no user-interpolated values. Existing ERB escaping rules (`<%=` vs `<%==`) unchanged. No new `raw` / `html_safe` calls introduced. |
| T-38-01-02 | Tampering | CSS selector scope in new `components/tooltip.css` | mitigate | Attribute selector `[data-controller~="tooltip"]` is bounded to elements carrying the Stimulus controller attribute. Task 3 audit explicitly narrows if the broad form bleeds into form controls. No user input affects the selector. No `@import url(...)` from external sources. |
| T-38-01-03 | Information Disclosure | New en.yml keys `warmup/warmup_a/warmup_b` | accept | Static UI label strings, no PII, no user-interpolated content, no template injection vector. Rails I18n standard escaping applies. |
| T-38-01-04 | Elevation of Privilege | Admin-only surfaces touched | accept | All modified files serve already-authenticated users only (tournament wizard + scoreboard surfaces behind Devise + Pundit). No change to authorization rules. No new routes, no new controllers. |
| T-38-01-05 | Spoofing | Dark-mode toggle / locale-switch exploited to render wrong content | accept | Existing Rails `I18n.locale` + user preference mechanisms unchanged. The en.yml edit only corrects values; the lookup mechanism is unmodified. |

**Overall risk:** LOW. This plan is pure CSS + static YAML label corrections + ERB class-attribute swaps. No new user input, no new routes, no new authorization surface, no template logic changes, no JavaScript changes. ERB escaping rules unchanged. The sole non-accept mitigation (T-38-01-02 tooltip selector scope) is handled explicitly by the Task 3 audit requirement.
</threat_model>

<verification>
## Plan-level verification

Run after Tasks 1-4 complete (Task 5 is the human UAT):

```bash
# G-01 (Task 1): Dark-mode Tailwind classes present on _wizard_steps_v2.html.erb
grep -c 'dark:bg-green-900/30' app/views/tournaments/_wizard_steps_v2.html.erb   # ≥ 1
grep -n 'style="background:' app/views/tournaments/_wizard_steps_v2.html.erb     # zero lines

# G-01 (Task 2): .step-help p rule still present, brace count balanced
grep -c 'html.dark .step-help' app/assets/stylesheets/tournament_wizard.css      # ≥ 1

# G-03 (Task 3): New file exists, exact rule text, @import registered
test -f app/assets/stylesheets/components/tooltip.css
grep -q 'cursor: help' app/assets/stylesheets/components/tooltip.css
grep -q 'border-bottom: 1px dashed currentColor' app/assets/stylesheets/components/tooltip.css
grep -q '@import "components/tooltip.css"' app/assets/stylesheets/application.tailwind.css

# I18N-01 (Task 4): en.yml warmup values corrected, en.yml:387 training: Training preserved
grep -c 'warmup: Warm-up' config/locales/en.yml                                  # = 1
grep -c 'warmup_a: Warm-up Player A' config/locales/en.yml                       # = 1
grep -c 'warmup_b: Warm-up Player B' config/locales/en.yml                       # = 1
grep -c 'warmup: Training' config/locales/en.yml                                 # = 0
grep -c 'training: Training' config/locales/en.yml                               # ≥ 1

# Lint gates
bundle exec erblint app/views/tournaments/_wizard_steps_v2.html.erb              # exit 0
bundle exec standardrb --no-fix app/views/tournaments/_wizard_steps_v2.html.erb  # exit 0 (no-op on ERB, defensive)

# I18n smoke test (Task 4)
bundle exec rails runner 'I18n.locale = :en; puts I18n.t("table_monitor.status.warmup")'
# => "Warm-up"
bundle exec rails runner 'I18n.locale = :en; puts I18n.t("activerecord.attributes.game.state.training")'
# => "Training" (en.yml:387 — untouched)

# Task 5 (human UAT artifact exists)
test -f .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md
grep -c 'UX-POL-03' .planning/phases/38-ux-polish-i18n-debt/38-UX-POL-03-UAT.md  # ≥ 1
```
</verification>

<success_criteria>
Plan 38-01 is complete when:

1. G-01 (UX-POL-01) — `_wizard_steps_v2.html.erb` line ≈167 no longer has `style="background: #dff0d8; ..."`. The replacement Tailwind class set `bg-green-50 dark:bg-green-900/30 border border-green-600 dark:border-green-500 text-green-900 dark:text-green-100` is present verbatim. Sites at lines 215 and 268 audited; any missing dark: variants added.
2. G-01 (UX-POL-01) — `tournament_wizard.css:287-295` specificity audit complete; rule bumped or converted to `@apply` if the audit found a Tailwind utility override. Rule is preserved (margin/padding kept).
3. G-03 (UX-POL-02) — New file `app/assets/stylesheets/components/tooltip.css` exists with the exact rule from CONTEXT.md D-07 (narrowed if 16-site audit required it). Registered via `@import` in `application.tailwind.css`. Zero ERB changes to `tournament_monitor.html.erb`.
4. I18N-01 (G-05) — `config/locales/en.yml:844-846` reads "Warm-up / Warm-up Player A / Warm-up Player B". `en.yml:387 training: Training` is verified untouched.
5. UX-POL-03 — Manual UAT artifact `38-UX-POL-03-UAT.md` exists with `result: pass` on all 4 required Phase 36B Test 1 criteria, plus the bonus G-01 dark-mode contrast confirmation. (This is the gate that closes Plan 38-01.)
6. Lint gates (erblint, standardrb) pass on all touched files.
7. No modifications to `app/models/discipline.rb`, `DISCIPLINE_PARAMETER_RANGES`, or any DATA-01-adjacent code. (DATA-01 is Phase 39, not Phase 38.)
</success_criteria>

<output>
After completion, create `.planning/phases/38-ux-polish-i18n-debt/38-01-SUMMARY.md` following the project template. Include:
- Frontmatter: phase, plan, type, status: complete, requirements: [UX-POL-01, UX-POL-02, UX-POL-03, I18N-01]
- What changed (5 files modified, 1 file created, 1 UAT artifact)
- Key decisions from CONTEXT.md honored (D-03, D-06, D-07, D-09, D-17)
- Link to `38-UX-POL-03-UAT.md` as evidence for UX-POL-03
- Deferred: none (all 4 Plan 38-01 requirements closed in this plan)
</output>
