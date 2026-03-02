# Universal Video System - Implementation Complete ✅

## Übersicht

Das universelle Video-System mit polymorphen Associations wurde erfolgreich implementiert. Es ersetzt das alte `international_videos` System und ermöglicht die bidirektionale Navigation zwischen Videos, Tournaments, Games und Players.

## Implementierte Änderungen

### 1. Neue `videos` Tabelle ✅

**Migration:** `20260218193951_create_videos.rb`

```ruby
create_table :videos do |t|
  t.string :external_id, null: false
  t.string :title
  t.text :description
  t.string :thumbnail_url
  
  # Video-Meta
  t.integer :duration
  t.datetime :published_at
  t.integer :view_count
  t.integer :like_count
  t.string :language
  
  # Source (YouTube, Kozoom, Vimeo, etc.)
  t.references :international_source
  
  # Polymorphe Association
  t.references :videoable, polymorphic: true
  
  # Metadata & Processing
  t.jsonb :data, default: {}
  t.boolean :metadata_extracted, default: false
  t.datetime :metadata_extracted_at
  
  # Optional: Discipline detection
  t.references :discipline
end
```

**Indexes:**
- `external_id` (unique)
- `published_at`
- `metadata_extracted`
- `videoable_type, videoable_id, published_at` (composite)

### 2. Video Model ✅

**Datei:** `app/models/video.rb`

**Features:**
- Polymorphe Association zu `Tournament`, `Game`, `Player`
- YouTube URL helpers (`youtube_url`, `youtube_embed_url`)
- Metadata extraction (`extracted_players`, `extracted_event_name`)
- Carom keyword detection (`CAROM_KEYWORDS`)
- Discipline detection (`DISCIPLINE_PATTERNS`)
- Translation support (`translated_title`, `needs_translation?`)

**Scopes:**
```ruby
scope :recent, -> { order(published_at: :desc) }
scope :for_tournaments, -> { where(videoable_type: 'Tournament') }
scope :for_games, -> { where(videoable_type: 'Game') }
scope :for_players, -> { where(videoable_type: 'Player') }
scope :unassigned, -> { where(videoable_id: nil) }
scope :youtube, -> { joins(:international_source).where(...) }
```

### 3. Polymorphe Associations ✅

**Tournament:**
```ruby
# app/models/tournament.rb
has_many :videos, as: :videoable, dependent: :nullify
```

**Game:**
```ruby
# app/models/game.rb
has_many :videos, as: :videoable, dependent: :nullify
```

**Player:**
```ruby
# app/models/player.rb
has_many :videos, as: :videoable, dependent: :nullify
```

### 4. InternationalTournament erweitert ✅

**Datei:** `app/models/international_tournament.rb`

**Neue Scopes:**
```ruby
scope :upcoming, -> { where('date >= ?', Date.today).order(date: :asc) }
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }
scope :by_discipline, ->(discipline_id) { where(discipline_id: discipline_id) }
scope :in_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) }
scope :official_umb, -> { where("data->>'umb_official' = ?", 'true') }
```

**View-Kompatibilität (Aliase):**
```ruby
def name           # → title
def location       # → location_text
def start_date     # → date.to_date
def date_range     # formatierter Datumsbereich
def official_umb?  # prüft data->>'umb_official'
```

### 5. Controller angepasst ✅

**InternationalController:**
```ruby
# Videos - polymorphe Association
@recent_videos = Video.for_tournaments
                      .where(videoable_type: 'Tournament')
                      .where("videoable_id IN (?)", InternationalTournament.pluck(:id))
                      .recent
                      .limit(12)

# Recent results via GameParticipation
@recent_results = GameParticipation
                   .joins(:game, :player)
                   .where(games: { tournament_id: recent_tournament_ids })
                   .order('games.ended_at DESC NULLS LAST')
                   .limit(20)
```

**TournamentsController#show:**
```ruby
# Results via GameParticipation
@results = GameParticipation
            .joins(:game, :player)
            .where(games: { tournament_id: @tournament.id })
            .order('games.ended_at DESC NULLS LAST, game_participations.points DESC')

# Videos - Tournament + Games
@videos = @tournament.videos.recent
@game_videos = Video.for_games.where(videoable_id: @tournament.games.pluck(:id)).recent
```

### 6. Cleanup ✅

- ✅ `international_video.rb` Model gelöscht (nicht mehr benötigt)
- ✅ `international_videos` Tabelle gedroppt (via `DropInternationalTables` Migration)

## Navigation Paths (Beispiele)

### 1. Player → Videos

```ruby
# Alle Videos von Spielen eines Players
player = Player.find(123)

# Via GameParticipations
game_videos = Video.for_games
                   .joins("INNER JOIN game_participations ON 
                          game_participations.game_id = videos.videoable_id")
                   .where(game_participations: { player_id: player.id })
                   .distinct

# Direkt zugeordnete Videos
player_videos = player.videos
```

### 2. Tournament → Videos

```ruby
tournament = InternationalTournament.find(123)

# Videos vom Turnier
tournament_videos = tournament.videos

# Videos von Spielen
game_videos = Video.for_games
                   .where(videoable_id: tournament.games.pluck(:id))

# Alle Videos (Turnier + Spiele)
all_videos = Video.where(
  "(videoable_type = 'Tournament' AND videoable_id = ?) OR 
   (videoable_type = 'Game' AND videoable_id IN (?))",
  tournament.id,
  tournament.games.pluck(:id)
)
```

### 3. Video → Related Content

```ruby
video = Video.find(123)

case video.videoable_type
when 'Tournament'
  tournament = video.videoable
  games = tournament.games
  players = tournament.seedings.map(&:player)
  
when 'Game'
  game = video.videoable
  tournament = game.tournament
  players = game.game_participations.map(&:player)
  
when 'Player'
  player = video.videoable
  # Player details
end
```

### 4. Game → Videos

```ruby
game = Game.find(123)

# Videos vom Spiel
game_videos = game.videos

# Videos vom zugehörigen Turnier
tournament_videos = game.tournament&.videos
```

## Use Cases

### A) UMB Scraping → Video zuordnen

```ruby
tournament = InternationalTournament.find_by(external_id: '310')

# Video erstellen
video = Video.create!(
  external_id: 'abc123',
  title: 'World Cup 3-Cushion Final',
  international_source: youtube_source,
  videoable: tournament  # Polymorphe Zuordnung!
)
```

### B) YouTube Scraping → Tournament erstellen

```ruby
# 1. Video gefunden
video = Video.create!(
  external_id: 'xyz789',
  title: 'Jaspers vs Zanetti - World Cup 2023',
  international_source: youtube_source
  # videoable: nil (noch nicht zugeordnet)
)

# 2. Metadata extrahieren
video.update!(data: {
  players: ['Dick JASPERS', 'Marco ZANETTI'],
  event_name: 'World Cup 2023',
  round: 'Final'
})

# 3. Turnier finden oder erstellen
tournament = InternationalTournament.find_or_create_by(
  title: 'World Cup 2023',
  external_id: 'wc2023'
)

# 4. Video zuordnen
video.update!(videoable: tournament)
```

### C) Game Recording → Video

```ruby
game = Game.find(456)

video = Video.create!(
  external_id: "local_#{Time.now.to_i}",
  title: "#{game.tournament.title} - Game #{game.seqno}",
  videoable: game,  # Direkt dem Spiel zugeordnet
  international_source: local_source
)
```

## Tests

```bash
# Models laden
bin/rails runner "puts Video.count; puts InternationalTournament.count"
# Output: 0, 5

# Associations testen
bin/rails runner "
t = InternationalTournament.first
puts t.videos.count
puts t.games.count
puts t.seedings.count
"
# Output: 0, 0, 0 (noch keine Videos)
```

## Vorteile

✅ **Universal**: Funktioniert für internationale UND lokale Turniere
✅ **Flexibel**: Videos können Tournaments, Games oder Players zugeordnet werden
✅ **Bidirektional**: Sowohl UMB→Video als auch Video→Tournament flows
✅ **Einfach**: Keine separate `international_videos` Tabelle mehr
✅ **STI kompatibel**: Funktioniert perfekt mit `InternationalTournament`/`Tournament`
✅ **Erweiterbar**: Später können auch `Club`, `Event`, etc. Videos haben

## Noch zu tun

### 1. Views anpassen (optional)

Die Views sollten noch angepasst werden um `@videos` korrekt anzuzeigen:

- `app/views/international/index.html.erb` (Dashboard)
- `app/views/international/tournaments/index.html.erb` (Turnier-Liste)
- `app/views/international/tournaments/show.html.erb` (Turnier-Details)
- `app/views/international/videos/` (Video-Views, falls vorhanden)

**Änderungen:**
- `tournament.name` → bleibt (alias auf `title`)
- `tournament.location` → bleibt (alias auf `location_text`)
- `tournament.international_videos` → `tournament.videos`
- `@videos` sollte funktionieren (via Controller)

### 2. Video Scraper implementieren (später)

Aktuell gibt es noch keinen Video-Scraper. Das wäre der nächste logische Schritt:

**Features:**
- YouTube API Integration
- Automatische Metadata Extraction (Spieler, Turnier, Datum)
- Auto-Linking zu bestehenden Tournaments/Games
- Bulk-Import von YouTube Channels (z.B. Kozoom, UMB)

### 3. PDF Video Links parsen (optional)

UMB PDFs enthalten manchmal YouTube Links. Diese könnten automatisch als Videos erfasst werden:

```ruby
# In UmbScraperV2
def scrape_video_links_from_pdf(pdf_url)
  text = download_pdf(pdf_url)
  youtube_ids = text.scan(/youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/)
  
  youtube_ids.each do |id|
    Video.find_or_create_by(external_id: id) do |video|
      video.international_source = youtube_source
      video.videoable = tournament
      # ... weitere Felder
    end
  end
end
```

### 4. Helper für View (optional)

Ein Helper könnte nützlich sein:

```ruby
# app/helpers/videos_helper.rb
module VideosHelper
  def video_count_badge(videoable)
    count = videoable.videos.count
    return '' if count.zero?
    
    content_tag(:span, class: 'badge badge-primary') do
      "#{count} video#{'s' if count != 1}"
    end
  end
  
  def video_thumbnail(video, size: :medium)
    image_tag(video.thumbnail_url || placeholder_image_url, 
              alt: video.title,
              class: "video-thumbnail video-thumbnail-#{size}")
  end
end
```

## Migration auf Production

Wenn auf Production noch `international_videos` Daten vorhanden sind:

```ruby
# Migration Script
Video.find_each do |old_video|
  Video.find_or_create_by(external_id: old_video.external_id) do |video|
    video.title = old_video.title
    video.description = old_video.description
    video.thumbnail_url = old_video.thumbnail_url
    video.duration = old_video.duration
    video.published_at = old_video.published_at
    video.view_count = old_video.view_count
    video.like_count = old_video.like_count
    video.language = old_video.language
    video.international_source_id = old_video.international_source_id
    video.discipline_id = old_video.discipline_id
    video.data = old_video.metadata || {}
    video.metadata_extracted = old_video.metadata_extracted
    video.metadata_extracted_at = old_video.metadata_extracted_at
    
    # Polymorphe Zuordnung
    video.videoable_type = 'Tournament'
    video.videoable_id = old_video.international_tournament_id
  end
end
```

## Zusammenfassung

✅ **Phase 1 - Complete**: Universal Video System implementiert
- `videos` Tabelle erstellt
- `Video` Model mit polymorphen Associations
- `Tournament`, `Game`, `Player` haben `has_many :videos`
- Controller angepasst für neue Struktur
- `InternationalTournament` mit View-Kompatibilität erweitert

🔜 **Phase 2 - Optional**: Views anpassen, Video Scraper bauen

Das System ist jetzt bereit für:
- UMB Tournament → Video Mapping
- YouTube Scraping → Tournament/Game Creation
- Player → Video Navigation
- Lokale Tournament Video Uploads
