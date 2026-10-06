# TableMonitor:: — Architektur

Der `TableMonitor::`-Namespace verwaltet die Echtzeit-Spielsteuerung an einem einzelnen Billard-Tisch. Er übernimmt die Spielerstellung, Spielerzuweisung, Punkteerfassung sowie die Übergänge zwischen Sätzen und Spielende.

Der Namespace besteht aus **2 Services** in `app/services/table_monitor/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `TableMonitor::GameSetup` | `app/services/table_monitor/game_setup.rb` | Kapselt die `start_game`-Logik — erstellt `Game`/`GameParticipation`-Datensätze, baut den Ergebnis-Hash auf und stellt `TableMonitorJob` in die Warteschlange |
| `TableMonitor::ResultRecorder` | `app/services/table_monitor/result_recorder.rb` | Ergebnispersistenz — speichert Satzdaten, navigiert zwischen Sätzen und koordiniert AASM-Zustandsübergänge |

## Öffentliche Schnittstelle

### GameSetup

**Einstiegspunkte:**

```ruby
TableMonitor::GameSetup.call(table_monitor: tm, options: params)
  # → true (wirft StandardError bei Fehler)

TableMonitor::GameSetup.assign(table_monitor: tm, game_participation: gp)
  # → führt assign_game-Logik aus, speichert TableMonitor-Zustand

TableMonitor::GameSetup.initialize_game(table_monitor: tm)
  # → schreibt initialen Datenhash in tm.data (Bälle, Aufnahmen, Spielerzustand)
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `table_monitor` | `TableMonitor` | ActiveRecord-Instanz des Tisch-Monitors |
| `options` | `Hash` | Spielparameter (Spieltyp, Spieler, Optionen) |
| `game_participation` | `GameParticipation` | Zuzuweisende Spielteilnahme |

### ResultRecorder

**Einstiegspunkte:**

```ruby
TableMonitor::ResultRecorder.call(table_monitor: tm)
  # → evaluate_result (Haupt-Einstieg — löst Satz-/Spielende-Logik aus)

TableMonitor::ResultRecorder.save_result(table_monitor: tm)
  # → Hash (game_set_result mit deutschen Feldnamen — siehe Datenvertrag unten)

TableMonitor::ResultRecorder.save_current_set(table_monitor: tm)
  # → nil (schiebt Ergebnis in data["sets"])

TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: tm)
  # → Integer

TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: tm)
  # → nil (initialisiert nächsten Satz, setzt Spielerzustand zurück, behandelt Snooker-Zustand)
```

**Datenvertrag — Rückgabe-Hash von `save_result`:**

```ruby
{
  "Gruppe"       => game.group_no,   # Integer
  "Partie"       => game.seqno,      # Integer
  "Spieler1"     => player_a.ba_id,  # Integer (BA-Spieler-ID)
  "Spieler2"     => player_b.ba_id,  # Integer
  "Innings1"     => Array,           # Aufnahmen-Array Spieler A
  "Innings2"     => Array,           # Aufnahmen-Array Spieler B
  "Ergebnis1"    => Integer,         # Endpunktzahl Spieler A
  "Ergebnis2"    => Integer,         # Endpunktzahl Spieler B
  "Aufnahmen1"   => Integer,         # Anzahl Aufnahmen Spieler A
  "Aufnahmen2"   => Integer,         # Anzahl Aufnahmen Spieler B
  "3BErgebnis1"  => Integer,         # Dreiband-Teilergebnis Spieler A (result_3b)
  "3BErgebnis2"  => Integer,         # Dreiband-Teilergebnis Spieler B
  "3BAufnahmen1" => Integer,         # Dreiband-Aufnahmen Spieler A (innings_3b)
  "3BAufnahmen2" => Integer,         # Dreiband-Aufnahmen Spieler B
  "Höchstserie1" => Integer,         # Höchstserie Spieler A
  "Höchstserie2" => Integer,         # Höchstserie Spieler B
  "Tischnummer"  => Integer,         # Tischnummer (game.table_no)
  "TiebreakWinner" => Integer        # Satz-Tiebreak-Sieger: 1 = playera, 2 = playerb; nil wenn keiner
}
```

Dieser Hash wird direkt in `data["sets"]` gespeichert und für den ClubCloud-Upload verwendet.

## Architektur-Entscheidungen

### a. ApplicationService für beide Services

`GameSetup` und `ResultRecorder` erben von `ApplicationService`, da beide Datenbankänderungen vornehmen (`Game`, `GameParticipation`, `TableMonitor`-Datensätze). Services ohne Seiteneffekte würden als POROs implementiert.

### b. AASM-Events auf dem Modell, nicht im Service

Die AASM-Events (`end_of_set!`, `finish_match!`, `acknowledge_result!`) werden auf `@tm` (der `TableMonitor`-Instanz) ausgelöst, nicht vom Service selbst. Dies stellt sicher, dass `after_enter`-Callbacks korrekt über die Modellreferenz ausgeführt werden.

### c. Keine direkten Broadcast-Aufrufe

Keiner der Services ruft CableReady oder ActionCable direkt auf. Broadcasts erfolgen über `after_update_commit`-Hooks am `TableMonitor`-Modell — die Services bleiben damit frei von Präsentationslogik.

### d. set_over ⟹ panel_state "protocol_final" (before_save-Invariante)

Solange der AASM-Zustand `set_over` ist ("Partie beendet"), erzwingt die before_save-Invariante `enforce_protocol_final_panel_at_set_over`, dass `panel_state = "protocol_final"` ist. Dadurch zeigt das Scoreboard am Spielende **immer direkt** den ProtokollEditor (final-mode, „Fertig" = `confirm_result` → `evaluate_result` schaltet den Zustand weiter) — statt des seltenen Umwegs über das „…OK?"/alte `innings_list`-Panel. Hintergrund: diverse Pfade überschreiben `panel_state` nach dem `set_over`-Eintritt (Karambol-Eingabe-Modus `"inputs"`, `key_a`/`key_b` `"pointer_mode"`, App-/Bridge-Spiele); die Invariante ist der eine pfad-unabhängige Chokepoint. `current_element` bleibt unangetastet (Tiebreak setzt `"tiebreak_winner_choice"`). Der `"…OK?"`-Status selbst ist die TL-Bestätigung bei `!player_controlled?` (siehe `locked_scoreboard`).

## Biathlon {#biathlon}

Biathlon (DBU-Regeln Biathlon §3) ist kein eigener Spieltyp, sondern Karambol mit zwei Phasen —
umgesetzt als kleine Erweiterung der bestehenden Pfade (Skill *extend-before-build*), nicht als
eigene Zustandsmaschine. Bedienung: [Biathlon am Scoreboard](../../players/biathlon.md).

**Daten in `tm.data`:**

| Schlüssel | Inhalt |
|---|---|
| `biathlon_phase` | `"3b"` (Dreiband) oder `"5k"` (5-Kegel) |
| `biathlon` | `{"balls_goal_3b", "innings_goal_3b", "factor"}` — Teildistanz, Aufnahmebegrenzung Dreiband, Verrechnungsfaktor (6). Fehlt ein Wert, gilt `TableMonitor::ScoreEngine::BIATHLON_DEFAULTS` (15/30/6) |
| `playerX.balls_goal` | **Gesamtziel** der Partie |
| `playerX.result_3b`, `innings_3b` | Dreiband-Stand beim Wechsel (Anzeige, Protokoll `3BErgebnis`/`3BAufnahmen`) |

Erkannt wird Biathlon an `TableMonitor#discipline == "Biathlon"` (= `playera.discipline`).

**ScoreEngine** (`app/models/table_monitor/score_engine.rb`):

- Dreiband-Phase: eigener Zweig in `add_n_balls`/`set_n_balls` (`add_biathlon_3b`,
  `set_biathlon_3b`) — gezählt wird roh gegen die Teildistanz, gekappt; bei Erreichen
  `:goal_reached`, damit `TableMonitor` die Aufnahme beendet.
- Wechsel an **einer** Stelle, am Ende jeder Aufnahme (`terminate_inning_data` →
  `switch_biathlon_to_5k!`), wenn ein Spieler die Teildistanz hat oder **beide** die
  Aufnahmebegrenzung — unabhängig vom Anstoß. Alle `innings_list`/`innings_redo_list` beider
  Spieler ×Faktor, `recompute_result`.
- Kegel-Phase: normaler Karambol-Pfad; `overflow_capped?` kappt Überschuss am Gesamtziel.
- Undo: `undo_hash` → `revert_biathlon_to_3b!`, wenn die Wechsel-Aufnahme zurückgenommen wird
  (beide Spieler stehen auf `innings_3b`).
- `innings_limit_open?` ist für Biathlon immer offen; `TableMonitor#follow_up?` und `end_of_set?`
  behandeln Biathlon ohne Nachstoß und ohne Partie-Aufnahmebegrenzung.

**Warum die Wächter statt eines sauberen Datenflusses:** Turnierpartien laufen über
`assign_game` → `initialize_game`, nicht über `GameSetup#perform_start_game`, und
`TournamentsController#start` schreibt `innings_goal` des Turniers **nach** der Platzierung auf alle
Tische. Statt jeden Weg zu flicken, ist Biathlon gegen `innings_goal`/`allow_follow_up` unempfindlich.

**Woher die Variante kommt:**

| Weg | Quelle | Gesetzt in |
|---|---|---|
| Schnellstart | Preset `{balls, balls_3b, innings_3b, discipline: "Biathlon"}` (`carambus.yml`, Match-Billard) → `biathlon[balls_goal_3b, innings_goal_3b]` | `GameSetup#biathlon_settings` |
| Detailseite | `discipline_choice` 13, `biathlon_3b(_2)_choice`, `innings_choice` (= Dreiband-Aufnahmen) | `TableMonitorsController#start_game` → `biathlon_settings` |
| Turnier | Startseite → `tournament_monitor.data["biathlon"]` (lokaler Datensatz; `tournament.data` würde ein Sync überschreiben) | `TournamentsController#start` (Tische der 1. Runde), `GameSetup.initialize_game` (jede weitere Partie) |
| Turnier-App | `POST start_game` mit `biathlon: {…}` je Spiel | `ExternalTournament::StartGameProcessor` → `biathlon_settings` |
| Rückspiel | `data["biathlon"]` | `TableMonitor#revert_players` |

Normalisiert wird an einer Stelle: `TableMonitor::GameSetup.biathlon_params` (nur positive Werte,
Rest aus den Defaults). `initialize_game` räumt `biathlon` einer Vorpartie am Tisch ab.

**Tests:** `test/models/table_monitor/score_engine_biathlon_test.rb`,
`test/models/table_monitor/biathlon_lifecycle_test.rb`, Biathlon-Fälle in
`test/services/table_monitor/game_setup_test.rb`, `test/controllers/table_monitors_controller_test.rb`,
`test/controllers/api/external_tournaments_lifecycle_test.rb`,
`test/integration/biathlon_tournament_start_test.rb`.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
