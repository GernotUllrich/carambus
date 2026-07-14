# TournamentMonitor:: — Architektur

Der `TournamentMonitor::`-Namespace stellt Services für die Verwaltung eines laufenden Turniers bereit — Verteilung von Spielern auf Gruppen, Auflösung von Platzierungsregeln, Verarbeitung von Spielergebnissen und Belegung von Tischen.

Der Namespace besteht aus **4 Services** in `app/services/tournament_monitor/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | Reines PORO — verteilt Spieler nach Zick-Zack- oder Round-Robin-Muster auf Gruppen gemäß NBV-Regeln |
| `TournamentMonitor::RankingResolver` | `app/services/tournament_monitor/ranking_resolver.rb` | Reines PORO — löst Spieler-IDs aus Ranking-Regelstrings auf (Gruppenränge, KO-Klammer-Referenzen) |
| `TournamentMonitor::ResultProcessor` | `app/services/tournament_monitor/result_processor.rb` | Verarbeitet Spielergebnisse mit pessimistischem DB-Lock — koordiniert ClubCloud-Upload und `GameParticipation`-Aktualisierungen |
| `TournamentMonitor::TablePopulator` | `app/services/tournament_monitor/table_populator.rb` | Weist Spiele Turniertischen zu — initialisiert `TableMonitor`-Datensätze und führt den Platziermungsalgorithmus aus |

## Öffentliche Schnittstelle

### PlayerGroupDistributor

**Einstiegspunkte (Klassenmethoden — kein Objekt notwendig):**

```ruby
TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups)
  # → Hash { "group1" => [player_ids], "group2" => [player_ids], … }
  # Verteilt players (Array von Integer) auf ngroups Gruppen via Zick-Zack

TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, ngroups, sizes)
  # → Hash { "group1" => [player_ids], "group2" => [player_ids], … }
  # Verteilt players auf ngroups Gruppen mit expliziten Gruppengrößen
```

**Eingabe:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `players` | `Array<Integer>` | Liste der Spieler-IDs (nach Ranking geordnet) |
| `ngroups` | `Integer` | Anzahl der Gruppen |
| `sizes` | `Array<Integer>` | Explizite Gruppengrößen (nur für `distribute_with_sizes`) |

**Ausgabe:** `Hash { String => Array<Integer> }` — Gruppenschlüssel (`"group1"`, `"group2"`, …) → Liste der Spieler-IDs.

### RankingResolver

**Einstiegspunkte:**

```ruby
resolver = TournamentMonitor::RankingResolver.new(tournament_monitor)

resolver.player_id_from_ranking(rule_str, opts = {})
  # → Integer (player_id) oder nil
```

**`rule_str`-DSL — Beispiele:**

| Ausdruck | Bedeutung |
|----------|-----------|
| `"g1.2"` | Spieler auf Rang 2 in Gruppe 1 |
| `"g1.rk4"` | Spieler auf Rang 4 in Gruppe 1 (explizites `rk`-Präfix) |
| `"(g1.rk4 + g2.rk4).rk2"` | Komposit-Regel: Rang 2 unter allen Rang-4-Spielern der Gruppen 1 und 2 |
| `"fin.rk1"` | Rang 1 des Finalspiels — also der Sieger des Finales (KO-Klammer-Referenz) |
| `"sl.rk1"` | Rang 1 im Kleinen Finale (small final) |

**Eingabe (Konstruktor):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord-Instanz des Turnier-Monitors |

### ResultProcessor

**Einstiegspunkte:**

```ruby
processor = TournamentMonitor::ResultProcessor.new(tournament_monitor)

processor.report_result(table_monitor)
  # → Seiteneffekte: schreibt Spielergebnis, löst finish_match! aus, lädt zu CC hoch

processor.advance_round_after_match_close(table_monitor)
  # → ÖFFENTLICH — aufgeschobene Runden-Fortschritts-Kaskade (Phase 38.8):
  #   accumulate_results → all_table_monitors_finished?-Gate → finalize_round /
  #   incr_current_round! / populate_tables / update_ranking / end_of_tournament!.
  #   Aufgerufen von TableMonitor#advance_tournament_round_if_present (dem close_match!-
  #   After-Callback), NACHDEM der Operator :final_match_score bestätigt hat. NICHT
  #   idempotent — läuft genau einmal pro "Weiter"-Klick (Re-Entry über das Thread-lokale
  #   Sentinel Thread.current[:_advancing_round_for_tm] abgesichert).

processor.accumulate_results
  # → ÖFFENTLICH — wird auch von TablePopulator verwendet

processor.update_ranking
  # → aktualisiert Rankings nach Ergebnisverarbeitung

processor.update_game_participations(tabmon)
  # → aktualisiert GameParticipation-Datensätze
  # → delegiert an update_game_participations_for_game(tabmon.game, tabmon.data)
```

**DB-Lock-Bereich:**

```ruby
game.with_lock do
  # Innerhalb des Locks: table_monitor + game neu laden, write_game_result_data,
  # beide erneut neu laden (um die vom AASM-Callback gelesene
  # table_monitor.game-Assoziation zu aktualisieren), dann ein abgesichertes
  # finish_match! (falls may_finish_match?).
  # Pessimistischer Lock verhindert Race Conditions bei gleichzeitigen Ergebnissen.
end

# Der ClubCloud-Upload (finalize_game_result) läuft AUSSERHALB des Locks,
# nach dessen Freigabe, um den Lock nicht während des Netzwerkaufrufs zu halten.
```

**Eingabe (Konstruktor):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord-Instanz des Turnier-Monitors |

### TablePopulator

**Einstiegspunkte:**

```ruby
populator = TournamentMonitor::TablePopulator.new(tournament_monitor)

populator.do_reset_tournament_monitor
  # → AASM after_enter Callback-Einstieg für vollständigen Reset

populator.populate_tables
  # → weist Spiele Turniertischen zu

populator.initialize_table_monitors
  # → initialisiert TableMonitor-Datensätze für alle Tische
```

**Eingabe (Konstruktor):**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `tournament_monitor` | `TournamentMonitor` | ActiveRecord-Instanz des Turnier-Monitors |

## Architektur-Entscheidungen

### a. PORO vs. PORO mit DB-Seiteneffekten

Die Services sind nach Zweck eingeteilt — nicht nach `ApplicationService`-Vererbung:

- **Reine POROs** (keine DB-Operationen): `PlayerGroupDistributor`, `RankingResolver`
- **POROs mit DB-Seiteneffekten**: `ResultProcessor`, `TablePopulator` — haben mehrere öffentliche Einstiegspunkte und erben daher nicht von `ApplicationService` (der nur einen `.call`-Einstieg unterstützt)

### b. AASM-Events auf dem Modell

AASM-Events (`finish_match!`, `after_enter`-Callbacks etc.) werden auf `@tournament_monitor` ausgelöst, nicht vom Service selbst. Dies stellt sicher, dass `after_enter`-Callbacks korrekt über die Modellreferenz ausgeführt werden.

### c. DB-Lock im Service, nicht im Modell

Der pessimistische Lock (`game.with_lock`) ist in `ResultProcessor` platziert, nicht im `TournamentMonitor`-Modell. Die Lock-Grenze gehört zur Ergebnisverarbeitungslogik — sie ist kein Modell-Infrastrukturanliegen.

### d. Querverweis: RankingResolver → PlayerGroupDistributor

`RankingResolver#group_rank` ruft `PlayerGroupDistributor.distribute_to_group` direkt auf. Diese Abhängigkeit ist bewusst — der Resolver muss die Gruppenverteilung kennen, um Ränge innerhalb von Gruppen aufzulösen.

### e. Klassen-Attribut `allow_change_tables`

`TournamentMonitor.allow_change_tables` wird als Klassen-Attribut (`cattr_accessor`) gesetzt und gesteuert. Zugriff erfolgt als `TournamentMonitor.allow_change_tables` (Klassenebene), nicht als Instanzmethode.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
