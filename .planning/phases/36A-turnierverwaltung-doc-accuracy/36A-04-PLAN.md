---
phase: 36A
plan: 04
type: execute
wave: 4
depends_on: [36A-03]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-01
  - DOC-ACC-03
must_haves:
  truths:
    - "Glossary has separate entries for Setzliste, Meldeliste, Teilnehmerliste with temporal relationship"
    - "Glossary has separate entries for Ballziel and Aufnahmebegrenzung (no longer one merged wrong entry)"
    - "Glossary has new entries for Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos"
    - "Glossary entry for Rangliste is rewritten as Carambus-internal (not 'from ClubCloud database')"
    - "Glossary entry for Setzliste is rewritten with the three sources (invitation / Carambus-internal / NOT ClubCloud)"
    - "Glossary entry for AASM-Status no longer claims Schritt 4 = tournament_seeding_finished and removes the 'Phase 36 will make badge prominent' promise"
    - "Glossary entry for Tournament plan codes uses Default{n} (not Default5/DefaultS)"
    - "Glossary entry for Scoreboard says binding is not fixed (manual selection at scoreboard)"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "Block-6 glossary rewrite (lines 172-218 region) — corrected entries plus 6 new entries"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored glossary rewrite"
  key_links:
    - from: "step-1-invitation"
      to: "glossary-wizard"
      via: "three-term Begriffshierarchie forward link"
      pattern: "Setzliste.*Meldeliste.*Teilnehmerliste"
---

<objective>
Rewrite the Glossar section to address all Block 6 findings (F-36-39 through F-36-50) — fix the wrong existing entries (Ballziel/Aufnahmebegrenzung, Setzliste, Default5, Scoreboard, AASM-Status, Rangliste) and add the 6 missing entries (Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos).

Purpose: The glossary is the conceptual anchor that the walkthrough corrections in Plans 01-03 forward-link into. Without correct glossary entries, the walkthrough's improved terminology becomes inconsistent. DOC-ACC-01 (Begriffshierarchie consistency) and DOC-ACC-03 (new glossary entries) hinge on this plan.

Output: DE + EN glossary sections rewritten with correct entries and 6 new entries added.
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
  <name>Task 1: Rewrite Glossar section in tournament-management.de.md</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (current state — Glossar section, find by anchor `<a id="glossary"></a>`)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 740-887 (Block 6 findings F-36-39..F-36-50)
  </read_first>
  <action>
**Re-read the current Glossar section first** (anchor `glossary` through `troubleshooting`). Apply targeted edits to existing entries and append new entries.

**Edit 1 — Replace the existing "Bälle-Ziel (innings_goal)" entry — F-36-39 + F-36-17 Tier A**

OLD entry (around line 188 in original file):
```
- **Bälle-Ziel (innings_goal)** — Die Zahl der Punkte (Karambolagen), die ein Spieler erzielen muss, um eine Partie zu gewinnen. Im System-Code heißt das Feld `innings_goal` (englisch) — im Start-Formular erscheint es als „Bälle vor". *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form). Weitere Erklärung zu den englischen Feldbezeichnungen im [dortigen Hinweiskasten](#step-7-start-form).*
```

NEW entry (and add a separate Aufnahmebegrenzung entry after it):
```
- **Ballziel (`balls_goal`)** — Die Zahl der Punkte (Karambolagen), die ein Spieler erzielen muss, um eine Partie zu gewinnen. Im System-Code heißt das Feld `balls_goal`. Für Freie Partie Klasse 1–3 typischerweise **150 Bälle** (ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung. *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Aufnahmebegrenzung (`innings_goal`)** — Maximale Aufnahmenzahl pro Partie. Im System-Code heißt das Feld `innings_goal`. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt.** *Sie konfigurieren diesen Wert im [Start-Formular, Schritt 7](#step-7-start-form).*

- **Bälle vor (Vorgabe-Wert)** — Eine **individuelle Vorgabe pro Spieler** in Vorgabe-/Handikap-Turnieren. Nicht zu verwechseln mit dem allgemeinen Ballziel — bei Vorgabeturnieren bekommt jeder Spieler einen anderen Wert.
```

**Edit 2 — Update the existing "Aufnahme" entry** to remove the now-duplicated Aufnahmebegrenzung text:

OLD:
```
- **Aufnahme** — Eine Aufnahme (auch: Inning) ist ein Spielzug — der Spieler schlägt an, bis er keinen Punkt erzielt oder das [Bälle-Ziel](#glossary-karambol) erreicht. Die **Aufnahmebegrenzung** im Start-Formular legt die maximale Aufnahmen-Anzahl pro Partie fest (0 = unbegrenzt). *Sie sehen diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*
```

NEW:
```
- **Aufnahme** — Eine Aufnahme (auch: Inning) ist ein Spielzug — der Spieler schlägt an, bis er keinen Punkt erzielt oder das [Ballziel](#glossary-karambol) erreicht. Die [Aufnahmebegrenzung](#glossary-karambol) legt die maximale Aufnahmen-Anzahl pro Partie fest. *Sie sehen diesen Begriff im [Start-Formular, Schritt 7](#step-7-start-form).*
```

**Edit 3 — Replace the existing "Setzliste" entry — F-36-40 Tier A**

OLD (in glossary-wizard section):
```
- **Setzliste** — Die geordnete Teilnehmerliste mit Setzposition (Platz 1 = gesetzt, Platz N = ungesetzt). Wird in [Schritt 3](#step-3-seeding-list) aus der Einladung oder der ClubCloud übernommen und in [Schritt 4](#step-4-participants) ergänzt. Das Abschließen der Setzliste in [Schritt 5](#step-5-finish-seeding) ist irreversibel.
```

NEW (single entry, plus 2 new neighbour entries Meldeliste + Teilnehmerliste — F-36-41):
```
- **Setzliste** — Die **geordnete** Liste der Anmelder (Platz 1 = top-gesetzt, Platz N = unten). Drei Herkunftsquellen sind möglich:
    1. **Offizielle Setzliste aus der Einladung** (Normalfall) — vom Landessportwart aus seinen Spreadsheets erstellt
    2. **Carambus-interne Setzliste** (Notfall ohne Einladung) — aus den Carambus-eigenen [Ranglisten](#glossary-system) per „Nach Ranking sortieren" in [Schritt 4](#step-4-participants)
    3. **Nicht aus der ClubCloud** — die ClubCloud führt nur Meldelisten, keine Setzlisten

- **Meldeliste** — **Snapshot der Setzliste nach dem Meldeschluss** — wer ist offiziell für das Turnier gemeldet. Kommt aus der ClubCloud und ist vorläufig: bis zum Turniertag kann sie sich noch ändern (Nachmeldungen, Abmeldungen). Cross-ref Begriffshierarchie in [Schritt 1](#step-1-invitation).

- **Teilnehmerliste** — Wer **tatsächlich** am Turniertag antritt. Wird kurz vor Turnierbeginn finalisiert. Resultiert aus der Meldeliste minus Nichterschienene plus eventuelle [Nachmeldungen](#appendix-nachmeldung). Die Finalisierung erfolgt in [Schritt 5](#step-5-finish-seeding).
```

**Edit 4 — Replace "Turnierplan-Kürzel" entry — F-36-42 + F-36-50**

OLD:
```
- **Turnierplan-Kürzel (T04, T05, Default5)** — Interne Bezeichnungen für vordefinierte Turnierpläne. **T** steht für Turnierplan, die Zahl für den Plancode. T04 und T05 sind die gängigen Pläne für 5-Spieler-Turniere im Jeder-gegen-Jeden-Format — sie unterscheiden sich hauptsächlich in der Zahl der Spielrunden. DefaultS ist ein flexibleres Format. *Sie wählen den Plan in [Schritt 6](#step-6-mode-selection).*
```

NEW:
```
- **Turnierplan-Kürzel (T-Plan vs. Default-Plan)** — Carambus kennt zwei Arten von Turnierplänen:
    - **T-nn** (z. B. T04, T05) — vordefinierte Pläne aus der **Karambol-Turnierordnung** mit fester Spielstruktur und fester Tischanzahl. Sinnvoll für Standard-Spielerzahlen mit Jeder-gegen-Jeden.
    - **`Default{n}`** — ein **dynamisch generierter** Jeder-gegen-Jeden-Plan, wobei `{n}` die Teilnehmerzahl ist. Wird automatisch erstellt, wenn kein passender T-Plan existiert; die benötigte Tischanzahl wird aus der Teilnehmerzahl berechnet.

  *Sie wählen den Plan in [Schritt 6](#step-6-mode-selection).*
```

**Edit 5 — Replace "Scoreboard" entry — F-36-43**

OLD:
```
- **Scoreboard** — Das berührungsempfindliche Eingabegerät an jedem Tisch, über das die Spieler oder ein Helfer die Punkte live eingeben. Die Scoreboards verbinden sich nach dem [Turnier starten](#step-9-start) automatisch mit dem Turnier-Monitor. Ohne aktive Scoreboard-Verbindung können keine Punkte erfasst werden.
```

NEW:
```
- **Scoreboard** — Das berührungsempfindliche Eingabegerät an jedem Tisch (Tisch-Monitor, Smartphone oder Web-Client), über das die Spieler oder ein Helfer die Punkte live eingeben. Die Scoreboard-Verbindung zum Tisch ist **nicht fest vorgegeben**: am Scoreboard wählt der Bediener den passenden physikalischen Tisch aus, und die Bindung erfolgt über den [TableMonitor](#glossary-system) des logischen Tischs. Die Verbindung kann bei Bedarf am Scoreboard neu gewählt werden (z. B. bei Ausfall eines Tisch-Monitors).
```

**Edit 6 — Replace "AASM-Status" entry — F-36-44**

OLD:
```
- **AASM-Status** — Der interne Zustand des Turniers im System, verwaltet durch die AASM-Zustandsmaschine (Acts As State Machine). Mögliche Zustände umfassen `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started` und weitere. Die Wizard-Schrittanzeige spiegelt diesen Status wider — Schritt 4 erledigt = `tournament_seeding_finished`, Turnier gestartet = `tournament_started`. *Phase 36 wird dieses Status-Badge im Wizard sichtbarer machen.*
```

NEW:
```
- **AASM-Status** — Der interne Zustand des Turniers im System, verwaltet durch die AASM-Zustandsmaschine (Acts As State Machine). Mögliche Zustände umfassen `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started` und weitere. Wichtig: die im Wizard angezeigten „Schritte" entsprechen **nicht eins-zu-eins** den AASM-States — Schritte 4 und 5 sind beispielsweise Aktions-Links auf einer State-Seite, kein eigener Zustand (siehe [Schritt 5](#step-5-finish-seeding)). Die sichtbarere Darstellung des Status-Badges im Wizard ist ein offenes Verbesserungsfeld.
```

**Edit 7 — Replace "Rangliste" entry — F-36-45**

OLD:
```
- **Rangliste** — Die regionale Spielerrangliste, die von der ClubCloud-Datenbank bezogen wird. In [Schritt 4](#step-4-participants) können Sie mit „Nach Ranking sortieren" die Teilnehmerliste automatisch nach Ranglistenposition ordnen — das entspricht der offiziellen Setzliste für die meisten NBV-Turniere.
```

NEW:
```
- **Rangliste** — Eine **Carambus-interne** Spielerrangliste, die pro Spieler aus den **Carambus-eigenen Turnierergebnissen** fortgeschrieben wird (also nicht von der ClubCloud bezogen). Sie dient u. a. als Default-Sortierkriterium, wenn keine offizielle Setzliste aus der Einladung vorliegt. In [Schritt 4](#step-4-participants) können Sie mit „Nach Ranking sortieren" die Teilnehmerliste automatisch nach Ranglistenposition ordnen.
```

**Edit 8 — Append new entries to glossary-system section — F-36-46 + F-36-47 + F-36-48 + F-36-49 + F-36-56**

After the rewritten "Rangliste" entry, append (still inside `<a id="glossary-system"></a>` section):

```
- **Logischer Tisch** — Eine TournamentPlan-interne Tisch-Identität (z. B. „Tisch 1", „Tisch 2" innerhalb von T04). Logische Tische werden beim Turnierstart in [Schritt 7](#step-7-start-form) auf physikalische Tische abgebildet. Der TournamentPlan referenziert ausschließlich logische Tischnamen — die einzelnen Spiele werden automatisch logischen Tischen zugeordnet.

- **Physikalischer Tisch** — Ein konkreter, nummerierter Spieltisch im Spiellokal (z. B. „BG Hamburg Tisch 1"). Aus Spielersicht existieren nur physikalische Tische — die Nummern stehen an den Tischen, und Wer-wo-spielt steht auf den Scoreboards und Tisch-Monitoren. Beim Turnierstart wird jeder logische Tisch einem physikalischen zugeordnet (siehe [Schritt 7](#step-7-start-form), Tischzuordnung).

- **TableMonitor** — Technischer Datensatz / „Automat", der die Abläufe an einem [logischen Tisch](#glossary-system) während eines Spiels steuert: Match-Zuweisungen, Ergebnis-Erfassung, Rundenwechsel. Aus Spielersicht: ein Bot, der entscheidet, welches Spiel auf welchem Tisch läuft. Jeder logische Tisch hat einen TableMonitor; alle Scoreboards, die sich mit dem zugehörigen physikalischen Tisch verbinden, bekommen die Match-Updates über diesen TableMonitor.

- **Turnier-Monitor** — Die übergeordnete Instanz, die alle [TableMonitors](#glossary-system) eines Turniers koordiniert. Der Turnier-Monitor ist sowohl der technische Koordinator als auch die Übersichtsseite, die der Turnierleiter ab [Schritt 9](#step-9-start) aufruft.

- **Trainingsmodus** — Betriebsart eines Scoreboards **außerhalb eines Turnier-Kontexts**, zur Abwicklung einzelner Spiele (Training, Freundschaftsspiele). Wird auch als **Fallback** verwendet, wenn ein laufendes Turnier nicht mehr in Carambus weitergeführt werden kann (siehe [Turnier nicht mehr änderbar](#ts-already-started)).

- **Freilos** — Wenn die Teilnehmerzahl ungerade ist (z. B. 5 Spieler, 2 Tische), kann ein Spieler in einer Spielrunde nicht antreten — er hat ein Freilos. Die Zuteilung erfolgt automatisch aus dem [Turnierplan](#glossary-wizard). Hinweis: Ein nachträglicher Match-Abbruch (z. B. wenn ein Spieler während des Turniers ausfällt) wird in der aktuellen Carambus-Version **nicht sauber unterstützt** — siehe Folge-Phase v7.1+.
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "Ballziel" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Aufnahmebegrenzung" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Meldeliste" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Logischer Tisch" docs/managers/tournament-management.de.md &amp;&amp; grep -c "TableMonitor" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Turnier-Monitor" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Trainingsmodus" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Freilos" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Default{n}" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Default5" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Bälle-Ziel (innings_goal)" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "ClubCloud-Datenbank bezogen" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Phase 36 wird dieses Status-Badge" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "Ballziel" returns ≥3 matches (entry exists + walkthrough usage)
    - grep "Aufnahmebegrenzung" returns ≥3 matches
    - grep "Meldeliste" returns ≥4 matches
    - grep "Teilnehmerliste" returns ≥6 matches
    - grep "Logischer Tisch" returns ≥1 match (new entry)
    - grep "Physikalischer Tisch" returns ≥1 match (new entry)
    - grep "TableMonitor" returns ≥2 matches
    - grep "Turnier-Monitor" returns ≥3 matches (entry + walkthrough usages)
    - grep "Trainingsmodus" returns ≥1 match (new entry)
    - grep "Freilos" returns ≥2 matches (entry + walkthrough mention)
    - grep "Default{n}" returns ≥2 matches
    - grep "T-Plan vs. Default-Plan" returns ≥1 match
    - grep -F "Default5" returns 0 (wrong plan name removed)
    - grep -F "DefaultS" returns 0
    - grep -F "Bälle-Ziel (innings_goal)" returns 0 (wrong merged entry removed)
    - grep -F "ClubCloud-Datenbank bezogen" returns 0 (Rangliste source corrected)
    - grep -F "Phase 36 wird dieses Status-Badge" returns 0 (false promise removed)
  </acceptance_criteria>
  <done>Glossar section in DE file is fully rewritten with correct entries and 6 new entries; all forward links from earlier walkthrough corrections now resolve to existing glossary terms.</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Glossar rewrite to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (current Glossar section)
    - docs/managers/tournament-management.de.md (after Task 1 — authoritative source)
  </read_first>
  <action>
Mirror Task 1 edits in EN. Translate each new entry idiomatically while keeping German technical terms in parentheses where appropriate (e.g., "Target balls (Ballziel, `balls_goal`)").

**Edit 1 — Replace the Target balls entry and split into two**

OLD entry "Target balls / innings_goal (Bälle-Ziel)" → NEW two separate entries:
```
- **Target balls (Ballziel, `balls_goal`)** — The number of points (caroms) a player must score to win a match. The database field is called `balls_goal`. For Freie Partie Class 1–3, typically **150 balls** (optionally reduced by 20 %). The Carom Sport Regulations are authoritative. *You configure this value in the [start form, Step 7](#step-7-start-form).*

- **Inning limit (Aufnahmebegrenzung, `innings_goal`)** — Maximum number of innings per match. The database field is `innings_goal`. For Freie Partie Class 1–3, typically **50 innings** (optionally reduced by 20 %). **Empty field or 0 = unlimited.** *You configure this value in the [start form, Step 7](#step-7-start-form).*

- **"Bälle vor" (handicap value)** — An **individual handicap value per player** used in handicap tournaments. Not to be confused with the general target-balls parameter — in handicap tournaments each player gets a different value.
```

**Edit 2 — Update Inning entry to remove the now-duplicated inning-limit info**

OLD "Inning (Aufnahme)" entry — NEW:
```
- **Inning (Aufnahme)** — One inning is one turn at the table: the player continues shooting until they fail to score or reach the [target balls](#glossary-karambol). The [inning limit](#glossary-karambol) sets the maximum number of innings per match. *You see this term in the [start form, Step 7](#step-7-start-form).*
```

**Edit 3 — Replace the Seeding-list entry and add Meldeliste + Teilnehmerliste neighbours**

NEW:
```
- **Seeding list (Setzliste)** — The **ordered** list of registrants (position 1 = top seed, position N = bottom). Three possible sources:
    1. **Official seeding list from the invitation** (the normal case) — produced by the regional sports officer from his spreadsheets
    2. **Carambus-internal seeding list** (the fallback case without invitation) — derived from the Carambus-internal [rankings](#glossary-system) via "Sort by ranking" in [Step 4](#step-4-participants)
    3. **Not from ClubCloud** — ClubCloud only carries registration lists, not seeding lists

- **Registration list (Meldeliste)** — **Snapshot of the seeding list at the close of registration** — who is officially registered for the tournament. Comes from ClubCloud and is provisional: it can still change up to tournament day (late registrations, withdrawals). Cross-reference the term hierarchy in [Step 1](#step-1-invitation).

- **Participant list (Teilnehmerliste)** — Who **actually** shows up on tournament day. Finalised shortly before the tournament starts. The result of the registration list minus no-shows plus any [late registrations](#appendix-nachmeldung). Finalisation happens in [Step 5](#step-5-finish-seeding).
```

**Edit 4 — Replace Tournament-plan codes entry**

NEW:
```
- **Tournament-plan codes (T-plan vs. Default plan)** — Carambus knows two kinds of tournament plans:
    - **T-nn** (for example T04, T05) — predefined plans from the **Carom Tournament Regulations** with fixed match structure and fixed table count. Useful for standard player counts in round-robin format.
    - **`Default{n}`** — a **dynamically generated** round-robin plan where `{n}` is the participant count. Created automatically when no T-plan fits; the required table count is computed from the participant count.

  *You select the plan in [Step 6](#step-6-mode-selection).*
```

**Edit 5 — Replace Scoreboard entry**

NEW:
```
- **Scoreboard** — The touch-enabled input device at each table (table monitor, smartphone, or web client) used by players or an assistant to enter points live during a match. The scoreboard-to-table binding is **not fixed**: at the scoreboard the operator picks the matching physical table, and the binding is established via the [TableMonitor](#glossary-system) of the logical table. The binding can be re-selected at the scoreboard when needed (for example if a table monitor fails).
```

**Edit 6 — Replace AASM-Status entry**

NEW:
```
- **AASM status (AASM-Status)** — The internal state of the tournament managed by the AASM state machine (Acts As State Machine). Possible states include `new_tournament`, `tournament_seeding_finished`, `tournament_started_waiting_for_monitors`, `tournament_started`, and others. Important: the wizard step display does **not** map one-to-one to AASM states — for example, Steps 4 and 5 are action links on a single state's page, not separate states (see [Step 5](#step-5-finish-seeding)). A more prominent status badge in the wizard is an open improvement area.
```

**Edit 7 — Replace Ranking entry**

NEW:
```
- **Ranking (Rangliste)** — A **Carambus-internal** player ranking that is updated per player from **Carambus's own tournament results** (so it is not sourced from ClubCloud). It serves as the default sort criterion when no official seeding list from an invitation is available. In [Step 4](#step-4-participants) you can use "Sort by ranking" to automatically order the participant list by ranking position.
```

**Edit 8 — Append new entries to System terms section**

```
- **Logical table (Logischer Tisch)** — A TournamentPlan-internal table identity (for example "Table 1", "Table 2" within T04). Logical tables are mapped to physical tables when the tournament starts in [Step 7](#step-7-start-form). The TournamentPlan references only logical table names — individual matches are automatically assigned to logical tables.

- **Physical table (Physikalischer Tisch)** — A specific, numbered playing table in the venue (for example "BG Hamburg Table 1"). From the players' perspective only physical tables exist — the numbers are on the tables and the who-plays-where information is on the scoreboards and table monitors. When the tournament starts, each logical table is mapped to a physical one (see [Step 7](#step-7-start-form), Table assignment).

- **TableMonitor** — A technical record / "automaton" that drives the activity at a [logical table](#glossary-system) during a match: match assignments, score capture, round changes. From the players' perspective: a bot that decides which match runs at which table. Each logical table has one TableMonitor; all scoreboards that connect to the corresponding physical table receive match updates via this TableMonitor.

- **Tournament Monitor (Turnier-Monitor)** — The top-level component that coordinates all [TableMonitors](#glossary-system) of a tournament. The Tournament Monitor is both the technical coordinator and the overview page that the tournament director opens from [Step 9](#step-9-start) onwards.

- **Training mode (Trainingsmodus)** — A scoreboard operating mode **outside any tournament context**, for running individual matches (training, friendly games). Also used as a **fallback** when a running tournament can no longer be continued in Carambus (see [Tournament already started](#ts-already-started)).

- **Bye (Freilos)** — When the participant count is odd (for example 5 players, 2 tables), one player cannot play in a given round — they have a bye. The assignment is automatic, derived from the [tournament plan](#glossary-wizard). Note: a mid-tournament match abort (for example when a player drops out during the tournament) is **not properly supported** in the current Carambus version — see follow-up phase v7.1+.
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "Target balls (Ballziel" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Inning limit" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Registration list (Meldeliste)" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Logical table" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Physical table" docs/managers/tournament-management.en.md &amp;&amp; grep -c "TableMonitor" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Training mode" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Bye (Freilos)" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Default{n}" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Default5" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "sourced from the ClubCloud database" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Phase 36 will make this status badge more prominent" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - All 8 new EN glossary entries exist (Target balls, Inning limit, Bälle vor, Registration list, Participant list, Logical table, Physical table, TableMonitor, Tournament Monitor, Training mode, Bye)
    - grep "Default{n}" returns ≥2 matches
    - grep -F "Default5" returns 0 in EN
    - grep -F "sourced from the ClubCloud database" returns 0 (Ranking entry corrected)
    - grep -F "Phase 36 will make this status badge more prominent" returns 0 (false promise removed)
  </acceptance_criteria>
  <done>EN glossary mirrors DE glossary; same set of entries, same forward-link targets.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Glossary entries should be parallel between DE and EN
for term in "Logischer Tisch|Logical table" "TableMonitor" "Trainingsmodus|Training mode" "Freilos|Bye"; do
  DE=$(grep -cE "$term" docs/managers/tournament-management.de.md)
  EN=$(grep -cE "$term" docs/managers/tournament-management.en.md)
  echo "$term: DE=$DE EN=$EN"
done
```
</verification>

<success_criteria>
- F-36-39 through F-36-50 are all addressed
- DOC-ACC-01 (Begriffshierarchie consistency) is satisfied through the glossary entries
- DOC-ACC-03 (new glossary entries) is fully covered: Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos, T-Plan vs. Default-Plan
- All forward links from Plans 01-03 walkthrough corrections now resolve to a defined glossary entry
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-04-SUMMARY.md`.
</output>
