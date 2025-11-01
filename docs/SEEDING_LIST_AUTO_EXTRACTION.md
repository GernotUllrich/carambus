# Automatische Setzlisten-Extraktion aus Einladungen

## Feature Overview

Dieses Feature ermöglicht das **automatische Auslesen der Setzliste** aus der offiziellen Turnier-Einladung (PDF oder Screenshot).

### Vorher (manuell):
1. PDF-Einladung öffnen
2. Jeden Spieler einzeln abtippen
3. Reihenfolge manuell setzen
4. ⏱️ Zeit: 5-10 Minuten

### Nachher (automatisch):
1. PDF oder Screenshot hochladen
2. Automatische Extraktion
3. Prüfen & bestätigen  
4. ⏱️ Zeit: 30 Sekunden

## Workflow

### Neue Schritte-Reihenfolge

**VORHER:**
1. Setzliste aktualisieren
2. Mit ClubCloud synchronisieren
3. Nach Rangliste sortieren
4. Rangliste abschließen

**NACHHER:**
1. **Meldeliste** von ClubCloud laden (wer hat sich angemeldet)
2. **Setzliste** aus Einladung übernehmen (offizielle Reihenfolge) ← NEU!
3. **Teilnehmerliste** bearbeiten (wer ist tatsächlich da, am Turniertag)
4. **Teilnehmerliste** finalisieren
5. Turniermodus wählen
6. Turnier starten

### Begriffsklärung

- **Meldeliste** = Anmeldungen aus ClubCloud
- **Setzliste** = Offizielle Reihenfolge nach Ranking (aus Einladung)
- **Teilnehmerliste** = Tatsächliche Teilnehmer (Setzliste ± Änderungen vor Ort)

## Technische Implementierung

### Komponenten

1. **SeedingListExtractor Service**
   - Extrahiert Text aus PDF (`pdf-reader` gem)
   - Extrahiert Text aus Screenshots via OCR (`rtesseract` gem)
   - Parst Spielerliste mit Regex
   - Matched mit Datenbank

2. **Controller Actions**
   - `compare_seedings` - Vergleichsansicht
   - `upload_invitation` - Upload-Handler
   - `parse_invitation` - Automatische Extraktion
   - `apply_seeding_order` - Reihenfolge übernehmen

3. **Views**
   - `compare_seedings.html.erb` - Upload-Interface
   - `parse_invitation.html.erb` - Ergebnis-Anzeige

### Abhängigkeiten

#### Ruby Gems

```ruby
# Gemfile
gem 'pdf-reader', '~> 2.12'       # PDF-Text-Extraktion
gem 'rtesseract', '~> 3.1'        # OCR für Screenshots
```

#### System-Pakete (für OCR)

**macOS:**
```bash
brew install tesseract
brew install tesseract-lang  # für deutsche Texte
```

**Ubuntu/Debian:**
```bash
sudo apt-get install tesseract-ocr
sudo apt-get install tesseract-ocr-deu
```

### Installation

```bash
# 1. Gems installieren
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_bcw
bundle install

# 2. Tesseract installieren (für Screenshot-OCR)
brew install tesseract tesseract-lang

# 3. Assets kompilieren
yarn build:css
```

## Verwendung

### 1. PDF hochladen

```
Tournament → Schritt 2: "Setzliste aus Einladung übernehmen"
→ "Einladung hochladen"
→ PDF oder Screenshot auswählen
→ "Hochladen & automatisch parsen"
```

### 2. Ergebnis prüfen

Das System zeigt:
- ✅ **Erfolgreich zugeordnete Spieler** (grün)
- ⚠️ **Vermutete Zuordnungen** (gelb, unsicher)
- ❌ **Nicht gefundene Spieler** (rot, müssen manuell hinzugefügt werden)

### 3. Bestätigen

```
→ Liste prüfen
→ "Setzliste übernehmen"
→ Fertig!
```

## Parsing-Logik

Der Extractor sucht nach diesem Pattern:

```
Setzliste
---------
1. Smrcka, Martin
2. Kiehn, Ulf
3. Lorkowski, Joshua
...
```

**Unterstützte Formate:**
- `1. Nachname, Vorname`
- `1 Nachname Vorname`
- `1. Vorname Nachname`

**Stoppt bei:**
- "Gruppenbildung"
- "Turniermodus"
- Anderen Überschriften

## Edge Cases

### Fall 1: Spieler nicht in Meldeliste

```
Erkannt: "Ernst, Michael"
Status: ❌ Nicht in Meldeliste

→ Lösung: In Schritt 3 manuell hinzufügen
```

### Fall 2: Name falsch erkannt (OCR-Fehler)

```
Erkannt: "Sch röder" (Leerzeichen durch OCR-Fehler)
Zugeordnet: "Schröder, Hans-Jörg" (⚠️ Vermutung)

→ Lösung: Manuell prüfen, ggf. korrigieren
```

### Fall 3: PDF ist Scan (Bild in PDF)

```
→ PDF-Reader kann keinen Text extrahieren
→ Automatischer Fallback auf OCR
→ Funktioniert wie bei Screenshot
```

## Testing

### Test mit Beispiel-PDF

```ruby
# Rails Console
t = Tournament.find(17068)
file_path = '/path/to/einladung.pdf'

result = SeedingListExtractor.extract_from_file(file_path)
puts result.inspect

# Sollte zeigen:
# {
#   success: true,
#   players: [
#     { position: 1, lastname: "Smrcka", firstname: "Martin", ... },
#     ...
#   ],
#   count: 7
# }
```

### Test mit Screenshot

```ruby
# Rails Console
file_path = '/path/to/screenshot.png'
result = SeedingListExtractor.extract_from_file(file_path)
```

## Bekannte Limitationen

1. **OCR-Qualität**
   - Hängt von Screenshot-Qualität ab
   - Deutsche Umlaute (ä, ö, ü) manchmal problematisch
   - Funktioniert am besten mit klaren, hochauflösenden Screenshots

2. **PDF-Struktur**
   - Funktioniert nur bei Text-PDFs
   - Gescannte PDFs werden automatisch per OCR verarbeitet
   - Layout muss "Setzliste" Header haben

3. **Name-Matching**
   - Exact Match bevorzugt
   - Fuzzy-Match für Tippfehler
   - Bei mehreren Spielern mit ähnlichem Namen: Manuelle Prüfung

## Fallback

Falls automatische Extraktion fehlschlägt:

```
❌ Extraktion fehlgeschlagen

Alternativen:
[Andere Datei hochladen]
[Manuell sortieren]
[ClubCloud-Reihenfolge verwenden]
```

## Future Improvements

- [ ] ML-basierte Extraktion (bessere Genauigkeit)
- [ ] Unterstützung für mehr PDF-Layouts
- [ ] Automatische Korrektur von OCR-Fehlern
- [ ] Batch-Processing für mehrere Turniere
- [ ] Vorschau des hochgeladenen PDFs in der UI

## Commit Info

**Branch:** feature/tournament-wizard-ui  
**Files:**
- `app/services/seeding_list_extractor.rb` - Extraktions-Logik
- `app/controllers/tournaments_controller.rb` - Upload & Processing
- `app/views/tournaments/compare_seedings.html.erb` - Upload-UI
- `app/views/tournaments/parse_invitation.html.erb` - Ergebnis-Anzeige
- `config/routes.rb` - Neue Routes
- `Gemfile` - PDF/OCR Gems

