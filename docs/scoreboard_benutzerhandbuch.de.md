# Scoreboard Benutzerhandbuch

## Übersicht

Das Carambus Scoreboard ist ein vollständiges Anzeigesystem für Billardspiele, das sowohl für Turniere als auch für Trainingsspiele verwendet werden kann. Die Bedienung ist in beiden Fällen identisch.

## Hauptfunktionen

- **Spielstandanzeige** - Echtzeit-Anzeige der Punktestände beider Spieler
- **Timer-Funktion** - Zeitmessung für Aufnahmen und Bedenkzeit
- **Einspielzeit** - Geführte Warm-up-Phase vor dem Spiel
- **Ausstoßen** - Bestimmung des Anstoßrechts
- **Disziplin-Unterstützung** - Karambolage, Pool, Snooker und weitere Disziplinen
- **Dark Mode** - Augenfreundliche Darstellung für verschiedene Lichtverhältnisse

---

## Inhaltsverzeichnis

1. [Erste Schritte](#erste-schritte)
2. [Scoreboard-Hauptansicht](#scoreboard-hauptansicht)
3. [Tastenbelegung](#tastenbelegung)
4. [Spielablauf](#spielablauf)
5. [Anzeige-Modi](#anzeige-modi)
6. [Anhang A: Training-Spiele einrichten](#anhang-a-training-spiele-einrichten)
7. [Anhang B: Undo/Edit-Funktion](#anhang-b-undoedit-funktion)

---

## Erste Schritte

### Scoreboard starten

1. **Raspberry Pi Setup**: Das Scoreboard startet automatisch beim Hochfahren des Raspberry Pi
2. **Manueller Start**: Öffnen Sie einen Browser und navigieren zu:
   ```
   http://[server-adresse]:3000/locations/[location-id]/scoreboard?sb_state=welcome
   ```
3. **Von der Location-Seite**: Klicken Sie auf den "scoreboard" Link

### Willkommensbildschirm

![Willkommensbildschirm](screenshots/scoreboard_welcome.png)

Der Willkommensbildschirm ist der Startpunkt für alle Scoreboard-Aktivitäten. Von hier aus können Sie:

- **Turnier auswählen** - Für offizielle Turniere
- **Tisch auswählen** - Für Trainingsspiele
- **Spielstände anzeigen** - Übersicht laufender Spiele

---

## Scoreboard-Hauptansicht

### Layout-Übersicht

Das Scoreboard zeigt folgende Informationen:

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Info] [Home] [Beenden]                │
│                                                       │
│  Spieler A                          Spieler B        │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │  Aktuelle       │              │  Aktuelle       ││
│  │  Aufnahme: 5    │              │  Aufnahme: --   ││
│  │                 │              │                 ││
│  │  Ziel: 50       │              │  Ziel: 50       ││
│  │  GD: 1.250      │              │  GD: 0.800      ││
│  │  HS: 8          │              │  HS: 12         ││
│  │                 │              │                 ││
│  │      45         │              │      38         ││
│  │                 │              │                 ││
│  │  Sätze: 1       │              │  Sätze: 0       ││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  [Eingabe-Bereich]                                   │
└─────────────────────────────────────────────────────┘
```

### Anzeigeelemente

#### Spielerinformationen (je Seite)

1. **Spielername** - Vollständiger Name oder Kurzname
2. **Aktuelle Aufnahme** - Punkte in der laufenden Aufnahme
3. **Ziel** - Zielpunktzahl (oder "no limit")
4. **GD (Generaldurchschnitt)** - Durchschnittliche Punkte pro Aufnahme
5. **HS (Höchstserie)** - Beste Einzelaufnahme im Spiel
6. **Gesamtpunkte** - Großer Punktestand in der Mitte
7. **Sätze** - Anzahl gewonnener Sätze (wenn Satzmodus aktiv)

#### Timer-Anzeige

Wenn ein Timer aktiv ist, erscheint eine Fortschrittsbalken-Anzeige:

```
⏱ 00:45  IIIIIIIIIIIIIIII------
        (Grün)     (Rot)
```

- **Grün**: Verbleibende Zeit im normalen Bereich
- **Rot**: Warnzeit läuft ab

#### Aktiver Spieler

Der aktive Spieler wird durch einen **grünen Rahmen** (8px breit) gekennzeichnet. Der wartende Spieler hat einen dünnen grauen Rahmen.

---

## Tastenbelegung

Das Scoreboard kann vollständig per Tastatur oder Fernbedienung gesteuert werden:

### Haupttasten

| Taste | Funktion | Beschreibung |
|-------|----------|--------------|
| **Pfeil Links** | Spieler A Punkte | Punkt für linken Spieler (im Pointer-Modus) |
| **Pfeil Rechts** | Spieler B Punkte | Punkt für rechten Spieler (im Pointer-Modus) |
| **Pfeil Oben** | Nächstes Element | Navigation nach rechts/weiter |
| **Pfeil Unten** | Aktion ausführen | Element aktivieren/bestätigen |
| **Bild Auf** | Spieler A Punkte | Alternative Taste für Spieler A |
| **Bild Ab** | Spieler B Punkte | Alternative Taste für Spieler B |
| **B** | Zurück/Weiter | Zurück (Escape) im Menü, Weiter (rechts) in Eingabefeldern |
| **Esc** | Zurück/Beenden | Zurück zum vorherigen Bildschirm |
| **Enter** | Bestätigen | Aktuelle Auswahl bestätigen |

### Spezielle Tasten

| Taste | Funktion |
|-------|----------|
| **F5** | Neustart | Scoreboard neu laden |
| **F11** | Fullscreen | Vollbildmodus ein/aus |
| **F12** | Beenden | Scoreboard beenden (Kiosk-Modus) |

### Schnelleingabe im Pointer-Modus

Im **Pointer-Modus** (Hauptmodus während des Spiels):

- **Links/Rechts-Taste**: Fügt 1 Punkt für den entsprechenden Spieler hinzu
- **B-Taste**: Wechselt zum **Timer-Bereich**
- **B-Taste** (im Timer): Wechselt zum **Eingabe-Bereich**
- **Down-Taste**: Bestätigt die Eingabe

---

## Spielablauf

### 1. Spielstart vorbereiten

Nach Auswahl eines Tisches oder Turniers erscheint der **Setup-Bildschirm**.

#### Für Turnierspiele

Die Parameter werden automatisch aus dem Turnier übernommen:
- Spieler A und B
- Disziplin (z.B. Freie Partie, 3-Band, Pool)
- Zielpunkte/Bälle
- Aufnahmen-Limit
- Sätze
- Timeout-Einstellungen

#### Für Trainingsspiele

Siehe [Anhang: Training-Spiele einrichten](#anhang-training-spiele-einrichten)

### 2. Einspielzeit (Warm-up)

![Einspielzeit](screenshots/scoreboard_warmup.png)

Beide Spieler haben Zeit zum Einspielen:

1. **Start Einspielzeit** (Spieler A) - Klicken um 5 Minuten für Spieler A zu starten
2. **Timer läuft** - Grüne Balken zeigen die verbleibende Zeit
3. **Halt** - Timer anhalten bei Bedarf
4. **Start Einspielzeit** (Spieler B) - Dann 5 Minuten für Spieler B
5. **Weiter zum Ausstoßen** - Wenn beide fertig sind

**Tasten:**
- **Enter/Down**: Start/Stopp der Einspielzeit
- **B**: Zwischen Spieler A und B wechseln

### 3. Ausstoßen (Shootout)

![Ausstoßen](screenshots/scoreboard_shootout.png)

Bestimmen Sie, wer das Spiel beginnt:

1. Beide Spieler stoßen vom Kopfende
2. Wählen Sie den Gewinner:
   - **Links-Taste** oder Button **"Spieler A"**: Spieler A gewinnt das Ausstoßen
   - **Rechts-Taste** oder Button **"Spieler B"**: Spieler B gewinnt das Ausstoßen
3. **Spiel starten** - Klicken um das eigentliche Spiel zu beginnen

**Alternative:**
- **Wechseln**: Den aktiven Spieler wechseln

### 4. Spiel läuft

![Spiel läuft](screenshots/scoreboard_playing.png)

Das Scoreboard wechselt in den **Spielmodus**.

#### Punkte eintragen

**Methode 1: Tasteneingabe (empfohlen für einfache Punkteingaben)**

- **Links-Taste**: +1 Punkt für den aktiven Spieler (links)
- **Rechts-Taste**: +1 Punkt für den aktiven Spieler (rechts, bei Spielerwechsel)
- Die Punkte werden **akkumuliert** und nach kurzer Verzögerung automatisch gespeichert
- Wenn das Ziel erreicht wird, erfolgt sofortige Validierung

**Methode 2: Zahlenfeld (für größere Punktzahlen)**

1. Drücken Sie **Down-Taste** mehrmals bis "numbers" fokussiert ist
2. Geben Sie die Punktzahl über das Zahlenfeld ein:
   - Tasten **1-9, 0** für Ziffern
   - **Del**: Letzte Ziffer löschen
   - **Esc**: Abbrechen
   - **Enter**: Punktzahl bestätigen

#### Eingabe-Buttons

Die Eingabeelemente sind in **horizontaler Reihenfolge** angeordnet:

```
[Undo] [-1] [-5] [-10] [Nächster] [+10] [+5] [+1] [Numbers]
```

- **Undo**: Aufnahmenliste bearbeiten (siehe [Anhang B: Undo/Edit-Funktion](#anhang-b-undoedit-funktion))
- **-1, -5, -10**: Punkte abziehen
- **+1, +5, +10**: Punkte hinzufügen
- **Nächster**: Spielerwechsel
- **Numbers**: Zahlenfeld öffnen für direkte Eingabe

**Navigation:**
- **B-Taste**: Bewegt sich nach rechts durch die Buttons
- **Down-Taste**: Aktiviert den fokussierten Button

> ℹ️ **Hinweis:** Die Undo/Edit-Funktion ist komplex und wird häufig missverstanden. Eine vollständige Erklärung mit Beispielen finden Sie in [Anhang B](#anhang-b-undoedit-funktion).
>
> 💡 **Geplante Verbesserung:** In einer zukünftigen Version wird die Undo-Funktion durch drei intuitivere Buttons ersetzt: **[◄ Cursor zurück] [Cursor vor ►] [✓ Fertig]**

#### Spielerwechsel

Der Spielerwechsel erfolgt entweder:
1. **Automatisch** - Wenn der aktive Spieler 0 Punkte macht
2. **Manuell** - Mit dem Button **"Nächster"** oder durch Tastatureingabe

Nach dem Wechsel:
- Der grüne Rahmen wechselt zum neuen aktiven Spieler
- Die aktuelle Aufnahme wird zurückgesetzt
- Der Timer startet neu (falls aktiv)

#### Timer-Steuerung

Wenn Timer aktiviert sind:

- **Pause** ⏸: Timer anhalten
- **Play** ▶: Timer fortsetzen
- **Stop** ⏹: Timer zurücksetzen
- **Timeout** ⏰: Timeout nehmen (begrenzte Anzahl pro Spieler, siehe Timeout-Icons ⏱)

### 5. Satzende

Wenn ein Spieler die Zielpunktzahl erreicht:

1. **Satzgewinn-Meldung** erscheint
2. Statistiken werden aktualisiert
3. Bei Mehrfachsatz-Spielen:
   - Neuer Satz beginnt automatisch
   - Satzstand wird aktualisiert
   - Anstoßrecht wechselt (je nach Einstellung)

### 6. Spielende

Wenn die erforderliche Anzahl von Sätzen gewonnen wurde oder das Spiel beendet wird:

1. **Endergebnis** wird angezeigt
2. Spielstatistiken werden gespeichert
3. Optionen:
   - **Zurück zur Übersicht**
   - **Neues Spiel starten**

---

## Anzeige-Modi

### Fullscreen-Modus

**Aktivierung:**
- Drücken Sie **F11** oder starten Sie über den entsprechenden Link
- Das Scoreboard füllt den gesamten Bildschirm

**Deaktivierung:**
- Drücken Sie erneut **F11**

Der Fullscreen-Modus ist ideal für:
- Zuschauer-Displays
- Wettkampfsituationen
- Raspberry Pi Kiosk-Modus

### Dark Mode

![Dark Mode](screenshots/scoreboard_dark.png)

**Umschalten:**
- Klicken Sie auf das **Dark Mode Icon** 🌓 in der Menüleiste
- Oder öffnen Sie das Menü und wählen Sie "Dark Mode"

**Vorteile:**
- Reduziert Augenbelastung in dunklen Räumen
- Spart Energie auf OLED-Displays
- Bessere Lesbarkeit bei schwachem Licht

Die Dark Mode Einstellung wird im Benutzerprofil gespeichert.

### Display-Only Modus

Für reine Anzeigezwecke ohne Eingabemöglichkeit:

```
/locations/[id]/scoreboard?sb_state=welcome&display_only=true
```

In diesem Modus:
- Keine Eingabeelemente sichtbar
- Nur Spielstandanzeige
- Ideal für Publikums-Bildschirme

---

## Menu und Navigation

### Hauptmenü-Icons

Die Menüleiste oben rechts enthält:

| Icon | Funktion | Beschreibung |
|------|----------|--------------|
| 🌓 | Dark Mode | Hell/Dunkel-Modus umschalten |
| ℹ️ | Info | Zur Tischübersicht wechseln |
| 🏠 | Home | Zurück zum Willkommensbildschirm |
| ⌫ | Beenden | Spiel beenden (mit Bestätigung) |

### Spiel beenden

1. Klicken Sie auf das **Beenden-Icon** ⌫ oder drücken Sie **B-Taste** im Pointer-Modus
2. **Bestätigungsdialog** erscheint:
   ```
   ┌─────────────────────────────────┐
   │  Spiel wirklich beenden?        │
   │                                 │
   │  [OK]  [Abbrechen]              │
   └─────────────────────────────────┘
   ```
3. Wählen Sie:
   - **OK**: Spiel wird beendet, zurück zur Übersicht
   - **Abbrechen**: Zurück zum Spiel

**Für Turnierspiele:**
- Das Spiel wird als "nicht gespielt" markiert
- Kann vom Turnierleiter neu gestartet werden

**Für Trainingsspiele:**
- Das Spiel wird gelöscht
- Statistiken werden nicht gespeichert

---

## Fehlerbehebung

### Scoreboard reagiert nicht

**Lösung:**
1. Drücken Sie **F5** um die Seite neu zu laden
2. Falls das nicht hilft, drücken Sie **B** um zum Pointer-Modus zurückzukehren
3. Im Notfall: Browser schließen und neu starten

### Punkte werden nicht gespeichert

**Ursache:** Netzwerkverbindung unterbrochen

**Lösung:**
1. Überprüfen Sie die Netzwerkverbindung
2. Die Punkte werden lokal gepuffert und beim nächsten Sync übertragen
3. Bei längerer Unterbrechung: Notieren Sie den Stand und korrigieren Sie manuell nach Wiederherstellung

### Timer läuft nicht

**Überprüfung:**
1. Ist der Timer für dieses Spiel aktiviert? (Timeout-Einstellung > 0)
2. Wurde der Timer gestartet? (Play-Button drücken)
3. Browser-Tab aktiv? (Manche Browser pausieren Timer im Hintergrund)

### Tastatur funktioniert nicht

**Lösung:**
1. Klicken Sie einmal in das Scoreboard-Fenster um den Fokus zu setzen
2. Prüfen Sie, ob die Tastatur korrekt angeschlossen ist
3. Bei Fernbedienung: Batterien überprüfen

### Anzeige ist verzerrt

**Lösung:**
1. Drücken Sie **F11** um Fullscreen zu aktivieren/deaktivieren
2. Browser-Zoom zurücksetzen (Strg+0 / Cmd+0)
3. Bildschirmauflösung überprüfen (mindestens 1024x768 empfohlen)

---

## Anhang A: Training-Spiele einrichten

Dieser Abschnitt erklärt, wie Sie schnell und einfach Trainingsspiele für freies Üben einrichten.

### Voraussetzungen

- Sie haben Zugang zum Scoreboard (als Scoreboard-User oder Administrator)
- Ein Tisch ist verfügbar und nicht für ein Turnier belegt

### Schritt-für-Schritt Anleitung

#### 1. Tisch auswählen

![Tischauswahl](screenshots/scoreboard_tables.png)

1. Vom **Willkommensbildschirm** aus wählen Sie **"Tische"**
2. Es erscheint eine Übersicht aller Tische der Location
3. Wählen Sie einen **freien Tisch** (grün markiert):
   - **Grün**: Tisch ist frei
   - **Gelb**: Tisch hat eine Reservierung aber kein aktives Spiel
   - **Rot**: Tisch ist belegt mit aktivem Spiel
4. Klicken Sie auf den gewünschten Tisch

#### 2. Spielform wählen

![Spielform wählen](screenshots/scoreboard_game_choice.png)

Nach Auswahl des Tisches erscheint ein Dialog zur Spielform-Auswahl:

**Karambolage:**
- **Quick Game** - Vordefinierte Schnellspiele (Freie Partie, Cadre, etc.)
- **Neue Karambol-Partie** - Individuelle Konfiguration

**Pool:**
- **Pool-Spiel** - 8-Ball, 9-Ball, 10-Ball, 14.1 endlos

**Wählen Sie die passende Kategorie.**

#### 3. Spieler auswählen

![Spieler auswählen](screenshots/scoreboard_player_selection.png)

##### Spieler A

1. Klicken Sie auf das Feld **"Spieler A"**
2. Ein Dropdown mit allen Spielern erscheint
3. Suchen Sie den Spieler:
   - **Tippen Sie** den Namen ein für schnelle Suche
   - Oder **scrollen Sie** durch die Liste
4. Wählen Sie den Spieler aus

##### Spieler B

Wiederholen Sie den Vorgang für **"Spieler B"**.

**Hinweis:** Für Trainingsspiele können Sie auch:
- Denselben Spieler für beide Seiten wählen (Solo-Training)
- Einen Dummy-Spieler anlegen (z.B. "Training")

#### 4. Spiel-Parameter konfigurieren

Je nach gewählter Spielform stehen verschiedene Parameter zur Verfügung:

##### Karambolage - Freie Partie

![Freie Partie Setup](screenshots/scoreboard_free_game_setup.png)

**Grundeinstellungen:**

| Parameter | Beschreibung | Beispiel |
|-----------|--------------|----------|
| **Disziplin** | Spielart (Freie Partie, Cadre, Dreiband, etc.) | "Freie Partie" |
| **Zielpunkte** | Punkte zum Gewinnen | 50, 100, 200 |
| **Aufnahmen-Limit** | Maximale Aufnahmen (optional) | 50, 100, "kein Limit" |
| **Sätze** | Anzahl zu spielender Sätze | 1, 3, 5 |

**Erweiterte Einstellungen:**

| Parameter | Beschreibung | Standard |
|-----------|--------------|----------|
| **Timeout** | Bedenkzeit pro Aufnahme (Sekunden) | 45 |
| **Timeouts pro Satz** | Anzahl erlaubter Timeouts | 1 |
| **Warnzeit** | Warnung vor Ablauf (Sekunden) | 10 |
| **Anstoß wechselt mit** | Wann wechselt das Anstoßrecht? | "Satz" |
| **Farbe bleibt bei Satz** | Spielerfarben bleiben beim Satzwechsel? | Nein |
| **Feste Anzeige links** | Linker Spieler bleibt links? | Nein |
| **Überlauf erlauben** | Über Zielpunkte hinaus zählen? | Nein |
| **Nachstoß erlauben** | Nachstoß bei Zielballberührung? | Ja |

##### Karambolage - Quick Game (Schnellstart)

![Quick Game](screenshots/scoreboard_quick_game.png)

Für schnelles Starten ohne viele Einstellungen:

1. **Wählen Sie ein Preset:**
   - **Freie Partie 50** - Klassisch zu 50 Punkten
   - **Freie Partie 100** - Standard-Trainingsspiel
   - **Cadre 47/2 100** - Cadre-Training
   - **Dreiband 50** - 3-Band zu 50
   - **Einband 100** - 1-Band zu 100

2. Die Parameter sind vorkonfiguriert, können aber noch angepasst werden

3. **Spiel starten** - Direkt loslegen

##### Pool-Billard

![Pool Setup](screenshots/scoreboard_pool_setup.png)

**Disziplinen:**
- **8-Ball** - Klassisches 8-Ball
- **9-Ball** - 9-Ball
- **10-Ball** - 10-Ball
- **14.1 endlos** - Straight Pool

**Parameter:**

| Parameter | Beschreibung | Beispiel |
|-----------|--------------|----------|
| **Disziplin** | Pool-Variante | "9-Ball" |
| **Sätze zu gewinnen** | Race to X | 3, 5, 7 |
| **Punkte/Bälle** | Zielbälle (14.1) oder Sets | 100 (14.1) |
| **Erster Anstoß** | Wer stößt zuerst an? | "Ausstoßen" |
| **Nächster Anstoß** | Wer stößt nach Satz an? | "Gewinner", "Verlierer", "Abwechselnd" |

#### 5. Spiel starten

Nachdem alle Parameter gesetzt sind:

1. Überprüfen Sie nochmals die Einstellungen
2. Klicken Sie auf **"Spiel starten"** oder **"Weiter"**
3. Das Scoreboard wechselt zur **Einspielzeit**

#### 6. Einspielzeit und Ausstoßen

Siehe [Spielablauf - Einspielzeit](#2-einspielzeit-warm-up) und [Ausstoßen](#3-ausstoßen-shootout)

### Quick-Tipps für Trainingsspiele

**Tipp 1: Standard-Spieler anlegen**

Legen Sie einen Dummy-Spieler "Training" an für schnelles Setup:
1. Gehen Sie zu **Spieler** > **Neu**
2. Name: "Training"
3. Vorname: "Solo"
4. Verein: Ihr Club

**Tipp 2: Favoriten-Setups**

Häufig verwendete Konfigurationen:
- **Freie Partie 100**: Standard-Übungsspiel
- **Dreiband 50**: Kurzes 3-Band-Training
- **Cadre 47/2**: Positionsspiel-Training

**Tipp 3: Timer deaktivieren**

Für entspanntes Training:
- Setzen Sie **Timeout auf 0**
- So gibt es keine Zeitbegrenzung

**Tipp 4: Überlauf erlauben**

Für kontinuierliches Training:
- Aktivieren Sie **"Überlauf erlauben"**
- So können Sie über die Zielpunkte hinaus spielen

**Tipp 5: Spiel schnell beenden**

Nach dem Training:
1. **B-Taste** oder **Beenden-Icon** ⌫
2. **OK** bestätigen
3. Tisch ist sofort wieder frei

### Unterschiede: Training vs. Turnier

| Aspekt | Training | Turnier |
|--------|----------|---------|
| **Spieler-Auswahl** | Frei wählbar | Vorgegeben durch Spielplan |
| **Parameter** | Frei konfigurierbar | Vorgegeben durch Turnierregeln |
| **Spielbeendigung** | Jederzeit möglich | Nur nach Spielende |
| **Statistiken** | Nicht gespeichert | Vollständig erfasst |
| **Anstoßrecht** | Frei wählbar | Gemäß Turniermodus |

### Häufige Fragen (FAQ)

**F: Kann ich ein Trainingsspiel pausieren?**

A: Ja, klicken Sie auf das **Home-Icon** 🏠. Das Spiel bleibt im Hintergrund aktiv. Wählen Sie den Tisch erneut aus um fortzufahren.

**F: Werden Trainings-Statistiken gespeichert?**

A: Nein, Trainingsspiele werden nicht in die offizielle Statistik aufgenommen. Für statistische Erfassung sollten Sie ein offizielles Spiel oder Turnier anlegen.

**F: Kann ich während eines Trainings die Parameter ändern?**

A: Nein, die Parameter sind nach Spielstart fixiert. Sie müssen das Spiel beenden und neu starten um Änderungen vorzunehmen.

**F: Was passiert, wenn ich den Browser schließe?**

A: Das Spiel läuft auf dem Server weiter. Öffnen Sie den Browser erneut und navigieren Sie zum Tisch um fortzufahren. In der Zwischenzeit gespeicherte Punkte bleiben erhalten.

**F: Kann ich zwei Trainingsspiele gleichzeitig auf verschiedenen Tischen laufen lassen?**

A: Ja, jeder Tisch kann ein eigenes Spiel haben. Starten Sie einfach für jeden Tisch ein separates Spiel.

---

## Tastatur-Referenz (Übersicht)

### Haupttastatur-Funktionen

| Modus | Taste | Aktion |
|-------|-------|--------|
| **Pointer** | ← / Bild↑ | Spieler A +1 Punkt |
| **Pointer** | → / Bild↓ | Spieler B +1 Punkt |
| **Pointer** | B | Timer-Bereich |
| **Pointer** | ↓ / Enter | Pointer-Element aktivieren |
| **Timer** | B | Eingabe-Bereich |
| **Timer** | ↓ / Enter | Timer-Aktion |
| **Eingabe** | B | Nächstes Element (→) |
| **Eingabe** | ← | Vorheriges Element (←) |
| **Eingabe** | ↓ / Enter | Element aktivieren |
| **Numbers** | 0-9 | Ziffer eingeben |
| **Numbers** | Del | Letzte Ziffer löschen |
| **Numbers** | Esc | Abbrechen |
| **Numbers** | ↓ / Enter | Bestätigen |
| **Alle** | Esc / B | Zurück / Beenden |
| **Alle** | F5 | Neu laden |
| **Alle** | F11 | Fullscreen |
| **Alle** | F12 | Exit (Kiosk) |

### Undo/Edit-Funktionen (Aufnahmenliste bearbeiten)

| Button | Funktion | Beschreibung |
|--------|----------|--------------|
| **Undo** | Cursor ← | Cursor eine Aufnahme zurück bewegen (Punkte bleiben unverändert) |
| **Nächster** | Cursor → | Cursor eine Aufnahme vorwärts bewegen (bei letzter Position: Spielerwechsel) |
| **+1, +5, +10** | Punkte + | Punkte an aktueller Cursor-Position erhöhen |
| **-1, -5, -10** | Punkte - | Punkte an aktueller Cursor-Position reduzieren |

**Wichtig:** Nach Bearbeitung mit Undo immer mit "Nächster" zur aktuellen Aufnahme zurückkehren!

---

## Anhang B: Undo/Edit-Funktion (Aufnahmenliste bearbeiten)

⚠️ **Häufig missverstanden:** Die "Undo"-Taste ist **keine** einfache Rückgängig-Funktion, sondern ein mächtiges **Bearbeitungswerkzeug** für die Aufnahmenliste!

**Ausnahme:** Bei Pool-Billard funktioniert Undo tatsächlich als echte Rückgängig-Funktion.

### Wie die Aufnahmenliste funktioniert

Unter den Hauptpunkteständen beider Spieler sehen Sie die **Aufnahmenliste**:

```
Spieler A                    Spieler B
   45                           38
┌─────────────┐            ┌─────────────┐
│ [5][8][12][│20│]         │ [6][7][10][│15│] │  ← Aufnahmen
└─────────────┘            └─────────────┘
   ▲                          ▲
   Erste                      Aktuell editierbar
   Aufnahme                   (umrandet = Cursor)
```

- **Erste Aufnahme** steht links
- **Aktuelle Aufnahme** ist rechts und durch einen Rahmen markiert (Cursor)
- Jede Zahl zeigt die Punkte in dieser Aufnahme

### Cursor-Navigation

**Mit Undo (Cursor nach links):**

1. Drücken Sie **Undo**
2. Der Cursor springt zur **vorherigen Aufnahme** des aktuellen Spielers
3. Die Punktzahlen bleiben **unverändert**

**Mit Nächster/Wechsel (Cursor nach rechts):**

1. Drücken Sie **Nächster**
2. Der Cursor springt zur **nächsten Aufnahme** (abwechselnd A/B)
3. Wenn Sie bei der letzten Aufnahme sind, wird ein Spielerwechsel ausgeführt

### Punkte bearbeiten

Wenn der Cursor auf einer Aufnahme steht:

1. Verwenden Sie **-1, -5, -10** um Punkte zu reduzieren
2. Verwenden Sie **+1, +5, +10** um Punkte zu erhöhen
3. Die Gesamtpunktzahl wird **automatisch neu berechnet**

### Schritt-für-Schritt Beispiel 1: Fehler in vorheriger Aufnahme korrigieren

**Situation:**
- Spieler A hat gerade 8 Punkte gemacht
- Sie bemerken, dass in der Aufnahme davor 12 statt 10 Punkte eingetragen wurden

**Lösung:**

```
Ausgangssituation:
Spieler A: [5][10][│8│]  (Cursor auf aktueller Aufnahme)
Gesamtpunktzahl: 23

Schritt 1: Undo drücken
Spieler A: [5][│10│][8]  (Cursor auf vorheriger Aufnahme)

Schritt 2: Zweimal "-1" drücken
Spieler A: [5][│8│][8]   (10 → 8)
Gesamtpunktzahl: 21 ✓    (automatisch korrigiert)

Schritt 3: "Nächster" drücken
Spieler A: [5][8][│8│]   (Cursor zurück zur aktuellen Aufnahme)
```

**Wichtig:** Nach der Bearbeitung **MUSS** man mit "Nächster" zurück zur aktuellen Aufnahme navigieren!

### Schritt-für-Schritt Beispiel 2: Mehrere Aufnahmen zurück

**Situation:**
- Spieler A: [6][8][10][│12│]
- Sie wollen die zweite Aufnahme (8) auf 7 korrigieren

**Lösung:**

```
Ausgangssituation:
Spieler A: [6][8][10][│12│]  (Cursor auf Position 4)
Gesamtpunktzahl: 36

Schritt 1: Undo drücken (1x)
Spieler A: [6][8][│10│][12]  (Cursor auf Position 3)

Schritt 2: Undo drücken (2x)
Spieler A: [6][│8│][10][12]  (Cursor auf Position 2)

Schritt 3: "-1" drücken
Spieler A: [6][│7│][10][12]  (8 → 7)
Gesamtpunktzahl: 35 ✓

Schritt 4: "Nächster" drücken (1x)
Spieler A: [6][7][│10│][12]  (Cursor auf Position 3)

Schritt 5: "Nächster" drücken (2x)
Spieler A: [6][7][10][│12│]  (Cursor zurück auf Position 4)
```

### Schritt-für-Schritt Beispiel 3: Beide Spieler bearbeiten

**Situation:**
- Spieler A hat gerade gespielt: [5][│8│]
- Spieler B soll jetzt spielen: [6][│--│]
- Sie müssen Spieler A's erste Aufnahme von 5 auf 6 korrigieren

**Lösung:**

```
Ausgangssituation:
Spieler A: [5][│8│]  (Cursor hier)
Spieler B: [6][--]

Schritt 1: Undo drücken
Spieler A: [│5│][8]  (Cursor auf Position 1)

Schritt 2: "+1" drücken
Spieler A: [│6│][8]  (5 → 6)

Schritt 3: "Nächster" drücken (1x)
Spieler A: [6][│8│]  (zurück zu Position 2)

Schritt 4: "Nächster" drücken (2x) - führt Spielerwechsel aus
Spieler A: [6][8]
Spieler B: [6][│--│]  ✓ (bereit für neue Aufnahme)
```

### Wichtige Hinweise

**✅ DO:**
- Cursor bewusst navigieren
- Nach Bearbeitung **immer** zurück zur aktuellen Aufnahme
- Änderungen visuell überprüfen (Gesamtpunktzahl)

**❌ DON'T:**
- Cursor irgendwo "stehen lassen"
- Ohne Navigation direkt weiterspielen
- Blindlings "Undo" mehrfach drücken

### Häufige Fehler

**Fehler 1: "Ich habe Undo gedrückt, aber nichts passiert"**

→ Sie haben die Punkte nicht geändert! Undo **verschiebt nur den Cursor**, die Punkte bleiben gleich.

**Lösung:** Nach Undo die Punkte mit +/- Tasten anpassen.

**Fehler 2: "Nach Undo zeigt die Punktzahl falsche Werte"**

→ Der Cursor steht noch auf einer alten Aufnahme, nicht auf der aktuellen.

**Lösung:** Mit "Nächster" zurück zur aktuellen Aufnahme navigieren.

**Fehler 3: "Ich komme nicht mehr zurück"**

→ Sie haben den Überblick verloren, wo der Cursor steht.

**Lösung:** 
1. Schauen Sie auf die Aufnahmenliste - die umrandete Zahl zeigt den Cursor
2. Drücken Sie "Nächster" bis Sie wieder bei der letzten Aufnahme sind
3. Im Notfall: F5 drücken (Seite neu laden)

### Wann verwenden?

**Typische Anwendungsfälle:**

✅ **Tippfehler korrigieren**
- Sie haben versehentlich 8 statt 6 eingegeben

✅ **Nachträglich Punkte ändern**
- Schiedsrichterentscheidung korrigiert eine frühere Aufnahme

✅ **Diskussionen klären**
- Spieler sind sich uneinig über eine frühere Aufnahme
- Sie können zurückgehen und korrigieren

**Nicht verwenden für:**

❌ **Aktuelle Aufnahme ändern**
- Verwenden Sie stattdessen einfach +/- Buttons

❌ **Spieler wechseln**
- Verwenden Sie den "Nächster" Button

### Zusammenfassung

| Taste | Funktion | Wirkung auf Cursor | Wirkung auf Punkte |
|-------|----------|-------------------|-------------------|
| **Undo** | Cursor zurück | ← Eine Position zurück | Keine |
| **Nächster** | Cursor vor / Spielerwechsel | → Eine Position vor | Keine |
| **+1, +5, +10** | Punkte hinzufügen | Keine | Erhöht Wert an Cursor-Position |
| **-1, -5, -10** | Punkte abziehen | Keine | Reduziert Wert an Cursor-Position |

**Merksatz:** 
> Undo = Cursor bewegen, +/- = Punkte ändern, Nächster = zurück zur aktuellen Aufnahme

### 💡 Vorschlag für zukünftige Verbesserung

#### Lösung 1: Spielprotokoll-Modal (EMPFOHLEN)

Die aktuelle Undo/Edit-Funktion ist komplex und fehleranfällig. Eine viel bessere Lösung wäre ein **Spielprotokoll-Modal**:

**Konzept:**

Button "Undo" wird ersetzt durch **[📋 Spielprotokoll]**

Beim Klick öffnet sich ein Modal mit vollständiger Übersicht:

```
┌─────────────────── Spielprotokoll ───────────────────┐
│                                                       │
│  Spieler A: Max Mustermann    Spieler B: Hans Test  │
│                                                       │
│  Aufn. │ Punkte │ Total     Aufn. │ Punkte │ Total  │
│  ──────┼────────┼─────     ──────┼────────┼───── │
│    1   │   5    │   5         1   │   6    │   6    │
│    2   │   8    │  13         2   │   7    │  13    │
│    3   │  12    │  25         3   │  10    │  23    │
│    4   │  20    │  45         4   │  15    │  38    │
│                                                       │
│  [Bearbeiten] [Fertig] [Drucken]                    │
└───────────────────────────────────────────────────────┘
```

**Im Bearbeiten-Modus:**

```
┌─────────────────── Spielprotokoll (Bearbeiten) ──────┐
│                                                       │
│  Aufn. │ Punkte      │ Total     Aufn. │ Punkte │... │
│  ──────┼─────────────┼─────     ──────┼────────┼──  │
│    1   │  5 [↑][↓]  │   5         1   │   6 [↑][↓] │
│    2   │  8 [↑][↓]  │  13         2   │   7 [↑][↓] │
│    3   │ 12 [↑][↓]  │  25         3   │  10 [↑][↓] │
│        │  [+ Aufnahme einfügen]                       │
│                                                       │
│  [Speichern] [Abbrechen]                             │
└───────────────────────────────────────────────────────┘
```

**Vorteile:**

✅ **Übersichtlich**
- ALLE Aufnahmen auf einen Blick sichtbar
- Keine versteckte Cursor-Navigation
- Gesamtverlauf sofort erkennbar

✅ **Intuitiv**
- Tabellenformat kennt jeder
- Klarer Edit-Modus mit Ein/Aus
- Pfeile ↑↓ sind selbsterklärend

✅ **Sicher**
- Versehentliche Änderungen ausgeschlossen (readonly im Ansicht-Modus)
- Klare Trennung: Ansehen vs. Bearbeiten
- "Fertig" beendet eindeutig und kehrt zum Spiel zurück

✅ **Mächtig**
- **Zeilen einfügen** für vergessene Spielerwechsel!
- Komplexe Korrekturen möglich
- Mehrere Fehler gleichzeitig korrigieren

✅ **Professionell**
- **Druckfunktion** für Spielprotokoll
- Dokumentation des Spielverlaufs
- Archivierung für Turniere

**Funktionen:**

1. **Ansicht-Modus (Standard)**
   - Readonly-Tabelle
   - Scrollbar bei vielen Aufnahmen
   - Aktuelle Aufnahme hervorgehoben
   - Buttons: [Bearbeiten] [Fertig] [Drucken]

2. **Bearbeiten-Modus**
   - Alle Punkte mit [↑] [↓] Buttons
   - Totals werden automatisch neu berechnet
   - [+ Aufnahme einfügen] zwischen Zeilen
   - Buttons: [Speichern] [Abbrechen]

3. **Drucken**
   - Druckoptimiertes Layout
   - Datum, Spieler, Endergebnis
   - Optional: PDF-Export

**Anwendungsfall: Vergessener Spielerwechsel**

Problem: Nach Aufnahme 3 von Spieler A wurde vergessen zu wechseln, er hat direkt Aufnahme 4 gespielt.

Lösung:
1. [📋 Spielprotokoll] öffnen
2. [Bearbeiten] klicken
3. Zwischen Zeile 3 und 4 von Spieler A: [+ Aufnahme einfügen]
4. Neue Leerzeile wird eingefügt
5. Punkte von Aufnahme 4 in die neue Zeile verschieben
6. [Speichern]

Dies wäre eine vollständige Neuentwicklung, aber **deutlich benutzerfreundlicher** als die aktuelle Lösung.

---

#### Lösung 2: Drei separate Buttons (Alternative)

Falls die Modal-Lösung zu aufwendig ist, wäre eine einfachere Verbesserung:

Die aktuelle Button-Belegung ist verwirrend, weil:
- "Undo" klingt wie "Rückgängig", ist aber "Cursor zurück"
- "Nächster" hat zwei Bedeutungen: "Cursor vor" UND "Spielerwechsel"

**Vereinfachte Lösung:**

Drei separate, eindeutige Buttons:

```
[◄ Cursor zurück] [Cursor vor ►] [✓ Fertig]
```

**Vorteile:**
- ✅ Jeder Button hat **genau eine** Funktion
- ✅ Selbsterklärende Beschriftung
- ✅ "✓ Fertig" macht klar: "Bearbeitung abschließen"
- ✅ Benutzer können nicht mehr "steckenbleiben"

**Nachteil gegenüber Spielprotokoll-Modal:**
- ❌ Keine Gesamtübersicht
- ❌ Immer noch versteckte Navigation
- ❌ Keine Druckfunktion
- ❌ Keine Möglichkeit Zeilen einzufügen

---

**Empfehlung:** Lösung 1 (Spielprotokoll-Modal) ist deutlich besser und löst alle Probleme grundlegend.

---

## Support und Hilfe

Bei Problemen oder Fragen:

1. **Dokumentation**: Lesen Sie diese Anleitung gründlich
2. **Administrator kontaktieren**: Ihr Club-Administrator kann helfen
3. **GitHub Issues**: [https://github.com/GernotUllrich/carambus/issues](https://github.com/GernotUllrich/carambus/issues)

---

## Version

Dieses Handbuch gilt für Carambus Version 2.0 und höher.

Letzte Aktualisierung: November 2025

