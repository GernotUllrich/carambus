# Video System Redesign - Universal Video Management

## Problem
Das alte `international_videos` System war zu spezifisch. Wir brauchen ein universelles Video-System für:

1. **UMB Turniere** → Videos von offiziellen Seiten
2. **Lokale Turniere** → eigene Aufnahmen
3. **YouTube Scraping** → Videos finden → Turniere/Spiele erstellen

## Lösung: Polymorphe Videos

### 1. Neue `videos` Tabelle (für ALLE Videos)

```ruby
create_table :videos do |t|
  # Basis-Info
  t.string :external_id, null: false, index: { unique: true }
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
  t.references :international_source  # YouTube, Kozoom, etc.
  
  # Polymorphe Associations
  t.references :videoable, polymorphic: true, index: true
  # videoable_type: 'Tournament', 'Game', 'Player', nil
  # videoable_id: tournament_id, game_id, player_id, null
  
  # Metadata & Processing
  t.jsonb :data, default: {}
  t.boolean :metadata_extracted, default: false, index: true
  t.datetime :metadata_extracted_at
  
  # Optional: Discipline detection
  t.references :discipline
  
  t.timestamps
end

# Indexes
add_index :videos, :published_at
add_index :videos, [:videoable_type, :videoable_id, :published_at],
          name: 'idx_videos_on_videoable_and_published'
```

### 2. Model: `Video` (universal)

```ruby
class Video < ApplicationRecord
  # Polymorphe Association
  belongs_to :videoable, polymorphic: true, optional: true
  belongs_to :international_source
  belongs_to :discipline, optional: true
  
  # Validations
  validates :external_id, presence: true, uniqueness: true
  validates :title, presence: true
  
  # Scopes
  scope :recent, -> { order(published_at: :desc) }
  scope :for_tournaments, -> { where(videoable_type: 'Tournament') }
  scope :for_games, -> { where(videoable_type: 'Game') }
  scope :for_players, -> { where(videoable_type: 'Player') }
  scope :unassigned, -> { where(videoable_id: nil) }
  scope :youtube, -> { joins(:international_source).where(international_sources: { source_type: 'youtube' }) }
  
  # Helper methods (same as InternationalVideo)
  def youtube_url
    return nil unless international_source.source_type == 'youtube'
    "https://www.youtube.com/watch?v=#{external_id}"
  end
  
  def youtube_embed_url
    return nil unless international_source.source_type == 'youtube'
    "https://www.youtube.com/embed/#{external_id}"
  end
  
  # Metadata helpers
  def json_data
    @json_data ||= begin
      return {} if data.blank?
      data.is_a?(String) ? JSON.parse(data) : data
    rescue JSON::ParserError
      {}
    end
  end
  
  def extracted_players
    json_data['players'] || []
  end
  
  def extracted_event_name
    json_data['event_name']
  end
end
```

### 3. Associations in Models

**Tournament:**
```ruby
class Tournament < ApplicationRecord
  has_many :videos, as: :videoable, dependent: :nullify
  # ...
end

class InternationalTournament < Tournament
  # Videos automatisch vererbt!
end
```

**Game:**
```ruby
class Game < ApplicationRecord
  has_many :videos, as: :videoable, dependent: :nullify
  # ...
end

class InternationalGame < Game
  # Videos automatisch vererbt!
end
```

**Player:**
```ruby
class Player < ApplicationRecord
  has_many :videos, as: :videoable, dependent: :nullify
  # Alle Videos in denen der Player vorkommt
end
```

### 4. Use Cases

#### A) UMB Turnier → Videos zuordnen
```ruby
tournament = InternationalTournament.find(123)
video = Video.create!(
  external_id: 'abc123',
  title: 'World Cup Final',
  international_source: youtube_source,
  videoable: tournament  # Polymorphe Zuordnung!
)
```

#### B) Video → Turnier erstellen (Scraping)
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

# 3. Turnier erstellen oder finden
tournament = InternationalTournament.find_or_create_by(
  title: 'World Cup 2023',
  external_id: 'wc2023'
)

# 4. Video zuordnen
video.update!(videoable: tournament)
```

#### C) Video direkt einem Game zuordnen
```ruby
game = Game.find(456)
video = Video.create!(
  external_id: 'def456',
  title: 'Game Recording',
  videoable: game  # Direkt dem Spiel zugeordnet
)
```

#### D) Alle Videos eines Spielers
```ruby
player = Player.find_by(umb_player_id: 12345)

# Via GameParticipations
videos = Video.joins(videoable: :game_participations)
              .where(game_participations: { player_id: player.id })
              
# Oder direkt assigned
player_videos = player.videos
```

### 5. Navigation Paths (UI)

#### Player → Videos
```ruby
# app/controllers/players_controller.rb
def show
  @player = Player.find(params[:id])
  
  # Videos von Spielen
  @game_videos = Video.for_games
                      .joins("INNER JOIN game_participations ON 
                             game_participations.game_id = videos.videoable_id")
                      .where(game_participations: { player_id: @player.id })
                      .distinct
  
  # Direkt zugeordnete Videos
  @player_videos = @player.videos
end
```

#### Tournament → Videos
```ruby
# app/controllers/tournaments_controller.rb
def show
  @tournament = Tournament.find(params[:id])
  
  # Videos vom Turnier
  @tournament_videos = @tournament.videos
  
  # Videos von Spielen des Turniers
  @game_videos = Video.for_games
                      .where(videoable_id: @tournament.games.pluck(:id))
end
```

#### Video → Related Content
```ruby
# app/controllers/videos_controller.rb
def show
  @video = Video.find(params[:id])
  
  case @video.videoable_type
  when 'Tournament'
    @tournament = @video.videoable
    @games = @tournament.games
  when 'Game'
    @game = @video.videoable
    @tournament = @game.tournament
    @players = @game.players
  when 'Player'
    @player = @video.videoable
    # ... player details
  end
end
```

### 6. Migration Plan

#### Phase 1: Create `videos` table
```bash
rails g migration CreateVideos
```

#### Phase 2: Migrate old InternationalVideo data (if any on production)
```ruby
# Wenn auf production noch InternationalVideo Daten sind:
InternationalVideo.find_each do |old_video|
  Video.create!(
    external_id: old_video.external_id,
    title: old_video.title,
    description: old_video.description,
    # ... copy all fields
    videoable_type: 'Tournament',
    videoable_id: old_video.international_tournament_id,
    data: old_video.metadata || {}
  )
end
```

#### Phase 3: Update Controllers/Views
- Replace `InternationalVideo` with `Video`
- Use polymorphic associations

#### Phase 4: Video Scraper
- YouTube scraper → creates `Video` records
- Metadata extraction → fills `data` field
- Auto-linking → finds/creates Tournaments/Games

## Vorteile

✅ **Universal**: Funktioniert für internationale UND lokale Turniere
✅ **Flexibel**: Videos können Tournaments, Games oder Players zugeordnet werden
✅ **Bidirektional**: Sowohl UMB→Video als auch Video→Tournament flows
✅ **Einfach**: Keine separate `international_videos` Tabelle mehr
✅ **STI kompatibel**: Funktioniert perfekt mit `InternationalTournament`/`Tournament`
✅ **Erweiterbar**: Später können auch `Club`, `Event`, etc. Videos haben

## Migration Reihenfolge

1. ✅ `videos` Tabelle erstellen
2. ✅ `Video` Model erstellen
3. ✅ Polymorphe Associations in `Tournament`, `Game`, `Player`
4. ✅ Controllers anpassen
5. ✅ Views anpassen
6. ✅ Video Scraper bauen (später)

## Soll ich das implementieren?
