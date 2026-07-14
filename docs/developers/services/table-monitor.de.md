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

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
