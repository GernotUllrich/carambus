---
phase: 36A
plan: 06
type: execute
wave: 6
depends_on: [36A-05]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-04
  - DOC-ACC-05
must_haves:
  truths:
    - "5 new appendix sections exist with the planned anchor IDs (#appendix-no-invitation, #appendix-missing-player, #appendix-nachmeldung, #appendix-cc-upload, #appendix-cc-csv-upload, #appendix-rangliste-manual)"
    - "Each appendix is a complete alternative flow / recipe — not just stub headings"
    - "ClubCloud-CSV-upload appendix is a first-pass version flagged as 'to be expanded in 36c with PREP-04'"
    - "All forward links from earlier plans (01-05) now resolve to existing appendix anchors"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "New '## Anhang' section with 6 sub-sections at end of file (after Problembehebung, before final pointer line)"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored '## Appendix' section"
  key_links:
    - from: "scenario, step-1-invitation, step-3-seeding-list, ts-invitation-upload"
      to: "appendix-no-invitation"
      via: "Sonderfall forward link"
      pattern: "appendix-no-invitation"
    - from: "step-7-start-form, step-14-upload, ts-csv-upload"
      to: "appendix-cc-upload, appendix-cc-csv-upload"
      via: "Upload-Modell forward link"
      pattern: "appendix-cc-upload"
---

<objective>
Add a new "Anhang" / "Appendix" section to both DE and EN files containing the 5 special-case flows and 1 manual-Rangliste recipe that earlier plans (01, 03, 05) forward-linked to. This plan closes all open `#appendix-*` references and satisfies DOC-ACC-04 (new appendix sections) and indirectly DOC-ACC-05 (walkthrough restructure honestly distinguishes manager-action from passive phases — the special-case flows live in the appendix instead of polluting the linear walkthrough).

The CC-upload appendix is a **first-pass version** based on what the SME info in F-36-23, F-36-37, F-36-38 already captured. It is explicitly marked as "to be expanded in Phase 36c via PREP-04" — Phase 36c depends on 36a, so PREP-04 is not available yet. We capture the known facts now and leave room for expansion.

Output: Both files have a new top-level section "Anhang" / "Appendix" added between the Problembehebung section and the final developer-doc pointer.
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
  <name>Task 1: Add Anhang section to tournament-management.de.md</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (current state — find end of Problembehebung section + the developer-doc pointer line at end)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 41-53 (F-36-01 appendix list), lines 138-155 (F-36-05 keine-Einladung), lines 462-495 (F-36-23 CC-upload), lines 696-712 (F-36-38 CC-CSV), lines 657-665 (F-36-34 Rangliste manual)
  </read_first>
  <action>
**Re-read the current file first** to find the exact location to insert the new Anhang section. It must come **after** the Problembehebung section and **before** the final `*Für weiterführende technische Details ...*` pointer line that Plan 36A-05 added.

> **Note for executor:** This plan uses `***` inside fenced code blocks where the actual docs file uses `---` as a Markdown horizontal-rule separator. Both render identically in mkdocs. When applying, use the variant consistent with the surrounding docs (the existing files use `---`).

Insert the following new section. Each appendix is a complete recipe with Problem / Vorgehen structure where applicable.

```
***

<a id="appendix"></a>
## Anhang: Spezialfälle und vertiefende Abläufe

Die folgenden Abschnitte beschreiben vollständige Alternativ-Abläufe und vertiefende Themen, die nicht in den linearen Walkthrough passen. Sie werden aus den entsprechenden Schritten und Troubleshooting-Rezepten verlinkt.

<a id="appendix-no-invitation"></a>
### Einladung fehlt — Setzliste ohne PDF erzeugen

**Wann:** Wenn Sie ausnahmsweise kein offizielles NBV-Einladungs-PDF erhalten haben (z. B. spontan organisiertes Vereinsturnier, internes Pokalturnier, vergessene Einladung des Sportwarts).

**Vorgehen:**

1. **Carambus öffnen** und das Turnier anlegen oder aus der ClubCloud synchronisieren wie in [Schritt 2](#step-2-load-clubcloud) beschrieben — auch ohne PDF läuft der ClubCloud-Sync, sofern das Turnier in der ClubCloud existiert.
2. **In Schritt 3 (Setzliste)** überspringen Sie den PDF-Upload-Pfad. Stattdessen übernehmen Sie die initiale Teilnehmerliste direkt aus der ClubCloud-Meldeliste — über den Link „→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)" im Einladungs-Hochladen-Formular (siehe [Schritt 4 Navigation](#step-4-participants), Eingangspunkt 3).
3. **In Schritt 4 (Teilnehmerliste)** klicken Sie auf **„Nach Ranking sortieren"**, um die Spieler nach den in Carambus gepflegten [Ranglisten](#glossary-system) zu ordnen. Diese Ordnung ersetzt die fehlende offizielle Setzliste.
4. **Manuell nachsortieren**, falls der Sportwart einen abweichenden Wunsch geäußert hat (z. B. titelverteidigender Spieler an Position 1).
5. **Abschließen** wie in [Schritt 5](#step-5-finish-seeding) — von dort läuft der Wizard normal weiter.

Hinweis: Diese Setzliste ist eine **Carambus-interne** und nicht offiziell. Bei NBV-relevanten Turnieren sollten Sie die Setzliste nachträglich von der zuständigen Sportwart-Person bestätigen lassen.

<a id="appendix-missing-player"></a>
### Spieler erscheint nicht zum Turnier

**Wann:** Ein in der Meldeliste aufgeführter Spieler erscheint nicht am Turniertag.

**Vorgehen:**

1. **Vor dem Turnierstart** (vor [Schritt 5 „Teilnehmerliste abschließen"](#step-5-finish-seeding)): Entfernen Sie den fehlenden Spieler in [Schritt 4](#step-4-participants) per „Spieler entfernen"-Aktion und prüfen Sie, ob die verbleibende Spielerzahl noch zum gewählten Turnierplan passt. Falls ein anderer Plan nötig wird, weist Carambus auf der Wizard-Seite einen neuen Vorschlag aus.
2. **Falls die Teilnehmerliste schon abgeschlossen ist**, aber das Turnier noch nicht gestartet wurde: Sie können das Setup über **„Zurücksetzen des Turnier-Monitors"** zurücksetzen und die Teilnehmerliste neu zusammenstellen. **Achtung:** Vor Schritt 9 ist Reset risikolos, danach nicht — siehe [Schritt 12 Reset-Warnung](#step-12-monitor).
3. **Wenn das Turnier bereits gestartet ist und der Spieler in einer noch nicht gespielten Runde steht**, gibt es keinen sauberen Pfad in der aktuellen Carambus-Version. Behandeln Sie den ausgefallenen Spieler de facto wie ein [Freilos](#glossary-system) — siehe [Spieler zieht während des Turniers zurück](#ts-player-withdraws).

**Vorbeugung:** Bestätigen Sie die Anwesenheit aller Spieler kurz vor [Schritt 5](#step-5-finish-seeding), nicht erst nach Turnierstart.

<a id="appendix-nachmeldung"></a>
### Spieler-Nachmeldung am Turniertag

**Wann:** Ein Spieler, der nicht in der ClubCloud-Meldeliste steht, möchte am Turniertag noch antreten.

**Vorgehen:**

1. **Klären Sie zuerst die Berechtigung:** Hat der Spieler eine gültige DBU-Lizenz? Erlaubt die Turnierordnung On-site-Nachmeldungen? Hat der Sportwart zugestimmt? Im Zweifel: Anruf beim Landessportwart.
2. **Vor Turnierstart** ist Nachmeldung in Carambus einfach: In [Schritt 4](#step-4-participants) tragen Sie die DBU-Nummer des nachzumeldenden Spielers in das Feld **„Spieler mit DBU-Nummer hinzufügen"** ein und klicken auf **„Spieler hinzufügen"**. Anschließend „Nach Ranking sortieren" oder per Drag-and-Drop nachsortieren.
3. **Eintragung in der ClubCloud:** Damit die Nachmeldung in die offizielle Statistik einfließt und der Endergebnis-Upload funktioniert, muss der Spieler **auch in der ClubCloud-Teilnehmerliste** ergänzt werden. Das kann nur ein **Club-Sportwart mit den entsprechenden Rechten** (siehe [Anhang ClubCloud-Upload](#appendix-cc-upload)). Wenn der Sportwart nicht vor Ort ist, müssen Sie ihn anrufen oder die Nachmeldung später nachpflegen lassen.
4. **Nach Turnierstart** ist Nachmeldung in Carambus aktuell **nicht sauber unterstützt** — der einzige Workaround ist das Zurücksetzen des Turnier-Monitors mit allen Konsequenzen.

<a id="appendix-cc-upload"></a>
### ClubCloud-Upload — zwei Wege

> **Hinweis:** Dieser Anhang ist eine erste Fassung auf Basis der bereits bekannten SME-Informationen. Eine vollständige Fassung (inkl. Screenshots der CC-Admin-Oberfläche, exakter Pfade und typischer Fehlermeldungen) ist als PREP-04 in Phase 36c vorgesehen und wird hier später ergänzt.

Carambus kennt zwei Wege, um Turnier-Ergebnisse in die ClubCloud zurückzuspielen — beide haben dieselbe Voraussetzung, aber unterschiedliche Workflows.

**Gemeinsame Voraussetzung:** Die **Teilnehmerliste muss in der ClubCloud finalisiert sein**. Das bedeutet: Jeder Spieler, der im Turnier antritt (auch [Nachmeldungen](#appendix-nachmeldung)), muss in der CC-Teilnehmerliste eingetragen sein, bevor irgendein Ergebnis hochgeladen werden kann. Die Finalisierung der Teilnehmerliste über die CC-API ist in Carambus **aktuell nicht implementiert** — sie muss manuell durch einen **Club-Sportwart** in der ClubCloud-Admin-Oberfläche erfolgen. Diese Berechtigung haben in der Regel nicht alle Vereinsmitglieder, sondern nur ausgewählte Funktionäre.

**Pfad 1: Einzelübertragung pro Spiel** (`auto_upload_to_cc` aktiviert)

- Jedes einzelne Ergebnis wird **sofort nach Match-Ende** an die ClubCloud übertragen.
- Technisch erfolgt das durch Formular-Emulation in der ClubCloud-Admin-Schnittstelle.
- **Voraussetzung:** Wie oben — die Teilnehmerliste in der CC muss bereits finalisiert sein, **bevor** das erste Spiel endet.
- **Vorteil:** Ergebnisse sind in nahezu Echtzeit in der ClubCloud sichtbar (z. B. für Live-Berichte des Verbands).
- **Aktivieren:** Im Start-Formular ([Schritt 7](#step-7-start-form)) die Checkbox **„Ergebnisse automatisch in ClubCloud hochladen"** (`auto_upload_to_cc`) setzen.

**Pfad 2: CSV-Batch-Upload am Ende** (`auto_upload_to_cc` deaktiviert oder Pfad 1 nicht möglich)

- Alle Ergebnisse werden während des Turniers nur lokal in Carambus erfasst.
- Am Ende des Turniers stellt Carambus eine **CSV-Datei** mit allen Spielergebnissen bereit.
- Die CSV wird per E-Mail an den Turnierleiter geschickt (oder steht zum Download bereit).
- Der Turnierleiter leitet sie an den Club-Sportwart weiter, der sie in die (jetzt finalisierte) ClubCloud-Teilnehmerliste importiert — das Detail-Vorgehen siehe [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload).
- **Vorteil gegenüber Pfad 1:** Der Sportwart kann die CC-Teilnehmerliste auch **nach** dem Turnier finalisieren — Pfad 2 ist robust gegen die Berechtigungs-Lücke.

**Berechtigungsproblem (offen):** Fehlende Spieler in der ClubCloud-Teilnehmerliste hinzufügen können nur **Club-Sportwarte**. Wenn keiner vor Ort ist, blockiert das Pfad 1 vollständig und Pfad 2 zumindest bis nach dem Turnier. Eine mögliche Lösung — die Hinterlegung von Club-Sportwart-Credentials in Carambus für genau diesen Delegations-Fall — ist als Folge-Feature für v7.1+ vorgesehen.

<a id="appendix-cc-csv-upload"></a>
### CSV-Upload in der ClubCloud (Pfad 2 im Detail)

> **Hinweis:** Dieser Anhang ist eine erste Fassung. Eine vollständige Schritt-für-Schritt-Anleitung mit Screenshots der CC-Admin-Oberfläche, exakten Menü-Pfaden und Liste der häufigsten Validierungsfehler ist als PREP-04 in Phase 36c vorgesehen. Bis dahin gilt:

**Wer:** Ein **Club-Sportwart** mit Schreibrechten auf die Teilnehmerliste und die Ergebnis-Tabelle in der ClubCloud.

**Voraussetzungen:** Die **Teilnehmerliste in der CC ist finalisiert** (siehe [ClubCloud-Upload — zwei Wege](#appendix-cc-upload)) und enthält jeden Spieler, der im CSV vorkommt — sonst scheitert der Import an einem Validierungsfehler.

**Wo in der ClubCloud:** In der ClubCloud-Admin-Oberfläche unter dem entsprechenden Turnier; die genaue Menü-Position variiert nach CC-Version. Bei Unsicherheit klären Sie mit dem Verbands-Sportwart.

**Häufige Fehlermeldungen (erste Liste, wird in PREP-04 ergänzt):**

- **„Spieler nicht gefunden"** — der Spieler ist im CSV, aber nicht in der CC-Teilnehmerliste. Lösung: Spieler in der CC-Teilnehmerliste ergänzen (Sportwart-Recht erforderlich) und CSV erneut importieren.
- **„Format fehlerhaft"** — die CSV entspricht nicht dem erwarteten CC-Format. Sehr selten, da Carambus die CSV in dem Format generiert, das der CC-Importer erwartet. Wenn doch: das genaue Format mit dem Verbands-Sportwart abstimmen.
- **„Doppelte Eintragung"** — ein Spieler wurde bereits per Pfad 1 (Einzelübertragung) hochgeladen und steht jetzt nochmal im CSV. Lösung: doppelten Eintrag in der CSV entfernen oder den Import explizit als „Update" konfigurieren.

<a id="appendix-rangliste-manual"></a>
### Endrangliste in der ClubCloud manuell pflegen

**Hintergrund:** Carambus berechnet die Turnier-Endrangliste aktuell **nicht automatisch** (siehe [Schritt 13](#step-13-finalize) und [Endrangliste fehlt nach Turnierende](#ts-endrangliste-missing)). Die Endrangliste muss daher manuell in der ClubCloud gepflegt werden.

**Wer:** Der Turnierleiter oder ein Club-Sportwart mit Schreibrechten auf die Ergebnis-Tabelle.

**Wann:** Nach dem letzten Spiel, sobald alle Ergebnisse erfasst sind und die Punktstände in Carambus oder am Scoreboard final sind.

**Vorgehen:**

1. **Sammeln Sie die Einzelergebnisse** — entweder aus dem Carambus-Turnier-Monitor (Übersichtsseite mit allen Spielen, Bällen, Aufnahmen, HS, GD), oder direkt von den Tisch-Scoreboards.
2. **Berechnen Sie die Platzierungen** nach den Regeln der jeweiligen Disziplin:
    - Anzahl gewonnener Partien (Hauptkriterium)
    - Bei Gleichstand: Generaldurchschnitt (GD)
    - Bei weiterem Gleichstand: Höchstserie (HS)
    - Disziplinabhängige Sonderregeln (z. B. direkter Vergleich)
    - Bei KO-Turnieren mit Stechen-Bedarf siehe [Stechen / Shootout nötig](#ts-shootout-needed)
3. **Tragen Sie die finalen Platzierungen in die ClubCloud ein.** Die genaue Stelle in der CC-Admin-Oberfläche variiert nach CC-Version.
4. **Konsistenzprüfung:** Vergleichen Sie die Carambus-Spielergebnisse mit den in der CC eingetragenen — falls Pfad 1 (Einzelübertragung) genutzt wurde, sollten beide identisch sein.

**Hinweis:** Eine **automatische Berechnung der Endrangliste in Carambus** (mit allen Sonderfällen) ist als großes Feature für v7.1+ eingeplant. Wenn das Feature ausgerollt ist, entfällt dieser Anhang.
```

After inserting this Anhang section, ensure the final `*Für weiterführende technische Details ...*` pointer line from Plan 36A-05 is still the very last line of the file.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "appendix-no-invitation" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-missing-player" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-nachmeldung" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-cc-csv-upload" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-rangliste-manual" docs/managers/tournament-management.de.md &amp;&amp; grep -c "## Anhang" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - Each of the 6 appendix anchor IDs appears ≥2 times (once in the anchor definition, once+ as forward-link target from earlier sections)
    - grep "## Anhang" returns ≥1 match (top-level section heading exists)
    - grep "to be expanded in 36c" or "PREP-04" returns ≥2 matches (CC-upload and CC-CSV appendices flag their first-pass status)
    - grep "Club-Sportwart" returns ≥3 matches (CC permission story documented)
    - File ends with the `*Für weiterführende technische Details ...*` pointer line from Plan 05
  </acceptance_criteria>
  <done>Anhang section inserted with 6 sub-sections; all appendix anchors are now defined; all forward links from Plans 01-05 resolve.</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Anhang section to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (current state — find end of Troubleshooting + the developer-doc pointer line)
    - docs/managers/tournament-management.de.md (after Task 1 — authoritative source for the Anhang content)
  </read_first>
  <action>
Insert an "Appendix" section into the EN file mirroring the DE Anhang. Place it between the Troubleshooting section and the final `*For further technical details ...*` pointer line that Plan 05 added.

```
***

<a id="appendix"></a>
## Appendix: special cases and deeper-dive flows

The following sections describe complete alternative flows and topics that do not fit the linear walkthrough. They are linked to from the corresponding steps and troubleshooting recipes.

<a id="appendix-no-invitation"></a>
### Invitation missing — generating a seeding list without a PDF

**When:** When you have exceptionally not received an official NBV invitation PDF (for example a spontaneous club tournament, an internal cup, or a forgotten invitation from the sports officer).

**Procedure:**

1. **Open Carambus** and create the tournament or sync it from ClubCloud as described in [Step 2](#step-2-load-clubcloud) — the ClubCloud sync runs even without a PDF, as long as the tournament exists in ClubCloud.
2. **In Step 3 (seeding list)** skip the PDF upload path. Instead, take over the initial participant list directly from the ClubCloud registration list — via the link "→ With registration list to Step 3 (sorted by ranking)" inside the upload-invitation form (see [Step 4 navigation](#step-4-participants), entry point 3).
3. **In Step 4 (participant list)** click **"Sort by ranking"** to order players by the [rankings](#glossary-system) maintained inside Carambus. This order replaces the missing official seeding list.
4. **Manually re-sort** if the sports officer asked for a deviation (for example the title-defending player at position 1).
5. **Close** as in [Step 5](#step-5-finish-seeding) — the wizard then continues normally.

Note: this seeding list is **Carambus-internal** and not official. For NBV-relevant tournaments you should have the seeding list confirmed afterwards by the responsible sports officer.

<a id="appendix-missing-player"></a>
### A registered player does not show up

**When:** A player listed on the registration list does not appear on tournament day.

**Procedure:**

1. **Before the tournament starts** (before [Step 5 "Close participant list"](#step-5-finish-seeding)): remove the missing player in [Step 4](#step-4-participants) using the "Remove player" action and check whether the remaining player count still fits the chosen tournament plan. If a different plan is needed, Carambus shows a new suggestion on the wizard page.
2. **If the participant list is already closed** but the tournament is not yet started: you can reset the setup via **"Reset tournament monitor"** and rebuild the participant list. **Note:** before Step 9 the reset is risk-free, after that it is not — see [Step 12 reset warning](#step-12-monitor).
3. **If the tournament is already started and the player is in a round that has not yet been played**, there is no clean path in the current Carambus version. Treat the dropped player de facto as a [bye](#glossary-system) — see [Player withdraws during the tournament](#ts-player-withdraws).

**Prevention:** Confirm the presence of all players just before [Step 5](#step-5-finish-seeding), not after the tournament starts.

<a id="appendix-nachmeldung"></a>
### Late registration on tournament day

**When:** A player who is not on the ClubCloud registration list wants to play on tournament day.

**Procedure:**

1. **First clarify eligibility:** Does the player have a valid DBU licence? Does the tournament regulation allow on-site late registrations? Has the sports officer agreed? When in doubt: call the regional sports officer.
2. **Before tournament start** late registration is easy in Carambus: in [Step 4](#step-4-participants) enter the late player's DBU number in the **"Add player by DBU number"** field and click **"Add player"**. Then "Sort by ranking" or drag-and-drop into the right place.
3. **Entry in ClubCloud:** For the late registration to appear in the official statistics and for the result upload to work, the player must **also be added to the ClubCloud participant list**. This requires a **club sports officer with the appropriate permissions** (see [Appendix ClubCloud upload](#appendix-cc-upload)). If the sports officer is not on site, you have to call them or have the late registration recorded later.
4. **After tournament start** late registration is currently **not properly supported** in Carambus — the only workaround is resetting the tournament monitor with all consequences.

<a id="appendix-cc-upload"></a>
### ClubCloud upload — two paths

> **Note:** This appendix is a first-pass version based on the SME information already captured. A complete version (including screenshots of the CC admin interface, exact menu paths, and a full list of typical validation errors) is planned as PREP-04 in Phase 36c and will be added here later.

Carambus knows two ways to push tournament results back to ClubCloud — both have the same prerequisite but different workflows.

**Common prerequisite:** The **participant list in ClubCloud must be finalised**. That means: every player who participates in the tournament (including [late registrations](#appendix-nachmeldung)) must be in the CC participant list before any result can be uploaded. Finalising the participant list via the CC API is **currently not implemented** in Carambus — it has to be done manually by a **club sports officer** in the ClubCloud admin interface. This permission is typically restricted to selected officers, not every club member.

**Path 1: Per-match upload** (`auto_upload_to_cc` enabled)

- Every individual result is uploaded to ClubCloud **immediately when the match ends**.
- Technically this happens through form emulation in the ClubCloud admin interface.
- **Prerequisite:** as above — the CC participant list must already be finalised **before** the first match ends.
- **Advantage:** results are visible in ClubCloud in near real time (for example for live federation reports).
- **Activate:** in the start form ([Step 7](#step-7-start-form)) tick the checkbox **"Upload results to ClubCloud automatically"** (`auto_upload_to_cc`).

**Path 2: CSV batch upload at the end** (`auto_upload_to_cc` disabled or path 1 not possible)

- All results are recorded only locally in Carambus during the tournament.
- At the end of the tournament Carambus produces a **CSV file** with all match results.
- The CSV is sent by email to the tournament director (or made available for download).
- The tournament director forwards it to the club sports officer who imports it into the (now finalised) ClubCloud participant list — for the detailed procedure see [CSV upload in ClubCloud](#appendix-cc-csv-upload).
- **Advantage over path 1:** the sports officer can finalise the CC participant list **after** the tournament — path 2 is robust against the permission gap.

**Permission problem (open):** Adding missing players to the ClubCloud participant list is restricted to **club sports officers**. If none is on site, this fully blocks path 1 and at least delays path 2 until after the tournament. A possible solution — storing club sports officer credentials in Carambus exactly for this delegation case — is planned as a follow-up feature for v7.1+.

<a id="appendix-cc-csv-upload"></a>
### CSV upload in ClubCloud (path 2 in detail)

> **Note:** This appendix is a first-pass version. A complete step-by-step guide with CC admin interface screenshots, exact menu paths, and a full list of common validation errors is planned as PREP-04 in Phase 36c. Until then:

**Who:** A **club sports officer** with write permissions on the participant list and the result table in ClubCloud.

**Prerequisites:** The **participant list in ClubCloud is finalised** (see [ClubCloud upload — two paths](#appendix-cc-upload)) and contains every player who appears in the CSV — otherwise the import fails with a validation error.

**Where in ClubCloud:** In the ClubCloud admin interface under the corresponding tournament; the exact menu position varies by CC version. When in doubt, clarify with the federation sports officer.

**Common error messages (first list, to be expanded in PREP-04):**

- **"Player not found"** — the player is in the CSV but not in the CC participant list. Fix: add the player to the CC participant list (sports officer permission required) and re-import the CSV.
- **"Format error"** — the CSV does not match the expected CC format. Very rare, since Carambus generates the CSV in the format the CC importer expects. If it does happen: clarify the exact format with the federation sports officer.
- **"Duplicate entry"** — a player was already uploaded via path 1 (per-match) and now appears in the CSV as well. Fix: remove the duplicate entry from the CSV or configure the import explicitly as "update".

<a id="appendix-rangliste-manual"></a>
### Maintaining the final ranking in ClubCloud

**Background:** Carambus does **not** currently calculate the tournament final ranking automatically (see [Step 13](#step-13-finalize) and [Final ranking missing after the tournament ends](#ts-endrangliste-missing)). The final ranking therefore has to be maintained manually in ClubCloud.

**Who:** The tournament director or a club sports officer with write permissions on the result table.

**When:** After the last match, once all results are recorded and the scores in Carambus or at the scoreboards are final.

**Procedure:**

1. **Collect the individual results** — either from the Carambus Tournament Monitor (overview page with all matches, balls, innings, HS, GD), or directly from the table scoreboards.
2. **Calculate the positions** according to the rules of the discipline:
    - Number of matches won (primary criterion)
    - On a tie: general average (GD)
    - On a further tie: high run (HS)
    - Discipline-specific tie-breakers (for example head-to-head)
    - For knock-out tournaments needing a playoff, see [Playoff / shootout match needed](#ts-shootout-needed)
3. **Enter the final positions in ClubCloud.** The exact location in the CC admin interface varies by CC version.
4. **Consistency check:** compare the Carambus match results with the ones entered in CC — if path 1 (per-match upload) was used, both should be identical.

**Note:** an **automatic final ranking calculation in Carambus** (with all special cases) is planned as a large feature for v7.1+. When it ships, this appendix becomes obsolete.
```

Verify the developer-doc pointer line from Plan 05 is still the very last line of the file.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "appendix-no-invitation" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-missing-player" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-nachmeldung" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-cc-csv-upload" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-rangliste-manual" docs/managers/tournament-management.en.md &amp;&amp; grep -c "## Appendix" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - All 6 appendix anchors exist in EN with ≥2 occurrences each
    - grep "## Appendix" returns ≥1 match
    - grep "PREP-04" returns ≥2 matches
    - grep "club sports officer" returns ≥3 matches
  </acceptance_criteria>
  <done>EN Appendix mirrors DE Anhang; same anchors; same first-pass disclaimers.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# All 6 appendix anchors must be defined in BOTH files
for anchor in appendix-no-invitation appendix-missing-player appendix-nachmeldung appendix-cc-upload appendix-cc-csv-upload appendix-rangliste-manual; do
  DE=$(grep -c "id=\"$anchor\"" docs/managers/tournament-management.de.md)
  EN=$(grep -c "id=\"$anchor\"" docs/managers/tournament-management.en.md)
  echo "$anchor: DE=$DE EN=$EN (must be 1/1)"
done
```
</verification>

<success_criteria>
- DOC-ACC-04 (new appendix sections) is satisfied: 6 new appendices present in both files
- DOC-ACC-05 (walkthrough restructure honestly distinguishes manager-action from passive phases) is reinforced — special cases live in appendix instead of polluting the linear walkthrough
- All forward links from Plans 01-05 to `#appendix-*` anchors now resolve
- CC-upload and CC-CSV appendices are flagged as first-pass with PREP-04 follow-up note
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-06-SUMMARY.md`.
</output>
