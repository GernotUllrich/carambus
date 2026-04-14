# Phase 36 — Turnierverwaltung Doc Review (DE)

**Started:** 2026-04-13
**Source:** `docs/managers/tournament-management.de.md` (268 lines, Phase 34 output)
**Mode:** Interactive sentence-by-sentence review (Option C from discuss-phase)
**Phase 36 discuss-phase status:** paused until this review is complete

## Scope

- Primary: `docs/managers/tournament-management.de.md` (268 Zeilen, 14 Walkthrough-Steps)
- Secondary (after DE pass): `docs/managers/tournament-management.en.md`, `docs/managers/index.{de,en}.md`
- User is SME for correctness and missing-content items; Claude can only verify code-against-doc

## Finding Tiers (decided post-review)

- **Tier A** — pure doc fix (reword, add nuance, fix factual claim against code behavior; no code changes)
- **Tier B** — code + doc both need change (doc exposes a real code bug or design flaw that should be fixed)
- **Tier C** — new content section (topic is missing entirely, requires net-new prose and possibly new step coverage)

## Block Plan

| Block | Abschnitte | Zeilen | Status |
|-------|------------|--------|--------|
| 1 | Szenario, Schritt 1 (NBV-Einladung), Schritt 2 (Turnier laden) | 6–30 | pending |
| 2 | Schritt 3 (Setzliste), Schritt 4 (Teilnehmer), Schritt 5 (abschließen) | 31–63 | pending |
| 3 | Schritt 6 (Modus), Schritt 7 (Start-Parameter), Schritt 8 (Tische) | 64–111 | pending |
| 4 | Schritt 9 (Start), Schritt 10 (Warmup), Schritt 11 (Spielbeginn) | 112–145 | pending |
| 5 | Schritt 12 (Ergebnisse), Schritt 13 (finalisieren), Schritt 14 (Upload) | 146–172 | pending |
| 6 | Glossar (Karambol, Wizard, System) | 173–222 | pending |
| 7 | Problembehebung + Mehr zur Technik | 223–268 | pending |

## Findings

### Block 1: Szenario + Schritt 1 (NBV-Einladung) + Schritt 2 (Turnier laden)

**Reviewed:** 2026-04-13
**Zeilen:** 6–28

---

#### F-36-01 — Szenario: Rolle des Einladungs-PDFs + fehlende Sonderfall-Anhänge
- **Tier:** A + C
- **Zeile:** 8
- **Current:** "Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur NDM Freie Partie Klasse 1–3 erhalten. Das Turnier läuft an einem Samstag in Ihrem Spiellokal mit 5 gemeldeten Teilnehmern auf zwei Tischen."
- **Should say:**
  - Umformulieren: "Sie haben als Turnierleiter Ihres Vereins vom NBV eine Einladung zur **NDM Freie Partie Klasse 1–3** per E-Mail als PDF erhalten. Dieses PDF dient im Normalfall als Start-Unterlage für das Turnier-Management."
  - Danach direkter Verweis auf Sonderfall-Anhänge: "Für abweichende Spezialfälle finden sich im Anhang spezialisierte Abläufe:"
    - **Einladung fehlt** — Ablauf ohne PDF
    - **Spieler fehlt** — Umgang mit nicht-erschienenen gemeldeten Spielern
    - **Spieler wird nachgemeldet** — On-site-Nachmeldung
- **Action:**
  - Tier A: Umformulierung in Zeile 8
  - Tier C: **neuer Anhangs-Abschnitt am Ende des Dokuments** mit 3 Sonderfall-Abläufen (Einladung fehlt / Spieler fehlt / Spieler-Nachmeldung). Die Troubleshooting-Section (Z 223+) ist nicht dasselbe — diese Anhänge sind vollständige Alternativ-Abläufe, nicht Fehlerrezepte.

---

#### F-36-02 — Schritt 1: Begriffshierarchie Setzliste/Meldeliste/Teilnehmerliste + fehlende Ausspielziele
- **Tier:** A + C
- **Zeile:** 18
- **Current:** "Die Einladung enthält den offiziellen Turnierplan, die Teilnehmerliste (Setzliste) und die Startzeiten."

- **Issue 1 (Tier A — Begriffshierarchie): Drei distinct concepts werden als eines behandelt.**

  Die korrekte Begriffshierarchie (bestätigt vom SME):

  | Begriff | Definition | Zeitpunkt |
  |---------|------------|-----------|
  | **Setzliste** | Geseedete/geordnete Liste der Anmelder | Während der Meldeperiode |
  | **Meldeliste** | **Setzliste-Snapshot nach dem Meldeschluss** — wer ist offiziell gemeldet | Vom Meldeschluss bis Turniertag |
  | **Teilnehmerliste** | Wer **tatsächlich** am Turnier antritt | Kurz vor Turnierbeginn finalisiert |

  - Die Einladung enthält die **Meldeliste** (also die Setzliste nach Meldeschluss), NICHT die Teilnehmerliste. Der aktuelle Doc-Satz setzt "Teilnehmerliste" und "Setzliste" als Synonyme, was beides falsch ist.
  - Fix Zeile 18: "die Teilnehmerliste (Setzliste)" → "die **Meldeliste** (Setzliste nach Meldeschluss)"
  - Die Walkthrough-Schritte 4 und 5 (aktuell "Teilnehmerliste prüfen" / "Teilnehmerliste abschließen") sind terminologisch **korrekt** — sie beschreiben die Finalisierung der Teilnehmerliste vor Ort. Meine ursprüngliche Annahme, "Teilnehmerliste" sei dort falsch, war unkorrekt. In Block 2 prüfen, ob Schritt 4/5 den Übergang Meldeliste→Teilnehmerliste explizit machen.
  - Glossar (Block 6) muss **alle drei Begriffe** separat definieren, mit dem zeitlichen Zusammenhang.

- **Issue 2 (Tier C — fehlender Inhalt):**
  - Die Einladung enthält **Ausspielziele**, die später in Schritt 7 (Start-Parameter) konfiguriert werden:
    - **Aufnahmebegrenzung** (innings limit)
    - **Ballziel** — allgemein für alle Spieler bei Normalturnieren, oder **individuell pro Spieler bei Vorgabeturnieren**
  - Schritt 1 muss erwähnen, dass diese Ziele aus der Einladung kommen, damit der Turnierleiter sie in Schritt 7 richtig übernimmt.

- **Action:**
  - Tier A: Zeile 18 umformulieren — "Meldeliste (Setzliste nach Meldeschluss)" statt "Teilnehmerliste (Setzliste)"
  - Tier A: Dokumentdurchgang auf **alle drei Begriffe** (Setzliste / Meldeliste / Teilnehmerliste) zur Konsistenzprüfung — jeder Vorkommen muss im zeitlich korrekten Kontext stehen
  - Tier C: Ausspielziele in Schritt 1 einführen (Aufnahmebegrenzung, Ballziel allgemein vs. individuell bei Vorgabeturnieren)
  - Tier C: Vorwärtsverweis "siehe Schritt 7" an der Ausspielziele-Erwähnung
  - Tier A: Glossar (Block 6) — drei separate Einträge: **Setzliste**, **Meldeliste**, **Teilnehmerliste** mit zeitlichem Zusammenhang
  - Verifizieren: Gibt es im Code/im Wizard ein "Vorgabeturnier"-Flag oder einen `handicap`-Feldtyp? → spätere Konsistenzprüfung

---

#### F-36-03 — Schritt 2: Navigationspfad zur Turnierseite fehlt komplett
- **Tier:** C
- **Zeile:** 21–23
- **Current:** "Öffnen Sie die Turnier-Detailseite in Carambus. Oben auf der Seite sehen Sie den Wizard-Fortschrittsbalken..."
- **Issue:** Das Dokument überspringt die Frage "**wie** komme ich zur Turnier-Detailseite?" Für einen 2-3x/Jahr-Turnierleiter ist das eine Lücke.
- **Should say (neue Sub-Section oder Vorspann vor Zeile 23):**
  - Pfad: **Organisationen → Regionalverbände → NBV → "Aktuelle Turniere in der Saison 2025/2026"** (Linkname literal, Saison dynamisch)
  - Idealerweise Screenshot der NBV-Regionalverbandsseite mit der Turnierliste
  - Dann der Klick auf das spezifische Turnier ("NDM Freie Partie Klasse 1-3")
- **Action:**
  - Tier C: Neuer Absatz vor oder am Anfang von Schritt 2, der den Navigationspfad beschreibt
  - Tier C: Möglicher neuer Screenshot der Regionalverbandsseite / der Turnierliste (nicht im Phase-33-Screenshot-Fundus — müsste ggf. neu gemacht werden)
  - Verifizieren: Ist "Organisationen → Regionalverbände → NBV" tatsächlich der kanonische Navigationspfad im aktuellen UI? Evtl. mit Scout-Agent klären wenn anders benannt.

---

#### F-36-04 — Schritt 2: Abbildung zeigt nicht was die Bildunterschrift/Prosa behauptet
- **Tier:** A
- **Zeile:** 27–28
- **Current (caption):** "Abbildung: Turnier-Setup-Wizard direkt nach dem ClubCloud-Sync (Beispiel aus dem Phase-33-Audit, NDM Freie Partie Klasse 1–3)."
- **Issue:** Die Abbildung (`images/tournament-wizard-overview.png`) zeigt den Wizard nach ClubCloud-Sync — aber nicht den im Prosa-Text beschriebenen Fehlerfall mit nur 1 geladenem Spieler. Die begleitende "Achtung"-Prosa (Zeile 25) spricht vom 1-Spieler-Fall; die Abbildung illustriert ihn nicht.
- **Options:**
  - **Option A (einfach):** Bildunterschrift korrigieren — ehrlich beschreiben, was das Bild tatsächlich zeigt (z.B. "Wizard-Übersicht mit korrektem ClubCloud-Sync — die typische Darstellung nach dem Standard-Fall"), und die "Achtung" wird ohne Bild-Verankerung stehen gelassen
  - **Option B (besser):** Zweites Screenshot hinzufügen — der Phase-33-Fundus enthält möglicherweise bereits ein "1-Spieler-Edge-Case"-Bild (prüfen in `33-ux-review-wizard-audit/screenshots/`). Wenn ja, als zweite Abbildung neben der Standard-Abbildung einbauen.
- **Action:**
  - Tier A: Bildunterschrift korrigieren ODER zweites Screenshot aus Phase-33-Fundus einbauen
  - Verifizieren: `ls .planning/phases/33-ux-review-wizard-audit/screenshots/` — gibt es `01-show-initial.png` oder ähnliches das den 1-Spieler-Fall zeigt? (Nebenbemerkung: Phase-33-Screenshots sind bereits im Fundus, siehe `02-edit-seeding.png` etc.)

---

**Block 1 Zusammenfassung:**
- 4 Findings (F-36-01 bis F-36-04)
- Tier A: 5 Action-Items (pure Doc-Korrektur)
- Tier C: 4 Action-Items (neue Inhalts-Sections / Screenshots / Navigationspfad)
- Code-Verifikations-Tasks: 3 (Vorgabeturnier-Flag im Code, Navigationspfad-Labels, Phase-33-Screenshot-Fundus)

---

### Block 2: Schritt 3 (Setzliste) + Schritt 4 (Teilnehmerliste prüfen) + Schritt 5 (Teilnehmerliste abschließen)

**Reviewed:** 2026-04-13
**Zeilen:** 31–62

---

#### F-36-05 — Schritt 3: Setzliste-Konzept grundlegend falsch erklärt
- **Tier:** A + C (Doc-Fix groß, konzeptuell)
- **Zeile:** 33–35
- **Current:** "In Wizard-Schritt 2 können Sie die Setzliste (die geordnete Teilnehmerliste) aus zwei Quellen übernehmen: entweder durch Upload der PDF-Einladung oder durch Übernahme der ClubCloud-Meldeliste als Alternative."
- **Issue:** Die gesamte Konzeption ist falsch. Der SME-Input:
  - **Setzliste** = Meldeliste + Ranking-Ordnung **ODER** eine vom Landessportwart vorgegebene Reihenfolge nach anderen Kriterien
  - Die Setzliste ist nur in der Einladung vorhanden (vom Sportwart offiziell festgelegt)
  - Wenn die Einladung fehlt ODER wenn neue Spieler am Spieltag hinzukommen, kann die Reihenfolge vom Turnierleiter neu erzeugt werden — typischerweise anhand der in Carambus pro Spieler gepflegten Rankings
  - Dafür gibt es beim Editieren der Teilnehmerliste dedizierte Sortier-Buttons ("Nach Ranking sortieren")
  - **Die Alternative "PDF-Upload vs. ClubCloud" als Entweder-Oder gibt es so NICHT.** Die tatsächlichen Wege sind:
    - Mit Einladung: PDF hochladen → Setzliste aus PDF übernehmen → ggf. mit ClubCloud-Meldeliste abgleichen
    - Ohne Einladung: Initiale Teilnehmerliste aus der ClubCloud übernehmen (orientiert am Meldestatus zum Meldeschluss) → dann durch den Turnierleiter modifizieren (z.B. "Nach Ranking sortieren")
- **Action:**
  - Tier A: Schritt 3 komplett umschreiben. Die Setzliste ist ein **Ergebnis** (Meldeliste + Ordnung), keine Quelle. Der Schritt sollte klar unterscheiden zwischen (a) Setzliste aus Einladung übernehmen, (b) Setzliste selbst erzeugen (wenn keine Einladung)
  - Tier C: Den Fall "keine Einladung" explizit als Nebenablauf dokumentieren (gehört in den Anhang aus F-36-01)
  - Tier A: Begriff **Ranking** im Glossar definieren (per-Spieler in Carambus gepflegt), und wie es als Sortierkriterium dient
  - Verifizieren: Welches Ranking-Feld/-Modell wird verwendet? (später Code-Scout)

---

#### F-36-06 — Schritt 4: Fehlende Navigation + UX-Komplexität der Einstiegspunkte
- **Tier:** C (Doc-Ergänzung) + B (UX-Befund für spätere Phase)
- **Zeile:** 40
- **Current:** Das Doc setzt stillschweigend voraus, dass man "in Wizard-Schritt 3" bereits ist.
- **Issue:** Es gibt drei (!) unterschiedliche Einstiegspunkte in den Teilnehmerliste-Bearbeiten-Schritt, abhängig vom aktuellen Zustand:

  1. **Button ganz unten auf der Turnierseite** — anfangs ist Wizard-Schritt 3 dort noch nicht aktiv, der Zugang ist trotzdem über einen Bottom-Link möglich
  2. **Via Meldeliste** — erreichbar über die Aktion **"Einladung hochladen"** (UX-Sorge: der Name ist verwirrend, wenn gar keine Einladung existiert)
     - Im Einladung-hochladen-Formular gibt es dann einen Link: **"→ Mit Meldeliste zu Schritt 3 (nach Rangliste sortiert)"**
  3. **Automatisch nach Setzliste-Übernahme** (aus dem vorigen Schritt)
- **SME-Kommentar:** "Alles etwas verwirrend, wie ich finde :-("
- **Action:**
  - Tier C: Neuer Absatz vor Schritt 4 ("Wie komme ich in Wizard-Schritt 3?") mit den drei Einstiegspunkten
  - Tier C: Erklärung, warum "Einladung hochladen" auch ohne Einladung ein legitimer Eingangspunkt ist (inkl. Verweis auf den "→ Mit Meldeliste zu Schritt 3"-Link)
  - Tier B (neues FIX-Item für spätere Phase): Die Navigation zu Teilnehmerliste-Bearbeiten hat drei Einstiegspunkte mit inkonsistenter UX. Vorschlag: "Einladung hochladen" umbenennen oder um einen Hinweis ergänzen, dass es auch ohne Einladung benutzt werden kann. → Folge-Phase-Kandidat
  - **Cross-ref:** Dieses Finding ist Fundament für die v7.0-Scope-Evolution-Diskussion (Phase 36.x oder 37+)

---

#### F-36-07 — Schritt 4: T04 ist ein echter, kanonischer Planname
- **Tier:** A (minor — Kontext hinzufügen)
- **Zeile:** 44
- **Current:** "Sobald die Teilnehmerzahl einem vordefinierten [Turnierplan] entspricht, erscheint ... **'automatisch vorgeschlagen: T04'**."
- **Info (nicht falsch, aber inkomplett):** T04 ist der echte Name eines vorgefertigten TournamentPlan, der so auch in der **offiziellen Karambol-Turnierordnung** steht. Nicht "ein Beispiel", sondern ein kanonischer Code.
- **Action:**
  - Tier A: Kurzer Klammerzusatz — "(Die Planbezeichnungen wie T04 stammen aus der offiziellen Karambol-Turnierordnung.)"
  - Tier C: Glossar-Eintrag **Turnierplan (T-Codes)** mit Verweis auf die Karambol-Turnierordnung als Quelle

---

#### F-36-08 — Schritt 4: "Spieler hinzufügen"-Link + UX-Farbinkonsistenz
- **Tier:** A + B
- **Zeile:** 40 & 46
- **Current:**
  - Zeile 40: Beschreibt DBU-Nummer-Eingabe, sagt nicht dass ein **"Spieler hinzufügen"-Link** zum Anwenden geklickt werden muss
  - Zeile 46: "Alle Änderungen werden sofort gespeichert; ein Bestätigungs-Klick ist nicht nötig" — **irreführend**: für das DBU-Nummer-Feld ist sehr wohl ein Klick auf "Spieler hinzufügen" nötig
- **Issue:**
  - Die "sofort gespeichert"-Aussage gilt für in-place-Edits (z.B. Sortierung, Einzelfeld-Bearbeitung), NICHT für das DBU-Nummer-Hinzufügen-Feld. Der Turnierleiter braucht explizit den "Spieler hinzufügen"-Link.
  - **Nebenbemerkung vom SME:** "Leider werden viele verschiedene Farben und Fonts benutzt, die alles etwas undurchsichtig machen." → UX-Befund
- **Action:**
  - Tier A: Zeile 40 erweitern — "...komma-getrennt eintragen und dann auf den Link **'Spieler hinzufügen'** klicken."
  - Tier A: Zeile 46 relativieren — "Die meisten Änderungen (Sortierung, in-place-Edits) werden sofort gespeichert. Für das Hinzufügen neuer Spieler per DBU-Nummer ist der Klick auf **'Spieler hinzufügen'** erforderlich."
  - Tier B (Folge-Phase-Kandidat): Teilnehmerliste-Edit-Seite verwendet viele verschiedene Farben und Fonts → UI-Konsistenz-Überarbeitung (Tailwind-Klassen-Vereinheitlichung). → Folge-Phase-Kandidat

---

#### F-36-09 — Schritt 5: AASM-State-Name durch UI-Label ersetzen
- **Tier:** A
- **Zeile:** 51
- **Current:** "...Damit wird die [Setzliste] endgültig festgeschrieben und das Turnier geht in den Status `tournament_seeding_finished` über."
- **Issue:** Der technische AASM-State-Name ist nicht volunteer-geeignet. Der Volunteer sieht im UI: **"Schritt 5: Turniermodus festlegen"**. Das ist die richtige, menschenlesbare Bezeichnung.
- **Action:**
  - Tier A: "tournament_seeding_finished" durch "Schritt 5: Turniermodus festlegen" ersetzen (oder vergleichbare UI-Label)
  - Tier A: Dokumentdurchgang auf alle `tournament_*` AASM-Konstanten — alle sollten UI-Labels bekommen, es sei denn der Kontext ist explizit Entwickler-Info
  - Verifizieren: Mapping aller AASM-States zu ihren UI-Labels (spätere Code-Scout-Aufgabe, oder aus dem Tournament-Model ableiten)

---

#### F-36-10 — Schritt 5: Warning-Block behauptet Falsches — Reset-Möglichkeit existiert
- **Tier:** A (wichtig — beseitigt unnötige Angst)
- **Zeile:** 53–59
- **Current (warning-Block):** "Der Klick auf **Teilnehmerliste abschließen** ist einmalig und nicht rückgängig zu machen. ... eine spätere Änderung der Teilnehmerliste ist nur noch über Admin-Eingriff möglich."
- **Issue:** **Faktisch falsch.** Der Turnierleiter kann alles zurücksetzen. Am unteren Ende der Turnierseite (im Kontext des Turnier-Monitors) existiert der Link **"Zurücksetzen des Turnier-Monitors"**, der alles rückgängig macht.
- **Action:**
  - Tier A: Warning-Block komplett neu fassen. Statt "nicht rückgängig" → "Der Klick ist normalerweise verbindlich, aber im Notfall kann der Turnierleiter das Turnier über den Link **'Zurücksetzen des Turnier-Monitors'** (am unteren Ende der Turnierseite) komplett zurücksetzen."
  - Tier A: Ton anpassen — das alte Wording war unnötig alarmierend ("nur noch über Admin-Eingriff möglich")
  - **F-09 `<!-- ref: F-09 -->`-Kommentar prüfen:** F-09 in den UX-Findings sagt "keine Bestätigung vor irreversibler Transition". Wenn Reset existiert, ist F-09 evtl. selbst stale — spätere Reklassifikation prüfen
  - Verifizieren: Wo genau ist der "Zurücksetzen des Turnier-Monitors"-Link? Gibt es Einschränkungen (z.B. nur vor einem bestimmten State)? → Code-Scout

---

#### F-36-11 — Schritt 5: Wizard-Schritt 4 ist kein eigener State — Schritte 4/5 sind Aktions-Links
- **Tier:** A (konzeptuell wichtig)
- **Zeile:** 61
- **Current:** "Nach dem Klick springt der Wizard-Fortschrittsbalken von Schritt 3 direkt auf Schritt 5 — Schritt 4 wird im Hintergrund automatisch erledigt und erscheint als erledigt. Diese Sprung-Darstellung ist verwirrend, aber inhaltlich korrekt."
- **Issue:** Die Erklärung "Schritt 4 wird im Hintergrund automatisch erledigt" ist **konzeptuell falsch**. Der SME:
  - Schritt 4 ist **kein eigener Wizard-Zustand**.
  - Nach Schritt 3 existiert eine Teilnehmerliste. Von dort aus gibt es zwei Aktionen, die beide als "Schritt 4"/"Schritt 5" im UI erscheinen:
    - **"Schritt 4" ("Teilnehmerliste bearbeiten")** — **Link**, der zur Bearbeitung zurückspringt
    - **"Schritt 5" ("Teilnehmerliste abschließen")** — **Link**, der die AASM-Transition auslöst
  - Das heißt: Schritte 4 und 5 sind **Aktions-Links auf der Teilnehmerliste-Seite**, nicht sequentielle Wizard-States. Der Wizard hat nur **einen** Zustand für die Teilnehmerliste-Phase — die "Sprung"-Darstellung ist nicht "inhaltlich korrekt trotz Verwirrung", sondern ein Artefakt der fehlenden Unterscheidung zwischen AASM-States und UI-Aktionen
- **Action:**
  - Tier A: Gesamten Abschnitt "Schritt 4/5" neu konzipieren. Vorschlag:
    - Schritt 4 (im Doc) = "Teilnehmerliste bearbeiten (Aktion auf Teilnehmerliste-Seite)"
    - Schritt 5 (im Doc) = "Teilnehmerliste abschließen (Link zum State-Übergang)"
    - Explizit sagen: Zwischen den beiden gibt es keinen eigenen Wizard-State
  - Tier A: Zeile 61 streichen oder neu fassen — der "Sprung von 3 auf 5" ist dann selbsterklärend, weil "Schritt 4" keinen eigenen State hat
  - Cross-ref zu F-11 in `33-UX-FINDINGS.md` — F-11 sagt "Sprung ist verwirrend". Die Lösung ist nicht "besseres Feedback im UI", sondern die Wizard-Anzeige sollte Schritt 4 gar nicht als separaten Step zählen. → **Folge-Phase-Kandidat: Wizard-Progress-Display-Korrektur**

---

**Block 2 Zusammenfassung:**
- 7 Findings (F-36-05 bis F-36-11)
- Tier A: 12 Action-Items (Doc-Umformulierungen, Begriffsklärungen, Warning-Ton)
- Tier B: 2 Action-Items (UX-Folgearbeit für spätere Phase: Einladung-hochladen-Naming, Teilnehmerliste-Edit-UI-Konsistenz)
- Tier C: 3 Action-Items (Schritt-4-Navigation-Absatz, Anhangs-Abschnitt "keine Einladung", Glossar-Erweiterung)
- Code-Verifikations-Tasks: 3 (Ranking-Feld, AASM-State-zu-UI-Label-Mapping, Zurücksetzen-Link-Constraints)
- **Meta-Finding:** F-36-06 + F-36-11 deuten auf einen fundamentalen Mismatch zwischen AASM-States und Wizard-UI-Zählung hin. Das ist keine Doc-Korrektur mehr, sondern ein UI-Redesign-Kandidat. **Gehört in die v7.0-Scope-Evolution-Diskussion.**

---

### Block 3: Schritt 6 (Turniermodus) + Schritt 7 (Start-Parameter) + Schritt 8 (Tische)

**Reviewed:** 2026-04-14
**Zeilen:** 63–110

---

#### F-36-12 — Schritt 6: Turnierplan-Anzahl variiert, `Default{n}` ist dynamisch generiert
- **Tier:** A + C
- **Zeile:** 66
- **Current:** "Sie sehen drei Karten mit den verfügbaren Turnierplänen: typischerweise T04, T05 und **DefaultS**."
- **Issue:**
  - Die Anzahl der angezeigten Turnierpläne ist **nicht immer drei** — sie hängt von der Teilnehmerzahl ab (nur Pläne, die zur aktuellen Teilnehmerzahl passen, werden angeboten, plus das Auto-Default)
  - **`DefaultS` ist falsch geschrieben** — korrekt ist `Default{n}`, ein **dynamisch generierter** TournamentPlan mit der Semantik "Jeder gegen Jeden mit n Spielern" (Round-Robin)
  - Bei Default{n} wird auch die benötigte Tischanzahl berechnet (nicht fest vorgegeben wie bei den T-Plänen)
- **Action:**
  - Tier A: "typischerweise drei Karten" → "eine oder mehrere Karten — die Auswahl hängt von der Teilnehmerzahl ab"
  - Tier A: "DefaultS" → "`Default{n}`, wobei `{n}` die aktuelle Teilnehmerzahl ist"
  - Tier C: Erklärung einfügen: "Default{n} ist ein dynamisch generierter Jeder-gegen-Jeden-Plan, dessen Tischanzahl aus der Teilnehmerzahl berechnet wird. Die T-Pläne (T04, T05, ...) haben dagegen fest vorgegebene Tischanzahl und Spielstruktur aus der Karambol-Turnierordnung."
  - Tier C: Glossar-Eintrag **Turnierplan** erweitern um die Unterscheidung T-Plan (vordefiniert, feste Struktur) vs. Default-Plan (dynamisch generiert)

---

#### F-36-13 — Schritt 6: Tip-Block "Welchen Turnierplan wählen?" überflüssig
- **Tier:** A
- **Zeile:** 68–74
- **Current:** Tip-Block "Welchen Turnierplan wählen?" empfiehlt "fast immer den Vorschlag"
- **Issue:**
  - Der Tip-Block ist redundant — der vorgeschlagene Plan kommt **vorzugsweise direkt aus der Einladung** (der Sportwart gibt ihn vor)
  - Die richtige Logik: "Übernehmen Sie den in der Einladung angegebenen Turnierplan" (nicht "den automatisch vorgeschlagenen")
- **Action:**
  - Tier A: Tip-Block entfernen oder deutlich verkürzen
  - Tier A: Hauptext umformulieren — statt "meist ein Plan automatisch vorgeschlagen" → "Der in der Einladung angegebene Turnierplan wird standardmäßig ausgewählt"
  - Cross-ref F-12 in 33-UX-FINDINGS.md (der ursprüngliche Anlass für diesen Tip-Block) — prüfen, ob die dort notierte Problemursache (Trade-off-Vergleich der Alternativen) überhaupt eine Rolle spielt, wenn der Modus ohnehin aus der Einladung kommt. F-12 ist möglicherweise selbst zu hinterfragen.

---

#### F-36-14 — Schritt 7: "15 Felder" weg, wesentliche Parameter explizit auflisten
- **Tier:** A + C
- **Zeile:** 85 & 98–100
- **Current:** "...ein Formular **Turnier Parameter** mit ca. 15 Feldern" + danach eine Beispielauswahl von 3 Feldern
- **Issue:**
  - "ca. 15 Felder" ist eine unpräzise Behauptung — tatsächlich gibt es **mehr** Parameter (je nach Disziplin), viele mit sinnvollen Default-Werten
  - Die ausgewählten 3 Beispielfelder sind inkonsistent erklärt (siehe F-36-17 unten)
- **SME-definierte wesentliche Parameter (die im Doc explizit genannt werden sollten):**
  1. **Tischzuordnung** (logische → physische Tische, siehe F-36-21)
  2. **Aufnahmebegrenzung** (innings_goal)
  3. **Ballziel** (balls_goal)
  4. **Spielabschluss** durch Manager oder durch Spieler
  5. **Automatische Übertragung in die ClubCloud pro Spiel** (`auto_upload_to_cc` — siehe F-36-23 für die Komplexität dahinter)
  6. **Timeout-Kontrolle**
  7. **Nachstoß** (in bestimmten Karambol-Disziplinen)
- **Action:**
  - Tier A: "ca. 15 Felder" streichen
  - Tier A: Statt Feld-Stichprobe die oben genannten 7 **wesentlichen Parameter** als Liste mit Kurzbeschreibung
  - Tier C: Neue Unter-Abschnitte oder Glossar-Einträge für jeden der 7 Parameter
  - Tier C: Disziplinspezifische Unterschiede erwähnen ("Manche Parameter erscheinen nur bei bestimmten Disziplinen")
  - Verifizieren: `app/views/tournaments/tournament_monitor.html.erb` (Form) + `app/models/tournament.rb` (Attribute) durchgehen, um die exakten Parameter-Felder und ihre Default-Werte zu kennen

---

#### F-36-15 — META-FINDING: "Schritte" sind historisch gewachsen, kein einheitliches UI-Konzept
- **Tier:** A (Doc-Einleitung) + B (UI-Folgearbeit) — **wichtiger Meta-Befund**
- **Zeilen:** gesamtes Walkthrough (betrifft alle Block-2-, Block-3- und Block-4-Schritte)
- **Problem:** Die im Doc linear nummerierten "Schritte 1–14" entsprechen **nicht** linear den UI-Screens oder AASM-States. SME-Erklärung der tatsächlichen Struktur:

  | Doc-Schritte | UI-Screen | Konzept |
  |--------------|-----------|---------|
  | Schritt 1 (NBV-Einladung) | Kein Carambus-UI | Vorbereitung offline |
  | Schritte 2–5 (Meldeliste, Setzliste, Teilnehmerliste) | `TournamentsController#index` / Wizard-Partial | 5 "Wizard-Steps" auf einer Seite — aber Schritte 4/5 sind Aktions-Links, keine States (siehe F-36-11) |
  | Schritt 6 (Turniermodus) | **Separate Mode-Selection-Seite** — Schritt 6 taucht auf der Wizard-Seite NICHT mehr auf | Eigene Route |
  | Schritt 7 (Start-Parameter) + Schritt 8 (Tische) | **`tournament_monitor` Parametrisierungs-Formular** — enthält Tischzuordnung als EINEN der vielen Parameter | Eine Seite, nicht zwei Schritte |
  | Schritt 9+ (Start, Warmup, Spielbeginn, Ergebnisse, ...) | `TableMonitor#show` + spätere Views | Weitere historisch gewachsene Screens |

- **SME-Kommentar:** "Alle diese Seiten sind historisch gewachsen und haben leider kein einheitliches UI-Konzept."
- **Konsequenzen:**
  - Die "Schritt N"-Nummerierung im Doc ist ein **Dokumentations-Konstrukt**, keine UI-Realität. Der Volunteer sieht andere Screens als die Schritt-Nummerierung suggeriert.
  - Block 2 F-36-11 (Schritt 4 ist kein eigener State) ist ein Instance-Fall dieses Meta-Problems.
  - Schritt 7 und Schritt 8 sind **dieselbe Formularseite** — die Trennung im Doc ist künstlich.
- **Action:**
  - Tier A: **Einleitung zum Walkthrough-Abschnitt** (aktuell Zeile 13) erweitern um einen Hinweiskasten, der ehrlich sagt: "Die im Folgenden nummerierten Schritte 1–14 sind eine **logisch-chronologische** Aufzählung. Die zugehörigen UI-Screens sind historisch gewachsen und zählen teilweise anders: Schritte 2–5 liegen auf der Wizard-Seite, Schritt 6 hat einen eigenen Screen, Schritte 7–8 sind auf derselben Parametrisierungsseite, ab Schritt 9 geht es in den Turnier-Monitor-Screen über."
  - Tier A: Schritte 7 und 8 im Doc **zusammenführen** zu einem Schritt "Start-Parameter und Tischzuordnung" — alternativ explizit kennzeichnen, dass Schritt 8 ein Unter-Abschnitt von Schritt 7 ist
  - Tier B (Folge-Phase): UI-Konsolidierung der Screens — das ist größeres UX-Redesign, nicht Doc-Arbeit. Gehört in die v7.0-Scope-Evolution oder eine spätere Phase. **Meta-Finding-Kandidat für die Organisations-Diskussion am Review-Ende.**

---

#### F-36-16 — Schritt 7 Tip-Block: "nach dem Turnier" → "vor dem Turnier-Start", plus Tooltip-UX-Vorschlag
- **Tier:** A + B
- **Zeile:** 87–93
- **Current:** "Im Zweifel übernehmen Sie die Standardwerte und kontrollieren Sie die Einstellungen **nach dem Turnier**."
- **Issue:**
  - "nach dem Turnier" ist **zu spät** — Parameter wie Ballziel/Aufnahmebegrenzung beeinflussen direkt das Spielergebnis
  - Fix: "vor dem Turnier-Start"
  - **SME-Kommentar:** "Eigentlich sollte dieser Block nicht notwendig sein, wenn alles konsistent und leicht verständlich beschrieben ist. Tooltips an den Parameterfeldern des Formulars wären sicher sehr hilfreich."
- **Action:**
  - Tier A: "nach dem Turnier" → "vor dem Start des Turniers"
  - Tier A: Block bleibt vorerst, weil die englischen Labels real sind (F-14)
  - Tier B (neues Feature für spätere Phase): **Tooltips an den Parameterfeldern** — wenn jedes Feld einen Tooltip mit erklärendem Text hätte, wäre der Tip-Block im Doc überflüssig. UI-Feature. → Folge-Phase-Kandidat
  - Cross-ref F-14 in 33-UX-FINDINGS.md (englische Labels) — die Tooltip-Lösung aus F-36-16 löst F-14 teilweise mit

---

#### F-36-17 — Schritt 7: "Bälle vor / Bälle-Ziel" ist eine Verwechslung
- **Tier:** A (faktisch falsch)
- **Zeile:** 98
- **Current:** "**Bälle vor** / **Bälle-Ziel** (innings_goal): Das Ziel in Bällen, das ein Spieler erreichen muss..."
- **Issue:**
  - **Zwei Fehler in einem Satz:**
    1. "Bälle vor / Bälle-Ziel" gehören nicht zusammen — das sind zwei verschiedene Konzepte
    2. Der i18n-Key `innings_goal` bezieht sich auf **Aufnahmen**, nicht Bälle — der Wert unter diesem Label ist die Aufnahmebegrenzung
  - **Korrekte Felder laut SME:**
    - **Ballziel** → i18n-Key `balls_goal` → Ziel in Bällen pro Partie
    - **Aufnahmebegrenzung** → i18n-Key `innings_goal` → Maximale Aufnahmenzahl
  - **"Bälle vor"** ist wahrscheinlich die **individuelle Vorgabe bei Handikap-Turnieren** (Tournament-Typ mit unterschiedlichen Zielen pro Spieler), **nicht** ein Standard-Parameter
- **Action:**
  - Tier A: Zeile 98 komplett neu schreiben — zwei getrennte Bullet-Einträge:
    - "**Ballziel** (`balls_goal`): Das Ziel in Bällen, das ein Spieler für den Partie-Gewinn erreichen muss. Für Freie Partie Klasse 1–3 steht der Wert in der Einladung (typischerweise **150 Bälle**, ggf. reduziert um 20%). Siehe Karambol-Sportordnung."
    - "**Aufnahmebegrenzung** (`innings_goal`): Maximale Aufnahmenzahl pro Partie. Für Freie Partie Klasse 1–3 typischerweise **50 Aufnahmen** (ggf. reduziert um 20%). Leerfeld oder 0 = unbegrenzt."
  - Tier A: "Bälle vor" — wenn relevant, separat unter "Handikap-Turniere" dokumentieren (oder ganz weglassen, wenn Handikap nicht zum Walkthrough-Szenario gehört)
  - Verifizieren: i18n-Keys im `config/locales/de.yml` + `en.yml` checken: `innings_goal`, `balls_goal`, `individual_handicap`, etc.

---

#### F-36-18 — Schritt 7: Wertebereich-Erklärung falsch (50/150 sind getrennte Werte)
- **Tier:** A
- **Zeile:** 98
- **Current:** "typische Werte zwischen 50 und 150 Bällen — prüfen Sie die Einladung."
- **Issue:**
  - "50 und 150" ist **kein Intervall** — es sind **zwei getrennte Werte** für zwei verschiedene Parameter:
    - **50** = typische Aufnahmebegrenzung für Freie Partie Klasse 1–3
    - **150** = typisches Ballziel für Freie Partie Klasse 1–3
  - Die Werte stehen in der **Karambol-Sportordnung**, nicht in der Einladung direkt (die Einladung verweist auf die Ordnung)
  - Reduktion: "ggf. um 20% reduziert" ist eine in der Sportordnung vorgesehene Option (z.B. Satz-statt-Partie-Spielmodus)
- **Action:**
  - Tier A: Wertebereich-Satz komplett neu fassen — wird durch die Korrektur in F-36-17 bereits abgedeckt
  - Tier C: Glossar oder Troubleshooting-Abschnitt mit Verweis auf die Karambol-Sportordnung als kanonische Werte-Quelle

---

#### F-36-19 — Schritt 7: Aufnahmebegrenzung unbegrenzt-Marker nicht im UI dokumentiert
- **Tier:** A (Doc) + B (UI-Fehlen)
- **Zeile:** 99
- **Current:** "**Aufnahmebegrenzung**: Maximale Zahl der Aufnahmen pro Partie. 0 = unbegrenzt."
- **Issue:**
  - Leerfeld **oder** 0 bedeutet unbegrenzt (beides zulässig)
  - **Im UI-Formular steht nichts dazu** — der Volunteer weiß nicht, wie er "unbegrenzt" konfiguriert, ohne die Doku zu lesen
- **Action:**
  - Tier A: Doc erweitern — "**Aufnahmebegrenzung**: ... 0 oder Leerfeld = unbegrenzt."
  - Tier B (Folge-Phase): **Tooltip oder Inline-Hilfetext** am Aufnahmebegrenzung-Feld im Formular ergänzen. (Teil der F-36-16 Tooltip-Initiative)

---

#### F-36-20 — Schritt 7: Englisches Label ist Lokalisierungs-Fehler
- **Tier:** A (Doc) + B (Code-Lokalisierung-Fix)
- **Zeile:** 100
- **Current:** "**Tournament manager checks results before acceptance**: Wenn aktiviert..."
- **Issue:**
  - Das englische Label ist **möglicherweise ein Lokalisierungs-Fehler** — fehlender oder defekter Eintrag in `config/locales/de.yml`
  - Cross-ref F-14 in 33-UX-FINDINGS.md (schwere i18n-Regression im Start-Formular)
- **Action:**
  - Tier A (Doc): Das **deutsche** Label verwenden, sobald es existiert (z.B. "Manager bestätigt Ergebnisse vor Annahme")
  - Tier B (Code): i18n-Key finden und DE-Übersetzung ergänzen/korrigieren. Vermutlich in `config/locales/de.yml` unter `activerecord.attributes.tournament.*` oder `simple_form.labels.tournament.*`
  - Verifizieren: Grep nach "checks results before acceptance" in den i18n-Dateien
  - Cross-ref F-14 (umfangreiche Lokalisierungs-Arbeit) — dieser ist ein Instance-Case davon

---

#### F-36-21 — Schritt 8: Logische vs. physikalische Tische — fehlende konzeptuelle Trennung
- **Tier:** A + C
- **Zeile:** 107
- **Current:** "Im Abschnitt **Zuordnung der Tische** weisen Sie den Turnier-Spielrunden die physischen Tische zu."
- **Issue:**
  - **Konzeptuell falsch.** Die korrekte Struktur laut SME:
    - **Logische Tischnamen** (Tisch 1 ... Tisch n) kommen aus dem TournamentPlan (z.B. T04 definiert "Tisch 1" und "Tisch 2")
    - **Physikalische Tischnamen** sind die konkreten Tische im Spiellokal (z.B. "Tisch BG Hamburg 1", "Tisch Vereinsheim 2")
    - Beim Turnierstart werden die **logischen Tische den physikalischen zugeordnet**
    - Die Zuordnung der **Spiele** (Matches) zu logischen Tischen ist **dynamisch** — der TournamentPlan bestimmt, welches Spiel auf welchem logischen Tisch läuft, nicht der Turnierleiter
  - Das aktuelle Doc sagt "Spielrunden → physische Tische", was die logische Zwischenschicht auslässt
- **Action:**
  - Tier A: Schritt 8 umformulieren:
    - "Der gewählte Turnierplan definiert **logische Tischnamen** (z.B. Tisch 1 und Tisch 2 bei T04). In diesem Schritt ordnen Sie jedem logischen Tisch einen **physikalischen Tisch** aus Ihrem Spiellokal zu."
    - "Die Zuordnung der einzelnen Spiele zu den logischen Tischen erfolgt **automatisch** aus dem Turnierplan — der Turnierleiter muss nur die Verbindung zu den physischen Tischen herstellen."
  - Tier C: Glossar-Eintrag **Logischer Tisch** und **Physikalischer Tisch** separat erklären
  - Tier C: Glossar-Eintrag **TableMonitor** — siehe auch F-36-22

---

#### F-36-22 — Schritt 8: Scoreboard-Tisch-Verbindung ist nicht fest, TableMonitor-Konzept fehlt
- **Tier:** A + C
- **Zeile:** 109
- **Current:** "...die Scoreboards verbinden sich nach dem Start automatisch mit dem zugewiesenen Tisch."
- **Issue:**
  - **Technisch falsch.** Es gibt keine feste Verbindung zwischen Scoreboard und physischem Tisch. Der SME:
    - Am Scoreboard wird der **physikalische Tisch** ausgewählt (manuell)
    - Ein Scoreboard kann an einem beliebigen physikalischen Tisch laufen — z.B. kann das Scoreboard "Tisch 2" am physikalischen Tisch 3 laufen, wenn der Monitor an Tisch 2 ausgefallen ist
    - Die eigentliche Bindung ist **Scoreboard → TableMonitor → logischer Tisch**
    - Alle Scoreboards und Smartphone-Browser, die sich mit einem physikalischen Tisch verbinden, bekommen die Meldungen an den logischen Tisch, der diesem physikalischen Tisch zugeordnet ist (technisch: der TableMonitor-Datensatz)
- **Action:**
  - Tier A: Zeile 109 komplett neu schreiben:
    - "Nach dem Turnierstart werden auf jedem physikalischen Tisch ein oder mehrere **Scoreboards** (Tisch-Monitore, Smartphones, Web-Clients) mit dem zugehörigen Tisch verbunden. Dazu wählt der Bediener am Scoreboard den passenden physikalischen Tisch aus — die Verbindung ist nicht fest vorgegeben und kann bei Bedarf am Scoreboard neu gewählt werden."
  - Tier C: Konzept-Kurz-Erklärung **TableMonitor** in Glossar: "Technischer Datensatz, der die Verbindung zwischen logischem Tisch (aus dem Turnierplan), physikalischem Tisch und den daran laufenden Scoreboards herstellt. Jeder logische Tisch hat einen TableMonitor, der die Match-Updates broadcastet."
  - Cross-ref: Tisch-Ausfall-Szenario wurde vom SME explizit als "nicht erwähnen, da selten" markiert — bleibt raus

---

#### F-36-23 — Fehlend in Schritt 7: `auto_upload_to_cc` + ClubCloud-Upload-Komplexität
- **Tier:** A + C + B — **größter Fund dieses Blocks**
- **Zeile:** fehlt komplett in Schritt 7 (aktuell nur in Schritt 14 Upload erwähnt)
- **Issue:** Die Checkbox "Ergebnisse automatisch in ClubCloud hochladen" ist Teil des Start-Parameter-Formulars (Schritt 7), wird aber im Schritt-7-Doc nicht erwähnt. FIX-02 aus den v7.0-Requirements zielte ursprünglich auf diese Lücke — aber die Realität ist **deutlich komplexer** als eine simple Checkbox-Dokumentation.
- **SME-definierte Komplexität (muss ins Doc):**

  **Pfad 1: Einzelübertragung pro Spiel** (wenn `auto_upload_to_cc` aktiviert)
  - Jedes einzelne Ergebnis wird sofort nach Match-Ende hochgeladen
  - Technik: Formular-Emulation im ClubCloud-Admin-Interface
  - **Voraussetzung:** Die Meldeliste muss **korrekt als Teilnehmerliste** in der ClubCloud eingetragen sein
  - **Berechtigungs-Problem:** Nur ein ClubCloud-Manager mit dem entsprechenden Recht kann die Teilnehmerliste in CC finalisieren
  - **Lücke (to-be-implemented):** Die Finalisierung der Teilnehmerliste an CC übertragen (via CC-Schnittstelle) — das ist aktuell NICHT implementiert
  - **Organisatorisches Problem:** Fehlende Spieler in CC hinzufügen können nur Club-Sportwarte (die nicht immer vor Ort sind). Lösungsidee: Credentials der Club-Sportwarte in Carambus eintragen für genau diesen Fall

  **Pfad 2: CSV-Batch-Upload** (wenn Pfad 1 nicht möglich)
  - Alle Ergebnisse werden am Ende als CSV-Datei bereitgestellt
  - **Gleiche Voraussetzung:** Teilnehmerliste muss in CC finalisiert sein
  - **Timing-Unterschied:** Die Finalisierung durch den Club-Sportwart kann **nach** dem Turnier erfolgen
  - **Workflow:** Der Turniermanager bekommt die CSV per E-Mail und leitet sie an den Club-Sportwart weiter, der sie dann in die (finalisierte) CC-Teilnehmerliste importiert

- **Action:**
  - Tier A: **Neuer Parameter-Eintrag** in Schritt 7 für `auto_upload_to_cc` — Checkbox erwähnen, Kurzbeschreibung des Pfads 1
  - Tier C: **Neuer eigener Sub-Abschnitt** am Ende des Walkthroughs (oder als Sub-Abschnitt von Schritt 14): "ClubCloud-Upload — zwei Wege"
    - Pfad 1 (Einzelübertragung pro Spiel) mit Voraussetzungen
    - Pfad 2 (CSV-Batch am Ende) mit Workflow
    - **Berechtigungs-Problem** offen dokumentieren (welche Rolle kann was)
    - **Lücke "Teilnehmerliste-Finalisierung an CC"** als bekannte Limitation erwähnen
  - Tier B (Code/Feature, Folge-Phase): **Implementierung der Teilnehmerliste-Finalisierung an CC** via CC-Schnittstelle — das ist ein echter neuer Code-Pfad, kein UI-Fix
  - Tier B (Organisatorisch/Code, Folge-Phase): **Credentials der Club-Sportwarte** in Carambus hinterlegen (oder ein Delegations-Mechanismus) — organisatorisch-technische Lösung für das Berechtigungs-Problem
  - Cross-ref: Dies ist die eigentliche **FIX-02**-Story. Die ursprüngliche Formulierung ("Checkbox-Ort in Docs stimmt nicht") war eine zu enge Lesart. Die richtige FIX-02 ist: "ClubCloud-Upload-Modell vollständig dokumentieren UND die Teilnehmerliste-Finalisierung implementieren, damit der Upload überhaupt funktionieren kann."
  - **F-36-23 ist ein Haupt-Argument dafür, dass Phase 36 Scope nicht mehr "klein" ist.**

---

**Block 3 Zusammenfassung:**
- 12 Findings (F-36-12 bis F-36-23)
- Tier A: ~20 Action-Items (zwei große Korrekturen: F-36-17 Bälle-vs-Aufnahmen-Verwechslung und F-36-23 ClubCloud-Komplexität; plus viele kleinere Wording-Fixes)
- Tier B: 6 Action-Items (Folge-Phase-Kandidaten):
  1. UI-Konsolidierung der historisch gewachsenen Screens (F-36-15)
  2. Tooltip-Feature für Parameterfelder (F-36-16, F-36-19)
  3. i18n-Korrektur für englische Labels (F-36-20) — Cross-ref F-14
  4. Teilnehmerliste-Finalisierung via CC-Schnittstelle implementieren (F-36-23 Pfad 1)
  5. Credentials-Delegation für Club-Sportwart-Rechte (F-36-23)
  6. Ggf. Bälle-vor-Feld korrekt abbilden (F-36-17, wenn Handikap-Turniere Scope sind)
- Tier C: ~10 Action-Items (neue Glossar-Einträge, Konzept-Erklärungen, neue Sub-Abschnitte)
- Code-Verifikations-Tasks: 5 (Parameter-Felder in `tournament_monitor.html.erb`, i18n-Keys für `innings_goal`/`balls_goal`/`individual_handicap`, englisches Label-Key, TableMonitor-Model, CC-Schnittstellen-Status)

**Meta-Findings-Update:**
- F-36-15 ist der **größte Meta-Befund der Review bisher**: "Schritt N" im Doc ≠ UI-Screen ≠ AASM-State. Historisch gewachsen.
- F-36-23 ist der **größte Content-Befund**: ClubCloud-Upload-Modell fehlt komplett + Lücken im Code.
- Zusammen mit Block-2-Meta-Finding (F-36-06, F-36-11) zeichnet sich ab: **Phase 36 in der ursprünglichen Form ("Small UX Fixes" mit 4 FIX-Items) ist nicht mehr adäquat.** Was wir hier entdecken sind drei verschiedene Kategorien:
  1. Doc-Korrekturen (pure Tier A, viele)
  2. UI-Redesign-Kandidaten (Tier B, mehrere)
  3. Code-Feature-Lücken (Tier B, mindestens CC-Finalisierung + Credentials-Delegation)
- **Dringend zu besprechen am Review-Ende:** Wie organisieren wir (a) die Tier-A-Arbeit, (b) die Tier-B-Folgearbeit, (c) die v7.0-Scope-Evolution?

---

### Block 4: Schritt 9 (Turnier starten) + Schritt 10 (Warmup) + Schritt 11 (Spielbeginn)

**Reviewed:** 2026-04-14
**Zeilen:** 111–144
**Mode:** schlank

---

#### F-36-24 — Schritt 9: Warning-Block "nicht erneut klicken" irreführend
- **Tier:** A
- **Zeile:** 116–122
- **Issue:** Button ist während der Aktion gesperrt — Doppelklick ist gar nicht möglich. Warnung falsch gerahmt.
- **Action:** Warning ersetzen durch schlichten Hinweis: "Der Start-Vorgang kann einige Sekunden dauern."
- Cross-ref F-19 (`<!-- ref: F-19 -->`): die dort beschriebene Sorge (transient state ohne Feedback) bleibt — aber das Doc sollte ehrlich sagen, dass der Button gesperrt ist, nicht suggerieren, es gäbe ein Risiko

---

#### F-36-25 — Schritt 9: AASM-Technik-Absatz ersatzlos raus, stattdessen Feedback-Check an den Tafeln
- **Tier:** A
- **Zeile:** 124
- **Issue:** "AASM-Event, `tournament_started_waiting_for_monitors`, Redis/ActionCable" ist Entwickler-Info, nicht volunteer-tauglich. In der Praxis geht der Start schnell.
- **Action:**
  - Zeile 124 ersatzlos streichen
  - Stattdessen: Hinweis auf das tatsächliche Feedback — "Nach dem Start erscheinen auf den Tisch-Tafeln die richtigen Paarungen der ersten Runde. Wenn das der Fall ist, ist der Start erfolgreich."
  - **Neue Info nachtragen (später):** Turnierleiter kann vom Laptop aus die Tisch-Links in eigenen Browser-Tabs öffnen, um einzelne Scoreboards zu beobachten und bei Bedarf einzugreifen → gehört evtl. eher in Schritt 12 (Ergebnisse verfolgen)

---

#### F-36-26 — Schritt 10: Wording "ausprobieren" → "einspielen", Warmup-Parameter erklären
- **Tier:** A + C
- **Zeile:** 131 (Warmup-Beschreibung)
- **Action:**
  - "Spieler die Tische und Bälle ausprobieren" → "die Spieler sich **einspielen**" (Fachterminus)
  - Ergänzen: Die Einspielzeit wird **am Scoreboard** gestartet, typischerweise 5 Min (Parameter **Warmup**)
- **Fehlende Visuals:** Snapshots der Scoreboard-Warmup-Ansicht fehlen — wahrscheinlich nicht im Phase-33-Fundus; müssten neu gemacht werden (Tier C, Folge-Arbeit)

---

#### F-36-27 — Schritt 10: "alle 4 Matches" ist faktisch falsch
- **Tier:** A
- **Zeile:** 131
- **Issue:** Bei 5 Teilnehmern laufen in Runde 1 **2 Matches mit 4 Spielern** (der 5. hat Freilos), NICHT 4 Matches.
- **Action:**
  - "alle 4 Matches" → "die Matches der ersten Runde entsprechend dem Turnierplan"
  - Konkret im 5-Spieler-Szenario: "2 Matches mit je 2 Spielern, plus 1 Spieler Freilos"

---

#### F-36-28 — Schritt 10: Die "Aktuelle Spiele Runde 1"-Tabelle mit Eingabefeldern ist Dead-Code-Kandidat
- **Tier:** A (Doc) + B (UI-Cleanup, wichtig)
- **Zeile:** 131 (Erwähnung der "Spielbeginn"-Buttons pro Zeile)
- **Issue:** Die Tabelle mit Spielbeginn-Buttons und Eingabe-UI dient nur als **Fallback** für den Fall, dass Scoreboards ausfallen und Ergebnisse von Spielprotokollzetteln manuell übertragen werden müssen. Aber: Wenn Scoreboards ausfallen, kann man die Ergebnisse auch direkt in der ClubCloud eingeben — dann ist der Nutzen von Carambus ohnehin weg. Feature ist **sinnlos**.
- **Action:**
  - Tier A (Doc): Erwähnung der Eingabefelder in der Tabelle streichen. Nur kurz erwähnen, dass die Tabelle die laufende Runde zeigt — die Buttons dort bleiben undokumentiert (bzw. besser: werden im Cleanup entfernt)
  - Tier B (UI-Cleanup, Folge-Phase): **Entfernung der manuellen Spielbeginn/Ergebniseingabe aus der Turnier-Monitor-Seite**. Der Code-Pfad ist toter Ballast und verwirrt die Doku. Gehört in die **F-36-15-Meta-UI-Konsolidierung**.

---

#### F-36-29 — Schritt 11: Rundenwechsel-Mechanik — manuelle Bestätigung ist Feature-Vereinfachungs-Kandidat
- **Tier:** A (Doc) + B (Feature-Entscheidung)
- **Zeilen:** 141–143
- **Fakten (SME):**
  - Alle Aktionen während des Spiels finden **am Scoreboard** statt (nicht im Turnier-Monitor)
  - Nur wenn das Turnier mit Parameter "manuelle Kontrolle durch Turnierleiter" konfiguriert ist, bleibt der Rundenwechsel blockiert, bis der Turnierleiter bei **allen** "OK?"-Buttons bestätigt hat
  - **SME überlegt, dieses Feature ganz zu entfernen:** Automatischer Rundenwechsel, sobald am letzten Scoreboard "Endergebnis erfasst" bestätigt ist
- **Action:**
  - Tier A: Schritt 11 neu fassen — siehe F-36-30 (ist faktisch falsch wenn ohne manuelle Kontrolle)
  - Tier B (offen): **Feature-Entscheidung:** Soll die manuelle Rundenwechsel-Kontrolle bleiben oder komplett raus? Wenn raus → Vereinfachung der Parameter (F-36-14-Parameterliste schrumpft um 1). Gehört in die Scope-Evolution-Diskussion am Review-Ende.

---

#### F-36-30 — Schritt 11: "Spielbeginn freigeben" ist faktisch falsch — Turniermanager klickt nichts
- **Tier:** A (wichtige Korrektur)
- **Zeilen:** 141–143
- **Issue:**
  - Die ganze Prämisse des Abschnitts ist falsch. Zitat SME: "hier klickt der Turniermanager **nichts mehr** — alles wird automatisch an die Scoreboards übertragen"
  - Der angebliche "Spielbeginn"-Button-Klick ist entweder:
    - Das Fallback-UI aus F-36-28 (toter Code-Pfad)
    - ODER der manuelle Rundenwechsel aus F-36-29 (der evtl. ganz raus soll)
  - In beiden Fällen ist Schritt 11 in der aktuellen Form **nicht die Realität**, die der Volunteer erlebt
- **Action:**
  - Tier A: Schritt 11 komplett neu fassen — Vorschlag:
    - Neuer Titel: "Schritt 11: Spielbetrieb läuft (Scoreboards steuern alles)"
    - Inhalt: Nach Warmup startet jedes Spiel automatisch am Scoreboard. Der Turnierleiter hat **keine aktive Rolle** im Standard-Fall. Seine Aufgabe beschränkt sich auf Beobachtung (siehe Schritt 12).
    - **Wenn** manuelle Kontrolle parametrisiert ist (F-36-29): dann erklären, dass der Turnierleiter "OK?" bei jedem Spielende bestätigen muss
  - Cross-ref: Der Aufruf des Walkthrough-Modells muss sich möglicherweise verschieben — Schritte 10, 11, 12 sind am Ende nicht drei Aktionen des Turnierleiters, sondern nur Phasen (Warmup, Spielbetrieb, Abschluss) mit minimaler Turnierleiter-Interaktion

---

#### F-36-31 — Neue Inhalte (fehlen komplett): Nachstoß-Problem + Oversight-via-Browser-Tabs
- **Tier:** C
- **Issue:** Im aktuellen Doc fehlen zwei wichtige praktische Punkte:
  1. **Nachstoß-Eingabe wird oft vergessen** am Scoreboard — in Karambol-Disziplinen mit Nachstoß-Regel ist das ein echtes Problem, das der Turnierleiter kennen sollte. Gehört in Schritt 12 (Ergebnisse verfolgen) oder in einen neuen Abschnitt "Häufige Fehlerquellen während des Spielbetriebs"
  2. **Turnierleiter-Oversight:** Aus der Turnier-Monitor-Seite kann der Turnierleiter per Klick die einzelnen Tisch-Scoreboards in eigenen Browser-Tabs öffnen — nützlich für Beobachtung und ggf. Eingreifen. Muss dokumentiert werden.
- **Action:**
  - Tier C: Beide Punkte als Ergänzung in Schritt 12 (kommt in Block 5) einplanen — dort passen sie thematisch besser hin

---

**Block 4 Zusammenfassung:**
- 8 Findings (F-36-24 bis F-36-31)
- Tier A: 9 Action-Items (mehrere komplette Neufassungen: Warning-Block, Schritt 11, Technik-Absatz)
- Tier B: 3 Folge-Phase-Kandidaten:
  - UI-Cleanup: manuelle Spielbeginn/Ergebnis-Eingabe aus Turnier-Monitor entfernen (F-36-28)
  - Feature-Entscheidung: manuelle Rundenwechsel-Kontrolle raus (F-36-29)
  - F-19 (aus 33-UX-FINDINGS) Reklassifikation: Button-Sperrung existiert, F-19 ist evtl. stale (F-36-24)
- Tier C: 3 Content-Ergänzungen (Warmup-Scoreboard-Snapshots, Nachstoß-Hinweis, Browser-Tab-Oversight)
- **Wichtiger Meta-Befund:** Schritt 11 ("Spielbeginn freigeben") ist in der aktuellen Form **faktisch nicht die Realität**. Der Turnierleiter hat in der Praxis während des laufenden Spielbetriebs kaum Interaktion mit Carambus — alles läuft an den Scoreboards. Die walkthrough-Struktur "Schritt für Schritt" suggeriert mehr Aktivität als wirklich nötig ist. → Konsequenz: Ganze Walkthrough-Gliederung vielleicht ehrlicher als "Phasen mit und ohne Turnierleiter-Aktion" strukturieren.

---

### Block 5: Schritt 12 (Ergebnisse verfolgen) + Schritt 13 (finalisieren) + Schritt 14 (Upload)

**Reviewed:** 2026-04-14
**Zeilen:** 145–168
**Mode:** schlank

---

#### F-36-32 — Reset-Funktion jederzeit möglich, aber tödlich bei laufendem Turnier
- **Tier:** A (Doc) + B (Feature: Safety-Gate)
- **Context:** Cross-ref F-36-10 — der "Zurücksetzen des Turnier-Monitors"-Link funktioniert jederzeit, auch während das Turnier läuft. Das führt zu **totalem Datenverlust der Spielergebnisse**.
- **Action:**
  - Tier A (Doc): F-36-10 präzisieren — Reset ist möglich, aber bei laufendem Turnier zerstört es alle bisher erfassten Ergebnisse
  - Tier B (Feature): **Sicherheitsabfrage** einbauen wenn Reset bei `tournament_started`-State oder später ausgelöst wird ("Sind Sie sicher? Alle bisherigen Ergebnisse gehen verloren.") — neues FIX-Item für spätere Phase

---

#### F-36-33 — Schritt 12: "Tournament manager checks results"-Button ist Löschungskandidat
- **Tier:** A (Doc)
- **Context:** Bestätigt F-36-29 — der Rundenwechsel-Kontrolle-Parameter soll ganz raus. Schritt 12 erwähnt aktuell den Bestätigungs-Button.
- **Action:** Erwähnung streichen sobald Feature-Entscheidung gefällt ist. Cross-ref F-36-29.

---

#### F-36-34 — Schritt 13: "Endrangliste berechnen" existiert nicht — manuelle CC-Pflege nötig ⚠️ großes Feature-Gap
- **Tier:** A (Doc) + B (Feature-Gap, groß) + C (Anhang)
- **Zeile:** 157
- **Current:** "Klicken Sie darauf, um die **Endrangliste zu berechnen** und das Turnier in den Abschlussstatus zu setzen."
- **Issue:** **Carambus berechnet derzeit keine Turnier-Endrangliste.** Die muss aktuell **händisch in der ClubCloud gepflegt** werden. Die Doku suggeriert etwas, das nicht existiert.
- **Action:**
  - Tier A: Zeile 157 komplett neu fassen — ehrlich sagen, dass Carambus die Ergebnisse zurückliefert, die Ranglisten-Berechnung aber derzeit manuell in der ClubCloud erfolgt
  - Tier B (Feature-Arbeit): **Endrangliste automatisch berechnen** — echter neuer Code. Wahrscheinlich nicht trivial (Sonderfälle: Stechen, Gleichstand-Kriterien, Disziplin-spezifische Regeln). Großes FIX-Item für spätere Phase
  - Tier C: Anhang "Rangliste in der ClubCloud pflegen" — dokumentiert den manuellen Workflow, damit der Turnierleiter ihn nachvollziehen kann
  - Cross-ref: Folge-Phase-Kandidat, groß

---

#### F-36-35 — Schritt 13: Shootout/Stichspiele nicht unterstützt ⚠️ kritisches Feature-Gap für KO-Turniere
- **Tier:** B (kritisch) + C (Doc-Hinweis)
- **Context:** Der aktuelle Code unterstützt **Shootout überhaupt nicht**. Bei **KO-Spielen ist Stechen zwingend erforderlich**, wenn zwei Spieler nach regulärer Partie denselben Stand haben.
- **SME-Kommentar:** "dickes TODO"
- **Action:**
  - Tier C (Doc): Einen ehrlichen Hinweis in Schritt 13 oder in einem bekannt-Limitation-Abschnitt: "Shootout/Stechen wird derzeit nicht unterstützt — bei KO-Turnieren müssen Stichspiele manuell durchgeführt und das Ergebnis außerhalb von Carambus dokumentiert werden."
  - Tier B (Feature-Arbeit, groß): **Shootout-Support implementieren**. Betrifft sowohl AASM (neuer State? neue Transition?), Turnierplan-Modelle, Scoreboard-UI, und Rangliste-Berechnung (wenn letztere kommt)
  - **Kandidat für eigene Phase oder eigenes Milestone** — das ist kein "Small UX Fix" mehr. Gehört ins **v7.1+ Backlog** als hoch-priorisierter Punkt

---

#### F-36-36 — Schritt 14: "auto_upload_to_cc" Zeitpunkt-Angabe widerspricht F-36-23
- **Tier:** A
- **Zeile:** 166
- **Current:** "...überträgt Carambus die Ergebnisse **beim Finalisieren** automatisch zurück an die ClubCloud."
- **Issue:** Falsch — laut F-36-23 erfolgt die Einzelübertragung **sofort nach jedem Spielende**, nicht beim Finalisieren. User bestätigt.
- **Action:** Zeile 166 konsistent zu F-36-23 neu fassen: "...überträgt Carambus jedes Einzelergebnis **sofort nach dem jeweiligen Spielende** an die ClubCloud." Voraussetzungen (Teilnehmerliste in CC finalisiert) aus F-36-23 hier verlinken.

---

#### F-36-37 — Schritt 14: "Schaltfläche Ergebnisse nach ClubCloud übertragen" existiert nicht
- **Tier:** A
- **Zeile:** 168
- **Current:** "...können Sie den Upload manuell auf der Turnier-Detailseite anstoßen (**Schaltfläche „Ergebnisse nach ClubCloud übertragen"**)."
- **Issue:** Diese Schaltfläche **existiert in Carambus nicht**. Der Satz erfindet ein UI-Element.
- **Reality:** Wenn Einzelübertragung nicht funktioniert, muss die CSV-Datei manuell über die ClubCloud-Admin-Schnittstelle hochgeladen werden. Siehe F-36-23 Pfad 2.
- **Action:**
  - Tier A: Zeile 168 komplett streichen/ersetzen. Stattdessen auf den CSV-Batch-Pfad aus F-36-23 verweisen.
  - Cross-ref F-36-38 (ClubCloud-Handling-Anhang)

---

#### F-36-38 — ClubCloud-CSV-Upload-Handling nicht trivial — eigener Anhang nötig
- **Tier:** C (größerer neuer Inhalt)
- **Context (SME):** Das ClubCloud-Seite-Handling ist "durchaus nicht trivial". Der Volunteer braucht einen eigenen Abschnitt/Anhang, der erklärt:
  - Wo genau in der ClubCloud der CSV-Upload erreichbar ist
  - Welche Rolle/Recht der CC-Benutzer braucht
  - Welche Validierungen die CC macht und was typische Fehlermeldungen bedeuten
  - Zusammenhang zur vorher nötigen Teilnehmerliste-Finalisierung (Cross-ref F-36-23)
- **Action:**
  - Tier C: Neuer Anhang "CSV-Upload in der ClubCloud" am Ende des Dokuments
  - Quelle für die Inhalte: der User bzw. ein Club-Sportwart, der den Prozess kennt. Muss möglicherweise im Rahmen der Tier-A-Korrektur-Phase separat recherchiert oder interviewt werden

---

**Block 5 Zusammenfassung:**
- 7 Findings (F-36-32 bis F-36-38)
- Tier A: 5 Action-Items (überwiegend Korrekturen falscher Aussagen)
- Tier B: **3 größere Feature-Gaps neu aufgedeckt:**
  1. **Reset-Sicherheitsabfrage** bei laufendem Turnier (F-36-32)
  2. **Endrangliste automatisch berechnen** (F-36-34) — großes Feature-Item
  3. **Shootout/Stichspiele-Support** (F-36-35) — **kritisch für KO-Turniere**, eigener Phasen- oder Milestone-Kandidat
- Tier C: 3 Content-Ergänzungen (Ranglisten-Anhang, Shootout-Limitation-Hinweis, CC-Upload-Anhang)

**Aktualisierte Feature-Gap-Liste (aus allen Blöcken bisher):**
1. Teilnehmerliste-Finalisierung via CC-Schnittstelle (F-36-23) — to-be-implemented
2. Credentials-Delegation für Club-Sportwart-Rechte (F-36-23) — organisatorisch-technisch
3. UI-Konsolidierung historisch gewachsener Screens (F-36-15) — groß
4. Tooltip-Feature für Parameterfelder (F-36-16, F-36-19)
5. i18n-Korrekturen (F-36-20, Cross-ref F-14)
6. Manuelle-Rundenwechsel-Kontrolle entfernen (F-36-29) — Vereinfachung
7. "Aktuelle Spiele"-Tabellen-Eingabe-UI entfernen (F-36-28) — Dead-Code-Cleanup
8. **Reset-Sicherheitsabfrage** (F-36-32) — NEU
9. **Endrangliste automatisch berechnen** (F-36-34) — NEU, **groß**
10. **Shootout-Support** (F-36-35) — NEU, **kritisch**

Diese 10 Punkte sind deutlich mehr als "Small UX Fixes". Mehrere sind eigene Phasen oder sogar eigene Milestones.

---

### Block 6: Glossar (Karambol / Wizard / System)

**Reviewed:** 2026-04-14
**Zeilen:** 172–218
**Mode:** schlank

---

#### F-36-39 — Glossar: Ballziel/Aufnahmebegrenzung Verwechslung (Cross-ref F-36-17)
- **Tier:** A
- **Zeile:** 188
- **Issue:** Doppelt falsch — `innings_goal` ist Aufnahmebegrenzung, nicht Bälle-Ziel. Plus: "Bälle-Ziel" → "Ballziel" (bessere Bezeichnung)
- **Action:**
  - Eintrag komplett neu fassen: **Ballziel** (`balls_goal`) + separater Eintrag **Aufnahmebegrenzung** (`innings_goal`)
  - "Bälle vor" ist laut F-36-17 wahrscheinlich die individuelle Vorgabe bei Handikap-Turnieren, nicht das Ballziel. Wenn relevant → separater Eintrag "Bälle vor (Handikap-Vorgabe)"

---

#### F-36-40 — Glossar: Setzliste-Definition falsch (Cross-ref F-36-05)
- **Tier:** A
- **Zeile:** 201
- **Issue:** Aktuell "geordnete Teilnehmerliste, aus Einladung ODER ClubCloud übernommen". Fakten:
  - **In der ClubCloud gibt es KEINE Setzliste.** Die CC führt nur Meldelisten.
  - Die Setzliste wird vom **Landessportwart** aus seinen **Spreadsheets** (mit zusammengeführten Turnierergebnissen) erstellt und kommt nur über die **Einladung**
  - **Carambus führt Rankinglisten pro Spieler** und kann daraus notfalls (wenn die offizielle Einladung fehlt) selbst eine Setzliste erzeugen
- **Action:** Eintrag neu fassen, drei Herkunftsquellen klar trennen:
  1. Offizielle Setzliste aus der Einladung (Normalfall — vom Landessportwart)
  2. Carambus-interne Setzliste aus den eigenen Rankings (Notfall ohne Einladung)
  3. Keine: aus ClubCloud kommt **keine** Setzliste

---

#### F-36-41 — Glossar: Meldeliste + Teilnehmerliste fehlen als eigene Einträge
- **Tier:** A (Doc-Lücke)
- **Action:**
  - Neuer Eintrag **Meldeliste** — Setzliste-Snapshot nach Meldeschluss. Kommt aus der ClubCloud. Vorläufig, kann sich bis zum Turniertag noch ändern
  - Neuer Eintrag **Teilnehmerliste** — Wer physisch anwesend ist. Wird kurz vor Turnierbeginn finalisiert. Resultat aus Meldeliste minus Nichterschienene plus eventuelle Nachmeldungen
  - Cross-ref F-36-02 Begriffshierarchie (Setzliste → Meldeliste → Teilnehmerliste)

---

#### F-36-42 — Glossar: Turnierplan-Kürzel Eintrag (Cross-ref F-36-12)
- **Tier:** A
- **Zeile:** 205
- **Issue:** "Default**5**" ist falsch — korrekt ist **Default{n}** als Template. "Flexibleres Format" ist zu vage.
- **Action:** Eintrag präzisieren:
  - T-nn (z.B. T04, T05) = vordefinierte TournamentPläne aus der Karambol-Turnierordnung; sinnvoll für kleinere Spielerzahlen mit Jeder-gegen-Jeden
  - Default{n} = **besonderer TournamentPlan** (dynamisch generiert) für "Jeder gegen Jeden mit n Spielern", wenn kein passender T-Plan existiert

---

#### F-36-43 — Glossar: Scoreboard-Eintrag — keine feste Tisch-Verbindung (Cross-ref F-36-22)
- **Tier:** A
- **Zeile:** 207
- **Issue:** "Scoreboards verbinden sich automatisch mit dem Turnier-Monitor" — falsch. Die Verbindung ist nicht fest; am Scoreboard wird der physikalische Tisch manuell ausgewählt.
- **Action:** Eintrag anpassen (konsistent zu F-36-22) — Scoreboard bindet sich durch manuelle Tischauswahl an den passenden TableMonitor

---

#### F-36-44 — Glossar: AASM-Status-Eintrag und "Phase 36 wird Status-Badge sichtbarer machen"-Versprechen
- **Tier:** A
- **Zeile:** 214
- **Issues:**
  - "Schritt 4 erledigt = `tournament_seeding_finished`" ist konzeptuell falsch — Schritt 4 ist laut F-36-11 gar kein eigener State
  - "Phase 36 wird dieses Status-Badge sichtbarer machen" — ist ein direkter FIX-04-Hinweis. Nach allem, was wir gefunden haben, ist FIX-04 Teil eines größeren Redesigns. Versprechen sollte hier raus oder mit Realismus versehen werden
- **Action:**
  - State-Mapping-Beispiel korrigieren (Schritt 4 raus)
  - "Phase 36"-Versprechen streichen oder mit Vorbehalt versehen ("... ist ein offenes Verbesserungsfeld")
  - Cross-ref F-36-11, F-36-15, FIX-04

---

#### F-36-45 — Glossar: Rangliste-Eintrag falsch — Rankings in Carambus gepflegt, nicht aus CC
- **Tier:** A
- **Zeile:** 218
- **Issue:** Aktuell "von der ClubCloud-Datenbank bezogen" — falsch. Rankings werden **pro Spieler in Carambus** gepflegt (aus Carambus-eigenen Turnierergebnissen). Cross-ref F-36-05, F-36-40
- **Action:** Eintrag neu fassen — Rangliste ist eine **Carambus-interne** Liste pro Spieler, wird aus Carambus-Turnierergebnissen fortgeschrieben, dient u.a. als Default-Sortierkriterium wenn keine offizielle Setzliste vorhanden ist

---

#### F-36-46 — Glossar: Logische vs. physikalische Tische (Cross-ref F-36-21)
- **Tier:** C (neue Einträge)
- **Context (SME):** Aus Spielersicht existieren nur **physikalische Tische** (Nummern stehen an den Tischen, Wer-wo-spielt steht auf Scoreboards und Table-Score-Monitoren). **Logische Tische** sind nur intern für die Spielpläne relevant — der TournamentPlan referenziert logische Tischnamen, die beim Turnierstart den physikalischen zugeordnet werden.
- **Action:**
  - Neuer Eintrag **Physikalischer Tisch** — nummerierte Spieltische im Spiellokal, für Spieler die einzig sichtbare Form
  - Neuer Eintrag **Logischer Tisch** — TournamentPlan-interne Tisch-Identität, wird beim Turnierstart auf physikalische Tische abgebildet
  - Kurzer Hinweis: Zuordnung ist beim Turnierstart manuell (Teil des Start-Parameter-Formulars, F-36-21)

---

#### F-36-47 — Glossar: TableMonitor fehlt (Cross-ref F-36-22)
- **Tier:** C (neuer Eintrag)
- **Definition (SME):** "Ein Automat, der die Abläufe während eines Spiels am Scoreboard steuert" — aus Spielersicht: ein Bot, der Spiele und Spieler den Tischen zuordnet
- **Action:** Neuer Glossar-Eintrag **TableMonitor**:
  - Technische Kurzdefinition: Automat, der den Spielablauf an einem Tisch steuert (Match-Zuweisungen, Ergebnis-Erfassung, Rundenwechsel)
  - Spielersicht: "Bot, der entscheidet, welches Spiel auf welchem Tisch läuft"
  - Bezug: jeder logische Tisch (F-36-46) hat einen TableMonitor; Scoreboards verbinden sich mit dem TableMonitor über die physikalische Tischauswahl

---

#### F-36-48 — Glossar: Turnier-Monitor eigener Eintrag
- **Tier:** C
- **Issue:** Mehrere Einträge verlinken auf "Turnier-Monitor", aber es gibt keinen eigenen Glossar-Eintrag
- **Definition (SME): "etwas technisch, aber wohl interessant für ein Verständnis der Abläufe"** — Turnier-Monitor ist die übergeordnete Instanz, die alle TableMonitors eines Turniers koordiniert
- **Action:** Neuer Eintrag **Turnier-Monitor** mit kurzer technischer Beschreibung und Bezug zu TableMonitor (F-36-47) und Wizard-Schritten

---

#### F-36-49 — Glossar: Freilos fehlt + Match-Abbruch-Feature-Lücke ⚠️ **neues Feature-Gap**
- **Tier:** C (Glossar) + B (Feature-Gap)
- **Issue:**
  - **Glossar-Lücke:** "Freilos" wird in Block 4 erwähnt (Schritt 11 "Der fünfte Spieler sitzt in Runde 1 aus"), hat aber keinen Eintrag
  - **Feature-Lücke (neu):** **Freilos fehlt auch in der Implementierung.** Es muss möglich sein, ein Spiel abzubrechen, wenn ein Spieler das Spiel nicht anfangen oder beenden kann (z.B. Krankheit, Rückzug, Notfall)
- **Action:**
  - Tier C: Neuer Glossar-Eintrag **Freilos** — Erklärung des Konzepts (Spieler spielt in einer Runde nicht) + Erklärung des Abbruchs (Spieler kann aussetzen/zurückziehen)
  - Tier B (Feature-Arbeit): **Match-Abbruch implementieren** — neuer Code. UI-Button im Turnier-Monitor oder am Scoreboard? Scoreboard wäre konsistent mit F-36-30 (alle Aktionen am Scoreboard). Auswirkung auf AASM-Transitions, Rangliste-Berechnung, Rundenwechsel. **Gehört ins v7.1+ Backlog.**

---

#### F-36-50 — Glossar: T-Plan vs. Default-Plan Unterscheidung (Cross-ref F-36-12, F-36-42)
- **Tier:** A
- **Definition (SME):** "Der Default Plan ist ein **besonderer TournamentPlan** (Jeder gegen Jeden)" — nicht ein Platzhalter oder Fallback, sondern ein First-Class-TournamentPlan-Typ
- **Action:** Bereits durch F-36-42 (Turnierplan-Kürzel-Eintrag neu fassen) abgedeckt. Hier Cross-ref.

---

**Block 6 Zusammenfassung:**
- 12 Findings (F-36-39 bis F-36-50)
- Tier A: 7 Action-Items (überwiegend Korrekturen bestehender Glossar-Einträge)
- Tier B: 1 neues Feature-Gap (**Match-Abbruch / Freilos-Handling** F-36-49)
- Tier C: 5 neue Glossar-Einträge (Meldeliste, Teilnehmerliste, Physikalischer/Logischer Tisch, TableMonitor, Turnier-Monitor, Freilos)
- Meta: Der Glossar ist durchgehend an die in Block 1-5 aufgedeckten Begriffs- und Konzept-Fehler gebunden. Viele Einträge brauchen Folge-Korrekturen aus den anderen Blöcken (Cross-refs zu F-36-02, F-36-05, F-36-11, F-36-12, F-36-15, F-36-17, F-36-21, F-36-22).

**Feature-Gap-Liste aktualisiert (jetzt 11 Items):**
1. Teilnehmerliste-Finalisierung via CC-API (F-36-23)
2. Credentials-Delegation Club-Sportwart (F-36-23)
3. UI-Konsolidierung historisch gewachsener Screens (F-36-15)
4. Tooltips an Parameterfeldern (F-36-16, F-36-19)
5. i18n-Korrekturen (F-36-20)
6. Manuelle Rundenwechsel-Kontrolle entfernen (F-36-29)
7. "Aktuelle Spiele"-Eingabe-UI entfernen (F-36-28)
8. Reset-Sicherheitsabfrage (F-36-32)
9. **Endrangliste automatisch berechnen (F-36-34)** — groß
10. **Shootout-Support (F-36-35)** — kritisch, eigenes Milestone
11. **Match-Abbruch / Freilos-Handling (F-36-49)** — **neu, mittelgroß**

---

### Block 7: Problembehebung + "Mehr zur Technik"

**Reviewed:** 2026-04-14
**Zeilen:** 222–268
**Mode:** schlank

---

#### F-36-51 — TS-1: PDF-Upload wird unfair dargestellt
- **Tier:** A
- **Zeile:** 232
- **Issues:**
  - "ClubCloud-Meldeliste als Quelle — Alternative in Schritt 3" — setzt die PDF-vs-CC-Alternative-Framing fort (Cross-ref F-36-05)
  - "Die ClubCloud-Route ist für reine NBV-Turniere in der Praxis zuverlässiger als der PDF-Upload" — **faktisch falsch.** PDF-Upload funktioniert prächtig, weil der Landessportwart immer wiederverwendete Templates nutzt, die sehr gut vom Parser verstanden werden.
- **Action:**
  - Rezept neu fassen konsistent zu F-36-05 (keine Entweder-Oder-Alternative)
  - PDF-Bashing-Satz streichen. Ehrliches Framing: PDF-Upload ist der Normalfall; wenn er mal fehlschlägt, gibt es die CC-Meldeliste als Backup

---

#### F-36-52 — TS-2: Rezept für Edge-Case, der fast nie auftritt
- **Tier:** A (Rezept entschärfen oder umformulieren)
- **Zeile:** 235–241
- **Issue:**
  - Der beschriebene Fall "Spieler nicht in der ClubCloud-Meldeliste" ist **normalerweise gar nicht möglich** — er trat nur im Phase-33-Test auf, weil der Test **vor dem Meldeschluss** durchgeführt wurde
  - Im Normalbetrieb ist die Einladung (falls verfügbar) kompatibel mit der CC-Meldeliste, weil beide den gleichen Meldeschluss-Snapshot darstellen
- **Action:**
  - Rezept entweder umformulieren zu einem realistischen Fall ("Wenn der Sync vor Meldeschluss durchgeführt wurde" / "Wenn ein Spieler nachgemeldet werden soll") ODER komplett streichen
  - Cross-ref F-03/F-04 in 33-UX-FINDINGS.md als möglicherweise selbst stale reklassifizieren — das beobachtete Verhalten war ein Test-Artefakt, kein Produktionsproblem

---

#### F-36-53 — TS-3: DefaultS falsch + fiktiver "Modus ändern"-Button
- **Tier:** A
- **Zeilen:** 246, 250
- **Issues:**
  - Zeile 246: "DefaultS" falsch (Cross-ref F-36-12, F-36-42) — korrekt `Default{n}`; "drei Modus-Karten" ist nicht immer drei
  - Zeile 250: **"Schaltfläche Modus ändern" existiert nicht**. Das Rezept beschreibt ein fiktives UI-Element.
- **Action:**
  - Zeile 246: DefaultS → `Default{n}`, "drei Karten" → "eine oder mehrere Karten"
  - Zeile 250: "Modus ändern"-Button ersatzlos streichen. Richtige Lösung: **"Zurücksetzen des Turnier-Monitors"-Link** auf der Turnierseite (cross-ref F-36-10, F-36-32 — mit Sicherheitshinweis wegen potenziellem Datenverlust wenn schon Ergebnisse erfasst wurden)

---

#### F-36-54 — TS-4: Komplette Neufassung — DB-Admin-Recovery existiert nicht
- **Tier:** A (große Korrektur)
- **Zeilen:** 252–259
- **Issues (zwei fundamentale Fehler):**
  1. "keinen Undo-Pfad für gestartete Turniere" — **falsch**. Der "Zurücksetzen des Turnier-Monitors"-Link existiert (Cross-ref F-36-10, F-36-32). Allerdings: bei laufendem Turnier bedeutet Reset totaler Datenverlust der bisher erfassten Spiele.
  2. **"Admin mit Datenbankzugang kann helfen" — falsch.** Selbst der DB-Admin kann nicht helfen. Selbst der Entwickler ist machtlos, weil die zu ändernden Datenstrukturen zu komplex sind. Das Rezept erzählt einen Rettungsweg, den es nicht gibt.
- **Realität (SME):**
  - Bei gestartetem Turnier lassen sich Parameter **nicht** mehr ändern — das ist Feature, nicht Bug
  - UNDO existiert nur in einzelnen Spielen **am Scoreboard**
  - Bei ernsten Problemen: **ehrlich Fehler eingestehen + zur herkömmlichen Methode (ohne Carambus) wechseln**
  - Scoreboards können im **Trainingsmodus** betrieben werden zur Abwicklung einzelner Spiele — das ist ein bisher im Doc undokumentiertes Feature
- **Action:**
  - Rezept komplett neu schreiben:
    - Ehrliche Aussage: gestartete Turniere sind nicht nachträglich umparametrierbar
    - Reset-Link existiert, aber zerstört Daten bei laufendem Turnier
    - Wenn wirklich was schiefgeht: Fallback auf herkömmliche Methode (Papierprotokoll, ClubCloud-Direkteingabe) + Scoreboards im Trainingsmodus für die einzelnen Spiele verwenden
  - Streichen: Admin/DB-Rettungsweg-Prosa
- **Cross-ref:** F-19 (33-UX-FINDINGS) — sollte entsprechend reklassifiziert werden

---

#### F-36-55 — Neues Feature-Item: Parameter-Verifikationsdialog vor Turnier-Start
- **Tier:** B (Feature-Vorschlag)
- **Context (SME):** "Man könnte ungewöhnlich gesetzte Parameter herausstellen und in einen Verifikationsdialog gehen."
- **Idee:** Vor dem Klick auf "Starte den Turnier Monitor" eine Prüfung der Start-Parameter. Wenn Werte vom Disziplin-üblichen Default deutlich abweichen (z.B. Ballziel < 50 oder > 200 für Freie Partie), einen Bestätigungsdialog anzeigen: "Folgende Werte sind ungewöhnlich für diese Disziplin: ... Wirklich fortfahren?"
- **Action:** Tier B Folge-Phase-Kandidat. **Reduziert das Risiko, dass F-36-54 überhaupt eintritt.**

---

#### F-36-56 — Neues Konzept: Trainingsmodus am Scoreboard (bisher nirgends dokumentiert)
- **Tier:** A (Doc) + C (Glossar)
- **Context (SME):** Scoreboards können im **Trainingsmodus** betrieben werden — zur Abwicklung einzelner Spiele ohne Turnier-Kontext. Dient u.a. als Fallback wenn das Carambus-Turnier nicht mehr änderbar ist (F-36-54).
- **Issue:** Weder das Doc noch der Glossar erwähnt das Konzept. Für Vereinsmitglieder ist der Trainingsmodus wahrscheinlich auch im Alltag nutzbar.
- **Action:**
  - Tier C: Neuer Glossar-Eintrag **Trainingsmodus** — Kurzbeschreibung + Hinweis, wann er relevant ist (Training, Freundschaftsspiele, Fallback bei Turnier-Problemen)
  - Tier A: Hinweis im Troubleshooting-Rezept F-36-54 auf den Trainingsmodus als Fallback-Lösung

---

#### F-36-57 — "Mehr zur Technik" komplett raus
- **Tier:** A
- **Zeilen:** 263–268
- **Issue (SME):** "Komplett raus!" — LocalProtector, API-Server/lokale Server, etc. — alles Entwickler-Info, die für einen Volunteer nicht hilfreich ist
- **Action:**
  - Den kompletten "Mehr zur Technik"-Abschnitt inklusive `<a id="architecture"></a>` streichen
  - Falls ein Link zur Entwickler-Doku behalten werden soll: ein schlanker Einzeiler am Dokumentende reicht

---

#### F-36-58 — Fehlende Troubleshooting-Rezepte
- **Tier:** C (neue Inhalte)
- **Issue:** Die aktuellen 4 Rezepte decken nur einen Bruchteil der realen Probleme ab. Aus den anderen Findings leiten sich folgende fehlende Rezepte ab:
  1. **"Endrangliste fehlt nach Turnierende"** — Cross-ref F-36-34. Rezept: Rangliste wird derzeit manuell in der ClubCloud gepflegt (+ Anhang)
  2. **"CSV-Upload in die ClubCloud funktioniert nicht"** — Cross-ref F-36-23/F-36-37/F-36-38. Rezept: Teilnehmerliste muss in CC finalisiert sein; Pfad zum CSV-Upload-Admin-Interface; häufige Fehler
  3. **"Spieler zieht während des Turniers zurück"** — Cross-ref F-36-49. Kein sauberer Weg vorhanden — Workaround: Spiel am Scoreboard als Freilos behandeln (falls möglich), sonst Trainingsmodus-Fallback
  4. **"Englische Feldbezeichnungen im Start-Formular"** — Cross-ref F-36-20, F-14. Rezept: Liste der häufigsten fehlerhaften Labels mit deutscher Übersetzung, bis die i18n-Korrektur ausgerollt ist
  5. **"Nachstoß vergessen am Scoreboard"** — Cross-ref F-36-31. Rezept: Wie im Protokoll nachträglich ergänzen (falls überhaupt möglich)
  6. **"Shootout / Stechen nötig"** — Cross-ref F-36-35. Rezept: Stechen derzeit nicht unterstützt — manuell durchführen, Ergebnis außerhalb Carambus dokumentieren
- **Action:** 6 neue Rezepte in der Problembehebung ergänzen

---

**Block 7 Zusammenfassung:**
- 8 Findings (F-36-51 bis F-36-58)
- Tier A: 5 große Korrekturen (TS-1 PDF-Framing, TS-2 Edge-Case, TS-3 fiktiver Button, TS-4 Recovery-Fehlinfo, Technik-Abschnitt raus)
- Tier B: 1 neues Feature (Parameter-Verifikationsdialog vor Start — **reduziert Risiko von F-36-54**)
- Tier C: 2 neue Glossar/Inhalt-Einträge (Trainingsmodus, 6 fehlende Troubleshooting-Rezepte)

**Feature-Gap-Liste jetzt 12 Items (+1 aus Block 7):**
1. Teilnehmerliste-Finalisierung via CC-API (F-36-23)
2. Credentials-Delegation Club-Sportwart (F-36-23)
3. UI-Konsolidierung historisch gewachsener Screens (F-36-15)
4. Tooltips an Parameterfeldern (F-36-16, F-36-19)
5. i18n-Korrekturen (F-36-20)
6. Manuelle Rundenwechsel-Kontrolle entfernen (F-36-29)
7. "Aktuelle Spiele"-Eingabe-UI entfernen (F-36-28)
8. Reset-Sicherheitsabfrage (F-36-32)
9. Endrangliste automatisch berechnen (F-36-34) — groß
10. Shootout-Support (F-36-35) — kritisch, eigenes Milestone
11. Match-Abbruch / Freilos-Handling (F-36-49)
12. **Parameter-Verifikationsdialog vor Turnier-Start (F-36-55)** — **neu, klein, hoher Wert**

---

## REVIEW KOMPLETT — Statistik

**Gesamt:** 58 Findings (F-36-01 bis F-36-58) über 7 Blöcke und 268 Zeilen

**Tier-Verteilung (approximativ):**
- **Tier A (Doc-Korrekturen):** ~60 Action-Items — mehrheitlich kleinere Korrekturen, einige komplette Neufassungen
- **Tier B (Folge-Phase-Kandidaten):** 12 Items — sieben sind echte Code-Features, fünf sind UI-Redesign oder Cleanup
- **Tier C (neue Inhalte):** ~25 Items — überwiegend Glossar-Ergänzungen und neue Troubleshooting-Rezepte
- **Meta-Findings:** 3 große Strukturfragen
  - F-36-11/F-36-15: Wizard-Schritt ≠ AASM-State ≠ UI-Screen
  - F-36-23: ClubCloud-Upload-Modell unvollständig
  - Walkthrough-Gliederung ("Schritt für Schritt") suggeriert mehr Turnierleiter-Aktivität als real existiert

**Vordringlichste strukturelle Erkenntnis:**
Phase 36 in der ursprünglichen Form ("Small UX Fixes" mit FIX-01..04) beschreibt einen Bruchteil der tatsächlichen Arbeit. Die entdeckten Lücken sind drei fundamental verschiedene Kategorien:
1. **Doc-Arbeit** (viele Tier-A-Items) — kann als eine Phase oder mehrere kleinere Plans erledigt werden
2. **UI-Cleanup + kleinere Features** (F-36-16, 19, 20, 28, 29, 32, 55) — ergibt eine eigene Phase
3. **Echte Code-Features** (F-36-23, 34, 35, 49) — **größer als eine Phase**, teilweise Milestone-Umfang (Shootout!)

---

_Review abgeschlossen. Nächster Schritt: Triage-Diskussion und Organisations-Entscheidung._
