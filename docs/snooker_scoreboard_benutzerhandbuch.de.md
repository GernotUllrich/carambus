# Snooker Scoreboard Benutzerhandbuch

## Übersicht

Das Carambus Snooker Scoreboard ist ein vollständiges Anzeigesystem für Snooker-Spiele, das sowohl für Turniere als auch für Trainingsspiele verwendet werden kann. Es unterstützt die klassische Snooker-Disziplin mit Frame-Zählung.

## Hauptfunktionen

- **Frame-Anzeige** - Echtzeit-Anzeige der gewonnenen Frames beider Spieler
- **Break-Anzeige** - Aktuelle Break-Punkte des aktiven Spielers
- **High Break (HB)** - Höchster Break jedes Spielers im Spiel
- **Frame-Verwaltung** - Automatische Frame-Zählung (Best of 3, 5, 7, 9)
- **Ball-Wert-Buttons** - Farbcodierte Buttons für alle Snooker-Bälle (Rot=1, Gelb=2, Grün=3, Braun=4, Blau=5, Pink=6, Schwarz=7)
- **Dark Mode** - Augenfreundliche Darstellung für verschiedene Lichtverhältnisse

---

## Inhaltsverzeichnis

1. [Erste Schritte](#erste-schritte)
2. [Snooker-Regeln im Überblick](#snooker-regeln-im-überblick)
3. [Scoreboard-Hauptansicht](#scoreboard-hauptansicht)
4. [Spielablauf](#spielablauf)
5. [Tastenbelegung](#tastenbelegung)
6. [Quickstart-Spiele](#quickstart-spiele)
7. [Fehlerbehebung](#fehlerbehebung)

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

Der Willkommensbildschirm ist der Startpunkt für alle Scoreboard-Aktivitäten. Von hier aus können Sie:

- **Turnier auswählen** - Für offizielle Snooker-Turniere
- **Tisch auswählen** - Für Trainingsspiele
- **Spielstände anzeigen** - Übersicht laufender Spiele

### Tischübersicht

Nach Auswahl von "Training" erscheint die Tischübersicht mit allen verfügbaren Pool- und Snooker-Tischen:

- **Blaue Buttons**: Freie Tische
- **Spielernamen**: Tische mit laufenden Spielen

---

## Snooker-Regeln im Überblick

### Grundregeln

Snooker wird mit 22 Bällen gespielt:

**Rote Bälle:**
- 15 rote Bälle (jeder zählt 1 Punkt)
- Zu Beginn des Frames werden alle 15 roten Bälle aufgestellt

**Farbige Bälle:**
- Gelb (2 Punkte)
- Grün (3 Punkte)
- Braun (4 Punkte)
- Blau (5 Punkte)
- Pink (6 Punkte)
- Schwarz (7 Punkte)

**Weißer Ball:**
- Die weiße Spielkugel (Cue Ball)

### Spielablauf

1. **Rote Phase**: Der Spieler muss zuerst einen roten Ball versenken (1 Punkt)
2. **Farbige Phase**: Nach einem roten Ball muss eine farbige Ball versenkt werden
3. **Wiederholung**: Rot → Farbe → Rot → Farbe ... bis alle roten Bälle versenkt sind
4. **Farbige Phase**: Nach den roten Bällen müssen die farbigen Bälle in aufsteigender Reihenfolge versenkt werden: Gelb → Grün → Braun → Blau → Pink → Schwarz

### Frame gewinnen

Ein Frame wird gewonnen, wenn:
- Ein Spieler alle Bälle versenkt hat (Maximum Break: 147 Punkte)
- Der Gegner aufgibt
- Der Gegner mehr Fouls begeht als Punkte erzielt hat

### Match gewinnen

Ein Match wird gewonnen, wenn ein Spieler die erforderliche Anzahl von Frames gewinnt:
- **Best of 3**: 2 Frames gewinnen
- **Best of 5**: 3 Frames gewinnen
- **Best of 7**: 4 Frames gewinnen
- **Best of 9**: 5 Frames gewinnen

### Fouls

Häufige Fouls im Snooker:
- **Ball nicht getroffen**: Mindestens 4 Punkte Strafe (oder Wert des Balles, wenn höher)
- **Falsche Ball getroffen**: Strafe entspricht dem Wert des falschen Balles
- **Ball versenkt, aber falscher Ball**: Strafe entspricht dem Wert des versenkten Balles
- **Weißer Ball versenkt**: Mindestens 4 Punkte Strafe

**Wichtig**: Bei einem Foul erhält der Gegner die Strafe als Punkte gutgeschrieben.

---

## Scoreboard-Hauptansicht

### Layout

```
┌─────────────────────────────────────────────────────┐
│  [Dark Mode] [Undo] [Home] [Beenden]                │
│                                                       │
│  Spieler A (aktiv)                  Spieler B        │
│  ┌─────────────────┐              ┌─────────────────┐│
│  │  Break: 24      │              │  Break: --     ││
│  │                 │              │                 ││
│  │  Frames: 1 / 3  │              │  Frames: 0 / 3 ││
│  │  HB: 45         │              │  HB: 32         ││
│  │                 │              │                 ││
│  │      1  ←───────│──────────────│───── 0          ││
│  │   (klick=+1)    │              │  (klick=wechsel)││
│  └─────────────────┘              └─────────────────┘│
│                                                       │
│  Frame 1                                            │
│  Best of 5                                          │
│                                                       │
│  [Undo] [1] [2] [3] [4] [5] [6] [7] [Calc]          │
│  (Rot)(Gelb)(Grün)(Braun)(Blau)(Pink)(Schwarz)      │
└─────────────────────────────────────────────────────┘
```

**Klickbare Bereiche:**
- **Frame-Score des aktiven Spielers** (1): Klick = +1 Punkt zum aktuellen Break
- **Frame-Score des inaktiven Spielers** (0): Klick = Spielerwechsel

### Anzeigeelemente

#### Spielerinformationen (je Seite)

1. **Spielername** - Vollständiger Name oder Kurzname
2. **Aktueller Break** - Punkte in der laufenden Aufnahme (rot hervorgehoben, nur bei aktivem Spieler)
3. **Frames** - Gewonnene Frames / Frames zum Gewinnen (z.B. "1 / 3" bedeutet 1 Frame gewonnen, 3 Frames zum Sieg)
4. **HB (High Break)** - Höchster Break im aktuellen Spiel
5. **Frame-Score** - Große Anzeige der gewonnenen Frames in der Mitte

#### Zentrale Anzeige

- **Frame-Nummer** - Aktueller Frame (z.B. "Frame 1")
- **Match-Format** - Best of X (z.B. "Best of 5")
- **Turnier-Informationen** - Turniername, Runde, Spielname (falls im Turnier)

#### Ball-Wert-Buttons (nur im Vollbildmodus)

Die untere Leiste zeigt farbcodierte Buttons für alle Snooker-Bälle:

- **Rot (1 Punkt)** - Rote Bälle
- **Gelb (2 Punkte)** - Gelber Ball
- **Grün (3 Punkte)** - Grüner Ball
- **Braun (4 Punkte)** - Brauner Ball
- **Blau (5 Punkte)** - Blauer Ball
- **Pink (6 Punkte)** - Pinker Ball
- **Schwarz (7 Punkte)** - Schwarzer Ball
- **Calculator** - Direkte Zahlen-Eingabe für größere Breaks

---

## Spielablauf

### 1. Tisch auswählen

1. Vom **Willkommensbildschirm** wählen Sie **"Tische"**
2. Wählen Sie einen **Snooker-Tisch** (erkennbar am Tischtyp)
3. Klicken Sie auf den gewünschten Tisch

### 2. Spielform wählen

Nach Auswahl des Tisches erscheinen die Snooker-Optionen:

**Quickstart-Buttons:**
- **Best of 3** (2 Frames zum Gewinn)
- **Best of 5** (3 Frames zum Gewinn)
- **Best of 7** (4 Frames zum Gewinn)
- **Best of 9** (5 Frames zum Gewinn)

**Oder:** Detaillierte Konfiguration über "Neue Snooker-Partie"

### 3. Spieler auswählen

- **Spieler-Auswahl**: Wählen Sie beide Spieler aus der Liste
- **Neuer Spieler**: Registrieren Sie einen neuen Gastspieler

### 4. Spielparameter einstellen

- **Frames**: Wählen Sie das Match-Format (Best of 3/5/7/9)
- **Spielzeit**: Einstellen der maximalen Spielzeit pro Frame (optional)
- **Warnzeit**: Einstellen der Warnzeit vor Ablauf (optional)
- **Erster Anstoß**: Ausstoßen, Spieler A oder Spieler B

### 5. Spiel starten

Klicken Sie auf **"Start Game"** - das Scoreboard zeigt den Spielstand an.

---

## Tastenbelegung

### Punkte eintragen

**Methode 1: Ball-Wert-Buttons (empfohlen)**

Klicken Sie auf den farbcodierten Button, der dem versenkten Ball entspricht:

- **Rot-Button**: Roter Ball versenkt → +1 Punkt
- **Gelb-Button**: Gelber Ball versenkt → +2 Punkte
- **Grün-Button**: Grüner Ball versenkt → +3 Punkte
- **Braun-Button**: Brauner Ball versenkt → +4 Punkte
- **Blau-Button**: Blauer Ball versenkt → +5 Punkte
- **Pink-Button**: Pinker Ball versenkt → +6 Punkte
- **Schwarz-Button**: Schwarzer Ball versenkt → +7 Punkte

**Beispiel:**
- Spieler versenkt einen roten Ball → Klick auf **Rot-Button (1)** → Break: +1
- Spieler versenkt danach den blauen Ball → Klick auf **Blau-Button (5)** → Break: +6 (1+5)
- Spieler versenkt weiteren roten Ball → Klick auf **Rot-Button (1)** → Break: +7 (1+5+1)

**Methode 2: Klick auf den eigenen Frame-Score (+1 Punkt)**

Für einzelne Punkte können Sie direkt auf den **Frame-Score des aktiven Spielers** klicken:

- Klicken Sie auf die große Frame-Zahl des aktiven Spielers
- Jeder Klick fügt **+1 Punkt** zum aktuellen Break hinzu
- Ideal für schnelle Einzelpunkt-Eingaben (z.B. rote Bälle)

**Methode 3: Direkte Eingabe (Calculator)**

Für größere Breaks können Sie die Calculator-Funktion verwenden:

- Klicken Sie auf den **Calculator-Button**
- Geben Sie die Gesamtpunktzahl des Breaks ein
- Das System übernimmt die Punkte automatisch

### Spielerwechsel

**Methode 1: Klick auf den Frame-Score des anderen Spielers**

Der einfachste Weg zum Spielerwechsel:

- Klicken Sie auf die **Frame-Zahl des nicht-aktiven Spielers**
- Der Spieler wechselt sofort
- Der aktuelle Break wird beendet und zum Frame-Score hinzugefügt
- Der grüne Rahmen wechselt zum neuen aktiven Spielers
- Der Break-Zähler wird zurückgesetzt

**Methode 2: Automatischer Wechsel**

Nach einem Foul oder wenn der Spieler keine Punkte erzielt:
- Der aktive Spieler wechselt automatisch
- Der grüne Rahmen zeigt den neuen aktiven Spieler

> **Tipp:** Der Klick auf den gegnerischen Frame-Score ist die schnellste Methode für den Spielerwechsel und wird von erfahrenen Schiedsrichtern bevorzugt.

### Frame beenden

Ein Frame endet automatisch, wenn:
- Ein Spieler alle Bälle versenkt hat
- Ein Spieler aufgibt (über Menü)
- Das Maximum erreicht wurde

Nach Frame-Ende:
- Der Frame-Score wird aktualisiert
- Der Frame-Zähler erhöht sich
- Das System zeigt "Frame Over" an
- Klicken Sie auf "Next Frame" um fortzufahren

### Match-Ende

Das Match endet automatisch, wenn ein Spieler die erforderliche Anzahl von Frames gewonnen hat:

- **Best of 3**: 2 Frames gewonnen
- **Best of 5**: 3 Frames gewonnen
- **Best of 7**: 4 Frames gewonnen
- **Best of 9**: 5 Frames gewonnen

Nach Match-Ende:
- Das System zeigt das Endergebnis an
- Sie können das Protokoll einsehen
- Das Spiel kann beendet werden

### Fouls eintragen

Für Fouls gibt es verschiedene Möglichkeiten:

**Option 1: Punkte abziehen**
- Verwenden Sie die **Undo-Funktion** oder **-1/-5/-10 Buttons** um Punkte abzuziehen
- Danach den **Spielerwechsel** durchführen

**Option 2: Direkte Eingabe**
- Verwenden Sie den **Calculator** um die korrigierte Punktzahl einzugeben
- Danach den **Spielerwechsel** durchführen

**Wichtig**: Bei einem Foul erhält der Gegner die Strafe als Punkte. Dies muss manuell über den Calculator oder die Punkt-Buttons eingegeben werden.

### Beispiel-Spielablauf

**Frame 1 - Best of 5:**

1. **Start**: Beide Spieler haben 0 Frames, Frame 1 beginnt
2. **Spieler A** versenkt roten Ball → Klick auf **Rot-Button (1)** → Break: 1
3. **Spieler A** versenkt blauen Ball → Klick auf **Blau-Button (5)** → Break: 6
4. **Spieler A** versenkt weiteren roten Ball → Klick auf **Rot-Button (1)** → Break: 7
5. **Spieler A** verschießt → Klick auf **Frame-Score von Spieler B (0)** → Spielerwechsel
   - Break von 7 wird zum Frame-Score hinzugefügt (wenn Frame gewonnen)
6. **Spieler B** versenkt roten Ball → Klick auf **Rot-Button (1)** → Break: 1
7. **Spieler B** verschießt → Klick auf **Frame-Score von Spieler A** → Spielerwechsel
8. ... (Spiel läuft weiter)
9. **Spieler A** gewinnt Frame 1 → Frame-Score: 1:0
10. **Frame 2** beginnt automatisch
11. ... (weitere Frames)
12. **Spieler A** erreicht 3 Frames → Match gewonnen!

### Eingabe-Zusammenfassung

| Aktion | Eingabe |
|--------|---------|
| **+1 Punkt** (Roter Ball) | Klick auf Rot-Button (1) oder Frame-Score |
| **+2 Punkte** (Gelber Ball) | Klick auf Gelb-Button (2) |
| **+3 Punkte** (Grüner Ball) | Klick auf Grün-Button (3) |
| **+4 Punkte** (Brauner Ball) | Klick auf Braun-Button (4) |
| **+5 Punkte** (Blauer Ball) | Klick auf Blau-Button (5) |
| **+6 Punkte** (Pinker Ball) | Klick auf Pink-Button (6) |
| **+7 Punkte** (Schwarzer Ball) | Klick auf Schwarz-Button (7) |
| **Spielerwechsel** | Klick auf gegnerischen Frame-Score |
| **Größere Breaks** | Calculator-Button verwenden |
| **Korrektur** | Undo-Button oder -1/-5/-10 Buttons |

---

## Quickstart-Spiele

### Best of 3 (2 Frames zum Gewinn)

Ideal für schnelle Trainingsspiele:
- Klicken Sie auf **"Best of 3"** Button
- Wählen Sie die Spieler
- Klicken Sie auf **"Start Game"**

### Best of 5 (3 Frames zum Gewinn)

Standard für die meisten Spiele:
- Klicken Sie auf **"Best of 5"** Button
- Wählen Sie die Spieler
- Klicken Sie auf **"Start Game"**

### Best of 7 (4 Frames zum Gewinn)

Für längere Spiele:
- Klicken Sie auf **"Best of 7"** Button
- Wählen Sie die Spieler
- Klicken Sie auf **"Start Game"**

### Best of 9 (5 Frames zum Gewinn)

Für Turniere und wichtige Spiele:
- Klicken Sie auf **"Best of 9"** Button
- Wählen Sie die Spieler
- Klicken Sie auf **"Start Game"**

---

## Tipps für effiziente Bedienung

### Schnelle Break-Eingabe

1. **Für rote Bälle**: Verwenden Sie den **Frame-Score-Klick** (+1) - am schnellsten
2. **Für farbige Bälle**: Verwenden Sie die **farbcodierten Buttons** - visuell klar
3. **Für größere Breaks**: Verwenden Sie den **Calculator** für direkte Eingabe

### Spielerwechsel optimieren

- **Immer auf den gegnerischen Frame-Score klicken** - das ist schneller als andere Methoden
- Der Break wird automatisch beendet und zum Frame-Score hinzugefügt

### Break-Tracking

- Der **aktuelle Break** wird nur beim aktiven Spieler angezeigt
- Nach Spielerwechsel wird der Break zum Frame-Score hinzugefügt
- Der **High Break (HB)** wird automatisch aktualisiert, wenn ein neuer Rekord erreicht wird

### Frame-Management

- Die **Frame-Nummer** wird automatisch erhöht
- Das **Match-Format** (Best of X) wird in der Mitte angezeigt
- Der **Frame-Score** zeigt gewonnene Frames / Frames zum Gewinn

---

## Fehlerbehebung

### Break wird nicht angezeigt

- **Prüfen Sie**: Ist der Spieler aktiv? (Grüner Rahmen)
- Der Break wird nur beim aktiven Spieler angezeigt
- Nach Spielerwechsel wird der Break zum Frame-Score hinzugefügt

### Falsche Punkte eingegeben

- **Undo-Button**: Macht die letzte Aktion rückgängig
- **-1/-5/-10 Buttons**: Ziehen Punkte ab
- **Calculator**: Für größere Korrekturen

### Spielerwechsel funktioniert nicht

- **Klicken Sie auf den Frame-Score des anderen Spielers** (nicht auf den eigenen)
- Der grüne Rahmen zeigt den aktiven Spieler an
- Prüfen Sie, ob das Spiel läuft (nicht pausiert)

### Frame-Score wird nicht aktualisiert

- Der Frame-Score wird nur aktualisiert, wenn ein Frame gewonnen wird
- Einzelne Breaks werden zum Frame-Score addiert, wenn der Frame gewonnen wird
- Prüfen Sie, ob der Frame bereits beendet wurde

### High Break wird nicht aktualisiert

- Der High Break wird nur aktualisiert, wenn ein neuer Rekord erreicht wird
- Prüfen Sie, ob der aktuelle Break höher ist als der bisherige High Break
- Der High Break wird pro Spiel (nicht pro Frame) geführt

---

## Turnier-Integration

### Snooker in Turnieren

Das Snooker Scoreboard ist vollständig in das Turniersystem integriert:

- **Automatische Frame-Zählung** für Turnierspiele
- **Ergebnis-Übermittlung** an das Turniersystem
- **Spielstand-Anzeige** in der Turnierübersicht
- **Protokoll-Erstellung** für offizielle Spiele

### Liga-Integration

Snooker-Ligen werden unterstützt:

- **Frame-Ergebnisse** werden automatisch in die Liga-Tabelle übernommen
- **High Breaks** werden in den Statistiken erfasst
- **Spielstände** werden für die Liga-Wertung verwendet

---

## Häufige Fragen (FAQ)

### Wie viele Punkte kann man maximal in einem Frame erzielen?

**147 Punkte** (Maximum Break):
- 15 rote Bälle (15 Punkte) + 15 schwarze Bälle (15 × 7 = 105 Punkte) = 120 Punkte
- Danach alle farbigen Bälle in Reihenfolge: Gelb (2) + Grün (3) + Braun (4) + Blau (5) + Pink (6) + Schwarz (7) = 27 Punkte
- **Gesamt: 147 Punkte**

### Was passiert, wenn beide Spieler die gleiche Anzahl von Frames haben?

Bei einem Unentschieden (z.B. 2:2 bei Best of 5) wird ein **Entscheidungsframe** gespielt, bis ein Spieler gewinnt.

### Wie werden Fouls gehandhabt?

Fouls müssen manuell eingegeben werden:
1. Punkte vom Break abziehen (oder korrigieren)
2. Foul-Punkte zum Gegner hinzufügen (über Calculator oder Punkt-Buttons)
3. Spielerwechsel durchführen

### Kann ich ein Spiel pausieren?

Ja, über das **Menü** können Sie:
- Das Spiel pausieren
- Das Spiel beenden
- Zurück zum Willkommensbildschirm

### Wie sehe ich die Spielstatistiken?

Nach Spielende können Sie:
- Das **Protokoll** einsehen
- **High Breaks** und **Frame-Ergebnisse** anzeigen
- Die **Spielstatistiken** im Turnier-/Liga-System prüfen

---

## Unterstützung

Bei Fragen oder Problemen wenden Sie sich bitte an:
- Den **Schiedsrichter** oder **Turnierleiter**
- Die **Club-Verwaltung**
- Den **System-Administrator**

---

**Viel Erfolg beim Snooker-Spielen!**

