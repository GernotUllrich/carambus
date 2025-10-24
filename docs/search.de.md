# Suche und Filter in Carambus

## Übersicht

Die Suche und Filterfunktion in Carambus ermöglicht schnelles und präzises Finden von Daten auf allen Index-Seiten. Das System kombiniert:
- **Freitext-Suche** für schnelles Finden
- **Strukturierte Filter** für präzise Abfragen
- **AND-Logik** für kombinierte Suche
- **Info-Tooltips** für einfache Bedienung

## Hauptsuchfeld

### Freitext-Suche mit AND-Logik
Geben Sie einen oder mehrere Begriffe in das Hauptsuchfeld ein. Alle Begriffe werden mit **UND** verknüpft.

**Beispiele:**
```
"Manfred Meyer" → findet Einträge die BEIDE Begriffe enthalten
"Meyer Berlin" → findet alle Meyers in Berlin
"Hamburg 2024" → findet Hamburg-bezogene Einträge aus 2024
```

**Wichtig:** Die **Reihenfolge ist egal!**
- "Manfred Meyer" = "Meyer Manfred" (gleiches Ergebnis)

### Suchbereiche (abhängig vom Kontext)

#### Spieler-Suche
Durchsucht:
- Vollständiger Name (Vor- und Nachname kombiniert)
- Vorname
- Nachname
- Nickname
- CC-ID (numerisch)

#### Club-Suche
Durchsucht:
- Clubname (vollständig und Kurzname)
- Adresse
- E-Mail
- Homepage
- Region (über Verknüpfung)
- CC-ID, BA-ID (numerisch)

#### Turnier-Suche
Durchsucht:
- Turniertitel
- Kurzname (Shortname)
- Saison
- Region/Veranstalter

### Intelligente Verknüpfungen
Die Suche nutzt automatisch Beziehungen zwischen Tabellen:
- **Spieler** → findet über Club → Region
- **Locations** → findet über Club → Region
- **Turniere** → findet über Saison, Region, Disziplin

## Filter-Formular

### Filter-Icon öffnen
Klicken Sie auf das **Filter-Icon** (⚙️) rechts neben dem Suchfeld, um das Filter-Formular zu öffnen.

### Aufbau des Filter-Formulars

#### 1. Allgemeine Suche
Freitext-Suche über alle relevanten Felder (wie im Hauptsuchfeld).

#### 2. Feldspezifische Filter
Jedes Feld hat einen eigenen Filter mit:
- **Info-Icon** (ℹ️) - Zeigt Beschreibung und Beispiele beim Hover
- **Passender Input-Typ:**
  - **Dropdowns** für Referenzen (Region, Club, Season, etc.)
  - **Zahlenfelder** für IDs und numerische Werte
  - **Textfelder** für Namen, Adressen, etc.
  - **Datums-Picker** für Datumsfelder (touch-optimiert)

### Info-Tooltips verstehen

Bewegen Sie die Maus über ein **Info-Icon** (ℹ️), um zu sehen:
- **Beschreibung** des Feldes
- **Beispiel-Werte** für die Eingabe

**Beispiel-Tooltip:**
```
Numerische ID | Beispiele: 12345, 67890
```

### Kombinierte Suche

#### Freitext + Feldfilter kombinieren
Sie können **beide Sucharten gleichzeitig** nutzen:

**Im Hauptsuchfeld eingeben:**
```
Meyer region_id:1
```
Findet: Alle "Meyer" in Region 1

**Oder im Filter-Formular:**
- Allgemeine Suche: `Meyer`
- Region: `NBV` auswählen
- Anwenden klicken

Beide Wege führen zum gleichen Ergebnis!

### Verknüpfung der Bedingungen
Alle Bedingungen werden **UND-verknüpft**:
- Freitext-Begriffe untereinander (AND)
- Feldfilter untereinander (AND)
- Freitext + Feldfilter (AND)

## Feldspezifische Filter-Syntax

### Syntax im Hauptsuchfeld
Format: `feldname:wert`

**Beispiele:**
```
region_id:1           → Region mit ID 1
cc_id:12345          → CC-ID 12345
firstname:Hans       → Vorname "Hans"
date:>2024-01-01     → Datum nach 1. Januar 2024
```

### Mehrere Filter kombinieren
Trennen Sie Filter mit **Leerzeichen**:
```
Meyer region_id:1 season_id:5
```
Findet: Alle "Meyer" in Region 1 UND Saison 5

### Operatoren

#### Datum-Filter
```
date:2024-01-15      → Exakt dieses Datum
date:>2024-01-01     → Nach diesem Datum
date:>=2024-01-01    → Ab diesem Datum (inkl.)
date:<2024-12-31     → Vor diesem Datum
date:<=2024-12-31    → Bis zu diesem Datum (inkl.)
date:heute           → Heute (wird zu aktuellem Datum)
```

#### Zahlen-Filter
```
cc_id:12345          → Exakt diese ID
points:>100          → Mehr als 100 Punkte
innings:<=50         → Bis zu 50 Aufnahmen
```

#### Text-Filter
```
firstname:Hans       → Vorname enthält "Hans"
club:Berlin          → Club enthält "Berlin"
```

### Feldnamen-Referenz

Die wichtigsten Feldnamen für Filter:

**Allgemein:**
- `id` - Datensatz-ID
- `region_id` - Region-ID
- `season_id` - Saison-ID
- `club_id` - Club-ID

**IDs:**
- `cc_id` - ClubCloud-ID
- `ba_id` - Billard-Amateure-ID
- `dbu_id` - DBU-Nummer

**Namen:**
- `firstname` - Vorname
- `lastname` - Nachname
- `nickname` - Spitzname
- `name` - Name (allgemein)

**Datum:**
- `date` - Datum (Turnier, Party, etc.)

## Praktische Anwendungsbeispiele

### Spieler-Suche

**Einfache Suche:**
```
Müller               → Alle Spieler mit "Müller" im Namen
Manfred Meyer        → Spieler mit "Manfred" UND "Meyer" (AND-Logik)
Meyer Manfred        → Gleiches Ergebnis (Reihenfolge egal!)
```

**Mit Feldfiltern:**
```
Meyer region_id:1    → Alle Meyers in Region 1 (NBV)
Hans club_id:347     → Alle Hans'e im Club 347
cc_id:12345         → Spieler mit CC-ID 12345
```

**Filter-Formular nutzen:**
1. Filter-Icon klicken
2. Region: "NBV" auswählen
3. Firstname: "Hans" eingeben
4. "Anwenden" klicken

### Club-Suche

**Einfache Suche:**
```
Hamburg              → Alle Clubs in/mit "Hamburg"
Berlin Billard       → Clubs mit "Berlin" UND "Billard"
```

**Mit Feldfiltern:**
```
region_id:1          → Alle Clubs in Region 1
Hamburg region_id:1  → Hamburg-Clubs in Region 1
homepage:billard     → Clubs mit "billard" in der Homepage-URL
```

### Turnier-Suche

**Einfache Suche:**
```
Stadtmeisterschaft   → Alle Stadtmeisterschaften
Pokal 2024          → Pokal-Turniere aus 2024
```

**Mit Feldfiltern:**
```
season_id:5          → Turniere der Saison 5
Pokal region_id:1    → Pokal-Turniere in Region 1
date:>2024-01-01    → Turniere nach dem 1. Januar 2024
```

**Im Filter-Formular:**
1. Filter-Icon klicken
2. Season: Auswählen
3. Discipline: Auswählen
4. Date: Datum-Picker nutzen
5. "Anwenden" klicken

### Party (Spieltage) Suche

**Mit Cascading Filters:**
```
region_id:1          → Spieltage in Region 1
Liga region_id:1     → Liga-Spieltage in Region 1
```

**Im Filter-Formular (Cascading):**
1. Region auswählen → Season-Liste wird gefiltert
2. Season auswählen → League-Liste wird gefiltert
3. League auswählen → Party-Liste wird gefiltert

### PartyGame (Spieltagpartien) Suche

**Komplexe Suche:**
```
Meyer                → Alle Partien mit Spieler "Meyer"
Meyer region_id:1    → Meyer-Partien in Region 1
Liga 1 Meyer         → Meyer in Liga 1
```

## Suchtipps & Best Practices

### Effektive Suche
1. **Beginnen Sie einfach** - Ein Begriff reicht oft
   ```
   Meyer    → findet alle Meyers
   ```

2. **Verfeinern mit AND** - Fügen Sie weitere Begriffe hinzu
   ```
   Meyer Hans    → nur Hans Meyers
   ```

3. **Nutzen Sie Feldfilter** - Für präzise Abfragen
   ```
   Meyer region_id:1    → Meyers in bestimmter Region
   ```

4. **Kombinieren Sie alles** - Freitext + mehrere Filter
   ```
   Hans Berlin region_id:1 club_id:347
   ```

5. **Nutzen Sie Info-Icons** - Hover über ℹ️ für Hilfe und Beispiele

### Touch-Bedienung

#### Auf Tablets/Smartphones:
1. **Dropdowns** - Große Touch-Targets für Referenzen
2. **Datums-Picker** - Native OS-Picker (iOS/Android)
3. **Filter-Formular** - Scrollbar bei vielen Feldern
4. **Ohne Tastatur** - Meiste Filter per Touch bedienbar

### Häufige Fehler vermeiden

❌ **Falsch:** Zu viele Filter gleichzeitig
```
Meyer Hans Berlin NBV 2024 Club
```
→ Findet vermutlich nichts

✅ **Richtig:** Schrittweise verfeinern
```
Schritt 1: Meyer        → 500 Treffer
Schritt 2: Meyer Hans   → 50 Treffer  
Schritt 3: Meyer Hans region_id:1  → 5 Treffer
```

❌ **Falsch:** Exakte Phrase suchen (funktioniert nicht mehr)
```
"Hans Meyer"    (mit Anführungszeichen)
```

✅ **Richtig:** Einfach Begriffe eingeben
```
Hans Meyer      (ohne Anführungszeichen, AND-Logik)
```

## Erweiterte Suchfunktionen

### Automatische Teilbegriff-Suche
Die Suche findet **automatisch Teilbegriffe** - Sie müssen nicht den vollständigen Begriff eingeben.

**Beispiele:**
```
Ham      → findet "Hamburg", "Hamm", "Hamborn"
Mey      → findet "Meyer", "Meyerhofer", "Meyers"
```

### Groß-/Kleinschreibung
Die Suche ist **case-insensitive**:
```
hamburg = Hamburg = HAMBURG    (gleiche Ergebnisse)
meyer = Meyer = MEYER          (gleiche Ergebnisse)
```

### Umlaute und Sonderzeichen
Umlaute und Sonderzeichen werden korrekt behandelt:
```
Müller = Müller    (exakte Suche)
Straße = Straße    (ß wird als ß behandelt)
```

### Cascading Filters (Abhängige Filter)

Einige Filter beeinflussen andere automatisch:

#### Spieler, Locations, SeasonParticipation
```
Region auswählen → Club-Liste zeigt nur Clubs dieser Region
```

#### Party, PartyGame
```
Region auswählen → Season-Liste gefiltert
Season auswählen → League-Liste gefiltert
League auswählen → Party-Liste gefiltert
```

**Tipp:** Nutzen Sie das Filter-Formular für Cascading - die Dropdowns aktualisieren sich automatisch!

## Feldtypen im Filter-Formular

### Versteckte Felder
Einige technische Felder (z.B. interne IDs) werden **nicht im Filter-Formular angezeigt**, 
funktionieren aber im Hauptsuchfeld:

**Beispiele versteckter Felder:**
- `id` - Datensatz-ID (intern)
- `region_id` - Region-ID (intern, nutzen Sie stattdessen Region-Dropdown)
- `club_id` - Club-ID (intern, nutzen Sie stattdessen Club-Dropdown)

**Warum versteckt?**
- Vereinfacht die UI (weniger Felder)
- Nur relevante Felder sichtbar
- Funktioniert trotzdem im Hauptsuchfeld mit `feldname:wert` Syntax

### Sichtbare Feldtypen

#### 1. Referenz-Felder (Dropdowns)
**Beispiele:** Region, Club, Season, League, Discipline

**Verwendung:**
- Im Filter-Formular: Dropdown-Liste zum Auswählen
- Im Hauptsuchfeld: Nutzen Sie die ID-Variante (`region_id:1`)

#### 2. Zahlenfelder
**Beispiele:** CC_ID, BA_ID, DBU_ID, Points, Result, Innings

**Verwendung:**
- Im Filter-Formular: Operator-Dropdown + Zahleneingabe
- Im Hauptsuchfeld: `cc_id:12345` oder `points:>100`

#### 3. Textfelder
**Beispiele:** Firstname, Lastname, Name, Address, Email

**Verwendung:**
- Im Filter-Formular: Texteingabe
- Im Hauptsuchfeld: `firstname:Hans` oder einfach `Hans`

#### 4. Datumsfelder
**Beispiele:** Date, Created At, Updated At

**Verwendung:**
- Im Filter-Formular: Native Datums-Picker (touch-optimiert)
- Im Hauptsuchfeld: `date:2024-01-15` oder `date:>2024-01-01`

## Technische Details

### Such-Algorithmus
- **AND-Logik** bei mehreren Begriffen (alle müssen vorkommen)
- **ILIKE** für case-insensitive Teilbegriff-Suche
- **LEFT JOIN** für Verknüpfungen zwischen Tabellen
- **DISTINCT** wo nötig (verhindert Duplikate)

### Performance
- **Datenbank-Indizes** für schnelle ID-Suchen
- **Eager Loading** von Assoziationen (vermeidet N+1 Queries)
- **Pagination** für große Ergebnismengen
- **Optimierte JOINs** für komplexe Abfragen

## Fehlerbehebung

### Keine Ergebnisse gefunden

**Mögliche Ursachen:**

1. **Zu restriktive Filter**
   ```
   Problem: Meyer Hans Berlin region_id:1 club_id:347
   Lösung: Entfernen Sie einige Filter
   ```

2. **Tippfehler**
   ```
   Problem: Mayer (falsch)
   Lösung: Meyer (richtig)
   ```

3. **Falsche Region/Season ausgewählt**
   - Lösung: Filter zurücksetzen und neu beginnen

4. **Cascading Filter nicht aktualisiert**
   - Lösung: Seite neu laden (Browser refresh)

### Unerwartete Ergebnisse

**Problem:** Zu viele Treffer
```
Beispiel: Suche "Meyer" findet 500 Spieler
Lösung: Verfeinern mit region_id:1 oder firstname:Hans
```

**Problem:** Feldfilter funktioniert nicht
```
Prüfen: Ist der Feldname korrekt? (siehe Feldnamen-Referenz)
Tipp: Nutzen Sie Info-Icons (ℹ️) für korrekte Syntax
```

### Filter zurücksetzen

**Im Filter-Formular:**
- Klicken Sie auf den **"Zurücksetzen"** Button

**Im Hauptsuchfeld:**
- Löschen Sie den Text manuell
- Oder: `Cmd+A` (alles markieren) → `Delete`

## Tastenkombinationen

### Schnellzugriff
- **Tab** - Zwischen Feldern wechseln
- **Enter** - Filter anwenden / Suche starten
- **Esc** - Filter-Popup schließen

### Im Hauptsuchfeld
- **Enter** - Suche ausführen
- **Cmd+A / Ctrl+A** - Alles markieren
- **Backspace** - Suche löschen

## FAQ - Häufig gestellte Fragen

### Warum finde ich "Manfred Meyer" nicht?
✅ **Lösung:** Stellen Sie sicher, dass AND-Logik aktiviert ist (seit Oktober 2024 Standard).
Die Suche findet jetzt Einträge, die BEIDE Begriffe enthalten.

### Wie funktioniert "Meyer region_id:1"?
✅ Das ist **gemischte Suche**: Freitext ("Meyer") + Feldfilter ("region_id:1").
Beide Bedingungen werden UND-verknüpft.

### Warum sehe ich weniger Felder im Filter?
✅ **Das ist gewollt!** Technische ID-Felder sind jetzt versteckt, um die UI zu vereinfachen.
Sie funktionieren aber weiterhin im Hauptsuchfeld.

### Was bedeuten die Info-Icons (ℹ️)?
✅ Bewegen Sie die Maus darüber (Hover), um Beschreibung und Beispiele zu sehen.
Hilft beim Verständnis, welche Werte eingegeben werden können.

### Wie funktioniert Cascading?
✅ **Cascading Filters** filtern abhängige Listen automatisch:
- Region auswählen → Club-Liste zeigt nur Clubs dieser Region
- Season auswählen → League-Liste zeigt nur Ligen dieser Saison

## Modell-spezifische Besonderheiten

### Spieler (Player)
- Durchsucht auch kombinierte Namen (`fl_name`)
- Region → Club Cascading aktiv
- CC_ID und DBU_ID als Zahlenfelder

### Spieltagpartien (PartyGame)
- **Komplexestes Cascading:** Region → Season → League → Party
- Player A und Player B separat durchsuchbar
- Viele versteckte ID-Felder (6 versteckt, 8 sichtbar)

### Turnierteilnahmen (Seeding)
- Unterstützt Turniere UND Ligen (polymorphisch)
- Komplexe JOINs für Season/Region
- Position und Status filterbar

### Partien (GameParticipation)
- Viele numerische Filter (Points, Result, GD, HS, Innings)
- Operatoren für Vergleiche (>, <, =, >=, <=)
- Rolle filterbar (home, guest, playera, playerb)

## Zukünftige Erweiterungen

Geplante Verbesserungen:
- **Quick-Filter-Chips** oberhalb der Tabelle ("Meine Region", "Aktuelle Saison")
- **Gespeicherte Filter** für häufig verwendete Kombinationen
- **Filter-Presets** ("Letzte 30 Tage", "Meine Spieler")
- **Export** von gefilterten Ergebnissen
- **Filter-Historie** (zuletzt verwendete Filter)

## Support

Bei Problemen mit der Suche:
1. Prüfen Sie diese Dokumentation
2. Nutzen Sie die Info-Icons (ℹ️) im Filter-Formular
3. Kontaktieren Sie den Administrator

---

**Letzte Aktualisierung:** Oktober 2024 (neue Filter-Architektur)

