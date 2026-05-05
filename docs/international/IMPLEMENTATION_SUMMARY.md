# 🎯 Internationale Erweiterung - Implementierungs-Übersicht

## ✅ Erstellte Dateien

### Database Migration
- `db/migrate/20260217221513_create_international_extension.rb`
  - Tabellen: international_sources, international_tournaments, international_results, international_videos, international_participations
  - Erweiterungen: players.international_player, tournaments.international_tournament_id

### Models (5)
1. `app/models/international_source.rb`
   - Verwaltung von YouTube-Kanälen, Verbänden
   - Bekannte Quellen: Kozoom, Five & Six, UMB, CEB

2. `app/models/international_tournament.rb`
   - Internationale Turniere (WM, EM, World Cups)
   - Scopes: upcoming, past, current, by_type, by_discipline

3. `app/models/international_result.rb`
   - Turnierergebnisse mit Spieler-Verknüpfung
   - Automatisches Player-Matching

4. `app/models/international_video.rb`
   - Video-Archiv mit YouTube-Integration
   - Automatische Disziplin-Erkennung
   - Keyword-basiertes Filtering

5. `app/models/international_participation.rb`
   - Spieler-Teilnahmen an Turnieren
   - Markiert Spieler als international_player

### Services (1)
- `app/services/youtube_scraper.rb`
  - YouTube Data API v3 Integration
  - Channel-Scraping
  - Video-Filtering nach Karambol-Keywords
  - Quota-Management

### Background Jobs (2)
1. `app/jobs/scrape_youtube_job.rb`
   - Automatisches Scraping aller bekannten Kanäle
   - Scheduled: täglich um 3:00 Uhr

2. `app/jobs/process_unprocessed_videos_job.rb`
   - Metadaten-Extraktion
   - Turnier-Matching
   - Disziplin-Zuordnung

### Controllers (3)
1. `app/controllers/international_controller.rb`
   - Landing Page mit Übersicht

2. `app/controllers/international/tournaments_controller.rb`
   - Liste und Details internationaler Turniere
   - Filter nach Typ, Disziplin, Jahr

3. `app/controllers/international/videos_controller.rb`
   - Video-Archiv mit Such- und Filterfunktion
   - Pagination

### Views (1)
- `app/views/international/index.html.erb`
  - Landing Page mit:
    - Upcoming Tournaments
    - Latest Videos
    - Recent Results

### Routes
- Ergänzungen in `config/routes.rb`:
  - `GET /international` → Landing Page
  - `GET /international/tournaments` → Turniere
  - `GET /international/videos` → Videos

### Seeds
- `db/seeds/international_sources.rb`
  - Bekannte YouTube-Kanäle
  - UMB, CEB Verbände

### Documentation (2)
1. `docs/international/README.md`
   - Setup-Anleitung
   - API Key Setup
   - Verwendungs-Beispiele
   - Troubleshooting

2. `docs/international/IMPLEMENTATION_SUMMARY.md` (diese Datei)

### Model-Erweiterungen
- `app/models/player.rb`
  - `has_many :international_participations`
  - `has_many :international_tournaments`
  - `has_many :international_results`

- `app/models/tournament.rb`
  - `belongs_to :international_tournament`
  - `scope :international`

## 🔄 Nächste Schritte

### Sofort ausführbar:
```bash
# 1. Migration
cd /Users/gullrich/DEV/carambus/carambus_master
rails db:migrate

# 2. Seeds
rails runner db/seeds/international_sources.rb

# 3. YouTube API Key setzen
export YOUTUBE_API_KEY='YOUR_KEY_HERE'
# Oder in .env Datei: YOUTUBE_API_KEY=YOUR_KEY_HERE

# 4. Test-Scraping
rails runner "ScrapeYoutubeJob.perform_now(days_back: 7)"

# 5. Server starten und testen
rails server
# Besuche: http://localhost:3000/international
```

### Noch zu implementieren:

#### Phase 2 (2-4 Wochen)
- [ ] UMB Tournament Scraper
  - URL: https://files.umb-carom.org/public/FutureTournaments.aspx
  - Format: XML/HTML
  
- [ ] CEB Tournament Scraper
  - URL: https://www.eurobillard.org/
  - Format: HTML

- [ ] Views für Tournaments#show und Videos#show erstellen

- [ ] Admin-Interface für manuelles Hinzufügen/Bearbeiten

#### Phase 3 (KI-Integration)
- [ ] AI Metadata Extractor
  - OpenAI/Anthropic API Integration
  - Spieler-Extraktion aus Titeln
  - Turnier-Erkennung
  
- [ ] Verbessertes Player-Matching
  - Fuzzy-Matching mit KI-Unterstützung
  - Automatische Merge-Vorschläge

- [ ] Turnier-Klassifizierung
  - Automatische Typ-Erkennung
  - Wichtigkeit/Prestige-Bewertung

#### Phase 4 (UI/UX)
- [ ] Responsive Design optimieren
- [ ] Video-Player mit Chapters
- [ ] Statistik-Dashboards
- [ ] Mehrsprachigkeit (EN, DE, FR, NL)

#### Phase 5 (Community)
- [ ] User-Kommentare zu Videos
- [ ] Favoriten/Watchlists
- [ ] Video-Vorschläge durch Community
- [ ] Rating-System

## 📊 Datenbank-Struktur

```
international_sources
  ├─ international_videos (1:n)
  └─ international_tournaments (1:n)
       ├─ international_results (1:n)
       │    └─ players (n:1)
       └─ international_participations (1:n)
            └─ players (n:1)

Bestehende Integration:
  players
    └─ international_participations (1:n)
         └─ international_tournaments (n:1)
  
  tournaments
    └─ international_tournament (1:1)
```

## 🎯 Features-Übersicht

### ✅ Implementiert
- YouTube-Scraping mit Channel-Support
- Video-Archiv mit Metadaten
- Internationale Turniere mit Ergebnissen
- Spieler-Verknüpfung mit bestehendem System
- Basic UI (Landing Page)
- Background Jobs für Automation
- Automatische Disziplin-Erkennung
- Keyword-basiertes Filtering

### 🔄 In Arbeit
- Views für Detail-Seiten
- Admin-Interface
- UMB/CEB Scraping

### 📋 Geplant
- KI-Metadaten-Extraktion
- Erweiterte Suche
- Statistik-Dashboards
- Community-Features

## 🔧 Konfiguration

### Umgebungsvariablen
```bash
YOUTUBE_API_KEY=your_key_here  # Required für YouTube-Scraping
```

### Scheduled Tasks (via whenever gem)
```ruby
# config/schedule.rb
every 1.day, at: '3:00 am' do
  runner "ScrapeYoutubeJob.perform_later"
end

every 6.hours do
  runner "ProcessUnprocessedVideosJob.perform_later"
end
```

### Bekannte Quellen
```ruby
# Können in InternationalSource::KNOWN_YOUTUBE_CHANNELS erweitert werden
- Kozoom
- Five & Six
- CEB Carom
```

## 📈 Performance-Überlegungen

### YouTube API Quota
- **Limit**: 10.000 Einheiten/Tag
- **Kosten pro Video**: ~3 Einheiten
- **Max Videos/Tag**: ~3.300
- **Empfohlene Strategie**: 
  - Täglich scrapen (7 Tage zurück)
  - Nur carom-relevante Videos speichern

### Datenbank-Größe (Schätzung)
- **Videos**: ~50 MB/Jahr (nur Metadaten)
- **Turniere**: ~1 MB/Jahr
- **Ergebnisse**: ~5 MB/Jahr
- **Gesamt**: ~60 MB/Jahr

### VPS-Ressourcen
- **CPU**: Niedrig (Scraping 5-10 min/Tag)
- **RAM**: ~100-200 MB für Background Jobs
- **Network**: ~10-20 MB/Tag (API Calls)
- **Storage**: ~60 MB/Jahr

## 🚀 Deployment

### Scenario-Management beachten!
```bash
# IMMER in carambus_master entwickeln
cd /Users/gullrich/DEV/carambus/carambus_master

# Nach Commit:
cd /Users/gullrich/DEV/carambus/carambus_api
git pull
rake db:migrate
# Server restart (Capistrano)
```

## 📞 Kontakt & Support

Bei Fragen:
- GitHub Issues
- E-Mail: gernot.ullrich@gmx.de

---

**Version**: 1.0.0  
**Datum**: 17. Februar 2026  
**Status**: MVP Ready for Testing
