# Automatische Tischreservierung für Einzelmeisterschaften

**BC Wedel, Gernot, 19. Januar 2026**

Diese Dokumentation beschreibt die automatische Reservierung von Tischen für Einzelmeisterschaften nach dem Meldeschluss.

## Übersicht

Das System reserviert automatisch die benötigten Tische für anstehende Einzelmeisterschaften im Google Kalender. Die Heizungssteuerung erfolgt dann wie gewohnt basierend auf diesen Kalendereinträgen.

## Funktionsweise

### Automatische Tischreservierung

Nach dem Meldeschluss eines Turniers wird täglich geprüft, ob eine Tischreservierung erstellt werden muss. Dabei werden folgende Kriterien berücksichtigt:

1. **Turniertyp**: Nur Einzelmeisterschaften (keine Ligen)
2. **Meldeschluss**: Muss in den letzten 7 Tagen abgelaufen sein
3. **Turnierdatum**: Liegt in der Zukunft
4. **Location**: Muss vorhanden sein
5. **Disziplin**: Muss vorhanden sein
6. **Teilnehmer**: Mindestens ein Teilnehmer gemeldet

### Tischberechnung

Die Anzahl der benötigten Tische wird wie folgt ermittelt:

1. **Aus Turnierplan**: Wenn ein TournamentPlan zugeordnet ist, wird die dort definierte Tischanzahl verwendet
2. **Mehrere Modi möglich**: Bei mehreren möglichen Turnierplänen wird die maximale Tischanzahl gewählt
3. **Fallback**: Falls kein Plan vorhanden: `(Anzahl Teilnehmer / 2)` aufgerundet

### Tischauswahl

Die Tische werden wie folgt ausgewählt:

1. **Tischtyp**: Passend zur Disziplin (über `table_kind`)
2. **Heizung**: Nur Tische mit `tpl_ip_address` (= Heizung vorhanden)
3. **Reihenfolge**: Aufsteigend nach Tisch-ID
4. **Anzahl**: Entsprechend der Berechnung (siehe oben)

### Reservierungsformat

Der Google Calendar Eintrag wird im folgenden Format erstellt:

```
T1-T3 NDM Cadre 35/2 Klasse 5-6
```

**Bestandteile:**
- Tischliste: `T1-T3` (bei zusammenhängenden Tischen) oder `T1, T2, T4` (bei nicht-zusammenhängenden)
- Turniername: Shortname oder Title
- Disziplin: Name der Disziplin
- Spielklasse: Falls vorhanden

### Zeitraum

**Startzeit:**
- Aus `tournament_cc.starting_at` (falls vorhanden)
- Sonst: 11:00 Uhr

**Endzeit:**
- Fest: 20:00 Uhr

**Heizungssteuerung:**
- Automatisches Einschalten 2 Stunden vor Reservierungsbeginn (kleine Tische)
- Automatisches Einschalten 3 Stunden vor Reservierungsbeginn (große Tische)
- Automatisches Ausschalten bei Inaktivität auf dem Scoreboard

## Ausführung

### Manuell

Der Task kann manuell ausgeführt werden:

```bash
cd /path/to/carambus_master
RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables
```

### Automatisch (Cron)

Für tägliche automatische Ausführung kann ein Cron-Job eingerichtet werden:

```bash
# Crontab bearbeiten
crontab -e

# Folgende Zeile hinzufügen (täglich um 10:00 Uhr):
0 10 * * * cd /path/to/carambus_master && RAILS_ENV=production bundle exec rake carambus:auto_reserve_tables >> /path/to/log/auto_reserve.log 2>&1
```

**Empfohlene Ausführungszeit:**
- **10:00 Uhr morgens** - Nach dem Meldeschluss haben sich die Teilnehmerzahlen stabilisiert

## Beispiel-Ablauf

### Szenario

1. **Turnier**: Norddeutsche Meisterschaft Cadre 35/2
2. **Datum**: 15. Februar 2026
3. **Meldeschluss**: 1. Februar 2026
4. **Teilnehmer**: 12 Spieler gemeldet
5. **Location**: BC Wedel
6. **Verfügbare Tische**: T1-T8 (Match Billard mit Heizung)

### Ablauf

**1. Februar 2026, 10:00 Uhr** (erster Durchlauf nach Meldeschluss):
- Task läuft automatisch via Cron
- Findet das Turnier (Meldeschluss gestern)
- Berechnet: 12 Teilnehmer → 6 Tische benötigt
- Wählt Tische: T1-T6 (aufsteigend nach ID)
- Erstellt Kalendereintrag: `T1-T6 NDM Cadre 35/2`
- Zeitraum: 11:00 - 20:00 Uhr

**15. Februar 2026, 08:00 Uhr** (3 Stunden vor Beginn):
- Heizungssteuerung schaltet Tische T1-T6 automatisch ein
- Grund: Kalendereintrag erkannt, Match Billard = 3h Vorheizdauer

**15. Februar 2026, 11:00 Uhr**:
- Turnier beginnt
- Tische sind bereits vorgeheizt

**15. Februar 2026, 20:00 Uhr**:
- Reservierung endet
- Bei Inaktivität: Heizungen schalten sich automatisch ab

## Anpassungen durch Veranstaltungsleiter

Falls die automatische Reservierung nicht passt, kann der Veranstaltungsleiter den Kalendereintrag manuell anpassen:

1. **Google Kalender öffnen**: [BC Wedel Kalender](https://calendar.google.com)
2. **Eintrag suchen**: Nach Turniernamen oder Datum
3. **Bearbeiten**:
   - Tische ändern: z.B. `T2, T4, T6` statt `T1-T3`
   - Zeiten anpassen: z.B. 09:00 - 22:00 Uhr
   - Umbenennen: z.B. zusätzliche Infos hinzufügen

**Wichtig:** Das Format muss beibehalten werden:
- Tische: `T1, T2` oder `T1-T3`
- Keine Doppelpunkte am Anfang (diese sind für Info-Einträge reserviert)

## Duplikate

Falls versehentlich mehrere Reservierungen für dasselbe Turnier erstellt werden, ist dies unkritisch:
- Heizungen schalten sich bei mehreren Einträgen trotzdem nur einmal ein
- Unnötige Einträge können im Kalender gelöscht werden

## Wartung und Überwachung

### Log-Ausgabe

Der Task protokolliert alle Aktionen:

```
==============================================================================
Tournament Auto-Reserve Tables Task
Started at: 2026-01-19 10:00:00 +0100
==============================================================================

Found 3 tournament(s) to process:

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
  Total processed: 3
  ✓ Created: 2
  ⚠️  Skipped: 1
  ✗ Failed: 0

Completed at: 2026-01-19 10:01:23 +0100
==============================================================================
```

### Mögliche Probleme

| Problem | Ursache | Lösung |
|---------|---------|--------|
| "No participants registered" | Keine Teilnehmer gemeldet | Normal - Turnier wird übersprungen |
| "Could not determine table count" | Kein Turnierplan, keine Teilnehmer | Turnierplan zuordnen oder Teilnehmer melden |
| "Only X tables available, need Y" | Nicht genug Tische mit Heizung | Warnung - fährt mit verfügbaren Tischen fort |
| "Failed to create calendar event" | Google API Fehler | Credentials prüfen, Netzwerk prüfen |

## Technische Details

### Modell: `Tournament`

**Neue Methoden:**

```ruby
# Berechnet benötigte Tischanzahl
tournament.required_tables_count
# => 6

# Erstellt Google Calendar Reservierung
tournament.create_table_reservation
# => #<Google::Apis::CalendarV3::Event>
```

### Rake Task

```ruby
# Pfad: lib/tasks/carambus.rake
namespace :carambus do
  desc "Auto-reserve tables for upcoming tournaments after registration deadline"
  task auto_reserve_tables: :environment do
    # Implementation...
  end
end
```

## Änderungshistorie

- **19. Januar 2026**: Erste Version der automatischen Tischreservierung
- Erstellt von: Gernot Ullrich & AI-Assistant
- Standort: BC Wedel

---

*Diese Dokumentation ist Teil der Carambus-Operational-Dokumentation für BC Wedel.*
