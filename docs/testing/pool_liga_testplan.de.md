# Pool Liga-Spielverwaltung Testplan

## Übersicht

Dieser Testplan beschreibt die Testszenarien für die Pool Liga-Spielverwaltung im Scenario `carambus_pbv` (Location 2368 - Pool/Snooker-Club mit 16 Pool- und 6 Snooker-Tischen).

## Datenmodell-Übersicht

### Relevante Models

| Model | Beschreibung |
|-------|-------------|
| `Party` | Ein Ligaspieltag (Team A vs Team B) |
| `PartyMonitor` | Steuerung/Monitoring eines Ligaspieltags |
| `PartyGame` | Einzelpartie innerhalb eines Spieltags (aus CC-Import) |
| `Game` | Aktives Spiel (wird vom TableMonitor verwendet) |
| `League` | Liga mit Disziplin und Spielplan |
| `LeagueTeam` | Mannschaft in einer Liga |
| `GamePlan` | Spielplan-Template für Liga-Begegnungen |

### State Machine (PartyMonitor)

```
seeding_mode (initial)
    ↓ prepare_next_round
table_definition_mode
    ↓ enter_next_round_seeding
next_round_seeding_mode
    ↓ finish_round_seeding_mode
ready_for_next_round
    ↓ start_round
playing_round
    ↓ finish_round
round_result_checking_mode
    ↓ finish_party
party_result_checking_mode
    ↓ close_party
closed
```

---

## Voraussetzungen

### Scenario Setup

1. **Scenario `carambus_pbv` aktiv** mit Location 2368
2. **Pool-Tische konfiguriert** (TableKind = Pool)
3. **Pool-Liga vorhanden** mit:
   - Mindestens 2 LeagueTeams
   - Spielern in beiden Teams
   - GamePlan mit Pool-Disziplinen (14.1 endlos, 8-Ball, 9-Ball, 10-Ball)
   - Mindestens eine Party (Spieltag)

### Datenprüfung vor Tests

```ruby
# Rails Console
location = Location.find(2368)
location.tables.joins(:table_kind).where(table_kinds: { key: 'pool' }).count
# Erwartung: >= 1

# Pool-Ligen der Location
League.joins(:parties).where(parties: { location_id: 2368 }).distinct
```

---

## Testfälle

### 1. Party Monitor starten

**Ziel:** Verifizieren, dass ein PartyMonitor für einen Ligaspieltag erstellt werden kann.

**Schritte:**
1. Navigiere zu `/parties`
2. Wähle eine Party (Spieltag) der Location 2368
3. Klicke auf "Party Monitor starten"
4. Verifiziere, dass der PartyMonitor erstellt wurde

**Erwartetes Ergebnis:**
- PartyMonitor wird erstellt mit `state: seeding_mode`
- Redirect zu `/party_monitors/:id`
- Spieler-Zuordnung wird angezeigt

**Prüfpunkte:**
- [ ] PartyMonitor.state == "seeding_mode"
- [ ] Party.party_monitor vorhanden
- [ ] Spieler von beiden Teams werden angezeigt

---

### 2. Spieler-Zuordnung (Seeding)

**Ziel:** Spieler den Partien zuordnen.

**Schritte:**
1. Im PartyMonitor-View
2. Ziehe Spieler von Team A auf Partie 1
3. Ziehe Spieler von Team B auf Partie 1
4. Wiederhole für alle Partien

**Erwartetes Ergebnis:**
- Seedings werden erstellt
- Spieler erscheinen in der Partie-Übersicht

**Prüfpunkte:**
- [ ] Seeding-Records werden erstellt
- [ ] Spieler-Namen erscheinen in der Partie-Zeile

---

### 3. Tisch-Zuordnung

**Ziel:** Pool-Tische den Partien zuordnen.

**Schritte:**
1. Im PartyMonitor-View
2. Wähle Tische für die Partien aus
3. Bestätige die Zuordnung

**Erwartetes Ergebnis:**
- TableMonitors werden mit PartyMonitor verknüpft
- Tische erscheinen in der Übersicht

**Prüfpunkte:**
- [ ] table_monitor.tournament_monitor == party_monitor
- [ ] Tisch-Namen werden angezeigt

---

### 4. Runde starten

**Ziel:** Eine Spielrunde starten.

**Schritte:**
1. Alle Spieler und Tische zugeordnet
2. Klicke "Runde starten"
3. Verifiziere State-Wechsel

**Erwartetes Ergebnis:**
- PartyMonitor wechselt zu `playing_round`
- TableMonitors werden initialisiert
- Games werden erstellt

**Prüfpunkte:**
- [ ] PartyMonitor.state == "playing_round"
- [ ] Game-Records für jede Partie erstellt
- [ ] TableMonitor.game_id gesetzt

---

### 5. 14.1 endlos Partie spielen

**Ziel:** Eine komplette 14.1 endlos Partie über das Scoreboard spielen.

**Schritte:**
1. Öffne Scoreboard für einen Tisch mit 14.1 endlos Partie
2. Starte Einspielzeit (optional)
3. Führe Ausstoßen durch
4. Spiele Partie:
   - Klicke auf Bälle um Punkte einzugeben
   - Teste Neuaufbau bei Ball 0 und Ball 1
   - Teste Foul-Eingabe (F1, F2)
   - Teste Spielerwechsel
5. Spiele bis Zielpunktzahl erreicht

**Erwartetes Ergebnis:**
- Punkte werden korrekt gezählt
- Neuaufbau funktioniert bei 0/1 Bällen
- Balls_counter_stack wird aktualisiert
- Spielende wird erkannt

**Prüfpunkte:**
- [ ] Ball-Anzeige aktualisiert sich korrekt
- [ ] Aufnahmen-Stack zeigt Zwischenstände
- [ ] GD und HS werden berechnet
- [ ] Spielende bei Zielpunktzahl

---

### 6. 8-Ball/9-Ball/10-Ball Partie spielen

**Ziel:** Eine Satz-basierte Partie spielen.

**Schritte:**
1. Öffne Scoreboard für einen Tisch mit 8-Ball Partie
2. Starte Einspielzeit (optional)
3. Führe Ausstoßen durch
4. Spiele Partie:
   - Klicke "Satz A" oder "Satz B" für Satzgewinne
5. Spiele bis Race-to-X erreicht

**Erwartetes Ergebnis:**
- Sätze werden gezählt
- Match endet bei erforderlicher Satzanzahl

**Prüfpunkte:**
- [ ] Satzzählung korrekt
- [ ] Match-Ende bei Race-to-X

---

### 7. Spielergebnis bestätigen

**Ziel:** Ein abgeschlossenes Spiel bestätigen.

**Schritte:**
1. Spiel beenden (Zielpunktzahl/Sätze erreicht)
2. Im PartyMonitor-View: Klicke auf Bestätigungs-Icon
3. Verifiziere Ergebnis-Übernahme

**Erwartetes Ergebnis:**
- TableMonitor wechselt zu `closed`
- Game.data enthält Ergebnisse
- GameParticipations werden aktualisiert

**Prüfpunkte:**
- [ ] TableMonitor.state == "closed"
- [ ] Game.data["ba_results"] vorhanden
- [ ] GameParticipation.result, .innings, .gd, .hs gesetzt

---

### 8. Runde abschließen

**Ziel:** Eine komplette Runde abschließen.

**Schritte:**
1. Alle Partien der Runde abgeschlossen
2. Verifiziere automatischen State-Wechsel

**Erwartetes Ergebnis:**
- PartyMonitor wechselt zu `round_result_checking_mode`
- Ergebnisse werden akkumuliert

**Prüfpunkte:**
- [ ] all_table_monitors_finished? == true
- [ ] PartyMonitor.state == "round_result_checking_mode"
- [ ] Rankings werden berechnet

---

### 9. Spieltag abschließen

**Ziel:** Einen kompletten Spieltag abschließen.

**Schritte:**
1. Alle Runden abgeschlossen
2. Klicke "Spieltag abschließen"
3. Verifiziere Endergebnis

**Erwartetes Ergebnis:**
- PartyMonitor wechselt zu `closed`
- Endergebnisse werden gespeichert

**Prüfpunkte:**
- [ ] PartyMonitor.state == "closed"
- [ ] Party.data enthält Endergebnisse

---

### 10. Undo/Redo während des Spiels

**Ziel:** Undo/Redo-Funktionalität testen.

**Schritte:**
1. Während einer laufenden Partie
2. Gib einige Punkte ein
3. Klicke Undo mehrfach
4. Klicke Redo

**Erwartetes Ergebnis:**
- Punkte werden rückgängig gemacht
- Redo stellt Punkte wieder her

**Prüfpunkte:**
- [ ] Undo funktioniert
- [ ] Redo funktioniert
- [ ] Ball-Anzeige aktualisiert sich

---

### 11. Spielabbruch

**Ziel:** Ein Spiel vorzeitig abbrechen.

**Schritte:**
1. Während einer laufenden Partie
2. Klicke "Beenden" im Menü
3. Bestätige Abbruch

**Erwartetes Ergebnis:**
- Spiel wird beendet
- TableMonitor wird zurückgesetzt

**Prüfpunkte:**
- [ ] TableMonitor.game_id == nil
- [ ] Tisch ist wieder verfügbar

---

### 12. Ersatzspieler einsetzen

**Ziel:** Einen Ersatzspieler aus einer anderen Mannschaft einsetzen.

**Schritte:**
1. Im PartyMonitor-View
2. Wähle Ersatzspieler aus verfügbaren Ersatzspielern
3. Ordne Ersatzspieler einer Partie zu

**Erwartetes Ergebnis:**
- Ersatzspieler kann zugeordnet werden
- Seeding wird erstellt

**Prüfpunkte:**
- [ ] available_replacement_players enthält Spieler
- [ ] Seeding wird korrekt erstellt

---

## Pool-spezifische Tests

### P1. 14.1 endlos: Neuaufbau bei 1 Ball

**Schritte:**
1. Spiele bis 1 Ball übrig
2. Klicke auf Ball "1"
3. Verifiziere Neuaufbau

**Erwartetes Ergebnis:**
- balls_on_table = 15
- balls_counter_stack wird erweitert
- Ball-Anzeige zeigt 15 Bälle

---

### P2. 14.1 endlos: Neuaufbau bei 0 Bällen

**Schritte:**
1. Spiele bis 0 Bälle übrig
2. Klicke auf Ball "0"
3. Verifiziere Neuaufbau

**Erwartetes Ergebnis:**
- balls_on_table = 15
- balls_counter += 15
- Ball-Anzeige zeigt 15 Bälle

---

### P3. 14.1 endlos: 3 Fouls in Folge

**Schritte:**
1. Klicke 3x auf F1 (Foul)
2. Verifiziere -15 Punkte Strafe

**Erwartetes Ergebnis:**
- 3x -1 Punkt + -15 Punkte = -18 Punkte
- Foul-Zähler wird zurückgesetzt
- Neuaufbau erfolgt

---

### P4. 14.1 endlos: Break-Foul

**Schritte:**
1. Bei vollem Tisch (15 Bälle)
2. Klicke auf F2 (Break-Foul)
3. Verifiziere -2 Punkte

**Erwartetes Ergebnis:**
- -2 Punkte
- Spielerwechsel

---

### P5. 8-Ball: Race to X

**Schritte:**
1. Starte 8-Ball Race to 5
2. Spiele bis 5:3
3. Verifiziere Match-Ende

**Erwartetes Ergebnis:**
- Match endet bei 5 Sätzen für einen Spieler
- Ergebnis wird gespeichert

---

## Fehlerszenarien

### E1. Netzwerkunterbrechung während Partie

**Schritte:**
1. Starte Partie
2. Simuliere Netzwerkunterbrechung
3. Stelle Verbindung wieder her
4. Lade Seite neu

**Erwartetes Ergebnis:**
- Spielstand wird wiederhergestellt
- Keine Datenverluste

---

### E2. Browser-Refresh während Partie

**Schritte:**
1. Während laufender Partie
2. Drücke F5

**Erwartetes Ergebnis:**
- Scoreboard lädt mit aktuellem Stand
- Keine Datenverluste

---

### E3. Doppelter Spielstart

**Schritte:**
1. Versuche ein Spiel auf einem bereits belegten Tisch zu starten

**Erwartetes Ergebnis:**
- Fehlermeldung oder Blockierung
- Kein Datenverlust des laufenden Spiels

---

## Testdaten-Setup

### Schnelles Setup via Rails Console

```ruby
# Location und Tische prüfen
location = Location.find(2368)
pool_tables = location.tables.joins(:table_kind).where(table_kinds: { key: 'pool' })
puts "Pool-Tische: #{pool_tables.count}"

# Pool-Liga finden
pool_discipline = Discipline.where("name LIKE '%14.1%' OR name LIKE '%Ball%'").first
league = League.joins(:discipline).where(disciplines: { id: pool_discipline.id }).last

# Party (Spieltag) finden oder erstellen
party = league.parties.last
puts "Party: #{party.name}" if party

# PartyMonitor prüfen
pm = party.party_monitor
puts "PartyMonitor State: #{pm&.state}"
```

---

## Checkliste für Tester

### Vor dem Test
- [ ] Scenario `carambus_pbv` ist aktiv
- [ ] Rails Server läuft
- [ ] Datenbank enthält Testdaten
- [ ] Browser-Konsole ist offen (für Fehler)

### Während des Tests
- [ ] Screenshots bei Fehlern
- [ ] Rails-Logs beobachten
- [ ] Netzwerk-Tab für API-Fehler prüfen

### Nach dem Test
- [ ] Testdaten aufräumen oder dokumentieren
- [ ] Gefundene Bugs dokumentieren
- [ ] Ergebnisse in diesem Dokument aktualisieren

---

## Bekannte Einschränkungen

1. **PartyGame vs Game**: `PartyGame` ist ein Import aus CC (Club-Computer), `Game` ist das aktive Spiel im TableMonitor. Die Verknüpfung erfolgt über den GamePlan.

2. **Manual Assignment**: Bei `party.manual_assignment == true` werden Spieler manuell zugeordnet statt automatisch aus dem GamePlan.

3. **Continuous Placements**: Bei `party.continuous_placements == true` können Spiele fortlaufend auf freie Tische verteilt werden.

---

## Version

Testplan Version: 1.0
Erstellt: Dezember 2025
Für Carambus Version: 2.0+




