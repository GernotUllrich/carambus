# Suche in Carambus

## Übersicht

Die Suchfunktion in Carambus ist ein mächtiges Werkzeug, das es Benutzern ermöglicht, schnell und effizient durch alle Daten zu navigieren. Die Suche funktioniert auf allen Index-Seiten der verschiedenen Tabellen und bietet sowohl globale als auch gezielte Suchmöglichkeiten.

## Globale Suche

### Funktionsweise
Durch einfache Texteingabe kann gleichzeitig an verschiedenen Stellen gesucht werden. Wo genau gesucht wird, ist abhängig vom Kontext der aktuellen Tabelle.

### Suchbereiche (Beispiel: Clubs)
Bei der Club-Suche wird in folgenden Feldern gesucht:
- **Name** - Vollständiger Clubname
- **Shortname** - Abgekürzter Clubname
- **Adresse** - Vollständige Clubadresse
- **Region.shortname** - Abgekürzter Regionsname
- **E-Mail** - Club-E-Mail-Adresse
- **CC-ID** - ClubCloud-Identifikator

### Intelligente Verknüpfungen
Die Suche nutzt intelligente Verknüpfungen zwischen verschiedenen Datenfeldern. So kann man beispielsweise:
- Nach "NBV" suchen und alle Clubs in der Region über die Verknüpfung `region.shortname` finden
- Nach einer spezifischen ClubCloud-ID suchen
- Nach Teilen von Adressen oder Namen suchen

### Mehrfach-Suche
Es können beliebig viele Textsegmente eingegeben werden. Die Begriffe werden "UND"-verknüpft, d.h. alle Textsegmente müssen in den gefundenen Tabellenzeilen vorkommen.

**Beispiel:**
- Suche nach "Wedel Billard" findet nur Clubs, die sowohl "Wedel" als auch "Billard" im Namen enthalten

## Gezielte Suche in Tabellenspalten

### Filter-Formular
Um es dem Anwender so einfach wie möglich zu machen, gibt es zu jedem Suchfeld ein Filter-Formular, welches durch Anklicken des Filter-Icons neben dem Suchfeld aktiviert wird.

### Suchfelder im Filter
Das Filter-Formular enthält:
1. **Globale Suchfeld** - Funktioniert wie oben beschrieben
2. **Zielgerichtete Felder** - Spezifische Suchkriterien für bestimmte Spalten
3. **Erweiterte Optionen** - Zusätzliche Suchparameter

### Verknüpfung der Bedingungen
Alle Bedingungen (globale Suche + zielgerichtete Suche) werden "UND"-verknüpft, um präzise Ergebnisse zu liefern.

## Spezielle Datentypen

### Datum-Suche
Bei Datumsfeldern werden spezielle Vergleichsoperatoren unterstützt:
- **=** - Exaktes Datum
- **<** - Vor dem angegebenen Datum
- **<=** - Vor oder am angegebenen Datum
- **>** - Nach dem angegebenen Datum
- **>=** - Nach oder am angegebenen Datum

#### Besondere Datumswerte
- **'today'** - Heutiges Datum
- **Standardverhalten** - Bei Datumssuchen wird standardmäßig eine Woche abgezogen
- **Beispiel:** `>today` bedeutet "von vor einer Woche bis in die Zukunft"

### Integer-Suche
Bei Zahlenfeldern werden folgende Vergleichsoperatoren unterstützt:
- **=** - Gleich
- **<** - Kleiner als
- **<=** - Kleiner oder gleich
- **>** - Größer als
- **>=** - Größer oder gleich

## Praktische Anwendungsbeispiele

### Club-Suche
```
Suchbegriff: "Hamburg"
Ergebnis: Alle Clubs in Hamburg oder mit "Hamburg" im Namen
```

### Turnier-Suche
```
Suchbegriff: "2024"
Ergebnis: Alle Turniere im Jahr 2024
```

### Spieler-Suche
```
Suchbegriff: "Müller"
Ergebnis: Alle Spieler mit dem Namen "Müller"
```

## Suchtipps

### Effektive Suche
1. **Beginnen Sie mit wenigen Zeichen** - Die Suche findet auch Teilbegriffe
2. **Nutzen Sie Abkürzungen** - Kurznamen werden oft besser gefunden
3. **Kombinieren Sie Begriffe** - Mehrere Suchbegriffe verfeinern die Ergebnisse
4. **Nutzen Sie die Filter** - Für komplexere Suchanfragen

### Häufige Fehler vermeiden
- **Zu spezifische Suche** - Beginnen Sie mit allgemeineren Begriffen
- **Falsche Schreibweise** - Achten Sie auf korrekte Schreibweise
- **Vergessen der Filter** - Nutzen Sie die erweiterten Suchoptionen

## Erweiterte Suchfunktionen

### Wildcard-Suche
Die Suche unterstützt automatisch Teilbegriffe, sodass Sie nicht den vollständigen Begriff eingeben müssen.

### Groß-/Kleinschreibung
Die Suche ist nicht case-sensitive, d.h. "hamburg" und "Hamburg" liefern die gleichen Ergebnisse.

### Akzent-Insensitive
Umlaute und Sonderzeichen werden korrekt behandelt.

## Technische Details

### Suchalgorithmus
- **Volltext-Suche** in allen relevanten Feldern
- **Fuzzy-Matching** für ähnliche Begriffe
- **Relevanz-Sortierung** der Ergebnisse

### Performance
- **Indizierte Suche** für schnelle Ergebnisse
- **Caching** häufig verwendeter Suchbegriffe
- **Lazy Loading** großer Ergebnismengen

## Fehlerbehebung

### Keine Ergebnisse gefunden
1. **Überprüfen Sie die Schreibweise**
2. **Vereinfachen Sie die Suchbegriffe**
3. **Nutzen Sie die Filter-Optionen**
4. **Kontaktieren Sie den Administrator**

### Langsame Suche
1. **Reduzieren Sie die Anzahl der Suchbegriffe**
2. **Nutzen Sie spezifischere Suchkriterien**
3. **Warten Sie bei großen Datenmengen**

## Zukünftige Erweiterungen

Geplante Verbesserungen der Suchfunktion:
- **Volltext-Suche** in Dokumenten und Notizen
- **Ähnlichkeitssuche** für verwandte Begriffe
- **Suchverlauf** für häufig verwendete Suchanfragen
- **Erweiterte Filter** für komplexe Datenstrukturen
- **Export-Funktionen** für Suchergebnisse

