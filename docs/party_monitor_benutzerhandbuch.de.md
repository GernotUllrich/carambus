# PartyMonitor - Spieltagabwicklung Benutzerhandbuch

## Übersicht

Der PartyMonitor ist das zentrale Werkzeug zur Abwicklung von Liga-Spieltagen in Carambus. Er ermöglicht die vollständige Verwaltung eines Mannschaftskampfes von der Spieleraufstellung über die Tischzuordnung bis zur Ergebniserfassung und -übermittlung.

### Unterstützte Ligen

- **Pool-Ligen** (Landesliga, Bezirksliga, etc.)
  - 14.1 endlos (Straight Pool)
  - 8-Ball
  - 9-Ball
  - 10-Ball
- **Karambol-Ligen** (in Vorbereitung)
- **Snooker-Ligen** (in Vorbereitung)

---

## Inhaltsverzeichnis

1. [Voraussetzungen](#voraussetzungen)
2. [PartyMonitor starten](#partymonitor-starten)
3. [Workflow-Übersicht](#workflow-übersicht)
4. [Phase 1: Mannschaftsaufstellung](#phase-1-mannschaftsaufstellung)
5. [Phase 2: Tischzuordnung](#phase-2-tischzuordnung)
6. [Phase 3: Spielerzuordnung](#phase-3-spielerzuordnung)
7. [Phase 4: Runde starten](#phase-4-runde-starten)
8. [Phase 5: Spiele durchführen](#phase-5-spiele-durchführen)
9. [Phase 6: Ergebnisse bestätigen](#phase-6-ergebnisse-bestätigen)
10. [Phase 7: Spieltag abschließen](#phase-7-spieltag-abschließen)
11. [Disziplin-Parameter](#disziplin-parameter)
12. [Administration](#administration)
13. [Fehlerbehebung](#fehlerbehebung)

---

## Voraussetzungen

### Systemanforderungen

- Carambus-Server mit konfigurierter Location
- Pool-Tische mit zugewiesenen TableMonitors
- Aktive Liga mit Spielplan (GamePlan)
- Benutzer mit entsprechenden Rechten (Admin für Reset-Funktionen)

### Datenvoraussetzungen

Bevor ein Spieltag abgewickelt werden kann, müssen folgende Daten vorhanden sein:

1. **Liga** - Eine aktive Liga mit Spielplan
2. **Mannschaften** - Zwei Mannschaften (Heim und Gast)
3. **Spieler** - Spielberechtigte Spieler für beide Mannschaften
4. **Spieltag (Party)** - Ein geplanter Spieltag mit Paarung
5. **Tische** - Verfügbare Pool-Tische an der Location

---

## PartyMonitor starten

### Über die Party-Seite

1. Navigieren Sie zur **Party-Detailseite** (z.B. `/parties/332914`)
2. Klicken Sie auf **"Spieltag Monitor"**

### Über die Location-Seite

1. Öffnen Sie die **Location-Seite**
2. Unter "Aktuelle Ligabegegnungen" finden Sie den Spieltag
3. Klicken Sie auf den Spieltag-Link

### Direkter URL-Zugriff

```
http://[server]/party_monitors/[party_monitor_id]
```

---

## Workflow-Übersicht

Der PartyMonitor führt Sie durch einen strukturierten Workflow:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        SPIELTAG-WORKFLOW                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. SEEDING_MODE (Mannschaftsaufstellung)                          │
│     └─> Spieler den Mannschaften zuordnen                          │
│         └─> "Mannschaftsaufstellung abschließen"                   │
│                                                                     │
│  2. TABLE_DEFINITION_MODE (Tischzuordnung)                         │
│     └─> Tische für jede Partie auswählen                           │
│         └─> "Tischzuordnung Runde X abschließen"                   │
│                                                                     │
│  3. NEXT_ROUND_SEEDING_MODE (Spielerzuordnung)                     │
│     └─> Spieler den einzelnen Partien zuordnen                     │
│         └─> "Spielerzuordnungen Runde X abschließen"               │
│                                                                     │
│  4. PLAYING_ROUND (Runde läuft)                                    │
│     └─> "Runde X starten"                                          │
│     └─> Spiele werden auf den Scoreboards gespielt                 │
│     └─> Ergebnisse werden automatisch erfasst                      │
│         └─> "Runde X abschließen"                                  │
│                                                                     │
│  5. ROUND_RESULT_CHECKING_MODE (Ergebnisprüfung)                   │
│     └─> Ergebnisse prüfen und bestätigen                           │
│                                                                     │
│  [Wiederholung für weitere Runden]                                 │
│                                                                     │
│  6. PARTY_RESULT_CHECKING_MODE (Spieltag abschließen)              │
│     └─> "Spieltag abschließen"                                     │
│     └─> "Upload in die ClubCloud"                                  │
│                                                                     │
│  7. CLOSED (Abgeschlossen)                                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Mannschaftsaufstellung

### Ansicht

Nach dem Start des PartyMonitors sehen Sie die **Teilnehmerliste** mit:

- **Heim-Mannschaft** (links)
- **Gast-Mannschaft** (rechts)

Für jede Mannschaft gibt es zwei Listen:

| Mitspieler | Spielberechtigte |
|------------|------------------|
| Aktive Spieler für diesen Spieltag | Alle spielberechtigten Spieler der Mannschaft |

### Spieler zuordnen

1. **Spieler auswählen**: Klicken Sie auf einen Spieler in der "Spielberechtigte"-Liste
2. **Zur Mannschaft hinzufügen**: Klicken Sie auf den **←** Pfeil
3. **Spieler entfernen**: Wählen Sie einen Spieler in "Mitspieler" und klicken Sie **→**

### Abschließen

Klicken Sie auf **"Mannschaftsaufstellung abschließen"**, wenn alle Spieler zugeordnet sind.

> **Hinweis**: Die Anzahl der Mitspieler muss den Liga-Regeln entsprechen (z.B. 4 Spieler pro Mannschaft).

---

## Phase 2: Tischzuordnung

### Ansicht

Nach Abschluss der Mannschaftsaufstellung sehen Sie:

- **Runde 1** mit den geplanten Partien
- Für jede Partie ein **Tisch-Dropdown**

### Tische zuordnen

1. Wählen Sie für jede Partie einen passenden Tisch aus dem Dropdown
2. Die verfügbaren Tische werden basierend auf der Disziplin gefiltert

### Workflow-Buttons

```
[Tischzuordnung Runde 1 abschließen] => [Spielerzuordnungen Runde 1 abschließen] => [Runde 1 starten]
```

Klicken Sie auf **"Tischzuordnung Runde X abschließen"**.

---

## Phase 3: Spielerzuordnung

### Ansicht

Für jede Partie sehen Sie:

| Seqno | Disziplin | Spieler A | Ergebnis | Spieler B | Punkte | Tisch |
|-------|-----------|-----------|----------|-----------|--------|-------|
| 1 | 14/1e | [Dropdown] | : | [Dropdown] | : | Table 1 |
| 2 | 8-Ball | [Dropdown] | : | [Dropdown] | : | Table 2 |

### Spieler zuordnen

1. Wählen Sie für jede Partie den **Spieler A** (Heim) aus dem Dropdown
2. Wählen Sie den **Spieler B** (Gast) aus dem Dropdown

### Abschließen

Klicken Sie auf **"Spielerzuordnungen Runde X abschließen"**.

---

## Phase 4: Runde starten

### Vor dem Start

Überprüfen Sie die **Disziplin-Parameter** (siehe [Disziplin-Parameter](#disziplin-parameter)):

- **14/1e**: Punkteziel (z.B. 80), Aufnahmelimit
- **8-Ball**: Gewinnspiele (z.B. 6)
- **9-Ball**: Gewinnspiele (z.B. 8)
- **10-Ball**: Gewinnspiele (z.B. 7)

### Runde starten

Klicken Sie auf **"Runde X starten"**.

Nach dem Start:
- Die Scoreboards auf den zugewiesenen Tischen werden aktiviert
- Die Spieler und Parameter werden übertragen
- Der Status wechselt zu **PLAYING_ROUND**

---

## Phase 5: Spiele durchführen

### Scoreboard-Ansicht

Jedes Spiel wird auf dem zugewiesenen Tisch-Scoreboard angezeigt. Die Spieler können:

- Punkte eingeben (Klick auf Score oder Bälle)
- Spielerwechsel durchführen
- Sätze abschließen

### PartyMonitor-Übersicht

Im PartyMonitor sehen Sie den Live-Status aller Spiele:

| Symbol | Bedeutung |
|--------|-----------|
| 👁️ (grau) | Spiel läuft |
| 👁️ (gelb) | Satz beendet, wartet auf Bestätigung |
| 👁️ (grün) | Spiel beendet |
| ✓ OK? (gelb) | Ergebnis muss bestätigt werden |

### Ergebnis bestätigen

Wenn ein Spiel den Status "Satz beendet" hat:

1. Klicken Sie auf das **👁️**-Symbol, um das Scoreboard zu öffnen
2. Überprüfen Sie das Ergebnis
3. Klicken Sie auf **"✓ OK?"** im PartyMonitor, um das Ergebnis zu bestätigen

---

## Phase 6: Ergebnisse bestätigen

### Ergebnisanzeige

Nach Abschluss aller Spiele einer Runde werden die Ergebnisse angezeigt:

**Für 14.1 endlos:**
```
Punkte: 48 : 80    Aufn.: 3 / 3    HS: 32 / 58
```

**Für 8-Ball, 9-Ball, 10-Ball:**
```
2 : 6
```

### Runde abschließen

Klicken Sie auf **"Runde X abschließen"**, wenn alle Ergebnisse bestätigt sind.

---

## Phase 7: Spieltag abschließen

### Endstand

Am Ende des Spieltags wird der **Endstand** angezeigt:

```
Endstand: 3 : 5
```

### Aktionen

| Button | Funktion |
|--------|----------|
| **Spieltag abschließen** | Schließt den Spieltag ab |
| **Upload in die ClubCloud** | Überträgt die Ergebnisse zur ClubCloud |

---

## Disziplin-Parameter

### Parameter bearbeiten

Die Disziplin-Parameter können **vor dem Start der Runde** bearbeitet werden:

1. Klicken Sie auf den **Bearbeiten-Button** neben dem Parameter
2. Wählen Sie den neuen Wert aus dem Dropdown
3. Die Änderung wird sofort gespeichert

### 14.1 endlos (14/1e)

| Parameter | Optionen | Standard |
|-----------|----------|----------|
| Punkteziel | 50, 60, 70, 75, 80, 100, 125, 150 | 80 |
| Aufnahmelimit | 0 (unbegrenzt), 15, 20, 25, 30, 35, 40 | 0 |
| Erster Anstoß | Ausstoßen, Spieler A, Spieler B | Ausstoßen |

### 8-Ball

| Parameter | Optionen | Standard |
|-----------|----------|----------|
| Gewinnspiele | 4, 5, 6, 7 | 6 |
| Anstoß | Wechsel, Gewinner, Verlierer | Wechsel |
| Erster Anstoß | Ausstoßen, Spieler A, Spieler B | Ausstoßen |

### 9-Ball

| Parameter | Optionen | Standard |
|-----------|----------|----------|
| Gewinnspiele | 5, 6, 7, 8, 9 | 8 |
| Anstoß | Wechsel, Gewinner, Verlierer | Wechsel |
| Erster Anstoß | Ausstoßen, Spieler A, Spieler B | Ausstoßen |

### 10-Ball

| Parameter | Optionen | Standard |
|-----------|----------|----------|
| Gewinnspiele | 5, 6, 7, 8 | 7 |
| Anstoß | Wechsel, Gewinner, Verlierer | Wechsel |
| Erster Anstoß | Ausstoßen, Spieler A, Spieler B | Ausstoßen |

---

## Administration

### Adminrechte erforderlich

Bestimmte Funktionen erfordern Admin-Rechte:

- **Spieltag-Monitor komplett zurücksetzen**

### PartyMonitor zurücksetzen

> ⚠️ **Warnung**: Diese Aktion löscht alle Spielerzuordnungen und Ergebnisse unwiderruflich!

1. Scrollen Sie zum Ende der Seite
2. Klicken Sie auf **"Spieltag-Monitor komplett zurücksetzen (Adminrechte notwendig)"**
3. Bestätigen Sie die Sicherheitsabfrage

Nach dem Reset:
- Der PartyMonitor kehrt zum Status **SEEDING_MODE** zurück
- Alle TableMonitors werden gelöscht
- Alle Spiele und Ergebnisse werden gelöscht
- Die Spielerzuordnungen werden zurückgesetzt

### Reset über Rails Console

Falls der UI-Reset nicht funktioniert:

```ruby
pm = PartyMonitor.find([ID])
party = pm.party

# TableMonitor-Games löschen
pm.table_monitors.each { |tm| tm.game&.destroy }

# TableMonitors löschen
pm.table_monitors.destroy_all

# Party-Games löschen
party.games.destroy_all

# Test-Seedings löschen
party.seedings.where("id > 5000000").destroy_all

# PartyMonitor zurücksetzen
pm.reset_party_monitor
pm.save!
```

---

## Fehlerbehebung

### Problem: Spielergebnisse werden nicht angezeigt

**Ursache**: Die TableMonitors sind nicht korrekt mit den Party-Games verknüpft.

**Lösung**:
1. Setzen Sie den PartyMonitor zurück
2. Starten Sie den Workflow erneut

### Problem: Reset-Button funktioniert nicht

**Ursache**: Fehlende Admin-Rechte oder technischer Fehler.

**Lösung**:
1. Stellen Sie sicher, dass Sie als Admin eingeloggt sind
2. Verwenden Sie alternativ die Rails Console (siehe oben)

### Problem: Tisch-Dropdown ist leer

**Ursache**: Keine passenden Tische für die Disziplin konfiguriert.

**Lösung**:
1. Prüfen Sie die Tisch-Konfiguration in der Location
2. Stellen Sie sicher, dass Pool-Tische vorhanden sind

### Problem: Spieler können nicht zugeordnet werden

**Ursache**: Keine spielberechtigten Spieler für die Mannschaft.

**Lösung**:
1. Prüfen Sie die Seedings der Mannschaft
2. Fügen Sie ggf. Spieler zur Mannschaft hinzu

### Problem: Parameter können nicht geändert werden

**Ursache**: Der PartyMonitor ist bereits im Status PLAYING_ROUND.

**Lösung**:
- Parameter können nur in den Status SEEDING_MODE, TABLE_DEFINITION_MODE oder NEXT_ROUND_SEEDING_MODE geändert werden
- Setzen Sie ggf. den PartyMonitor zurück

---

## Glossar

| Begriff | Beschreibung |
|---------|--------------|
| **Party** | Ein Spieltag/Mannschaftskampf |
| **PartyMonitor** | Das Verwaltungstool für einen Spieltag |
| **GamePlan** | Der Spielplan einer Liga mit allen Paarungen |
| **Seeding** | Zuordnung eines Spielers zu einer Mannschaft/Turnier |
| **TableMonitor** | Das Scoreboard eines einzelnen Tisches |
| **Round** | Eine Runde innerhalb eines Spieltags |
| **ba_results** | Die Ergebnisdaten im Billard-Area-Format |

---

## Technische Referenz

### PartyMonitor States

| State | Beschreibung |
|-------|--------------|
| `seeding_mode` | Mannschaftsaufstellung |
| `table_definition_mode` | Tischzuordnung |
| `next_round_seeding_mode` | Spielerzuordnung |
| `playing_round` | Runde läuft |
| `round_result_checking_mode` | Ergebnisprüfung |
| `party_result_checking_mode` | Spieltag abschließen |
| `closed` | Abgeschlossen |

### Relevante URLs

| Seite | URL |
|-------|-----|
| Party-Details | `/parties/[party_id]` |
| PartyMonitor | `/party_monitors/[party_monitor_id]` |
| Scoreboard | `/table_monitors/[table_monitor_id]` |
| Location | `/locations/[location_id]` |

---

*Letzte Aktualisierung: Dezember 2025*

