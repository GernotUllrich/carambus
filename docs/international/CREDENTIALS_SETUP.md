# YouTube API Key in Rails Credentials speichern

## Für Production (carambus_api Server)

### 1. Production Credentials bearbeiten

```bash
cd /Users/gullrich/DEV/carambus/carambus_master

# Production credentials öffnen
EDITOR=nano rails credentials:edit --environment production
```

### 2. YouTube API Key hinzufügen

Füge folgende Zeile hinzu:

```yaml
# YouTube Data API v3 für internationales Video-Scraping
youtube_api_key: AIzaSy... # Dein API Key hier

# Existierende Credentials bleiben unverändert
# ...
```

Speichern und schließen (nano: `Ctrl+O`, `Enter`, `Ctrl+X`)

### 3. Im Code verwenden

Der YoutubeScraper ist bereits so konfiguriert, dass er den Key aus den Credentials liest:

```ruby
# app/services/youtube_scraper.rb (bereits implementiert)
def initialize(source = nil)
  @youtube = Google::Apis::YoutubeV3::YouTubeService.new
  @youtube.key = Rails.application.credentials.youtube_api_key || ENV['YOUTUBE_API_KEY']
  # ...
end
```

### 4. Credentials-Änderung commiten

**Wichtig**: Nur die `.yml.enc` Datei wird committet, NICHT der `.key` File!

```bash
cd /Users/gullrich/DEV/carambus/carambus_master

# Prüfen welche Dateien geändert wurden
git status

# Sollte zeigen:
# modified:   config/credentials/production.yml.enc

git add config/credentials/production.yml.enc
git commit -m "Add YouTube API key to production credentials"
git push
```

### 5. Auf carambus_api Server deployen

```bash
# Im carambus_api Verzeichnis
cd /Users/gullrich/DEV/carambus/carambus_api

# Pull der Änderungen
git pull

# Migration ausführen
RAILS_ENV=production rails db:migrate

# Seeds ausführen
RAILS_ENV=production rails runner db/seeds/international_sources.rb

# Server neu starten (via Capistrano oder manuell)
# rake scenario:deploy[carambus_api]
```

---

## Für Development & Testing

Falls Sie auch lokal testen möchten:

```bash
# Development credentials
EDITOR=nano rails credentials:edit --environment development

# Füge hinzu:
youtube_api_key: AIzaSy...
```

---

## Testen

### Lokal (Development):
```bash
cd /Users/gullrich/DEV/carambus/carambus_master

rails runner "puts Rails.application.credentials.youtube_api_key.present? ? '✅ Key gefunden' : '❌ Key fehlt'"
```

### Auf carambus_api (Production):
```bash
cd /Users/gullrich/DEV/carambus/carambus_api

RAILS_ENV=production rails runner "puts Rails.application.credentials.youtube_api_key.present? ? '✅ Key gefunden' : '❌ Key fehlt'"
```

---

## Wichtige Hinweise

### ⚠️ Credentials Key File
Der `config/credentials/production.key` File enthält den Master Key zum Entschlüsseln.
- **NIEMALS** in Git committen (ist in `.gitignore`)
- Muss auf dem Production Server vorhanden sein
- Prüfen: `ls -la /Users/gullrich/DEV/carambus/carambus_api/config/credentials/production.key`

### 🔒 Sicherheit
- Der API Key ist verschlüsselt in `production.yml.enc`
- Nur mit dem `production.key` entschlüsselbar
- Kann sicher in Git committed werden

### 🔄 Fallback
Falls Credentials nicht funktionieren, gibt es einen Fallback auf ENV:
```ruby
Rails.application.credentials.youtube_api_key || ENV['YOUTUBE_API_KEY']
```

---

## Troubleshooting

### Problem: "Missing encryption key"
```bash
# Prüfe ob production.key existiert
ls -la config/credentials/production.key

# Wenn nicht, muss er vom bestehenden Setup übernommen werden
# Oder neu generieren (verliert alte credentials!):
# rails credentials:edit --environment production
```

### Problem: Key nicht gefunden
```bash
# Credentials anzeigen (nur lokal!)
rails credentials:show --environment production

# Sollte enthalten:
# youtube_api_key: AIzaSy...
```

---

## Alternative: Umgebungsvariable (nicht empfohlen)

Falls Credentials nicht funktionieren, kannst du auch eine ENV Variable setzen:

```bash
# Auf dem Production Server
export YOUTUBE_API_KEY='AIzaSy...'

# Oder in /etc/environment oder .bashrc
```

Aber Credentials sind der bevorzugte Weg in Rails 7!
