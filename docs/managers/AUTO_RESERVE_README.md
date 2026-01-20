# Automatische Tischreservierung - Quick Start Guide

## Übersicht

Automatische Reservierung von Tischen für Einzelmeisterschaften nach dem Meldeschluss.

## Features

✅ Automatische Berechnung der benötigten Tischanzahl  
✅ Auswahl passender Tische nach Disziplin  
✅ Nur Tische mit Heizung (tpl_ip_address)  
✅ Google Calendar Integration  
✅ Täglicher Cron-Job  
✅ Detailliertes Logging  

## Quick Start

### 1. Manuell ausführen

```bash
cd /path/to/carambus_master
RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables
```

### 2. Automatisch per Cron

```bash
# Crontab bearbeiten
crontab -e

# Täglich um 10:00 Uhr
0 10 * * * cd /path/to/carambus_master && RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables >> /path/to/log/auto_reserve.log 2>&1
```

## Kriterien für Auto-Reservierung

Ein Turnier wird berücksichtigt, wenn:

1. ✅ `single_or_league = 'single'`
2. ✅ `location_id` vorhanden
3. ✅ `discipline_id` vorhanden
4. ✅ `date` liegt in der Zukunft
5. ✅ `accredation_end` (Meldeschluss) in letzten 7 Tagen
6. ✅ Mindestens 1 Teilnehmer gemeldet

## Tischberechnung

```
1. TournamentPlan.tables (falls vorhanden)
2. Bei mehreren Modi: Maximum
3. Fallback: (Teilnehmer / 2) aufgerundet
```

## Kalender-Format

```
T1-T3 NDM Cadre 35/2 Klasse 5-6
```

**Zeitraum:**
- Start: `tournament_cc.starting_at` (default 11:00)
- Ende: 20:00 Uhr

## Test in Console

```ruby
# Rails Console öffnen
rails console

# Test-Skript laden
load 'docs/managers/auto_reserve_test_example.rb'

# Oder manuell ein Turnier testen:
tournament = Tournament.find(12345)
puts "Benötigte Tische: #{tournament.required_tables_count}"

# Reservierung erstellen (NUR in Development!)
response = tournament.create_table_reservation
puts response.summary
```

## Monitoring

### Log-Datei prüfen

```bash
tail -f /path/to/log/auto_reserve.log
```

### Erwartete Ausgabe

```
==============================================================================
Tournament Auto-Reserve Tables Task
Started at: 2026-01-19 10:00:00 +0100
==============================================================================

Found 2 tournament(s) to process:

Tournament: NDM Cadre 35/2
  ✓ SUCCESS: Calendar event created
    Summary: T1-T6 NDM Cadre 35/2

==============================================================================
Summary:
  Total processed: 2
  ✓ Created: 2
  ⚠️  Skipped: 0
  ✗ Failed: 0
==============================================================================
```

## Häufige Probleme

| Problem | Lösung |
|---------|--------|
| Keine Turniere gefunden | Prüfen: Meldeschluss in letzten 7 Tagen? |
| "No participants" | Normal - wird übersprungen |
| "Could not determine table count" | TournamentPlan zuordnen |
| "Failed to create event" | Google Credentials prüfen |

## Manuelle Anpassung

Falls automatische Reservierung nicht passt:

1. Google Kalender öffnen
2. Eintrag suchen
3. Tische/Zeiten anpassen
4. Format beibehalten: `T1, T2, T3 Name`

## Dokumentation

📄 Vollständige Dokumentation: `docs/managers/automatische_tischreservierung.de.md`  
📄 Bestehende Heizungssteuerung: `docs/managers/tischreservierung_heizungssteuerung.de.md`

## Code-Locations

```
app/models/tournament.rb          # Methoden: required_tables_count, create_table_reservation
lib/tasks/carambus.rake           # Task: auto_reserve_tables
```

## Support

Bei Fragen oder Problemen:
- gernot.ullrich@gmx.de
- wcauel@gmail.com

---

**Version:** 1.0  
**Datum:** 19. Januar 2026  
**Autor:** Gernot Ullrich
