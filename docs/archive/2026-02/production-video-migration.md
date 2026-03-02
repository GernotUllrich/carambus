# Production Video Migration Plan

## Discovered Data

### Production Database Status (carambus_api_production)

```
Total Videos: 3.566
Tournaments with videos: 12
Video sources: 12
Date range: 2025-02-18 to 2026-02-18
```

### Video Distribution

| Status | Count | Percentage |
|--------|-------|------------|
| **Unassigned** | 3.307 | 92.7% |
| **Assigned to tournaments** | 259 | 7.3% |

**Top Tournaments (by video count):**
- Tournament ID 22: 113 videos
- Tournament ID 26: 94 videos
- Tournament ID 16: 14 videos
- Tournament ID 18: 12 videos

### Sample Unassigned Videos

```
- "China World Game 2025 | Group A | Cho Myung Woo vs Martin Horn"
- "3 Cushion Billiards Bricol Shot #164"
- "3 Cushion Billiards Shots #515"
- "무슨 설명이 더 필요합니까 #산체스 #PBA #VAMOS_DANI" (Korean)
```

→ **Viele Videos sind YouTube-Scraped und noch nicht Turnieren zugeordnet!**

## Migration Strategy

### Option A: Full Migration (Empfohlen) ✅

**Was wird migriert:**
- Alle 3.566 Videos
- Metadata (JSONB)
- YouTube IDs, Titles, Descriptions
- Timestamps (published_at, created_at)
- View/Like counts
- Extraction status

**Mapping:**
- `international_videos.international_tournament_id` → `videos.videoable_id` (type: Tournament)
- Unassigned videos bleiben unassigned (`videoable_id = NULL`)
- Können später über Metadata-Matching zugeordnet werden

**Vorteile:**
- ✅ Keine Datenverluste
- ✅ Große YouTube-Sammlung erhalten (3.307 Videos!)
- ✅ Später automatisch Turnieren zuordnen via Metadata
- ✅ Basis für Video-Discovery/Matching

**Nachteile:**
- ⚠️ Viele unzugeordnete Videos (aber das ist OK!)

### Option B: Nur Tournament-Videos

**Was wird migriert:**
- Nur 259 Videos die Turnieren zugeordnet sind

**Vorteile:**
- ✅ Sauberer Start
- ✅ Schneller

**Nachteile:**
- ❌ 3.307 YouTube-Videos gehen verloren
- ❌ Wertvoll für Discovery/Matching

## Empfehlung: Option A

Die unassigned Videos sind **wertvoll**:
1. **Große Datensammlung** (3.307 Videos)
2. **Metadata ist extrahiert** (`metadata_extracted = true`)
3. **Können später automatisch matched werden**:
   - Via Player names
   - Via Tournament names
   - Via Dates
4. **Basis für AI/ML Video-Discovery**

## Migration Steps

### 1. Vorbereitung

```bash
# Gemfile (pg gem für direkte DB connection)
gem 'pg'

# Install
bundle install

# Environment Variable setzen
export PROD_DB_PASSWORD="<password_from_database.yml>"
```

### 2. Dry Run (Preview)

```bash
cd /Volumes/EXT2TB/gullrich/DEV/carambus/carambus_api
bin/rails videos:dry_run
```

**Output:**
```
Total videos in production: 3566

By assignment status:
  Assigned: 259
  Unassigned: 3307

Top 5 video sources:
  YouTube: 3500
  Kozoom: 66

Sample unassigned videos:
  [2026-02-18] China World Game 2025... (1N9Zt0O-Vac)
  ...
```

### 3. Migration ausführen

```bash
# WICHTIG: Zuerst Tournaments migrieren (falls noch nicht geschehen)
bin/rails umb_v2:scrape_range[1,500]

# Dann Videos
PROD_DB_PASSWORD="xxx" bin/rails videos:migrate_from_production
```

**Output:**
```
VIDEO MIGRATION: international_videos → videos
================================================

1. Connecting to production database...
   ✓ Connected to api.carambus.net
   ✓ Found 3566 videos in production

2. Fetching videos from production...
   ✓ Fetched 3566 videos

3. Migrating videos to new table...
   ... 100/3566 processed (100 migrated, 0 skipped)
   ... 200/3566 processed (200 migrated, 0 skipped)
   ...

================================================
MIGRATION COMPLETE
================================================
Total videos in production: 3566
Successfully migrated:      3566
Skipped (already exists):   0
Errors:                     0
================================================

4. New Video Statistics:
   Total videos:                3566
   Assigned to tournaments:     259
   Unassigned:                  3307
   YouTube videos:              3500
   Metadata extracted:          3566
```

### 4. Verification

```bash
# Check counts
bin/rails runner "
  puts 'Videos total: ' + Video.count.to_s
  puts 'Assigned: ' + Video.where.not(videoable_id: nil).count.to_s
  puts 'Unassigned: ' + Video.unassigned.count.to_s
  puts 'YouTube: ' + Video.youtube.count.to_s
"

# Check sample video
bin/rails runner "
  v = Video.first
  puts 'Title: ' + v.title
  puts 'External ID: ' + v.external_id
  puts 'YouTube URL: ' + v.youtube_url.to_s
  puts 'Tournament: ' + (v.videoable ? v.videoable.title : 'unassigned')
"
```

## Post-Migration: Auto-Matching

Nach der Migration können unassigned Videos automatisch matched werden:

### Strategy 1: Player Name Matching

```ruby
# lib/tasks/video_matching.rake
namespace :videos do
  desc "Auto-match videos to tournaments via player names"
  task auto_match: :environment do
    unassigned = Video.unassigned.where(metadata_extracted: true)
    
    unassigned.find_each do |video|
      players = video.extracted_players
      next if players.blank?
      
      # Find games with these players
      games = Game.joins(:game_participations, :players)
                  .where(players: { fl_name: players })
                  .where('games.started_at::date = ?', video.published_at.to_date)
                  .distinct
      
      if games.count == 1
        video.update!(videoable: games.first)
        puts "✓ Matched: #{video.title} → Game #{games.first.id}"
      end
    end
  end
end
```

### Strategy 2: Event Name + Date Matching

```ruby
namespace :videos do
  desc "Auto-match via event name and date"
  task match_by_event: :environment do
    Video.unassigned.find_each do |video|
      event_name = video.extracted_event_name
      next if event_name.blank?
      
      # Find tournaments by name and date
      tournaments = InternationalTournament
                     .where("title ILIKE ?", "%#{event_name}%")
                     .where("date::date = ?", video.published_at.to_date)
      
      if tournaments.count == 1
        video.update!(videoable: tournaments.first)
        puts "✓ Matched: #{video.title} → #{tournaments.first.title}"
      end
    end
  end
end
```

### Strategy 3: Manual Review UI

```ruby
# app/controllers/admin/video_matching_controller.rb
class Admin::VideoMatchingController < ApplicationController
  def index
    @unmatched_videos = Video.unassigned
                             .where(metadata_extracted: true)
                             .order(published_at: :desc)
                             .page(params[:page])
    
    # Show potential matches
    @unmatched_videos.each do |video|
      video.potential_matches = find_potential_matches(video)
    end
  end
  
  def assign
    video = Video.find(params[:id])
    video.update!(
      videoable_type: params[:videoable_type],
      videoable_id: params[:videoable_id]
    )
    redirect_back fallback_location: admin_video_matching_path
  end
  
  private
  
  def find_potential_matches(video)
    # Logic to suggest tournaments/games
    # Based on: players, date, event name
  end
end
```

## Benefits of Migrating All Videos

### 1. Discovery Engine
```ruby
# Find all videos about a player
player = Player.find_by(lastname: 'JASPERS')
jaspers_videos = Video.where("data->>'players' ILIKE ?", "%JASPERS%")
```

### 2. Tournament Enrichment
```ruby
# Find videos for tournaments without assigned videos
tournament = InternationalTournament.find_by(title: 'World Cup 2023')
potential_videos = Video.unassigned
                        .where("title ILIKE ?", "%World Cup 2023%")
                        .where("published_at >= ? AND published_at <= ?", 
                               tournament.date, tournament.end_date)
```

### 3. Analytics
```ruby
# Most viewed players
Video.where("data->>'players' IS NOT NULL")
     .group("data->>'players'")
     .order("SUM(view_count) DESC")
     .limit(10)
```

### 4. Video Recommendations
```ruby
# "Similar videos" feature
game = Game.find(123)
players = game.players.pluck(:fl_name)
similar_videos = Video.where("data->>'players' ?| array[:names]", names: players)
                      .where.not(id: game.videos.pluck(:id))
```

## Timeline

1. **Jetzt (Development)**:
   - ✅ Migration Script erstellt
   - 🔜 Dry Run testen
   - 🔜 Migration ausführen

2. **Phase 2** (Optional):
   - Auto-Matching implementieren
   - Manual Review UI
   - Video Discovery Features

3. **Production**:
   - Migration Script auf Production laufen lassen
   - Oder: Videos direkt in production migrieren (neue `videos` Tabelle)

## Risk Assessment

**Low Risk** ✅
- Migration ist read-only (production data bleibt unberührt)
- Kann jederzeit wiederholt werden
- Rollback: Einfach `videos` Tabelle leeren

**Testing:**
```bash
# Before migration
bin/rails runner "puts Video.count"  # => 0

# After migration
bin/rails runner "puts Video.count"  # => 3566

# Rollback (if needed)
bin/rails runner "Video.delete_all"  # => 0
```

## Conclusion

**Empfehlung: ALLE 3.566 Videos migrieren** ✅

Die unassigned Videos sind wertvoll für:
- Video Discovery
- Future Matching (AI/ML)
- Analytics
- Player Highlight Reels
- Tournament Enrichment

Das neue polymorphe Video-System ist perfekt dafür designed!
