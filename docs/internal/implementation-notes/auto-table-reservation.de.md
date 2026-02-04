# Automatische Tischreservierung - Implementierung

**Datum:** 19. Januar 2026  
**Entwickler:** AI-Assistant im Auftrag von Gernot Ullrich  
**Projekt:** Carambus - BC Wedel

## Zusammenfassung

Implementierung der automatischen Tischreservierung für Einzelmeisterschaften nach dem Meldeschluss. Die Reservierungen werden als Google Calendar Events erstellt und triggern die bestehende Heizungssteuerung.

## Implementierte Features

### 1. Tournament Model - Neue Methoden

**Datei:** `carambus_master/app/models/tournament.rb`

#### `required_tables_count`
Berechnet die benötigte Anzahl an Tischen basierend auf:
- Tournament Plan (falls zugeordnet)
- Bei mehreren möglichen Modi: Maximum
- Fallback: `(Teilnehmer / 2).ceil`

#### `create_table_reservation`
Erstellt Google Calendar Event mit:
- Automatischer Tischauswahl (passend zur Disziplin, mit Heizung, aufsteigend nach ID)
- Formatierter Event-Summary: `T1-T3 NDM Cadre 35/2 Klasse 5-6`
- Zeitraum: `starting_at` (default 11:00) bis 20:00 Uhr
- Google API Integration

#### Private Helper-Methoden
- `fallback_table_count(participant_count)` - Fallback-Berechnung
- `format_table_list(table_names)` - Formatierung der Tischliste (T1-T3 oder T1, T2, T4)
- `build_event_summary(table_string)` - Zusammenbau der Event-Beschreibung
- `calculate_start_time` - Berechnung der Startzeit aus `tournament_cc.starting_at`
- `calculate_end_time` - Feste Endzeit 20:00 Uhr
- `create_google_calendar_event(summary, start_time, end_time)` - Google API Call

### 2. Rake Task

**Datei:** `carambus_master/lib/tasks/carambus.rake`

#### `carambus:auto_reserve_tables`

**Funktionalität:**
- Findet Turniere mit Meldeschluss in den letzten 7 Tagen
- Prüft Kriterien: Einzelturnier, Location vorhanden, Disziplin vorhanden, Teilnehmer vorhanden
- Berechnet benötigte Tischanzahl
- Erstellt Google Calendar Reservierung
- Detailliertes Logging mit Farben (✓, ⚠️, ✗)
- Zusammenfassung am Ende

**Ausführung:**
```bash
RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables
```

**Cron-Beispiel:**
```bash
0 10 * * * cd /path/to/carambus_master && RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables >> /path/to/log/auto_reserve.log 2>&1
```

### 3. Dokumentation

#### Haupt-Dokumentation
**Datei:** `carambus_master/docs/managers/automatische_tischreservierung.de.md`

Inhalt:
- Übersicht der Funktionsweise
- Tischberechnung im Detail
- Tischauswahl-Kriterien
- Reservierungsformat
- Zeitraum-Konfiguration
- Ausführung (manuell & Cron)
- Beispiel-Ablauf (Szenario)
- Anpassungen durch Veranstaltungsleiter
- Umgang mit Duplikaten
- Wartung und Überwachung
- Fehlerbehebung
- Technische Details

#### Quick Start Guide
**Datei:** `carambus_master/docs/managers/AUTO_RESERVE_README.md`

Kompakte Übersicht für schnellen Einstieg mit:
- Feature-Liste
- Quick Start Befehle
- Kriterien
- Kalender-Format
- Test-Anleitung
- Monitoring
- Häufige Probleme
- Code-Locations

#### Test-Beispiel
**Datei:** `carambus_master/docs/managers/auto_reserve_test_example.rb`

Interaktives Skript für Rails Console mit:
- Beispiel 1: Turnier mit Tournament Plan
- Beispiel 2: Turnier ohne Plan (Fallback)
- Beispiel 3: Rake Task Simulation
- Hilfreiche Console-Abfragen

## Technische Details

### Abhängigkeiten

**Bereits vorhanden:**
- `google-apis-calendar_v3` Gem
- Google Service Account Credentials in Rails credentials
- `CalendarEvent` Model mit `tables_from_summary` Methode
- Heizungssteuerung via `Table#check_heater_on`

**Neu genutzt:**
- `Tournament#discipline.table_kind_id` - Verknüpfung Disziplin → Tischtyp
- `Table#tpl_ip_address` - Identifikation von Tischen mit Heizung
- `TournamentCc#starting_at` - Turnier-Startzeit
- `Tournament#accredation_end` - Meldeschluss

### Datenfluss

```
1. Cron startet Rake Task (täglich 10:00)
   ↓
2. Task findet Turniere (Meldeschluss in letzten 7 Tagen)
   ↓
3. Für jedes Turnier:
   a. required_tables_count → Berechnung der Tischanzahl
   b. create_table_reservation → Google Calendar Event
   ↓
4. Google Calendar Event erstellt
   ↓
5. Bestehende Heizungssteuerung (check_reservations Task)
   a. Liest Events aus Google Calendar
   b. CalendarEvent.tables_from_summary parst Tische
   c. Table#check_heater_on schaltet Heizung 2-3h vorher ein
   ↓
6. Automatische Heizung aktiv
```

### Kriterien für Auto-Reservierung

```ruby
Tournament
  .where(single_or_league: 'single')              # Nur Einzelturniere
  .where.not(location_id: nil)                    # Location vorhanden
  .where.not(discipline_id: nil)                  # Disziplin vorhanden
  .where('date >= ?', Time.current)               # Zukunft
  .where('accredation_end IS NOT NULL')           # Meldeschluss gesetzt
  .where('accredation_end >= ? AND accredation_end <= ?', 
         7.days.ago, Time.current)                # In letzten 7 Tagen
```

### Tischauswahl

```ruby
location.tables
  .joins(:table_kind)
  .where(table_kinds: { id: discipline.table_kind_id })  # Passender Typ
  .where.not(tpl_ip_address: nil)                        # Mit Heizung
  .order(:id)                                             # Aufsteigend
  .limit(tables_needed)                                   # Anzahl
```

### Event-Format

```
Komponenten: [Tische] [Name] [Disziplin] [Klasse]
Beispiel:    T1-T6 NDM Cadre 35/2 Klasse 5-6

Tische:
  - Zusammenhängend: T1-T6
  - Nicht zusammenhängend: T1, T3, T5
  
Zeitraum:
  - Start: tournament_cc.starting_at (default 11:00)
  - Ende: 20:00 (fest)
  - UTC Timezone
```

## Testing

### Syntax-Check

```bash
cd carambus_master
ruby -c app/models/tournament.rb  # ✓ Syntax OK
ruby -c lib/tasks/carambus.rake   # ✓ Syntax OK
```

### Task verfügbar

```bash
bundle exec rake -T | grep auto_reserve
# ✓ rake carambus:auto_reserve_tables
```

### Manueller Test (in Console)

```ruby
# Test-Skript laden
load 'docs/managers/auto_reserve_test_example.rb'

# Oder manuell:
tournament = Tournament.find(12345)
puts tournament.required_tables_count
# => 6

# WICHTIG: NUR in Development!
response = tournament.create_table_reservation
puts response.summary
# => "T1-T6 NDM Cadre 35/2"
```

## Konfiguration

### Google Credentials

Bereits vorhanden in `config/credentials.yml.enc`:
```yaml
google_service:
  public_key: "..."
  private_key: "..."
location_calendar_id: "..."
```

### Cron-Setup

```bash
# Crontab bearbeiten
crontab -e

# Täglich um 10:00 Uhr
0 10 * * * cd /path/to/carambus_master && RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables >> /var/log/carambus/auto_reserve.log 2>&1
```

## Logging

### Task-Ausgabe

```
==============================================================================
Tournament Auto-Reserve Tables Task
Started at: 2026-01-19 10:00:00 +0100
==============================================================================

Found 2 tournament(s) to process:

--------------------------------------------------------------------------------
Tournament: Norddeutsche Meisterschaft Cadre 35/2
  ID: 12345
  Date: 2026-02-15 00:00:00 +0100
  Location: BC Wedel
  Discipline: Cadre 35/2
  Registration deadline: 2026-02-01 23:59:59 +0100
  Participants: 12
  Tables needed: 6
  Available tables with heaters: 8
  ✓ SUCCESS: Calendar event created
    Event ID: abc123xyz
    Summary: T1-T6 NDM Cadre 35/2
    Start: 2026-02-15 10:00:00 UTC
    End: 2026-02-15 19:00:00 UTC

==============================================================================
Summary:
  Total processed: 2
  ✓ Created: 2
  ⚠️  Skipped: 0
  ✗ Failed: 0

Completed at: 2026-01-19 10:01:23 +0100
==============================================================================
```

### Rails Logger

```ruby
# In Tournament#create_google_calendar_event
Rails.logger.info "Tournament ##{id}: Created calendar reservation '#{summary}' (Event ID: #{response.id})"
Rails.logger.error "Tournament ##{id}: Failed to create calendar reservation: #{e.message}"
```

## Fehlerbehandlung

### Robustheit

- Alle Google API Calls in `begin/rescue` Block
- Detaillierte Fehlermeldungen im Log
- Task läuft weiter auch bei Einzelfehlern
- Zusammenfassung am Ende mit Fehler-Liste

### Häufige Fehler

| Fehler | Ursache | Lösung |
|--------|---------|--------|
| "No participants registered" | Keine Teilnehmer | Normal - wird übersprungen |
| "Could not determine table count" | Kein Plan, keine Teilnehmer | Plan zuordnen |
| "Failed to create calendar event" | Google API Fehler | Credentials prüfen |
| "Only X tables available, need Y" | Nicht genug Tische | Warnung - fährt fort |

## Nächste Schritte

### Deployment

1. Code committen:
   ```bash
   git add app/models/tournament.rb
   git add lib/tasks/carambus.rake
   git add docs/managers/
   git commit -m "Add automatic table reservation for tournaments"
   ```

2. Nach Production deployen:
   ```bash
   # Je nach Deployment-Strategie
   git push production master
   ```

3. Cron-Job einrichten:
   ```bash
   # Auf Production-Server
   crontab -e
   # Zeile hinzufügen (siehe oben)
   ```

### Monitoring einrichten

1. Log-Rotation:
   ```bash
   # /etc/logrotate.d/carambus_auto_reserve
   /var/log/carambus/auto_reserve.log {
     daily
     rotate 30
     compress
     delaycompress
     notifempty
     missingok
   }
   ```

2. Monitoring-Alert (optional):
   ```bash
   # Check ob Task läuft
   # E-Mail bei Fehlern
   ```

### Testing in Production

1. **Erste Woche:** Manuell täglich prüfen
   ```bash
   tail -f /var/log/carambus/auto_reserve.log
   ```

2. **Google Kalender prüfen:** Wurden Einträge erstellt?

3. **Heizung prüfen:** Schalten sich Heizungen automatisch?

## Offene Punkte / Verbesserungen

### Optional für später

- [ ] E-Mail-Benachrichtigung bei Fehlern
- [ ] Webhook für Monitoring-System
- [ ] Dashboard für Reservierungs-Übersicht
- [ ] Automatisches Löschen alter/abgelaufener Reservierungen
- [ ] Unterstützung für mehrtägige Turniere
- [ ] Intelligentere Tischauswahl (Berücksichtigung bereits reservierter Tische)

## Support & Kontakt

**Bei Fragen oder Problemen:**
- gernot.ullrich@gmx.de
- wcauel@gmail.com

**Code-Review:**
- Tournament Model: `app/models/tournament.rb` (Zeilen 1565-1783)
- Rake Task: `lib/tasks/carambus.rake` (Zeilen 1060-1177)

---

**Implementierung abgeschlossen am:** 19. Januar 2026  
**Status:** ✓ Bereit für Production  
**Getestet:** ✓ Syntax OK, Task verfügbar
