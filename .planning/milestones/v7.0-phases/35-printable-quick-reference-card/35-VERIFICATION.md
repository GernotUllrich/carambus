---
phase: 35-printable-quick-reference-card
verified: 2026-04-13T18:00:00Z
updated: 2026-04-13T18:30:00Z
status: passed
score: 4/4 success criteria fully verified (SC-2 automated PASS + human print-preview smoke test approved-with-notes)
human_verification:
  - task: "Print-preview smoke test of /managers/tournament-quick-reference/ (DE + EN) at A4, confirm mkdocs chrome hidden and page fits one sheet — Task 2 of 35-05-PLAN.md"
    result: approved-with-notes
    resolved_at: 2026-04-13T18:30:00Z
gaps: []
deferred:
  - "Replace keyboard-shortcut cheat sheet with annotated scoreboard screenshots + handle table (user feedback Task 2)"
  - "Add warm-up phase, shootout phase, and protocol editor coverage (user feedback Task 2)"
  - "Relax D-04a one-page A4 soft ceiling to 2 pages to accommodate expanded content (user feedback Task 2)"
---

# Phase 35: printable-quick-reference-card Verification Report

## Goal Achievement

### Success Criteria (from ROADMAP)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| 1 | Files exist, reachable from mkdocs nav, Before/During/After sections with checkbox items | PASS | DE + EN files present; `managers/tournament-quick-reference.md` in nav; DE nav_translation `Tournament Quick Reference: Turnier-Schnellreferenz` present; 21 task-list items in each file (within 19–25 range); anchors `before`, `during`, `after` all present in both files. |
| 2 | Print preview hides mkdocs chrome + A4 layout + legible font | PASS (automated + visual) | `docs/stylesheets/print.css` exists with `@media print` block and `size: A4` rule; all 7 chrome selectors present (`.md-header`, `.md-sidebar`, `.md-footer`, `.md-tabs`, `.md-search`, `.md-nav`, `.md-top`); print.css wired in `mkdocs.yml` `extra_css`. **Visual confirmation:** Human smoke test 2026-04-13 returned `approved-with-notes` — chrome hidden and A4 layout correct in both DE and EN; notes about content scope (shortcuts vs screenshots, warm-up/shootout/editor coverage, 2-page ceiling) captured in "Human Verification Required" section below and routed to follow-up phase. |
| 3 | Scoreboard keyboard shortcut cheat sheet included | PASS | DE ASCII strip (`[Protokoll] [-1] [-5] [-10] [Nächster] [+10] [+5] [+1] [Numbers]`) and EN ASCII strip (`[Protocol] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]`) both match `scoreboard-guide.{de,en}.md` line 228/227 byte-for-byte via `grep -Fxq`; DE table header `\| Taste \| Aktion \| Wann \|` and EN table header `\| Key \| Action \| When \|` present; `#scoreboard-shortcuts` anchors present in both files. |
| 4 | mkdocs build --strict zero new warnings vs baseline | PASS | `baseline=191` `final=191` `delta=0`. Full strict build log at `/tmp/35-05-mkdocs-final.log`. |

### Cross-Reference Integrity

| Check | Status | Evidence |
|-------|--------|----------|
| F-09, F-12, F-14, F-19 exist in 33-UX-FINDINGS.md | PASS | `grep "^\| F-NN "` matched all four IDs in `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md`. |
| All card deep-links resolve to Phase 34 anchors | PASS | 13 unique deep-link targets per language (`#walkthrough`, `#step-2-load-clubcloud`, `#step-4-participants`, `#step-5-finish-seeding`, `#step-6-mode-selection`, `#step-7-start-form`, `#step-8-tables`, `#step-9-start`, `#step-10-warmup`, `#step-11-release-match`, `#step-12-monitor`, `#step-13-finalize`, `#step-14-upload`); every target matched `<a id="...">` in `tournament-management.{de,en}.md`. Zero `CROSS-REF FAIL` lines. |

### Baseline Counts (from 35-01-BASELINE.txt)

| Stage | Warning count |
|-------|---------------|
| Pre-edit baseline (Plan 01 Task 1) | 191 |
| After Plan 01 (print.css + extra_css) | 191 |
| After Plan 02 (skeleton + nav) | 191 |
| After Plan 03 DE prose | 191 |
| After Plan 03 EN prose | 191 |
| After Plan 04 DE shortcuts | 191 |
| After Plan 04 EN shortcuts | 191 |
| Final (Plan 05) | 191 |

**D-09 gate:** PASSED — final warnings (191) <= baseline (191), delta = 0.

## Human Verification Required

The only step Claude cannot automate is the printed-page visual smoke test (Task 2 of 35-05-PLAN.md). Steps to execute:

1. Start local mkdocs dev server:
   ```bash
   cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master && mkdocs serve -a localhost:8000
   ```
2. Open `http://localhost:8000/en/managers/tournament-quick-reference/` (EN) and `http://localhost:8000/de/managers/tournament-quick-reference/` (DE).
3. Open the browser Print Preview (Cmd+P / Ctrl+P, A4 portrait, default margins).
4. Visually confirm for both languages:
   - mkdocs header, left sidebar, right ToC sidebar, tabs, footer, and search bar are ALL hidden
   - Content expands to full A4 page width
   - Page fits on ONE A4 sheet (or at most two — soft ceiling per D-04a)
   - Fonts are legible at arm's length (11pt body, 14–16pt headings)
   - Checkboxes render as visible square boxes
   - ASCII keycap strip is not clipped or wrapped mid-line
   - Shortcut table is readable, not cramped
   - No dependency on color for meaning (B/W-printer-friendly)
5. Stop the dev server: Ctrl+C.

On `approved` (or `approved-with-notes: ...`): continuation agent updates `status:` to `passed`, flips SC-2 row to full PASS, appends notes to this section.

On `rejected: <reason>`: continuation agent leaves `status:` as `human_needed`, adds entry to `gaps:` frontmatter array, escalates to orchestrator.

### Result: approved-with-notes (2026-04-13)

The human print-preview smoke test was executed against the local mkdocs dev server. Both DE (`/de/managers/tournament-quick-reference/`) and EN (`/en/managers/tournament-quick-reference/`) variants printed with mkdocs chrome hidden and correct A4 layout. The user returned **`approved-with-notes`** — the work ships as-is, with follow-up scope captured below.

**Verbatim user observation (DE):**

> "Scoreboard-Kürzel machen hier doch wenig Sinn. Es sollten Snapshots des Scoreboard sein mit markierten Handles, die tabellarisch kurz beschrieben werden. Warm-up und Shootout-Phasen werden nicht behandelt, ebenso der Protokoll-Editor. Das geht sicher nicht auf eine Seite - 2 Seiten dafür wären aber auch ok"

**English translation / summary (3 follow-up observations):**

1. **Wrong format for the shortcut reference.** Keyboard-shortcut cheat sheet does not fit the volunteer use case on this card. The section should instead use annotated scoreboard screenshots with marked handles, described in a compact table alongside the screenshots.
2. **Missing phase coverage.** The card does not address three tournament-day surfaces that volunteers also need: the warm-up phase, the shootout phase, and the protocol editor.
3. **One-page ceiling is too tight.** The D-04a one-page A4 soft ceiling cannot accommodate the expanded content above. A 2-page A4 card is acceptable.

**These items represent follow-up scope — see follow-up phase routing below.** The orchestrator will route items 1–3 to a new follow-up phase (likely Phase 38+) after Plan 35-05 closes and Phase 35 is marked complete. Plan 35 as scoped and shipped satisfies all four ROADMAP success criteria; the observations above describe content reshape and expansion that were explicitly out of Phase 35's scope.

### Follow-up phase routing

The three observations above will be handed to the orchestrator upon Plan 35-05 completion. They will NOT be addressed in Plan 35-05 and do NOT block Phase 35 completion. Expected follow-up phase content:

- Convert `#scoreboard-shortcuts` section from shortcut table + ASCII keycap strip to annotated scoreboard screenshots + handle-description table (images live under `docs/assets/` with bilingual captions).
- Add `#warmup`, `#shootout`, and `#protocol-editor` sections to the card in both languages.
- Update `docs/stylesheets/print.css` `@page { size: A4 }` rule and related `page-break-*` rules to permit a 2-page layout without clipping sections.
- Update D-04a decision record to reflect the new 2-page ceiling.

## Evidence Files

- `/tmp/35-05-mkdocs-final.log` — full `mkdocs build --strict` output (191 WARNING lines, exit code 1, matches baseline)
- `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` — per-plan warning counts with final delta recorded
- `.planning/phases/33-ux-review-wizard-audit/33-UX-FINDINGS.md` — F-NN citation source
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-management.{de,en}.md` — walkthrough anchor target file
