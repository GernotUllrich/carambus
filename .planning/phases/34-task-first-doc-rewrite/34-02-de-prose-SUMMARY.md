---
phase: 34-task-first-doc-rewrite
plan: 02
subsystem: docs
tags: [mkdocs, markdown, DE, carambus_master, tournament-management, walkthrough, glossary, troubleshooting]

# Dependency graph
requires:
  - plan: 34-01
    provides: "Frozen H2/H3/anchor skeleton for tournament-management.de.md and index.de.md"
provides:
  - "Full DE prose for tournament-management.de.md: 14-step task-first walkthrough, 15+ term glossary, 4-case troubleshooting, architecture tail"
  - "Rewritten index.de.md Quick Start: 10-step teaser linking into walkthrough anchors (DOC-05)"
  - "4 mandatory Phase 33 callouts embedded with <!-- ref: F-NN --> comments for Phase 36 grepping (D-02a)"
affects:
  - "34-03 (EN prose): parallel plan, no file overlap"
  - "35-quick-reference-card: walkthrough anchors stable, card can condense from this content"
  - "37-in-app-doc-links: anchor slugs are stable English-based IDs established in 34-01"
  - "36-small-ux-fixes: can grep <!-- ref: F-09/F-12/F-14/F-19 --> to remove obsolete callouts atomically"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Admonition callouts with trailing <!-- ref: F-NN --> HTML comments for Phase 36 atomic removal (D-02a)"
    - "Glossary entries with wizard-step cross-references via #step-N-slug fragment links"
    - "Troubleshooting cases using bold-label format: **Problem:** / **Ursache:** / **Lösung:**"
    - "Index Quick Start as 10-step teaser condensing 14 walkthrough steps with anchor deep-links"

key-files:
  created: []
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/index.de.md

key-decisions:
  - "mkdocs build --strict: 191 warnings both before and after changes — zero new warnings introduced (pre-existing stale links in other doc sections)"
  - "Walkthrough prose describes current wizard behavior honestly including known UX bugs (F-03/F-04 partial sync, F-11 step-skip) per D-02"
  - "Admonition wording matches <interfaces> block exactly for F-09, F-12, F-14, F-19 — no paraphrasing"
  - "All three tasks (walkthrough, glossary, troubleshooting) written in single file write to avoid anchor-disruption risk, then committed atomically"

requirements-completed: [DOC-01, DOC-03, DOC-04, DOC-05]

# Metrics
duration: 35min
completed: 2026-04-13
---

# Phase 34 Plan 02: DE Prose Summary

**Full DE volunteer-facing walkthrough, glossary (15 terms), troubleshooting (4 cases), and index Quick Start teaser written for tournament-management.de.md — NDM Freie Partie Klasse 1–3 scenario framing with 4 mandatory Phase 33 callouts embedded**

## Performance

- **Duration:** ~35 min
- **Completed:** 2026-04-13
- **Tasks:** 3 (Task 1: walkthrough + tail, Task 2: glossary, Task 3: troubleshooting + index + commit)
- **Files modified:** 2 (in carambus_master)

## Line Count

| File | Before | After |
|------|--------|-------|
| tournament-management.de.md | 130 lines (skeleton) | 259 lines |
| index.de.md | unchanged structure | Quick Start section updated (10 lines replaced) |

## Accomplishments

- 14-step task-first walkthrough written with concrete click-level prose, formal "Sie" throughout
- Scenario section uses exact D-04a framing: generic NBV NDM Freie Partie Klasse 1–3, 5 participants, 2 tables
- 4 mandatory admonition callouts present with exact <interfaces> wording and trailing `<!-- ref: F-NN -->` comments
- Glossary complete: 10 Karambol terms + 4 Wizard terms + 4 System terms = 18 entries total
- 4 troubleshooting cases with Problem/Ursache/Lösung, grounded in Phase 33 findings
- 2-paragraph "Mehr zur Technik" tail block links to `../developers/index.md`
- index.de.md Quick Start: 10 teaser steps with `#step-N-*` fragment links into walkthrough anchors
- All placeholder bodies (`_(Inhalt folgt in Plan 34-02)_`, `_(folgt)_`) removed
- Zero new mkdocs build --strict warnings introduced

## Admonitions Added

| Ref | Type | Step | Opening text |
|-----|------|------|-------------|
| F-09 | `!!! warning` | Schritt 5 — Teilnehmerliste abschließen | "Teilnehmerliste abschließen ist endgültig" |
| F-12 | `!!! tip` | Schritt 6 — Turniermodus auswählen | "Welchen Turnierplan wählen?" |
| F-14 | `!!! tip` | Schritt 7 — Start-Parameter ausfüllen | "Englische Feldbezeichnungen im Start-Formular" |
| F-19 | `!!! warning` | Schritt 9 — Turnier starten | "Warten, nicht erneut klicken" |

## Glossary Terms Defined

**Karambol-Begriffe (10):** Freie Partie, Cadre (35/2 47/1 47/2 71/2), Dreiband, Einband, Aufnahme, Bälle-Ziel (innings_goal), Höchstserie (HS), Generaldurchschnitt (GD), Spielrunde, Tisch-Warmup

**Wizard-Begriffe (4):** Setzliste, Turniermodus / Austragungsmodus, Turnierplan-Kürzel (T04 T05 Default5), Scoreboard

**System-Begriffe (4):** ClubCloud, AASM-Status, DBU-Nummer, Rangliste

## Commit in carambus_master

- **SHA:** `0505ed50`
- **Message:** `docs(34-02): DE prose — walkthrough, glossary, troubleshooting, Quick Start teaser`
- **Files:** docs/managers/tournament-management.de.md, docs/managers/index.de.md
- **Net change:** +168 / -65 lines

## mkdocs build --strict Result

**No new warnings introduced.** Warning count: 191 before and 191 after our changes (verified via `git stash` round-trip). The 191 warnings are all pre-existing stale cross-links in unrelated doc sections (players/, administrators/, decision-makers/, developers/). The `managers/index.de.md` INFO-level messages pointing to old `tournament-management.de.md` anchors (e.g. `#spielerverwaltung`, `#round-robin`) are pre-existing stale links from deeper in that file — they are INFO-level (not WARNING-level) and were present before this plan.

## Deviations from Plan

### Auto-fixed Issues

None.

### Minor scope notes

- All three tasks (walkthrough prose, glossary, troubleshooting) were written as a single full-file rewrite rather than three separate Edit passes. This avoids anchor-disruption risk from sequential edits on a structurally complex file and was explicitly permitted by the plan ("Full rewrite is acceptable here as long as the anchor tags and H2/H3 headers are preserved verbatim").
- The plan called for separate commits per task; instead a single atomic commit covers all three tasks as directed by Task 3's commit instruction (`git commit` at end of Task 3 covering both files). The plan's own commit message template confirms this design.

## Known Stubs

None — all placeholder bodies from the skeleton have been replaced with real prose. The `../developers/index.md` link in the "Mehr zur Technik" tail block points to an existing file.

## Threat Flags

None — docs-only changes, no new code surface.

## Self-Check

Checked files:
- `tournament-management.de.md`: FOUND (259 lines) ✓
- `index.de.md`: FOUND (Quick Start updated) ✓
- Commit `0505ed50`: FOUND in carambus_master git log ✓
- All 4 `<!-- ref: F-NN -->` comments: PRESENT ✓
- All 14 `id="step-..."` anchors: PRESENT (14) ✓
- All glossary anchor IDs (glossary-karambol, glossary-wizard, glossary-system): PRESENT ✓
- All 4 troubleshooting anchor IDs: PRESENT ✓
- No placeholder strings remaining: CONFIRMED ✓
- mkdocs build --strict: 191 warnings (all pre-existing) ✓

## Self-Check: PASSED
