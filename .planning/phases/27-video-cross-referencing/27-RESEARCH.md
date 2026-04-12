# Phase 27: Video Cross-Referencing - Research

**Researched:** 2026-04-12
**Domain:** Video-to-tournament matching, SoopLive billiards JSON API, Kozoom eventId cross-reference
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** 0.75 confidence threshold is locked. Scoring model design is Claude's discretion.
- **D-02:** Auto-assign above 0.75. Whether to implement 0.5–0.75 review tier is Claude's discretion.
- **D-03:** Build full `SoopliveBilliardsClient` adapter covering all three discovered endpoints: `/api/games`, `/api/game/{game_no}/matches`, `/api/game/{game_no}/results`.
- **D-04:** Wire `SoopliveBilliardsClient` into `DailyInternationalScrapeJob` for daily sync of SoopLive tournament and match data.
- **D-05:** SoopLive VOD linking via `replay_no` → `vod.sooplive.com/player/{replay_no}` URL construction.
- **D-06:** Build BOTH: rake task for one-time backfill AND incremental matching in `DailyInternationalScrapeJob`.
- **D-07:** Rake task name: `rake videos:match_tournaments` — runs `Video::TournamentMatcher` against `Video.unassigned` scope.
- **D-08:** Incremental: `DailyInternationalScrapeJob` Step 3 calls `Video::TournamentMatcher` for newly scraped videos after tournament data is up to date.
- **D-09:** Regex-first extraction strategy. Known player names from `InternationalHelper::WORLD_CUP_TOP_32`, round labels from `UmbScraper::GAME_TYPE_MAPPINGS`.
- **D-10:** AI fallback (`AiSearchService` / GPT-4) for titles where regex fails. Optional/configurable — not called on every video.

### Claude's Discretion

- Confidence scoring model weights and formula
- Whether to implement the 0.5–0.75 review tier
- `SoopliveBilliardsClient` internal architecture (PORO vs ApplicationService)
- Error handling strategy for SoopLive API
- `Video::MetadataExtractor` PORO design and regex pattern organization

### Deferred Ideas (OUT OF SCOPE)

None documented.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| VIDEO-01 | `Video::TournamentMatcher` service assigns unassigned videos to `InternationalTournament` by date range + player name intersection + title similarity; only above 0.75 threshold | Video.unassigned scope confirmed; Tournament has `date`/`end_date`/`title`; `text` gem Levenshtein pattern confirmed; player detection already in `detect_player_tags` |
| VIDEO-02 | SoopLive VOD linking via `replay_no` to specific game records | `replay_no` field confirmed in Phase 24 SoopLive API response; URL pattern `vod.sooplive.com/player/{replay_no}` confirmed |
| VIDEO-03 | Kozoom event cross-referencing via `eventId` mapping to `InternationalTournament` | Kozoom stores `eventId` in `video.json_data` (via `v.merge(...)` in `KozoomScraper`); `watch_url` already falls back to `json_data["eventId"]`; cross-ref needs InternationalTournament lookup by Kozoom external_id |
</phase_requirements>

---

## Summary

Phase 27 builds three complementary video-assignment mechanisms: (1) a confidence-scored `Video::TournamentMatcher` for general fuzzy assignment; (2) a `SoopliveBilliardsClient` that fetches match-level data with `replay_no` for high-precision VOD-to-game linking; (3) Kozoom `eventId`-based direct cross-referencing. The codebase already contains most of the raw materials — `Video#detect_player_tags`, `InternationalHelper::WORLD_CUP_TOP_32`, `Club#calculate_similarity` with `Text::Levenshtein`, and `Video.unassigned` scope.

The main new infrastructure is: `Video::TournamentMatcher` (ApplicationService), `Video::MetadataExtractor` (PORO), and `SoopliveBilliardsClient` (PORO or ApplicationService, Claude's discretion). The existing `DailyInternationalScrapeJob` Step 3 replaces `TournamentDiscoveryService` (which creates new tournaments from video metadata) with `Video::TournamentMatcher` (which assigns existing videos to existing tournaments).

A critical design distinction: `TournamentDiscoveryService` creates tournaments from scratch from video data; `Video::TournamentMatcher` is the inverse — it queries existing `InternationalTournament` records and assigns unassigned videos to them by confidence scoring. Both can coexist, but Step 3 in the job should call the matcher after scrapers have populated tournaments.

**Primary recommendation:** Build `Video::MetadataExtractor` as a pure PORO first (no side effects), then `Video::TournamentMatcher` as ApplicationService consuming it, then `SoopliveBilliardsClient` as a separate PORO with the same `fetch_json` pattern as `SoopliveScraper`.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `text` gem | bundled | `Text::Levenshtein.distance` for title similarity | Already used in `Club#calculate_similarity`; exact same pattern reusable |
| `ApplicationService` | project base | `.call(kwargs)` pattern for side-effect services | All services in this project inherit it |
| `Net::HTTP` + `JSON` | stdlib | HTTP fetching for `SoopliveBilliardsClient` | Same pattern as `SoopliveScraper#fetch_json` and `KozoomScraper#make_request` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ruby-openai` (via `OpenAI::Client`) | 7.3 | GPT-4 AI fallback for MetadataExtractor | D-10: only when regex extraction fails and `ai_extraction_enabled?` returns true |
| `InternationalHelper::WORLD_CUP_TOP_32` | project constant | Player name list for regex matching | MetadataExtractor player detection; same data `detect_player_tags` uses |
| `UmbScraper::GAME_TYPE_MAPPINGS` / `Umb::DetailsScraper::GAME_TYPE_MAPPINGS` | project constant | Round label recognition (PPPQ, PPQ, Q, R16, etc.) | MetadataExtractor round detection |

**Version verification:** `text` gem already in Gemfile [VERIFIED: codebase grep — `require 'text'` in `app/models/club.rb:743`]. No new gem installation needed.

---

## Architecture Patterns

### Recommended Project Structure
```
app/models/
└── video/
    ├── tournament_matcher.rb      # ApplicationService — side effects (video.update)
    └── metadata_extractor.rb     # PORO — pure extraction, no DB writes

app/services/
└── sooplive_billiards_client.rb  # PORO — wraps /api/games, /api/game/{id}/matches, /api/game/{id}/results

lib/tasks/
└── videos.rake                   # rake videos:match_tournaments (new task in existing namespace)
```

**Note:** `video_game_matching.rake` already uses `namespace :videos` — the new `match_tournaments` task should be added to the same namespace (either same file or a new file with the same namespace).

### Pattern 1: ApplicationService with `.call`

```ruby
# Source: app/services/application_service.rb [VERIFIED: codebase]
class ApplicationService
  def self.call(kwargs = {})
    new(kwargs).call
  end
end

# Usage:
Video::TournamentMatcher.call(video_ids: Video.unassigned.pluck(:id))
```

### Pattern 2: Text::Levenshtein for title similarity

```ruby
# Source: app/models/club.rb:732-749 [VERIFIED: codebase]
require 'text'
max_length = [str1.length, str2.length].max
distance = Text::Levenshtein.distance(str1.downcase.strip, str2.downcase.strip)
similarity = 1.0 - (distance.to_f / max_length)
```

### Pattern 3: Video.unassigned scope

```ruby
# Source: app/models/video.rb:59 [VERIFIED: codebase]
scope :unassigned, -> { where(videoable_id: nil) }
```

"Unassigned" means `videoable_id IS NULL`. The `videoable_type` column can be nil or set. The safe check is `videoable_id: nil`.

### Pattern 4: Video#detect_player_tags (existing, reusable)

```ruby
# Source: app/models/video.rb:370-379 [VERIFIED: codebase]
def detect_player_tags
  detected = []
  text = "#{title} #{description}".upcase
  InternationalHelper::WORLD_CUP_TOP_32.each do |tag, info|
    detected << tag.downcase if text.include?(tag.upcase) || text.include?(info[:full_name].upcase)
  end
  detected
end
```

This method returns tag strings (e.g., `"jaspers"`, `"cho"`). `Video::MetadataExtractor` should call this rather than duplicate the logic.

### Pattern 5: SoopliveBilliardsClient fetch_json

```ruby
# Mirror of app/services/sooplive_scraper.rb:130-150 [VERIFIED: codebase]
BILLIARDS_BASE_URL = "https://billiards.sooplive.com"

def fetch_games
  fetch_json("#{BILLIARDS_BASE_URL}/api/games")
end

def fetch_matches(game_no)
  fetch_json("#{BILLIARDS_BASE_URL}/api/game/#{game_no}/matches")
end

def fetch_results(game_no)
  fetch_json("#{BILLIARDS_BASE_URL}/api/game/#{game_no}/results")
end

private

def fetch_json(url)
  uri = URI(url)
  request = Net::HTTP::Get.new(uri)
  request['Accept'] = 'application/json'
  request['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)'
  response = Net::HTTP.start(uri.hostname, uri.port,
                              use_ssl: true,
                              verify_mode: ssl_verify_mode) do |http|
    http.request(request)
  end
  JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
rescue StandardError => e
  Rails.logger.error "[SoopliveBilliardsClient] #{e.message}"
  nil
end
```

**SSL note:** Phase 25 fixed SSL handling — use `Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE` or delegate to `Umb::HttpClient`'s ssl_verify_mode helper.

### Pattern 6: Kozoom eventId cross-reference

Kozoom videos are saved with `data: v.merge({ "url" => link, "player" => "kozoom" })` where `v` is the raw API video object. The Kozoom `/videos?eventId={event_id}` API response objects contain an `eventId` field [ASSUMED — the `watch_url` method references `json_data["eventId"]` suggesting it exists in production data, but the API response format was not inspected in Phase 24]. `KozoomScraper#scrape` iterates `event["id"]` but does NOT explicitly store `eventId` in the video `data` — however, if the raw `v` object from Kozoom's API contains an `eventId` key, it gets stored via `v.merge(...)`.

**Cross-reference logic:** Find `InternationalTournament` records where `external_id` matches `video.json_data["eventId"]` AND `international_source.source_type == "kozoom"`.

```ruby
# VIDEO-03 cross-reference lookup
kozoom_source = InternationalSource.find_by(source_type: "kozoom")
Video.joins(:international_source)
     .where(international_sources: { source_type: "kozoom" })
     .unassigned
     .find_each do |video|
  event_id = video.json_data["eventId"]
  next if event_id.blank?
  tournament = InternationalTournament
                 .where(international_source: kozoom_source)
                 .find_by(external_id: event_id.to_s)
  video.update(videoable: tournament) if tournament
end
```

**Risk:** If `InternationalTournament` records from Kozoom are not present (Kozoom scraping creates Video records but may not create InternationalTournament records via the API), this cross-reference yields no matches. The planner should note this dependency.

### Pattern 7: SoopLive replay_no VOD linking (VIDEO-02)

```ruby
# Phase 24 FINDINGS.md [VERIFIED: codebase]
# Match record: { "replay_no": 160553493, "match_no": 16669, "game_no": 127, ... }
# VOD URL construction:
vod_url = "https://vod.sooplive.com/player/#{match["replay_no"]}"
```

The existing `SoopliveScraper` saves videos with `external_id = item['title_no'].to_s` and the VOD embed URL is `vod.sooplive.co.kr/player/{external_id}`. The NEW `SoopliveBilliardsClient` uses a different domain (`billiards.sooplive.com/api/...`) and a different ID (`replay_no`). These are two separate identification systems: channel VOD IDs (from `chapi.sooplive.co.kr`) vs. tournament match VOD IDs (from `billiards.sooplive.com`).

**VIDEO-02 implementation path:** For each SoopLive match with `replay_no != 0` and `record_yn == "Y"`, construct the VOD URL and either:
- Find an existing `Video` record with `external_id == replay_no.to_s` and assign it to the InternationalGame, OR
- Create a new Video record pointing to the VOD URL if none exists.

The `replay_no` → video linkage requires matching against `Video.by_source(fivesix_source_id)` by external_id. The current `SoopliveScraper` saves `external_id = item['title_no']` (channel VOD number). Phase 24 confirmed `replay_no` from the billiards API is the same identifier as used on `vod.sooplive.com/player/{replay_no}` — so `replay_no` should match `external_id` of existing SoopLive Video records.

### Anti-Patterns to Avoid

- **Building a new player detection system:** `Video#detect_player_tags` already exists. `MetadataExtractor` should call it, not duplicate it.
- **Scoring only on title similarity:** Levenshtein on long Korean/Vietnamese tournament titles against English tournament names will produce noise. Weight date overlap heavily — a video published during a tournament's `date..end_date` range is strong evidence.
- **Using `TournamentDiscoveryService` pattern for matching:** That service creates new tournaments from video metadata. `TournamentMatcher` queries existing tournaments; do not confuse the two.
- **Calling AI on every video:** D-10 says AI fallback is optional/configurable. Guard with a flag check before making OpenAI calls.
- **Ignoring `videoable_type` when assigning:** The polymorphic assignment for `InternationalTournament` requires `videoable_type: "InternationalTournament"`, not `"Tournament"`. The STI type string must match.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| String similarity scoring | Custom edit-distance implementation | `Text::Levenshtein.distance` (already required in `club.rb`) | Tested, handles Unicode correctly |
| Player name detection | Re-implement player scan | `video.detect_player_tags` | Already tested against `WORLD_CUP_TOP_32` |
| HTTP fetching with JSON | Custom HTTP class | Mirror `SoopliveScraper#fetch_json` pattern | Consistent SSL handling, error logging |
| AI extraction | Custom OpenAI wrapper | `OpenAI::Client.new` from `ruby-openai` (same client as `AiSearchService`) | Already configured, same model (`gpt-4o-mini`) |

---

## Common Pitfalls

### Pitfall 1: STI type string mismatch
**What goes wrong:** Assigning `videoable_type: "Tournament"` instead of `"InternationalTournament"` when linking to an InternationalTournament record.
**Why it happens:** `InternationalTournament` is a STI subclass of `Tournament`. The polymorphic assignment uses `videoable.class.name`, which is `"InternationalTournament"`.
**How to avoid:** Always use `video.update(videoable: tournament_record)` not `video.update(videoable_type: "Tournament", videoable_id: id)`. The polymorphic assignment via `update(videoable: obj)` sets the correct type automatically.
**Warning signs:** Assigned videos show up under `Video.for_tournaments` (which filters `videoable_type: "Tournament"`) missing if you use the parent type string.

### Pitfall 2: Kozoom eventId not in video data
**What goes wrong:** Assuming all Kozoom videos have `json_data["eventId"]` populated.
**Why it happens:** `KozoomScraper#scrape` saves `data: v.merge({"url" => ..., "player" => "kozoom"})` — if the Kozoom API `v` object contains `"eventId"` as a field, it gets saved; if not, the key is absent.
**How to avoid:** Scope the Kozoom cross-reference query with `where("data->>'eventId' IS NOT NULL")` to skip records with no eventId.
**Warning signs:** VIDEO-03 shows 0 assignments even when Kozoom videos exist.

### Pitfall 3: Tournament date range for unfinished tournaments
**What goes wrong:** `InternationalTournament.end_date` is `nil` for ongoing or future tournaments.
**Why it happens:** `InternationalTournament` inherits `end_date` from `Tournament` which is optional (no NOT NULL constraint in schema).
**How to avoid:** `MetadataExtractor` date-overlap check should handle nil `end_date`: treat `end_date.nil?` as "tournament may still be ongoing" — use `date..date + 7.days` as fallback range.

### Pitfall 4: SoopLive replay_no = 0 for unrecorded matches
**What goes wrong:** `replay_no: 0` in match data means no VOD is available for that match.
**Why it happens:** Phase 24 confirmed `record_yn: "Y"` and non-zero `replay_no` indicate recorded matches. Matches with `replay_no: 0` have no VOD.
**How to avoid:** Skip matches where `replay_no.to_i == 0` or `record_yn != "Y"` in `SoopliveBilliardsClient` match processing.
**Warning signs:** Dead links to `vod.sooplive.com/player/0`.

### Pitfall 5: Player tag format from detect_player_tags
**What goes wrong:** `detect_player_tags` returns lowercase tag strings (e.g., `"jaspers"`, `"cho"`), not full player names. These are the hash keys from `WORLD_CUP_TOP_32`, not the `:full_name` values.
**Why it happens:** The method does `detected << tag.downcase` where `tag` is the hash key.
**How to avoid:** When comparing detected players against tournament seedings, map tag back to full name via `InternationalHelper::WORLD_CUP_TOP_32[tag.upcase][:full_name]`.

### Pitfall 6: DailyInternationalScrapeJob Step 3 currently calls TournamentDiscoveryService
**What goes wrong:** The plan may assume Step 3 is empty. It currently calls `TournamentDiscoveryService.new.discover_from_videos` inside a `if defined?(TournamentDiscoveryService)` guard.
**Why it happens:** Phase 25 bug fix wired TournamentDiscoveryService into Step 3.
**How to avoid:** Replace or extend Step 3: call `Video::TournamentMatcher` AFTER `TournamentDiscoveryService` (which creates new tournament records), or decide whether to keep both. The two services are complementary — `TournamentDiscoveryService` creates tournament stubs from video clusters, `TournamentMatcher` assigns videos to pre-existing UMB-scraped tournament records.

---

## Code Examples

### Confidence scoring model (Claude's discretion — recommended design)

Based on available signals in the codebase:

```ruby
# Source: inferred from codebase signals [ASSUMED — specific weights are Claude's design]
def confidence_score(video, tournament)
  score = 0.0

  # Signal 1: Date overlap (strongest signal — 0.40 weight)
  if date_overlap?(video, tournament)
    score += 0.40
  end

  # Signal 2: Player name intersection (0.35 weight)
  detected = video.detect_player_tags  # returns ["jaspers", "cho", ...]
  seeded_tags = tournament_player_tags(tournament)  # from seedings
  intersection = (detected & seeded_tags).size
  union = (detected | seeded_tags).size
  jaccard = union > 0 ? intersection.to_f / union : 0.0
  score += jaccard * 0.35

  # Signal 3: Title similarity (0.25 weight)
  title_sim = title_similarity(video.title, tournament.title)
  score += title_sim * 0.25

  score
end

def date_overlap?(video, tournament)
  return false if video.published_at.blank? || tournament.date.blank?
  end_date = tournament.end_date || tournament.date + 7.days
  range = tournament.date..(end_date + 3.days)  # 3-day grace for late uploads
  range.cover?(video.published_at.to_date)
end
```

**Notes:**
- 0.40 + 0.35 + 0.25 = 1.0. Date overlap alone cannot reach 0.75 threshold — requires at least one additional signal.
- Player intersection requires seedings to exist on the tournament record. If no seedings, Jaccard = 0 → signals 1 + 3 must carry.
- Title similarity alone on Korean/Vietnamese titles will be low — that is intentional.

### title_similarity helper

```ruby
# Reusing Club.calculate_similarity pattern [VERIFIED: app/models/club.rb:732-748]
def title_similarity(str1, str2)
  return 0.0 if str1.blank? || str2.blank?
  s1 = str1.to_s.downcase.strip
  s2 = str2.to_s.downcase.strip
  return 1.0 if s1 == s2
  require 'text'
  max_length = [s1.length, s2.length].max
  return 0.0 if max_length == 0
  distance = Text::Levenshtein.distance(s1, s2)
  1.0 - (distance.to_f / max_length)
end
```

### Rake task skeleton

```ruby
# lib/tasks/videos.rake (extends existing namespace)
namespace :videos do
  desc "Match unassigned videos to InternationalTournaments above 0.75 confidence"
  task match_tournaments: :environment do
    before_count = Video.unassigned.count
    puts "Unassigned videos before: #{before_count}"
    result = Video::TournamentMatcher.call
    after_count = Video.unassigned.count
    puts "Assigned: #{result[:assigned_count]}, Skipped: #{result[:skipped_count]}"
    puts "Unassigned videos after: #{after_count}"
  end
end
```

### DailyInternationalScrapeJob Step 3 replacement

```ruby
# Replace Step 3 in DailyInternationalScrapeJob#perform:
# Step 3: Match unassigned videos to tournaments
match_count = 0
begin
  if defined?(Video::TournamentMatcher)
    result = Video::TournamentMatcher.call
    match_count = result[:assigned_count]
    Rails.logger.info "[DailyInternationalScrape] Matched #{match_count} videos to tournaments"
  end
rescue StandardError => e
  Rails.logger.error "[DailyInternationalScrape] Error matching videos: #{e.message}"
end
```

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `TournamentDiscoveryService` creates tournament stubs from video clusters | `Video::TournamentMatcher` assigns videos to UMB-scraped tournaments | Different direction: top-down from authoritative source, not bottom-up from video guesses |
| `video_game_matching.rake` assigns to `Game` records by player pairs | `rake videos:match_tournaments` assigns to `InternationalTournament` by confidence score | Tournament-level is coarser but more reliable for unmatched videos |

---

## Open Questions

1. **Does Kozoom's `/videos?eventId={id}` response include an `eventId` field in each video object? (RESOLVED)**
   - What we know: `KozoomScraper` saves `data: v.merge({"url" => ..., "player" => "kozoom"})`. The `watch_url` method in `Video` references `json_data["eventId"]`, suggesting production data has this field.
   - What's unclear: Whether the raw Kozoom API `v` object contains `"eventId"` as a key (so it gets stored) or whether it was stored manually/elsewhere.
   - Resolution: Accepted assumption defended by SQL guard — `where("data->>'eventId' IS NOT NULL")` in Plan 27-02 Task 3 filters out any records where eventId is absent. If 0 matches result during verification, revisit KozoomScraper to explicitly store eventId during save.

2. **Are `InternationalTournament` records from Kozoom source present in the database? (RESOLVED)**
   - What we know: `KozoomScraper#scrape` creates `Video` records but does not create `InternationalTournament` records.
   - What's unclear: Whether another job/service populates `InternationalTournament.where(international_source: kozoom_source)`.
   - Resolution: Graceful degradation implemented — `cross_reference_kozoom_videos` returns `{ assigned_count: 0 }` early if no Kozoom source exists, and silently skips individual videos when no matching tournament is found. No fallback to fuzzy matching required; 0 results is acceptable.

3. **Does `TournamentDiscoveryService` in Step 3 stay or get replaced? (RESOLVED)**
   - What we know: Step 3 currently calls `TournamentDiscoveryService` (creates tournament stubs from video metadata). `Video::TournamentMatcher` (assigns videos to existing tournaments) is complementary, not a replacement.
   - Resolution: Resolved as Step 3a/3b in Plan 27-03. `TournamentDiscoveryService` stays as Step 3a; `Video::TournamentMatcher` is added as Step 3b immediately after, so newly discovered tournaments are available for matching in the same job run.

---

## Environment Availability

Step 2.6: SKIPPED — Phase 27 is code-only changes. No external tools or CLI utilities required beyond the Rails stack already present. `billiards.sooplive.com` API was confirmed reachable in Phase 24.

---

## Security Domain

> `security_enforcement` not explicitly set to false in config.json — including this section.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | SoopLive API is unauthenticated; Kozoom auth already handled in `KozoomScraper` |
| V3 Session Management | no | Background job, no session |
| V4 Access Control | no | Internal service, no external access control surface |
| V5 Input Validation | yes | Video title and json_data inputs should be treated as untrusted when feeding into regex/AI |
| V6 Cryptography | no | No new crypto — Kozoom credentials already handled via Rails credentials |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| ReDoS via malicious video title | Denial of Service | Use non-backtracking regex patterns; set match timeout via `Regexp::FIXEDENCODING` or simple anchored patterns |
| OpenAI cost explosion | Denial of Resource | Guard AI calls with configurable flag (D-10); limit batch size; log calls |
| SSRF via constructed SoopLive URLs | Spoofing | URL is constructed from integer game_no (numeric guard), not from user input |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Kozoom API `/videos?eventId={id}` response objects contain an `"eventId"` key that gets stored in `video.data` via `v.merge(...)` | Code Examples (Kozoom cross-reference), Architecture Patterns Pattern 6 | VIDEO-03 yields 0 assignments; need to explicitly store eventId in KozoomScraper |
| A2 | `InternationalTournament` records with `international_source.source_type == "kozoom"` exist in production | Open Questions #2, Pattern 6 | VIDEO-03 cross-reference path produces 0 results; fallback to fuzzy matching required |
| A3 | `replay_no` values from `billiards.sooplive.com/api/game/{id}/matches` match `external_id` values of existing `Video` records from `SoopliveScraper` | Architecture Patterns Pattern 7 | VIDEO-02 VOD linkage creates duplicate Video records instead of updating existing ones |

---

## Sources

### Primary (HIGH confidence)
- `app/models/video.rb` — video schema, `unassigned` scope, `detect_player_tags`, `json_data`, `CAROM_KEYWORDS` [VERIFIED: direct read]
- `app/models/international_tournament.rb` — `date`, `end_date`, `title` fields; STI from Tournament [VERIFIED: direct read]
- `app/models/international_game.rb` — STI from Game; `json_data["round"]` accessor [VERIFIED: direct read]
- `app/models/club.rb:732-748` — `Text::Levenshtein` usage pattern [VERIFIED: direct read]
- `app/helpers/international_helper.rb` — `WORLD_CUP_TOP_32` (30 players), player tag format [VERIFIED: direct read]
- `app/services/sooplive_scraper.rb` — `fetch_json` pattern, `external_id = item['title_no']`, SSL handling [VERIFIED: direct read]
- `app/services/kozoom_scraper.rb` — `data: v.merge(...)` pattern, `eventId` not explicitly stored [VERIFIED: direct read]
- `app/services/tournament_discovery_service.rb` — Step 3 current occupant; `assign_videos_to_tournament` uses `video.update(videoable: tournament)` [VERIFIED: direct read]
- `app/jobs/daily_international_scrape_job.rb` — Step 1-5 structure; Step 3 currently calls `TournamentDiscoveryService` [VERIFIED: direct read]
- `app/services/application_service.rb` — `.call(kwargs = {})` pattern [VERIFIED: direct read]
- `db/schema.rb` — `videos` table: `data jsonb`, `videoable_type/id`, `hidden`, `metadata_extracted` [VERIFIED: direct read]
- `.planning/phases/24-data-source-investigation/24-FINDINGS.md` — SoopLive API endpoints, `replay_no` field, `record_yn`, VOD URL construction [VERIFIED: direct read]
- `lib/tasks/video_game_matching.rake` — existing `videos` rake namespace [VERIFIED: direct read]

### Secondary (MEDIUM confidence)
- `app/services/ai_search_service.rb` — GPT-4 via `gpt-4o-mini` model, `OpenAI::Client.new`, `response_format: {type: 'json_object'}` [VERIFIED: direct read]
- `app/services/umb_scraper.rb:18-30` / `app/services/umb/details_scraper.rb:17-30` — `GAME_TYPE_MAPPINGS` keys and values [VERIFIED: direct read]

---

## Metadata

**Confidence breakdown:**
- Video model schema and scopes: HIGH — direct schema.rb + model read
- InternationalTournament fields: HIGH — direct model read
- SoopLive billiards API: HIGH — Phase 24 probe results confirmed endpoints and `replay_no` field
- Kozoom eventId storage: MEDIUM — inferred from `watch_url` fallback; not confirmed by API inspection
- Text gem Levenshtein pattern: HIGH — exact pattern confirmed in Club model
- DailyInternationalScrapeJob step structure: HIGH — direct read
- Confidence scoring formula weights: ASSUMED — Claude's discretion per D-01

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (SoopLive API may change; all other findings are stable against the local codebase)
