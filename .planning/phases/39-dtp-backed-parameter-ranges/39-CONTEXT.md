# Phase 39: DTP-Backed Parameter Ranges - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

`Discipline#parameter_ranges` wird kontextabhängig: queriert die bestehende
`discipline_tournament_plans`-Tabelle, statt fest kodierter Konstanten. Liefert für
ein Tournament-Argument einen Hash mit Range-Werten für `balls_goal` und
`innings_goal`, abgeleitet aus dem DTP-Eintrag für (Disziplin + tournament_plan +
players + player_class). Verifikations-Modal in `tournaments_controller.rb#start`
feuert künftig nicht mehr false-positiv auf legitime Jugend-/Handicap-/Pool-/
Snooker-/Biathlon-/Kegel-Konfigurationen, weil:

- Ranges leiten sich aus echten DTP-Daten ab (statt einer einzigen weiten
  Hardcoded-Range pro Carambol-Disziplin),
- Disziplinen ohne DTP-Eintrag liefern `{}` (= "no check"),
- Handicap-Turniere liefern `{}` (= "no check"),
- Operator-Felder ohne Master-Daten-Quelle (timeout, sets_to_*, warm-up-Timeouts)
  verlassen die Verifikation komplett.

**Out of scope für Phase 39:** UI-Veränderungen am TournamentMonitor-Form (Checkbox
"Reduced-Defaults"), neue DB-Migrationen (kein `tournament.reduced_format`-Spalte),
Untersuchung der DTP-Lückenmuster (Investigation-Item, separate Phase oder Backlog).

</domain>

<decisions>
## Implementation Decisions

### Methoden-Signatur und Lookup

- **D-01:** `Discipline#parameter_ranges(tournament:)` ist die kanonische Signatur
  (Keyword-Argument). Hartes Brechen mit der bisherigen No-Arg-Variante;
  Aufrufer in `app/controllers/tournaments_controller.rb#verify_tournament_start_parameters`
  wird auf den neuen Aufruf umgestellt (`tournament.discipline&.parameter_ranges(tournament: tournament)`).

- **D-02:** Lookup-Query: `DisciplineTournamentPlan.where(discipline: self,
  tournament_plan: tournament.tournament_plan, players: tournament.seedings.count,
  player_class: <derived>)`. Bei Class-Mismatch greift D-04 (Fallback-Walk).

- **D-03:** `players`-Argument für DTP-Query = `tournament.seedings.count` (live count
  aus der Seedings-Assoziation, nicht aus `TournamentPlan.players`). Begründung:
  Verifikation läuft pre-start, aber nach Seeding-Eintrag — `seedings.count`
  reflektiert die tatsächlich gemeldeten Spieler. **Researcher-Auftrag:** prüfen,
  ob das in allen Fällen den DTP-Werten entspricht (TournamentPlan.players ist als
  Cross-Check verfügbar).

### Player-Class-Hierarchie und Fallback

- **D-04:** Player-Class-Ordnung (worst → best):
  `PLAYER_CLASS_ORDER = %w[7 6 5 4 3 2 1 I II III].freeze`. Lebt als Konstante auf
  `Discipline` (oder optional auf `PlayerClass`). Eine spätere Daten-Source-of-Truth-
  Migration (z. B. `player_classes.order_index`) ist für Phase 39 NICHT in scope.

- **D-05:** Class-Match-Strategie: Erst exakter Match auf `tournament.player_class`,
  bei 0 Treffern Walk in Richtung "höher" (besser) durch `PLAYER_CLASS_ORDER` bis
  zum ersten Treffer. Kein Walk in Richtung "niedriger". Bei vollständigem
  Walk-Miss: leerer Hash (`{}`).

- **D-06:** Lückenmuster in DTPs (z. B. `4` und `6` vorhanden, `5` fehlt) sind
  **Investigation-Item, kein Phase-39-Blocker**. Phase 39 implementiert die
  Fallback-Logik korrekt; Daten-Audit + Auffüllung der Lücken läuft separat
  (Backlog-Kandidat oder Quick-Task).

### Reduced-Mode (operator-getroffene Reduktion)

- **D-07:** Reduktionsfaktor ist **0.75**, nicht 0.80. Phase 38 D-20 war hier
  veraltet — die Praxis ist 80/20 → 60/15 (= 0.75x). Phase 39 nutzt 0.75
  durchgängig in Tests und Code.

- **D-08:** Lenient-OR-Modus: `parameter_ranges` liefert für points → Range
  `(canonical*0.75).floor..canonical` und für innings analog. Keine Modus-
  Unterscheidung, kein Trigger. Operator gibt entweder Voll- oder Reduced-Werte
  ein, beide passen.

- **D-09:** Kein Tournament-Flag, keine Migration. Die operator-getroffene
  Reduced-Entscheidung steht in der Turnier-Einladung (Landessportwart) und ist
  nicht maschinenlesbar im DB-Modell zu repräsentieren.

### Non-DTP-Disziplinen + handicap_tournier

- **D-10:** Disziplinen OHNE DTP-Eintrag (BK-Familie aus Phase 38.6: BK-2kombi,
  BK50, BK100, BK-2, BK-2plus; Pool, Snooker, Kegel, Biathlon, 5-Kegel; sowie
  Karambol-Spezialvarianten ohne DTP-Daten wie "Freie Partie" ohne Suffix,
  "Cadre 47/1", "Einband", "Dreiband") → `parameter_ranges` liefert `{}`.
  Verifikations-Controller springt via `return [] if ranges.empty?` ab. Keine
  Hardcoded-Fallback-Tabelle.

- **D-11:** Wenn `tournament.handicap_tournier == true` → `parameter_ranges`
  liefert `{}` unabhängig von der Disziplin. Begründung: balls_goal ist
  per-Seeding (siehe `seedings.balls_goal`-Spalte), innings ist nicht limitiert
  (open-ended Spielzeit). Tournament-Level-Felder sind bei den 4 vorhandenen
  Handicap-Turnieren typisch nil.

### Verifikations-Felder (Controller-Seite)

- **D-12:** `UI_07_FIELDS` in `app/controllers/tournaments_controller.rb` wird auf
  `[:balls_goal, :innings_goal]` reduziert. Die 5 bisher mitgeprüften Felder
  (`timeout`, `sets_to_play`, `sets_to_win`, `time_out_warm_up_first_min`,
  `time_out_warm_up_follow_up_min`) sind operator-eingegebene Parameter aus der
  Turnier-Einladung — kein Master-Daten-Bezug. Verifikation entfällt für sie.

- **D-13:** `UI_07_SENTINEL_VALUES` (Layer-4-Fix aus quick-260506-o93) bleibt
  unangetastet, weil die Sentinel-Logik nur für `sets_to_play`/`sets_to_win`
  galt und diese nach D-12 ohnehin nicht mehr geprüft werden. Die Konstante
  wird mit-gestrichen, da sie Toten Code wird.

### Konstanten-Cleanup

- **D-14:** Folgende Konstanten in `app/models/discipline.rb:60-94` werden
  vollständig entfernt:
  - `UI_07_SHARED_RANGES`
  - `UI_07_DISCIPLINE_SPECIFIC_RANGES`
  - `DISCIPLINE_PARAMETER_RANGES`
  Der bisherige Kommentar zu D-17 (Phase 36B) sowie der 2026-04-27-Widening-
  Hinweis werden ebenfalls entfernt — Phase 39 löst das thematisch ab.

- **D-15:** Folgende Konstanten in `app/controllers/tournaments_controller.rb`
  werden entfernt: `UI_07_FIELDS` wird **reduziert** (siehe D-12),
  `UI_07_SENTINEL_VALUES` wird **gelöscht** (siehe D-13).

### Test-Strategie

- **D-16:** `test/models/discipline_test.rb` deckt ab:
  (a) DTP-Hit Normal: Tournament mit Disziplin+Plan+players+class, das exakt eine
      DTP-Row matcht → Range = `(p*0.75..p)` für points, analog innings.
  (b) Class-Fallback-Walk: kein exakter Class-Match → erster höherer Match wird
      gefunden.
  (c) Walk-Miss: kein Match in `PLAYER_CLASS_ORDER` → `{}`.
  (d) Non-DTP-Disziplin (z. B. Pool, BK-2kombi) → `{}`.
  (e) handicap_tournier=true (egal welche Disziplin) → `{}`.
  (f) tournament.tournament_plan=nil → `{}` (defensiv).

- **D-17:** `test/system/tournament_parameter_verification_test.rb` wird angepasst:
  bestehende Karambol-Test-Cases bleiben gültig (Range-Werte ggf. anpassen wegen
  0.75-Faktor und der DTP-abgeleiteten Bounds), neue Cases für Pool-/BK-/
  Handicap-Turniere validieren das No-Check-Verhalten.

- **D-18:** Bestehende Fixtures/Factories für DisciplineTournamentPlan werden
  **gelesen**, nicht neu erstellt. `test/fixtures/discipline_tournament_plans.yml`
  bzw. die existierenden 464 DB-Rows werden Test-seitig genutzt.

### Claude's Discretion

- Genaue Methoden-Komposition innerhalb `Discipline#parameter_ranges(tournament:)`
  (Hilfsmethoden-Extraktion, Modul-Split — solange die externe API D-01 stimmt).
- Reihenfolge der Branches innerhalb der Methode (handicap-Check zuerst vs.
  Disziplin-DTP-Check zuerst — beide liefern `{}` bei Trefferlosigkeit).
- Konkrete Test-Datenkonstellationen, solange D-16 a–f abgedeckt sind.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 38 Sketch und Vorab-Entscheidungen

- `.planning/phases/38-ux-polish-i18n-debt/38-CONTEXT.md` §D-19/D-20/D-21 —
  ursprünglicher Phase-39-Sketch. **Achtung: D-20 nennt Faktor 0.80, das ist in
  Phase 39 D-07 auf 0.75 korrigiert.**
- `.planning/phases/38.6-discipline-master-data-cleanup/38.6-CONTEXT.md` —
  Liste der 5 BK-Disziplinen als kanonische Discipline-Records (BK-2kombi, BK50,
  BK100, BK-2, BK-2plus). Diese haben keine DTP-Einträge → fallen unter D-10.
- `.planning/phases/38.5-bk-param-hierarchy-multiset-config/38.5-CONTEXT.md` —
  BK-Param-Hierarchie 5-stufig. Phase 39 ist orthogonal: parameter_ranges
  versorgt die Verifikation, BK-Param-Hierarchie versorgt die Score-Engine.
  Keine direkte Code-Berührung erwartet.

### Anforderungen und Roadmap

- `.planning/REQUIREMENTS.md` §DATA-01 — Anforderungs-Statement, das durch
  Phase 39 erfüllt wird.
- `.planning/ROADMAP.md` §"Phase 39: DTP-Backed Parameter Ranges" — Goal +
  6 Success Criteria.

### Code-Touchpoints

- `app/models/discipline.rb:51-101` — bestehende `DISCIPLINE_PARAMETER_RANGES`-
  Implementierung + bestehender Phase-39-Hinweis-Kommentar (Zeilen 67-72).
- `app/models/discipline_tournament_plan.rb` — DTP-Modell mit Schema-Kommentar.
- `app/controllers/tournaments_controller.rb` (Method `verify_tournament_start_parameters`,
  Konstanten `UI_07_FIELDS`, `UI_07_SENTINEL_VALUES`) — Aufrufer der Methode.
- `app/models/tournament.rb` — Felder `tournament_plan_id`, `player_class`,
  `handicap_tournier`. `seedings`-Assoziation.
- `app/models/seeding.rb` — `balls_goal`-Spalte (per-participant, relevant für
  D-11-Begründung).
- `app/models/player_class.rb` — `shortname`-Spalte; Phase 39 modelliert die
  Klassen-Ordnung NICHT auf diesem Modell, sondern als Discipline-Konstante (D-04).

### Tests

- `test/models/discipline_test.rb` — wird gemäß D-16 erweitert.
- `test/system/tournament_parameter_verification_test.rb` — wird gemäß D-17
  angepasst.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Discipline has_many :discipline_tournament_plans`** (line 26) — Assoziation
  bereits vorhanden, kein neuer Code für die Lookup-Beziehung nötig.
- **`DisciplineTournamentPlan`** Modell mit Schema (`points`, `innings`, `players`,
  `player_class`, `discipline_id`, `tournament_plan_id`) — direkt query-fähig.
- **`Tournament#seedings`** Assoziation für D-03 (live `players`-count).
- **`tournaments_controller.rb#verify_tournament_start_parameters`** behandelt
  bereits leeren Range-Hash (`return [] if ranges.empty?`) und nil-range
  (`next unless range`) — defensive Codepfade existieren, Phase 39 muss sie
  nur konsistent füttern.

### Established Patterns

- **Hash-of-Ranges-Returnvalue** (Phase 36B D-17) bleibt das Vertrags-Format.
  Phase 39 ändert nur die Quelle, nicht die Form.
- **Konstanten-Cleanup nach Phase-Übergang** ist im Projekt etabliert (siehe
  Phase 38.5/38.6 Vorgehen). Phase 39 entfernt drei Konstanten + Felder-Liste
  + Sentinel-Konstante in einer Phase, mit Tests als Sicherheitsnetz.
- **`LocalProtector`-Concern**: `Discipline` und `DisciplineTournamentPlan` sind
  beide global (`id < 50_000_000`). Phase 39 schreibt KEINE neuen DB-Daten —
  nur Lese-Queries.

### Integration Points

- **`tournaments_controller.rb#verify_tournament_start_parameters`** (existing
  Methode) — einzige Aufruf-Site von `parameter_ranges`. Aufruf wird auf
  Keyword-Form `parameter_ranges(tournament: tournament)` migriert.
- **Test-Fixtures**: `test/fixtures/discipline_tournament_plans.yml` (falls
  existent) bzw. die produktiven 464 DTP-Rows. Researcher prüft den
  Fixture-Stand und entscheidet ob Factory-Bot oder Fixtures der bessere Weg
  für die DTP-spezifischen Tests sind.

</code_context>

<specifics>
## Specific Ideas

- "Lieber den strengeren Bereich anwenden, kleinere False-Positive-Gefahr" —
  begründet die D-05-Wahl "Walk in Richtung höhere Klasse" (anstelle niedrigerer
  Klasse oder Strict-Only).
- "Reduced wird typischerweise in der Einladung vom Landessportwart entschieden" —
  begründet D-09 (kein DB-Flag, keine Migration). Operator-Intent steht in einem
  PDF, nicht in der DB.
- "Überschreiben der Ziele im TournamentMonitor Formular muss aber möglich
  bleiben" — begründet die Lenient-OR-Wahl (D-08). Operator hat immer
  Wert-Hoheit, parameter_ranges ist nur Tippfehler-Filter.
- "Operator-Felder kommen aus der Ausschreibung" — begründet D-12 (keine
  System-Verifikation für timeout/sets_to_*/warm-up-Timeouts).

</specifics>

<deferred>
## Deferred Ideas

- **TournamentMonitor-Form-Checkbox "Reduced-Modus"**: Pre-fill der
  `balls_goal`/`innings_goal`-Felder mit 0.75x der Standardwerte aus DTP. Reine
  UI-Komfortfunktion, ohne Persistierung im Datenmodell. Kandidat für Backlog
  oder spätere v7.x-Phase.
- **DTP-Daten-Audit**: warum sind in einigen Disziplin/Plan/Players-Kombinationen
  die player_class-Einträge lückig (z. B. "4" und "6" da, "5" fehlt)?
  Daten-Auffüllung oder bewusste Begründung der Lücken. Backlog-Kandidat.
- **Player-Class-Ordnung als DB-Daten-Source**: Migration einer
  `player_classes.order_index`-Spalte und Seed der Ordnung. Würde D-04 von einer
  Konstante auf eine DB-Lookup umstellen. Erst sinnvoll wenn die Ordnung
  variieren soll (z. B. pro Disziplin).
- **Long-term DB-backed historical-data Range**: aus realen Tournament-Daten
  per Nightly-Rake aktualisierte Ranges. Aus Phase 38 explizit out-of-scope und
  bleibt es auch für Phase 39.

</deferred>

---

*Phase: 39-dtp-backed-parameter-ranges*
*Context gathered: 2026-05-06*
