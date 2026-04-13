---
phase: 35-printable-quick-reference-card
plan: 04
subsystem: docs
tags: [docs, scoreboard, keyboard-shortcuts, ascii-keycap, dry-link]

# Dependency graph
requires:
  - phase: 35-printable-quick-reference-card
    plan: 03
    provides: Before/During/After checklist prose with F-NN callouts intact; scoreboard-shortcuts H2 still on its Plan 02 placeholder awaiting Plan 04
  - phase: 35-printable-quick-reference-card
    plan: 02
    provides: bilingual scoreboard-shortcuts H2 anchor (#scoreboard-shortcuts) in both DE and EN files
  - canonical_source:
      file: docs/players/scoreboard-guide.de.md
      line: 228
      content: "[Protokoll] [-1] [-5] [-10] [Nächster] [+10] [+5] [+1] [Numbers]"
  - canonical_source:
      file: docs/players/scoreboard-guide.en.md
      line: 227
      content: "[Protocol] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]"
provides:
  - Complete DE + EN scoreboard-shortcuts H2 section with shortcut table (14 data rows) and verbatim ASCII keycap strip
  - Single fragment-less link in each file from the shortcut section to docs/players/scoreboard-guide.md
  - Bilingual parity preserved: identical anchor set, identical row count, identical link count
  - Phase 35 content is now 100% authored — only Plan 05 (validation) remains
affects:
  - 35-05-PLAN.md (validation unblocked; all content in place)
  - carambus_master follow-up: if scoreboard-guide.{de,en}.md:228/227 ever changes, this card drifts — documented below as known DRY follow-up

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "D-03 two-block structure: markdown shortcut table + verbatim ASCII keycap strip, table first then strip"
    - "D-03a verbatim-copy discipline: ASCII strip copied via sed -n '228p' / '227p' from source, not retyped"
    - "D-03b single canonical link, fragment-less (no #keyboard-shortcuts anchor exists in bilingual source; documented discretionary deviation)"
    - "Post-edit verification via grep -Fxq with source line captured via sed (byte-identical assertion)"

key-files:
  created:
    - .planning/phases/35-printable-quick-reference-card/35-04-SUMMARY.md
  modified:
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md
    - /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md
    - .planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt

key-decisions:
  - "Fragment-less link target (D-03b deviation): plan CONTEXT.md §D-03b proposed ../players/scoreboard-guide.md#keyboard-shortcuts, but verification showed no such anchor exists — DE source uses #tastenbelegung, EN uses #key-bindings. Using either fragment would break bilingual parity AND risk a strict-build warning. Discretionary decision under D-05b to link to the page with no fragment; also protects against drift in source heading slugs."
  - "14 shortcut table rows per language (arrow+PgUp/PgDn, +1/+5/+10, -1/-5/-10, Numbers->0-9, Del, Esc, Enter, Next, Protocol, B, Down, Ctrl+Z undo, B->Down timer) — matches D-03 canonical coverage plus Ctrl+Z undo explicitly permitted by D-03 and timer-control B->Down derived from scoreboard-guide §lines 629-632"
  - "Triple-backtick fenced code block (no language hint) for the ASCII strip, matching the source format in scoreboard-guide.{de,en}.md:227-229 / 226-228"
  - "Bilingual parity verified via three independent checks: (a) row count identical (16 lines each including header+separator = 14 data rows), (b) anchor diff empty, (c) ASCII strip byte-identical to its own language's source line"

requirements-completed:
  - QREF-03

# Metrics
duration: ~2min
completed: 2026-04-13
---

# Phase 35 Plan 04: Scoreboard Keyboard Shortcut Cheat Sheet Summary

**DE and EN tournament-quick-reference files now carry the complete scoreboard-shortcuts section — 14-row shortcut table plus verbatim ASCII keycap strip copied byte-for-byte from scoreboard-guide.{de,en}.md:228/227, wired with a single fragment-less link to the canonical scoreboard guide page, mkdocs strict warning count unchanged at 191 (delta 0 vs Plan 03 ceiling).**

## Performance

- **Duration:** ~2 min
- **Started:** 2026-04-13T17:50:34Z
- **Completed:** 2026-04-13T17:52:40Z
- **Tasks:** 2
- **Files modified:** 3 (2 carambus_master, 1 carambus_api)
- **Commits:** 2 (carambus_master)

## Accomplishments

- Replaced DE scoreboard-shortcuts placeholder (`_(Tastenkürzel-Tabelle und ASCII-Button-Leiste folgen in Plan 35-04.)_`) with:
  - 1 canonical-source link: `Vollständige Erklärung: [Scoreboard-Anleitung](../players/scoreboard-guide.md).`
  - 1 markdown table `| Taste | Aktion | Wann |` with 14 data rows
  - 1 fenced code block containing the verbatim DE ASCII keycap strip from `scoreboard-guide.de.md:228`
- Replaced EN placeholder (`_(Shortcut table and ASCII button strip TBD in Plan 35-04.)_`) with the mirror structure and the verbatim EN ASCII strip from `scoreboard-guide.en.md:227`
- Ran `mkdocs build --strict` after each file edit: 191 WARNING log lines both times (delta 0 vs Plan 03, delta 0 vs D-09 ceiling)
- Recorded post_plan_04 DE+EN metrics in `35-01-BASELINE.txt`
- Committed each task atomically in carambus_master with conventional-commit messages

## ASCII Keycap Strips Captured (verbatim)

**DE** — copied from `docs/players/scoreboard-guide.de.md:228`:

```
[Protokoll] [-1] [-5] [-10] [Nächster] [+10] [+5] [+1] [Numbers]
```

**EN** — copied from `docs/players/scoreboard-guide.en.md:227`:

```
[Protocol] [-1] [-5] [-10] [Next] [+10] [+5] [+1] [Numbers]
```

Byte-identical verification (both passed):
```
# DE
$ source_line=$(sed -n '228p' .../scoreboard-guide.de.md)
$ grep -Fxq "$source_line" .../tournament-quick-reference.de.md && echo STRIP_OK
STRIP_OK

# EN
$ source_line=$(sed -n '227p' .../scoreboard-guide.en.md)
$ grep -Fxq "$source_line" .../tournament-quick-reference.en.md && echo STRIP_OK
STRIP_OK
```

## Shortcut Table Row Count

| Language | Header | Separator | Data rows | Total | Range per D-03 |
|----------|--------|-----------|-----------|-------|----------------|
| DE       | 1      | 1         | 14        | 16    | covers canonical list |
| EN       | 1      | 1         | 14        | 16    | covers canonical list |

DE/EN parity verified:
```
$ de_rows=$(awk '/<a id="scoreboard-shortcuts">/,0' .../de.md | grep -c '^|.*|.*|.*|$')
$ en_rows=$(awk '/<a id="scoreboard-shortcuts">/,0' .../en.md | grep -c '^|.*|.*|.*|$')
$ echo "DE: $de_rows, EN: $en_rows"
DE: 16, EN: 16
```

Row coverage (both languages): arrows/PgUp/PgDn for +1 per player, button-press `+1/+5/+10` and `-1/-5/-10`, `Numbers`→digits, `Del`, `Esc`, `Enter`, `Next`/`Nächster`, `Protocol`/`Protokoll`, navigation `B`, `Down`, `Ctrl+Z` (`^v`) undo, `B`→`Down` timer control.

## Canonical Link to Scoreboard Guide

Both files contain exactly one fragment-less link at the top of the shortcut section:

- **DE:** `Vollständige Erklärung: [Scoreboard-Anleitung](../players/scoreboard-guide.md).`
- **EN:** `Full explanations: [Scoreboard Guide](../players/scoreboard-guide.md).`

Verified no anchor fragment:
```
$ grep -oE 'scoreboard-guide\.md[^)]*' .../de.md
scoreboard-guide.md
$ grep -oE 'scoreboard-guide\.md[^)]*' .../en.md
scoreboard-guide.md
```

**Discretionary deviation from CONTEXT.md §D-03b:** The context doc suggested `[...](../players/scoreboard-guide.md#keyboard-shortcuts)`. Verification showed no such anchor exists in either source file — DE uses `## Tastenbelegung` (auto-slug `#tastenbelegung`), EN uses `## Key Bindings` (auto-slug `#key-bindings`). Using either fragment would (a) break bilingual parity in the link target (DE would have to link to one slug, EN to another) and (b) risk a strict-build warning if the slug doesn't match exactly. Under D-05b ("planner decides item-by-item"), the fragment-less page link was chosen. Planner note in 35-04-PLAN.md §Objective documents this decision.

## Post-Plan-04 mkdocs strict Warning Counts

| Stage | WARNING log lines | Delta vs Phase 35 ceiling |
|---|---|---|
| Plan 01 baseline | 191 | 0 |
| Plan 02 post-edit | 191 | 0 |
| Plan 03 post-DE-edit | 191 | 0 |
| Plan 03 post-EN-edit | 191 | 0 |
| **Plan 04 post-DE-edit** | **191** | **0** |
| **Plan 04 post-EN-edit** | **191** | **0** |
| **Phase 35 ceiling (D-09)** | **191** | — |

D-09 gate SATISFIED: zero new warnings added by Plan 04 in either language, no warnings reference `tournament-quick-reference` or `scoreboard-guide`.

## Bilingual Parity Checks (all passed)

- **Anchor parity:** `diff` of `<a id="...">` markers between DE and EN files is empty (anchors `#before`, `#during`, `#after`, `#scoreboard-shortcuts`)
- **Table row parity:** 16 = 16 (DE = EN) under the scoreboard-shortcuts section
- **F-NN ref parity:** both files carry `<!-- ref: F-09 -->`, `<!-- ref: F-12 -->`, `<!-- ref: F-14 -->`, `<!-- ref: F-19 -->` (Plan 03 content untouched — verified)
- **Task-list parity:** 21 task-list items per file (Plan 03 Before/During/After totals — verified no regression)
- **ASCII strip source:** DE strip byte-identical to `scoreboard-guide.de.md:228`; EN strip byte-identical to `scoreboard-guide.en.md:227`

## Plan 03 Content Non-Regression Verification

Confirmed via grep that Plan 03's Before/During/After content is untouched:

- All 4 F-NN forward-reference callouts still present in both files (F-09, F-12, F-14, F-19)
- Task-list item count still 21 per file (10 Before + 6 During + 5 After)
- Admonition titles ("Endgültiger Klick", "Welchen Plan wählen?", "Englische Feldbezeichnungen", "Warten, nicht erneut klicken" / "Irreversible click", "Which plan to pick?", "English field labels", "Wait — do not re-click") still present

T-35-14 threat (untouched Plan 03 sections) mitigated by scoped Edit replacements targeting only the scoreboard-shortcuts placeholder string.

## Task Commits

1. **Task 1 (carambus_master):** `e7f5fffc` — `docs(35-04): fill DE scoreboard-shortcuts with table + verbatim ASCII strip`
2. **Task 2 (carambus_master):** `3d6e8532` — `docs(35-04): fill EN scoreboard-shortcuts with table + verbatim ASCII strip`

carambus_api-side SUMMARY + STATE + ROADMAP + BASELINE update lands in a follow-up metadata commit.

## Files Created/Modified

- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md` (modified, +24/-1) — DE shortcut table + verbatim ASCII strip + fragment-less link
- `/Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md` (modified, +24/-1) — EN mirror
- `.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt` (modified, +6 lines) — post_plan_04_de + post_plan_04_en metrics

## Decisions Made

- **Fragment-less link (D-03b deviation):** As documented above — no `#keyboard-shortcuts` anchor exists in bilingual source, discretionary fragment-less link chosen.
- **Table-first, strip-second ordering:** The markdown table is the primary reference (scannable during actual gameplay); the ASCII strip is the visual reinforcement at the bottom, matching how it appears on the actual scoreboard. This ordering matches volunteer usage: look up the action in the table, confirm the button position from the strip.
- **Introductory sentence before ASCII strip:** Added a one-liner ("Auf dem Scoreboard sehen Sie unten diese Button-Leiste (verbatim aus der Scoreboard-Anleitung):" / "On the scoreboard you see this button row at the bottom (verbatim from the Scoreboard Guide):") to contextualize the strip as a verbatim reproduction. Avoids confusion about why the same content appears twice (once in table, once as strip).
- **Ctrl+Z undo row included (D-03 optional):** D-03 left Ctrl+Z undo as planner discretion. Included because the F-nn findings in Plan 03 reference corrections/undo scenarios, so the undo shortcut adds real value for a day-of volunteer checklist.
- **Timer control `B` → `Down`:** Derived from scoreboard-guide.de.md §lines 629-632 (keyboard reference — B enters timer area, Down activates). Added because D-03 explicitly lists "pause/resume timer" in the canonical shortcut set.

## Deviations from Plan

**1. [D-03b / Planner note] Fragment-less link instead of `#keyboard-shortcuts`**
- **Found during:** Plan 04 authoring (not during execution — noted in plan §Objective §Planner note)
- **Issue:** CONTEXT.md §D-03b cited `[Scoreboard Guide](../players/scoreboard-guide.md#keyboard-shortcuts)` but no such anchor exists in either language file. DE source uses `## Tastenbelegung` (`#tastenbelegung`), EN uses `## Key Bindings` (`#key-bindings`).
- **Fix:** Linked to the scoreboard-guide page with no fragment. This avoids bilingual parity break + strict-build warning risk.
- **Authority:** D-05b ("planner decides item-by-item"), D-09 ("treat deep-link that doesn't resolve as blocking defect")
- **Files modified:** both `tournament-quick-reference.{de,en}.md`
- **Commit:** `e7f5fffc` (DE) and `3d6e8532` (EN)

Otherwise plan executed exactly as written. Both tasks completed in order; all automated verify checks and acceptance criteria passed on first run.

## Issues Encountered

None. Both Edit operations applied successfully on the first try (after the PreToolUse read-before-edit reminder hook confirmed the files had been read earlier in the session). Both mkdocs strict runs returned 191 WARNING lines. Both atomic commits succeeded.

## Known Stubs

None. Phase 35 content is now 100% authored. Plan 05 will perform final validation — no content work remains.

## Known DRY Follow-Up

**If `docs/players/scoreboard-guide.de.md:228` or `scoreboard-guide.en.md:227` is ever edited (reordered, renamed, or rephrased), the corresponding `tournament-quick-reference.{de,en}.md` scoreboard strip drifts** — it is a verbatim copy, not a dynamic include. Mitigation options for future maintenance:

1. **Manual:** When editing scoreboard-guide, also update the tournament-quick-reference strip.
2. **Grep gate:** Add a CI check that the `grep -Fxq` verification passes on both language pairs.
3. **mkdocs macros plugin (Phase 37+?):** Convert the strip to a `{% include %}` directive so both locations render from a single source file.

This follow-up is explicitly documented in the threat register as T-35-11 ("Tampering (DRY drift)") with disposition "mitigated by design" because the grep-based verification catches drift at plan-authoring time. Runtime drift between releases is a known, accepted gap — addressed in Plan 05 validation.

## Threat Model Verification

- **T-35-11 (Tampering / DRY drift in ASCII keycap strip):** Mitigated at authoring time. Both strips verified via `grep -Fxq` against their source-of-truth line. Runtime drift is an accepted follow-up (documented above).
- **T-35-12 (Information Disclosure in shortcut table):** Mitigated by design. All content is already public in scoreboard-guide.
- **T-35-13 (Spoofing / broken link):** Mitigated. Link targets `scoreboard-guide.md` with no fragment; page existence confirmed via Task 1 read-first step. No strict-build warning triggered.
- **T-35-14 (Supply chain / new image assets):** Mitigated. `git status docs/managers/` confirmed no new PNG/SVG files added. ASCII-only approach holds per D-03a.

## User Setup Required

None — no external service configuration required. All work is documentation content.

## Next Phase Readiness

- **Plan 35-05 (final validation) is FULLY UNBLOCKED.** All content sections (Before/During/After from Plan 03; scoreboard-shortcuts from Plan 04) are now complete in both languages. Plan 05 will run final bilingual parity, mkdocs strict, print-preview, and anchor-existence checks.
- **D-09 ceiling preserved:** 191 WARNING log lines remains the ceiling. Phase 35's cumulative delta is 0.
- **Phase 35 completion path:** Only Plan 05 (validation-only, no content edits) stands between now and Phase 35 completion.
- **Phase 36 forward-reference hook unchanged:** The 4 `<!-- ref: F-NN -->` callouts from Plan 03 are still the grep targets for Phase 36.

## Self-Check: PASSED

- Files verified on disk:
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.de.md (14-row shortcut table, verbatim DE ASCII strip, fragment-less link, Plan 03 content intact)
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master/docs/managers/tournament-quick-reference.en.md (14-row shortcut table, verbatim EN ASCII strip, fragment-less link, Plan 03 content intact)
  - FOUND: /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/.planning/phases/35-printable-quick-reference-card/35-01-BASELINE.txt (post_plan_04_de + post_plan_04_en recorded)
- Commits verified in git history (carambus_master):
  - FOUND: e7f5fffc (Task 1 — DE file)
  - FOUND: 3d6e8532 (Task 2 — EN file)
- All acceptance criteria passed: ASCII strips byte-identical, table headers present, placeholders removed, F-NN refs untouched, anchor parity preserved, mkdocs strict delta 0

---

*Phase: 35-printable-quick-reference-card*
*Completed: 2026-04-13*
