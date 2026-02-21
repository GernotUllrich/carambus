# Deployment Checklist für carambus_api Production

## Vor dem Deployment (auf Production Server)

### 1. Backup erstellen
```bash
# PostgreSQL Dump erstellen
pg_dump carambus_api_production > backup_before_deployment_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Code deployen (von Development)
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
git push  # bereits erledigt
```

### 3. Auf Production Server: Code pullen
```bash
cd /path/to/carambus_api_production
git pull origin master
```

## Deployment Steps auf Production

### 4. Bundle und Assets
```bash
bundle install
rake assets:precompile RAILS_ENV=production
```

### 5. Datenbank Migrationen
```bash
# Migrationen ausführen (STI + Videos Tabelle)
rake db:migrate RAILS_ENV=production
```

**Wichtige Migrationen:**
- `20260218185613_add_sti_fields_to_tournaments.rb` - STI für Tournaments
- `20260218193951_create_videos.rb` - Videos Tabelle erstellen

### 6. Placeholder Records erstellen
```bash
# KRITISCH: Diese müssen VOR dem Scraping existieren!
rake placeholders:create RAILS_ENV=production
```

**Erstellt:**
- Unknown Season
- Unknown Discipline  
- Unknown Location
- Unknown Region
- Unknown Club

### 7. Optional: Bestehende Daten migrieren
```bash
# Falls alte Tournaments bereits .first verwenden, migrieren:
rake placeholders:migrate_to_placeholders RAILS_ENV=production
```

### 8. Server neu starten
```bash
# Je nach Setup:
sudo systemctl restart puma-carambus_api
# oder
touch tmp/restart.txt
```

## Nach dem Deployment: Scraping durchführen

### 9. YouTube Videos scrapen
```bash
# Alle YouTube-Quellen neu scrapen
rake youtube:scrape_all RAILS_ENV=production

# Oder einzeln:
rake youtube:scrape[1] RAILS_ENV=production  # Kozoom
rake youtube:scrape[2] RAILS_ENV=production  # Carom Café
# etc.
```

### 10. UMB Tournaments scrapen
```bash
# Option A: Import aller bekannten IDs (empfohlen, schneller)
rake umb:import_all RAILS_ENV=production

# Option B: Sequentielles Scraping (langsamer, aber vollständig)
rake umb:scrape_archive[1,500] RAILS_ENV=production
rake umb:scrape_all_details RAILS_ENV=production

# Option C: Mit UMB Scraper V2 (neuer Scraper mit verbessertem KO-Parsing)
rake umb_v2:scrape_range[300,400] RAILS_ENV=production
```

**Empfehlung:** Verwenden Sie `umb:import_all` - das ist am schnellsten und überspringt automatisch nicht existierende IDs.

**Wichtig:** UMB Scraper erstellt jetzt automatisch:
- Locations aus "Place: City (Country)"
- Seasons basierend auf "Starts on" Datum
- Organizer "UMB" (Union Mondiale de Billard)

### 11. Status prüfen
```bash
# Placeholder Statistiken
rake placeholders:stats RAILS_ENV=production

# Incomplete Records auflisten
rake placeholders:list_incomplete RAILS_ENV=production
```

### 12. Automatische Fixes (optional)
```bash
# Disciplines automatisch korrigieren basierend auf Tournament-Titeln
rake placeholders:auto_fix_disciplines RAILS_ENV=production
```

## Nach dem Scraping: Admin Interface

### 13. Incomplete Records manuell nachbearbeiten
```
https://your-production-url/admin/incomplete_records
```

Hier können verbleibende Tournaments mit Placeholder-Referenzen manuell korrigiert werden:
- Season auswählen
- Location erstellen/zuweisen
- Discipline korrigieren
- Organizer zuweisen

## Monitoring & Troubleshooting

### Logs überwachen
```bash
tail -f log/production.log
```

### Wichtige Checks
```bash
# Video Count
rails runner "puts 'Videos: ' + Video.count.to_s" RAILS_ENV=production

# Tournament Count
rails runner "puts 'Tournaments: ' + InternationalTournament.count.to_s" RAILS_ENV=production

# Placeholder Usage
rake placeholders:stats RAILS_ENV=production
```

### Falls Probleme auftreten
```bash
# Rollback zur letzten Migration
rake db:rollback RAILS_ENV=production

# Datenbank aus Backup wiederherstellen
psql carambus_api_production < backup_before_deployment_TIMESTAMP.sql

# Server-Logs prüfen
tail -n 100 log/production.log
```

## Zusammenfassung der Reihenfolge

1. ✅ Backup erstellen
2. ✅ Code deployen & pullen
3. ✅ Bundle & Assets
4. ✅ **DB Migrationen** (`rake db:migrate`)
5. ✅ **Placeholder Records erstellen** (`rake placeholders:create`) - **KRITISCH!**
6. ✅ Server neu starten
7. ✅ **YouTube scrapen** (`rake youtube:scrape_all`)
8. ✅ **UMB scrapen** (`rake umb:import_all` oder `rake umb:scrape_archive[1,500]` + `rake umb:scrape_all_details`)
9. ✅ Status prüfen (`rake placeholders:stats`)
10. ✅ Admin Interface nutzen (`/admin/incomplete_records`)

## Wichtige Hinweise

⚠️ **KRITISCH:** `rake placeholders:create` muss VOR dem Scraping laufen!

✅ Der UMB Scraper erstellt jetzt automatisch:
- Locations (aus Place-Text geparst)
- Seasons (aus Start-Datum berechnet)
- UMB als Organizer

✅ YouTube Scraper setzt jetzt `metadata_extracted = true` automatisch

✅ Incomplete Records können später im Admin-Interface nachgebessert werden

## Neue Features im Scraping

1. **Auto-Location-Creation**: "Nice (France)" → Location: Nice, Country: FR
2. **Auto-Season-Creation**: Turnier vom 15.01.2009 → Season 2008/2009
3. **Auto-Organizer-Assignment**: UMB Region wird allen UMB-Turnieren zugewiesen
4. **Bessere Discipline Detection**: "3-cushion" im Titel → Dreiband groß
5. **Graceful Degradation**: Falls etwas fehlt → Unknown Placeholder statt Fehler
