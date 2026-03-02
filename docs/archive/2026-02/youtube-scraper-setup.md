# YouTube Scraper - Setup & Usage

## ✅ Migration Complete

Der YouTube Scraper wurde erfolgreich auf das neue **polymorphe `Video` Model** migriert!

### Was wurde migriert:

1. ✅ `YoutubeScraper` Service
2. ✅ `ScrapeYoutubeJob` Background Job
3. ✅ YouTube Rake Tasks
4. ✅ Video Model mit Carom-Detection

### Key Changes:

**ALT (carambus_master):**
```ruby
InternationalVideo.create!(
  international_source: source,
  international_tournament_id: tournament.id,  # Direct FK
  ...
)
```

**NEU (carambus_api):**
```ruby
Video.create!(
  international_source: source,
  videoable_type: nil,  # Polymorphic - initially unassigned
  videoable_id: nil,
  ...
)
```

## Setup

### 1. YouTube API Key

Der Scraper benötigt einen YouTube API Key:

**Option A: Rails Credentials (empfohlen)**
```bash
bin/rails credentials:edit
```

Füge hinzu:
```yaml
youtube_api_key: YOUR_API_KEY_HERE
```

**Option B: Environment Variable**
```bash
export YOUTUBE_API_KEY="YOUR_API_KEY_HERE"
```

### 2. Google API Gem

Already included in Gemfile:
```ruby
gem 'google-api-client'
```

### 3. Known YouTube Channels

Channels sind in `InternationalSource::KNOWN_YOUTUBE_CHANNELS` definiert:

```ruby
KNOWN_YOUTUBE_CHANNELS = {
  kozoom_carom: {
    name: 'Kozoom Carom',
    channel_id: 'UCxxxxx',
    url: 'https://www.youtube.com/@kozoom',
    priority: 1
  },
  pba_tv: {
    name: 'PBA TV',
    channel_id: 'UCxxxxx',
    ...
  }
}
```

## Usage

### Test API Access

```bash
bin/rails youtube:test
```

**Output:**
```
=== Testing YouTube API Access ===
✅ YouTube API is working correctly!
```

### Scrape Single Channel

```bash
bin/rails youtube:scrape_channel[CHANNEL_ID,30]
```

**Example:**
```bash
bin/rails youtube:scrape_channel[UCE5y3n5EXy0qH89qQvuAz_Q,7]
```

**Output:**
```
================================================================================
SCRAPING YOUTUBE CHANNEL
================================================================================
Channel ID: UCE5y3n5EXy0qH89qQvuAz_Q
Days back: 7
================================================================================

✅ Scraped 15 new videos
```

### Scrape All Known Channels

```bash
bin/rails youtube:scrape_all[7]
```

Scrapes all channels defined in `KNOWN_YOUTUBE_CHANNELS` for the last 7 days.

### Search YouTube

```bash
bin/rails youtube:search[50]
```

Searches YouTube for carom-related videos (uses more quota).

### Statistics

```bash
bin/rails youtube:stats
```

**Output:**
```
================================================================================
YOUTUBE SCRAPING STATISTICS
================================================================================

Total videos:        3566
YouTube videos:      3566 (100.0%)

Top YouTube sources:
  PBA TV                            700
  I Love Billiards                  700
  Pro Billiard TV                   682
  Kozoom Carom                      387

New videos (last 7 days): 25
Unassigned videos:        3566 (100.0%)
================================================================================
```

### List Known Channels

```bash
bin/rails youtube:list_channels
```

Shows all configured YouTube channels with their status.

## How It Works

### 1. Channel Scraping Flow

```
1. Get channel info (snippet, contentDetails)
2. Get uploads playlist ID
3. Fetch recent videos from playlist (pages)
4. Filter for carom-related videos (keywords)
5. Get full video details (statistics, duration)
6. Save to Video model (polymorphic, unassigned)
7. Auto-assign discipline if detected
```

### 2. Carom Detection

Uses `Video.contains_carom_keywords?` to filter relevant videos:

```ruby
CAROM_KEYWORDS = [
  # English
  'three cushion', '3-cushion', '3 cushion', 'carom', 'billiard',
  # German
  'dreiband', 'driebanden', 'karambol',
  # Korean
  '당구', '3쿠션', '캐롬',
  # Vietnamese
  'bi-a', 'bida', 'carom',
  # Organizations
  'UMB', 'CEB', 'kozoom',
  # Famous Players
  'verhoeven', 'sanchez', 'zanetti', 'jaspers', ...
]
```

### 3. Video Saving

Videos are saved **unassigned** (polymorphic):

```ruby
Video.create!(
  international_source: source,        # YouTube channel
  external_id: video.id,              # YouTube video ID
  title: video.title,
  description: video.description,
  duration: duration_seconds,
  published_at: video.published_at,
  view_count: video.view_count,
  like_count: video.like_count,
  
  # Polymorphic - initially NULL
  videoable_type: nil,
  videoable_id: nil,
  
  # Metadata
  data: { year: 2025 }
)
```

Later, videos can be assigned to:
- `Tournament` (videoable_type: 'Tournament')
- `Game` (videoable_type: 'Game')
- `Player` (videoable_type: 'Player')

### 4. Discipline Auto-Assignment

After saving, the scraper calls:

```ruby
video.auto_assign_discipline!
```

This automatically detects and assigns the discipline (Dreiband, Pool, etc.) based on title/description keywords.

## Background Job

For scheduled/automated scraping:

```ruby
# Run daily
ScrapeYoutubeJob.perform_later(days_back: 1)

# Specific channel
ScrapeYoutubeJob.perform_later(channel_id: 'UCxxxxx', days_back: 7)
```

Can be scheduled with:
- Cron
- Sidekiq Scheduler
- Whenever gem
- Heroku Scheduler

## Quota Management

YouTube API has daily quota limits (10,000 units/day).

**Cost per operation:**
- List channel: 1 unit
- List playlist items: 1 unit
- List videos: 1 unit
- Search: 100 units (expensive!)

**Scraping 1 channel:**
- ~3 units per video
- ~150 units for 50 videos
- Safe to scrape ~60 channels/day

**Recommendations:**
1. Scrape known channels daily (low quota)
2. Use search sparingly (high quota)
3. Monitor quota usage in Google Console
4. Use `days_back: 1` for daily runs

## Data Flow

### Current State (after migration)

```
Videos: 3,566
  - All YouTube
  - All unassigned (videoable_id: NULL)
  - 100% metadata extracted
```

### Next Steps

1. **Auto-Matching** - Match videos to games/tournaments
2. **Manual Review** - UI for assigning videos
3. **Continued Scraping** - Daily updates

## Integration with Existing System

### Works with STI Models

```ruby
# InternationalTournament can have videos
tournament = InternationalTournament.find(123)
tournament.videos  # => polymorphic association works!

# InternationalGame can have videos  
game = InternationalGame.find(456)
game.videos  # => polymorphic association works!
```

### Navigation Paths

```ruby
# Player → Videos
player = Player.find_by(lastname: 'JASPERS')
videos = Video.where("title ILIKE ?", "%JASPERS%")

# Tournament → Videos
tournament = InternationalTournament.find(123)
direct_videos = tournament.videos
game_videos = Video.for_games.where(videoable_id: tournament.games.ids)

# Video → Tournament (if assigned)
video = Video.find(789)
tournament = video.videoable if video.videoable_type == 'Tournament'
```

## Testing

### Test API Key

```bash
bin/rails youtube:test
```

### Test Single Channel (dry run)

```bash
# Find channel ID first
bin/rails youtube:find_channel[@kozoom]

# Then scrape
bin/rails youtube:scrape_channel[UC_CHANNEL_ID,7]
```

### Verify Results

```bash
# Check stats
bin/rails youtube:stats

# Check database
bin/rails runner "
  puts Video.youtube.count
  puts Video.youtube.unassigned.count
  puts Video.youtube.order(:created_at).last.title
"
```

## Production Deployment

### 1. Set API Key

On production server:

```bash
# Option A: Credentials
EDITOR=nano bin/rails credentials:edit --environment production

# Option B: Environment
export YOUTUBE_API_KEY="xxx"
```

### 2. Schedule Daily Scraping

**Cron:**
```bash
# Every day at 3am
0 3 * * * cd /var/www/carambus_api/current && bin/rails youtube:scrape_all[1]
```

**Sidekiq Scheduler:**
```yaml
# config/sidekiq.yml
:schedule:
  scrape_youtube:
    cron: '0 3 * * *'
    class: ScrapeYoutubeJob
    queue: low_priority
    args: [days_back: 1]
```

### 3. Monitor

- Check logs: `tail -f log/production.log | grep YouTube`
- Check quota: Google Cloud Console
- Check stats: `bin/rails youtube:stats`

## Troubleshooting

### API Key Error

```
YouTube API Key not found
```

**Fix:** Set `youtube_api_key` in credentials or `YOUTUBE_API_KEY` env var.

### Quota Exceeded

```
YouTube API error: quotaExceeded
```

**Fix:** 
- Wait until next day (quota resets at midnight Pacific Time)
- Reduce scraping frequency
- Use `days_back: 1` instead of 7+

### No Videos Found

```
Filtered to 0 carom-related videos
```

**Fix:**
- Check if channel actually has carom content
- Adjust `CAROM_KEYWORDS` in `Video` model
- Check channel ID is correct

## Success Metrics

✅ **System Status:**
- YouTube Scraper migrated to new Video model
- Polymorphic associations working
- All 3,566 production videos imported
- Carom detection functional
- Auto-discipline assignment working

✅ **Ready for:**
- Daily YouTube scraping
- Video discovery
- Auto-matching to games/tournaments
- Player highlights
- Content analytics

---

**Status: Production Ready** 🚀
