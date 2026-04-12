# Video:: — Cross-Referencing System

The Video:: cross-referencing system links `Video` records to `InternationalTournament` or `InternationalGame` records. For UMB and Kozoom videos, confidence-scored matching (`Video::TournamentMatcher`) is combined with structured metadata extraction (`Video::MetadataExtractor`). For SoopLive videos, linking happens directly via `replay_no` from the SoopLive JSON API (`SoopliveBilliardsClient`).

> **Note:** Unlike other service namespaces, `Video::` classes live in `app/models/video/`, not `app/services/video/`. `SoopliveBilliardsClient` is a standalone service in `app/services/`.

---

## Component Overview

| Class | Path | Type |
|-------|------|------|
| `Video::TournamentMatcher` | `app/models/video/tournament_matcher.rb` | ApplicationService |
| `Video::MetadataExtractor` | `app/models/video/metadata_extractor.rb` | PORO |
| `SoopliveBilliardsClient` | `app/services/sooplive_billiards_client.rb` | Plain Ruby Class |

---

## Video::TournamentMatcher

**Type:** `ApplicationService`  
**Path:** `app/models/video/tournament_matcher.rb`

Processes a scope of `Video` records and assigns each video to the `InternationalTournament` with the highest confidence score — provided that score is >= `CONFIDENCE_THRESHOLD`.

### Public Interface

```ruby
# Default: all unassigned videos (Video.unassigned)
Video::TournamentMatcher.call
# => { assigned_count: Integer, skipped_count: Integer, results: Array }

# Restricted scope:
Video::TournamentMatcher.call(video_scope: Video.where(id: [1, 2, 3]))
# => { assigned_count: Integer, skipped_count: Integer, results: Array }
```

**Return value:**
- `assigned_count` — number of videos successfully assigned
- `skipped_count` — number of videos skipped (already assigned or score too low)
- `results` — array of `{ video_id:, tournament_id:, confidence: }` for each assignment

### Confidence Scoring

Three weighted signals combine to produce a total score between 0.0 and 1.0:

| Signal | Weight | Method | Details |
|--------|--------|--------|---------|
| Date overlap | 0.40 | `date_overlap_score` | Returns 1.0 if `video.published_at` falls within the tournament date range (+3 day grace period after `end_date`). `nil` end_date defaults to `date + 7 days`. |
| Player intersection | 0.35 | `player_intersection_score` | Jaccard similarity between the video's detected player tags and the tournament's seedings |
| Title similarity | 0.25 | `title_similarity_score` | Normalized Levenshtein distance: `1.0 - (distance / max_length)` |

**Threshold:** `CONFIDENCE_THRESHOLD = 0.75` — videos scoring >= 0.75 are auto-assigned. There is no manual review tier (D-02 from the source code comment).

### Testability

`confidence_score` is a public method and can be called directly in tests:

```ruby
matcher = Video::TournamentMatcher.new
score = matcher.confidence_score(video, tournament, metadata)
# => Float 0.0..1.0
```

`metadata` is optional — if omitted, `Video::MetadataExtractor.new(video).extract_all` is called internally.

---

## Video::MetadataExtractor

**Type:** Pure PORO (not an ApplicationService)  
**Path:** `app/models/video/metadata_extractor.rb`

Extracts structured metadata from video titles and descriptions. Strategy: regex first, AI only as fallback.

### Public Interface

```ruby
extractor = Video::MetadataExtractor.new(video)

extractor.extract_all
# => { players: Array<String>, round: String|nil, tournament_type: String|nil, year: Integer|nil }

extractor.extract_players
# => Array<String>  (delegates to video.detect_player_tags)

extractor.extract_round
# => String|nil  (from GAME_TYPE_MAPPINGS keys)

extractor.extract_tournament_type
# => String|nil  (one of: world_cup, world_championship, european_championship, masters, grand_prix)

extractor.extract_year
# => Integer|nil  (4-digit year 2010-2029)

extractor.extract_with_ai_fallback(ai_extraction_enabled: false)
# => { players:, round:, tournament_type:, year: }
# AI fallback only fires when ALL regex values are blank AND ai_extraction_enabled: true
```

### Regex-First Strategy

Extraction uses known patterns from the codebase:

- **`ROUND_PATTERNS`** — keys from `Umb::DetailsScraper::GAME_TYPE_MAPPINGS` (shared constant, cross-namespace dependency)
- **`TOURNAMENT_TYPE_PATTERNS`** — named regexes for tournament type keywords (world_cup, world_championship, european_championship, masters, grand_prix)
- **Year pattern:** `/\b(20[12]\d)\b/` — captures years 2010-2029

Patterns are checked with word-boundary anchors (`/\b#{Regexp.escape(pattern)}\b/i`) to avoid partial-string false matches.

### AI Fallback

The AI fallback fires only when **all** regex extraction values are blank **and** `ai_extraction_enabled: true` is explicitly set:

- **Model:** `gpt-4o-mini` with `response_format: { type: "json_object" }`
- **Default:** disabled (`ai_extraction_enabled: false`) — prevents unexpected OpenAI calls in batch/background contexts
- **Error handling:** exceptions are rescued and an empty hash is returned (no re-raise)

```ruby
# Only enable when needed:
extractor.extract_with_ai_fallback(ai_extraction_enabled: true)
```

---

## SoopliveBilliardsClient

**Type:** Plain Ruby Class (not ApplicationService, not PORO)  
**Path:** `app/services/sooplive_billiards_client.rb`

Client for the JSON API at `billiards.sooplive.com`. Retrieves tournament lists, match data with `replay_no`, and links VOD URLs to existing `Video` records.

### Public Interface

```ruby
client = SoopliveBilliardsClient.new

client.fetch_games
# GET https://billiards.sooplive.com/api/games
# => Array of tournament hashes (or nil on error)

client.fetch_matches(game_no)
# GET https://billiards.sooplive.com/api/game/{game_no}/matches
# => Array of match hashes: { "replay_no" => Integer, "record_yn" => "Y"|"N", ... }

client.fetch_results(game_no)
# GET https://billiards.sooplive.com/api/game/{game_no}/results
# => Array of ranking hashes

SoopliveBilliardsClient.vod_url(replay_no)
# => "https://vod.sooplive.com/player/{replay_no}"
# IMPORTANT: caller must check replay_no != 0 before using (replay_no == 0 means no VOD)

client.link_match_vods(game_no, international_game: game)
# => Array of { video_id:, replay_no: } for each video linked

SoopliveBilliardsClient.cross_reference_kozoom_videos
# => { assigned_count: Integer }
```

### replay_no == 0 Guard (Pitfall)

`replay_no == 0` means no VOD is available for that match. `link_match_vods` skips these matches automatically. When calling `vod_url` directly, **the caller must check**:

```ruby
# Correct:
if replay_no != 0
  url = SoopliveBilliardsClient.vod_url(replay_no)
end

# Wrong — replay_no == 0 produces an invalid URL:
url = SoopliveBilliardsClient.vod_url(replay_no)  # replay_no might be 0!
```

Additionally, matches with `record_yn != "Y"` are also skipped by `link_match_vods`.

### Behavior of link_match_vods

`link_match_vods` does **not** create new `Video` records. It only links pre-existing `Video` records to the provided `InternationalGame`. Skipped cases:

- Matches with `replay_no == 0` (no VOD)
- Matches with `record_yn != "Y"` (not recorded)
- Videos already assigned to another record (`videoable_id` is set)

### Kozoom Cross-Referencing

```ruby
SoopliveBilliardsClient.cross_reference_kozoom_videos
```

Class method for batch processing. Finds unassigned `Video` records from the Kozoom source that have `json_data["eventId"]` set, and links them to the matching `InternationalTournament` via `external_id`.

---

## Operational Workflow

Three operational modes — choose the appropriate path depending on context:

### 1. Incremental (New Tournament)

Used when a new SoopLive tournament is imported and VOD URLs should be assigned directly:

```ruby
# 1. Fetch match data for the tournament
matches = client.fetch_matches(game_no)

# 2. For each InternationalGame record of the tournament:
client.link_match_vods(game_no, international_game: international_game)
# => VOD URLs are assigned directly to existing Video records
```

This path is wired in `DailyInternationalScrapeJob` step 3a.

### 2. Backfill (Existing Videos)

Used to retroactively link already-imported but unassigned videos:

```ruby
Video::TournamentMatcher.call
# => Processes all Video.unassigned with confidence scoring
# Auto-assigns videos >= 0.75 to the best-matching InternationalTournament
```

Or with a restricted scope:

```ruby
Video::TournamentMatcher.call(video_scope: Video.where(source: "sooplive"))
```

This path is available as a Rake task for initial backfill processing.

### 3. Kozoom Cross-Reference

Separate batch operation for Kozoom-source videos:

```ruby
SoopliveBilliardsClient.cross_reference_kozoom_videos
# Links Kozoom videos via json_data["eventId"] to InternationalTournament.external_id
```

Class method, callable without a client instance.

### Which Path to Use?

| Situation | Recommended Path |
|-----------|-----------------|
| New SoopLive tournament imported | Incremental: `link_match_vods` |
| Existing videos without tournament assignment | Backfill: `TournamentMatcher.call` |
| Kozoom videos without tournament assignment | Kozoom: `cross_reference_kozoom_videos` |

---

## See Also

- [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
- [Umb:: Namespace](./umb.en.md) — source of the shared constant `GAME_TYPE_MAPPINGS` (`Umb::DetailsScraper::GAME_TYPE_MAPPINGS`), required by `Video::MetadataExtractor::ROUND_PATTERNS`
