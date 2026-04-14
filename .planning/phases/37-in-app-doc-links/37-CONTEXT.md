# Phase 37: In-App Doc Links - Context

**Gathered:** 2026-04-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Wire in-app wizard steps and tournament form help to the mkdocs-built documentation (Phase 34 rewrite). Fix the `mkdocs_link` locale bug (LINK-01), give every happy-path wizard step a working doc link (LINK-02), add form help links to five TournamentsController view contexts (LINK-03), and deep-link at least 3 wizard steps to stable anchors in the rewritten walkthrough (LINK-04).

**Out of scope:** any `docs/` content rewriting beyond adding stable `{#anchor-id}` attrs on target headings (Phase 34 owns the prose); any change to the mkdocs build config (`mkdocs.yml`) other than what the existing `attr_list` extension already enables; any change to the `docs_page.html.erb` view controller flow; any change to AASM states or to the Phase 36b tooltip Stimulus controller; any new form fields, validations, or Reflex handlers; any change to scoreboard/TableMonitor code paths; any ClubCloud sync or upload logic.

</domain>

<decisions>
## Implementation Decisions

### LINK-01: `mkdocs_link` helper URL shape
- **D-01:** The fixed `mkdocs_link` helper produces `/docs/en/#{path}/` for EN locale and `/docs/#{path}/` for DE locale (DE is the mkdocs root — no `de/` prefix). This matches the existing pattern at `app/views/static/docs_page.html.erb:18-22` and what the deployed mkdocs site actually serves. **REQUIREMENTS.md wording (`/docs/de/#{path}`) is treated as a typo** — we follow the code and the deployed site, not the requirements prose. No `mkdocs.yml` i18n config changes. No Nginx redirect layer.
- **D-02:** Index-page trailing-slash handling replicates `docs_page.html.erb:18-22` exactly: `mkdocs_path.end_with?('/index') || mkdocs_path == 'index'` ⇒ no trailing slash; otherwise add trailing slash. This matches `use_directory_urls: true` (mkdocs default) and avoids the 301 redirect penalty on every click.
- **D-03:** Helper callers MUST pass the `text:` argument — the current auto-humanize fallback (`path.split('/').last.humanize`) is removed. Rationale: the fallback produces English text in DE views ("Tournament Management") which is wrong, and there are no callers yet so removal is non-breaking. Wizard and form callers pass i18n-looked-up strings (e.g., `t('tournaments.docs.walkthrough_link')`).
- **D-04:** Helper accepts an optional `anchor:` keyword argument. When present, the built URL is `"#{base_url}##{anchor}"`. When nil, no fragment is appended. Anchors are passed as bare IDs (no leading `#`).
- **D-05:** The helper keeps `target: '_blank'` and `rel: 'noopener'` (current behavior) — doc opens in a new tab so volunteers don't lose their wizard state.

### LINK-04: Cross-locale stable anchor strategy
- **D-06:** Stable anchor IDs are added as explicit `{#stable-id}` `attr_list` attributes on the target headings in **both** `docs/managers/tournament-management.de.md` and `docs/managers/tournament-management.en.md`. The `attr_list` markdown extension is already enabled in `mkdocs.yml` (line 248), so no config change is needed. Identical fragments work in both locales — the Ruby helper stays locale-agnostic for the anchor portion.
- **D-07:** Exactly **4 stable anchors** are added in Phase 37 (minimum to exceed LINK-04's ≥3 floor with a safety margin):
  - `{#seeding-list}` on Schritt 3 / Step 3 (Setzliste übernehmen / Take over or generate the seeding list)
  - `{#mode-selection}` on Schritt 6 / Step 6 (Turniermodus auswählen / Select tournament mode)
  - `{#start-parameters}` on Schritt 7 / Step 7 (Start-Parameter und Tischzuordnung / Start parameters and table assignment)
  - `{#participants}` on Schritt 4 / Step 4 (Teilnehmerliste prüfen und ergänzen / Review and add participants)
- **D-08:** Anchor IDs are English-only kebab-case, identical between DE and EN files. Matches the REQUIREMENTS.md example prose (`#seeding-list`, `#mode-selection`). Short, language-neutral, stable. No `de-`/`en-` prefixes.
- **D-09:** Heading edits to `.de.md` and `.en.md` are the ONLY doc content changes in Phase 37. No prose rewrites, no section reordering, no new sections, no glossary additions. Editing is confined to appending `{#anchor}` after existing heading text on exactly 4 `###` lines per file (8 heading edits total).

### LINK-02: Wizard step partial API and link placement
- **D-10:** `app/views/tournaments/_wizard_step.html.erb` gets two new optional locals: `docs_path:` (string, e.g., `'managers/tournament-management'`) and `docs_anchor:` (string, e.g., `'seeding-list'`). Backward-compatible: steps without a `docs_path` render no link. The partial uses `local_assigns.fetch(:docs_path, nil)` / `fetch(:docs_anchor, nil)` matching the existing pattern (lines 15-20).
- **D-11:** The doc link renders **inside the collapsible `<details>` help block**, directly below the existing `<p>` help text, on its own line styled as `📖 Detailanleitung im Handbuch →`. This preserves Phase 36b's visual rhythm, keeps the link discoverable when it matters (active steps auto-open the details per Phase 36b `open` attr), and never competes visually with the primary action CTA.
- **D-12:** Inline steps 1 (Meldeliste von ClubCloud laden), 2 (Setzliste aus Einladung übernehmen), and 6 (Verwaltung der Turnierspiele) in `_wizard_steps_v2.html.erb` are retrofitted with direct `mkdocs_link` calls inside their existing `<details>` help blocks, using the same placement convention as the partial. This delivers success criterion 2 ("All 6 happy-path wizard steps in the canonical partial render a working doc link").
- **D-13:** Wizard step → anchor mapping:
  - Step 1 (ClubCloud load) → no anchor, links to `managers/tournament-management` page top (the Step 2 doc section describes this; but since success criterion 4 only requires ≥3 deep links, Step 1 using page-top is fine and keeps the link set conservative)
  - Step 2 (invitation upload) → `#seeding-list`
  - Step 3 (participants edit) → `#participants`
  - Step 4 (finalize participants) → `#participants` (same section covers finalize)
  - Step 5 (mode selection) → `#mode-selection`
  - Step 6 (start + manage) → `#start-parameters`
  - This gives 5 deep-linked wizard steps + 1 page-top, comfortably exceeding LINK-04's ≥3 requirement while mapping each step to the most relevant doc section.
- **D-14:** Link text is provided via new i18n keys under `tournaments.docs.walkthrough_link` (DE and EN). Single key per link type — reused across all wizard steps. German: `"📖 Detailanleitung im Handbuch →"`. English: `"📖 Full walkthrough in handbook →"`.

### LINK-03: Form help link scope and placement
- **D-15:** Five form contexts map to **four views**, each getting exactly **one** prominent doc link:
  - Invitation upload → `app/views/tournaments/parse_invitation.html.erb` → `#seeding-list`
  - Participant editing → `app/views/tournaments/define_participants.html.erb` → `#participants`
  - Mode selection → `app/views/tournaments/finalize_modus.html.erb` → `#mode-selection`
  - Table assignment + start settings → `app/views/tournaments/tournament_monitor.html.erb` → `#start-parameters` (both contexts share one form, so one link)
- **D-16:** For `tournament_monitor.html.erb`: the doc link sits at the **form top**, above the parameter field rows, as a single prominent `📖 Detailanleitung im Handbuch →` link. The ~13 Phase 36b Stimulus tooltips (`data-controller="tooltip"`) on parameter fields are **NOT modified** — they stay as quick inline hints. The form-top link is the "when I need depth" escape hatch. Zero regressions on Phase 36b work.
- **D-17:** For the three pre-start views (`parse_invitation`, `define_participants`, `finalize_modus`): the doc link sits directly below the page H1/title in a small **`📖 Hilfe:`** info box styled as an unobtrusive blue strip. Format: `📖 Hilfe zu diesem Schritt: [Detailanleitung im Handbuch →]`. Consistent location across all three views so 2×/year volunteers build a "look there when stuck" habit. Info box uses the same Tailwind classes as the existing Begriffserklärung box in `_wizard_steps_v2.html.erb` (`bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4 mb-6`) for visual consistency.
- **D-18:** Form help links reuse the 4 stable anchors from D-07 — no new anchors introduced for form use cases. Wizard and form share the same deep-link targets because they document the same workflow from complementary angles.
- **D-19:** Link text for form help uses a new i18n key `tournaments.docs.form_help_link` — same text reused across all four views. German: `"📖 Detailanleitung im Handbuch →"`. English: `"📖 Full walkthrough in handbook →"`. (Intentionally the same as D-14 wizard link text — one canonical string reduces translation drift and matches the "single escape hatch" mental model.)
- **D-20:** The `📖 Hilfe:` label text itself is also i18n'd via `tournaments.docs.form_help_prefix` (DE: `"Hilfe zu diesem Schritt:"`, EN: `"Help for this step:"`).

### Claude's Discretion
- Exact Tailwind class tuning for the new form-header info boxes (e.g., whether to use `mt-4` vs `my-6`, responsive padding choices) — keep consistent with Phase 36b visual conventions.
- Whether the `mkdocs_link` helper returns raw URL strings as a second API (for cases where the caller wants `link_to` with custom wrapping) vs always wrapping in `link_to`. Recommend: keep current `link_to` wrapping; if a caller needs raw URL, extract a private `mkdocs_url` helper method and keep `mkdocs_link` as the `link_to` wrapper.
- Exact placement of the new i18n keys in `config/locales/de.yml` and `config/locales/en.yml` — alphabetize inside the existing `tournaments:` namespace; add a new `docs:` sub-namespace. Follow Phase 36b's `tournaments.monitor_form.*` convention.
- Whether to add a minimal Capybara system test that visits one wizard step and asserts the doc link renders with the correct URL shape + anchor fragment for both DE and EN locales. Recommend: yes — one test per locale is cheap insurance against future regressions.
- Whether test fixtures / factories need updating for the system test — only if the existing tournament fixture can't reach the wizard view in a state that shows active steps. Likely a no-op.

### Folded Todos
None — no relevant pending todos matched this phase's scope.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Roadmap + requirements
- `.planning/ROADMAP.md` §Phase 37 — Phase goal, dependencies on 34/35/36a, success criteria
- `.planning/REQUIREMENTS.md` §In-App Doc Links — LINK-01..LINK-04 acceptance criteria
- `.planning/REQUIREMENTS.md` §Task-First Walkthrough Rewrite — DOC-01, DOC-02 (upstream anchors Phase 34 was meant to establish; Phase 37 adds the stable `{#id}` attrs on top)

### Helper + views to modify
- `app/helpers/application_helper.rb:143-151` — `mkdocs_link` helper (current buggy version)
- `app/helpers/application_helper.rb:134-140` — `docs_page_link` helper (reference for the correct locale pattern)
- `app/views/static/docs_page.html.erb:18-22` — Canonical locale-aware URL pattern (DE root, EN prefix, index handling) — the fixed helper must match this exactly
- `app/views/tournaments/_wizard_steps_v2.html.erb` — Canonical wizard partial (6 happy-path steps, steps 1/2/6 inline, steps 3/4/5 via `render 'wizard_step'`)
- `app/views/tournaments/_wizard_step.html.erb` — Step partial, gets new `docs_path:` + `docs_anchor:` locals
- `app/views/tournaments/parse_invitation.html.erb` — Invitation upload view (LINK-03 target)
- `app/views/tournaments/define_participants.html.erb` — Participant editing view (LINK-03 target)
- `app/views/tournaments/finalize_modus.html.erb` — Mode selection view (LINK-03 target)
- `app/views/tournaments/tournament_monitor.html.erb` — Start settings + table assignment (LINK-03 target, already has Phase 36b tooltips — DO NOT MODIFY those)

### Doc files to add stable anchors (exactly 4 headings each)
- `docs/managers/tournament-management.de.md` — append `{#seeding-list}`, `{#mode-selection}`, `{#start-parameters}`, `{#participants}` on the four target `###` headings
- `docs/managers/tournament-management.en.md` — same four `{#anchor}` IDs on matching headings (identical IDs, English-only kebab-case per D-08)
- `mkdocs.yml:248` — confirms `attr_list` extension is enabled (no config change needed)

### i18n
- `config/locales/de.yml` — add `tournaments.docs.walkthrough_link`, `tournaments.docs.form_help_link`, `tournaments.docs.form_help_prefix`
- `config/locales/en.yml` — same keys, English strings
- `config/locales/de.yml` existing `tournaments.monitor_form.*` namespace (Phase 36b) — follow this naming convention

### Prior phase artifacts
- `.planning/phases/36B-ui-cleanup-kleine-features/36B-CONTEXT.md` §Parameter form tooltips — Phase 36b tooltip Stimulus convention (DO NOT modify the 13 existing tooltips)
- `.planning/phases/34-task-first-doc-rewrite/` — upstream doc rewrite (Phase 37 only adds heading anchors, does NOT touch prose)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `mkdocs_link` helper (`app/helpers/application_helper.rb:143`) — already wired into the I18n locale lookup; just needs the locale-aware URL shape fix + anchor support + text enforcement.
- `docs_page_link` helper (`app/helpers/application_helper.rb:135`) — proves the pattern (locale-aware internal link). NOT touched by this phase; internal doc viewer stays as-is.
- Stimulus `tooltip` controller (Phase 36b) — NOT modified, but its presence in `tournament_monitor.html.erb` constrains the new doc link placement (must not interfere with the 13 existing tooltipped fields).
- `_wizard_step.html.erb` partial's `local_assigns.fetch(...)` pattern (lines 15-20) — direct template for adding new optional locals.
- `attr_list` markdown extension in `mkdocs.yml` (already enabled) — unlocks `{#id}` explicit anchor IDs in both `.de.md` and `.en.md` without config changes.

### Established Patterns
- **Locale-aware URLs:** `docs_page.html.erb:18-22` is the canonical template for handling DE-root / EN-prefix with index-file trailing-slash handling. Any new URL-building helper must replicate this exactly.
- **i18n key namespacing:** `tournaments.monitor_form.{labels,tooltips}.*` (Phase 36b) establishes the pattern. Phase 37 adds `tournaments.docs.*`.
- **Partial locals with defaults:** `local_assigns.fetch(:key, default)` — existing `_wizard_step.html.erb` uses this for all 5 optional locals; new `docs_path`/`docs_anchor` follow suit.
- **Blue info box styling:** `bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-700 rounded-lg p-4 mb-6` — used in `_wizard_steps_v2.html.erb:373` for the Begriffserklärung box. Reused for the four form-help info boxes in LINK-03.
- **Collapsible help:** `<details open={status==:active}>` from Phase 36b wizard auto-expand — the doc link renders inside this block so it auto-surfaces on the active step.

### Integration Points
- Single helper change (`application_helper.rb`) is consumed by all 6 wizard step renders + 4 form-help renders = 10 call sites total.
- Doc heading edits (8 total: 4 IDs × 2 language files) are the only mkdocs content changes. The mkdocs CI rebuild after deploy will pick them up; no runtime Rails coupling.
- i18n key additions (3 keys × 2 locales = 6 YAML entries) under new `tournaments.docs.*` namespace — isolated, no risk of colliding with Phase 36b keys.

</code_context>

<specifics>
## Specific Ideas

- User explicitly chose the REQUIREMENTS.md typo interpretation (D-01): follow `docs_page.html.erb` and the actual mkdocs build, not the REQUIREMENTS prose. This is important for the planner — it tells you NOT to add a `/docs/de/` rewrite rule or change `mkdocs.yml`.
- User chose "all 6 wizard steps get links" (D-12) — the retrofit of inline steps 1/2/6 is load-bearing for success criterion 2. Don't defer it.
- User chose to reuse wizard anchors for form help (D-18) — only 4 anchors total for Phase 37, shared between wizard and form use cases. Planner should NOT introduce a 5th or 6th anchor unless a concrete gap appears.
- User chose to leave Phase 36b's 13 tooltips untouched (D-16) — the form-top link in `tournament_monitor.html.erb` is additive, not a replacement for tooltips.
- User chose i18n-locked link text with "Require caller to pass text" (D-03) — removal of the humanize fallback is deliberate. Planner should NOT reintroduce a fallback "for safety".

</specifics>

<deferred>
## Deferred Ideas

- **Per-field doc links in `tournament_monitor.html.erb`** — hybrid approach (form-top link + 2-3 key field sub-links on `sets_to_win`/`sets_to_play`/`timeout`) was rejected in favor of the single form-top link. Revisit only if volunteer feedback shows the form-top link gets missed.
- **Form-oriented separate anchor set** — creating `#invitation-upload`, `#table-assignment`, etc. anchors that differ from wizard anchors. Rejected to keep the 4-anchor set minimal. Revisit if form docs diverge from wizard docs.
- **Flash-banner style doc links** — rejected because dismissable banners disappear on the second visit and 2×/year volunteers would lose track.
- **Anchor registry lookup table in Ruby** (anchor-key → locale-slug map) — rejected in favor of explicit `{#id}` attrs. If future phases add many more anchors, a registry may become worthwhile, but YAGNI for 4 anchors.
- **Mkdocs config change to force `/docs/de/` prefix** — rejected. Too much blast radius. Revisit only if the marketing site architecture requires symmetric language URLs.
- **Adding stable anchors to other doc files beyond `tournament-management.{de,en}.md`** — deferred to whichever future phase introduces the first in-app link to those other files. Phase 37 only anchors what it links.
- **Minimum Capybara system test across all 6 wizard steps** — only 1 test per locale is in scope (Claude's discretion). Full per-step coverage deferred.

</deferred>

---

*Phase: 37-in-app-doc-links*
*Context gathered: 2026-04-14*
