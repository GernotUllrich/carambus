# ✅ Migration erfolgreich! - Nächste Schritte

## Status: Datenbank bereit ✓

Die internationale Erweiterung ist installiert und betriebsbereit.

---

## 🎯 Was jetzt zu tun ist

### 1. YouTube API Key einrichten

Um Videos scrapen zu können, benötigen Sie einen YouTube Data API v3 Key:

#### A. API Key beantragen:
1. Gehe zu [Google Cloud Console](https://console.cloud.google.com/)
2. Erstelle ein neues Projekt (oder wähle bestehendes)
3. Aktiviere die **YouTube Data API v3**:
   - Navigiere zu "APIs & Services" → "Enable APIs and Services"
   - Suche nach "YouTube Data API v3"
   - Klicke "Enable"
4. Erstelle Credentials:
   - "Create Credentials" → "API Key"
   - Kopiere den API Key

#### B. Key in Production Credentials speichern (empfohlen):

```bash
cd /Users/gullrich/DEV/carambus/carambus_master

# Production credentials bearbeiten
EDITOR=nano rails credentials:edit --environment production

# Füge hinzu:
youtube_api_key: AIzaSy... # Dein API Key hier

# Speichern: Ctrl+O, Enter, Ctrl+X
```

**Wichtig**: Dann die geänderte `config/credentials/production.yml.enc` committen:
```bash
git add config/credentials/production.yml.enc
git commit -m "Add YouTube API key to production credentials"
git push
```

#### C. Alternative: Development Credentials (für lokales Testen):

```bash
EDITOR=nano rails credentials:edit --environment development
# Füge youtube_api_key hinzu
```

📖 **Detaillierte Anleitung**: Siehe `docs/international/CREDENTIALS_SETUP.md`

### 2. Test-Scraping durchführen

Nachdem der API Key gesetzt ist:

```bash
cd /Users/gullrich/DEV/carambus/carambus_master

# Test ob API Key gesetzt ist
rails runner "puts ENV['YOUTUBE_API_KEY'].present? ? '✅ API Key gefunden' : '❌ API Key fehlt'"

# Test-Scraping (7 Tage zurück)
rails runner "ScrapeYoutubeJob.perform_now(days_back: 7)"
```

Das sollte einige Videos von Kozoom, Five & Six und CEB scrapen.

### 3. Ergebnisse prüfen

```bash
rails runner "
puts '=== Scraping Results ==='
puts \"Videos found: #{Video.count}\"
puts ''
puts 'Latest 5 videos:'
Video.recent.limit(5).each do |v|
  puts \"  - #{v.title[0..60]}...\"
  puts \"    Source: #{v.international_source.name}\"
  puts \"    Published: #{v.published_at&.strftime('%Y-%m-%d')}\"
  puts ''
end
"
```

### 4. Server starten und testen

```bash
rails server

# In Browser öffnen:
# http://localhost:3000/international
```

### 5. (Optional) Scheduled Tasks einrichten

Für automatisches tägliches Scraping:

```ruby
# Installiere whenever gem falls noch nicht vorhanden
# gem 'whenever', require: false

# In config/schedule.rb
every 1.day, at: '3:00 am' do
  runner "ScrapeYoutubeJob.perform_later"
end

every 6.hours do
  runner "ProcessUnprocessedVideosJob.perform_later"
end
```

Dann:
```bash
whenever --update-crontab
```

---

## 📊 Was bereits funktioniert

✅ Datenbank mit 5 neuen Tabellen  
✅ 5 bekannte Quellen geseedet (Kozoom, Five & Six, CEB, UMB)  
✅ Models mit Validierungen und Scopes  
✅ YouTube-Scraper vorbereitet  
✅ Background Jobs  
✅ Routes für `/international`  
✅ Landing Page View  

---

## 🔄 Nächste Entwicklungs-Schritte (optional)

### Phase 2: UMB Turniere manuell hinzufügen

Während du auf vollautomatisches UMB-Scraping wartest, kannst du Turniere manuell hinzufügen:

```ruby
rails console

# Beispiel: UMB World Cup 2026 Bogota
discipline = Discipline.find_by(name: 'Dreiband groß')

tournament = InternationalTournament.create!(
  name: 'UMB World Cup 2026 - Bogota',
  tournament_type: 'world_cup',
  discipline: discipline,
  start_date: Date.new(2026, 4, 6),
  end_date: Date.new(2026, 4, 12),
  location: 'Bogota',
  country: 'Colombia',
  organizer: 'UMB',
  source_url: 'https://files.umb-carom.org/...'
)

puts "Created tournament: #{tournament.display_name}"
```

### Phase 3: Detail-Views erstellen

Die Index-Views sind fertig, aber Detail-Views fehlen noch:
- `/international/tournaments/:id`
- `/international/videos/:id`

Diese können nach Bedarf implementiert werden.

### Phase 4: KI-Integration für Metadaten

Für bessere Spieler-Erkennung und Turnier-Matching kann später ein LLM-Service integriert werden.

---

## 🐛 Troubleshooting

### Problem: API Key nicht erkannt
```bash
# Prüfe ob gesetzt:
echo $YOUTUBE_API_KEY

# Wenn leer, nochmal setzen und Shell neu laden
export YOUTUBE_API_KEY='AIzaSy...'
source ~/.zshrc
```

### Problem: Quota exceeded
YouTube API hat 10.000 Units/Tag Limit. Jedes Video kostet ~3 Units.
- Reduziere `days_back` Parameter
- Warte bis nächsten Tag

### Problem: Keine Videos gefunden
- Prüfe ob Kanäle Videos haben
- Prüfe Keyword-Matching in `Video::CAROM_KEYWORDS`
- Logs prüfen: `tail -f log/development.log`

---

## 📞 Support

Bei Fragen:
- Dokumentation: `/docs/international/README.md`
- GitHub Issues: https://github.com/GernotUllrich/carambus/issues
- E-Mail: gernot.ullrich@gmx.de

---

## ✅ Checkliste

- [x] Migration erfolgreich
- [x] Seeds ausgeführt
- [x] Quellen angelegt
- [ ] YouTube API Key eingerichtet
- [ ] Test-Scraping durchgeführt
- [ ] Server getestet
- [ ] Landing Page besucht

**Nächster Schritt: YouTube API Key einrichten! 🚀**
