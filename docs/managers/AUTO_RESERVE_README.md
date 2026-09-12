# Automatische Tischreservierung - Quick Start Guide

## Übersicht

Automatische Reservierung von Tischen für Einzelmeisterschaften nach dem Meldeschluss.

## Features

✅ Automatische Berechnung der benötigten Tischanzahl  
✅ Auswahl passender Tische nach Disziplin  
✅ Nur Tische mit Heizung (`tpl_ip_address`, bei globalen Tischen in `table_locals`)  
✅ Google Calendar Integration  
✅ Täglicher Cron-Job  
✅ Detailliertes Logging  

## Quick Start

Der Task läuft auf dem **Location-Server** (er braucht dessen Datenbank und die Google-Credentials), im
Deploy-Verzeichnis `/var/www/<basename>/current` (BC Wedel: `/var/www/carambus_bcw/current`).

### 1. Manuell ausführen

```bash
cd /var/www/<basename>/current
RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables
```

### 2. Automatisch per Cron

Der Task steht nicht im Zeitplan der Anwendung (`config/schedule.rb`); die Crontab-Zeile trägt man auf dem
Location-Server von Hand ein, als der Benutzer, unter dem Carambus läuft (`www-data`). Cron kennt kein rbenv im
`PATH`, deshalb der absolute `bundle`-Pfad wie in `config/schedule.rb`.

```bash
# Crontab bearbeiten (als www-data)
crontab -e

# Täglich um 10:00 Uhr
0 10 * * * cd /var/www/<basename>/current && RAILS_ENV=production /var/www/.rbenv/shims/bundle exec rake carambus:auto_reserve_tables >> /var/www/<basename>/current/log/auto_reserve.log 2>&1
```

## Kriterien für Auto-Reservierung

Ein Turnier wird berücksichtigt, wenn:

1. ✅ `location_id` vorhanden
2. ✅ `discipline_id` vorhanden
3. ✅ `date` liegt in der Zukunft
4. ✅ `accredation_end` (Meldeschluss) gesetzt und in letzten 7 Tagen
5. ✅ Mindestens 1 Teilnehmer gemeldet (pro Turnier geprüft)

> Hinweis: Es gibt aktuell **keinen** technischen `single_or_league = 'single'`-Filter
> im Task – die Auswahl erfolgt allein über die obigen Kriterien.

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

# Ein Turnier mit denselben Methoden prüfen, die der Task nutzt:
tournament = Tournament.find(12345)
puts "Benötigte Tische: #{tournament.required_tables_count}"
puts "Tische mit Heizung: #{tournament.available_tables_with_heaters.map(&:name).join(', ')}"

# Reservierung erstellen (NUR in Development!)
response = tournament.create_table_reservation
puts response.summary
```

> **Hinweis zum Testskript** `docs/managers/auto_reserve_test_example.rb`: Es weicht vom Task ab. Es filtert auf
> `single_or_league: 'single'` und prüft die Heizung nur über `tables.tpl_ip_address`, nicht über
> `table_locals` bei globalen Tischen. Maßgeblich sind die beiden Methoden oben.

## Monitoring

### Log-Datei prüfen

```bash
tail -f /var/www/<basename>/current/log/auto_reserve.log
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
| "Could not determine table count" | Der passende Turnierplan hat Tischanzahl 0 — Tischanzahl im TournamentPlan pflegen |
| "FAILED: Could not create calendar event" | Keine beheizten Tische passenden Typs an der Location, fehlende `google_service`-Credentials oder ein Google-API-Fehler (Details im Rails-Log) |

## Manuelle Anpassung

Falls automatische Reservierung nicht passt:

1. Google Kalender öffnen
2. Eintrag suchen
3. Tische/Zeiten anpassen
4. Format beibehalten: `T1, T2, T3 Name` bzw. `T1-T3 Name`. Einträge ohne erkennbare Tischangabe (und ohne
   `Wort:`-Präfix für Info-Einträge) löscht der nächste Reservierungs-Check

## Dokumentation

📄 Vollständige Dokumentation: `docs/managers/automatische_tischreservierung.de.md`  
📄 Bestehende Heizungssteuerung: `docs/managers/tischreservierung_heizungssteuerung.de.md`

## Code-Locations

```
app/models/tournament.rb                              # required_tables_count, available_tables_with_heaters, create_table_reservation
app/services/tournament/table_reservation_service.rb  # Tischliste, Kalendereintrag, Zeiten
lib/tasks/carambus.rake                               # Task: auto_reserve_tables
```

## Support

Bei Fragen oder Problemen:
- gernot.ullrich@gmx.de
- wcauel@gmail.com

---

**Version:** 1.0  
**Datum:** 19. Januar 2026  
**Autor:** Gernot Ullrich
