---
---
title: Tischreservierung und Heizungssteuerung
summary: Automatisierte Tischreservierung über Google Calendar und intelligente Heizungssteuerung basierend auf Scoreboard-Aktivitäten
version:
published_at: !ruby/object:ActiveSupport::TimeWithZone
  utc: 2025-01-27 10:00:00.000000000 Z
  zone: !ruby/object:ActiveSupport::TimeZone
    name: Europe/Berlin
  time: 2025-01-27 11:00:00.000000000 Z
tags: [reservierung, heizung, automatisation, google-calendar]
metadata: {}
position: 0
id: 100
---

# Tischreservierung und Heizungssteuerung

*BC Wedel, Gernot, 7. Mai 2024*

## 1. Tischreservierung

### Zugang zum Google Calendar
Tischreservierungen können ab sofort von berechtigten Mitgliedern im zentralen Google Calendar "BC Wedel" vorgenommen werden.

**Zugangslinks erhalten Sie durch eine formlose E-Mail an:**
- gernot.ullrich@gmx.de
- wcauel@gmail.com

### Wichtige Formatierung für Carambus-Auswertung
**Der Titel der Reservierung muss einem spezifischen Format folgen, damit Carambus die Reservierung korrekt auswerten kann.**

#### Gültige Reservierungstitel-Beispiele:

- **"T6 Gernot + Lothar"** - Einzelne Tischreservierung
- **"T1, T4-T8 Clubabend"** - Mehrere Tische für Clubabend
- **"T5, T7 NDM Cadre 35/2 Klasse 5-6"** - Turnierreservierung (Cadre wird rot hervorgehoben)

### Formatierungsregeln:
- **Tischnummern:** Verwenden Sie "T" gefolgt von der Tischnummer (z.B. T1, T6)
- **Mehrere Tische:** Trennen Sie mit Komma (T1, T4) oder Bereich (T4-T8)
- **Beschreibung:** Fügen Sie nach den Tischnummern eine Beschreibung hinzu
- **Turniere:** Verwenden Sie spezielle Schlüsselwörter wie "Cadre" für automatische Erkennung

## 2. Heizungssteuerung

### Automatisierte Steuerung
Die Tischheizungen werden automatisch basierend auf Kalendereinträgen und Scoreboard-Aktivitäten geschaltet.

### Heizung EIN (AN)

Die Heizung wird automatisch eingeschaltet:

1. **2 Stunden vor einer Reservierung** - Basierend auf Google Calendar Einträgen
2. **Spätestens 5 Minuten vor Beginn** - Wenn ein Spiel auf dem Scoreboard erkannt wird

### Heizung AUS (AUS)

Die Heizung wird automatisch ausgeschaltet:

1. **Nach 1 Stunde ohne Scoreboard-Aktivität** - Wenn die Reservierung bereits begonnen hat
2. **Nach 1 Stunde ohne Aktivität** - Wenn keine Reservierung läuft und keine Scoreboard-Aktivität erkannt wird

### Technische Details

- **Scoreboard-Integration:** Das System überwacht kontinuierlich die Aktivitäten auf dem Carambus Scoreboard
- **Kalender-Integration:** Google Calendar Einträge werden automatisch ausgelesen und verarbeitet
- **Intelligente Logik:** Das System berücksichtigt sowohl geplante Reservierungen als auch spontane Aktivitäten

### Vorteile der automatisierten Steuerung

- **Energieeffizienz:** Heizungen werden nur bei Bedarf eingeschaltet
- **Komfort:** Automatische Vorheizung vor Reservierungen
- **Kosteneinsparung:** Vermeidung unnötiger Heizkosten bei ungenutzten Tischen
- **Benutzerfreundlichkeit:** Keine manuelle Bedienung der Heizungen erforderlich

---

*Diese Dokumentation beschreibt die Integration von Google Calendar Reservierungen mit der Carambus Scoreboard-Technologie für eine vollautomatisierte Tisch- und Heizungsverwaltung im BC Wedel.* 