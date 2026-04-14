---
phase: 36A
plan: 03
type: execute
wave: 3
depends_on: [36A-02]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-02
  - DOC-ACC-05
must_haves:
  truths:
    - "Schritt 9 warning block no longer suggests doppelklick risk — replaced with simple 'der Vorgang dauert einige Sekunden' wording"
    - "Schritt 9 AASM-Technik paragraph (Redis/ActionCable) is removed and replaced with table-feedback check"
    - "Schritt 10 uses 'einspielen' Fachterminus instead of 'ausprobieren'"
    - "Schritt 10 no longer claims 'alle 4 Matches' — describes correct round-1 layout for 5 players (2 matches + 1 Freilos)"
    - "Schritt 10 'Aktuelle Spiele'-table input UI is documented as read-only / not used by manager"
    - "Schritt 11 is rewritten to honestly say the manager has no active role during play (passive observation phase)"
    - "Schritt 12 documents the browser-tab oversight workflow and Nachstoß awareness"
    - "Schritt 13 honest about Endrangliste-not-calculated and Shootout-not-supported limitations with forward links"
    - "Schritt 14 corrects beim-Finalisieren timing and removes the fictional 'Ergebnisse nach ClubCloud übertragen' button"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "Block-4+5 corrections (lines 111-168 region) — Schritte 9-14 rewritten"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored Block-4+5 corrections"
  key_links:
    - from: "step-13-finalize"
      to: "appendix-rangliste-manual, troubleshooting-shootout"
      via: "honest limitation forward-links"
      pattern: "appendix-rangliste-manual"
    - from: "step-14-upload"
      to: "appendix-cc-upload"
      via: "two-paths forward-link"
      pattern: "appendix-cc-upload"
---

<objective>
Apply factual corrections from review blocks 4 and 5 (F-36-24 through F-36-38) to both DE and EN files — Schritte 9 (Turnier starten), 10 (Warmup), 11 (Spielbeginn), 12 (Ergebnisse), 13 (finalisieren), and 14 (Upload).

Purpose: This block contains the most consequential walkthrough restructuring (DOC-ACC-05). Schritt 11 has to be rewritten because the entire premise — "manager clicks Spielbeginn buttons" — is factually wrong. Schritte 10/11/12 must honestly distinguish phases-with-manager-action from passive-observation phases. Schritte 13 and 14 must remove fictional UI elements and honestly disclose the Endrangliste / Shootout / CSV-upload limitations.

Output: DE + EN files with lines 111-168 (DE) rewritten per F-36-24..F-36-38.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/REQUIREMENTS.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@docs/managers/tournament-management.de.md
@docs/managers/tournament-management.en.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Apply Block 4+5 corrections to tournament-management.de.md</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (current state after Plans 36A-01 + 36A-02 — lines containing Schritte 9-14)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 522-738 (Block 4 + Block 5 findings F-36-24..F-36-38)
  </read_first>
  <action>
**Re-read the current DE file first** because Plans 01 and 02 changed line numbers. Find the Schritt-9 through Schritt-14 region (anchors `step-9-start` through `step-14-upload`).

**Edit 1 — Schritt 9 warning block + AASM technical paragraph — F-36-24 + F-36-25**

OLD (warning callout + the paragraph after it):
```
!!! warning "Warten, nicht erneut klicken"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite mehrere
    Sekunden lang unverändert aus. Das ist normal — der Wizard bereitet im
    Hintergrund die Tisch-Monitore vor. **Klicken Sie den Button nicht erneut**
    und navigieren Sie nicht zurück. Nach wenigen Sekunden öffnet sich der
    Turnier-Monitor automatisch.
<!-- ref: F-19 -->

Im Hintergrund löst Carambus das AASM-Event `start_tournament!` aus (Übergang nach `tournament_started_waiting_for_monitors`), initialisiert alle TableMonitors und leitet Sie dann automatisch zur Turnier-Monitor-Seite weiter. Wenn sich die Seite nach 30 Sekunden nicht ändert, prüfen Sie, ob Redis und der ActionCable-Dienst laufen.
```

NEW:
```
!!! info "Der Start-Vorgang dauert einige Sekunden"
    Nach dem Klick auf **Starte den Turnier Monitor** sieht die Seite kurz
    unverändert aus. Das ist normal — der Wizard bereitet im Hintergrund
    die Tisch-Monitore vor. Der Button ist während des Vorgangs gesperrt,
    so dass ein versehentlicher Doppelklick nichts auslöst. Nach wenigen
    Sekunden öffnet sich der Turnier-Monitor automatisch.
<!-- ref: F-19 -->

**Erfolgreich gestartet?** Der zuverlässigste Check ist, an den **Tisch-Tafeln** nachzusehen: Wenn dort die korrekten Paarungen der ersten Runde erscheinen, ist der Start gelungen.
```

**Edit 2 — Schritt 10 (Warmup) — F-36-26 + F-36-27 + F-36-28**

OLD (the Schritt-10 prose):
```
Nachdem der Turnier-Monitor geöffnet ist, sehen Sie die Übersichtsseite „Turnier-Monitor · NDM Freie Partie Klasse 1–3". Jeder der zwei Tische zeigt einen Status-Badge **„warmup"** und die zugewiesenen Spielerpaare für Partie 1 (z. B. „Simon, Franzel / Smrcka, Martin" auf Tisch 1).

In der Warmup-Phase können die Spieler die Tische und Bälle ausprobieren. Die Scoreboards sind bereits aktiv, aber die Punkte zählen noch nicht. Im Abschnitt „Aktuelle Spiele Runde 1" sehen Sie alle 4 Matches der ersten Runde mit den Spalten Tisch / Gruppe / Partie / Spieler und einem **„Spielbeginn"**-Button pro Zeile.

Sie müssen hier nichts aktiv tun — beobachten Sie, ob alle Scoreboards verbunden sind (grüner Status), und warten Sie auf den Startschuss des Turniers.
```

NEW:
```
Nachdem der Turnier-Monitor geöffnet ist, sehen Sie die Übersichtsseite „Turnier-Monitor · NDM Freie Partie Klasse 1–3". Jeder der zwei Tische zeigt einen Status-Badge **„warmup"** und die zugewiesenen Spielerpaare für Partie 1 (z. B. „Simon, Franzel / Smrcka, Martin" auf Tisch 1).

In der Warmup-Phase können sich die Spieler **einspielen** (Fachterminus für „Tisch und Bälle ausprobieren bevor es zählt"). Die Einspielzeit wird **am Scoreboard** gestartet und beträgt typischerweise 5 Minuten (Parameter **Warmup**). Die Scoreboards sind bereits aktiv, aber Punkte zählen noch nicht.

Im Turnier-Monitor sehen Sie im Abschnitt „Aktuelle Spiele Runde 1" die Matches der laufenden Runde mit den Spalten Tisch / Gruppe / Partie / Spieler. **Bei 5 Teilnehmern in Runde 1 laufen 2 Matches mit je 2 Spielern; der fünfte Spieler hat in dieser Runde [Freilos](#glossary-wizard).** (Nicht 4 Matches — die Anzahl ergibt sich aus dem Turnierplan.)

> **Hinweis:** In dieser Tabelle sehen Sie pro Zeile auch Buttons wie „Spielbeginn" — das ist ein Fallback-UI für den Notfall (Scoreboard-Ausfall mit manueller Übertragung von Papierprotokollen). Im Standardablauf braucht der Turnierleiter diese Buttons **nicht** zu klicken.

Als Turnierleiter müssen Sie hier nichts aktiv tun — beobachten Sie, ob alle Scoreboards verbunden sind (grüner Status), und warten Sie auf den Startschuss durch die Spieler an den Scoreboards.
```

**Edit 3 — Schritt 11 (Spielbeginn) — F-36-29 + F-36-30 — COMPLETE REWRITE**

OLD:
```
<a id="step-11-release-match"></a>
### Schritt 11: Spielbeginn freigeben

Wenn der Warmup abgeschlossen ist und alle Spieler bereit sind, klicken Sie für jede Partie in der Tabelle „Aktuelle Spiele Runde 1" auf den Button **„Spielbeginn"**. Dieser Klick startet die Zeitmessung und aktiviert die Ball-Eingabe am [Scoreboard](#glossary-wizard).

In unserem Szenario mit 5 Teilnehmern und 2 Tischen laufen in Runde 1 gleichzeitig 2 Partien — klicken Sie also nacheinander auf zwei „Spielbeginn"-Buttons. Der fünfte Spieler sitzt in Runde 1 aus (Freilos, abhängig vom gewählten Turnierplan).
```

NEW:
```
<a id="step-11-release-match"></a>
### Schritt 11: Spielbetrieb läuft (Scoreboards steuern alles)

**Im Standardablauf hat der Turnierleiter hier keine aktive Rolle.** Sobald der Warmup an einem Scoreboard zu Ende ist, startet das jeweilige Spiel automatisch — der Spielbeginn wird **am Scoreboard** ausgelöst, nicht im Turnier-Monitor.

Schritte 10, 11 und 12 sind in Wahrheit drei **Phasen** (Warmup → Spielbetrieb → Abschluss), nicht drei „Aktionen des Turnierleiters". Während dieser Phasen läuft alles an den Scoreboards. Ihre einzige Aufgabe ist Beobachtung und das Eingreifen bei Problemen — dafür siehe [Schritt 12](#step-12-monitor).

> **Sonderfall Manuelle Rundenwechsel-Kontrolle:** Wenn Sie im Start-Formular den Parameter „Tournament manager checks results before acceptance" aktiviert haben, wird der Rundenwechsel blockiert, bis Sie bei jedem Spielende auf „OK?" klicken. Diese Option ist inzwischen umstritten und wird voraussichtlich entfernt; im Standardfall lassen Sie sie deaktiviert.
```

**Edit 4 — Schritt 12 — F-36-31 (Nachstoß-Hinweis + Browser-Tab-Oversight) + F-36-32 (Reset-Sicherheitshinweis) + F-36-33 (manueller Bestätigungs-Button erwähnen)**

OLD:
```
<a id="step-12-monitor"></a>
### Schritt 12: Ergebnisse verfolgen

Nach dem Spielbeginn übernehmen die Spieler die Scoreboard-Eingabe. Der Turnier-Monitor aktualisiert sich in Echtzeit über ActionCable — Sie müssen die Seite nicht neu laden.

Beobachten Sie die Spaltenwerte **Bälle** / **Aufnahme** / **HS** ([Höchstserie](#glossary-karambol)) / **GD** ([Generaldurchschnitt](#glossary-karambol)) in der Spiele-Tabelle. Wenn eine Partie abgeschlossen ist, wechselt die Tischkarte automatisch zur nächsten Partie in der Runde. Nach Abschluss aller Partien einer [Spielrunde](#glossary-karambol) schaltet der Monitor auf Runde 2, und die nächste Paarung erscheint.

Als Turnierleiter greifen Sie normalerweise nicht aktiv ein — außer wenn ein Spieler ein Ergebnis anfechtet oder ein Scoreboard-Problem vorliegt. Wenn Sie „Tournament manager checks results before acceptance" aktiviert haben, erscheint nach jedem Spiel ein Bestätigungs-Button für Sie.
```

NEW:
```
<a id="step-12-monitor"></a>
### Schritt 12: Beobachten und bei Bedarf eingreifen

Während des Spielbetriebs übernehmen die Spieler bzw. das Scoreboard-Personal die Punkteingabe. Der Turnier-Monitor aktualisiert sich in Echtzeit — Sie müssen die Seite nicht neu laden.

**Was Sie in der Übersicht sehen:** die Spaltenwerte **Bälle** / **Aufnahme** / **HS** ([Höchstserie](#glossary-karambol)) / **GD** ([Generaldurchschnitt](#glossary-karambol)) in der Spiele-Tabelle. Nach Partie-Ende wechselt die Tischkarte automatisch zur nächsten Partie der Runde; nach Abschluss aller Partien einer [Spielrunde](#glossary-karambol) schaltet der Monitor auf die nächste Runde.

**Beobachtung per Browser-Tab:** Vom Turnier-Monitor aus können Sie die einzelnen Tisch-Scoreboards in eigenen Browser-Tabs öffnen (Klick auf den jeweiligen Tisch-Link). Das ist die übliche Methode, um aus der Ferne den Spielstand mehrerer Tische gleichzeitig im Auge zu behalten und bei Bedarf einzugreifen.

**Häufige Fehlerquellen während des Spielbetriebs:**

- **Nachstoß vergessen am Scoreboard** — in Karambol-Disziplinen mit Nachstoß-Regel ist es eine wiederkehrende Quelle für falsche Endergebnisse. Wenn Sie das beobachten, sprechen Sie das Scoreboard-Personal direkt an, bevor der nächste Aufschlag passiert.

!!! danger "Reset zerstört bei laufendem Turnier alle Daten"
    Der Link **„Zurücksetzen des Turnier-Monitors"** am unteren Ende der
    Turnierseite ist **jederzeit** verfügbar — auch während das Turnier
    läuft. Bei laufendem Turnier zerstört der Reset jedoch **alle bisher
    erfassten Spielergebnisse**. Eine Sicherheitsabfrage ist aktuell
    nicht eingebaut (geplant für eine Folge-Phase). Verwenden Sie den
    Reset während des Spielbetriebs nur, wenn Sie das Turnier wirklich
    abbrechen wollen.
<!-- ref: F-36-32 -->

> **Sonderfall manuelle Kontrolle:** Wenn Sie im Start-Formular „Tournament manager checks results before acceptance" aktiviert haben, erscheint nach jedem Spiel ein Bestätigungs-Button für Sie. Dieser Button ist Teil der Sonderbetriebsart aus [Schritt 11](#step-11-release-match) und wird voraussichtlich entfallen.
```

**Edit 5 — Schritt 13 (Finalize) — F-36-34 + F-36-35**

OLD:
```
<a id="step-13-finalize"></a>
### Schritt 13: Turnier finalisieren

Nach Abschluss aller Runden erscheint im Turnier-Monitor eine Schaltfläche zum Finalisieren des Turniers. Klicken Sie darauf, um die Endrangliste zu berechnen und das Turnier in den Abschlussstatus zu setzen.

Falls Platzierungen noch angepasst werden müssen (z. B. wegen eines Steches oder einer manuellen Korrektur), lesen Sie die Details in der [Einzelturnier-Verwaltung](single-tournament.md), die den Platzierungs-Workflow ausführlich beschreibt.

Nach dem Finalisieren ist das Turnier abgeschlossen — Änderungen an Ergebnissen sind nur noch über Admin-Eingriff möglich.
```

NEW:
```
<a id="step-13-finalize"></a>
### Schritt 13: Turnier abschließen

Nach Abschluss aller Runden setzt der Turnier-Monitor das Turnier in den Abschlussstatus.

!!! warning "Endrangliste wird derzeit NICHT automatisch berechnet"
    Carambus liefert die einzelnen Spielergebnisse korrekt zurück, die
    **Berechnung der Turnier-Endrangliste** (Platzierungen, Stechen,
    Gleichstands-Kriterien) erfolgt aktuell **manuell in der ClubCloud**.
    Den manuellen Pflege-Workflow finden Sie im Anhang
    [Endrangliste in der ClubCloud pflegen](#appendix-rangliste-manual).
    Eine automatische Berechnung in Carambus ist als Folge-Feature für
    v7.1+ vorgesehen.
<!-- ref: F-36-34 -->

!!! warning "Shootout / Stechen wird nicht unterstützt"
    Stichspiele bei KO-Turnieren werden in der aktuellen Carambus-Version
    **nicht unterstützt**. Wenn nach der regulären Partie ein Stechen nötig
    ist, müssen Sie das **außerhalb von Carambus** durchführen (am Tisch
    auf Papier protokollieren) und das Ergebnis manuell in der ClubCloud
    eintragen. Shootout-Support ist als kritisches Feature für ein
    späteres Milestone (v7.1 oder v7.2) eingeplant.
<!-- ref: F-36-35 -->
```

**Edit 6 — Schritt 14 (Upload) — F-36-36 + F-36-37**

OLD:
```
<a id="step-14-upload"></a>
### Schritt 14: Ergebnis-Upload nach ClubCloud

Wenn im Start-Formular (Schritt 7) die Option **„auto_upload_to_cc"** aktiviert war, überträgt Carambus die Ergebnisse beim Finalisieren automatisch zurück an die ClubCloud. Sie sehen anschließend eine Bestätigung, dass der Upload erfolgreich war.

Wenn der automatische Upload deaktiviert ist oder fehlschlägt, können Sie den Upload manuell auf der Turnier-Detailseite anstoßen (Schaltfläche „Ergebnisse nach ClubCloud übertragen"). Prüfen Sie in der ClubCloud, ob die Ergebnisse angekommen sind — normalerweise sind sie innerhalb weniger Minuten sichtbar.
```

NEW:
```
<a id="step-14-upload"></a>
### Schritt 14: Ergebnisse in die ClubCloud übertragen

Wenn im Start-Formular (Schritt 7) die Option **„auto_upload_to_cc"** aktiviert war, überträgt Carambus jedes **Einzelergebnis sofort nach dem jeweiligen Spielende** an die ClubCloud — nicht erst beim Finalisieren. Voraussetzung: Die Teilnehmerliste muss in der ClubCloud bereits **finalisiert** sein. Die volle Erklärung beider Upload-Pfade und ihrer Voraussetzungen finden Sie im Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).

Wenn der automatische Upload nicht aktiviert war oder die Voraussetzungen fehlen, läuft der Upload über den **CSV-Batch-Pfad**: Carambus stellt am Ende eine CSV-Datei mit allen Ergebnissen bereit, die manuell in die (finalisierte) ClubCloud-Teilnehmerliste eingespielt werden muss. Der Anhang [CSV-Upload in der ClubCloud](#appendix-cc-csv-upload) beschreibt den Weg im Detail.

> Eine „Übertragen nach ClubCloud"-Schaltfläche, wie sie in früheren Doc-Versionen erwähnt wurde, gibt es im aktuellen Carambus-UI nicht. Der manuelle Upload erfolgt ausschließlich über die ClubCloud-Admin-Oberfläche.
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "einspielen" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-rangliste-manual" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Shootout" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "alle 4 Matches" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "manuell auf der Turnier-Detailseite anstoßen (Schaltfläche" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "AASM-Event \`start_tournament" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Spielbeginn freigeben" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Endrangliste zu berechnen" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Klicken Sie den Button nicht erneut" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "einspielen" returns ≥1 match (Fachterminus added)
    - grep "appendix-rangliste-manual" returns ≥1 match
    - grep "appendix-cc-upload" returns ≥1 match (Step 14 forward link)
    - grep "appendix-cc-csv-upload" returns ≥1 match
    - grep "Shootout" returns ≥1 match (limitation called out)
    - grep "Browser-Tab" returns ≥1 match (oversight workflow documented)
    - grep "Nachstoß" returns ≥1 match (häufige Fehlerquelle documented)
    - grep "Reset zerstört" returns ≥1 match (data-loss warning)
    - grep -F "alle 4 Matches" returns 0 (false claim removed)
    - grep -F "manuell auf der Turnier-Detailseite anstoßen (Schaltfläche" returns 0 (old fictional-button wording removed)
    - grep -F "Endrangliste zu berechnen" returns 0 (false promise removed)
    - grep -F "Klicken Sie den Button nicht erneut" returns 0 (Doppelklick-Mythos removed)
    - grep "AASM-Event" returns 0 (developer info removed from Step 9)
  </acceptance_criteria>
  <done>All 6 edits applied; the rewritten Schritte 9-14 honestly distinguish manager-action phases (9, 13, 14) from passive-observation phases (10, 11, 12).</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Block 4+5 corrections to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (current state — find Step-9 through Step-14 region)
    - docs/managers/tournament-management.de.md (after Task 1 — authoritative source)
  </read_first>
  <action>
Mirror Task 1 edits in the EN file. Translate each new German block into idiomatic English.

**Edit 1 — Step 9 warning + AASM paragraph — F-36-24 + F-36-25**

OLD warning + the AASM paragraph after it. Replace with:

```
!!! info "The start takes a few seconds"
    After clicking **Start tournament monitor** the page may look unchanged
    for a few seconds. That is normal — the wizard is preparing the table
    monitors in the background. The button is disabled during the
    operation, so an accidental double-click does nothing. After a few
    seconds the Tournament Monitor opens automatically.
<!-- ref: F-19 -->

**Did the start succeed?** The most reliable check is to look at the **table scoreboards**: if they show the correct round-1 pairings, the start was successful.
```

**Edit 2 — Step 10 (Warmup) — F-36-26 + F-36-27 + F-36-28**

Replace existing Step-10 prose with:

```
After the Tournament Monitor opens, you see the overview page "Tournament Monitor · NDM Freie Partie Class 1–3". Each of the two tables shows a status badge **"warmup"** and the assigned player pairs for match 1 (for example "Simon, Franzel / Smrcka, Martin" on Table 1).

In the warmup phase the players **break in** the table (German: *einspielen* — the technical term for "try out the table and balls before they count"). The warmup time is started **at the scoreboard** and is typically 5 minutes (parameter **Warmup**). The scoreboards are already active, but points do not count yet.

In the Tournament Monitor, the section "Current matches Round 1" shows the matches of the current round with columns Table / Group / Match / Players. **With 5 participants in Round 1 there are 2 matches with 2 players each; the fifth player has a [bye](#glossary-wizard) (Freilos) in this round.** (Not 4 matches — the count is determined by the tournament plan.)

> **Note:** Each row in this table also has buttons such as "Start match" — that is fallback UI for the emergency case (scoreboard failure with manual transcription from paper protocols). In the standard flow the tournament director does **not** need to click these buttons.

As the tournament director you have nothing to do here actively — observe whether all scoreboards are connected (green status) and wait for the players to start the matches at their scoreboards.
```

**Edit 3 — Step 11 — F-36-29 + F-36-30 — COMPLETE REWRITE**

Replace the existing Step-11 block with:

```
<a id="step-11-release-match"></a>
### Step 11: Match play (the scoreboards drive everything)

**In the standard flow the tournament director has no active role here.** Once warmup ends at a scoreboard, that scoreboard automatically starts the match — the start is triggered **at the scoreboard**, not in the Tournament Monitor.

Steps 10, 11 and 12 are in truth three **phases** (warmup → match play → finalisation), not three "tournament-director actions". During these phases everything happens at the scoreboards. Your only job is observation and intervention if something goes wrong — see [Step 12](#step-12-monitor).

> **Special case: manual round-change control:** If you enabled the parameter "Tournament manager checks results before acceptance" in the start form, the round change will be blocked until you click "OK?" at every match end. This option is now disputed and is likely to be removed; in the standard case, leave it disabled.
```

**Edit 4 — Step 12 — F-36-31 + F-36-32 + F-36-33**

Replace existing Step-12 block with:

```
<a id="step-12-monitor"></a>
### Step 12: Observe and intervene as needed

During match play the players or scoreboard helpers handle point entry. The Tournament Monitor updates in real time — you do not need to reload the page.

**What you see in the overview:** the columns **Balls** / **Innings** / **HS** ([high run](#glossary-karambol)) / **GD** ([general average](#glossary-karambol)) in the matches table. After a match ends, the table card automatically advances to the next match in the round; after all matches in a [round](#glossary-karambol) are finished the monitor advances to the next round.

**Browser-tab oversight:** From the Tournament Monitor you can open the individual table scoreboards in their own browser tabs (click the corresponding table link). This is the usual way to keep an eye on multiple tables at once and intervene when needed.

**Common error sources during match play:**

- **Nachstoß forgotten at the scoreboard** — in carom disciplines with the Nachstoß rule this is a recurring source of wrong final scores. If you observe it, address the scoreboard helper directly before the next break shot.

!!! danger "Reset destroys all data while a tournament is running"
    The link **"Reset tournament monitor"** at the bottom of the
    tournament page is **always available** — even while the tournament
    is running. While the tournament is running the reset destroys
    **all results recorded so far**. A safety dialog is currently not
    in place (planned for a follow-up phase). Use the reset during
    match play only if you really intend to abort the tournament.
<!-- ref: F-36-32 -->

> **Special case manual control:** If you enabled "Tournament manager checks results before acceptance" in the start form, a confirmation button appears for you after each match. This button is part of the special operating mode from [Step 11](#step-11-release-match) and is likely to be removed.
```

**Edit 5 — Step 13 — F-36-34 + F-36-35**

Replace the existing Step-13 block with:

```
<a id="step-13-finalize"></a>
### Step 13: Conclude the tournament

After all rounds are finished the Tournament Monitor moves the tournament into the finalisation status.

!!! warning "Final ranking is NOT calculated automatically"
    Carambus correctly returns the individual match results, but the
    **calculation of the final tournament ranking** (positions, tie-breakers,
    discipline-specific rules) currently happens **manually in ClubCloud**.
    The manual maintenance workflow is documented in the appendix
    [Maintaining the final ranking in ClubCloud](#appendix-rangliste-manual).
    Automatic calculation in Carambus is planned as a follow-up feature
    for v7.1+.
<!-- ref: F-36-34 -->

!!! warning "Shootout / playoff matches are not supported"
    Playoff matches in knock-out tournaments are **not supported** in the
    current Carambus version. If a shootout is needed after the regular
    match, you must run it **outside Carambus** (record the result on
    paper at the table) and enter the result manually in ClubCloud.
    Shootout support is planned as a critical feature for a later
    milestone (v7.1 or v7.2).
<!-- ref: F-36-35 -->
```

**Edit 6 — Step 14 — F-36-36 + F-36-37**

Replace the existing Step-14 block with:

```
<a id="step-14-upload"></a>
### Step 14: Transfer results to ClubCloud

If the option **"auto_upload_to_cc"** was enabled in the start form (Step 7), Carambus uploads each **individual result immediately when the corresponding match ends** — not at finalisation time. Prerequisite: the participant list must already be **finalised** in ClubCloud. The full explanation of both upload paths and their prerequisites is in the appendix [ClubCloud upload — two paths](#appendix-cc-upload).

If automatic upload was not enabled or the prerequisites are missing, the upload runs through the **CSV batch path**: at the end Carambus produces a CSV file with all results, which must be imported manually into the (finalised) ClubCloud participant list. The appendix [CSV upload in ClubCloud](#appendix-cc-csv-upload) describes the path in detail.

> An "Upload to ClubCloud"-button, as mentioned in earlier doc versions, does not exist in the current Carambus UI. Manual upload happens exclusively via the ClubCloud admin interface.
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "einspielen" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-rangliste-manual" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Shootout" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "all 4 matches" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "you can manually trigger the upload on the tournament detail page" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "AASM event \`start_tournament" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Step 11: Release matches" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "to calculate the final standings" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "einspielen" returns ≥1 match
    - grep "appendix-rangliste-manual" returns ≥1 match in EN
    - grep "appendix-cc-upload" returns ≥1 match in EN
    - grep "Shootout" returns ≥1 match in EN
    - grep "Browser-tab oversight" returns ≥1 match
    - grep "Nachstoß forgotten" returns ≥1 match
    - grep -F "all 4 matches" returns 0
    - grep -F "you can manually trigger the upload on the tournament detail page" returns 0 (old fictional-button wording removed)
    - grep "AASM event" returns 0 in EN file
  </acceptance_criteria>
  <done>EN file mirrors all DE Block-4+5 changes; same anchors, same forward-link targets.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Both files should now reference the to-be-created appendix anchors
for ref in "appendix-rangliste-manual" "appendix-cc-upload" "appendix-cc-csv-upload"; do
  DE=$(grep -c "$ref" docs/managers/tournament-management.de.md)
  EN=$(grep -c "$ref" docs/managers/tournament-management.en.md)
  echo "$ref: DE=$DE EN=$EN"
done
```
</verification>

<success_criteria>
- F-36-24 through F-36-38 are addressed in both files
- DOC-ACC-02 (factual corrections) and DOC-ACC-05 (walkthrough restructure for passive phases) are covered
- Schritt 11 honestly states the manager has no active role
- Step 13 discloses Endrangliste and Shootout limitations
- Step 14 corrects the timing claim and removes the fictional button
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-03-SUMMARY.md`.
</output>
</content>
</invoke>