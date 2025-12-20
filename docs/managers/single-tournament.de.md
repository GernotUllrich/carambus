# Einzelturnierverwaltung - Wizard-System

## Übersicht

Das neue **Wizard-System** für die Turnierverwaltung führt Sie Schritt für Schritt durch den gesamten Prozess der Turnier-Vorbereitung. Jeder Schritt ist klar strukturiert und bietet kontextbezogene Hilfe, damit auch weniger technisch versierte Turnierleiter das System sicher bedienen können.

## Zugang

Für das Carambus Turniermanagement ist ein Account mit **Admin-Rechten** auf dem Carambus Location Server erforderlich. Dieser kann vom Club-Vorsitzenden oder [Carambus-Entwickler](mailto:gernot.ullrich@gmx.de) eingerichtet werden.

Die URL ist aus den URLs der Scoreboards ableitbar, z.B. in Wedel: `http://192.168.2.210:3131`

## Der Wizard-Workflow

Das neue Wizard-System besteht aus **6 Hauptschritten**, die Sie visuell durch den gesamten Prozess führen:

### Schritt 1: Meldeliste von ClubCloud laden

**Ziel:** Die Meldeliste vom API Server holen.

**Was passiert hier?**
- Das System synchronisiert die Meldeliste aus der ClubCloud

**Wann wird dieser Schritt benötigt?**
- Wenn das Turnier erstmalig geladen wird
- Wenn sich die Meldeliste nach dem Meldeschluss geändert hat

**Schnell-Laden:**
- ⚡ **"Anstehende Turniere laden"** Button: Lädt nur Turniere der nächsten 30 Tage (schneller als vollständige Synchronisation)
- Verfügbar auf der Regionalverband-Seite: `Regionalverbände → [Ihr Verband] → "⚡ Schnell-Aktualisierung"`

**Manuelle Synchronisation:**
- `Turnier → "Jetzt synchronisieren"`: Vollständige Synchronisation aller Daten
- `Turnier → "📊 Ergebnisse von ClubCloud laden"`: Nur für Archivierung nach Turnierende (löscht lokale Daten!)

### Schritt 2: Setzliste aus Einladung übernehmen

**Ziel:** Die offizielle Setzliste aus der Einladung des Landessportwartes übernehmen, oder direkt mit der Meldeliste weitergehen.

**Was passiert hier?**
- **Option 1:** Sie laden eine PDF-Datei oder ein Screenshot der Einladung hoch
- Das System extrahiert automatisch:
  - Spielernamen und Positionen
  - **Vorgaben (Handicap-Punkte)** für Vorgabeturniere
  - **Gruppenbildung** (wenn in der Einladung vorhanden)
  - **Turniermodus** (z.B. "T21 - Turnier wird im Modus...")
- **Option 2 (Alternative):** Wenn keine Einladung vorliegt, können Sie direkt mit der Meldeliste zu Schritt 3 weitergehen
  - Die Spieler werden automatisch nach dem **Carambus-Ranking** für die Disziplin sortiert
  - Die Sortierung basiert auf den effektiven Rankings (neueste verfügbare Saison aus den letzten 2-3 Jahren)

**Wie funktioniert es?**
1. Klicken Sie auf **"Einladung hochladen"**
2. Wählen Sie eine PDF-Datei oder ein Screenshot (PNG/JPG) der Einladung
3. Das System analysiert das Dokument automatisch
4. Prüfen Sie die **Extrahierte Setzliste**:
   - ✅ Spieler korrekt erkannt?
   - ✅ Positionen richtig?
   - ✅ Vorgaben vorhanden (bei Vorgabeturnieren)?
5. Korrigieren Sie ggf. manuell:
   - Spieler falsch erkannt → **"Spieler ändern"** klicken
   - Position falsch → In der Liste korrigieren
   - Vorgabe fehlt → Manuell eintragen
6. **"Setzliste übernehmen"** klicken

**Unterstützte Formate:**
- ✅ PDF-Dateien (mit Text)
- ✅ Screenshots (PNG, JPG)
- ✅ Ein- und zweispaltige Tabellen
- ✅ Tabellen mit Vorgaben-Spalte ("Pkt")

**Was wird extrahiert?**
- Spielernamen (Vor- und Nachname)
- Positionen in der Setzliste
- Vorgaben (bei Vorgabeturnieren)
- Gruppenbildung (wenn vorhanden)
- Turniermodus-Vorschlag (z.B. "T21")

### Schritt 3: Teilnehmerliste bearbeiten

**Ziel:** Die finale Teilnehmerliste erstellen und anpassen.

**Was passiert hier?**
- Sie sehen die aktuelle Teilnehmerliste mit folgenden Informationen:
  - Position (Setzliste)
  - Spielername und Club
  - **Carambus-Ranking** für die Disziplin (mit Link zur Rangliste)
  - Vorgabe (bei Vorgabeturnieren)
- Sie können:
  - **No-Shows** markieren (Spieler erscheint nicht)
  - **Vorgaben korrigieren** (bei Vorgabeturnieren)
  - **Positionen anpassen** mit ↑↓ Buttons oder direkter Eingabe
  - **Nachmelder hinzufügen** (mit DBU-Nummer)

**Neue Features in Schritt 3:**

**1. Ranking-Anzeige:**
- Jeder Spieler zeigt sein **effektives Carambus-Ranking** für die Disziplin
- Basierend auf den letzten 2-3 Saisons (neueste verfügbare)
- Klickbar: Link führt zur vollständigen Rangliste der Region mit Anchor zur Disziplin

**2. Positionsänderung:**
- **↑↓ Buttons:** Spieler eine Position nach oben/unten verschieben
- **Direkte Eingabe:** Neue Position direkt eingeben (z.B. "5" eingeben und Enter)
- Änderungen werden sofort gespeichert
- Die Gruppenzuordnungen in der Turnierplan-Vorschau aktualisieren sich automatisch

**3. Turnierplan-Vorschau:**
- Zeigt **mögliche Turnierpläne** für die aktuelle Teilnehmerzahl
- **Gruppenzuordnungen** werden dynamisch berechnet und angezeigt
- Aktualisiert sich automatisch bei Änderungen an der Teilnehmerliste
- Zeigt Anzahl der Runden für jeden Plan
- **Vorgeschlagener Plan:** Aus Einladung (falls vorhanden) oder automatisch berechnet
- **Alternative Pläne:** Gleiche Disziplin, andere Disziplinen, "Jeder gegen Jeden" (bei ≤6 Teilnehmern)

**Nachmelder hinzufügen:**
1. Scrollen Sie zum Abschnitt **"➕ Kurzfristiger Nachmelder?"**
2. Geben Sie die **DBU-Nummer** des Spielers ein
3. Klicken Sie auf **"Spieler hinzufügen"**
4. Der Spieler wird automatisch zur Liste hinzugefügt (am Ende)

**⚠️ Wichtig:**
- Spieler **ohne DBU-Nummer** können nicht nachgemeldet werden
- Grund: In der ClubCloud können nur Spieler mit DBU-Nummer eingetragen werden
- Lösung: Spieler muss DBU-Nummer beantragen, oder als Gast eintragen lassen

**Automatisches Speichern:**
- Alle Änderungen (Checkboxen, Vorgaben) werden **sofort gespeichert**
- Sie können jederzeit hierher zurückkehren

**Weiter zum nächsten Schritt:**
- Nach Abschluss: **"← Zurück zum Wizard"** klicken
- Dann weiter zu **Schritt 4: Teilnehmerliste finalisieren**

### Schritt 4: Teilnehmerliste finalisieren

**Ziel:** Die Teilnehmerliste abschließen und für die Gruppenbildung vorbereiten.

**Was passiert hier?**
- Die Teilnehmerliste wird finalisiert
- No-Shows werden aus der Liste entfernt
- Die Liste wird für die Gruppenbildung gesperrt

**⚠️ Wichtig:**
- Dieser Schritt ist **nicht umkehrbar**
- Nach der Finalisierung können keine Spieler mehr hinzugefügt oder entfernt werden
- Positionen können nicht mehr geändert werden

### Schritt 5: Turniermodus festlegen

**Ziel:** Den passenden Turniermodus auswählen und die Gruppenbildung überprüfen.

**Was passiert hier?**
- Das System schlägt automatisch einen Turniermodus vor:
  - Basierend auf der Teilnehmeranzahl
  - Basierend auf der Disziplin
  - Basierend auf dem **extrahierte Turniermodus aus der Einladung**

**Vorschläge aus Einladung:**
- Wenn eine Einladung hochgeladen wurde, wird der **extrahierte Turniermodus** bevorzugt angezeigt
- Beispiel: "T21 - Turnier wird im Modus..."
- Diese Vorgabe kommt direkt vom Landessportwart

**Gruppenbildung:**
- Das System zeigt die **berechnete Gruppenbildung** nach NBV-Standard
- Wenn eine Einladung hochgeladen wurde, wird auch die **extrahierte Gruppenbildung** angezeigt

**Drei mögliche Szenarien:**

1. **✅ Gruppenbildung aus Einladung stimmt mit Algorithmus überein**
   - Grüne Banner: "✅ Gruppenbildung aus Einladung übernommen"
   - Die Zuordnung ist identisch mit dem NBV-Standard-Algorithmus
   - **Empfehlung:** Einladung verwenden (vom Landessportwart vorgegeben)

2. **⚠️ Gruppenbildung aus Einladung weicht vom Algorithmus ab**
   - Rotes Banner: "⚠️ WARNUNG: Abweichung vom NBV-Standard erkannt!"
   - Vergleich wird angezeigt: Einladung vs. berechnet
   - **Empfehlung:** Einladung verwenden (vom Landessportwart vorgegeben)
   - **Alternative:** Algorithmus verwenden (falls Sie sicher sind, dass der Algorithmus korrekt ist)

3. **🤖 Keine Einladung vorhanden**
   - Blaues Banner: "🤖 Gruppenbildung automatisch berechnet (NBV-konform)"
   - Standard-Algorithmus wird verwendet

**Turniermodus auswählen:**
1. Prüfen Sie die **vorgeschlagene Option** (grün hervorgehoben)
2. Prüfen Sie **Alternativen** (falls verfügbar):
   - Gleiche Disziplin mit anderen Spieleranzahlen
   - Andere Disziplinen mit gleicher Spieleranzahl
3. **"Weiter mit [Modusname]"** klicken

### Schritt 6: Turnier starten

**Ziel:** Das Turnier initialisieren und die Scoreboards aktivieren.

**Was passiert hier?**
- Sie konfigurieren die Turnierparameter:
  - **Tische zuordnen** (Mapping interner Tischname zu extern Namen)
  - **Ballziel** (ggf. bereits für Turnier vorgegeben)
  - **Aufnahmebegrenzung** (ggf. bereits für Turnier vorgegeben)
  - **Timeout** in Sekunden (0 oder leer, wenn keine Timeouts)
  - **Timeouts** (maximale Anzahl von Timeout-Verlängerungen)
  - **Checkbox:** "Tournament manager checks results before acceptance"
  - **Einspielzeit** (Standard und verkürzt bei Wechsel)

**Turnierparameter:**
- Viele Parameter können aus der **Einladung** übernommen werden
- Beispiel: "Das Ausspielziel beträgt 80 Punkte in 20 Aufnahmen"
- Diese Informationen werden automatisch extrahiert (falls verfügbar)

**Turnier starten:**
1. Alle Parameter prüfen und ggf. anpassen
2. **"Turnier starten"** klicken
3. Das System:
   - Initialisiert den Tournament Monitor
   - Erstellt alle Spiele gemäß Turniermodus
   - Ordnet Tische zu
   - Startet die Scoreboards

**Nach dem Start:**
- Neue Spielpaarungen erscheinen automatisch auf den Scoreboards
- Der **Tournament Monitor** zeigt den aktuellen Stand
- Spieler können Spiele starten und Ergebnisse eingeben

## Während des Turniers: Tournament Status

Nach dem Start des Turniers wird der **Wizard ausgeblendet** und durch die **Tournament Status**-Ansicht ersetzt.

**Was zeigt der Tournament Status?**

**1. Turnier-Übersicht:**
- Aktuelle Turnier-Phase (z.B. "Gruppenphase", "Finalrunde")
- Fortschrittsbalken (gespielte vs. geplante Spiele)
- Anzahl der abgeschlossenen Spiele

**2. Aktuelle Spiele:**
- Zeigt bis zu 6 laufende Spiele gleichzeitig
- Live-Punktestände mit aktuellen Inning-Ergebnissen
- Status-Anzeige: "▶️ Läuft" oder "Wartet"
- Zugeordnete Tische

**3. Gruppeneinteilung:**
- Übersicht über alle Gruppen
- Spieler je Gruppe
- NBV-konforme Zuordnung

**4. Setzliste:**
- Finale Teilnehmerliste mit Positionen
- **Carambus-Rankings** für jeden Spieler
- Club-Zugehörigkeit
- Bei Vorgabeturnieren: Ballziele
- **Link zur Rangliste:** Führt zur vollständigen Rangliste der Region

**5. Aktuelle Platzierungen:**
- Zwischenstände nach Gruppenphasen
- Finale Platzierungen nach Turnierablauf
- Generaldurchschnitt, Höchstserie, etc.

**Nur für Spielleiter sichtbar:**
- **🎮 Tournament Monitor öffnen** Button
- Zugriff auf Spielverwaltung und Tischzuordnung
- Ergebnis-Kontrolle und Freigabe

**Für Zuschauer:**
- Übersichtliche Ansicht des Turnierstands
- Live-Updates bei Spielfortschritt
- Keine Bearbeitungsmöglichkeiten

## Troubleshooting

### Problem: "Keine Seedings gefunden"

**Ursache:** Die Meldeliste wurde noch nicht synchronisiert.

**Lösung:**
1. Gehen Sie zu **Schritt 1**
2. Klicken Sie auf **"Jetzt synchronisieren"**
3. Warten Sie auf die Synchronisation
4. Prüfen Sie, ob Seedings vorhanden sind

### Problem: "Spieler wird nicht erkannt" (bei Einladung-Upload)

**Ursache:** Der Name im Dokument wurde nicht korrekt erkannt.

**Lösung:**
1. In der **Extrahierte Setzliste** finden Sie den Spieler
2. Klicken Sie auf **"Spieler ändern"**
3. Suchen Sie nach dem korrekten Spieler
4. Wählen Sie den richtigen aus

### Problem: "Gruppenbildung stimmt nicht"

**Ursache:** Die Extraktion aus der Einladung war nicht korrekt, oder der Algorithmus passt nicht.

**Lösung:**
1. Prüfen Sie die **Extrahierte Gruppenbildung** vs. **Berechnet**
2. Wenn Einladung vorhanden: **"✅ Einladung verwenden"** klicken (vom Landessportwart vorgegeben)
3. Wenn keine Einladung: **"🔄 Neu berechnen"** klicken
4. Falls weiterhin falsch: **Schritt 3** erneut aufrufen und Positionen anpassen

### Problem: "Nachmelder kann nicht hinzugefügt werden"

**Ursache:** Spieler hat keine DBU-Nummer.

**Lösung:**
1. Spieler muss DBU-Nummer beantragen, oder
2. Turnierleiter trägt Spieler als Gast ein (kontaktieren Sie den Landessportwart)

### Problem: "Turnier kann nicht gestartet werden"

**Ursache:** TournamentPlan passt nicht zur Spieleranzahl.

**Lösung:**
1. Prüfen Sie die **Fehlermeldung** im Tournament Monitor
2. Gehen Sie zurück zu **Schritt 5**
3. Wählen Sie den **richtigen TournamentPlan** aus:
   - Beispiel: 11 Spieler → T21 (nicht T22!)
   - Prüfen Sie die Spieleranzahl in Schritt 3

### Problem: "Seedings werden nach Synchronisation gelöscht"

**Ursache:** Alte "destroy" Version Records auf dem API Server.

**Lösung:**
1. Auf API Server ausführen: `rake tournament:check_seeding_versions[TOURNAMENT_ID]`
2. Falls destroy-Version Records gefunden: `rake tournament:cleanup_seeding_versions[TOURNAMENT_ID]`
3. Erneut synchronisieren

## Nach dem Turnier

### Ergebnisse exportieren

Nach Abschluss des Turniers erhalten Sie automatisch per **eMail** eine CSV-Datei mit den Ergebnissen im Format für den Upload in die ClubCloud.

Die Datei wird auch lokal gespeichert: `{carambus}/tmp/result-{ba_id}.csv`

### Ergebnisse in ClubCloud hochladen

Der Turnierleiter kann die CSV-Datei direkt in die ClubCloud hochladen.

### Finaler Abgleich

Als letzten Schritt kann nochmal ein **Abgleich mit der ClubCloud** erfolgen:
- `Turnier → "📊 Ergebnisse von ClubCloud laden"` (nur für Archivierung!)

Die damit heruntergeladenen Daten sind Grundlage für später ausgerechnete Rankings.

## Wichtige Unterschiede: Meldeliste vs. Setzliste vs. Teilnehmerliste

**Meldeliste:**
- Alle Spieler, die sich für das Turnier angemeldet haben
- Kommt aus der ClubCloud
- Wird täglich aktualisiert

**Setzliste:**
- Die **Reihenfolge** nach effektivem Ranking
- Beste Spieler zuerst (niedrigste Ranking-Nummer = Position 1)
- **Effektives Ranking:** Basiert auf der neuesten verfügbaren Saison aus den letzten 2-3 Jahren
- Kommt aus der **Einladung** vom Landessportwart ODER wird automatisch nach Carambus-Rankings sortiert
- Wird in **Schritt 2** übernommen oder berechnet

**Teilnehmerliste:**
- Die Spieler, die **tatsächlich zum Turnier erscheinen**
- Kann mehr oder weniger Spieler haben als die Meldeliste
- No-Shows werden entfernt
- Nachmelder werden hinzugefügt
- Wird in **Schritt 3** erstellt und in **Schritt 4** finalisiert

## Technische Details

### Automatische Extraktion

Das System verwendet **OCR (Optical Character Recognition)** und **PDF-Text-Extraktion**, um Informationen aus Einladungen zu extrahieren:

- **PDF:** Text wird direkt extrahiert
- **Screenshots:** Tesseract OCR erkennt Text
- **Tabellen:** Ein- und zweispaltige Layouts werden erkannt
- **Vorgaben:** Werden aus "Pkt"-Spalten extrahiert
- **Gruppenbildung:** Wird aus "Gruppenbildung"-Tabellen extrahiert

### NBV-konforme Gruppenbildung

Das System verwendet **offizielle NBV-Algorithmen** für die Gruppenbildung:

- **2 Gruppen:** Zig-Zag/Serpentine-Pattern
- **3+ Gruppen:** Round-Robin-Pattern
- **Ungleiche Gruppengrößen:** Spezial-Algorithmus (z.B. T21: 3+4+4)

Die Gruppengrößen werden aus den `executor_params` des TournamentPlans extrahiert.

### Synchronisation

- **Setup-Phase:** Seedings werden nicht gelöscht (nur lokale Seedings werden zurückgesetzt)
- **Archivierungs-Phase:** Alle Seedings werden gelöscht und neu geladen (für Ergebnis-Übernahme)

Der Parameter `reload_games` steuert, ob Seedings gelöscht werden:
- `false` (Standard): Setup-Phase (Seedings bleiben erhalten)
- `true`: Archivierungs-Phase (Seedings werden gelöscht)

## Support

Bei Problemen oder Fragen:
- **E-Mail:** [gernot.ullrich@gmx.de](mailto:gernot.ullrich@gmx.de)
- **Dokumentation:** Diese Seite und die Inline-Hilfen im Wizard
