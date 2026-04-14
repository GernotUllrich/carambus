---
phase: 36A
plan: 07
type: execute
wave: 7
depends_on: [36A-06]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-01
  - DOC-ACC-02
  - DOC-ACC-03
  - DOC-ACC-04
  - DOC-ACC-05
  - DOC-ACC-06
must_haves:
  truths:
    - "mkdocs build --strict passes with zero new warnings over the Phase 35 baseline (191 WARNING log lines)"
    - "Coverage matrix shows every F-36-NN finding (01..58) is mapped to at least one prior plan in 36A-01 through 36A-06"
    - "All 7 phase success criteria pass via grep verification"
    - "All 6 DOC-ACC-NN requirements have at least one task addressing them"
    - "DE and EN files are in sync — same set of anchors, same set of glossary entries, same set of appendix sections"
    - "No broken internal markdown links (every #anchor reference resolves to an existing anchor in the same file)"
  artifacts:
    - path: ".planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md"
      provides: "Coverage matrix mapping every F-36-NN finding to the plan/task that addressed it"
  key_links:
    - from: "verification script"
      to: "all 6 DOC-ACC requirements"
      via: "automated grep + mkdocs strict build"
      pattern: "DOC-ACC-0[1-6]"
---

<objective>
Final verification plan for Phase 36A. Run mkdocs --strict build, generate a coverage matrix mapping every F-36-NN finding to its addressing plan/task, and verify all 7 phase success criteria with grep-based checks against both the DE and EN files.

Purpose: This is the DOC-ACC-* completion gate. Without this plan, we have no evidence that all 58 findings were actually addressed and no proof that the documentation still builds cleanly.

Output: 36A-COVERAGE.md artifact + verified mkdocs build + grep evidence captured in 36A-07-SUMMARY.md.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/REQUIREMENTS.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@docs/managers/tournament-management.de.md
@docs/managers/tournament-management.en.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Run mkdocs --strict and verify zero-delta warnings</name>
  <files>(verification only — no file modifications)</files>
  <read_first>
    - .planning/STATE.md (line 49 "Phase 35 D-09 baseline recorded: 191 mkdocs strict WARNING log lines")
    - docs/managers/tournament-management.de.md (final state after Plans 01-06)
    - docs/managers/tournament-management.en.md (final state after Plans 01-06)
  </read_first>
  <action>
Run the mkdocs strict build from the project root and capture the warning count for delta comparison against the Phase 35 baseline (191 WARNING log lines).

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
mkdocs build --strict 2>&1 | tee /tmp/36a-mkdocs-strict.log
WARN_COUNT=$(grep -c "WARNING" /tmp/36a-mkdocs-strict.log)
ERROR_COUNT=$(grep -c "ERROR" /tmp/36a-mkdocs-strict.log)
echo "MKDOCS STRICT BUILD: $WARN_COUNT warnings, $ERROR_COUNT errors"
echo "PHASE 35 BASELINE: 191 warnings"
echo "DELTA: $((WARN_COUNT - 191))"
```

**Interpretation:**

- **Pass (zero-delta):** `WARN_COUNT == 191` AND `ERROR_COUNT == 0` — Phase 36A docs build cleanly with no new warnings.
- **Pass (delta down):** `WARN_COUNT < 191` AND `ERROR_COUNT == 0` — improvements are welcome.
- **Fail (delta up):** `WARN_COUNT > 191` — investigate which new warnings the Phase-36A edits introduced (likely broken anchor links). Inspect the new warnings:
  ```bash
  grep "WARNING" /tmp/36a-mkdocs-strict.log | tail -20
  ```
  Common causes: typos in anchor IDs, links to anchors that don't exist, removed anchors that other docs still link to. Fix in the offending file and re-run until delta ≤ 0.
- **Fail (errors):** `ERROR_COUNT > 0` — the build outright fails. Read the error message and fix immediately.

If the build fails, do **not** mark this task done. Fix the underlying issue (in the appropriate file) and re-run.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; mkdocs build --strict 2>&amp;1 | tee /tmp/36a-mkdocs-strict.log &amp;&amp; WARN=$(grep -c "WARNING" /tmp/36a-mkdocs-strict.log) &amp;&amp; ERR=$(grep -c "ERROR" /tmp/36a-mkdocs-strict.log) &amp;&amp; test "$ERR" -eq 0 &amp;&amp; test "$WARN" -le 191 &amp;&amp; echo "PASS: $WARN warnings (baseline 191), $ERR errors"</automated>
  </verify>
  <acceptance_criteria>
    - mkdocs build exit code 0
    - WARNING count ≤ 191 (Phase 35 baseline; equal is the pass condition, less is welcome improvement)
    - ERROR count == 0
    - The final command outputs "PASS: ..."
  </acceptance_criteria>
  <done>mkdocs strict build passes with zero new warnings over Phase 35 baseline; log captured at /tmp/36a-mkdocs-strict.log.</done>
</task>

<task type="auto">
  <name>Task 2: Verify all 7 success criteria + 6 DOC-ACC requirements via grep matrix</name>
  <files>(verification only — produces COVERAGE artifact)</files>
  <read_first>
    - docs/managers/tournament-management.de.md (final state)
    - docs/managers/tournament-management.en.md (final state)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md (for the F-36-NN list)
    - .planning/REQUIREMENTS.md lines 31-40 (DOC-ACC-01..06 acceptance criteria)
  </read_first>
  <action>
Run the following grep-based verification matrix and capture the output in `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md`. Use Write tool to create the file with the actual results substituted in.

**Step 1 — Phase success criteria checks (each must PASS):**

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

DE=docs/managers/tournament-management.de.md
EN=docs/managers/tournament-management.en.md

# Success criterion 1: Begriffshierarchie (DOC-ACC-01)
grep -c "Meldeliste" $DE  # expect ≥4
grep -c "Teilnehmerliste" $DE  # expect ≥6
grep -c "Setzliste" $DE  # expect ≥4

# Success criterion 2: Factual corrections from blocks 1-7 (DOC-ACC-02)
# (covered indirectly by the failing-greps in plans 01-05; here we re-verify a few key removals)
! grep -F "tournament_seeding_finished" $DE  # AASM state name removed
! grep -F "DefaultS" $DE  # wrong plan name removed
! grep -F "Teilnehmerliste (Setzliste)" $DE  # false synonym removed
! grep -F "Schaltfläche „Ergebnisse nach ClubCloud übertragen" $DE  # fictional button removed
! grep -F "alle 4 Matches" $DE  # wrong claim removed
! grep -F "Carambus-Admin mit Datenbankzugang" $DE  # false recovery path removed
! grep -F "Bälle-Ziel (innings_goal)" $DE  # wrong merged glossary entry removed
! grep -F "ClubCloud-Datenbank bezogen" $DE  # wrong Rangliste source removed

# Success criterion 3: New glossary entries (DOC-ACC-03)
for term in "Meldeliste" "Teilnehmerliste" "Logischer Tisch" "Physikalischer Tisch" "TableMonitor" "Turnier-Monitor" "Trainingsmodus" "Freilos" "T-Plan vs. Default-Plan"; do
  grep -c "$term" $DE  # each ≥1
done

# Success criterion 4: New appendix sections (DOC-ACC-04)
for anchor in appendix-no-invitation appendix-missing-player appendix-nachmeldung appendix-cc-upload appendix-cc-csv-upload appendix-rangliste-manual; do
  grep -c "id=\"$anchor\"" $DE  # each == 1
done

# Success criterion 5: Walkthrough restructured for passive phases (DOC-ACC-05)
grep "keine aktive Rolle" $DE  # ≥1 — Step 11 honest about manager passivity
grep "Phasen" $DE  # ≥2 — phases-vs-actions reframing

# Success criterion 6: Mehr zur Technik removed (DOC-ACC-06)
! grep -F "## Mehr zur Technik" $DE
! grep -F "<a id=\"architecture\"" $DE

# Same checks on EN
# (translate German strings to English equivalents for the EN file)
grep -c "Meldeliste\|registration list" $EN  # ≥3
! grep -F "tournament_seeding_finished" $EN
! grep -F "DefaultS" $EN
! grep -F "## More on the architecture" $EN
for anchor in appendix-no-invitation appendix-missing-player appendix-nachmeldung appendix-cc-upload appendix-cc-csv-upload appendix-rangliste-manual; do
  grep -c "id=\"$anchor\"" $EN  # each == 1
done
```

**Step 2 — Build the F-36-NN coverage matrix:**

For each of the 58 findings F-36-01 through F-36-58, identify the plan/task that addressed it (from the `<read_first>` and `<action>` sections of Plans 36A-01 through 36A-06). Use the following mapping derived from the plan structure:

| Finding | Plan | Notes |
|---------|------|-------|
| F-36-01 | 36A-01 | Szenario rewording + appendix forward-links |
| F-36-02 | 36A-01 | Begriffshierarchie + Ausspielziele in Schritt 1 |
| F-36-03 | 36A-01 | Schritt 2 Navigationspfad |
| F-36-04 | 36A-01 | Schritt 2 caption ehrlich |
| F-36-05 | 36A-01 | Schritt 3 komplett umgeschrieben |
| F-36-06 | 36A-01 | Schritt 4 drei Einstiegspunkte |
| F-36-07 | 36A-01 | T04 Karambol-Turnierordnung Klammerzusatz |
| F-36-08 | 36A-01 | Spieler hinzufügen Klick |
| F-36-09 | 36A-01 | AASM-State-Name durch UI-Label ersetzt |
| F-36-10 | 36A-01 | Reset-Möglichkeit dokumentiert (Warning-Block neu) |
| F-36-11 | 36A-01 | Schritt 4/5 als Aktions-Links erklärt |
| F-36-12 | 36A-02 | Default{n} + variable Karten-Anzahl |
| F-36-13 | 36A-02 | Tip-Block "Welchen Plan?" entfernt |
| F-36-14 | 36A-02 | 7 essential parameters explicit |
| F-36-15 | 36A-01 (intro) + 36A-02 (Schritte 7+8 merge) | Meta-Hinweis-Box + Merge |
| F-36-16 | 36A-02 | "vor dem Start des Turniers" + Tooltip-Hinweis als Folge-Phase |
| F-36-17 | 36A-02 | Ballziel/Aufnahmebegrenzung getrennt |
| F-36-18 | 36A-02 | Wertebereich-Erklärung (durch F-36-17 abgedeckt) |
| F-36-19 | 36A-02 | Aufnahmebegrenzung-leerfeld-doku |
| F-36-20 | 36A-02 (Tier A) + 36A-05 (Troubleshooting recipe) | DE-Label fehlt |
| F-36-21 | 36A-02 | logische vs physikalische Tische |
| F-36-22 | 36A-02 | TableMonitor + Scoreboard-Verbindung nicht fest |
| F-36-23 | 36A-02 (Tier A) + 36A-06 (Anhang Tier C) | auto_upload_to_cc + CC-Upload-Anhang |
| F-36-24 | 36A-03 | Warning-Block ersetzt |
| F-36-25 | 36A-03 | AASM-Technik-Absatz raus |
| F-36-26 | 36A-03 | "einspielen" Fachterminus + Warmup-Parameter |
| F-36-27 | 36A-03 | "alle 4 Matches" → 2 Matches + 1 Freilos |
| F-36-28 | 36A-03 | Aktuelle-Spiele-Tabelle als Fallback markiert |
| F-36-29 | 36A-03 | Manuelle Rundenwechsel-Kontrolle als Sonderfall |
| F-36-30 | 36A-03 | Schritt 11 komplett neu — keine aktive Rolle |
| F-36-31 | 36A-03 | Browser-Tab-Oversight + Nachstoß-Hinweis in Schritt 12 |
| F-36-32 | 36A-03 | Reset-Sicherheitshinweis im Schritt 12 |
| F-36-33 | 36A-03 | manuelle Bestätigung erwähnt + Crossref |
| F-36-34 | 36A-03 (Doc) + 36A-06 (Anhang) | Endrangliste manuelle Pflege |
| F-36-35 | 36A-03 | Shootout-Limitation in Schritt 13 |
| F-36-36 | 36A-03 | "beim Finalisieren" → "sofort nach Spielende" |
| F-36-37 | 36A-03 | fiktiver "Übertragen"-Button entfernt |
| F-36-38 | 36A-06 | CC-CSV-Upload-Anhang |
| F-36-39 | 36A-04 | Glossar Ballziel/Aufnahmebegrenzung |
| F-36-40 | 36A-04 | Glossar Setzliste neu |
| F-36-41 | 36A-04 | Glossar Meldeliste + Teilnehmerliste neu |
| F-36-42 | 36A-04 | Glossar Default{n} |
| F-36-43 | 36A-04 | Glossar Scoreboard nicht fest |
| F-36-44 | 36A-04 | Glossar AASM-Status (Phase-36-Versprechen raus) |
| F-36-45 | 36A-04 | Glossar Rangliste Carambus-intern |
| F-36-46 | 36A-04 | Glossar Logischer/Physikalischer Tisch neu |
| F-36-47 | 36A-04 | Glossar TableMonitor neu |
| F-36-48 | 36A-04 | Glossar Turnier-Monitor neu |
| F-36-49 | 36A-04 | Glossar Freilos neu (+ Match-Abbruch als Folge-Phase) |
| F-36-50 | 36A-04 | T-Plan vs. Default-Plan (durch F-36-42 abgedeckt) |
| F-36-51 | 36A-05 | TS-1 PDF-Bashing entfernt |
| F-36-52 | 36A-05 | TS-2 Edge-Case neu gefasst |
| F-36-53 | 36A-05 | TS-3 fiktiver "Modus ändern"-Button entfernt |
| F-36-54 | 36A-05 | TS-4 DB-Admin-Recovery entfernt |
| F-36-55 | (out of scope — Phase 36b UI-07) | Parameter-Verifikationsdialog |
| F-36-56 | 36A-04 (Glossar) + 36A-05 (TS-4 fallback) | Trainingsmodus dokumentiert |
| F-36-57 | 36A-05 | "Mehr zur Technik" entfernt |
| F-36-58 | 36A-05 | 6 neue Troubleshooting-Rezepte |

**Step 3 — Write 36A-COVERAGE.md** with this matrix plus the actual grep results from Step 1, the mkdocs build delta from Task 1, and a final PASS/FAIL summary per success criterion.

**Step 4 — Verify there are no orphan F-36-NN findings** (findings not addressed by any plan): the only legitimate exception is F-36-55 (Parameter-Verifikationsdialog) which is documented as Phase 36b UI-07 in REQUIREMENTS.md. All 57 other findings must have a plan in the matrix.

**Step 5 — Anchor integrity check** — verify every internal `#anchor` reference in both files resolves to an actual anchor definition:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
for FILE in $DE $EN; do
  # Extract all anchor references and definitions
  REFS=$(grep -oE "#[a-z0-9-]+" "$FILE" | sort -u)
  DEFS=$(grep -oE 'id="[a-z0-9-]+"' "$FILE" | sed 's/id="//;s/"//' | sort -u)
  # Find references that have no definition
  for ref in $REFS; do
    anchor="${ref#\#}"
    if ! echo "$DEFS" | grep -qx "$anchor"; then
      # Some references are to other files — those are OK if the # is part of a path. Filter heuristically.
      echo "POSSIBLE BROKEN: $FILE references $ref (no matching id= in same file)"
    fi
  done
done | tee /tmp/36a-anchor-integrity.log
```

Inspect the log. Cross-document anchors (e.g. `single-tournament.md` references) are acceptable; same-file anchor references that are missing must be fixed. Common offenders to verify: `glossary-karambol`, `glossary-wizard`, `glossary-system`, `step-1-invitation` through `step-14-upload`, `appendix-*`, `ts-*`.

If any same-file anchor reference is missing, fix it in the appropriate plan output by adding the missing anchor or correcting the link target.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; test -f .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md &amp;&amp; grep -c "F-36-58" .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md &amp;&amp; grep -c "PASS" .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md &amp;&amp; ! grep -F "FAIL" .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md</automated>
  </verify>
  <acceptance_criteria>
    - 36A-COVERAGE.md exists in the phase directory
    - Coverage matrix lists all 58 F-36-NN findings (or 57 + explicit F-36-55 deferral note)
    - All 6 DOC-ACC-NN requirements have a PASS line
    - All 7 phase success criteria have a PASS line
    - No "FAIL" string in the coverage file
    - mkdocs build delta is documented (≤ 0 vs Phase 35 baseline of 191 warnings)
    - No same-file broken anchor references in either DE or EN
  </acceptance_criteria>
  <done>Coverage matrix written, all checks pass, mkdocs strict build green.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Final phase-level verification:
mkdocs build --strict 2>&1 | grep -c WARNING  # ≤ 191
test -f .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md
grep -c "F-36-" .planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md  # ≥ 58 (or 57+F-36-55-note)
```
</verification>

<success_criteria>
- All 7 phase success criteria from the planning context are verified PASS
- All 6 DOC-ACC-NN requirements are satisfied
- All 58 findings are accounted for in the coverage matrix (with F-36-55 explicitly deferred to Phase 36b)
- mkdocs --strict passes with zero new warnings over the Phase 35 baseline (191)
- No broken same-file anchor references in either DE or EN file
</success_criteria>

<output>
After completion, create:
- `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-COVERAGE.md` — coverage matrix (Task 2 main output)
- `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-07-SUMMARY.md` — final phase summary including mkdocs build log excerpts and the PASS/FAIL summary

These two artifacts together close Phase 36A.
</output>
