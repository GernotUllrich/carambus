---
phase: 36A
plan: 02
type: execute
wave: 2
depends_on: [36A-01]
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-02
must_haves:
  truths:
    - "Schritt 6 no longer hardcodes 'three cards' or 'DefaultS' — uses '`Default{n}`' wording"
    - "Schritt 7 lists the 7 essential parameters explicitly (Tischzuordnung, Aufnahmebegrenzung, Ballziel, Spielabschluss, auto_upload_to_cc, Timeout, Nachstoß)"
    - "Ballziel and Aufnahmebegrenzung are documented as TWO DISTINCT parameters with correct i18n keys (balls_goal vs innings_goal)"
    - "Schritte 7+8 are merged or marked as one parameter form, not two screens"
    - "Schritt 8 distinguishes logical from physical tables and explains the mapping is what the manager configures"
    - "Scoreboard-table binding is documented as not-fixed (manual selection at the scoreboard)"
    - "auto_upload_to_cc parameter is mentioned in Step 7 with a forward link to the appendix"
    - "Tip block 'check after the tournament' is corrected to 'before the tournament'"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "Block-3 corrections applied (lines 63-110)"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored Block-3 corrections (English)"
  key_links:
    - from: "step-7-start-form"
      to: "appendix-cc-upload"
      via: "auto_upload_to_cc bullet forward-link"
      pattern: "appendix-cc-upload"
---

<objective>
Apply all factual corrections from review block 3 (F-36-12 through F-36-23) to both DE and EN files — Schritt 6 (Turniermodus), Schritt 7 (Start-Parameter), and Schritt 8 (Tische). This is the largest single block of corrections and includes the Ballziel/Aufnahmebegrenzung disambiguation, the logical-vs-physical-table concept, and the auto_upload_to_cc parameter introduction.

Purpose: Eliminate the most factually wrong technical content in the walkthrough — the Ballziel/innings_goal mix-up, the made-up "three cards always" claim, the missing logical/physical table distinction, and the missing auto_upload_to_cc parameter. Merge Schritte 7+8 to honestly reflect that they are the same form page.

Output: Updated DE + EN files with lines 63-110 (DE) and equivalent EN region rewritten per F-36-12..F-36-23 action items.
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
  <name>Task 1: Apply Block 3 corrections to tournament-management.de.md (Schritte 6-8)</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (current state after Plan 36A-01, lines 60-115)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 259-510 (Block 3 findings F-36-12..F-36-23)
  </read_first>
  <action>
Apply the following exact edits to docs/managers/tournament-management.de.md.

**Edit 1 — Schritt 6 first paragraph (line 66) — F-36-12 + F-36-13 Tier A**

OLD:
```
Wizard-Schritt 5 öffnet eine separate Seite „Abschließende Auswahl des Austragungsmodus". Sie sehen drei Karten mit den verfügbaren [Turnierplänen](#glossary-wizard): typischerweise **T04**, **T05** und **DefaultS**. Jede Karte zeigt die Spielrunden-Zahl und Turniertage. Bei 5 Teilnehmern lautet der Vorschlag meist T04 (5 Spielrunden, 1 Turniertag, 2 Tische).
```

NEW:
```
Wizard-Schritt 5 öffnet eine separate Seite „Abschließende Auswahl des Austragungsmodus". Sie sehen **eine oder mehrere Karten** mit den verfügbaren [Turnierplänen](#glossary-wizard) — die Auswahl hängt von der Teilnehmerzahl ab und enthält nur Pläne, die zur aktuellen Teilnehmerzahl passen, plus den dynamisch generierten Plan **`Default{n}`**, wobei `{n}` die aktuelle Teilnehmerzahl ist.

`Default{n}` ist ein **dynamisch generierter Jeder-gegen-Jeden-Plan**, dessen benötigte Tischanzahl aus der Teilnehmerzahl berechnet wird. Die T-Pläne (T04, T05, …) haben dagegen feste Spielstruktur und Tischanzahl aus der Karambol-Turnierordnung.

Bei 5 Teilnehmern lautet der Vorschlag typischerweise **T04** (Standard für 5 Spieler aus der Sportordnung). Der **in der Einladung angegebene Turnierplan** ist im Normalfall der vom Landessportwart verbindlich vorgegebene — übernehmen Sie diesen Vorschlag.
```

**Edit 2 — Schritt 6 Tip-Block (lines 68-75) — F-36-13 Tier A — REMOVE**

OLD:
```
!!! tip "Welchen Turnierplan wählen?"
    Bei der Modus-Auswahl schlägt Carambus meist einen Plan automatisch vor
    (zum Beispiel **T04** bei 5 Teilnehmern). Übernehmen Sie den Vorschlag,
    wenn Sie nicht bewusst eine Alternative bevorzugen. Die Alternativen
    unterscheiden sich vor allem in der Zahl der Spielrunden und Turniertage
    — für eine typische NDM Freie Partie Klasse 1–3 ist der Vorschlag fast
    immer der richtige.
<!-- ref: F-12 -->
```

NEW: (delete entirely — leave just a blank line where the block was)

**Edit 3 — Schritte 7 + 8 — F-36-14 + F-36-15 + F-36-16 + F-36-17 + F-36-18 + F-36-19 + F-36-20 + F-36-21 + F-36-22 + F-36-23 — MERGE both steps and rewrite**

This is the biggest edit. Replace the entire region from `<a id="step-7-start-form"></a>` (currently around line 82) through the end of Schritt 8 (currently around line 109) with the new merged content below.

OLD region (Schritt 7 + Schritt 8 blocks together — read current file to get exact bounds, approximately lines 82-109 after Plan 01 edits):
```
<a id="step-7-start-form"></a>
### Schritt 7: Start-Parameter ausfüllen

Nach der Modusauswahl öffnet sich das Start-Formular. ...

[ ... entire Schritt 7 + Schritt 8 region ... ]

(Note that the file has been modified by Plan 36A-01 — re-read to find the actual current line numbers)
```

NEW (replaces entire Schritte-7-and-8 region):
```
<a id="step-7-start-form"></a>
### Schritt 7: Start-Parameter und Tischzuordnung ausfüllen

!!! info "Schritte 7 und 8 leben auf derselben Seite"
    Nach der Modusauswahl öffnet sich **eine** Parametrisierungsseite, die
    sowohl die Start-Parameter als auch die Tischzuordnung enthält. Im Doc
    sind sie aus didaktischen Gründen zwei Schritte — im UI ist es eine
    Seite.

Oben sehen Sie eine Zusammenfassung des gewählten Modus, darunter den Abschnitt **„Zuordnung der Tische"** und ein Formular **„Turnier Parameter"** mit den Spielregeln.

!!! tip "Englische Feldbezeichnungen im Start-Formular"
    Einige Parameter im Start-Formular heißen derzeit auf Englisch oder sind
    unklar beschriftet (zum Beispiel *Tournament manager checks results before
    acceptance* oder *Assign games as tables become available*). Das
    [Glossar](#glossary) unten erklärt die wichtigsten Begriffe. Im Zweifel
    übernehmen Sie die Standardwerte und kontrollieren Sie die Einstellungen
    **vor dem Start des Turniers**.
<!-- ref: F-14 -->

**Die wesentlichen Parameter, die Sie kennen müssen:**

- **Tischzuordnung** (siehe Abschnitt unten in diesem Schritt) — welche **physikalischen Tische** in Ihrem Spiellokal die **logischen Tische** des Turnierplans abbilden
- **Ballziel** (`balls_goal`): Das Ziel in Bällen, das ein Spieler für den Partie-Gewinn erreichen muss. Für Freie Partie Klasse 1–3 steht der Wert in der Einladung (typischerweise **150 Bälle**, ggf. um 20 % reduziert). Maßgeblich ist die Karambol-Sportordnung.
- **Aufnahmebegrenzung** (`innings_goal`): Maximale Aufnahmenzahl pro Partie. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. um 20 % reduziert). **Leerfeld oder 0 = unbegrenzt** (im UI nicht eindeutig dokumentiert — bitte hier nachlesen).
- **Spielabschluss** durch Manager oder durch Spieler — wer bestätigt das Ergebnis am Scoreboard nach Partie-Ende
- **`auto_upload_to_cc`** (Checkbox „Ergebnisse automatisch in ClubCloud hochladen") — wenn aktiviert, wird jedes Einzelergebnis sofort nach Spielende an die ClubCloud übertragen. Voraussetzungen und Alternativen siehe Anhang [ClubCloud-Upload — zwei Wege](#appendix-cc-upload).
- **Timeout-Kontrolle** — Schiedsrichter-Timer pro Aufnahme (disziplinabhängig)
- **Nachstoß** — Regelvariante in bestimmten Karambol-Disziplinen (wenn der Aufschläger das Ballziel erreicht, hat der Gegner einen Nachstoß)

Manche Parameter erscheinen nur bei bestimmten Disziplinen — z. B. ist der Nachstoß-Schalter nur sichtbar, wenn die gewählte Disziplin diese Regel verwendet.

> **Hinweis zu „Bälle vor":** In der UI-Beschriftung taucht zusätzlich der Ausdruck „Bälle vor" auf — das ist eine **individuelle Vorgabe bei Vorgabe-/Handikap-Turnieren** (jeder Spieler bekommt einen anderen Wert), nicht zu verwechseln mit dem allgemeinen Ballziel.

<a id="step-8-tables"></a>
#### Tischzuordnung (Unter-Abschnitt von Schritt 7)

Der gewählte Turnierplan definiert **logische Tischnamen** (z. B. „Tisch 1" und „Tisch 2" bei T04). In diesem Abschnitt ordnen Sie jedem **logischen Tisch** einen **physikalischen Tisch** aus Ihrem Spiellokal zu. Wählen Sie aus der Dropdown-Liste die zwei Tische in Ihrem Spiellokal aus. Für unser NDM-Szenario wählen Sie z. B. „BG Hamburg Tisch 1" und „BG Hamburg Tisch 2".

Die Zuordnung der einzelnen Spiele (Matches) zu den logischen Tischen erfolgt **automatisch** aus dem Turnierplan — der Turnierleiter muss nur die Verbindung logischer-Tisch → physikalischer-Tisch herstellen.

**Scoreboard-Verbindung:** Nach dem Turnierstart werden auf jedem physikalischen Tisch ein oder mehrere **Scoreboards** (Tisch-Monitore, Smartphones, Web-Clients) mit dem zugehörigen Tisch verbunden. Dazu wählt der Bediener am Scoreboard den passenden physikalischen Tisch aus — die Verbindung ist **nicht fest vorgegeben** und kann bei Bedarf am Scoreboard neu gewählt werden. Technisch geschieht die Vermittlung über den [TableMonitor](#glossary-system) des logischen Tischs.
```

(Note: the new merged section drops the old separate `### Schritt 8: Tische zuordnen` H3 heading and replaces it with `#### Tischzuordnung (Unter-Abschnitt von Schritt 7)` to honestly reflect that it's the same form page. The `<a id="step-8-tables"></a>` anchor is preserved so existing forward-links still work.)
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "balls_goal" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Default{n}" docs/managers/tournament-management.de.md &amp;&amp; grep -c "logischen Tisch" docs/managers/tournament-management.de.md &amp;&amp; grep -c "auto_upload_to_cc" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "DefaultS" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Bälle vor** / **Bälle-Ziel" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "ca. 15 Feldern" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "kontrollieren Sie die Einstellungen nach dem Turnier" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Welchen Turnierplan wählen?" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "balls_goal" returns ≥1 match
    - grep "Default{n}" returns ≥1 match
    - grep "logischen Tisch" returns ≥2 matches
    - grep "auto_upload_to_cc" returns ≥1 match
    - grep "appendix-cc-upload" returns ≥1 match (forward link to Plan 06 appendix)
    - grep -F "DefaultS" returns 0 (wrong plan name removed)
    - grep -F "Bälle vor** / **Bälle-Ziel" returns 0 (wrong concept-merge removed)
    - grep -F "ca. 15 Feldern" returns 0 (vague claim removed)
    - grep "nach dem Turnier" returns 0 in the tip block (replaced with "vor dem Start des Turniers")
    - grep -F "Welchen Turnierplan wählen?" returns 0 (redundant tip block removed)
    - grep "step-8-tables" returns ≥1 match (anchor preserved)
  </acceptance_criteria>
  <done>All Block-3 edits applied; merged Schritte 7+8 region is internally consistent; preserved anchor `step-8-tables` so cross-references continue to work.</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Block 3 corrections to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (current state, lines 60-115)
    - docs/managers/tournament-management.de.md (after Task 1 — authoritative source for the new content)
  </read_first>
  <action>
Mirror Task 1 edits in the EN file. Translate the new German content into idiomatic English while preserving the same anchor IDs (`step-7-start-form`, `step-8-tables`) and forward links (`appendix-cc-upload`).

**Edit 1 — Step 6 first paragraph — F-36-12 + F-36-13**

OLD:
```
Wizard Step 5 opens a separate page "Final selection of the playing format". You see three cards with the available [tournament plans](#glossary-wizard): typically **T04**, **T05**, and **DefaultS**. ...
```

NEW:
```
Wizard Step 5 opens a separate page "Final selection of the playing format". You see **one or more cards** with the available [tournament plans](#glossary-wizard) — the selection depends on the participant count and only shows plans that fit, plus the dynamically generated **`Default{n}`** plan where `{n}` is the current participant count.

`Default{n}` is a **dynamically generated round-robin plan**; its required table count is computed from the participant count. The T-plans (T04, T05, …) by contrast have fixed match structures and table counts taken from the official Carom Tournament Regulations.

With 5 participants, the typical suggestion is **T04** (the standard for 5 players in the regulations). The plan **specified in the invitation** is normally the binding one set by the regional sports officer — accept that suggestion.
```

**Edit 2 — Step 6 tip block — F-36-13 — REMOVE**

OLD:
```
!!! tip "Which tournament plan to choose?"
    ...
<!-- ref: F-12 -->
```

NEW: delete entirely.

**Edit 3 — Steps 7 + 8 merge — F-36-14..F-36-23**

Replace the entire region from `<a id="step-7-start-form"></a>` through the end of Step 8 with:

```
<a id="step-7-start-form"></a>
### Step 7: Start parameters and table assignment

!!! info "Steps 7 and 8 live on the same page"
    After mode selection, **one** parametrisation page opens that contains
    both the start parameters and the table assignment. The doc separates
    them into two steps for didactic reasons — in the UI they are one page.

At the top you see a summary of the selected mode, then the **"Table assignment"** section, and a form **"Tournament parameters"** with the playing rules.

!!! tip "English field labels in the start form"
    Some parameters in the start form are currently labelled in English or
    described unclearly (for example *Tournament manager checks results
    before acceptance* or *Assign games as tables become available*). The
    [glossary](#glossary) below explains the most important terms. When in
    doubt, accept the defaults and verify the settings **before starting
    the tournament**.
<!-- ref: F-14 -->

**The essential parameters you need to know:**

- **Table assignment** (see the section further down in this step) — which **physical tables** in your venue map to the **logical tables** of the tournament plan
- **Target balls** (`balls_goal`): The number of points (caroms) a player must score to win a match. For NDM Freie Partie Class 1–3 the value comes from the invitation (typically **150 balls**, optionally reduced by 20 %). The Carom Sport Regulations are authoritative.
- **Inning limit** (`innings_goal`): Maximum number of innings per match. For Freie Partie Class 1–3 typically **50 innings** (optionally reduced by 20 %). **Empty field or 0 = unlimited** (the UI does not document this clearly — please read it here).
- **Match closure** by the manager or by the players — who confirms the result at the scoreboard after a match ends
- **`auto_upload_to_cc`** (checkbox "Upload results automatically to ClubCloud") — if enabled, every individual result is uploaded to ClubCloud immediately after the match ends. See the appendix [ClubCloud upload — two paths](#appendix-cc-upload) for prerequisites and alternatives.
- **Timeout control** — referee timer per inning (discipline-dependent)
- **Nachstoß** — rule variant in certain carom disciplines (if the player who reaches the target was not the opener, the opponent gets one final inning to equalise)

Some parameters only appear for certain disciplines — for example the Nachstoß checkbox only shows when the chosen discipline uses that rule.

> **Note on "Bälle vor":** The UI label "Bälle vor" sometimes appears next to target balls — that is an **individual handicap value used in handicap tournaments** (each player gets a different value), not to be confused with the general target-balls parameter.

<a id="step-8-tables"></a>
#### Table assignment (sub-section of Step 7)

The chosen tournament plan defines **logical table names** (for example "Table 1" and "Table 2" for T04). In this sub-section you assign each **logical table** a **physical table** from your venue. Pick the two physical tables from the dropdown. For our NDM scenario, choose for example "BG Hamburg Table 1" and "BG Hamburg Table 2".

The assignment of individual matches to logical tables happens **automatically** from the tournament plan — the tournament director only has to set up the logical-to-physical table mapping.

**Scoreboard binding:** After the tournament starts, one or more **scoreboards** (table monitors, smartphones, web clients) are connected to each physical table. The scoreboard operator picks the matching physical table — the binding is **not fixed** and can be re-selected at the scoreboard at any time. Technically the routing happens through the [TableMonitor](#glossary-system) of the logical table.
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "balls_goal" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Default{n}" docs/managers/tournament-management.en.md &amp;&amp; grep -c "logical table" docs/managers/tournament-management.en.md &amp;&amp; grep -c "auto_upload_to_cc" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-cc-upload" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "DefaultS" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Which tournament plan to choose?" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "approximately 15 fields" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "verify the settings after the tournament" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "balls_goal" returns ≥1 match in EN
    - grep "Default{n}" returns ≥1 match in EN
    - grep "logical table" returns ≥3 matches in EN
    - grep "auto_upload_to_cc" returns ≥1 match in EN
    - grep "appendix-cc-upload" returns ≥1 match in EN
    - grep -F "DefaultS" returns 0 in EN
    - grep -F "Which tournament plan to choose?" returns 0 (tip block removed)
    - grep "before starting the tournament" returns ≥1 match (tip-block correction)
    - grep "step-8-tables" returns ≥1 match (anchor preserved)
  </acceptance_criteria>
  <done>EN file mirrors all DE Block-3 changes; structure is parallel; same anchors; same forward links.</done>
</task>

</tasks>

<verification>
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Both files mention all 7 essential parameters
for term in "balls_goal" "innings_goal" "auto_upload_to_cc" "Default{n}"; do
  DE=$(grep -c "$term" docs/managers/tournament-management.de.md)
  EN=$(grep -c "$term" docs/managers/tournament-management.en.md)
  echo "$term: DE=$DE EN=$EN"
done
```
</verification>

<success_criteria>
- F-36-12 through F-36-23 are addressed in both files
- DOC-ACC-02 (factual corrections from Block 3) is fully covered
- Schritte 7 and 8 are honestly merged (Step 8 is now a sub-section)
- The two-different-meanings of Ballziel vs. Aufnahmebegrenzung are unambiguous
- auto_upload_to_cc parameter exists in Step 7 with forward link to appendix
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-02-SUMMARY.md` documenting which findings were addressed and the resulting line ranges.
</output>
