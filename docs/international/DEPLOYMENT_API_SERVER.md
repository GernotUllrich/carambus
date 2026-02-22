# 🚀 Deployment auf carambus_api Server (Production)

## Übersicht

Die internationale Erweiterung läuft auf dem **carambus_api** Server in der Production-Umgebung.

---

## 📋 Voraussetzungen

- [x] YouTube API Key besorgt
- [x] API Key in production credentials gespeichert
- [x] Änderungen committed und gepusht
- [ ] Auf carambus_api Server deployen

---

## 🔧 Deployment-Schritte

### 1. Code auf carambus_api aktualisieren

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Neueste Änderungen holen
git pull

# Sollte zeigen:
# - Migration: db/migrate/20260217221513_create_international_extension.rb
# - Neue Models: app/models/international_*.rb
# - Neue Services: app/services/youtube_scraper.rb
# - Etc.
```

### 2. Dependencies installieren

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Bundle install für neue gems (falls welche hinzugefügt wurden)
bundle install

# Yarn install (falls JS-Dependencies)
yarn install
```

### 3. Assets precompilen

```bash
yarn build && yarn build:css && RAILS_ENV=production rails assets:precompile
```

### 4. Migration ausführen

```bash
RAILS_ENV=production rails db:migrate
```

### 5. Seeds ausführen

```bash
RAILS_ENV=production rails runner db/seeds/international_sources.rb
```

### 6. Credentials Key prüfen

**Wichtig**: Der `production.key` muss auf carambus_api existieren:

```bash
ls -la /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api/config/credentials/production.key

# Sollte existieren (32 Bytes)
# Falls nicht, von carambus_master kopieren:
# cp ../carambus_master/config/credentials/production.key config/credentials/
```

### 7. API Key testen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

RAILS_ENV=production rails runner "
key = Rails.application.credentials.youtube_api_key
if key.present?
  puts '✅ YouTube API Key gefunden: ' + key[0..10] + '...'
else
  puts '❌ YouTube API Key NICHT gefunden!'
  puts 'Fallback ENV: ' + (ENV['YOUTUBE_API_KEY'].present? ? 'vorhanden' : 'fehlt')
end
"
```

### 8. Test-Scraping durchführen (optional)

```bash
# Achtung: Verwendet echtes API-Quota!
RAILS_ENV=production rails runner "
puts 'Starting test scraping...'
begin
  count = ScrapeYoutubeJob.perform_now(days_back: 3)
  puts \"✅ Success! Scraped #{count} videos\"
rescue => e
  puts \"❌ Error: #{e.message}\"
end
"
```

### 9. Server neu starten

#### A. Via Capistrano (empfohlen):
```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_master
rake "scenario:deploy[carambus_api]"
```

#### B. Manuell (falls nötig):
```bash
# Auf dem Production Server (SSH)
cd /path/to/carambus_api
touch tmp/restart.txt
# Oder: systemctl restart carambus_api
```

---

## 📊 Verifikation

### 1. Datenbank prüfen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

RAILS_ENV=production rails runner "
puts '=== Production Database Check ==='
puts \"InternationalSource: #{InternationalSource.count}\"
puts \"InternationalTournament: #{InternationalTournament.count}\"
puts \"Video: #{Video.count}\"
puts ''
puts 'Sources:'
InternationalSource.all.each { |s| puts \"  - #{s.display_name}\" }
"
```

### 2. Web-Interface testen

```bash
# Browser öffnen:
# http://carambus-api-server.de/international
# (oder welche Domain auch immer)
```

### 3. Logs prüfen

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api

# Production log
tail -f log/production.log

# Oder via Capistrano:
cap production logs:tail
```

---

## ⏰ Scheduled Scraping einrichten

### Option A: Cron Job

Auf dem Production Server:

```bash
# Crontab bearbeiten
crontab -e

# Füge hinzu (täglich um 3:00 Uhr):
0 3 * * * cd /path/to/carambus_api && RAILS_ENV=production bundle exec rails runner "ScrapeYoutubeJob.perform_now" >> log/youtube_scraper.log 2>&1

# Video-Verarbeitung alle 6 Stunden:
0 */6 * * * cd /path/to/carambus_api && RAILS_ENV=production bundle exec rails runner "ProcessUnprocessedVideosJob.perform_now" >> log/video_processor.log 2>&1
```

### Option B: Whenever Gem

Falls `whenever` gem verwendet wird:

```ruby
# config/schedule.rb (bereits in carambus_master)
set :environment, 'production'
set :output, 'log/cron.log'

every 1.day, at: '3:00 am' do
  runner "ScrapeYoutubeJob.perform_now"
end

every 6.hours do
  runner "ProcessUnprocessedVideosJob.perform_now"
end
```

Dann deployen:

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
RAILS_ENV=production whenever --update-crontab
```

### Option C: Sidekiq Scheduler

Falls Sidekiq verwendet wird (bevorzugt für robuste Background Jobs):

```yaml
# config/sidekiq.yml
:schedule:
  youtube_scraper:
    cron: '0 3 * * *'  # Täglich 3:00 Uhr
    class: ScrapeYoutubeJob
    args: { days_back: 7 }
    
  video_processor:
    cron: '0 */6 * * *'  # Alle 6 Stunden
    class: ProcessUnprocessedVideosJob
```

---

## 🔍 Monitoring

### Logs überwachen

```bash
# Scraping-Aktivität
grep -i "youtube" log/production.log | tail -20

# Fehler
grep -i "error" log/production.log | grep -i "international" | tail -10
```

### Statistiken

```bash
RAILS_ENV=production rails runner "
puts '=== Scraping Statistics ==='
puts \"Total Videos: #{Video.count}\"
puts \"Processed: #{Video.processed.count}\"
puts \"Unprocessed: #{Video.unprocessed.count}\"
puts \"Last scraping: #{InternationalSource.order(:last_scraped_at).last&.last_scraped_at}\"
"
```

---

## 🐛 Troubleshooting

### Problem: API Key nicht gefunden

```bash
# Prüfe credentials
RAILS_ENV=production rails credentials:show | grep youtube

# Prüfe key file
ls -la config/credentials/production.key

# Fallback: ENV Variable setzen
export YOUTUBE_API_KEY='AIzaSy...'
```

### Problem: Migration schlägt fehl

```bash
# Prüfe Status
RAILS_ENV=production rails db:migrate:status | grep international

# Rollback und nochmal
RAILS_ENV=production rails db:rollback
RAILS_ENV=production rails db:migrate
```

### Problem: Quota exceeded

YouTube API Limit ist 10.000 Units/Tag.

```bash
# Reduziere Scraping-Frequenz
# Oder warte bis nächsten Tag
```

### Problem: Keine Videos gefunden

```bash
# Teste manuell
RAILS_ENV=production rails console

scraper = YoutubeScraper.new
scraper.scrape_channel('CHANNEL_ID', days_back: 7)
```

---

## 📈 Performance

### Ressourcen-Nutzung (geschätzt)

- **Storage**: ~60 MB/Jahr (nur Metadaten)
- **RAM**: ~100-200 MB während Scraping
- **CPU**: Niedrig (~5-10 min/Tag)
- **Network**: ~10-20 MB/Tag (API Calls)

### Optimierungen

```ruby
# Batch-Processing für große Mengen
Video.unprocessed.find_in_batches(batch_size: 100) do |batch|
  batch.each { |video| video.auto_assign_discipline! }
end
```

---

## 🔐 Sicherheit

### Credentials Best Practices

- ✅ Credentials verschlüsselt in Git
- ✅ Master Key NICHT in Git (in `.gitignore`)
- ✅ API Key rotieren alle 6-12 Monate
- ✅ Quota-Limits überwachen

### Backup

```bash
# Credentials sichern (nur master key!)
cp config/credentials/production.key ~/backup/carambus_api_prod.key

# Datensicherung
RAILS_ENV=production rails runner "
File.write('backup_intl_sources.json', InternationalSource.all.to_json)
"
```

---

## 📞 Support

Bei Problemen:
- Logs prüfen: `log/production.log`
- Database Console: `RAILS_ENV=production rails dbconsole`
- Rails Console: `RAILS_ENV=production rails console`
- GitHub Issues: https://github.com/GernotUllrich/carambus/issues

---

## ✅ Deployment Checklist

- [ ] Git pull in carambus_api
- [ ] Bundle install
- [ ] Assets precompile
- [ ] Migration ausführen
- [ ] Seeds ausführen
- [ ] Credentials key vorhanden
- [ ] API Key getestet
- [ ] Test-Scraping erfolgreich
- [ ] Server neu gestartet
- [ ] Web-Interface erreichbar
- [ ] Scheduled Jobs eingerichtet
- [ ] Monitoring aktiv

**Ready for Production! 🚀**
