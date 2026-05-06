# 🌍 International Carom Billiards Extension

Diese Erweiterung ermöglicht es Carambus, internationale Karambol-Turniere, Videos und Ergebnisse zu verfolgen und zu archivieren.

## 📋 Features

- **Video-Archiv**: Automatisches Scraping von YouTube-Kanälen (Kozoom, Five & Six, etc.)
- **Turnier-Tracking**: Verwaltung internationaler Turniere (WM, EM, World Cups)
- **Ergebnis-Tracking**: Speicherung und Anzeige von Turnierergebnissen
- **Spieler-Integration**: Verknüpfung internationaler Spieler mit bestehenden Player-Records
- **ClubCloud-Kompatibilität**: Nahtlose Integration mit bestehender deutscher Infrastruktur

## 🚀 Setup

### 1. Migration ausführen

```bash
cd /Users/gullrich/DEV/carambus/carambus_master
rails db:migrate
```

### 2. YouTube API Key einrichten

#### A. API Key beantragen
1. Gehe zu [Google Cloud Console](https://console.cloud.google.com/)
2. Erstelle ein neues Projekt (oder wähle bestehendes)
3. Aktiviere die YouTube Data API v3
4. Erstelle Credentials → API Key
5. Kopiere den API Key

**Wichtig**: YouTube Data API hat ein tägliches Quota von 10.000 Einheiten. Jede Video-Abfrage kostet ca. 3 Einheiten.

#### B. Key in Production Credentials speichern (empfohlen)

```bash
# Production credentials bearbeiten
EDITOR=nano rails credentials:edit --environment production

# Füge hinzu:
youtube_api_key: AIzaSy... # Dein API Key hier

# Speichern: Ctrl+O, Enter, Ctrl+X
```

Dann committen:
```bash
git add config/credentials/production.yml.enc
git commit -m "Add YouTube API key to production credentials"
git push
```

**Detaillierte Anleitungen:**
- `docs/international/CREDENTIALS_SETUP.md` - Credentials-Konfiguration
- `docs/international/DEPLOYMENT_API_SERVER.md` - Production Deployment

### 3. Seeds ausführen

```bash
# Bekannte Quellen (YouTube-Kanäle, Verbände) seeden
rails runner db/seeds/international_sources.rb
```

### 4. Erstes Scraping durchführen

```bash
# Manuelles Test-Scraping (7 Tage zurück)
rails runner "ScrapeYoutubeJob.perform_now(days_back: 7)"
```

### 5. Scheduled Tasks einrichten (optional)

Für automatisches tägliches Scraping, füge zu `config/schedule.rb` hinzu (mit `whenever` gem):

```ruby
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

## 📊 Datenmodell

### Neue Tabellen

- **international_sources**: YouTube-Kanäle, Verbände (UMB, CEB)
- **international_tournaments**: Internationale Turniere
- **international_results**: Turnierergebnisse
- **international_videos**: Video-Archiv
- **international_participations**: Spieler-Teilnahmen an Turnieren

### Integration mit bestehendem Modell

- `players.international_player` (boolean): Markiert Spieler mit internationalen Teilnahmen
- `tournaments.international_tournament_id`: Verknüpft lokale mit internationalen Turnieren
- Bestehende `Discipline`-Modelle werden wiederverwendet

## 🎯 Verwendung

### Video-Archiv durchsuchen

```ruby
# Alle Videos
videos = Video.all

# Nur Dreiband
videos = Video.joins(:discipline)
                           .where(disciplines: { name: 'Dreiband groß' })

# Eines spezifischen Turniers
videos = Video.where(international_tournament_id: tournament.id)

# Unverarbeitete Videos
videos = Video.unprocessed
```

### Turniere verwalten

```ruby
# Kommende Turniere
tournaments = InternationalTournament.upcoming

# Turniere eines Jahres
tournaments = InternationalTournament.in_year(2026)

# Weltmeisterschaften
tournaments = InternationalTournament.by_type('world_championship')
```

### Manuelles Hinzufügen eines Turniers

```ruby
tournament = InternationalTournament.create!(
  name: 'UMB World Cup 2026 - Bogota',
  tournament_type: 'world_cup',
  discipline: Discipline.find_by(name: 'Dreiband groß'),
  start_date: Date.new(2026, 4, 6),
  end_date: Date.new(2026, 4, 12),
  location: 'Bogota',
  country: 'Colombia',
  organizer: 'UMB',
  source_url: 'https://files.umb-carom.org/...'
)

# Ergebnisse hinzufügen
tournament.add_result(
  player_name: 'Frédéric Caudron',
  position: 1,
  points: 1000,
  prize: 15000,
  metadata: { games_played: 8, average: 2.150 }
)
```

## 🤖 KI-Unterstützung (Zukünftig)

Für erweiterte Metadaten-Extraktion kann ein LLM-Service integriert werden:

```ruby
# app/services/ai_metadata_extractor.rb
class AiMetadataExtractor
  def extract_from_video(video)
    # OpenAI/Anthropic API Call
    # Extraktion von: Spielernamen, Turniername, Runde, etc.
  end
end
```

## 📝 Bekannte YouTube-Kanäle

Die folgenden Kanäle werden automatisch gescrapt:

1. **Kozoom** - Professioneller Streaming-Service
2. **Five & Six** - Turnierberichterstattung
3. **CEB Carom** - Europäischer Verband

Weitere Kanäle können in `InternationalSource::KNOWN_YOUTUBE_CHANNELS` hinzugefügt werden.

## 🔗 Wichtige URLs

- **Landing Page**: `/international`
- **Turniere**: `/international/tournaments`
- **Videos**: `/international/videos`

## 📚 Weitere Quellen

### Federations & Websites

- **UMB**: https://files.umb-carom.org/public/FutureTournaments.aspx
- **CEB**: https://www.eurobillard.org/
- **3cushionbilliards.com**: Community-Seite mit guten Daten

### Scraper-Erweiterungen (TODO)

- UMB Tournament Scraper (XML/JSON)
- CEB Tournament Scraper
- 3cushionbilliards.com Results Scraper

## 🛠️ Development

### Tests ausführen

```bash
# TODO: Tests erstellen
rails test test/models/international_*
rails test test/services/youtube_scraper_test.rb
```

### Console-Debugging

```ruby
rails console

# Source erstellen
source = InternationalSource.create!(
  name: 'Test Channel',
  source_type: 'youtube',
  base_url: 'https://youtube.com/@test'
)

# Scraper testen
scraper = YoutubeScraper.new
scraper.scrape_channel('CHANNEL_ID', days_back: 7)

# Videos anzeigen
Video.recent.limit(10).each do |v|
  puts "#{v.title} (#{v.published_at})"
end
```

## 🐛 Troubleshooting

### YouTube API Quota überschritten

```bash
# Check verbleibende Quota in Google Cloud Console
# Reduziere Scraping-Frequenz oder erhöhe days_back Parameter
```

### Videos werden nicht als Karambol erkannt

```ruby
# Prüfe Keywords
Video::CAROM_KEYWORDS

# Manuell zuordnen
video = Video.find(id)
video.auto_assign_discipline!
```

### Spieler nicht gefunden

```ruby
# Erstelle Spieler manuell oder verwende Player-Matching
result = InternationalResult.find(id)
result.match_player!
```

## 📈 Roadmap

### Phase 1 (Aktuell)
- ✅ YouTube-Scraping
- ✅ Basic UI
- ✅ Video-Archiv

### Phase 2 (Nächste Schritte)
- [ ] UMB/CEB Scraping für Turnierdaten
- [ ] KI-gestützte Metadaten-Extraktion
- [ ] Verbesserte Spieler-Matching-Logik
- [ ] Admin-Interface

### Phase 3 (Zukunft)
- [ ] Automatische Video-Kategorisierung
- [ ] Highlight-Extraktion
- [ ] Statistik-Dashboards
- [ ] Community-Features (Kommentare, Favoriten)

## 📞 Support

Bei Fragen oder Problemen:
- GitHub Issues: https://github.com/GernotUllrich/carambus/issues
- E-Mail: gernot.ullrich@gmx.de

---

**Version**: 1.0  
**Erstellt**: Februar 2026  
**Autor**: Dr. Gernot Ullrich
