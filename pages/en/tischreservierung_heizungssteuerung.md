# Tischreservierung und Heizungssteuerung

**BC Wedel, Gernot, 7. Mai 2024**

Diese Dokumentation beschreibt die Prozesse für Tischreservierungen und die automatische Heizungssteuerung im BC Wedel.

## Tischreservierungen

### Reservierungsprozess

Tischreservierungen können von autorisierten Mitgliedern im zentralen Google Kalender "BC Wedel" vorgenommen werden.

#### Zugang zum Kalender

Zugangslinks können durch eine informelle E-Mail an folgende Adressen angefordert werden:
- `gernot.ullrich@gmx.de`
- `wcauel@gmail.com`

#### Reservierungstitel-Format

Der Titel der Reservierung muss einem spezifischen Format folgen, um von **Carambus** korrekt ausgewertet werden zu können.

##### Beispiele für Reservierungstitel:

- **Einzeltisch**: `T6 Gernot + Lothar`
- **Mehrere Tische**: `T1, T4-T8 Clubabend`
- **Turnier mit Disziplin**: `T5, T7 NDM Cadre 35/2 Klasse 5-6`

> **Hinweis**: Der Begriff "Cadre" ist ein spezieller Terminus, der in der Reservierung verwendet werden muss.

## Heizungssteuerung (Tischheizungen)

Die Tischheizungen werden automatisch basierend auf Kalendereinträgen und Aktivitäten auf dem **Scoreboard** gesteuert.

### Aktivierung (AN)

Die Heizungen werden automatisch aktiviert:

1. **2 Stunden vor einer Reservierung**
2. **Spätestens innerhalb von 5 Minuten**, wenn ein Spiel auf dem **Scoreboard** erkannt wird

### Deaktivierung (AUS)

Die Heizungen werden automatisch deaktiviert:

1. **Nach Reservierungsbeginn**: Wenn für eine Stunde keine Aktivität auf dem **Scoreboard** erkannt wird
2. **Ohne laufende Reservierung**: Wenn keine Reservierung läuft und für eine Stunde keine Aktivität auf dem **Scoreboard** erkannt wird

## Technische Integration

### Carambus-System

Das **Carambus**-System wertet die Kalendereinträge aus und koordiniert die Heizungssteuerung.

### Scoreboard-Integration

Das **Scoreboard** erkennt Spielaktivitäten und kommuniziert diese an das Heizungssteuerungssystem.

## Wartung und Support

### Kalenderzugang

Bei Problemen mit dem Kalenderzugang kontaktieren Sie:
- `gernot.ullrich@gmx.de`
- `wcauel@gmail.com`

### Heizungsprobleme

Bei Problemen mit der Heizungssteuerung:
1. Überprüfen Sie die Kalendereinträge auf korrekte Formatierung
2. Kontrollieren Sie die Scoreboard-Aktivität
3. Kontaktieren Sie den Systemadministrator

## Änderungshistorie

- **7. Mai 2024**: Erste Version der Dokumentation
- Erstellt von: Gernot Ullrich
- Standort: BC Wedel

---

*Diese Dokumentation ist Teil der Carambus-Operational-Dokumentation für BC Wedel.* 