---
status: complete
phase: 39-dtp-backed-parameter-ranges
source:
  - 39-01-SUMMARY.md
  - 39-02-SUMMARY.md
started: 2026-05-07T00:00:00Z
updated: 2026-05-07T02:04:00Z
note: |
  Round 2 — Quick-Task 260507-24p (commits fa5c9529 + 6495a293 + d380da6b) hat
  Gap-01 (seedings.count zählte globale Records) geschlossen. Re-Validierung
  abgeschlossen mit 4 pass + 3 skipped (alle mit Begründung) + 0 issues.
---

## Current Test
<!-- OVERWRITE each test - shows where we are -->

[testing complete]

## Tests

### 1. In-range Tournament-Start (FPK Klasse 1, Plan t04_5, 5 Spieler)
expected: Bei FPK Klasse 1 / Plan t04_5 / 5 Spielern startet das Turnier mit balls_goal=200 (innerhalb 187..250) OHNE Verifikations-Modal direkt auf das TableMonitor-View.
result: pass
verified: |
  Round 2 (2026-05-07T01:56Z) — Tournament 17401 ("NDM Cadre 35/2 Klasse 1")
  mit player_class="1", tournament_plan_id=5, handicap_tournier=nil,
  9 alle Seedings / 5 lokale Seedings. DTP-Treffer (disc=35, plan=5, players=5,
  class="1") → (points=200, innings=15) → balls_goal in 150..200, innings_goal in 11..15.
  Bei in-range balls_goal startet das Turnier ohne Modal — bestätigt nach
  Folge-Test mit balls_goal=700 (out-of-range), wo der Modal sauber feuerte.
round_1_history: |
  Round 1 (2026-05-07T00:30Z) — issue / blocker. Modal feuerte bei keinem
  getesteten Wert. Root Cause: seedings.count zählte globale Records.
  Behoben durch Quick-Task 260507-24p (commits fa5c9529 + 6495a293 + d380da6b).
  Sekundär-Hinweis: Test-Turnier muss tournament.player_class gesetzt haben
  (RQ-03 Short-Circuit ist by-design, aber Bestands-Turniere wie
  "NDM Cadre 35/2 Klasse 1" haben player_class=nil — separate Daten-Pflege nötig
  → TODO 2026-05-07-scrape-player-class-from-tournament-title).

### 2. Out-of-range Tournament-Start löst Modal aus (BK-Disziplin mit DTP)
expected: Bei FPK Klasse 1 / Plan t04_5 / 5 Spielern mit balls_goal=100 (unter 187) erscheint das Verifikations-Modal mit Range-Hinweis (187..250). Operator kann bestätigen oder abbrechen.
result: pass
verified: |
  Round 2 (2026-05-07T01:56Z) — Tournament 17401 mit balls_goal=700 (klar out-of-range
  für 150..200) hat Verifikations-Modal mit Range-Hinweis "Bälle-Ziel = 700 (üblich: 150-200)"
  ausgelöst. Operator-Path "bestätigen / abbrechen" beobachtet beim Tournament-Start.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

### 3. Non-DTP-Disziplin (BK-2kombi) überspringt Verifikation komplett
expected: Bei einem BK-2kombi-Turnier (keine DTP-Rows vorhanden) startet das Turnier auch mit extremen Werten (z. B. balls_goal=99999) OHNE Verifikations-Modal — D-10 short-circuit.
result: pass
verified: |
  Round 2 (2026-05-07T02:00Z) — D-10 short-circuit bestätigt: BK-Familie hat keine DTP-Rows
  in der Dev-DB, parameter_ranges liefert {} → kein Modal. Auch durch Phase-39 Unit-Test
  "parameter_ranges returns {} when discipline has no DTP rows (D-10)" abgedeckt.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

### 4. Handicap-Turnier überspringt Verifikation
expected: Bei einem Turnier mit handicap_tournier=true startet das Turnier auch mit out-of-range balls_goal OHNE Verifikations-Modal — D-11 short-circuit.
result: skipped
reason: |
  User skip 2026-05-07T02:01Z — kein Handicap-Turnier in der Dev-DB zur Hand.
  D-11 short-circuit (`return {} if tournament.handicap_tournier`) ist durch den
  Phase-39 Unit-Test "parameter_ranges returns {} when handicap_tournier is true"
  in test/models/discipline_test.rb abgedeckt.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

### 5. Turnier ohne tournament_plan überspringt Verifikation
expected: Bei einem Turnier ohne zugewiesenen tournament_plan startet das Turnier ohne Modal — D-16(f) defensive short-circuit.
result: skipped
reason: |
  User skip 2026-05-07T02:02Z — domain-operational nicht reproduzierbar:
  Ein TournamentMonitor braucht immer einen TournamentPlan, sodass Tournaments
  mit tournament_plan_id=nil in der Praxis nicht entstehen. Das Schema erlaubt
  den nil-Wert (`belongs_to :tournament_plan, optional: true` in tournament.rb:76),
  aber operativ kann der Zustand nicht herbeigeführt werden. Das D-16(f) Guard
  in discipline.rb:71 (`return {} if tournament.tournament_plan_id.nil?`) ist
  defensiv für einen Schema-erlaubten aber operativ unerreichbaren Zustand und
  durch den Phase-39 Unit-Test "parameter_ranges returns {} when tournament_plan_id is nil"
  abgedeckt.
domain_note: |
  Sollte in einer zukünftigen Refaktorierung das `optional: true` aus dem belongs_to
  entfernt werden (z. B. via NOT NULL DB-Constraint), kann das D-16(f) Guard
  entfallen — vorher allerdings Migration für eventuelle Bestands-Daten und
  Validierung im Tournament-Model nötig. Bis dahin: das Guard bleibt als
  Defense-in-Depth gegen Schema-erlaubte Edge-Cases.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

### 6. sets_to_play / sets_to_win / timeout / warm-up lösen kein Modal mehr aus
expected: Auch bei „extremen" Werten in sets_to_play, sets_to_win, timeout, time_out_warm_up_first_min, time_out_warm_up_follow_up_min wird KEIN Verifikations-Modal mehr ausgelöst — UI_07_FIELDS ist auf [balls_goal, innings_goal] reduziert.
result: skipped
reason: |
  User skip 2026-05-07T02:03Z — abgedeckt durch Phase-39 Plan 02 Code-Änderungen:
    1. UI_07_FIELDS in tournaments_controller.rb:30 von 7 auf 2 Einträge reduziert
       (`%i[balls_goal innings_goal]`).
    2. UI_07_SENTINEL_VALUES Constant + Sentinel-Guard in
       verify_tournament_start_parameters komplett entfernt.
    3. test/integration/tournament_verification_sentinels_test.rb (107 LOC, 7 Tests)
       gelöscht — keine Tests mehr für entfernten Code-Pfad.
  Statisch verifiziert: `grep "sets_to_play\|sets_to_win\|timeout\|time_out_warm_up"
  app/controllers/tournaments_controller.rb` zeigt nur noch I18n-Labels und Form-Setup —
  kein Verifikations-Lookup mehr.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

### 7. innings_goal out-of-range löst Modal aus
expected: Bei FPK Klasse 1 / Plan t04_5 / 5 Spielern mit innings_goal außerhalb des per DTP abgeleiteten Bereichs erscheint das Verifikations-Modal analog zu balls_goal.
result: pass
verified: |
  Round 2 (2026-05-07T02:04Z) — Tournament 17401 (FPK Klasse 1 / Plan 5 /
  5 lokale Seedings) mit innings_goal außerhalb 11..15 löst Verifikations-Modal
  aus. Code-Pfad symmetrisch zu balls_goal — UI_07_FIELDS = [balls_goal, innings_goal]
  iteriert beide Felder gleich.
round_1_history: blocked by Gap-01 — fix 260507-24p hat unblocked.

## Summary

total: 7
passed: 4
issues: 0
pending: 0
skipped: 3
blocked: 0
round_1: 1 issue / 6 blocked → all unblocked by quick-260507-24p

## Gaps

- truth: "Verifikations-Modal feuert bei out-of-range balls_goal/innings_goal für DTP-gedeckte Turniere"
  status: resolved
  resolved_by: "quick-260507-24p (commits fa5c9529 + 6495a293 + d380da6b) — Discipline#effective_player_count helper mit Smart-Fallback-Pattern (lokale Seedings wenn vorhanden, sonst globale)"
  resolved_at: 2026-05-07T00:42:00Z
  reason: "User reported: Modal feuert nie — t.player_class=nil bei Bestands-Turnier 'NDM Cadre 35/2 Klasse 1', UND t.seedings.count zählt globale + lokale Seedings. Nur Seedings mit id >= Seeding::MIN_ID dürfen berücksichtigt werden."
  severity: blocker
  test: 1
  root_cause: |
    Phase 39 Discipline#lookup_dtp_with_class_walk (app/models/discipline.rb:90-108) verwendet
    tournament.seedings.count ohne Local/Global-Filter. Im Carambus-Codebase wird der Local/Global-
    Split für Seedings überall sonst korrekt umgesetzt:
      - app/models/tournament.rb:424 → seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
      - app/models/table_monitor.rb:879 → player.seedings.where("seedings.id >= #{Seeding::MIN_ID}")
      - app/models/tournament_cc.rb:286 → smart fallback (lokale wenn vorhanden, sonst globale)
    Phase-39-Tests deckten das nicht auf, weil alle Test-Fixture-Seedings (test/fixtures/seedings.yml,
    IDs 50_000_300..50_000_405) bereits ≥ MIN_ID sind — der Global/Local-Split wird im Test-Set
    nicht ausgeübt.

    Sekundärer Befund (RQ-03 by-design, aber Praxis-Auswirkung): Bestands-Turniere wie
    'NDM Cadre 35/2 Klasse 1' haben player_class=nil (Klasse steht nur im Titel-String).
    Phase 39 setzt voraus, dass tournament.player_class als strukturiertes Attribut gepflegt ist —
    Daten-Migrations- bzw. Form-Validation-Lücke, die separat zu adressieren ist.
  artifacts:
    - path: "app/models/discipline.rb"
      issue: "Zeile 93 — .where(players: tournament.seedings.count) zählt globale + lokale Seedings"
    - path: "app/models/discipline.rb"
      issue: "Zeile 91-93 — base_scope berücksichtigt MIN_ID-Konvention nicht"
  missing:
    - "Filter auf seedings.where('seedings.id >= ?', Seeding::MIN_ID).count im base_scope-Aufbau (oder smart fallback wie tournament_cc.rb:286)"
    - "Test-Fixture mit gemischten globalen + lokalen Seedings (z. B. lokales Turnier mit 5 lokalen Seedings + zusätzlichen globalen Aliasen) zur Absicherung der Filter-Logik"
    - "Optional: separate Phase/Plan zur Pflege von tournament.player_class für Bestands-Turniere (z. B. Daten-Migration aus Titel-Parsing oder UI-Validation, die player_class als Pflichtfeld setzt, sobald tournament_plan zugewiesen ist)"
  debug_session: ""
