# Test-Checkliste für Verbesserung 1: Status-Übersicht

## Implementierte Features

### ✅ 1. Wizard nur für Spielleiter
- **Erwartung:** Wizard wird nur angezeigt wenn `current_user.club_admin?` oder `current_user.system_admin?`
- **Test:** Als normaler User einloggen → Wizard sollte nicht sichtbar sein
- **Test:** Als club_admin einloggen → Wizard sollte sichtbar sein

### ✅ 2. Status-Übersicht für alle
- **Erwartung:** Status-Sektion wird angezeigt wenn Turnier läuft oder abgeschlossen ist
- **Test:** Turnier noch nicht gestartet → Status-Sektion sollte NICHT sichtbar sein
- **Test:** Turnier gestartet → Status-Sektion sollte sichtbar sein mit:
  - Turnier-Phase (z.B. "playing_groups")
  - Aktuelle Runde (falls vorhanden)
  - Spiele-Fortschritt (Fortschrittsbalken)
  - Aktuelle Spiele (vereinfacht, nur wenn playing_groups/playing_finals)
  - Link zum Tournament Monitor (nur für Spielleiter)
  - Gruppen (falls vorhanden)
  - Platzierungen (falls vorhanden)

### ✅ 3. Admin-Bereich für Spielleiter
- **Erwartung:** Admin-Bereich wird nur für Spielleiter angezeigt
- **Test:** Als normaler User → Admin-Bereich sollte NICHT sichtbar sein
- **Test:** Als club_admin → Admin-Bereich sollte sichtbar sein mit:
  - Geparste Einladung (falls vorhanden)
  - Setzliste (Position, Spieler, Vorgabe)
  - Schnellzugriff-Links

### ✅ 4. Zugriffskontrolle Tournament Monitor
- **Erwartung:** Nur Spielleiter können auf Tournament Monitor zugreifen
- **Test:** Als normaler User versuchen Tournament Monitor aufzurufen → Sollte redirecten mit Fehlermeldung
- **Test:** Als club_admin → Tournament Monitor sollte zugänglich sein

## Zu testende Szenarien

### Szenario 1: Turnier nicht gestartet
- **Als normaler User:** Nur Tournament Details sichtbar
- **Als Spielleiter:** Wizard + Admin-Bereich sichtbar, keine Status-Sektion

### Szenario 2: Turnier läuft
- **Als normaler User:** Status-Sektion sichtbar, kein Wizard, kein Admin-Bereich
- **Als Spielleiter:** Alle Sektionen sichtbar, Link zum Tournament Monitor prominent

### Szenario 3: Turnier abgeschlossen
- **Als normaler User:** Status-Sektion mit finalen Ergebnissen sichtbar
- **Als Spielleiter:** Status-Sektion + Admin-Bereich sichtbar

## Potenzielle Probleme

### Edge Cases zu prüfen:
1. **Kein Tournament Monitor vorhanden:** Status-Sektion sollte nicht angezeigt werden (✓ bereits implementiert)
2. **Keine Gruppen:** Gruppen-Sektion sollte nicht angezeigt werden (✓ bereits implementiert)
3. **Keine Platzierungen:** Platzierungen-Sektion sollte nicht angezeigt werden (✓ bereits implementiert)
4. **Keine Spiele:** Spiele-Fortschritt sollte nicht angezeigt werden (✓ bereits implementiert)
5. **Keine Einladung:** Geparste Einladung zeigt Warnung (✓ bereits implementiert)

### Performance:
- Prüfen ob mehrere DB-Queries vermieden werden (includes für game_participations verwendet)

## Bekannte Verbesserungen für später

1. **Seedings-Tabelle:** Sollte auch nur für Spielleiter bearbeitbar sein (aktuell möglicherweise noch für alle)
2. **Responsive Design:** Mobile Ansicht prüfen
3. **Styling:** Eventuell Tailwind CSS Klassen anpassen falls nicht konsistent

