# UMB Scraping Methoden - Übersicht

## Verfügbare Rake Tasks

### ⭐ Option 0: Incremental Update (NEU - BESTE Methode für laufende Systeme)
```bash
rake umb:update RAILS_ENV=production
```

**Vorteile:**
- ✅ Kombiniert alle Strategien (Future + New IDs + Updates)
- ✅ **Fixt automatisch fehlende Organizer** (alle UMB Turniere bekommen UMB als Organizer)
- ✅ Updated kürzliche Turniere mit neuen Ergebnissen
- ✅ Findet neue Turniere über aktuelles Maximum hinaus
- ✅ Intelligent & effizient (nur was nötig ist)

**Was wird automatisch gefixt:**
- Fehlende Organizer (setzt UMB als Organizer für alle Turniere ohne Organizer)
- Neue zukünftige Turniere werden erkannt
- Bestehende Turniere werden mit aktuellen Ergebnissen aktualisiert

**Verwendung:** Für regelmäßige Updates (z.B. täglich/wöchentlich)

---

### Option 1: Import All (Schnellste Methode für Initial Import)
```bash
rake umb:import_all RAILS_ENV=production
```

**Vorteile:**
- ✅ Schnellste Methode (überspringt nicht-existierende IDs)
- ✅ Importiert alle bekannten Tournament IDs
- ✅ Sortiert nach neuestem zuerst
- ✅ Vollständiger Import (Tournaments + Games + Seedings)

**Verwendung:** Für Production Deployment empfohlen

---

### Option 2: Archiv-Scraping (Sequentiell)
```bash
# Phase 1: Tournaments erstellen (ID-Range)
rake umb:scrape_archive[1,500] RAILS_ENV=production

# Phase 2: Details scrapen (Games, Players, Seedings)
rake umb:scrape_all_details RAILS_ENV=production
```

**Vorteile:**
- ✅ Findet auch "versteckte" IDs in Lücken
- ✅ 2-Phasen-Ansatz (erst Tournaments, dann Details)

**Nachteile:**
- ❌ Langsamer (prüft jede ID einzeln)
- ❌ Zwei separate Befehle notwendig

**Verwendung:** Wenn Sie sicherstellen wollen, dass wirklich ALLE IDs gecheckt wurden

---

### Option 3: UMB Scraper V2 (EXPERIMENTAL)
```bash
# Einzelnes Tournament testen
rake umb_v2:scrape[310] RAILS_ENV=production

# ID-Range scrapen
rake umb_v2:scrape_range[300,400] RAILS_ENV=production
```

**Besonderheiten:**
- ✅ Verbessertes KO-Runden-Parsing
- ✅ Moderne Code-Struktur (Umb:: services)
- ⚠️ Noch in Entwicklung

**Verwendung:** Für spezielle Fälle oder Testing

---

### Einzelne Tournaments neu scrapen
```bash
# Einzelnes Tournament
rake umb:scrape_tournament_details[375] RAILS_ENV=production

# Mehrere Tournaments (für Debugging)
rake umb:debug_import[375,376,377] RAILS_ENV=production
```

---

## Zusätzliche Hilfreiche Tasks

### Status & Diagnose
```bash
# Umfassender Status-Report (NEU - empfohlen!)
rake umb:status RAILS_ENV=production

# Detaillierte Statistiken
rake umb:stats RAILS_ENV=production
rake umb_v2:stats RAILS_ENV=production
```

### Neue Turniere finden
```bash
# Nur checken (ohne Import) - NEU!
rake umb:check_new RAILS_ENV=production
```

### Fehlende Daten nachträglich fixen
```bash
# Organizer fixen (WICHTIG wenn "organizer not set" Error!)
rake umb:fix_organizers RAILS_ENV=production

# Fehlende Locations nachträglich scrapen
rake umb:rescrape_missing_locations RAILS_ENV=production

# Disciplines automatisch korrigieren
rake umb:fix_disciplines RAILS_ENV=production

# Location/Season für alle UMB Tournaments fixen
rake umb:fix_tournaments RAILS_ENV=production
```

### Discipline-Analyse
```bash
rake umb:discipline_stats RAILS_ENV=production
```

---

## Empfohlener Workflow für Production

### Erstmaliges Deployment (Fresh Install)

```bash
# 1. Placeholder Records erstellen
rake placeholders:create RAILS_ENV=production

# 2. UMB Tournaments importieren (EMPFOHLEN)
rake umb:import_all RAILS_ENV=production

# 3. Statistiken prüfen
rake umb:stats RAILS_ENV=production
rake placeholders:stats RAILS_ENV=production

# 4. Optional: Disciplines automatisch korrigieren
rake umb:fix_disciplines RAILS_ENV=production

# 5. Incomplete Records im Admin Interface nachbearbeiten
# https://your-domain/admin/incomplete_records
```

### Laufendes System (Update) - EMPFOHLEN

```bash
# BESTE METHODE: Inkrementelles Update (kombiniert alle Strategien)
rake umb:update RAILS_ENV=production

# Nur Status anzeigen (ohne Änderungen)
rake umb:status RAILS_ENV=production

# Nur neue Tournaments checken (ohne Import)
rake umb:check_new RAILS_ENV=production

# Nur Organizer fixen
rake umb:fix_organizers RAILS_ENV=production
```

**Was macht `umb:update`?**
1. ✅ Scraped zukünftige Turniere von UMB Website
2. ✅ Sucht nach neuen Tournament IDs (über aktuelles Maximum hinaus)
3. ✅ Fixt fehlende Organizer (UMB Region)
4. ✅ Updated kürzliche Turniere mit Ergebnissen (letzte 2 Jahre)
5. ✅ Rate limiting & Error handling

**Alternative (bei Problemen):**
```bash
# Manuell: Nur neue/zukünftige Tournaments
rake umb:scrape_future RAILS_ENV=production

# Manuell: Erneuter kompletter Import (überschreibt Updates)
rake umb:import_all RAILS_ENV=production
```

---

## Was wird automatisch erstellt?

Der UMB Scraper (`umb:import_all` und `umb:scrape_archive`) erstellt automatisch:

### 1. Locations
```
"Nice (France)" → Location: Nice, Country: FR
"Ho Chi Minh City (Vietnam)" → Location: Ho Chi Minh City, Country: VN
```

### 2. Seasons
```
Starts on: 15-January-2009 → Season: 2008/2009 (Juli-basiert)
Starts on: 01-August-2024 → Season: 2024/2025
```

### 3. Organizer
```
Alle UMB Tournaments → Organizer: Region "Union Mondiale de Billard" (UMB)
```

### 4. Disciplines
```
"3-Cushion World Cup" → Discipline: Dreiband groß
"Cadre 47/2 World Cup" → Discipline: Cadre 47/2
```

### 5. Fallback zu Placeholders
Wenn etwas nicht erkannt werden kann:
- → Unknown Location
- → Unknown Season  
- → Unknown Discipline
- → Unknown Region (Organizer)

Diese können später im Admin Interface `/admin/incomplete_records` korrigiert werden.

---

## Performance

### umb:import_all
- ~311 Tournaments (bekannte IDs)
- ~5-10 Minuten (abhängig von Netzwerk)
- Überspringt nicht-existierende IDs automatisch

### umb:scrape_archive[1,500]
- Prüft jede ID von 1-500 sequentiell
- ~30-60 Minuten (viele IDs existieren nicht)
- Findet auch "versteckte" Tournaments

### umb:scrape_all_details
- Nur für Tournaments ohne Details (Games/Seedings)
- ~10-20 Minuten

---

## Troubleshooting

### "Don't know how to build task 'umb:scrape_overview'"
✅ **Lösung:** Verwenden Sie stattdessen `rake umb:import_all`

### Timeout-Errors beim Scraping
```bash
# Kleinere Batches verwenden
rake umb:scrape_archive[1,100] RAILS_ENV=production
rake umb:scrape_archive[101,200] RAILS_ENV=production
# etc.
```

### Fehlende Locations/Seasons
```bash
# Automatisch nachträglich fixen
rake umb:fix_tournaments RAILS_ENV=production
```

### Falsche Disciplines
```bash
# Automatische Korrektur basierend auf Tournament-Titeln
rake umb:fix_disciplines RAILS_ENV=production
```

---

## Zusammenfassung

### Für Initial Production Deployment:
```bash
rake placeholders:create RAILS_ENV=production  # ERST!
rake umb:import_all RAILS_ENV=production       # DANN!
rake umb:fix_organizers RAILS_ENV=production   # UMB Organizer setzen
```

### Für laufende Systeme (regelmäßige Updates):
```bash
# Einmal pro Woche/Monat ausführen:
rake umb:update RAILS_ENV=production

# Oder nur Status checken:
rake umb:status RAILS_ENV=production
```

**Das war's!** 🎉

### Quick Troubleshooting

**Problem: "organizer UMB not set" Fehler**
```bash
rake umb:fix_organizers RAILS_ENV=production
```

**Problem: Keine zukünftigen Turniere**
```bash
rake umb:update RAILS_ENV=production  # Scraped future tournaments
```

**Problem: Veraltete Ergebnisse**
```bash
rake umb:update RAILS_ENV=production  # Updated recent tournaments
```

Danach optional Statistiken prüfen und im Admin-Interface `/admin/incomplete_records` nachbearbeiten.
