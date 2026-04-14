---
phase: 36A
plan: 05
type: execute
wave: 5
depends_on: [36A-04]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-02
  - DOC-ACC-04
  - DOC-ACC-06
must_haves:
  truths:
    - "TS-1 (PDF upload) recipe no longer claims ClubCloud is more reliable than PDF; honest framing"
    - "TS-2 (Player not in CC) recipe is rewritten as 'sync before deadline / Nachmeldung' edge case"
    - "TS-3 (Wrong mode) recipe removes fictional 'Modus ändern' button; points to Reset link"
    - "TS-4 (Tournament already started) recipe is completely rewritten — no DB-Admin recovery; honest fallback to Trainingsmodus + paper protocol"
    - "6 new troubleshooting recipes added (Endrangliste fehlt, CSV-Upload, Spieler-Rückzug, English labels, Nachstoß vergessen, Shootout)"
    - "'Mehr zur Technik' section is completely removed (lines 263-268 in original DE file)"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "Block-7 troubleshooting rewrite + Mehr-zur-Technik removal (lines 222-268)"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored Block-7 changes"
  key_links:
    - from: "ts-already-started"
      to: "glossary-system (Trainingsmodus)"
      via: "fallback recipe pointer"
      pattern: "Trainingsmodus|Training mode"
---

<objective>
Apply Block 7 corrections (F-36-51 through F-36-58) to both files: rewrite the 4 existing troubleshooting recipes (TS-1 through TS-4), add 6 new recipes for previously-uncovered failure modes, and completely remove the "Mehr zur Technik" / "More on the architecture" section.

Purpose: The existing troubleshooting recipes contain fictional UI elements (TS-3 "Modus ändern" button), false recovery paths (TS-4 DB-Admin), and unfair PDF-bashing (TS-1). The new recipes cover the real failures that volunteers encounter (Endrangliste manuell, CSV-Upload, Shootout, etc.). DOC-ACC-04 (new troubleshooting recipes) and DOC-ACC-06 (Mehr zur Technik removed) hinge on this plan.

Output: DE + EN troubleshooting sections rewritten and "Mehr zur Technik" removed.
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
  <name>Task 1: Rewrite Problembehebung + remove Mehr-zur-Technik in DE file</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (current state — Problembehebung section + Mehr zur Technik section, find by anchors `troubleshooting` and `architecture`)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 888-1015 (Block 7 findings F-36-51..F-36-58)
  </read_first>
  <action>
**Re-read the current Problembehebung region first** (anchor `troubleshooting` through end-of-file).

> **Note for executor:** This plan uses `***` inside fenced code blocks where the actual docs file uses `---` as a Markdown horizontal-rule separator. Both `---` and `***` render identically in mkdocs. When applying these edits to `tournament-management.{de,en}.md`, you may use whichever is consistent with the surrounding docs (the existing files use `---`).

**Edit 1 — Replace TS-1 ("Einladungs-PDF konnte nicht hochgeladen werden") — F-36-51**

OLD:
```
<a id="ts-invitation-upload"></a>
### Einladungs-PDF konnte nicht hochgeladen werden

**Problem:** Der Upload-Dialog in Schritt 3 zeigt einen Fehler, dreht sich im Kreis (unendlicher Spinner) oder die PDF-Datei wird hochgeladen, aber die Setzliste bleibt leer.

**Ursache:** Der PDF-Parser von Carambus kann bestimmte NBV- und DBU-Druckvorlagen nicht zuverlässig auslesen — besonders wenn die PDF-Datei gescannt (kein maschinenlesbarer Text), zu niedrig aufgelöst oder mit einem nicht-standardisierten Seitenformat erstellt wurde. OCR-Fehler sind häufig bei Einladungen, die als Bild-Scan vorliegen.

**Lösung:** Nutzen Sie direkt die **ClubCloud-Meldeliste als Quelle** — das ist die „Alternative" in Schritt 3. Klicken Sie auf „ClubCloud-Meldeliste verwenden", um die Teilnehmer direkt aus dem ClubCloud-Sync zu übernehmen. Ergänzen Sie anschließend in [Schritt 4](#step-4-participants) ggf. fehlende Spieler über ihre DBU-Nummer. Die ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger als der PDF-Upload.
```

NEW:
```
<a id="ts-invitation-upload"></a>
### Einladungs-PDF konnte nicht hochgeladen werden

**Problem:** Der Upload-Dialog zeigt einen Fehler, dreht sich im Kreis (unendlicher Spinner) oder die PDF-Datei wird hochgeladen, aber die Setzliste bleibt leer.

**Ursache:** Der PDF-Parser von Carambus erwartet das vom Landessportwart verwendete Standard-Template. Wenn das Template abweicht (gescanntes PDF ohne maschinenlesbaren Text, niedrige Auflösung, ungewöhnliches Seitenformat), kann der Parser die Setzliste nicht extrahieren. Im Normalbetrieb funktioniert der PDF-Upload zuverlässig, weil das Standard-Template wiederverwendet wird.

**Lösung:** Wechseln Sie auf die **ClubCloud-Meldeliste als Backup-Quelle**. Sie ist nicht weniger zuverlässig als der PDF-Upload — sie ist eine gleichwertige Alternative für den Sonderfall, dass der PDF-Parser scheitert. Den vollen Ablauf finden Sie im Anhang [Einladung fehlt](#appendix-no-invitation), der die Setzliste-Erzeugung aus den Carambus-Ranglisten beschreibt.
```

**Edit 2 — Replace TS-2 ("Spieler nicht in der ClubCloud-Meldeliste") — F-36-52**

OLD:
```
<a id="ts-player-not-in-cc"></a>
### Spieler nicht in der ClubCloud-Meldeliste
... (full existing block)
```

NEW:
```
<a id="ts-player-not-in-cc"></a>
### Spieler fehlen in der ClubCloud-Meldeliste

**Problem:** Nach dem ClubCloud-Sync wurden weniger Spieler geladen als erwartet. Der Wizard zeigt „Weiter zu Schritt 3 mit diesen N Spielern" mit einem grünen Button, obwohl N zu niedrig ist.

**Ursache:** Im Normalbetrieb sollte das nicht vorkommen — die Einladung und die ClubCloud-Meldeliste stellen denselben Meldeschluss-Snapshot dar. Es gibt drei realistische Auslöser:

1. **Sync wurde vor dem Meldeschluss durchgeführt** — Carambus hat die ClubCloud-Daten zu früh übernommen und kennt Spätanmelder noch nicht. Lösung: Den Sync nach dem Meldeschluss erneut auslösen.
2. **Spieler wird am Turniertag nachgemeldet** — siehe [On-site-Nachmeldung](#appendix-nachmeldung).
3. **Spieler war von Anfang an nicht gemeldet** — sie tauchen daher korrekterweise nicht auf, und sind kein Carambus-Bug.

**Lösung:** Klären Sie zuerst, welcher der drei Fälle vorliegt. Wenn ein echter Spieler fehlt, fügen Sie ihn in [Schritt 4](#step-4-participants) per DBU-Nummer hinzu. Wenn die ClubCloud-Daten unvollständig sind, lassen Sie sie vom Club-Sportwart in der ClubCloud korrigieren und führen den Sync erneut aus.
```

**Edit 3 — Replace TS-3 ("Falscher Turniermodus gewählt") — F-36-53**

OLD: existing block.

NEW:
```
<a id="ts-wrong-mode"></a>
### Falscher Turniermodus gewählt

**Problem:** Sie haben in Schritt 6 auf eine Modus-Karte (z. B. T04, T05 oder `Default{n}`) geklickt und damit den falschen Plan aktiviert. Das Start-Formular hat sich bereits geöffnet.

**Ursache:** Die Modus-Auswahl wird in Carambus unmittelbar beim Klick angewendet — ohne Bestätigungsdialog (F-13).

**Lösung:** Solange das Turnier **noch nicht gestartet** ist (Schritt 9 noch nicht ausgeführt), benutzen Sie den Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der Turnierseite, um das Setup zurückzusetzen, und gehen Sie dann erneut bis zur Modus-Auswahl. Ein separater Button zum nachträglichen Wechseln des Turniermodus existiert in der aktuellen Carambus-UI nicht.

!!! warning "Reset bei laufendem Turnier ist gefährlich"
    Wenn das Turnier bereits gestartet wurde (`tournament_started`), zerstört
    der Reset alle bereits erfassten Spielergebnisse. Verwenden Sie den
    Reset-Link in diesem Zustand nur, wenn Sie das Turnier wirklich
    abbrechen wollen. Siehe [Turnier wurde bereits gestartet](#ts-already-started)
    für Alternativen.
```

**Edit 4 — Replace TS-4 ("Turnier wurde bereits gestartet") — F-36-54**

OLD: existing block (the DB-Admin recovery story).

NEW:
```
<a id="ts-already-started"></a>
### Turnier wurde bereits gestartet — und etwas läuft schief

**Problem:** Sie möchten Teilnehmer, Turniermodus oder Start-Parameter ändern, oder ein gravierendes Problem ist während des laufenden Turniers aufgetreten. Der Wizard zeigt bereits den Turnier-Monitor und die Detailseite zeigt „Turnier läuft".

**Ursache:** Das AASM-Event `start_tournament!` (ausgelöst in [Schritt 9](#step-9-start)) wechselt das Turnier in einen Zustand, in dem die Parameter nicht mehr nachträglich änderbar sind. Das ist eine **bewusste Designentscheidung**, um Datenkonsistenz bei laufenden Scoreboards zu gewährleisten, und kein Bug.

**Realität:** Es gibt **keinen** technischen Recovery-Pfad — auch nicht für einen Datenbank-Admin oder Entwickler. Die zu ändernden Datenstrukturen sind zu komplex.

**Lösung im Notfall:**

1. **UNDO einzelner Spiele** ist möglich — direkt am betroffenen Scoreboard.
2. **Reset des gesamten Turniers** ist möglich, zerstört aber alle bereits erfassten Spielergebnisse (siehe [Schritt 12 Reset-Warnung](#step-12-monitor)).
3. **Wenn beides nicht in Frage kommt:** Wechseln Sie auf die **herkömmliche Methode**: Spiele auf Papier protokollieren, Ergebnisse direkt in der ClubCloud erfassen. Die Scoreboards können Sie für die einzelnen Spiele im **[Trainingsmodus](#glossary-system)** weiterbenutzen (kein Turnier-Kontext, aber funktionierende Punkterfassung).

Eine Sicherheitsabfrage vor dem Reset bei laufendem Turnier sowie ein Parameter-Verifikationsdialog vor dem Start sind als Folge-Features für eine spätere Phase eingeplant — sie reduzieren das Risiko, dass dieser Notfall überhaupt eintritt.
```

**Edit 5 — Append 6 new troubleshooting recipes — F-36-58**

After the rewritten TS-4 block, append:

```
<a id="ts-endrangliste-missing"></a>
### Endrangliste fehlt nach Turnierende

**Problem:** Das Turnier ist abgeschlossen, aber Carambus zeigt keine berechnete Endrangliste mit Platzierungen.

**Ursache:** Carambus berechnet die **Turnier-Endrangliste derzeit nicht automatisch**. Diese Funktion ist als Folge-Feature für v7.1+ eingeplant.

**Lösung:** Pflegen Sie die Endrangliste **manuell in der ClubCloud**. Den Workflow finden Sie im Anhang [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual).

<a id="ts-csv-upload"></a>
### CSV-Upload in die ClubCloud funktioniert nicht

**Problem:** Sie haben am Ende des Turniers eine CSV-Datei mit den Ergebnissen, aber die ClubCloud nimmt sie nicht an oder wirft Validierungsfehler.

**Ursache:** Der CSV-Upload setzt voraus, dass die **Teilnehmerliste in der ClubCloud finalisiert** ist — wenn dort ein Spieler fehlt, der im CSV vorkommt, scheitert der Import. Die Teilnehmerliste-Finalisierung über die CC-API ist in Carambus aktuell nicht implementiert; sie muss manuell durch einen Club-Sportwart in der ClubCloud-Admin-Oberfläche erfolgen.

**Lösung:** Den vollen Ablauf inkl. der nötigen Berechtigungen finden Sie im Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload). Im Zweifel bitten Sie den Club-Sportwart Ihres Vereins, die Teilnehmerliste in der ClubCloud zuerst zu finalisieren.

<a id="ts-player-withdraws"></a>
### Spieler zieht während des Turniers zurück

**Problem:** Ein Spieler kann während des Turniers nicht weiterspielen (Krankheit, Notfall, Rückzug).

**Ursache:** Carambus unterstützt einen sauberen **Match-Abbruch / Spieler-Rückzug während des laufenden Turniers** in der aktuellen Version **nicht**. Die Funktion ist als mittelgroßes Folge-Feature für v7.1+ eingeplant.

**Lösung (Workaround):** Beenden Sie das laufende Spiel des Spielers am Scoreboard mit dem zuletzt erfassten Stand. Für die folgenden Runden behandeln Sie den ausgefallenen Spieler de-facto wie ein [Freilos](#glossary-system) — die Gegner bekommen die Partie ggf. außerhalb von Carambus zugeschrieben. Dokumentieren Sie den Vorgang manuell im Turnierprotokoll und in der ClubCloud.

<a id="ts-english-labels"></a>
### Englische Feldbezeichnungen im Start-Formular

**Problem:** Im Start-Formular (Schritt 7) erscheinen einige Parameter mit englischen oder unklaren Labels (z. B. *Tournament manager checks results before acceptance*, *Assign games as tables become available*).

**Ursache:** Fehlende oder defekte Einträge in den i18n-Dateien (`config/locales/de.yml`). Die Korrektur ist als UI-Feature für eine Folge-Phase eingeplant.

**Lösung (bis die i18n-Korrektur ausgerollt ist):** Nutzen Sie die folgende Übersetzungstabelle:

| Englisches Label | Deutsche Bedeutung |
|------------------|--------------------|
| Tournament manager checks results before acceptance | Manager bestätigt Ergebnisse vor Annahme (manuelle Rundenwechsel-Kontrolle) |
| Assign games as tables become available | Spiele zuweisen, sobald Tische frei werden |
| auto_upload_to_cc | Ergebnisse automatisch in ClubCloud hochladen |

Im Zweifel behalten Sie die Standardwerte bei und verifizieren Sie die Werte vor dem Klick auf „Starte den Turnier Monitor".

<a id="ts-nachstoss-forgotten"></a>
### Nachstoß am Scoreboard vergessen

**Problem:** In einer Karambol-Disziplin mit Nachstoß-Regel hat das Scoreboard das Spiel beendet, ohne dass der Nachstoß durchgeführt wurde.

**Ursache:** Bedienfehler am Scoreboard — die Nachstoß-Eingabe wird in der Praxis häufig vergessen.

**Lösung:** Wenn das Spiel im Scoreboard noch offen ist (vor Bestätigung „Endergebnis erfasst"), kann das Scoreboard-Personal den Nachstoß noch nachholen. Wenn das Ergebnis bereits bestätigt ist, gibt es **keinen sauberen Nachträglich-Korrigieren-Pfad** — protokollieren Sie die Korrektur manuell und tragen Sie den korrigierten Wert in die ClubCloud ein. Für die Zukunft: Beim nächsten Turnier das Scoreboard-Personal explizit auf die Nachstoß-Eingabe hinweisen.

<a id="ts-shootout-needed"></a>
### Stechen / Shootout nötig (KO-Turnier)

**Problem:** Bei einem KO-Turnier endet eine Partie unentschieden und es wäre ein Stechen erforderlich.

**Ursache:** Stechen / Shootout wird in der aktuellen Carambus-Version **überhaupt nicht unterstützt**. Diese Funktion ist als kritisches Feature für ein späteres Milestone (v7.1 oder v7.2) eingeplant.

**Lösung:** Führen Sie das Stechen **außerhalb von Carambus** durch — am Tisch auf Papier protokollieren — und tragen Sie das Endergebnis manuell in die ClubCloud ein. Der Carambus-Spielstand muss in solchen Fällen nicht weiter gepflegt werden, das Stechen ist außerhalb des Systems abgewickelt.
```

**Edit 6 — Remove the entire "Mehr zur Technik" section — F-36-57**

OLD (lines 263-268 in original file, now possibly different line numbers):
```
***

<a id="architecture"></a>
## Mehr zur Technik

Carambus ist ein verteiltes System aus mehreren Web-Diensten: Ein zentraler API-Server veröffentlicht Turniere und Spielerdaten ... Für die Durchführung eines Turniers nach dieser Anleitung müssen Sie das Innenleben nicht verstehen. Wenn Sie die obigen Schritte befolgt haben, wissen Sie alles, was Sie für einen reibungslosen Turniertag brauchen. Für weiterführende technische Details — Datenbankstruktur, ActionCable-Konfiguration, Deployment — lesen Sie die [Entwickler-Dokumentation](../developers/index.md).
```

NEW: delete the entire `---` separator + `<a id="architecture"></a>` + `## Mehr zur Technik` heading + the two paragraphs. Leave only a single optional pointer at the very end of the file:

```
***

*Für weiterführende technische Details siehe die [Entwickler-Dokumentation](../developers/index.md).*
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "ts-endrangliste-missing" docs/managers/tournament-management.de.md &amp;&amp; grep -c "ts-csv-upload" docs/managers/tournament-management.de.md &amp;&amp; grep -c "ts-shootout-needed" docs/managers/tournament-management.de.md &amp;&amp; grep -c "ts-player-withdraws" docs/managers/tournament-management.de.md &amp;&amp; grep -c "ts-english-labels" docs/managers/tournament-management.de.md &amp;&amp; grep -c "ts-nachstoss-forgotten" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Mehr zur Technik" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "## Mehr zur Technik" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Modus ändern" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Carambus-Admin mit Datenbankzugang" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - 6 new TS recipes exist (grep all six anchor IDs)
    - grep -F "Mehr zur Technik" returns 0 (section removed; pointer line is allowed but uses different wording)
    - grep -F "## Mehr zur Technik" returns 0 (heading removed)
    - grep -F "Modus ändern" returns 0 (fictional button removed from TS-3; the new TS-3 paraphrases the issue without using this literal phrase)
    - grep -F "Carambus-Admin mit Datenbankzugang" returns 0 (false recovery path removed from TS-4)
    - grep -F "ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger" returns 0 (PDF-bashing removed from TS-1)
    - grep "Trainingsmodus" returns ≥1 match in TS-4 (Notfall-Fallback documented)
    - grep "appendix-rangliste-manual" returns ≥2 matches (TS-endrangliste forward link)
  </acceptance_criteria>
  <done>All 4 existing TS recipes rewritten; 6 new TS recipes added; "Mehr zur Technik" section removed.</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Block 7 changes to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (current Troubleshooting + More-on-the-architecture sections)
    - docs/managers/tournament-management.de.md (after Task 1 — authoritative source)
  </read_first>
  <action>
Mirror Task 1 in EN. Translate each rewritten and new recipe into idiomatic English.

**Edit 1 — Replace TS-1 ("Invitation upload failed")**

NEW:
```
<a id="ts-invitation-upload"></a>
### Invitation upload failed

**Problem:** The upload dialog shows an error, spins indefinitely, or the PDF is uploaded but the seeding list remains empty.

**Cause:** The Carambus PDF parser expects the standard template the regional sports officer uses. If the template deviates (scanned PDF without machine-readable text, low resolution, unusual page format), the parser cannot extract the seeding list. In normal operation the PDF upload is reliable because the standard template is reused.

**Fix:** Switch to the **ClubCloud registration list as a backup source**. It is not less reliable than the PDF upload — it is a perfectly equivalent alternative for the special case where the PDF parser fails. The full flow is in the appendix [Invitation missing](#appendix-no-invitation), which describes seeding-list generation from Carambus rankings.
```

**Edit 2 — Replace TS-2 ("Player not in ClubCloud")**

NEW:
```
<a id="ts-player-not-in-cc"></a>
### Players missing from the ClubCloud registration list

**Problem:** After the ClubCloud sync, fewer players were loaded than expected. The wizard shows a green "Continue to Step 3 with these N players" button even though N is too low.

**Cause:** In normal operation this should not happen — the invitation and the ClubCloud registration list represent the same close-of-registration snapshot. Three realistic triggers:

1. **The sync ran before the close of registration** — Carambus took the ClubCloud data too early and does not yet know about late registrations. Fix: re-trigger the sync after the registration deadline.
2. **A player is registered late on tournament day** — see [Late registration on tournament day](#appendix-nachmeldung).
3. **The player was never registered at all** — they correctly do not appear and that is not a Carambus bug.

**Fix:** First clarify which of the three cases applies. If a real player is missing, add them in [Step 4](#step-4-participants) by DBU number. If the ClubCloud data is incomplete, ask your club sports officer to correct it in ClubCloud and run the sync again.
```

**Edit 3 — Replace TS-3 ("Wrong mode selected")**

NEW:
```
<a id="ts-wrong-mode"></a>
### Wrong mode selected

**Problem:** In Step 6 you clicked one of the mode cards (for example T04, T05, or `Default{n}`) and the wrong plan is now active. The start form has already opened.

**Cause:** Mode selection is applied immediately on click — there is no confirmation dialog (F-13).

**Fix:** As long as the tournament has **not yet been started** (Step 9 has not yet run), use the **"Reset tournament monitor"** link at the bottom of the tournament page to reset the setup and then go back through the wizard up to the mode selection again. A separate button that would switch the tournament mode afterwards does not exist in the current Carambus UI.

!!! warning "Reset is dangerous if the tournament is already running"
    If the tournament has already been started (`tournament_started`), the
    reset destroys all results recorded so far. Use the reset link in this
    state only if you really intend to abort the tournament. See
    [Tournament already started](#ts-already-started) for alternatives.
```

**Edit 4 — Replace TS-4 ("Tournament already started")**

NEW:
```
<a id="ts-already-started"></a>
### Tournament already started — and something is going wrong

**Problem:** You need to change participants, the tournament mode, or start parameters, or a serious problem has occurred during the running tournament. The wizard already shows the Tournament Monitor and the detail page shows "Tournament running".

**Cause:** The AASM event `start_tournament!` (triggered in [Step 9](#step-9-start)) moves the tournament into a state where the parameters can no longer be changed retroactively. This is a **deliberate design decision** to ensure data consistency with running scoreboards, not a bug.

**Reality:** There is **no** technical recovery path — not even for a database admin or developer. The data structures involved are too complex to safely modify mid-run.

**Emergency fix:**

1. **Undo for individual matches** is possible — directly at the affected scoreboard.
2. **Resetting the entire tournament** is possible, but destroys all results recorded so far (see [Step 12 reset warning](#step-12-monitor)).
3. **If neither option is acceptable:** Switch to the **traditional method**: record matches on paper, enter results directly into ClubCloud. You can keep using the scoreboards in **[training mode](#glossary-system)** for the individual matches (no tournament context, but working point capture).

A safety dialog before reset while a tournament is running, and a parameter verification dialog before start, are planned as follow-up features for a later phase — they reduce the risk of this emergency happening at all.
```

**Edit 5 — Append 6 new EN troubleshooting recipes**

```
<a id="ts-endrangliste-missing"></a>
### Final ranking missing after the tournament ends

**Problem:** The tournament is finished but Carambus does not show a calculated final ranking with positions.

**Cause:** Carambus does **not** calculate the final tournament ranking automatically. This function is planned as a follow-up feature for v7.1+.

**Fix:** Maintain the final ranking **manually in ClubCloud**. The workflow is in the appendix [Maintaining the final ranking in ClubCloud](#appendix-rangliste-manual).

<a id="ts-csv-upload"></a>
### CSV upload to ClubCloud does not work

**Problem:** At the end of the tournament you have a CSV file with the results, but ClubCloud does not accept it or returns validation errors.

**Cause:** The CSV upload requires the **participant list in ClubCloud to be finalised** — if a player who appears in the CSV is missing in ClubCloud, the import fails. Finalising the participant list via the CC API is currently not implemented in Carambus; it has to happen manually through a club sports officer in the ClubCloud admin interface.

**Fix:** The full flow including the required permissions is in the appendix [CSV upload in ClubCloud](#appendix-cc-csv-upload). When in doubt, ask your club sports officer to finalise the participant list in ClubCloud first.

<a id="ts-player-withdraws"></a>
### A player withdraws during the tournament

**Problem:** A player cannot continue during the tournament (illness, emergency, withdrawal).

**Cause:** Carambus does **not** support a clean **mid-tournament match abort / player withdrawal** in the current version. The function is planned as a medium-sized follow-up feature for v7.1+.

**Fix (workaround):** Close the affected player's current match at the scoreboard with the last recorded score. For the following rounds, treat the dropped player as a de-facto [bye](#glossary-system) — opponents are credited with the match outside Carambus if needed. Document the process manually in the tournament protocol and in ClubCloud.

<a id="ts-english-labels"></a>
### English field labels in the start form

**Problem:** Some parameters in the start form (Step 7) appear with English or unclear labels (for example *Tournament manager checks results before acceptance*, *Assign games as tables become available*).

**Cause:** Missing or broken entries in the i18n files (`config/locales/de.yml`). The fix is planned as a UI feature for a follow-up phase.

**Fix (until the i18n correction ships):** Use the following translation table:

| English label | German meaning |
|---------------|----------------|
| Tournament manager checks results before acceptance | Manager confirms results before acceptance (manual round-change control) |
| Assign games as tables become available | Assign matches as tables become free |
| auto_upload_to_cc | Upload results to ClubCloud automatically |

When in doubt, keep the defaults and verify the values before clicking "Start tournament monitor".

<a id="ts-nachstoss-forgotten"></a>
### Nachstoß forgotten at the scoreboard

**Problem:** In a carom discipline with the Nachstoß rule, the scoreboard has finished the match without the Nachstoß having been executed.

**Cause:** Operator error at the scoreboard — Nachstoß entry is frequently forgotten in practice.

**Fix:** If the match is still open in the scoreboard (before "Final result confirmed" has been clicked), the scoreboard helper can still record the Nachstoß. If the result has already been confirmed, there is **no clean retroactive correction path** — record the correction manually and enter the corrected value in ClubCloud. For the future: at the next tournament, brief the scoreboard helpers explicitly about Nachstoß entry.

<a id="ts-shootout-needed"></a>
### Playoff / shootout match needed (knock-out tournament)

**Problem:** In a knock-out tournament a match ends in a draw and a playoff would be required.

**Cause:** Playoff / shootout is **not supported at all** in the current Carambus version. This function is planned as a critical feature for a later milestone (v7.1 or v7.2).

**Fix:** Run the playoff **outside Carambus** — record it on paper at the table — and enter the final result manually in ClubCloud. The Carambus state does not need to be maintained for these cases; the playoff is settled outside the system.
```

**Edit 6 — Remove "More on the architecture" section**

OLD (existing):
```
***

<a id="architecture"></a>
## More on the architecture

Carambus is a distributed system of web services ... For further technical details — database structure, ActionCable configuration, deployment — read the [Developer Documentation](../developers/index.md).
```

NEW: delete entirely; replace with:
```
***

*For further technical details, see the [developer documentation](../developers/index.md).*
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "ts-endrangliste-missing" docs/managers/tournament-management.en.md &amp;&amp; grep -c "ts-csv-upload" docs/managers/tournament-management.en.md &amp;&amp; grep -c "ts-shootout-needed" docs/managers/tournament-management.en.md &amp;&amp; grep -c "ts-player-withdraws" docs/managers/tournament-management.en.md &amp;&amp; grep -c "ts-english-labels" docs/managers/tournament-management.en.md &amp;&amp; grep -c "ts-nachstoss-forgotten" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "## More on the architecture" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Change mode" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Carambus admin with database access" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "ClubCloud route is more reliable in practice" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - All 6 new EN ts-* anchors exist
    - grep -F "## More on the architecture" returns 0 (heading removed)
    - grep -F "Change mode" returns 0 (fictional button removed; the new TS-3 paraphrases the issue without using this literal phrase)
    - grep -F "Carambus admin with database access" returns 0
    - grep -F "ClubCloud route is more reliable in practice" returns 0 (PDF-bashing removed)
    - grep "training mode" returns ≥1 match in EN TS-4 (fallback documented)
  </acceptance_criteria>
  <done>EN troubleshooting + Mehr-zur-Technik changes mirror DE; all anchors parallel.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Both files have all 10 ts-* anchors (4 rewritten + 6 new)
for anchor in ts-invitation-upload ts-player-not-in-cc ts-wrong-mode ts-already-started ts-endrangliste-missing ts-csv-upload ts-player-withdraws ts-english-labels ts-nachstoss-forgotten ts-shootout-needed; do
  DE=$(grep -c "\"$anchor\"" docs/managers/tournament-management.de.md)
  EN=$(grep -c "\"$anchor\"" docs/managers/tournament-management.en.md)
  echo "$anchor: DE=$DE EN=$EN"
done
```
</verification>

<success_criteria>
- F-36-51 through F-36-58 are all addressed
- DOC-ACC-02 (factual corrections — TS-3 fictional button, TS-4 false recovery path)
- DOC-ACC-04 (new troubleshooting recipes — 6 new ones added)
- DOC-ACC-06 ("Mehr zur Technik" removed)
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-05-SUMMARY.md`.
</output>
</content>
</invoke>
