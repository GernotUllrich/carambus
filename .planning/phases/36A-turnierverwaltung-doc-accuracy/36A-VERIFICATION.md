---
phase: 36a-turnierverwaltung-doc-accuracy
verified: 2026-04-14T00:00:00Z
status: passed
score: 7/7 success criteria verified; 6/6 requirements satisfied; 57/58 findings addressed + 1 explicitly deferred
must_haves_passed: 7
must_haves_total: 7
---

# Phase 36A: Turnierverwaltung Doc Accuracy — Verification Report

**Phase Goal:** All 58 findings from the Phase 36 sentence-by-sentence review of `docs/managers/tournament-management.de.md` are addressed — factual errors corrected, missing glossary entries added, new troubleshooting recipes created, special-case appendices written, and the walkthrough restructured to honestly reflect manager activity vs. passive phases.

**Verified:** 2026-04-14
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) is used consistently across walkthrough + glossary in both languages | PASS | DE: Meldeliste=19, Teilnehmerliste=35, Setzliste=21. All three terms defined both as intro list (DE lines 31-33) and as full glossary entries (DE lines 293-302). EN parity confirmed (lines 39-40, 298-305). |
| 2 | All factual corrections from review blocks 1-7 applied to BOTH language files | PASS | Absence greps all return 0 for forbidden patterns (`DefaultS`, `alle 4 Matches`, `Carambus-Admin mit Datenbankzugang`, `Bälle-Ziel (innings_goal)`, `ClubCloud-Datenbank bezogen`, `## Mehr zur Technik`, `Modus ändern`-button, `Ergebnisse nach ClubCloud übertragen`-button, `DB-Admin-Recovery`, `<a id="architecture"`) in BOTH DE and EN files. |
| 3 | 9 new glossary entries exist in both languages | PASS | DE lines 293 (Meldeliste), 300 (Teilnehmerliste), 304 (T-Plan vs. Default-Plan), 323 (Logischer Tisch), 325 (Physikalischer Tisch), 327 (TableMonitor), 329 (Turnier-Monitor), 331 (Trainingsmodus), 333 (Freilos). EN lines 298/305/309/328/330/332/334/336/338 — full parity. |
| 4 | 5+ new appendix sections exist covering the required flows | PASS | 6 appendix anchors present in both files: `appendix-no-invitation`, `appendix-missing-player`, `appendix-nachmeldung`, `appendix-cc-upload`, `appendix-cc-csv-upload`, `appendix-rangliste-manual` (DE lines 464/479/492/504/531/548; EN lines 466/481/494/506/533/550). |
| 5 | Walkthrough restructured to honestly distinguish manager-action from passive phases (especially Schritt 11) | PASS | DE line 194: "Im Standardablauf hat der Turnierleiter hier keine aktive Rolle." DE line 196: phases-framing "Schritte 10, 11 und 12 sind in Wahrheit drei Phasen (Warmup → Spielbetrieb → Abschluss)". EN line 200: "In the standard flow the tournament director has no active role here." EN line 28 intro note: "tournament director normally has no active role". |
| 6 | "Mehr zur Technik" / "More on the architecture" section absent | PASS | `grep -F "## Mehr zur Technik"` = 0 (DE). `grep -F "## More on the architecture"` = 0 (EN). `grep 'id="architecture"'` = 0 both files. No forward-promise of "Phase 36 wird/will" remains. |
| 7 | `mkdocs build --strict` passes with zero new warnings over Phase 35 baseline | PASS | mkdocs build --strict ran to exit 0 with 0 WARNING lines and 0 ERROR lines (5.02s, 5.26s for both i18n builds). Remaining INFO-level anchor messages are pre-existing `managers/index.{de,en}.md` navigation issues (unresolved anchors `#player-management`, `#result-control`, etc.) that are out of Phase 36A scope per COVERAGE matrix. |

**Score:** 7/7 success criteria verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `docs/managers/tournament-management.de.md` | 573 lines, includes full walkthrough + glossary (3 sections) + troubleshooting + appendix | VERIFIED | 573 lines, 51 glossary entries, 14 step anchors, 10 TS recipe anchors, 6 appendix anchors, 0 occurrences of forbidden patterns |
| `docs/managers/tournament-management.en.md` | Mirror of DE with same structural anchors | VERIFIED | 575 lines, 6 appendix anchors, 10 TS anchors, full term parity with DE (Meldeliste/Teilnehmerliste glossary entries use German names in parentheses for disambiguation) |

### Key Link Verification

| From | To | Via | Status |
|------|-----|-----|--------|
| Schritt 1 intro | appendix-no-invitation, appendix-missing-player, appendix-nachmeldung | Markdown cross-refs | WIRED (DE line 58 forward-refs appendix-no-invitation; appendix-missing-player and appendix-nachmeldung referenced from Schritt 1 area) |
| Schritt 13 Endrangliste warning | appendix-rangliste-manual | Markdown cross-ref | WIRED (DE lines 230-235: `!!! warning "Endrangliste wird derzeit NICHT automatisch berechnet"` → `[Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual)`) |
| auto_upload_to_cc discussion | appendix-cc-upload | Markdown cross-ref | WIRED (6 occurrences of `auto_upload_to_cc` in DE file, cross-referenced to appendix) |
| Schritt 11 passive-phase text | step-12-monitor | Markdown cross-ref | WIRED (phases-framing at DE line 196) |
| TS-4 recipe | appendix-rangliste-manual + Trainingsmodus glossary | Markdown cross-ref | WIRED (DE line 391: "Trainingsmodus weiterbenutzen") |

### Anchor Integrity

Per COVERAGE.md Step 07 independent verification: 0 broken same-file anchor references in either DE or EN. All 6 appendix anchors (created by Plan 36A-06) and 14 step anchors (pre-existing + preserved) resolve. Zero 36A-owned broken links in mkdocs log.

---

## Success Criteria (ROADMAP.md Phase 36a) — All 7 Verified

| # | Criterion | DE | EN | Result |
|---|-----------|----|----|--------|
| 1 | Begriffshierarchie consistency across walkthrough + glossary | PASS | PASS | PASS |
| 2 | Factual corrections from review blocks 1-7 applied | PASS | PASS | PASS |
| 3 | 9 new glossary entries exist | PASS | PASS | PASS |
| 4 | New appendix sections cover no-invitation, missing-player, Nachmeldung, CC CSV upload, manual Rangliste (5 minimum; +1 cc-upload for 6 total) | PASS | PASS | PASS |
| 5 | Walkthrough restructured to distinguish manager-action from passive phases | PASS | PASS | PASS |
| 6 | "Mehr zur Technik" / "More on the architecture" section removed | PASS | PASS | PASS |
| 7 | mkdocs build --strict passes with zero new warnings over Phase 35 baseline | PASS | PASS | PASS |

---

## Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|----------------|-------------|--------|----------|
| DOC-ACC-01 | 36A-01, 36A-04, 36A-07 | Establish Begriffshierarchie (Meldeliste/Setzliste/Teilnehmerliste) | SATISFIED | Intro list + glossary entries + walkthrough usage consistent; REQUIREMENTS.md line 35 checkbox `[x]` |
| DOC-ACC-02 | 36A-01, 36A-02, 36A-03, 36A-05, 36A-07 | Correct factual errors in walkthrough Schritte 1-14 | SATISFIED | Absence greps all 0 for forbidden patterns; 11+ findings across blocks 1-7 verified; REQUIREMENTS.md line 36 checkbox `[x]` |
| DOC-ACC-03 | 36A-04, 36A-07 | Add missing glossary entries for system terms | SATISFIED | All 9 required entries present in both DE and EN glossary; REQUIREMENTS.md line 37 checkbox `[x]` |
| DOC-ACC-04 | 36A-05, 36A-06, 36A-07 | Create appendix sections for special cases | SATISFIED | 6 `id="appendix-*"` anchors in both files (5 required + 1 bonus cc-upload); REQUIREMENTS.md line 38 checkbox `[x]` |
| DOC-ACC-05 | 36A-03, 36A-06, 36A-07 | Reframe walkthrough passive phases honestly | SATISFIED | "keine aktive Rolle" / "no active role" in Schritt 11; phases-framing intro at DE line 196 / EN line 202; REQUIREMENTS.md line 39 checkbox `[x]` |
| DOC-ACC-06 | 36A-05, 36A-07 | Remove architectural monologue ("Mehr zur Technik") | SATISFIED | Section absent; no Phase-36 forward-promise; REQUIREMENTS.md line 40 checkbox `[x]` |

**Orphaned requirements:** None. All 6 DOC-ACC-NN requirements declared in PLAN frontmatters. No additional requirement IDs mapped to Phase 36a in REQUIREMENTS.md.

---

## Findings Coverage (F-36-01..F-36-58)

Input artifact `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md` contains exactly 58 findings (verified via `grep -oE 'F-36-[0-9]+' | sort -u | wc -l` = 58).

| Status | Count | Findings |
|--------|-------|----------|
| Addressed | 57 | F-36-01..F-36-54, F-36-56, F-36-57, F-36-58 |
| Deferred | 1 | F-36-55 (Parameter verification dialog — UI feature, tracked as UI-07 in REQUIREMENTS.md, scheduled for Phase 36b) |
| Orphaned | 0 | — |

Full finding-by-finding mapping is in `36A-COVERAGE.md` (Plan 36A-07). Spot-check verifications performed during this verification:

- F-36-12 (`DefaultS` → `Default{n}`): grep `DefaultS` = 0 in both files
- F-36-27 (`alle 4 Matches` → `2 Matches + 1 Freilos`): grep `alle 4 Matches` = 0; DE line 182 has corrected "2 Matches mit je 2 Spielern; der fünfte Spieler hat Freilos"
- F-36-30 (Schritt 11 rewrite — "keine aktive Rolle"): DE line 194 present
- F-36-34 (Endrangliste NOT auto-calculated): DE line 230 "Endrangliste wird derzeit NICHT automatisch berechnet"; Schritt 13 + `#appendix-rangliste-manual` + `#ts-endrangliste-missing` all present
- F-36-37 ("Übertragen nach ClubCloud" button removed): grep `Übertragen nach ClubCloud` = 0
- F-36-53 ("Modus ändern" fictional button): grep `Modus ändern` = 0
- F-36-54 (DB-Admin recovery myth): grep `Carambus-Admin mit Datenbankzugang` = 0
- F-36-57 ("Mehr zur Technik" section removed): grep `## Mehr zur Technik` = 0; no `id="architecture"`

---

## DE/EN Structural Parity

| Metric | DE | EN | Status |
|--------|----|----|--------|
| Appendix anchors | 6 | 6 | PASS |
| TS recipe anchors | 10 | 10 | PASS |
| Step anchors (step-1..step-14) | 14 | 14 | PASS |
| File line count | 573 | 575 | ~parity (EN +2 lines for intro note) |

---

## Scope-Boundary Retention (Documented Exception)

**Pattern:** `tournament_seeding_finished` retained in 1 location per file (DE line 317, EN line 322) — inside the System-Begriffe glossary entry for `AASM-Status`.

**Classification:** This is a **scope-boundary retention**, not a gap. F-36-09 targeted Schritt 5 user-facing text (which is clean — `grep` against Schritt 5 area returns 0). The glossary is a technical reference section for developers/admins where enumerating internal state names is appropriate. COVERAGE.md Plan 36A-01 documented this explicitly as a scope boundary.

No override is required; the COVERAGE matrix classifies this as SCOPE-BOUNDARY with a documented rationale.

---

## Anti-Patterns Scan

No anti-patterns found. Input artifact is markdown, and verification centered on presence/absence of specific strings. No TODO/FIXME/PLACEHOLDER markers found in the tournament-management.{de,en}.md files. The one retained technical term (`tournament_seeding_finished`) is inside a glossary reference entry, not a stub marker.

---

## mkdocs Build Delta

| Metric | Phase 35 Baseline | Phase 36A Result | Delta |
|--------|-------------------|------------------|-------|
| Exit code | 0 | 0 | PASS |
| WARNING lines | 191 | 0 | -191 (PASS — lower classification in current env) |
| ERROR lines | 0 | 0 | 0 (PASS) |
| Broken 36A-owned anchors | N/A | 0 | PASS |

**Note:** Current mkdocs environment emits anchor-resolution messages at INFO level rather than WARNING (lower severity than Phase 35 baseline). Success condition "WARN_COUNT ≤ 191 AND ERROR_COUNT == 0" passes trivially under either classification.

Remaining INFO-level broken anchors (~20 references) are **pre-existing navigation links** in `managers/index.{de,en}.md` pointing at section anchors that never existed in `tournament-management.md` (`#spielerverwaltung`, `#ergebniskontrolle`, `#round-robin`, `#ko-system`, etc.). These are explicitly out of Phase 36A scope and should be addressed by a later phase that overhauls the managers index navigation.

---

## Gaps Summary

None. All 7 roadmap success criteria verified against actual doc files via absence/presence greps. All 6 DOC-ACC requirements satisfied. 57/58 input findings addressed; 1 (F-36-55) explicitly deferred to Phase 36b as UI-07 per REQUIREMENTS.md. Zero orphaned findings. DE/EN parity confirmed. mkdocs strict build is clean. Phase 36A is complete and ready to close.

---

*Verified: 2026-04-14*
*Verifier: Claude (gsd-verifier, Opus 4.6 1M)*
