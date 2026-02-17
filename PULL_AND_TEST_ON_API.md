# 🚀 Pull & Test auf carambus_api

## ✅ Status: Code ist gepusht!

Commit: `7d2c5add` - feat(international): Add international carom billiards extension

---

## 📋 Schnellstart für carambus_api

### 1. Pull auf carambus_api

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
git pull
```

**Erwartete Ausgabe:**
```
Updating 31b9a716..7d2c5add
Fast-forward
 19 files changed, 1709 insertions(+), 20 deletions(-)
 create mode 100644 app/models/international_source.rb
 # ... weitere Files
```

### 2. Dependencies & Assets

```bash
# Falls neue gems (google-apis-youtube_v3)
bundle install

# Assets
yarn install
yarn build && yarn build:css
RAILS_ENV=production rails assets:precompile
```

### 3. Migration ausführen

```bash
RAILS_ENV=production rails db:migrate
```

**Erwartete Ausgabe:**
```
== 20260217221513 CreateInternationalExtension: migrating =====================
-- create_table(:international_sources)
   -> 0.0095s
# ... etc
== 20260217221513 CreateInternationalExtension: migrated (0.0913s) ============
```

### 4. Seeds ausführen

```bash
RAILS_ENV=production rails runner db/seeds/international_sources.rb
```

**Erwartete Ausgabe:**
```
Seeding international sources...
  Created: Kozoom
  Created: Five & Six
  Created: CEB Carom
  Created: Union Mondiale de Billard
  Created: Confédération Européenne de Billard
International sources seeded successfully!
Total sources: 5
```

### 5. Datenbank prüfen

```bash
RAILS_ENV=production rails runner "
puts '=== Database Check ==='
puts \"InternationalSource: #{InternationalSource.count}\"
puts \"InternationalTournament: #{InternationalTournament.count}\"
puts \"InternationalVideo: #{InternationalVideo.count}\"
puts ''
puts 'Sources:'
InternationalSource.all.each { |s| puts \"  - #{s.display_name}\" }
"
```

**Erwartete Ausgabe:**
```
=== Database Check ===
InternationalSource: 5
InternationalTournament: 0
InternationalVideo: 0

Sources:
  - Kozoom (YOUTUBE)
  - Five & Six (YOUTUBE)
  - CEB Carom (YOUTUBE)
  - Union Mondiale de Billard (UMB)
  - Confédération Européenne de Billard (CEB)
```

---

## 🔑 YouTube API Key Setup

### Option 1: Via Rails Credentials (empfohlen)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Prüfe ob production.key existiert
ls -la config/credentials/production.key

# Falls nicht, von master kopieren:
cp ../carambus_master/config/credentials/production.key config/credentials/

# Credentials bearbeiten
EDITOR=nano rails credentials:edit --environment production

# Füge hinzu:
youtube_api_key: AIzaSy...YOUR_KEY_HERE

# Speichern: Ctrl+O, Enter, Ctrl+X
```

### Option 2: Via ENV Variable (schneller zum Testen)

```bash
export YOUTUBE_API_KEY='AIzaSy...YOUR_KEY_HERE'

# Oder dauerhaft in ~/.bashrc oder ~/.zshrc
echo "export YOUTUBE_API_KEY='AIzaSy...'" >> ~/.zshrc
source ~/.zshrc
```

### API Key Test

```bash
RAILS_ENV=production rails runner "
key = Rails.application.credentials.youtube_api_key || ENV['YOUTUBE_API_KEY']
if key.present?
  puts '✅ YouTube API Key gefunden: ' + key[0..10] + '...'
else
  puts '❌ YouTube API Key NICHT gefunden!'
end
"
```

---

## 🧪 Test-Scraping durchführen

### Kleiner Test (3 Tage)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

RAILS_ENV=production rails runner "
puts 'Starting YouTube scraping (3 days back)...'
begin
  count = ScrapeYoutubeJob.perform_now(days_back: 3)
  puts \"✅ Success! Scraped #{count} videos\"
rescue => e
  puts \"❌ Error: #{e.message}\"
  puts e.backtrace.first(5).join(\"\n\")
end
"
```

### Ergebnisse prüfen

```bash
RAILS_ENV=production rails runner "
puts '=== Scraping Results ==='
puts \"Total Videos: #{InternationalVideo.count}\"
puts \"Processed: #{InternationalVideo.processed.count}\"
puts \"Unprocessed: #{InternationalVideo.unprocessed.count}\"
puts ''
puts 'Latest 5 videos:'
InternationalVideo.recent.limit(5).each do |v|
  puts \"  - #{v.title[0..60]}...\"
  puts \"    Source: #{v.international_source.name}\"
  puts \"    Published: #{v.published_at&.strftime('%Y-%m-%d')}\"
  puts \"    Discipline: #{v.discipline&.name || 'not assigned'}\"
  puts ''
end
"
```

---

## 🌐 Web-Interface testen

### Server starten/neu starten

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Via Capistrano
rake scenario:restart[carambus_api]

# Oder manuell
touch tmp/restart.txt
```

### Im Browser öffnen

```
http://carambus-api-server.de/international
# (oder welche URL der API Server hat)
```

**Erwartetes Ergebnis:**
- Landing Page wird angezeigt
- "Upcoming Tournaments" Section (leer)
- "Latest Videos" Section (mit Videos falls Scraping erfolgreich)
- "Recent Results" Section (leer)

---

## 📊 Monitoring & Logs

### Production Log überwachen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Live tail
tail -f log/production.log

# Nur YouTube-relevante Zeilen
tail -f log/production.log | grep -i youtube

# Fehler
grep -i error log/production.log | grep -i international | tail -20
```

### Statistiken anzeigen

```bash
RAILS_ENV=production rails runner "
puts '=== Statistics ==='
puts \"Videos: #{InternationalVideo.count}\"
puts \"  - YouTube: #{InternationalVideo.youtube.count}\"
puts \"  - With discipline: #{InternationalVideo.where.not(discipline_id: nil).count}\"
puts \"  - Processed: #{InternationalVideo.processed.count}\"
puts ''
puts \"Sources:\"
InternationalSource.all.each do |source|
  count = source.international_videos.count
  last = source.last_scraped_at&.strftime('%Y-%m-%d %H:%M')
  puts \"  - #{source.name}: #{count} videos (last: #{last || 'never'})\"
end
"
```

---

## 🐛 Troubleshooting

### Problem: Migration schlägt fehl

```bash
# Status prüfen
RAILS_ENV=production rails db:migrate:status | grep international

# Rollback falls nötig
RAILS_ENV=production rails db:rollback

# Nochmal versuchen
RAILS_ENV=production rails db:migrate
```

### Problem: API Key nicht gefunden

```bash
# Credentials prüfen
RAILS_ENV=production rails credentials:show | grep youtube

# Falls leer: Credentials bearbeiten oder ENV setzen
export YOUTUBE_API_KEY='AIzaSy...'
```

### Problem: Keine Videos gefunden

```bash
# Prüfe ob Scraper funktioniert
RAILS_ENV=production rails console

scraper = YoutubeScraper.new
# Dies testet direkt (ohne API Key würde es crashen)
scraper.youtube.key
# => sollte den Key zeigen

# Manuell ein Channel scrapen
# scraper.scrape_channel('CHANNEL_ID', days_back: 7)
```

### Problem: Quota exceeded

YouTube API Limit: 10.000 Units/Tag
- Jedes Video kostet ~3 Units
- Max ~3.300 Videos/Tag

**Lösung:**
- Warte bis nächsten Tag
- Oder reduziere `days_back` Parameter

---

## ✅ Success Checklist

- [ ] Code gepullt auf carambus_api
- [ ] Bundle install erfolgreich
- [ ] Migration erfolgreich
- [ ] Seeds erfolgreich
- [ ] 5 Sources in Datenbank
- [ ] YouTube API Key konfiguriert
- [ ] API Key Test erfolgreich
- [ ] Test-Scraping durchgeführt
- [ ] Videos in Datenbank
- [ ] Web-Interface erreichbar
- [ ] Landing Page funktioniert
- [ ] Logs sehen gut aus

---

## 📖 Weitere Dokumentation

- `NEXT_STEPS.md` - Setup-Anleitung
- `docs/international/README.md` - Vollständige Doku
- `docs/international/CREDENTIALS_SETUP.md` - Credentials Details
- `docs/international/DEPLOYMENT_API_SERVER.md` - Production Deployment
- `docs/international/IMPLEMENTATION_SUMMARY.md` - Technical Details

---

## 🎯 Nächste Schritte nach erfolgreichem Test

1. **Scheduled Jobs einrichten**
   - Cron Job für tägliches Scraping
   - Siehe `DEPLOYMENT_API_SERVER.md`

2. **Monitoring aktivieren**
   - Log-Rotation
   - Quota-Tracking

3. **Erste Turniere manuell hinzufügen**
   - Via Rails Console
   - Siehe `README.md` für Beispiele

4. **Feedback & Iteration**
   - UI-Verbesserungen
   - Weitere Quellen hinzufügen
   - KI-Integration planen

---

**Viel Erfolg beim Testen! 🚀**

Bei Problemen: Logs prüfen und ggf. Issue auf GitHub erstellen.
