# KI-gestützte Suche

Die KI-gestützte Suche ermöglicht die Verwendung natürlicher deutscher Sprache, um Daten in Carambus zu finden. Die Funktion nutzt OpenAI's GPT-4o-mini Modell, um Suchanfragen in strukturierte Filter-Syntax zu übersetzen.

## 📋 Inhaltsverzeichnis

- [Setup](#setup)
- [Verwendung](#verwendung)
- [Beispiele](#beispiele)
- [Unterstützte Entities](#unterstützte-entities)
- [Filter-Syntax](#filter-syntax)
- [Troubleshooting](#troubleshooting)
- [Kosten](#kosten)

## 🚀 Setup

### OpenAI API Key hinzufügen

1. **OpenAI API Key besorgen**
   - Account auf https://platform.openai.com erstellen
   - API Key unter "API Keys" generieren
   - Key kopieren (beginnt mit `sk-...`)

2. **Key in Rails Credentials einfügen**

   ```bash
   cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
   EDITOR="code --wait" rails credentials:edit --environment development
   ```

3. **Folgende Zeilen hinzufügen:**

   ```yaml
   openai:
     api_key: sk-your-actual-api-key-here
   ```

4. **Speichern und schließen**
   - Datei speichern (Cmd+S in VS Code)
   - Editor schließen
   - Rails verschlüsselt die Credentials automatisch

5. **Für Production** (auf dem API-Server):

   ```bash
   EDITOR="nano" rails credentials:edit --environment production
   ```

## 💡 Verwendung

### Zugriff

1. **KI-Assistent Button** in der linken Navigation (zwischen Logo und Menü)
2. Button zeigt ein ✨ Sparkle-Icon
3. Klick öffnet das Suchfeld

### Suchanfrage stellen

1. Anfrage in natürlicher deutscher Sprache eingeben
2. Enter drücken oder "Suchen" klicken
3. KI analysiert die Anfrage (1-3 Sekunden)
4. Automatische Navigation zur Ergebnis-Seite

### Beispiel-Workflow

```
Eingabe: "Turniere in Hamburg letzte 2 Wochen"
        ↓
KI analysiert...
        ↓
Übersetzt zu: "Region:HH Date:>heute-2w"
        ↓
Navigiert zu: /tournaments?sSearch=Region:HH+Date:>heute-2w
```

## 📝 Beispiele

### Turniere finden

```
"Turniere in Hamburg"
→ tournaments mit Filter: Region:HH

"Dreiband Turniere 2024"
→ tournaments mit Filter: Discipline:Dreiband Season:2024/2025

"Turniere letzte 2 Wochen"
→ tournaments mit Filter: Date:>heute-2w

"Freie Partie in Westfalen heute"
→ tournaments mit Filter: Discipline:Freie Partie Region:WL Date:heute

"Turniere im BC Wedel"
→ tournaments mit Filter: Location:"BC Wedel"

"Turniere im BC Wedel Saison 2025"
→ tournaments mit Filter: Location:"BC Wedel" Season:2025/2026
```

### Spieler finden

```
"Alle Spieler aus Westfalen"
→ players mit Filter: Region:WL

"Meyer Hamburg"
→ players mit Filter: Meyer Region:HH

"Spieler aus Berlin Saison 2024"
→ players mit Filter: Region:BE Season:2024/2025
```

### Vereine finden

```
"Vereine in Hamburg"
→ clubs mit Filter: Region:HH

"Clubs Westfalen"
→ clubs mit Filter: Region:WL
```

### Spieltage und Ligen

```
"Spieltage letzte Woche"
→ parties mit Filter: Date:>heute-1w

"Mannschaftsspiele heute"
→ party_games mit Filter: Date:heute

"Spieltage Hamburg 2024"
→ parties mit Filter: Region:HH Season:2024/2025
```

## 🎯 Unterstützte Entities

Die KI kann folgende Datentypen durchsuchen:

| Entity | Deutsche Namen | Häufige Filter |
|--------|---------------|----------------|
| `players` | Spieler, Player, Teilnehmer | Region, Club, Firstname, Lastname, Season |
| `clubs` | Vereine, Clubs, Verein | Region, Name |
| `tournaments` | Turniere, Turnier, Veranstaltung | Season, Region, Discipline, Date, Title, Location |
| `locations` | Spielorte, Locations, Orte | Region, Name, City |
| `regions` | Regionen, Region, Landesverbände | Shortname, Name |
| `seasons` | Saisons, Saison, Spielzeit | Name |
| `season_participations` | Saisonteilnahmen | Season, Player, Club, Region |
| `parties` | Spieltage, Spieltag, Partien | Season, League, Date, Region |
| `game_participations` | Spielteilnahmen | Player, Game, Season |
| `seedings` | Setzungen, Turnierteilnahmen | Tournament, Player, Season, Discipline |
| `party_games` | Mannschaftsspiele | Party, Player, Date |
| `disciplines` | Disziplinen | Name |

## 🔍 Filter-Syntax

Die KI übersetzt Ihre Anfrage in folgende Filter-Syntax:

### Regionen (Kürzel verwenden!)

```
Region:WL   → Westfalen-Lippe
Region:HH   → Hamburg
Region:BE   → Berlin
Region:BY   → Bayern
Region:NI   → Niedersachsen
Region:BW   → Baden-Württemberg
Region:HE   → Hessen
Region:NW   → Nordrhein-Westfalen
Region:RP   → Rheinland-Pfalz
Region:SH   → Schleswig-Holstein
Region:SL   → Saarland
```

### Disziplinen

```
Discipline:Freie Partie
Discipline:Dreiband
Discipline:Einband
Discipline:Cadre
Discipline:Pool
Discipline:Snooker
```

### Locations (Spielorte)

```
# Für Werte mit Leerzeichen: Anführungszeichen verwenden
Location:"BC Wedel"
Location:"Billard-Centrum Hamburg"

# Alternativ: Wenn der Name eindeutig ist
Location:Wedel
Location:Hamburg
```

### Seasons

```
Season:2024/2025
Season:2023/2024
```

### Datum (relativ und absolut)

```
# Relativ
Date:heute              → heute
Date:>heute-2w          → nach vor 2 Wochen
Date:<heute+7           → vor in 7 Tagen
Date:>heute-1m          → nach vor 1 Monat

# Einheiten
d = Tage
w = Wochen  
m = Monate

# Absolut
Date:>2025-01-01
Date:<2025-12-31
Date:2025-10-24
```

### Freitext

```
Meyer                   → Sucht "Meyer" in allen Textfeldern
Dreiband Hamburg        → Kombiniert mehrere Suchbegriffe mit AND-Logik
```

### Kombination (mehrere Filter)

```
Season:2024/2025 Region:HH                  → Saison UND Region
Discipline:Dreiband Date:>heute-2w          → Disziplin UND Datum
Meyer Region:WL Season:2024/2025            → Freitext UND Filter
Location:"BC Wedel" Season:2025/2026        → Location mit Leerzeichen UND Saison
```

### Wichtig: Werte mit Leerzeichen

Wenn ein Filterwert Leerzeichen enthält (z.B. Spielortnamen), **müssen** Anführungszeichen verwendet werden:

```
✅ Richtig:
Location:"BC Wedel" Season:2025/2026
Discipline:"Freie Partie" Region:HH

❌ Falsch (wird nicht korrekt geparst):
Location:BC Wedel Season:2025/2026
→ Wird interpretiert als: Location:BC + Freitext "Wedel" + Season:2025/2026
```

Sie können sowohl `"` als auch `'` verwenden:
```
Location:"BC Wedel"
Location:'BC Wedel'
```

## 🔧 Troubleshooting

### "OpenAI nicht konfiguriert"

**Problem:** API Key fehlt in credentials  
**Lösung:** Setup-Schritte oben befolgen, API Key hinzufügen

### "Die KI konnte Ihre Anfrage nicht verstehen"

**Problem:** Anfrage zu vage oder mehrdeutig  
**Lösung:** 
- Genauer formulieren: "Turniere" statt "Veranstaltungen"
- Region/Disziplin/Zeitraum explizit nennen
- Beispiele als Vorlage nutzen

### Niedrige Confidence (<70%)

**Problem:** KI ist unsicher  
**Lösung:**
- Eindeutigere Begriffe verwenden
- Mehr Kontext geben
- Direkt die Filter-Syntax verwenden (in normalem Suchfeld)

### Falsche Entity erkannt

**Problem:** Suche nach "Spieler" führt zu "Turnieren"  
**Lösung:**
- Klarer formulieren: "Alle Spieler aus..." statt "Spieler Hamburg"
- Entity-Namen aus Tabelle oben verwenden

## 💰 Kosten

Die Nutzung von OpenAI GPT-4o-mini ist **sehr günstig**:

| Aktion | Input Tokens | Output Tokens | Kosten |
|--------|-------------|---------------|---------|
| 1 Anfrage | ~500 | ~100 | ~€0.0001 |
| 1000 Anfragen/Monat | - | - | ~€0.08 |
| 10.000 Anfragen/Monat | - | - | ~€0.80 |

**Hinweis:** Die tatsächlichen Kosten sind minimal und für normale Nutzung vernachlässigbar.

### Kostenüberwachung

OpenAI Dashboard zeigt Echtzeit-Nutzung: https://platform.openai.com/usage

## 📊 Technische Details

### Architektur

```
User Input (Deutsch)
        ↓
Stimulus Controller (ai_search_controller.js)
        ↓
POST /api/ai_search
        ↓
AiSearchController
        ↓
AiSearchService
        ↓
OpenAI GPT-4o-mini (JSON Response)
        ↓
Filter-Syntax
        ↓
Navigation zu gefilterten Ergebnissen
```

### Service-Struktur

```ruby
AiSearchService.call(
  query: "Turniere in Hamburg",
  user: current_user
)

# Returns:
{
  success: true,
  entity: "tournaments",
  filters: "Region:HH",
  confidence: 95,
  explanation: "Suche nach Turnieren in Hamburg",
  path: "/tournaments?sSearch=Region:HH"
}
```

### System-Prompt

Der KI-Service nutzt einen optimierten System-Prompt:
- Deutsche Billard-Terminologie (Dreiband, Freie Partie, etc.)
- Carambus Entity-Mapping
- Filter-Syntax mit Beispielen
- JSON Schema Enforcement
- Context über verfügbare Regionen und Disziplinen

### Sicherheit

- ✅ User Authentication erforderlich
- ✅ CSRF-Protection
- ✅ API Key verschlüsselt in Rails Credentials
- ✅ Input Sanitization
- ✅ Error Handling mit Fallbacks

## 🎓 Best Practices

### Gute Anfragen

✅ "Turniere in Hamburg letzte 2 Wochen"  
✅ "Dreiband Spieler aus Berlin"  
✅ "Freie Partie Saison 2024/2025"  
✅ "Spieltage Hamburg heute"

### Weniger gute Anfragen

❌ "Sachen" (zu vage)  
❌ "Irgendwas mit Billard" (nicht spezifisch)  
❌ "Alle Daten" (keine Filter)

### Tipps

1. **Spezifisch sein:** Region/Disziplin/Zeitraum erwähnen
2. **Standard-Begriffe nutzen:** "Turnier" statt "Event"
3. **Kombinieren:** Mehrere Filter in einer Anfrage möglich
4. **Bei Unsicherheit:** Beispiele als Vorlage nehmen

## 📚 Weiterführende Links

- [OpenAI Platform](https://platform.openai.com)
- [GPT-4o-mini Pricing](https://openai.com/pricing)
- [Carambus Filter-Dokumentation](../search.md)

## 🤝 Support

Bei Problemen oder Fragen:
1. Troubleshooting-Sektion oben prüfen
2. Log-Files checken: `log/development.log` oder `log/production.log`
3. GitHub Issues erstellen

---

**Version:** 1.0.0  
**Letzte Aktualisierung:** Oktober 2024  
**Status:** MVP (Minimum Viable Product)

