# Phase 35: Printable Quick-Reference Card - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Create `docs/managers/tournament-quick-reference.{de,en}.md` as a one-page printable A4 card that a volunteer can laminate and keep next to the tournament-day laptop. Content is a Before / During / After checklist plus a scoreboard keyboard shortcut cheat sheet. Print behavior must hide all mkdocs navigation chrome via shared `docs/stylesheets/print.css`, and the card must be reachable from the mkdocs nav in both languages with a DE label in `nav_translations`. `mkdocs build --strict` must pass with zero new warnings after the files and nav entries land.

No changes to existing docs, no new plugins, no rewrite of scoreboard-guide, no print-to-PDF tooling.
</domain>

<decisions>
## Implementation Decisions

### Content scope: Day-of
- **D-01:** Before / During / After describe **tournament day only**, not the tournament cycle. Scope anchors:
  - **Before** = morning setup (≈2 hours before first match): laptop plugged in and online, ClubCloud sync done, seeding reviewed, tables assigned, scoreboards open on every table's monitor, timer settings verified
  - **During** = tournament in progress: results entry per match, player rotation, handling absent players, correcting mis-entered scores, live monitoring
  - **After** = post-final-match: verifying all results entered, uploading to ClubCloud, closing out the AASM state, saving the protocol PDFs
- **D-01a:** Multi-day-cycle tasks (invitation handling, pre-tournament setup, scheduling) are OUT of scope for this card — they live in the Phase 34 walkthrough prose. The card intentionally duplicates nothing the walkthrough already covers; it only surfaces the check-off items a volunteer needs on the physical table during the tournament.

### Print layout strategy: Shared print.css via @media print
- **D-02:** Print layout is achieved with a single shared stylesheet at `docs/managers/../stylesheets/print.css` (i.e. `docs/stylesheets/print.css`), registered in `mkdocs.yml` under `extra_css` as a sibling of the existing `stylesheets/extra.css`. Contents use `@media print { ... }` and hide `.md-header`, `.md-header__button`, `.md-sidebar`, `.md-sidebar--primary`, `.md-sidebar--secondary`, `.md-footer`, `.md-tabs`, `.md-search`, `.md-nav`, `.md-top`, and any theme admonition chrome that wastes vertical space. The main content area `.md-content` expands to full page width with A4-safe margins (~15mm top/bottom, ~12mm left/right).
- **D-02a:** `print.css` is site-wide in theory (anyone printing any mkdocs page gets the same stripped chrome), but only the quick-reference card is intentionally designed for printing. Other pages continuing to print is a non-goal — we neither optimize nor break them.
- **D-02b:** Font sizing inside `@media print`: base 11pt, headings 13–16pt, monospace 10pt. Explicit rule — no dependency on color for meaning (REQUIREMENTS QREF-02): all checklist markers, keycap borders, and section dividers must be legible in pure black on white.
- **D-02c:** NO new plugins (no `mkdocs-print-site-plugin`, no `mkdocs-pdf-export-plugin`). Users print from the browser's native Print dialog after opening the card page.

### Scoreboard shortcut cheat sheet format: Markdown table + ASCII keycap strip
- **D-03:** The scoreboard shortcut section is built from **two blocks**:
  1. A markdown table with columns `Key | Action | When` covering the canonical shortcuts from `docs/players/scoreboard-guide.{de,en}.md` lines 209–233 and 624–626: `+1` (left/right arrows), `+5`, `+10`, `-1`, `-5`, `-10`, numeric `nnn`, `DEL`, `Next` (player switch), `Protocol`, pause/resume timer, undo (`^v` / Ctrl+Z).
  2. An ASCII keycap strip reproducing the scoreboard's on-screen button row verbatim: ``[Protocol] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]`` — same glyphs as `scoreboard-guide.de.md` line 228.
- **D-03a:** No new PNG/SVG keycap assets. The ASCII strip keeps the section print-safe at any DPI and matches the source-of-truth visual already in `scoreboard-guide.{de,en}.md`.
- **D-03b:** Shortcut section references the scoreboard guide once at the top as the canonical source: "Full explanations: [Scoreboard Guide](../players/scoreboard-guide.md#keyboard-shortcuts)". No deep-copy of prose — card stays tight.

### Checklist mechanism: Markdown task-list syntax
- **D-04:** All Before / During / After items are rendered as markdown task-list syntax — `- [ ] Text here`. mkdocs-material renders these as empty square boxes in both the on-screen view and the printed page. Volunteers can check items with a pen on the laminated printout. No HTML `<input>` tags, no Unicode `☐`, no custom CSS for box rendering.
- **D-04a:** Target item counts (soft ceiling — one A4 page): Before 8–10 items, During 6–8 items, After 5–7 items. If the total + shortcut cheat sheet exceeds one A4 page in `print.css`, trim by collapsing sub-items (the planner can verify fit during the plan phase by rendering + print-previewing).

### Cross-linking to Phase 34 walkthrough
- **D-05:** Each checklist item MAY include a deep link to its corresponding walkthrough anchor in `tournament-management.{de,en}.md` (e.g. `#step-2-load-clubcloud`). On-screen, the links render as clickable text; in print they are suppressed visually via `@media print { .md-content a { text-decoration: none; color: inherit } }` in `print.css`.
- **D-05a:** Walkthrough anchors referenced MUST be ones the Phase 34 skeleton locked (`#step-1-...` through `#step-14-upload`, plus `#walkthrough`, `#glossary`, `#troubleshooting`). No new anchors in `tournament-management.{de,en}.md` — Phase 35 is read-only toward Phase 34 output.
- **D-05b:** Not every item needs a link. Prefer links for multi-step items ("Tables assigned and monitors open") that benefit from the walkthrough's context; skip links for trivially obvious items ("Laptop plugged in"). The planner decides item-by-item during plan phase.

### Honesty about open UX bugs: current-state + forward-reference
- **D-06:** The card describes the CURRENT tournament-day flow, matching Phase 34 D-02. Where a known bug from `33-UX-FINDINGS.md` affects a check-off item, a short inline `!!! warning` callout (mkdocs admonition) with a trailing `<!-- ref: F-NN -->` comment surfaces it the same way Phase 34 did.
- **D-06a:** Mandatory forward-reference rule: Phase 36 (Small UX Fixes) MUST grep for these `<!-- ref: F-NN -->` comments in `tournament-quick-reference.{de,en}.md` when it fixes the underlying bug and either remove the warning callout or restate it post-fix. This mirrors the Phase 34 convention and preserves atomic doc/code alignment. Add this grep step to Phase 36's plan when it is created.
- **D-06b:** Target mandatory callouts for the card (to be refined during plan phase):
  - F-09 at "Tische zuordnen" step (table assignment gotcha)
  - F-12 / F-14 near "Scoreboards öffnen" (table monitor / kiosk mode handling)
  - F-19 at the upload-to-ClubCloud step (known upload edge case — Tier 3, gated for Phase 36 test plan)

### mkdocs nav entry and i18n label
- **D-07:** `mkdocs.yml` `nav:` block gets a new entry under the existing `Managers` section:
  ```
  - Tournament Quick Reference: managers/tournament-quick-reference.md
  ```
- **D-07a:** `nav_translations` block in the `i18n` plugin config gets a matching DE label: `Tournament Quick Reference: Turnier-Quick-Reference-Karte` (or similar — the planner picks the exact DE phrasing, but it MUST go into `nav_translations` in the SAME commit as the file creation, per QREF-01).
- **D-07b:** The quick-reference entry sits BETWEEN `Tournament Management` and `League Management` in the Managers nav group — logically adjacent to the full walkthrough.

### Bilingual parity and anchor convention (carried from Phase 34)
- **D-08:** Both language files share identical H2/H3 structure and English-based anchor slugs. Anchors: `#before`, `#during`, `#after`, `#scoreboard-shortcuts` at H2 level; H3 sub-anchors if any are added during planning must also be English-based.
- **D-08a:** As in Phase 34, the bilingual skeleton (matching headings + anchors) MUST land in its own commit before any prose is written — this is a **hard gate** carried forward from Phase 34 D-05. Any plan that writes prose before the skeleton is committed violates this.

### mkdocs strict build zero-warnings gate
- **D-09:** The card files + `print.css` + `mkdocs.yml` nav entries + `nav_translations` additions must collectively introduce **zero NEW strict warnings** over the Phase 34 post-rebase baseline of 94 warnings (191 WARNING log lines). If any of the 8–10 walkthrough deep-links in D-05 resolve to an anchor that doesn't actually exist in `tournament-management.{de,en}.md`, mkdocs strict will catch it — treat those as blocking defects and fix them in the plan that introduces them.
- **D-09a:** Follow Phase 34's baseline-measurement pattern: run `mkdocs build --strict` BEFORE touching the files (record baseline), then after each plan in the phase, then at the end of the final validation plan. Record counts in the phase SUMMARYs.

### Claude's Discretion
- Exact DE phrasing of the nav label (`Turnier-Quick-Reference-Karte` vs. `Schnellreferenz` vs. `Turnierkarte`)
- Exact ordering of the 8–10 Before items, 6–8 During items, 5–7 After items
- Exact A4 margin values (within the QREF-02 "safe for printing" constraint)
- Which of the 8–10 walkthrough deep-links actually materialize per D-05b
- Placement order of the two shortcut blocks (table first vs. keycap strip first)
- Exact `@media print` CSS rule list beyond the named selectors in D-02
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` §"Phase 35: Printable Quick-Reference Card" — Goal, success criteria 1–4, dependencies on Phase 34
- `.planning/REQUIREMENTS.md` QREF-01 / QREF-02 / QREF-03 — File existence + nav + `nav_translations`; print.css + A4-safe + no color dependency; scoreboard shortcut cheat sheet inclusion
- `.planning/PROJECT.md` — Volunteer persona (club officer, 2-3 tournaments/year), v7.0 Manager Experience milestone, "Code and docs stay in sync" core value

### Phase 34 output — prerequisite source-of-truth for walkthrough anchors
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md` — Walkthrough anchors `#step-1-*` through `#step-14-upload`, `#walkthrough`, `#glossary`, `#troubleshooting`, and the warning/tip callout pattern
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.en.md` — EN mirror with same anchors (bilingual parity locked by Phase 34 D-05)
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md` — 10-step Quick Start teaser from Phase 34 D-06 (relationship: card complements teaser; teaser is on-screen nav, card is on-paper reference)
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.en.md` — EN mirror
- `.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md` §"Implementation Decisions" D-02 (honest-about-bugs callout pattern) and D-05/D-05a (bilingual skeleton gate and English anchors)
- `.planning/phases/34-task-first-doc-rewrite/34-VERIFICATION.md` — Post-rebase mkdocs strict baseline (94 warnings) and bilingual parity verification recipe

### Scoreboard keyboard shortcut source-of-truth
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/players/scoreboard-guide.de.md` §lines 209–233 (+1/+5/+10/-1/-5/-10/Next/Protocol, timer controls) and §lines 624–626 (arrow key mapping) — Canonical shortcut list, DO NOT re-invent
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/players/scoreboard-guide.en.md` §lines 208–232 and §lines 623–625 — EN mirror

### Phase 33 UX findings — source for mandatory warning callouts
- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — F-IDs referenced by D-06b (F-09, F-12, F-14, F-19). Card's `<!-- ref: F-NN -->` comments MUST cite existing F-IDs from this file, never invented ones.

### mkdocs configuration surface
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/mkdocs.yml` §`nav:` block (add entry) / §`plugins: i18n: nav_translations` (add DE label) / §`extra_css` (add `stylesheets/print.css` alongside existing `stylesheets/extra.css`) / §`theme: features` (existing `navigation.sections`, `navigation.expand` — card page must work under both)
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/stylesheets/extra.css` — Existing stylesheet; `print.css` is a sibling file

### Translation / i18n
- `.planning/phases/34-task-first-doc-rewrite/34-CONTEXT.md` §"Translation / i18n" (canonical refs subsection) — translation workflow and terminology rules carried forward from Phase 34

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **mkdocs-material task-list styling**: `- [ ]` markdown syntax already renders cleanly in both on-screen and print contexts — no custom CSS needed for checkbox appearance
- **Admonition syntax** (`!!! warning`, `!!! tip`): Established in Phase 34 walkthrough — card's UX-bug callouts reuse the exact pattern (trailing `<!-- ref: F-NN -->` comment)
- **Existing `docs/stylesheets/extra.css`**: Template for how a stylesheet gets wired into `mkdocs.yml` `extra_css` list — sibling file pattern
- **Scoreboard button strip ASCII art** (`[Protocol] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]`): Already exists in `scoreboard-guide.de.md:228` and `scoreboard-guide.en.md:227` — copy-paste, don't re-invent
- **mkdocs-static-i18n plugin nav_translations block**: Already populated with DE labels for every existing managers page — follow the same add-a-line pattern

### Established Patterns
- **Bilingual parity hard gate**: Phase 34 D-05 established that the bilingual skeleton (matching headings + anchors) MUST land in its own commit BEFORE any prose is written. Same gate applies to Phase 35 (D-08a).
- **English-based anchor slugs, translated headings**: Phase 34 D-05a. Same convention for `#before`, `#during`, `#after`, `#scoreboard-shortcuts`.
- **Forward-reference UX bug callouts**: Phase 34 D-02/D-02a. Inline `!!! warning` with `<!-- ref: F-NN -->` comment tagging the `33-UX-FINDINGS.md` entry. Phase 36 atomically removes/updates these when it fixes the underlying bug.
- **mkdocs strict zero-new-warnings acceptance**: Phase 34 baseline = 94 warnings / 191 WARNING log lines (recorded in 34-VERIFICATION.md). Phase 35 adds zero to this count.
- **Cross-repo edit path**: Although files live in `carambus_master`, edits happen inline from `carambus_api` working directory; sync via `git -C carambus_master` + push/pull (per feedback memory `feedback_scenario_edits_in_current_dir.md`).

### Integration Points
- `mkdocs.yml` `nav:` block — Managers section gets one new entry
- `mkdocs.yml` `plugins: i18n: nav_translations` — one new DE label entry
- `mkdocs.yml` `extra_css` — one new entry for `stylesheets/print.css`
- `docs/stylesheets/print.css` — new file, sibling of existing `extra.css`
- `docs/managers/tournament-quick-reference.de.md` — new file
- `docs/managers/tournament-quick-reference.en.md` — new file
- Outbound links: Phase 34 walkthrough anchors in `tournament-management.{de,en}.md` (read-only, must not introduce changes there)

### Scope boundaries (reinforcement)
- **Read-only toward Phase 34 output** — card references Phase 34 anchors but does not modify `tournament-management.{de,en}.md` or `index.{de,en}.md`
- **Read-only toward scoreboard-guide** — card cites `scoreboard-guide.{de,en}.md` but does not modify it
- **No new plugins, no new theme features, no new custom JavaScript** — pure markdown + `@media print` CSS
</code_context>

<specifics>
## Specific Ideas

- The card should feel like a **pilot's pre-flight checklist** crossed with a restaurant kitchen's line checklist — dense but scannable, designed to be read in 30 seconds and used with a pen.
- Physical usage target: **laminated, clipped to the tournament-day laptop or taped next to the scoreboard**. This informs density (not minimal) and item ordering (chronological in the volunteer's actual workflow, not logical grouping).
- ASCII keycap strip should be **verbatim** from `scoreboard-guide.de.md:228` / `scoreboard-guide.en.md:227` — copy, don't rewrite. This is a deliberate DRY link to the source of truth.
- The card ships BEFORE Phase 36 lands, so **current-state callouts are non-negotiable** even if they make Phase 36's fix plan a bit more work. Volunteers printing today need the current reality.

</specifics>

<deferred>
## Deferred Ideas

- **PDF export** — "Print from browser" covers the use case; a dedicated PDF export pipeline (mkdocs-pdf-export-plugin) adds plugin weight for marginal value. Revisit only if users ask.
- **QR code linking to the on-screen version** — would be nice for "scan the printed card to see the full walkthrough", but needs a QR-generation step in the build. Park as a backlog item.
- **Localized nav label variants beyond DE/EN** — the i18n plugin supports more languages, but Phase 35 sticks to the DE/EN parity line the rest of the v7.0 milestone uses.
- **Interactive web-only version with clickable checkboxes that persist in localStorage** — out of scope for a printable card; belongs in a future "web dashboard" phase if it ever materializes.
- **Pre-tournament / post-tournament (non-day-of) cycle tasks** — explicitly excluded by D-01a. These belong in the Phase 34 walkthrough prose and the v7.0 milestone's broader manager experience work, not on a one-page day-of laminate.

### Reviewed Todos (not folded)
None — `gsd-tools todo match-phase 35` returned zero pending todos matching this phase's scope.

</deferred>

---

*Phase: 35-printable-quick-reference-card*
*Context gathered: 2026-04-13*
