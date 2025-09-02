# Anleitung: Schiedsrichter-Tabelle in Google Sheets

## Übersicht

Die Schiedsrichter-Einteilung für das PREDATOR GRAND PRIX DREIBAND DAMEN 2025 ist jetzt als strukturierte Tabelle verfügbar und kann einfach in Google Sheets importiert werden.

## Verfügbare Dateien

### CSV-Tabellen

- **Schiedsrichter-Einteilung:** `docs/predator_grand_prix_schiedsrichter_tabelle.csv`
  - **Format:** CSV (Comma Separated Values)
  - **Inhalt:** Vollständige Schiedsrichter- und Schreiber-Einteilung mit Zeiten
- **Verfügbarkeiten:** `docs/predator_grand_prix_verfuegbarkeiten.csv`
  - **Format:** CSV (Comma Separated Values)
  - **Inhalt:** Übersicht über Verfügbarkeiten aller Beteiligten

### PDF-Referenz

- **Datei:** `doc/doc-local/PREDATOR/Schiris Predator.v1.6 25.8.19 Uhr..pdf`
- **Inhalt:** Original-Schiedsrichter-Plan

## Import in Google Sheets

### Schritt 1: Google Sheets öffnen

1. **Öffne Google Sheets** (sheets.google.com)
2. **Erstelle ein neues Tabellenblatt**

### Schritt 2: CSV-Dateien importieren

1. **Datei → Importieren**
2. **Wähle "Hochladen"**
3. **Ziehe die erste CSV-Datei hinein** oder klicke "Datei auswählen"
4. **Wähle "Neues Tabellenblatt erstellen"**
5. **Klicke "Daten importieren"**
6. **Wiederhole für die zweite CSV-Datei** (als neues Tabellenblatt)

### Schritt 3: Formatierung anpassen

1. **Spaltenbreiten anpassen** (Doppelklick auf Spaltentrenner)
2. **Überschriften formatieren** (fett, Hintergrundfarbe)
3. **Zeilen abwechselnd einfärben** für bessere Lesbarkeit

## Tabellenstruktur

### Spalten - Schiedsrichter-Einteilung

- **Tag:** Wochentag
- **Datum:** Datum im Format DD.MM.YYYY
- **Tisch:** Tischnummer (T1-T4)
- **Zeit:** Zeitraum der Schicht
- **Schiedsrichter:** Name des Schiedsrichters
- **Schreiber:** Name des Schreibers
- **Status:** Training oder Wettkampf
- **Bemerkungen:** Zusätzliche Informationen

### Spalten - Verfügbarkeiten

- **Name:** Name der Person
- **Funktion:** Schiedsrichter oder Schreiber
- **29.8. (Freitag):** Verfügbarkeit Freitag
- **30.8. (Samstag):** Verfügbarkeit Samstag
- **31.8. (Sonntag):** Verfügbarkeit Sonntag
- **Gesamt Schichten:** Anzahl der Schichten
- **Bemerkungen:** Besondere Hinweise

### Schichtplan

- **Donnerstag:** Training (gestrichen)
- **Freitag:** 4 Schichten (09:30-22:00)
- **Sonnabend:** 3 Schichten (09:30-19:00)
- **Sonntag:** 3 Schichten (10:00-18:00) + Siegerehrung

## Vorteile der Google Sheets-Version

### ✅ **Übersichtlichkeit**

- Alle Informationen auf einen Blick
- Einfache Filterung nach Tag, Tisch oder Person
- Farbliche Hervorhebung möglich

### ✅ **Bearbeitbarkeit**

- Einfache Änderungen bei Ausfällen
- Neue Schichten hinzufügen
- Kommentare und Notizen möglich

### ✅ **Teilbarkeit**

- Mit allen Beteiligten teilen
- Verschiedene Berechtigungen (nur lesen, kommentieren, bearbeiten)
- Echtzeit-Updates

### ✅ **Druckbarkeit**

- Saubere Ausgabe für den Club
- Anpassbare Seitenformate
- PDF-Export möglich

## Erweiterte Funktionen

### Filter und Sortierung

1. **Filter aktivieren:** Daten → Filter aktivieren
2. **Nach Tag filtern:** Klick auf Pfeil in Spalte "Tag"
3. **Nach Person filtern:** Klick auf Pfeil in Spalte "Schiedsrichter" oder "Schreiber"

### Bedingte Formatierung

1. **Status farblich hervorheben:**
   - Training: Gelb
   - Wettkampf: Grün
   - Siegerehrung: Blau

2. **Zeitliche Überschneidungen prüfen:**
   - Gleiche Zeiten in verschiedenen Farben

### Formeln und Berechnungen

1. **Arbeitszeit pro Person berechnen:**

   ```
   =COUNTIF(B:B, "Rolf") * 3.5
   ```

2. **Schichtverteilung pro Tag:**

   ```
   =COUNTIF(A:A, "Freitag")
   ```

## Teamarbeit

### Berechtigungen setzen

1. **Teilen** (oben rechts)
2. **E-Mail-Adressen eingeben**
3. **Berechtigungen wählen:**
   - **Nur lesen:** Für alle Beteiligten
   - **Kommentieren:** Für Schiedsrichter
   - **Bearbeiten:** Für Turnierleitung

### Kommentare nutzen

1. **Rechtsklick auf Zelle**
2. **Kommentar hinzufügen**
3. **Feedback und Änderungswünsche**

### Versionsverlauf

1. **Datei → Versionsverlauf → Versionen anzeigen**
2. **Alle Änderungen nachverfolgen**
3. **Bei Bedarf zurücksetzen**

## Export und Backup

### PDF-Export

1. **Datei → Herunterladen → PDF-Dokument**
2. **Für den Club ausdrucken**
3. **Als Referenz aufbewahren**

### Excel-Export

1. **Datei → Herunterladen → Microsoft Excel**
2. **Für Offline-Bearbeitung**
3. **Backup-Zweck**

## Fehlerbehebung

### Häufige Probleme

#### CSV wird nicht korrekt importiert

- **Prüfe Trennzeichen:** Komma vs. Semikolon
- **Zeichenkodierung:** UTF-8 verwenden
- **Spaltenanzahl:** Sollte 8 Spalten haben

#### Formatierung geht verloren

- **Nach Import neu formatieren**
- **Überschriften als Überschriften markieren**
- **Spaltenbreiten anpassen**

#### Deutsche Umlaute werden nicht angezeigt

- **UTF-8-Kodierung prüfen**
- **Schriftart auf Arial oder ähnlich setzen**

## Support

Bei Problemen:

1. **Prüfe die CSV-Datei** auf Korrektheit
2. **Verwende die PDF-Referenz** als Fallback
3. **Kontaktiere den IT-Support** (Gernot)

---

**Erstellt:** 25.8.2025  
**Nächste Überprüfung:** 27.8.2025  
**Verantwortlich:** Dr. Gernot Ullrich
