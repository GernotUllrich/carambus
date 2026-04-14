# Phase 35: Printable Quick-Reference Card - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-13
**Phase:** 35-printable-quick-reference-card
**Mode:** discuss (recommended defaults shortcut)
**Areas presented:** A. Content scope, B. Print layout strategy, C. Shortcut cheat sheet format, D. Checklist mechanism, E. Cross-linking to walkthrough, F. UX bug honesty

---

## A. Before/During/After content scope

| Option | Description | Selected |
|--------|-------------|----------|
| Day-of (morning setup / during / upload+cleanup) | Matches "tournament-day laminated card" use case; week-before tasks belong in walkthrough prose | ✓ |
| Tournament cycle (days before / day-of / post-tournament) | Wider scope; cycle-level tasks | |

**Recommended default accepted.** → D-01, D-01a

---

## B. Print layout strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Shared `print.css` with `@media print` in `docs/stylesheets/` | CSS-only, works from browser Print, no plugin dependencies | ✓ |
| Dedicated print route (mkdocs-print-site-plugin) | Extra plugin weight | |
| Inline `<style media="print">` block scoped to card file | Limited to one page but non-standard | |

**Recommended default accepted.** → D-02, D-02a, D-02b, D-02c

---

## C. Keyboard shortcut cheat sheet format

| Option | Description | Selected |
|--------|-------------|----------|
| Markdown table + ASCII keycap strip verbatim from scoreboard-guide:228 | Zero new assets, print-safe, DRY with source of truth | ✓ |
| Simple markdown table only | Least visual | |
| Mini 2-column grid of keycap PNG images | Needs new PNG assets | |

**Recommended default accepted.** → D-03, D-03a, D-03b

---

## D. Checklist mechanism

| Option | Description | Selected |
|--------|-------------|----------|
| Markdown `- [ ]` task-list syntax | Idiomatic, renders as empty boxes on-screen and in print | ✓ |
| HTML `<input type="checkbox">` | Interactive in browser, fillable in print, but non-markdown | |
| Unicode `☐` character | Simplest, but no task-list semantics | |

**Recommended default accepted.** → D-04, D-04a

---

## E. Cross-linking to Phase 34 walkthrough

| Option | Description | Selected |
|--------|-------------|----------|
| Links present but suppressed visually in print via `@media print { a { text-decoration: none; color: inherit } }` | Rich on-screen, clean in print | ✓ |
| Every item always links to walkthrough anchor | Rich on-screen, noisy in print | |
| No links — card is standalone | Print-optimal but on-screen less useful | |

**Recommended default accepted.** → D-05, D-05a, D-05b

---

## F. Honesty about open UX bugs

| Option | Description | Selected |
|--------|-------------|----------|
| Current state with `!!! warning` callouts + `<!-- ref: F-NN -->` comments matching Phase 34 | Volunteers printing today get current reality; Phase 36 atomically updates | ✓ |
| Post-Phase-36 clean state (assume fixes land first) | Card aligned with future code but wrong for today's users | |

**Recommended default accepted.** → D-06, D-06a, D-06b

---

## Claude's Discretion
- Exact DE nav label phrasing
- Exact ordering and count of checklist items within the soft ceilings (Before 8–10, During 6–8, After 5–7)
- Exact A4 margin values within the "safe for printing" constraint
- Which walkthrough deep-links materialize per D-05b
- Shortcut block ordering (table-first vs keycap-strip-first)
- Exact `@media print` CSS rule list beyond the named selectors in D-02

## Deferred Ideas
- PDF export pipeline
- QR code on printed card linking to on-screen walkthrough
- Localized nav labels beyond DE/EN
- Interactive web-only version with persistent checkbox state
- Pre-tournament / post-tournament cycle tasks (explicitly excluded by D-01a)
