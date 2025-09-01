# Anleitung: Markdown zu Google Docs konvertieren

## Schnellstart (Empfohlen)

### 1. Direkte Konvertierung in Google Docs
1. **Öffne Google Docs** (docs.google.com)
2. **Erstelle ein neues Dokument**
3. **Kopiere den Inhalt** aus der gewünschten Markdown-Datei
4. **Füge ihn ein** - Google Docs erkennt die Formatierung

### 2. Automatische Konvertierung (mit Skript)
```bash
# Führe das Konvertierungsskript aus
./scripts/convert_to_google_docs.sh

# Oder manuell mit Pandoc
pandoc docs/predator_grand_prix_2025.de.md -o PREDATOR_GRAND_PRIX_2025_DE.docx
```

## Verfügbare Dokumente

### Hauptdokumentation
- **Deutsch:** `docs/predator_grand_prix_2025.de.md`
- **Englisch:** `docs/predator_grand_prix_2025.en.md`

### Zusatzdokumentation
- **Zeitplan:** `docs/predator_grand_prix_timeline_2025.de.md`
- **Funktionsbesetzung:** `docs/predator_grand_prix_roles_2025.de.md`

## Schritt-für-Schritt Anleitung

### Option A: Manuelle Konvertierung (Einfachste)

1. **Öffne die Markdown-Datei** in deinem Editor
2. **Kopiere den gesamten Inhalt** (Strg+A, Strg+C)
3. **Öffne Google Docs** (docs.google.com)
4. **Erstelle ein neues Dokument**
5. **Füge den Inhalt ein** (Strg+V)
6. **Formatiere nach Bedarf:**
   - Überschriften werden automatisch erkannt
   - Listen werden korrekt formatiert
   - Tabellen können manuell angepasst werden

### Option B: Automatische Konvertierung (Professionell)

#### Voraussetzungen
- **Pandoc installieren:**
  ```bash
  # macOS
  brew install pandoc
  
  # Ubuntu/Debian
  sudo apt-get install pandoc
  
  # Windows
  # Download von pandoc.org
  ```

#### Konvertierung durchführen
```bash
# Alle Dokumente auf einmal konvertieren
./scripts/convert_to_google_docs.sh

# Oder einzeln
pandoc docs/predator_grand_prix_2025.de.md -o PREDATOR_GRAND_PRIX_2025_DE.docx
pandoc docs/predator_grand_prix_timeline_2025.de.md -o PREDATOR_GRAND_PRIX_ZEITPLAN_2025_DE.docx
pandoc docs/predator_grand_prix_roles_2025.de.md -o PREDATOR_GRAND_PRIX_FUNKTIONEN_2025_DE.docx
```

#### In Google Docs hochladen
1. **Öffne Google Docs**
2. **Datei → Öffnen**
3. **Wähle "Hochladen"**
4. **Ziehe die .docx-Datei hinein**
5. **Google Docs konvertiert sie automatisch**

## Formatierung in Google Docs

### Überschriften
- **H1 (#):** Titel
- **H2 (##):** Hauptabschnitte  
- **H3 (###):** Unterabschnitte

### Listen
- **Aufzählungen (-):** Automatisch erkannt
- **Nummerierte Listen (1. 2. 3.):** Automatisch erkannt

### Tabellen
- Werden als einfache Tabellen konvertiert
- Können in Google Docs nachbearbeitet werden

### Links
- Werden automatisch als klickbare Links erkannt

## Tipps für bessere Formatierung

### Nach der Konvertierung
1. **Überprüfe alle Überschriften**
2. **Passe Tabellen an** (Spaltenbreiten, Ausrichtung)
3. **Füge Seitenzahlen hinzu**
4. **Erstelle ein Inhaltsverzeichnis** (Einfügen → Inhaltsverzeichnis)

### Für Teamarbeit
1. **Teile das Dokument** mit allen Beteiligten
2. **Setze Berechtigungen** (nur lesen, kommentieren, bearbeiten)
3. **Nutze Kommentare** für Feedback
4. **Verwende Versionsverlauf** für Änderungen

## Fehlerbehebung

### Häufige Probleme

#### Pandoc nicht gefunden
```bash
# Prüfe Installation
which pandoc

# Installiere neu
brew install pandoc  # macOS
```

#### Formatierungsprobleme
- **Überschriften:** Manuell als Überschriften formatieren
- **Tabellen:** In Google Docs neu erstellen
- **Listen:** Manuell als Listen formatieren

#### Zeichenkodierung
- Verwende UTF-8 für deutsche Umlaute
- Pandoc handhabt dies automatisch

## Alternative Online-Tools

### Markdown zu Google Docs
- **StackEdit** (stackedit.io)
- **Dillinger** (dillinger.io)
- **HackMD** (hackmd.io)

### Markdown zu Word
- **Pandoc Online** (pandoc.org/try)
- **Markdown to Word** (Online-Konverter)

## Support

Bei Problemen:
1. **Prüfe die Markdown-Syntax**
2. **Verwende die manuelle Methode** als Fallback
3. **Kontaktiere den IT-Support** (Gernot)

---

**Erstellt:** 25.8.2025  
**Nächste Überprüfung:** 27.8.2025  
**Verantwortlich:** Dr. Gernot Ullrich



