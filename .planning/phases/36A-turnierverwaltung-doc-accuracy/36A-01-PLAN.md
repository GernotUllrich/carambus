---
phase: 36A
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - docs/managers/tournament-management.de.md
  - docs/managers/tournament-management.en.md
autonomous: true
requirements:
  - DOC-ACC-01
  - DOC-ACC-02
must_haves:
  truths:
    - "Szenario paragraph names PDF as primary source and points to special-case appendices"
    - "Step 1 introduces Begriffshierarchie (Meldeliste vs. Setzliste vs. Teilnehmerliste) and mentions Ausspielziele (Ballziel/Aufnahmebegrenzung)"
    - "Step 2 explains how to navigate to the tournament detail page (Organisationen → Regionalverbände → NBV → Aktuelle Turniere)"
    - "Step 3 (Setzliste) no longer frames PDF vs. ClubCloud as either-or; describes setzliste as a result of (Meldeliste + Ordnung)"
    - "Step 4 has a navigation paragraph listing the three entry points to the participant edit page"
    - "Step 4 explicitly mentions the 'Spieler hinzufügen' click for DBU number entry"
    - "Step 5 warning block is rewritten to mention the Reset link instead of claiming irreversibility"
    - "Step 5 no longer claims AASM state name 'tournament_seeding_finished' as user-facing"
    - "Schritt-4-as-action-link concept is documented (no separate AASM state)"
  artifacts:
    - path: "docs/managers/tournament-management.de.md"
      provides: "Block-1+2 corrections applied (lines 6-62)"
    - path: "docs/managers/tournament-management.en.md"
      provides: "Mirrored Block-1+2 corrections (English)"
  key_links:
    - from: "step-1-invitation"
      to: "appendix-no-invitation, appendix-missing-player, appendix-nachmeldung"
      via: "forward references in Szenario + Schritt 1"
      pattern: "appendix-(no-invitation|missing-player|nachmeldung)"
---

<objective>
Apply all factual corrections from review blocks 1 and 2 (F-36-01 through F-36-11) to both the DE and EN tournament-management walkthrough — Szenario, Schritt 1 (NBV-Einladung), Schritt 2 (Turnier laden), Schritt 3 (Setzliste), Schritt 4 (Teilnehmerliste prüfen), and Schritt 5 (Teilnehmerliste abschließen).

Purpose: Establish the correct Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste), remove the false either-or framing of PDF vs. ClubCloud, document the three entry points into the participant edit page, fix the misleading "irreversible" warning block, and remove the false claim that Schritt 4 is its own AASM state.

Output: Updated DE + EN files with lines 6-62 (DE) / equivalent EN lines rewritten per F-36-01..F-36-11 action items.
</objective>

<execution_context>
@.claude/get-shit-done/workflows/execute-plan.md
@.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/REQUIREMENTS.md
@.planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md
@docs/managers/tournament-management.de.md
@docs/managers/tournament-management.en.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Apply Block 1+2 corrections to tournament-management.de.md</name>
  <files>docs/managers/tournament-management.de.md</files>
  <read_first>
    - docs/managers/tournament-management.de.md (lines 1-65)
    - .planning/phases/36-small-ux-fixes/36-DOC-REVIEW-NOTES.md lines 33-256 (Block 1 + Block 2 findings F-36-01..F-36-11)
  </read_first>
  <action>
Apply the following exact edits to docs/managers/tournament-management.de.md. Use string-precise Edit tool calls.

**Edit 1 — Szenario (line 8) — F-36-01 Tier A**

OLD:
```
Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur **NDM Freie Partie Klasse 1–3** erhalten. Das Turnier läuft an einem Samstag in Ihrem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen. Diese Seite begleitet Sie Schritt für Schritt vom Eingang der Einladung bis zum Ergebnis-Upload zurück in die ClubCloud.
```

NEW:
```
Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur **NDM Freie Partie Klasse 1–3** per E-Mail als PDF erhalten. Dieses PDF dient im Normalfall als Start-Unterlage für das Turnier-Management. Das Turnier läuft an einem Samstag in Ihrem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen. Diese Seite begleitet Sie Schritt für Schritt vom Eingang der Einladung bis zur Abgabe der Ergebnisse an die ClubCloud.

Für abweichende Spezialfälle finden sich im Anhang spezialisierte Abläufe:

- **[Einladung fehlt](#appendix-no-invitation)** — Ablauf ohne PDF-Einladung
- **[Spieler fehlt](#appendix-missing-player)** — Umgang mit nicht-erschienenen gemeldeten Spielern
- **[Spieler wird nachgemeldet](#appendix-nachmeldung)** — On-site-Nachmeldung am Turniertag
```

**Edit 2 — Walkthrough-Einleitung (line 13) — F-36-15 META Tier A (intro hint about Schritt-Numerierung)**

OLD:
```
Die folgende Anleitung orientiert sich am tatsächlichen Ablauf des Carambus-Wizards — so wie er in der Praxis funktioniert. Wo die Oberfläche ungewohnte Formulierungen oder unerwartetes Verhalten zeigt, finden Sie einen farbigen Hinweiskasten.
```

NEW:
```
Die folgende Anleitung orientiert sich am tatsächlichen Ablauf des Carambus-Wizards — so wie er in der Praxis funktioniert. Wo die Oberfläche ungewohnte Formulierungen oder unerwartetes Verhalten zeigt, finden Sie einen farbigen Hinweiskasten.

!!! info "Schritt-Nummerierung ist logisch, nicht UI-eins-zu-eins"
    Die im Folgenden nummerierten Schritte 1–14 sind eine **logisch-chronologische** Aufzählung. Die zugehörigen UI-Screens sind historisch gewachsen und zählen teilweise anders: Schritte 2–5 liegen alle auf der Wizard-Seite, Schritt 6 hat einen eigenen Mode-Selection-Screen, Schritte 7–8 sind dieselbe Parametrisierungsseite, ab Schritt 9 wechselt der Ablauf in den Turnier-Monitor und die Tisch-Scoreboards. Während des laufenden Spielbetriebs (Schritte 10–12) hat der Turnierleiter im Standardfall **keine aktive Rolle** — die Aktionen finden alle an den Scoreboards statt.
```

**Edit 3 — Schritt 1 (line 18) — F-36-02 Tier A + Tier C (Begriffshierarchie + Ausspielziele)**

OLD:
```
Sie erhalten vom Landessportwart per E-Mail eine PDF-Einladung zur NDM. Die Einladung enthält den offiziellen Turnierplan, die Teilnehmerliste (Setzliste) und die Startzeiten. Sie müssen in diesem Schritt noch nichts im System klicken — öffnen Sie die Einladung, legen Sie das PDF bereit, und öffnen Sie dann in Carambus die Turnier-Detailseite des NDM-Turniers.
```

NEW:
```
Sie erhalten vom Landessportwart per E-Mail eine PDF-Einladung zur NDM. Die Einladung enthält den offiziellen Turnierplan, die **Meldeliste** (Setzliste-Snapshot nach dem Meldeschluss) und die Startzeiten. Außerdem stehen in der Einladung die **Ausspielziele** für die Disziplin: das **Ballziel** (allgemein für alle Spieler bei Normalturnieren, oder individuell pro Spieler bei Vorgabeturnieren) und die **Aufnahmebegrenzung**. Diese Werte tragen Sie später in [Schritt 7](#step-7-start-form) in das Start-Formular ein.

Drei Begriffe sollten Sie auseinanderhalten — sie beschreiben dieselben Spieler zu unterschiedlichen Zeitpunkten:

- **Setzliste** — geseedete/geordnete Liste der Anmelder, gepflegt während der Meldeperiode
- **Meldeliste** — Snapshot der Setzliste nach dem Meldeschluss (das, was in der Einladung steht)
- **Teilnehmerliste** — wer **tatsächlich** am Turniertag antritt (wird kurz vor Turnierbeginn finalisiert)

Im [Glossar](#glossary-wizard) finden Sie die Begriffe noch einmal mit ihrem zeitlichen Zusammenhang.

Sie müssen in diesem Schritt noch nichts im System klicken — öffnen Sie die Einladung, legen Sie das PDF bereit, und öffnen Sie dann in Carambus die Turnier-Detailseite des NDM-Turniers.
```

**Edit 4 — Schritt 2 (insert before line 21) — F-36-03 Tier C (Navigationspfad)**

OLD (the heading + first paragraph at lines 20-23):
```
<a id="step-2-load-clubcloud"></a>
### Schritt 2: Turnier aus ClubCloud laden (Wizard Schritt 1)

Öffnen Sie die Turnier-Detailseite in Carambus. Oben auf der Seite sehen Sie den Wizard-Fortschrittsbalken „Turnier-Setup". Schritt 1 „Meldeliste von ClubCloud laden" ist in der Regel bereits automatisch abgeschlossen — ein grüner Haken (GELADEN) zeigt an, dass Carambus die Meldeliste bereits synchronisiert hat.
```

NEW:
```
<a id="step-2-load-clubcloud"></a>
### Schritt 2: Turnier aus ClubCloud laden (Wizard Schritt 1)

**Navigation zur Turnierseite:** Im Carambus-Hauptmenü öffnen Sie **Organisationen → Regionalverbände → NBV** und klicken dort auf den Link **„Aktuelle Turniere in der Saison 2025/2026"** (die Saison ist dynamisch). In der Turnierliste wählen Sie das passende Turnier aus (im Beispielszenario „NDM Freie Partie Klasse 1–3").

Auf der Turnier-Detailseite sehen Sie oben den Wizard-Fortschrittsbalken „Turnier-Setup". Schritt 1 „Meldeliste von ClubCloud laden" ist in der Regel bereits automatisch abgeschlossen — ein grüner Haken (GELADEN) zeigt an, dass Carambus die Meldeliste bereits synchronisiert hat.
```

**Edit 5 — Schritt 2 caption (line 28) — F-36-04 Tier A (caption ehrlich machen)**

OLD:
```
*Abbildung: Turnier-Setup-Wizard direkt nach dem ClubCloud-Sync (Beispiel aus dem Phase-33-Audit, NDM Freie Partie Klasse 1–3).*
```

NEW:
```
*Abbildung: Turnier-Setup-Wizard nach erfolgreichem ClubCloud-Sync — die typische Standard-Darstellung, wenn der Sync vollständig durchgelaufen ist (Beispiel aus dem Phase-33-Audit, NDM Freie Partie Klasse 1–3). Den im Achtung-Block beschriebenen 1-Spieler-Fall illustriert dieses Bild **nicht** — er tritt nur bei unvollständigem Sync auf.*
```

**Edit 6 — Schritt 3 (lines 31-35) — F-36-05 Tier A (Setzliste-Konzept)**

OLD:
```
<a id="step-3-seeding-list"></a>
### Schritt 3: Setzliste übernehmen — Einladung oder ClubCloud-Meldeliste

In Wizard-Schritt 2 können Sie die Setzliste (die geordnete Teilnehmerliste) aus zwei Quellen übernehmen: entweder durch **Upload der PDF-Einladung** oder durch Übernahme der **ClubCloud-Meldeliste** als Alternative.

Die aktuelle Oberfläche stellt den PDF-Upload als primäre Option dar und ClubCloud als „Alternative" — für Vereine, die ClubCloud als offizielle Anmeldequelle nutzen, ist das umgekehrt. Wenn Sie das NBV-Einladungs-PDF hochladen, zeigt Carambus anschließend einen Vergleich beider Setzlisten nebeneinander, damit Sie Abweichungen erkennen können. Wenn das PDF-Upload fehlschlägt (häufig bei bestimmten Druckvorlagen), nutzen Sie direkt die ClubCloud-Liste — details dazu unter [Einladungs-PDF konnte nicht hochgeladen werden](#ts-invitation-upload).
```

NEW:
```
<a id="step-3-seeding-list"></a>
### Schritt 3: Setzliste übernehmen oder erzeugen

Die **Setzliste** ist ein **Ergebnis**: Meldeliste plus Ordnung. Die Ordnung wird normalerweise vom Landessportwart in der Einladung vorgegeben (anhand seiner Spreadsheets mit den zusammengeführten Turnierergebnissen). Sie ist keine Quelle, die Sie irgendwoher „herunterladen".

**Im Normalfall (mit Einladung):** Sie laden das PDF der Einladung in Wizard-Schritt 2 hoch. Carambus liest die Setzliste aus dem PDF und gleicht sie anschließend mit der ClubCloud-Meldeliste ab. Abweichungen werden Ihnen zur Klärung angezeigt.

**Wenn die Einladung fehlt:** Sie übernehmen die initiale Teilnehmerliste aus der ClubCloud-Meldeliste (orientiert am Meldestatus zum Meldeschluss) und ordnen sie anschließend in [Schritt 4](#step-4-participants) per Klick auf **„Nach Ranking sortieren"** anhand der in Carambus gepflegten [Rangliste](#glossary-system) — den vollständigen Ablauf finden Sie im Anhang [Einladung fehlt](#appendix-no-invitation).

Wenn das PDF-Upload technisch fehlschlägt (häufig bei bestimmten Druckvorlagen), lesen Sie [Einladungs-PDF konnte nicht hochgeladen werden](#ts-invitation-upload).
```

**Edit 7 — Schritt 4 navigation paragraph (insert after line 38) — F-36-06 Tier C (drei Einstiegspunkte)**

OLD (line 38-40):
```
<a id="step-4-participants"></a>
### Schritt 4: Teilnehmerliste prüfen und ergänzen (Wizard Schritt 3)

In Wizard-Schritt 3 „Teilnehmerliste bearbeiten" sehen Sie die aktuell vorhandenen Teilnehmer. Fehlen Spieler, fügen Sie diese über das Feld **„Spieler mit DBU-Nummer hinzufügen"** hinzu. Mehrere [DBU-Nummern](#glossary-system) können Sie komma-getrennt eintragen (Beispiel: `121308, 121291, 121341, 121332`).
```

NEW:
```
<a id="step-4-participants"></a>
### Schritt 4: Teilnehmerliste prüfen und ergänzen (Wizard Schritt 3)

**Wie komme ich in die Teilnehmerliste-Bearbeitung?** Es gibt drei mögliche Einstiegspunkte, abhängig vom aktuellen Wizard-Zustand:

1. **Direkt aus Schritt 3** — nachdem Sie in Schritt 3 die Setzliste übernommen haben, leitet Sie der Wizard automatisch in die Bearbeitung weiter
2. **Über den Button am unteren Ende der Turnierseite** — auch wenn Wizard-Schritt 3 noch nicht aktiv ist, ist der Zugang über diesen Bottom-Link möglich
3. **Über die Aktion „Einladung hochladen"** — auch wenn Sie keine Einladung haben, ist dieser Eingangspunkt nutzbar: im Einladungs-Hochladen-Formular finden Sie den Link **„→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)"**

Die Mehrfach-UX ist historisch gewachsen — alle drei Wege landen auf derselben Bearbeitungsseite.

In Wizard-Schritt 3 „Teilnehmerliste bearbeiten" sehen Sie die aktuell vorhandenen Teilnehmer. Fehlen Spieler, tragen Sie deren [DBU-Nummern](#glossary-system) komma-getrennt im Feld **„Spieler mit DBU-Nummer hinzufügen"** ein (Beispiel: `121308, 121291, 121341, 121332`) und klicken anschließend auf den Link **„Spieler hinzufügen"**, um die Eingabe anzuwenden.
```

**Edit 8 — Schritt 4 sofort-gespeichert-Hinweis (line 46) — F-36-08 Tier A**

OLD:
```
Alle Änderungen werden sofort gespeichert; ein Bestätigungs-Klick ist nicht nötig.
```

NEW:
```
Die meisten Änderungen — Sortierung, in-place-Edits einzelner Felder — werden sofort gespeichert. **Ausnahme:** Für das Hinzufügen neuer Spieler per DBU-Nummer ist der Klick auf den Link **„Spieler hinzufügen"** erforderlich.
```

**Edit 9 — Schritt 4 T04-Klammerzusatz (line 44) — F-36-07 Tier A**

OLD:
```
Sobald die Teilnehmerzahl einem vordefinierten [Turnierplan](#glossary-wizard) entspricht, erscheint unter der Teilnehmerliste ein gelb hervorgehobenes Panel **„Mögliche Turnierpläne für N Teilnehmer — automatisch vorgeschlagen: T04"**. Bei 5 Teilnehmern wird Ihnen T04 vorgeschlagen. Das ist der beste Hinweis, dass die Teilnehmerzahl stimmt — wenn kein Plan vorgeschlagen wird, überprüfen Sie die Teilnehmerzahl. Die endgültige Modusauswahl erfolgt erst in Schritt 6.
```

NEW:
```
Sobald die Teilnehmerzahl einem vordefinierten [Turnierplan](#glossary-wizard) entspricht, erscheint unter der Teilnehmerliste ein gelb hervorgehobenes Panel **„Mögliche Turnierpläne für N Teilnehmer — automatisch vorgeschlagen: T04"**. Bei 5 Teilnehmern wird Ihnen T04 vorgeschlagen (die Planbezeichnungen wie T04 stammen aus der offiziellen Karambol-Turnierordnung). Das ist der beste Hinweis, dass die Teilnehmerzahl stimmt — wenn kein Plan vorgeschlagen wird, überprüfen Sie die Teilnehmerzahl. Die endgültige Modusauswahl erfolgt erst in Schritt 6.
```

**Edit 10 — Schritt 5 (lines 49-61) — F-36-09 + F-36-10 + F-36-11 Tier A (Warning-Block + AASM-Name + Schritt-4-ist-kein-State)**

OLD (the entire Schritt-5 block, lines 48-61):
```
<a id="step-5-finish-seeding"></a>
### Schritt 5: Teilnehmerliste abschließen (Wizard Schritt 4)

Wenn die Teilnehmerliste vollständig ist, klicken Sie in Wizard-Schritt 4 auf den blauen Button **„Teilnehmerliste abschließen"**. Damit wird die [Setzliste](#glossary-wizard) endgültig festgeschrieben und das Turnier geht in den Status `tournament_seeding_finished` über.

!!! warning "Teilnehmerliste abschließen ist endgültig"
    Der Klick auf **Teilnehmerliste abschließen** ist einmalig und nicht
    rückgängig zu machen. Prüfen Sie vorher die Teilnehmerliste sorgfältig —
    nach dem Abschließen springt der Wizard direkt zur Modus-Auswahl, und
    eine spätere Änderung der Teilnehmerliste ist nur noch über Admin-Eingriff
    möglich.
<!-- ref: F-09 -->

Nach dem Klick springt der Wizard-Fortschrittsbalken von Schritt 3 direkt auf Schritt 5 — Schritt 4 wird im Hintergrund automatisch erledigt und erscheint als erledigt. Diese Sprung-Darstellung ist verwirrend, aber inhaltlich korrekt. Der nächste aktive Schritt ist die Modus-Auswahl.
```

NEW:
```
<a id="step-5-finish-seeding"></a>
### Schritt 5: Teilnehmerliste abschließen

**Wichtig zum Verständnis:** Die im Wizard angezeigten „Schritt 4" und „Schritt 5" sind **keine eigenen Wizard-Zustände**, sondern **Aktions-Links** auf der Teilnehmerliste-Seite:

- **„Schritt 4: Teilnehmerliste bearbeiten"** — Link zur weiteren Bearbeitung der Teilnehmerliste
- **„Schritt 5: Teilnehmerliste abschließen"** — Link, der den State-Übergang auslöst und in die Turniermodus-Auswahl führt

Zwischen den beiden gibt es im Wizard keinen separaten Zustand. Der Wizard-Fortschrittsbalken springt nach dem Abschließen direkt zur Modus-Auswahl, weil „Schritt 4" eben nur ein Aktions-Link war.

Wenn die Teilnehmerliste vollständig ist, klicken Sie auf den Link **„Teilnehmerliste abschließen"**. Damit wird die [Setzliste](#glossary-wizard) festgeschrieben und das Turnier geht in den nächsten Wizard-Zustand über („Schritt 5: Turniermodus festlegen").

!!! warning "Teilnehmerliste abschließen — was ist möglich, was nicht"
    Der Klick auf **Teilnehmerliste abschließen** ist normalerweise verbindlich:
    Sie wechseln in die Turniermodus-Auswahl und können die Teilnehmerliste
    nicht über den normalen Wizard-Pfad mehr ändern. **Im Notfall** können Sie
    aber das gesamte Turnier-Setup über den Link **„Zurücksetzen des
    Turnier-Monitors"** am unteren Ende der Turnierseite zurücksetzen — das
    ist möglich, aber bei bereits laufendem Turnier mit Datenverlust
    verbunden (siehe [Schritt 12](#step-12-monitor) für die Details).
<!-- ref: F-09 -->
```
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "Meldeliste" docs/managers/tournament-management.de.md &amp;&amp; grep -c "Spieler hinzufügen" docs/managers/tournament-management.de.md &amp;&amp; grep -c "appendix-no-invitation" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "tournament_seeding_finished" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "Teilnehmerliste (Setzliste)" docs/managers/tournament-management.de.md &amp;&amp; ! grep -F "endgültig festgeschrieben" docs/managers/tournament-management.de.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "Meldeliste" returns ≥3 matches in DE file
    - grep "Spieler hinzufügen" returns ≥2 matches
    - grep "appendix-no-invitation" returns ≥1 match (forward link to appendix Plan 06 will create)
    - grep "Organisationen → Regionalverbände → NBV" returns ≥1 match
    - grep -F "tournament_seeding_finished" returns 0 (state name removed from user-facing text)
    - grep -F "Teilnehmerliste (Setzliste)" returns 0 (false synonym removed)
    - grep -F "Aktions-Links" returns ≥1 match (Schritt-4-not-a-state concept documented)
    - grep "Schritt 4 wird im Hintergrund automatisch erledigt" returns 0 (false claim removed)
    - grep "Zurücksetzen des Turnier-Monitors" returns ≥1 match (warning rewrite)
  </acceptance_criteria>
  <done>All 10 edits applied; grep verifications pass; file remains valid Markdown (no broken admonition blocks).</done>
</task>

<task type="auto">
  <name>Task 2: Mirror Block 1+2 corrections to tournament-management.en.md</name>
  <files>docs/managers/tournament-management.en.md</files>
  <read_first>
    - docs/managers/tournament-management.en.md (lines 1-65)
    - docs/managers/tournament-management.de.md (after Task 1 — read the new DE content as authoritative source for translation)
  </read_first>
  <action>
Mirror Task 1 edits into the EN file. The DE content from Task 1 is the authoritative source — translate each new German block into idiomatic English. Use the same anchor IDs and the same forward-link targets (`#appendix-no-invitation`, etc.).

**Edit 1 — Scenario (line 8) — F-36-01**

OLD:
```
As the tournament director for your club you have received an NBV invitation for the **NDM Freie Partie Class 1–3** — a regional carom tournament running one Saturday in your club's playing location with 5 registered players across two tables. This page walks you through running the tournament from the moment the invitation arrives to the moment the results are uploaded back to ClubCloud.
```

NEW:
```
As the tournament director for your club you have received an NBV invitation for the **NDM Freie Partie Class 1–3** by email as a PDF — a regional carom tournament running one Saturday in your club's playing location with 5 registered players across two tables. The PDF normally serves as your starting reference for managing the tournament. This page walks you through the run from the moment the invitation arrives to the moment the results reach ClubCloud.

For deviating special cases, dedicated flows live in the appendix:

- **[Invitation missing](#appendix-no-invitation)** — flow without a PDF invitation
- **[Player missing](#appendix-missing-player)** — handling registered players who do not show up
- **[Late registration on tournament day](#appendix-nachmeldung)** — on-site player registration
```

**Edit 2 — Walkthrough intro (line 13) — F-36-15**

OLD:
```
The following guide follows the actual flow of the Carambus wizard — as it works in practice. Where the interface uses unfamiliar labels or shows unexpected behaviour, you will find a coloured callout box explaining what to expect.
```

NEW:
```
The following guide follows the actual flow of the Carambus wizard — as it works in practice. Where the interface uses unfamiliar labels or shows unexpected behaviour, you will find a coloured callout box explaining what to expect.

!!! info "Step numbering is logical, not one-to-one with the UI"
    The steps numbered 1–14 below are a **logical-chronological** breakdown.
    The corresponding UI screens have grown historically and do not always
    map one-to-one: Steps 2–5 all live on the wizard page, Step 6 has its
    own mode-selection screen, Steps 7–8 are the same parametrisation page,
    and from Step 9 onwards the action moves into the Tournament Monitor
    and the table scoreboards. During match play (Steps 10–12) the
    tournament director normally has **no active role** — all actions
    happen at the scoreboards.
```

**Edit 3 — Step 1 (line 18) — F-36-02**

OLD:
```
You receive a PDF invitation from the regional sports officer by email for the NDM. The invitation contains the official tournament plan, the participant list (seeding list), and the start times. You do not need to click anything in the system yet — open the invitation, keep the PDF handy, and then open the tournament detail page in Carambus.
```

NEW:
```
You receive a PDF invitation from the regional sports officer by email for the NDM. The invitation contains the official tournament plan, the **registration list (Meldeliste)** — the seeding-list snapshot at the close of registration — and the start times. The invitation also lists the **playing targets** for the discipline: the **target balls** (a single value for normal tournaments, or an individual handicap value per player for handicap tournaments) and the **inning limit**. You enter these values into the start form in [Step 7](#step-7-start-form).

Three terms describe the same players at different points in time — keep them straight:

- **Seeding list (Setzliste)** — the seeded/ordered list of registrants, maintained throughout the registration period
- **Registration list (Meldeliste)** — snapshot of the seeding list at the close of registration (this is what the invitation contains)
- **Participant list (Teilnehmerliste)** — the players who **actually** show up on tournament day (finalised shortly before the tournament starts)

The [glossary](#glossary-wizard) covers all three terms with their temporal relationship.

You do not need to click anything in the system yet — open the invitation, keep the PDF handy, and then open the tournament detail page in Carambus.
```

**Edit 4 — Step 2 navigation (insert before existing first paragraph at line 23) — F-36-03**

OLD (lines 20-23):
```
<a id="step-2-load-clubcloud"></a>
### Step 2: Load tournament from ClubCloud (Wizard Step 1)

Open the tournament detail page in Carambus. At the top of the page you see the wizard progress bar "Tournament Setup". Step 1 "Load registration list from ClubCloud" is usually already completed automatically — a green tick (LOADED) indicates that Carambus has already synchronised the registration list.
```

NEW:
```
<a id="step-2-load-clubcloud"></a>
### Step 2: Load tournament from ClubCloud (Wizard Step 1)

**Navigating to the tournament page:** From the Carambus main menu, open **Organisations → Regional Federations → NBV** and click the link **"Current tournaments in season 2025/2026"** (the season is dynamic). In the tournament list, pick the right tournament (in the example scenario "NDM Freie Partie Class 1–3").

On the tournament detail page you see the wizard progress bar "Tournament Setup" at the top. Step 1 "Load registration list from ClubCloud" is usually already completed automatically — a green tick (LOADED) indicates that Carambus has already synchronised the registration list.
```

**Edit 5 — Step 2 caption (line 28) — F-36-04**

OLD:
```
*Figure: Tournament setup wizard right after ClubCloud sync (example from the Phase 33 audit, NDM Freie Partie Class 1–3).*
```

NEW:
```
*Figure: Tournament setup wizard after a successful ClubCloud sync — the typical default appearance when the sync completed in full (example from the Phase 33 audit, NDM Freie Partie Class 1–3). The 1-player edge case described in the warning callout is **not** illustrated here — it only occurs with an incomplete sync.*
```

**Edit 6 — Step 3 (lines 31-35) — F-36-05**

OLD:
```
<a id="step-3-seeding-list"></a>
### Step 3: Seeding list — invitation vs ClubCloud

In Wizard Step 2 you can import the seeding list (the ordered participant list) from two sources: either by **uploading the PDF invitation** or by using the **ClubCloud registration list** as an alternative.

The current interface presents the PDF upload as the primary option and ClubCloud as the "alternative" — for clubs that use ClubCloud as their official registration source, the logic is the reverse. If you upload the NBV invitation PDF, Carambus shows a side-by-side comparison of both seeding lists so you can spot any discrepancies. If the PDF upload fails (common with certain print templates), use the ClubCloud list directly — see [Invitation upload failed](#ts-invitation-upload) for details.
```

NEW:
```
<a id="step-3-seeding-list"></a>
### Step 3: Take over or generate the seeding list

The **seeding list** is a **result**: registration list plus an order. The order is normally provided by the regional sports officer in the invitation (based on his spreadsheets that consolidate prior tournament results). It is not a source you "download" from somewhere.

**The normal case (with invitation):** You upload the invitation PDF in Wizard Step 2. Carambus reads the seeding list from the PDF and reconciles it against the ClubCloud registration list. Discrepancies are surfaced for you to resolve.

**Without an invitation:** You start from the ClubCloud registration list (a snapshot at the close of registration) and then in [Step 4](#step-4-participants) you click **"Sort by ranking"** to order it by the [ranking](#glossary-system) maintained per player in Carambus — the full flow lives in the appendix [Invitation missing](#appendix-no-invitation).

If the PDF upload fails technically (common with certain print templates), see [Invitation upload failed](#ts-invitation-upload).
```

**Edit 7 — Step 4 navigation paragraph + Spieler-hinzufügen click (lines 38-40) — F-36-06 + F-36-08**

OLD:
```
<a id="step-4-participants"></a>
### Step 4: Review and add participants (Wizard Step 3)

In Wizard Step 3 "Edit participant list" you see the currently registered participants. If players are missing, add them using the **"Add player by DBU number"** field. You can enter multiple [DBU numbers](#glossary-system) comma-separated (example: `121308, 121291, 121341, 121332`).
```

NEW:
```
<a id="step-4-participants"></a>
### Step 4: Review and add participants (Wizard Step 3)

**How do I get into the participant edit page?** There are three possible entry points depending on the current wizard state:

1. **Directly from Step 3** — once you have taken over the seeding list in Step 3, the wizard forwards you automatically into the edit page
2. **Via the button at the bottom of the tournament page** — even when Wizard Step 3 is not yet active, this bottom link gives you access
3. **Via the "Upload invitation" action** — even without an invitation this entry point is usable: inside the invitation upload form there is a link **"→ With registration list to Step 3 (sorted by ranking)"**

This multi-path UX has grown historically — all three paths land on the same edit page.

In Wizard Step 3 "Edit participant list" you see the currently registered participants. If players are missing, enter their [DBU numbers](#glossary-system) comma-separated in the **"Add player by DBU number"** field (example: `121308, 121291, 121341, 121332`) and then click the **"Add player"** link to apply the entry.
```

**Edit 8 — Step 4 sofort-gespeichert (line 46) — F-36-08**

OLD:
```
All changes are saved immediately; no confirmation click is required.
```

NEW:
```
Most changes — sorting and in-place edits of individual fields — are saved immediately. **Exception:** Adding a new player by DBU number requires a click on the **"Add player"** link to apply the entry.
```

**Edit 9 — T04 parenthetical (line 44) — F-36-07**

OLD:
```
Once the number of participants matches a predefined [tournament plan](#glossary-wizard), a gold-highlighted panel **"Possible tournament plans for N participants — automatically suggested: T04"** appears below the participant list. With 5 participants, T04 is suggested. This is the best indicator that the participant count is correct — if no plan is suggested, check your participant count. The final mode selection happens in Step 6.
```

NEW:
```
Once the number of participants matches a predefined [tournament plan](#glossary-wizard), a gold-highlighted panel **"Possible tournament plans for N participants — automatically suggested: T04"** appears below the participant list. With 5 participants, T04 is suggested (the plan codes such as T04 come from the official Carom Tournament Regulations). This is the best indicator that the participant count is correct — if no plan is suggested, check your participant count. The final mode selection happens in Step 6.
```

**Edit 10 — Step 5 (lines 49-61 region) — F-36-09 + F-36-10 + F-36-11**

OLD:
```
<a id="step-5-finish-seeding"></a>
### Step 5: Close participant list (Wizard Step 4)
```

Use Read first to find the EN equivalent (around lines 48-61) and apply the parallel rewrite. The EN file's Step 5 begins around line 48 and includes the same warning callout structure. Replace it with this NEW content:

```
<a id="step-5-finish-seeding"></a>
### Step 5: Close the participant list

**Important conceptual note:** The wizard's "Step 4" and "Step 5" labels are **not separate wizard states** but **action links** on the participant list page:

- **"Step 4: Edit participant list"** — link back to further editing
- **"Step 5: Close participant list"** — link that triggers the state transition into mode selection

There is no separate state between the two. The wizard progress bar therefore jumps straight to mode selection after closing — because "Step 4" was just an action link.

When the participant list is complete, click the **"Close participant list"** link. The [seeding list](#glossary-wizard) is now committed and the tournament moves into the next wizard state ("Step 5: Choose tournament mode").

!!! warning "Closing the participant list — what is and isn't possible"
    Clicking **Close participant list** is normally binding: you move into
    mode selection and can no longer change the participant list through
    the normal wizard path. **In an emergency**, however, you can reset the
    entire tournament setup via the **"Reset tournament monitor"** link at
    the bottom of the tournament page — that is possible, but if the
    tournament is already running it destroys data (see
    [Step 12](#step-12-monitor) for details).
<!-- ref: F-09 -->
```

Locate the corresponding original block via Read and replace cleanly. Remove the old "the wizard progress bar jumps from Step 3 to Step 5 — Step 4 is automatically completed in the background" sentence as well.
  </action>
  <verify>
    <automated>cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api &amp;&amp; grep -c "registration list (Meldeliste)" docs/managers/tournament-management.en.md &amp;&amp; grep -c "Add player" docs/managers/tournament-management.en.md &amp;&amp; grep -c "appendix-no-invitation" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "tournament_seeding_finished" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "(seeding list)" docs/managers/tournament-management.en.md &amp;&amp; ! grep -F "Step 4 is automatically completed in the background" docs/managers/tournament-management.en.md</automated>
  </verify>
  <acceptance_criteria>
    - grep "registration list (Meldeliste)" returns ≥1 match
    - grep "Add player" returns ≥2 matches in EN file
    - grep "appendix-no-invitation" returns ≥1 match
    - grep "Organisations → Regional Federations → NBV" returns ≥1 match
    - grep -F "tournament_seeding_finished" returns 0 in EN file
    - grep -F "(seeding list)" returns 0 (false synonym removed in EN)
    - grep "action links" returns ≥1 match (Schritt-4-not-a-state concept mirrored)
    - grep "Reset tournament monitor" returns ≥1 match (warning rewrite mirrored)
  </acceptance_criteria>
  <done>EN file has all 10 edits applied with parallel structure to DE; same anchor IDs preserved; same forward-link targets used.</done>
</task>

</tasks>

<verification>
After both tasks complete, run from the project root:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
# Both files have the same number of new key terms
DE_MELDE=$(grep -c "Meldeliste" docs/managers/tournament-management.de.md)
EN_MELDE=$(grep -c "Meldeliste" docs/managers/tournament-management.en.md)
echo "DE Meldeliste: $DE_MELDE / EN Meldeliste: $EN_MELDE"

# Forward links to appendix exist in both
grep -l "appendix-no-invitation" docs/managers/tournament-management.de.md docs/managers/tournament-management.en.md
```

Both files must have ≥3 occurrences of "Meldeliste" and at least one `appendix-no-invitation` forward link.
</verification>

<success_criteria>
- F-36-01 through F-36-11 are addressed in BOTH language files
- DOC-ACC-01 (Begriffshierarchie) is consistently introduced in Schritt 1 and forwarded to glossary
- DOC-ACC-02 (factual corrections from blocks 1-2) is satisfied for these specific findings
- No newly introduced content references appendices that don't exist yet — but forward links use the planned `#appendix-no-invitation`, `#appendix-missing-player`, `#appendix-nachmeldung` IDs that Plan 06 will create
</success_criteria>

<output>
After completion, create `.planning/phases/36A-turnierverwaltung-doc-accuracy/36A-01-SUMMARY.md` documenting which findings were addressed, the exact line ranges modified, and any verification grep output.
</output>
