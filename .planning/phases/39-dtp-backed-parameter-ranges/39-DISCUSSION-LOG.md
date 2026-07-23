# Phase 39: DTP-Backed Parameter Ranges - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-06
**Phase:** 39-dtp-backed-parameter-ranges
**Areas discussed:** DTP-Lookup-Semantik (Felder + Rows), Reduced-Mode-Trigger, Fallback für Non-DTP-Disziplinen, handicap_tournier Branch

---

## DTP-Lookup-Semantik (Felder + Rows)

### Q1: Woher kommt die `players`-Zahl für den DTP-Lookup?

| Option | Description | Selected |
|--------|-------------|----------|
| TournamentPlan.players | Kanonisches Feld am TournamentPlan (T08→players=6 etc.). Pre-start deterministisch. | |
| seedings.count | Live aus tournament.seedings.count. Reflektiert tatsächliche Anmeldungen. | ✓ |
| Plan first, seedings fallback | TournamentPlan.players primär, falls nil dann seedings.count. | |

**User's choice:** seedings.count
**Notes:** Kein expliziter Kommentar — Kurze direkte Wahl trotz Recommendation TournamentPlan.players. Logge als Researcher-Auftrag (CONTEXT D-03), ob seedings.count im Production-Workflow alle Fälle abdeckt.

### Q2: player_class fallback bei fehlendem exakten Match

| Option | Description | Selected |
|--------|-------------|----------|
| Nächst-höhere Klasse | Fallback in Richtung höhere/bessere Klasse | ✓ |
| Nächst-niedrigere Klasse | Fallback in Richtung niedrigere/schlechtere Klasse | |
| Strict-only → empty hash | Kein Match → empty hash | |
| nil-class fallback | Fallback auf player_class=nil-Row | |

**User's choice:** "Nächst-höhere Klasse, aber ich muss checken, warum da Lücken sind"
**Notes:** Class-Hierarchie 7,6,5,4,3,2,1,I,II,III (7 schlechteste, III beste — vom User in vorheriger Antwort etabliert). Die Lückenfrage ist als Investigation-Item ins CONTEXT.md aufgenommen (D-06, Deferred Ideas).

### Q3: Wo wird die Klassenhierarchie hinterlegt?

| Option | Description | Selected |
|--------|-------------|----------|
| Discipline-Konstante | PLAYER_CLASS_ORDER auf Discipline | |
| PlayerClass-Modell | Ordering im PlayerClass-Modell | |
| DB-Spalte order | order_index Spalte migrieren | |

**User's choice (free-text):** "Ergibt sich aus dem Spieler-Ranking pro Disziplin"
**Notes:** Domänenseitig richtig — die Class-Order leitet sich aus player_ranking ab. Für Phase 39 reicht eine Konstante (D-04), Daten-Source-Migration ist deferred.

### Q4: Was passiert mit timeout, sets_to_play, sets_to_win, time_out_warm_up_*?

| Option | Description | Selected |
|--------|-------------|----------|
| UI_07_SHARED behalten | Konstante in Discipline behalten, in Result-Hash mergen | |
| Aus Verifikation streichen | UI_07_FIELDS auf [balls_goal, innings_goal] reduzieren | ✓ |
| Tournament-Defaults-Konstante | Globale Range-Konstante auf Controller-Level | |

**User's choice (free-text):** "Das sind alles Parameter, die in der Regel in der Ausschreibung festgelegt werden und die über die Parameter zum Start des TournamentMonitor festgelegt werden"
**Notes:** Operator-Eingabe → keine Master-Daten-Source → Verifikation entfernt. Mappt auf Option 2 (D-12).

---

## Reduced-Mode-Trigger

### Q1: WANN gilt der Reduced-Range (points*0.8..points)?

| Option | Description | Selected |
|--------|-------------|----------|
| Lenient OR — immer beide akzeptieren | Range immer (value*0.75..value) | ✓ |
| Tournament.reduced_format Migration | Boolean-Spalte mit UI-Toggle | |
| Tournament.data['reduced_format'] | JSON-Key | |
| Zwei-Stufen-Modal | Außerhalb Reduced blockt, dazwischen warnt | |

**User's choice (free-text Round 1):** "Tatsächlich ist die Reduktion 0.75 Also z.B. Bälle/Aufnahmen von 80/20 auf 60/15 reduziert. Wird gemacht, wenn man einen Modus wählt, der mehr als 5-6 Runden erforderlich macht, um die Gesamtzeit des Turniers zu verkürzen. Wird typischerweise in der Einladung vom Landessportwart entschieden."

**Notes Round 1:**
- **Korrektur Faktor 0.75 (nicht 0.80)** — Phase 38 D-20 war veraltet. Phase 39 D-07.
- Reduced ist menschliche Entscheidung in Ausschreibung — nicht aus DB ableitbar.

**User's choice (Round 2 follow-up):** "Nur im Formular für dem TournamentMonitor festzulegen. Man könnte dort eine checkbox anbringen und dann die default Ziele reduziert anzeigen. Überschreiben der Ziele im TournamentMonitor Formular muss aber möglich bleiben."

**Notes Round 2:** UI-Checkbox ist UI-Komfort, nicht Datenmodell-Feature → Deferred. Range-Logik = Lenient OR (D-08), Faktor 0.75.

### Q2: TournamentMonitor-Checkbox für reduced-Defaults — Phase 39 Scope?

| Option | Description | Selected |
|--------|-------------|----------|
| Ja, deferred | Phase 39 = nur Range-Logik. Checkbox = spätere Phase | ✓ |
| Nein, gehört rein | Phase 39 erweitert auch UI | |
| Phase 39 macht Skelett | Client-only Pre-Fill ohne Persistierung | |

**User's choice:** Ja, deferred
**Notes:** Klare Scope-Begrenzung. Idee bleibt im Deferred-Block.

---

## Fallback für Non-DTP-Disziplinen

### Q1: Was liefert parameter_ranges für Disziplinen ohne DTP-Eintrag?

| Option | Description | Selected |
|--------|-------------|----------|
| Empty hash (= no check) | {} → Verifikation springt ab | ✓ |
| Hardcoded fallback hash | Konstante DISCIPLINE_FALLBACK_RANGES für explizite Liste | |
| Hybrid: BK-* fallback, Rest empty | BK-Familie kriegt fallback, andere empty | |

**User's choice:** Empty hash (= no check)
**Notes:** Klare, einfache Regel. Mappt auf D-10. Konsistent mit handicap_tournier-Behandlung (D-11).

---

## handicap_tournier Branch

### Q1: Was liefert parameter_ranges für Tournament mit handicap_tournier=true?

| Option | Description | Selected |
|--------|-------------|----------|
| Empty hash (= no check) | Kompletter Skip — balls_goal+innings beide nicht geprüft | ✓ |
| innings skip, balls_goal weit | Innings raus, balls_goal als 0..2000 Catch-all | |
| Pro-Seeding-Aggregat | Verifikation der per-Seeding balls_goal-Werte | |

**User's choice:** Empty hash (= no check)
**Notes:** Saubere Begründung — balls_goal ist per-Seeding (D-11), innings ist nicht limitiert. Identische Returnform wie Non-DTP-Disziplin → vereinfacht Verifikations-Code.

---

## Claude's Discretion

- Genaue Methoden-Komposition innerhalb `parameter_ranges` (Hilfsmethoden, Modul-Split)
- Reihenfolge der Branches (handicap-Check zuerst vs. Disziplin-Check zuerst)
- Konkrete Test-Datenkonstellationen, solange D-16 a–f abgedeckt sind

## Deferred Ideas

- TournamentMonitor-Form-Checkbox "Reduced-Modus" (UI-Pre-Fill)
- DTP-Daten-Audit: Warum Lücken in player_class-Einträgen?
- Player-Class-Ordnung als DB-Daten-Source (`player_classes.order_index`)
- Long-term DB-backed historical-data Range (aus Phase 38 deferred, bleibt es)

## Inflight Corrections

- **Phase 38 D-20 Faktor-Korrektur**: Sketch sagte 0.80, real ist 0.75. CONTEXT D-07 dokumentiert die Korrektur explizit.
- **DTP-Felder-Verständnis**: Initial vermutete Phase-39-Implementierung würde alle 7 UI_07_FIELDS füttern; Codebase-Probe zeigte DTP hat nur points + innings. Folge: D-12 streicht 5 Felder aus UI_07_FIELDS.
