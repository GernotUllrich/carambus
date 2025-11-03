# Implementierungsplan: Top 3 Verbesserungen Turniermanagement

**Datum:** 2024-12-19  
**Status:** Planung

## Übersicht

Dieser Plan beschreibt die Implementierung der drei wichtigsten Verbesserungen aus dem Review:

1. **Status-Übersicht während/nach Turnier im Tournament View**
2. **Datenverlust bei Archivierung vermeiden**
3. **Live-Feedback bei Setzliste-Definition**

---

## Verbesserung 1: Status-Übersicht während/nach Turnier im Tournament View

### Problem
- Wenn das Turnier läuft kann ein Außenstehender nichts sehen
- Nach dem Turnier ist der Ablauf nicht mehr nachvollziehbar
- Der Übergang zum Tournament Monitor ist nicht klar

### Lösung

#### 1.1 Tournament Status-Sektion (während/nach Turnier)
**Ziel:** Zwischenstände und Ergebnisse für alle sichtbar machen

**Implementierung:**
- Neue Sektion in `tournaments/show.html.erb` nach dem Wizard
- Anzeige nur wenn `tournament.tournament_started?` oder Turnier abgeschlossen
- Zeige:
  - Turnier-Status (playing_groups, playing_finals, etc.)
  - Aktuelle Runde
  - Anzahl gespielter Spiele vs. Gesamt
  - Gruppentabellen (falls Gruppenphase)
  - Aktuelle Platzierungen
  - Link zum Tournament Monitor (prominent)

**Code-Stellen:**
- `app/views/tournaments/show.html.erb` - neue Sektion hinzufügen
- `app/views/tournaments/_tournament_status.html.erb` - neues Partial
- `app/helpers/tournament_helper.rb` - Helper-Methoden für Status-Daten

**Datenquelle:**
- `tournament.tournament_monitor` für aktuelle Status
- `tournament.games` für Spiele-Informationen
- `tournament_monitor.data['groups']` für Gruppen-Informationen

#### 1.2 Admin-Bereich: Geparste Einladung & Setzliste
**Ziel:** Für Spielleiter jederzeit Rückgriff auf ursprüngliche Daten

**Implementierung:**
- Collapsible Sektion nur für Admins
- Zeige:
  - Geparste Einladung (falls vorhanden): `tournament.data['invitation_filename']`
  - Setzliste (Original-Reihenfolge)
  - Extrahierte Gruppenbildung (falls vorhanden)

**Code-Stellen:**
- `app/views/tournaments/_admin_tournament_info.html.erb` - neues Partial
- Zeige nur wenn `current_user&.admin?`

#### 1.3 Prominenter Link zum Tournament Monitor
**Ziel:** Klarer Übergang zum Tournament Monitor

**Implementierung:**
- Prominenter Button/Section wenn Turnier läuft
- Sticky/immer sichtbar während Turnier

**Code-Stellen:**
- `app/views/tournaments/_wizard_steps_v2.html.erb` - bereits vorhanden, aber prominenter machen
- Oder neue Sektion oben im View

### Aufwand
- **Schätzung:** 4-6 Stunden
- **Komplexität:** Mittel
- **Priorität:** Hoch

---

## Verbesserung 2: Datenverlust bei Archivierung vermeiden

### Problem
- Lokale Daten werden beim Turnier-Ende gelöscht
- Keine Möglichkeit für Vergleich lokale vs. ClubCloud-Daten

### Lösung

#### 2.1 Export-Funktion vor Archivierung
**Ziel:** Lokale Daten exportieren bevor sie gelöscht werden

**Implementierung:**
- Neuer Button "📥 Turnierdaten exportieren" vor Archivierung
- Export als JSON oder CSV
- Enthält:
  - Alle Spiele mit detaillierten Ergebnissen
  - Seedings mit Positionen
  - Tournament Monitor Daten
  - Geparste Einladung (falls vorhanden)

**Code-Stellen:**
- `app/controllers/tournaments_controller.rb` - neue Action `export_tournament_data`
- `app/views/tournaments/_wizard_steps_v2.html.erb` - Button hinzufügen
- `app/models/tournament.rb` - Export-Methode

#### 2.2 Optionale Archivierung statt Löschung
**Ziel:** Lokale Daten optional archivieren statt löschen

**Implementierung:**
- Checkbox "Lokale Daten archivieren" bei Archivierung
- Wenn aktiviert: Daten in `tournament.data['archived_local_data']` speichern
- Archivierte Daten bleiben verfügbar für Vergleich

**Code-Stellen:**
- `app/controllers/tournaments_controller.rb` - `reload_from_cc` Action anpassen
- `app/views/tournaments/_wizard_steps_v2.html.erb` - Checkbox hinzufügen

#### 2.3 Vergleichsansicht (Optional)
**Ziel:** Vergleich lokale vs. ClubCloud-Daten

**Implementierung:**
- Neue View `tournaments/compare_data`
- Zeige Unterschiede zwischen lokalen und ClubCloud-Daten
- Nur wenn beide vorhanden

**Code-Stellen:**
- `app/controllers/tournaments_controller.rb` - neue Action `compare_data`
- `app/views/tournaments/compare_data.html.erb` - neue View

### Aufwand
- **Schätzung:** 3-4 Stunden
- **Komplexität:** Niedrig-Mittel
- **Priorität:** Hoch

---

## Verbesserung 3: Live-Feedback bei Setzliste-Definition

### Problem
- Kein Feedback auf Gruppenbesetzung bei Änderung der Reihenfolge
- Alternativen zu Turniermodi erst spät sichtbar

### Lösung

#### 3.1 Live-Vorschau der Gruppenbesetzung
**Ziel:** Unmittelbares Feedback bei Änderung der Reihenfolge

**Implementierung:**
- JavaScript/Cable Ready für Live-Updates
- Wenn Position geändert wird:
  - Berechne Gruppen für alle möglichen Turniermodi
  - Zeige Vorschau der Gruppenbesetzung
  - Zeige Spielpaarungen

**Code-Stellen:**
- `app/views/tournaments/define_participants.html.erb` - JavaScript hinzufügen
- `app/javascript/` - neues JS für Live-Updates
- `app/controllers/tournaments_controller.rb` - neue Action `preview_groups` (AJAX)

**Technologie:**
- Stimulus Controller für Live-Updates
- Oder Cable Ready für Echtzeit-Updates
- Oder einfaches AJAX-Polling

#### 3.2 Frühe Anzeige von Turniermodi-Alternativen
**Ziel:** Alternativen schon bei Setzliste-Definition zeigen

**Implementierung:**
- In `define_participants.html.erb` zusätzliche Sektion
- Zeige passende TournamentPlans basierend auf Spieleranzahl
- Live-Vorschau der Gruppenbesetzung für jeden Plan

**Code-Stellen:**
- `app/views/tournaments/define_participants.html.erb` - neue Sektion
- `app/helpers/tournament_helper.rb` - Helper für Plan-Vorschläge

#### 3.3 Visualisierung der Gruppen
**Ziel:** Gruppen visuell darstellen

**Implementierung:**
- Cards/Tabs für jede Gruppe
- Spielerliste pro Gruppe
- Erste Spielpaarungen anzeigen

**Code-Stellen:**
- `app/views/tournaments/_group_preview.html.erb` - neues Partial
- CSS für Gruppen-Cards

### Aufwand
- **Schätzung:** 6-8 Stunden
- **Komplexität:** Hoch (JavaScript + Backend)
- **Priorität:** Hoch

---

## Implementierungs-Reihenfolge

### Sprint 1 (4-6 Stunden): Verbesserung 1
1. Tournament Status-Sektion implementieren
2. Admin-Bereich für geparste Einladung
3. Prominenter Link zum Tournament Monitor

### Sprint 2 (3-4 Stunden): Verbesserung 2
1. Export-Funktion implementieren
2. Optionale Archivierung

### Sprint 3 (6-8 Stunden): Verbesserung 3
1. Live-Vorschau der Gruppenbesetzung
2. Frühe Anzeige von Alternativen
3. Visualisierung

---

## Technische Überlegungen

### Datenzugriff
- `tournament.tournament_monitor` für aktuelle Status
- `tournament.games.where("games.id >= #{Game::MIN_ID}")` für lokale Spiele
- `tournament_monitor.data['groups']` für Gruppen-Informationen

### Performance
- Caching für Gruppenberechnungen
- Lazy Loading für große Turniere
- AJAX für Live-Updates (nicht Page Reload)

### UI/UX
- Responsive Design
- Loading States bei Live-Updates
- Fehlerbehandlung

---

## Offene Fragen

1. **Verbesserung 1:** Soll die Status-Sektion immer sichtbar sein oder nur wenn Turnier läuft?
2. **Verbesserung 2:** Format für Export (JSON, CSV, beide)?
3. **Verbesserung 3:** Wie detailliert soll die Live-Vorschau sein? (nur Gruppen oder auch Paarungen?)

---

## Nächste Schritte

1. ✅ Plan erstellen (dieses Dokument)
2. ⏳ User-Feedback zu Plan einholen
3. ⏳ Implementierung starten mit Verbesserung 1

