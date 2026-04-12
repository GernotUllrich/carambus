# PartyMonitor:: — Architektur

Der `PartyMonitor::`-Namespace enthält Services zur Verwaltung eines laufenden Ligaspieltags. Er ist das direkte Gegenstück zu `TournamentMonitor::`, jedoch auf den Party-Kontext (Ligaspieltag) beschränkt.

Der Namespace besteht aus **2 Services** in `app/services/party_monitor/`.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `PartyMonitor::ResultProcessor` | `app/services/party_monitor/result_processor.rb` | Verarbeitet Spielergebnisse im PartyMonitor-Kontext mit pessimistischem DB-Lock |
| `PartyMonitor::TablePopulator` | `app/services/party_monitor/table_populator.rb` | Setzt PartyMonitor zurück und weist TableMonitor-Records den Party-Tischen zu |

## Öffentliche Schnittstelle

### ResultProcessor

**Einstiegspunkte:**

```ruby
processor = PartyMonitor::ResultProcessor.new(party_monitor)

processor.report_result(table_monitor)
  # → Seiteneffekte: schreibt Spielergebnis, löst finish_match! aus, schließt Runde ab

processor.accumulate_results
  # → nil; aggregiert GameParticipation-Ergebnisse in @party_monitor.data["rankings"]

processor.finalize_round
  # → nil; schließt alle TableMonitor-Records und akkumuliert Ergebnisse

processor.finalize_game_result(table_monitor)
  # → nil; schreibt GameParticipation-Updates und führt manuelle Zuweisung durch

processor.update_game_participations(table_monitor)
  # → nil; aktualisiert GameParticipation-Records mit Ergebnisdaten
```

**DB-Lock-Verhalten in `report_result`:**

```
Thread A erwirbt game.with_lock
→ write_game_result_data(table_monitor)   # Datenschreibung (PRIVAT)
→ table_monitor.finish_match!             # State-Transition (falls may_finish_match?)
Thread A gibt Lock frei
Thread B erwirbt Lock → prüft Idempotenz → überspringt (bereits finalisiert)
```

Der Lock umfasst `write_game_result_data` und `finish_match!` gemeinsam, um Race Conditions bei gleichzeitigen Ergebnismeldungen zu verhindern.

**Wichtig — `TournamentMonitor.transaction` bewusst beibehalten:**

```ruby
# ResultProcessor#report_result:
TournamentMonitor.transaction do
  ...
end
```

Der `TournamentMonitor.transaction`-Scope wurde aus der ursprünglichen `PartyMonitor`-Implementierung übernommen und ist absichtlich nicht auf `PartyMonitor.transaction` geändert worden (Pitfall 5 in der Quellcodedokumentation). Diese Scope-Entscheidung darf nicht geändert werden.

### TablePopulator

**Einstiegspunkte:**

```ruby
populator = PartyMonitor::TablePopulator.new(party_monitor)

populator.reset_party_monitor
  # → nil; setzt sets_to_play, sets_to_win, team_size zurück; löscht lokale Games/Seedings

populator.initialize_table_monitors
  # → nil; weist TableMonitors den Party-Tischen zu

populator.do_placement(game, r_no, t_no)
  # → platziert ein einzelnes Spiel auf einem Tisch (Runden-Nr. r_no, Tisch-Nr. t_no)
```

**Eingabe für `do_placement`:**

| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| `game` | `Game` | Das zu platzierende Spiel |
| `r_no` | `Integer` | Runden-Nummer |
| `t_no` | `Integer` | Tisch-Nummer |

## Architektur-Entscheidungen

### a. POROs mit DB-Seiteneffekten

Beide Services sind POROs (keine `ApplicationService`-Unterklasse), da sie mehrere öffentliche Eintrittspunkte haben und kein einzelnes `call`-Interface sinnvoll wäre. POROs ermöglichen hier flexible Aufrufmuster bei gleichzeitiger klarer Verantwortungstrennung.

### b. AASM-Events auf dem Modell, nicht im Service

Alle AASM-Events (z. B. `finish_match!`, `close_match!`) werden auf `@party_monitor` bzw. dem jeweiligen `table_monitor`-Record ausgelöst, nicht vom Service selbst. Dies stellt sicher, dass `after_enter`-Callbacks korrekt über die Modellreferenz ausgeführt werden.

### c. cattr_accessor-Muster

Der `cattr_accessor`-Wert `allow_change_tables` wird als `PartyMonitor.allow_change_tables` (Klassen-Level) abgerufen — nicht als `TournamentMonitor.allow_change_tables`. Dies spiegelt den eigenständigen Namespace des PartyMonitors wider.

### d. Paralleles Muster zu TournamentMonitor::

`PartyMonitor::ResultProcessor` und `PartyMonitor::TablePopulator` sind direkte Analoga zu `TournamentMonitor::ResultProcessor` und `TournamentMonitor::TablePopulator`. Die Extraktionsmuster wurden 1:1 übernommen, einschließlich des DB-Lock-Scopes und der AASM-Event-Delegation.

### e. Pitfall — Scope-Erhalt bei `TournamentMonitor.transaction`

Der `TournamentMonitor.transaction`-Scope in `ResultProcessor#report_result` ist kein Fehler. Er wurde aus dem originalen `PartyMonitor`-Modell extrahiert und bewusst beibehalten. Eine Änderung zu `PartyMonitor.transaction` würde das Transaktionsverhalten unvorhersehbar verändern.

## Querverweise

- Übergeordneter Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
