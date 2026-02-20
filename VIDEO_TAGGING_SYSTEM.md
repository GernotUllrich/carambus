# Video Tagging System - Complete Implementation ✅

## Übersicht

Ein flexibles Video-Tagging-System basierend auf JSONB-Arrays im `data` Feld der `videos` Tabelle. Unterstützt automatische Tag-Erkennung und hierarchische Filterung.

## Features

✅ **Auto-Detection**: Automatische Erkennung von Content-Types, Spielern und Qualität
✅ **JSONB-basiert**: Keine zusätzlichen Tabellen, nutzt bestehendes `data` Feld
✅ **Hierarchische Filter**: Strukturierte Tag-Gruppen wie Disziplin-Filter
✅ **Top 32 Player**: World Cup Top 32 Spieler automatisch erkennbar
✅ **Flexible Erweiterung**: Neue Tags einfach hinzufügbar

---

## Tag-Kategorien

### 1. Content Type Tags (Auto-Detection)

| Tag | Erkennung | Bedingung |
|-----|-----------|-----------|
| `full_game` | Dauer > 30min + "vs" + 2 Spieler | Vollständige Spiele |
| `shot_of_the_day` | Dauer < 5min + Keywords | Highlight-Shots |
| `high_run` | "high run" + Zahl > 10 | Hohe Serien |
| `highlights` | "highlights" / "best of" | Zusammenfassungen |
| `training` | "training" / "lesson" | Trainings-Videos |

**Beispiel Auto-Detection:**
```ruby
video = Video.find(123)
video.detect_content_type_tags
# => ["full_game", "high_run"]
```

### 2. Player Tags (Top 32 World Cup)

Automatische Erkennung der Top 32 World Cup Spieler:

| Rank | Player | Tag | Country |
|------|--------|-----|---------|
| 1 | CHO Myung Woo | `cho` | 🇰🇷 KR |
| 2 | Dick JASPERS | `jaspers` | 🇳🇱 NL |
| 3 | Tayfun TASDEMIR | `tasdemir` | 🇹🇷 TR |
| 4 | Eddy MERCKX | `merckx` | 🇧🇪 BE |
| 5 | Marco ZANETTI | `zanetti` | 🇮🇹 IT |
| ... | ... | ... | ... |

Vollständige Liste in `InternationalHelper::WORLD_CUP_TOP_32`

**Beispiel Auto-Detection:**
```ruby
video = Video.find(123)
video.title = "Jaspers vs Zanetti - World Cup 2025"
video.detect_player_tags
# => ["jaspers", "zanetti"]
```

### 3. Quality Tags

| Tag | Erkennung | Beschreibung |
|-----|-----------|--------------|
| `4k` | "4K" / "2160p" | Ultra HD |
| `hd` | "HD" / "1080p" / "720p" | High Definition |
| `slow_motion` | "slow motion" / "slow-mo" | Zeitlupe |
| `multi_angle` | "multi-angle" | Mehrere Kameras |

---

## Implementierung

### Model: `Video` (`app/models/video.rb`)

#### Scopes für Filterung

```ruby
# Einzelner Tag
Video.with_tag('full_game')

# Einer von mehreren Tags (OR)
Video.with_any_tag(['jaspers', 'zanetti'])

# Alle Tags müssen vorhanden sein (AND)
Video.with_all_tags(['full_game', 'hd'])

# Videos ohne Tags
Video.without_tags
```

#### Instance Methods

```ruby
video = Video.find(123)

# Tags lesen/schreiben
video.tags                    # => ["full_game", "jaspers"]
video.tags = ['full_game']    # Set tags
video.add_tag('hd')           # Add single tag
video.remove_tag('training')  # Remove tag
video.tagged_with?('hd')      # => true/false

# Auto-Detection
video.detect_player_tags      # => ["jaspers", "zanetti"]
video.detect_content_type_tags # => ["full_game"]
video.detect_quality_tags     # => ["hd"]
video.detect_all_tags         # => alle erkannten Tags

# Auto-Tagging (speichert automatisch)
video.auto_tag!               # Fügt alle erkannten Tags hinzu

# Vorschläge (ohne Speichern)
video.suggested_tags          # => Tags die noch nicht gesetzt sind
```

### Helper: `InternationalHelper` (`app/helpers/international_helper.rb`)

#### Konstanten

```ruby
# Top 32 Spieler
InternationalHelper::WORLD_CUP_TOP_32
# => { 'CHO' => { full_name: 'CHO Myung Woo', country: 'KR', rank: 1 }, ... }

# Tag-Gruppen für hierarchische Filter
InternationalHelper::VIDEO_TAG_GROUPS
# => {
#   'Content Type' => { tags: [...], icon: '🎬' },
#   'Top Players' => { tags: [...], icon: '⭐', grouped_by_country: true },
#   'Quality' => { tags: [...], icon: '🎥' }
# }
```

#### Helper Methods

```ruby
# Spieler nach Land gruppiert
InternationalHelper.player_tags_by_country
# => { 'KR' => [{tag: 'CHO', name: 'CHO Myung Woo', rank: 1}, ...], ... }

# Badge CSS Klassen
video_tag_badge_class('full_game')
# => 'bg-blue-100 text-blue-800'
```

---

## Verwendung

### 1. Manuelles Tagging

```ruby
video = Video.find(123)
video.tags = ['full_game', 'jaspers', 'zanetti', 'hd']
video.save
```

### 2. Auto-Tagging bei Video-Import

```ruby
# In ScrapeYoutubeJob oder ähnlich
video = Video.create!(
  external_id: 'abc123',
  title: 'Dick Jaspers vs Marco Zanetti - World Cup 2025 Final',
  duration: 3600,
  # ...
)

# Auto-Tag direkt nach Import
video.auto_tag!
# => Tags: ["full_game", "jaspers", "zanetti"]
```

### 3. Bulk Auto-Tagging (Job)

```ruby
# Job für bestehende Videos
class AutoTagVideosJob < ApplicationJob
  def perform(video_ids = nil)
    scope = video_ids ? Video.where(id: video_ids) : Video.without_tags
    
    scope.find_each do |video|
      video.auto_tag!
    rescue StandardError => e
      Rails.logger.error("Auto-tag failed for video #{video.id}: #{e.message}")
    end
  end
end

# Ausführen
AutoTagVideosJob.perform_later
```

### 4. Controller Filterung

```ruby
# VideosController
class VideosController < ApplicationController
  def index
    @videos = Video.recent
    
    # Filter nach Tag
    if params[:tag].present?
      @videos = @videos.with_tag(params[:tag])
    end
    
    # Filter nach mehreren Tags (OR)
    if params[:tags].present?
      @videos = @videos.with_any_tag(params[:tags])
    end
    
    # Filter nach Disziplin + Tags kombiniert
    if params[:discipline_id].present?
      @videos = @videos.by_discipline(params[:discipline_id])
    end
    
    @videos = @videos.page(params[:page])
  end
end
```

### 5. View - Hierarchischer Filter

```erb
<!-- app/views/videos/_filter.html.erb -->
<div class="filters">
  <h3>Filter Videos</h3>
  
  <!-- Content Type -->
  <div class="filter-group">
    <h4>🎬 Content Type</h4>
    <% InternationalHelper::VIDEO_TAG_GROUPS['Content Type'][:tags].each do |tag| %>
      <%= link_to tag.titleize, 
                  videos_path(tag: tag), 
                  class: "badge #{video_tag_badge_class(tag)}" %>
    <% end %>
  </div>
  
  <!-- Top Players (gruppiert nach Land) -->
  <div class="filter-group">
    <h4>⭐ Top Players</h4>
    <% InternationalHelper.player_tags_by_country.each do |country, players| %>
      <div class="country-group">
        <strong><%= country %></strong>
        <% players.take(5).each do |player| %>
          <%= link_to player[:name].split(' ').last, 
                      videos_path(tag: player[:tag].downcase),
                      class: "badge bg-gray-100 text-gray-800" %>
        <% end %>
      </div>
    <% end %>
  </div>
  
  <!-- Quality -->
  <div class="filter-group">
    <h4>🎥 Quality</h4>
    <% InternationalHelper::VIDEO_TAG_GROUPS['Quality'][:tags].each do |tag| %>
      <%= link_to tag.upcase, 
                  videos_path(tag: tag), 
                  class: "badge #{video_tag_badge_class(tag)}" %>
    <% end %>
  </div>
</div>
```

---

## Migration Path

### Schritt 1: Bestehende Videos taggen

```bash
# Rails Console
bin/rails c

# Alle Videos ohne Tags auto-taggen
Video.without_tags.find_each(&:auto_tag!)

# Nur bestimmte Videos
Video.where(published_at: 1.year.ago..Time.current).find_each(&:auto_tag!)
```

### Schritt 2: Integration in Scraper

```ruby
# app/services/youtube_scraper.rb
def import_video(youtube_data)
  video = Video.create!(
    external_id: youtube_data[:id],
    title: youtube_data[:title],
    # ...
  )
  
  # Auto-Tag direkt nach Import
  video.auto_tag!
  
  video
end
```

### Schritt 3: Admin Interface (Optional)

```ruby
# app/views/admin/videos/edit.html.erb
<div class="form-group">
  <label>Tags</label>
  <div>
    <% @video.tags.each do |tag| %>
      <%= content_tag(:span, tag, class: "badge #{video_tag_badge_class(tag)}") %>
      <%= link_to '×', remove_tag_admin_video_path(@video, tag: tag), 
                  method: :delete, 
                  class: 'remove-tag' %>
    <% end %>
  </div>
  
  <h4>Suggested Tags</h4>
  <% @video.suggested_tags.each do |tag| %>
    <%= link_to "+ #{tag}", 
                add_tag_admin_video_path(@video, tag: tag), 
                method: :post,
                class: "badge badge-secondary" %>
  <% end %>
</div>
```

---

## Erweiterungen

### Neue Tags hinzufügen

**1. Content Type Tag:**

```ruby
# app/models/video.rb
CONTENT_TYPE_DETECTORS = {
  # ... bestehende Tags ...
  'interview' => lambda { |video|
    video.title.downcase.match?(/interview|talk|conversation/)
  }
}.freeze
```

**2. Player hinzufügen:**

```ruby
# app/helpers/international_helper.rb
WORLD_CUP_TOP_32 = {
  # ... bestehende Spieler ...
  'NEUER_SPIELER' => { full_name: 'Max Mustermann', country: 'DE', rank: 33 }
}.freeze
```

**3. Neue Tag-Gruppe:**

```ruby
# app/helpers/international_helper.rb
VIDEO_TAG_GROUPS = {
  # ... bestehende Gruppen ...
  'Language' => {
    tags: ['english', 'german', 'korean', 'vietnamese'],
    icon: '🌐'
  }
}.freeze
```

---

## Performance

### JSONB Indexing

Für bessere Performance bei vielen Videos:

```ruby
# Migration
class AddGinIndexToVideosTags < ActiveRecord::Migration[7.2]
  def change
    add_index :videos, :data, 
              using: :gin, 
              opclass: :jsonb_path_ops,
              algorithm: :concurrently
  end
end
```

### Query Optimization

```ruby
# Gut: Nutzt JSONB Operatoren
Video.with_any_tag(['jaspers', 'zanetti'])

# Besser: Mit Eager Loading
Video.with_any_tag(['jaspers', 'zanetti'])
     .includes(:international_source, :discipline)
     .recent
     .limit(50)
```

---

## Testing

```ruby
# test/models/video_test.rb
class VideoTest < ActiveSupport::TestCase
  test "detects full game" do
    video = videos(:long_game)
    assert_includes video.detect_content_type_tags, 'full_game'
  end
  
  test "detects player tags" do
    video = videos(:jaspers_vs_zanetti)
    tags = video.detect_player_tags
    assert_includes tags, 'jaspers'
    assert_includes tags, 'zanetti'
  end
  
  test "auto tagging works" do
    video = videos(:untagged_game)
    video.auto_tag!
    assert video.tags.any?
  end
end
```

---

## Vorteile dieser Lösung

✅ **Einfach**: Nutzt bestehendes `data` JSONB Feld
✅ **Flexibel**: Neue Tags ohne Migration hinzufügbar
✅ **Performant**: GIN Index für schnelle JSONB-Queries
✅ **Automatisiert**: Auto-Detection spart manuelle Arbeit
✅ **Skalierbar**: Funktioniert mit vielen Tags und Videos
✅ **Hierarchisch**: Strukturierte Filter wie Disziplinen

---

## Nächste Schritte

1. ✅ **Phase 1 Complete**: Tag-System implementiert
2. 🔜 **Phase 2**: Controller & Views mit Filterung erstellen
3. 🔜 **Phase 3**: Admin-Interface für manuelles Tagging
4. 🔜 **Phase 4**: Bulk Auto-Tagging Job für bestehende Videos

---

## Zusammenfassung

Das Video-Tagging-System ist vollständig implementiert und einsatzbereit:

- ✅ `InternationalHelper` mit Top 32 Spielern und Tag-Gruppen
- ✅ `Video` Model mit Auto-Detection und Scopes
- ✅ Helper Methods für Badge-Styles
- ✅ Flexible JSONB-basierte Tag-Speicherung
- ✅ Hierarchische Filter-Struktur vorbereitet

**Verwendung:**
```ruby
# Auto-Tagging
video.auto_tag!

# Filterung
Video.with_tag('full_game')
Video.with_any_tag(['jaspers', 'zanetti'])

# Vorschläge
video.suggested_tags
```
