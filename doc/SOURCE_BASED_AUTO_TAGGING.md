# Source-Based Auto-Tagging for Videos

## Overview

Videos from specific sources can now be automatically tagged with predefined tags. This is useful when certain channels consistently produce content of a specific type (e.g., training videos, tournament coverage, etc.).

## How It Works

1. **Configuration**: Default tags are configured in the `KNOWN_YOUTUBE_CHANNELS` or `KNOWN_FIVESIX_CHANNELS` constants in `app/models/international_source.rb`
2. **Storage**: When sources are seeded, the default tags are stored in the `metadata` JSONB field
3. **Application**: When videos are auto-tagged (via `video.auto_tag!`), source-based tags are automatically included

## Configuration

### Adding Default Tags to a Source

Edit the channel configuration in `app/models/international_source.rb`:

```ruby
KNOWN_YOUTUBE_CHANNELS = {
  "fred_coudron" => {
    name: "Fred Coudron",
    channel_id: "UCpkOaTxfSpYa6npVpBcn-TA",
    base_url: "https://www.youtube.com/channel/UCpkOaTxfSpYa6npVpBcn-TA",
    priority: 2,
    description: "Billiard videos from Frédéric Caudron",
    default_tags: ["training"]  # ← Add this line
  }
}
```

### Example Use Cases

Here are some common tag assignments:

```ruby
# Training/Tutorial channels
default_tags: ["training"]

# Tournament coverage channels
default_tags: ["tournament", "official"]

# Highlight channels
default_tags: ["highlights"]

# Multiple tags
default_tags: ["training", "high_quality", "instructional"]
```

## Applying Tags to Existing Sources

After adding default_tags to the configuration, you need to:

1. **Re-seed the sources** to update the metadata:
   ```bash
   rails console
   InternationalSource.seed_known_sources
   ```

2. **Re-tag existing videos** from those sources:
   ```bash
   rails international:process_all_videos
   ```

   Or for a specific source:
   ```ruby
   source = InternationalSource.find_by(name: "Fred Coudron")
   source.videos.find_each { |video| video.auto_tag! }
   ```

## Manual Override

You can also set default tags for a source directly in the database:

```ruby
source = InternationalSource.find_by(name: "Fred Coudron")
source.metadata = source.metadata.merge("default_tags" => ["training", "instructional"])
source.save
```

## How Tags Are Applied

When `video.auto_tag!` is called, it combines tags from multiple sources:

1. **Player tags**: Detected from title/description (e.g., "zanetti", "jaspers")
2. **Content type tags**: Detected from content analysis (e.g., "full_game", "highlights")
3. **Quality tags**: Detected from title (e.g., "4k", "hd")
4. **Source tags**: Based on the video's source (e.g., "training" for Fred Coudron videos)

All tags are combined and deduplicated automatically.

## Suggested Channels for Default Tags

Here are some recommended default_tags for existing channels:

```ruby
# Training/Educational Content
"fred_coudron" => { default_tags: ["training"] }
"carom_lab_korea" => { default_tags: ["training", "educational"] }

# Official Tournament Coverage
"kozoom_carom" => { default_tags: ["official", "tournament"] }

# Regional Content
"sponoiter_korea" => { default_tags: ["korean_content"] }
"ky_phong_viet_art" => { default_tags: ["vietnamese_content"] }

# Pool vs Carom
"kozoom_pool" => { default_tags: ["pool"] }  # To distinguish from carom content
```

## API / Model Methods

### InternationalSource

```ruby
source = InternationalSource.find_by(name: "Fred Coudron")

# Get default tags for this source
source.default_tags  # => ["training"]
```

### Video

```ruby
video = Video.first

# Detect all tags including source-based ones
video.detect_all_tags  # => ["zanetti", "full_game", "hd", "training"]

# Detect only source-based tags
video.detect_source_tags  # => ["training"]

# Auto-tag (applies all detected tags)
video.auto_tag!
```

## Testing

To test the feature:

1. Configure a source with default_tags
2. Scrape videos from that source
3. Check that videos are automatically tagged:

```ruby
source = InternationalSource.find_by(name: "Fred Coudron")
video = source.videos.first
video.auto_tag!
puts video.tags  # Should include "training"
```
