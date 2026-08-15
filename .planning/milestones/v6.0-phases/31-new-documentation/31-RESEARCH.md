# Phase 31: New Documentation - Research

**Researched:** 2026-04-13
**Domain:** MkDocs documentation authoring — namespace architecture pages + Video:: cross-referencing page
**Confidence:** HIGH

## Summary

Phase 31 creates 9 new documentation files (8 namespace overview pages + 1 Video:: cross-referencing page), each as a bilingual DE+EN pair (18 files total). The work is pure documentation writing — no code changes. All source-of-truth content has been read directly from the service files and models in this session. Every namespace's public interface, entry points, and data contracts are captured below.

The documentation pattern is already established by Phase 30: the `umb-scraping-implementation.de.md` and `umb-scraping-methods.de.md` files show the expected heading structure, table format, and prose style. The new namespace pages go into a new `docs/developers/services/` subdirectory (D-05), and `mkdocs.yml` gains a new `Services` section under `Developers`.

**Primary recommendation:** Use the Phase 30 UMB docs as the template for all namespace pages. Extract content verbatim from the source files read in this session — no additional code exploration is needed at plan or implementation time.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Architecture + public interface — each page covers: namespace role, service list with responsibilities, public method signatures for key entry points, data contracts (what goes in/out). No internal implementation details. Target ~200-400 lines per page.
- **D-02:** 8 namespace pages total: TableMonitor::, RegionCc::, Tournament::, TournamentMonitor::, League::, PartyMonitor::, Umb::, Video::
- **D-03:** Umb:: summary page linking to existing Phase 30 docs — create a brief Umb:: namespace overview that links to `umb-scraping-implementation` and `umb-scraping-methods`. Avoids duplication while satisfying the "8 namespace overview pages" criterion.
- **D-04:** Video:: page follows SC-2 strictly — covers exactly: TournamentMatcher confidence scoring (0.75 threshold, two-path matching), MetadataExtractor (regex-first + AI fallback), SoopliveBilliardsClient (replay_no linking), and operational workflow (backfill vs incremental matching). No broader video system context beyond SC-2.
- **D-05:** New `docs/developers/services/` subdirectory for all namespace pages.
- **D-06:** Namespace as kebab-case naming: `table-monitor.de.md`, `region-cc.de.md`, `tournament.de.md`, `tournament-monitor.de.md`, `league.de.md`, `party-monitor.de.md`, `umb.de.md`, `video-crossref.de.md`.
- **D-07:** German primary, AI-assisted translation to English (consistent with D-03/D-04 from Phase 30).
- **D-08:** One commit per bilingual doc pair (consistent with D-08 from Phase 30).

### Claude's Discretion

- Internal structure of each namespace page (heading order, section grouping)
- How to present data contracts (table, code block, or narrative)
- Whether to include a services/ index page or rely on mkdocs nav
- mkdocs.yml nav updates for the new subdirectory

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DOC-01 | Document all 37 extracted services grouped by namespace (8 namespace overview pages) | All 7 non-Umb namespace source files read; Umb:: covered by Phase 30 docs — summary page per D-03 |
| DOC-02 | Document video cross-referencing system (Video::TournamentMatcher, Video::MetadataExtractor, SoopliveBilliardsClient) | All three files read in full; confidence weights, threshold, matching paths, relay_no linking all captured |
</phase_requirements>

---

## Standard Stack

This phase writes documentation only. No new library installations are required. [VERIFIED: codebase inspection]

| Tool | Version | Purpose |
|------|---------|---------|
| MkDocs Material | installed | Site framework with `mkdocs-static-i18n` plugin |
| mkdocs-static-i18n | installed | `.de.md` / `.en.md` suffix-based language routing |

**File naming convention** (already in use, verified from `docs/developers/`): `{slug}.de.md` and `{slug}.en.md` — the plugin picks up the language suffix automatically. No YAML front matter language keys required. [VERIFIED: codebase inspection of existing docs]

---

## Architecture Patterns

### Recommended Directory Structure

```
docs/developers/services/
├── table-monitor.de.md
├── table-monitor.en.md
├── region-cc.de.md
├── region-cc.en.md
├── tournament.de.md
├── tournament.en.md
├── tournament-monitor.de.md
├── tournament-monitor.en.md
├── league.de.md
├── league.en.md
├── party-monitor.de.md
├── party-monitor.en.md
├── umb.de.md
├── umb.en.md
├── video-crossref.de.md
└── video-crossref.en.md
```

### Pattern: Namespace Page Structure

Derived from `docs/developers/umb-scraping-implementation.de.md` (Phase 30 reference). [VERIFIED: file read]

```markdown
# {Namespace}:: — Architektur

Kurze Einleitung: Was dieser Namespace tut, welches Subsystem er bedient.

## Namespace-Übersicht

| Klasse | Datei | Beschreibung |
|--------|-------|--------------|
| `{Class}` | `app/services/{path}.rb` | Ein-Satz-Beschreibung |

## Öffentliche Schnittstelle

### {ClassName}

**Einstiegspunkt(e):**
```ruby
ClassName.call(param: value)           # → Rückgabewert
ClassName.class_method(...)            # → ...
```

**Eingabe:**
| Parameter | Typ | Beschreibung |
|-----------|-----|--------------|
| param     | ... | ...          |

**Ausgabe:** `{return type/shape}`

## Architektur-Entscheidungen

{Explain PORO vs ApplicationService split, dispatcher vs single-call patterns, etc.}

## Querverweise

- Zugehöriger Leitfaden: [Developer Guide — Extrahierte Services](../developer-guide.md#extrahierte-services)
```

### Anti-Patterns to Avoid

- **Documenting private methods:** D-01 says no internal implementation details. Stop at public method signatures.
- **Duplicating Umb:: content:** D-03 says the Umb:: page is a summary + links only, not a copy of umb-scraping-implementation.de.md.
- **Writing English first:** D-07 says German primary. Write the full `.de.md`, then translate to `.en.md`.
- **Batching commits:** D-08 says one commit per bilingual pair. Each `.de.md` + `.en.md` is one commit.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Language switching | Custom routing logic | mkdocs-static-i18n suffix convention — just name files correctly |
| Nav entry for new section | Editing multiple files | Single `mkdocs.yml` nav block addition |
| Translation coverage verification | Manual file listing | `bin/check-docs-translations.rb` (already built in Phase 28) |

---

## Namespace Content Reference

This section contains all raw material the implementer needs. No further code reading is required.

### TableMonitor:: (2 services)

**Namespace role:** Manages real-time billiards game control on a single table. Handles game creation, player assignment, score tracking, and set/match-end transitions. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `TableMonitor::GameSetup` | `app/services/table_monitor/game_setup.rb` | Encapsulates `start_game` logic — creates Game/GameParticipation records, builds result hash, enqueues TableMonitorJob |
| `TableMonitor::ResultRecorder` | `app/services/table_monitor/result_recorder.rb` | Result persistence — saves set data, navigates between sets, coordinates AASM state transitions |

**GameSetup public interface:**
```ruby
TableMonitor::GameSetup.call(table_monitor: tm, options: params)
  # → true (raises StandardError on failure)

TableMonitor::GameSetup.assign(table_monitor: tm, game_participation: gp)
  # → performs assign_game logic, saves table monitor state

TableMonitor::GameSetup.initialize_game(table_monitor: tm)
  # → writes initial data hash to tm.data (balls, innings, player state)
```

**ResultRecorder public interface:**
```ruby
TableMonitor::ResultRecorder.call(table_monitor: tm)
  # → evaluate_result (main entry — triggers set/match-end logic)

TableMonitor::ResultRecorder.save_result(table_monitor: tm)
  # → Hash (game_set_result with Gruppe, Partie, Spieler1/2, Ergebnis1/2, etc.)

TableMonitor::ResultRecorder.save_current_set(table_monitor: tm)
  # → nil (pushes result into data["sets"])

TableMonitor::ResultRecorder.get_max_number_of_wins(table_monitor: tm)
  # → Integer

TableMonitor::ResultRecorder.switch_to_next_set(table_monitor: tm)
  # → nil (initializes next set, resets player state, handles snooker state)
```

**Key data contract — `save_result` return hash:**
```ruby
{
  "Gruppe"       => game.group_no,
  "Partie"       => game.seqno,
  "Spieler1"     => player_a.ba_id,
  "Spieler2"     => player_b.ba_id,
  "Innings1"     => Array,
  "Innings2"     => Array,
  "Ergebnis1"    => Integer,
  "Ergebnis2"    => Integer,
  "Aufnahmen1"   => Integer,
  "Aufnahmen2"   => Integer,
  "Höchstserie1" => Integer,
  "Höchstserie2" => Integer,
  "Tischnummer"  => Integer
}
```

**Architecture notes:**
- `GameSetup` is `ApplicationService` (has DB side effects)
- `ResultRecorder` is `ApplicationService` (has DB side effects)
- AASM events (`end_of_set!`, `finish_match!`, `acknowledge_result!`) are fired on `@tm`, not on the service
- No direct broadcast calls in either service — broadcasts happen via `after_update_commit` on the model

---

### RegionCc:: (10 services)

**Namespace role:** Synchronises local Carambus DB with the ClubCloud (CC) admin platform — the PHP-based German billiards federation management system. All sync operations are dispatched via `RegionCc.synchronize(opts)` on the model; each service handles one sync domain. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `RegionCc::ClubCloudClient` | `app/services/region_cc/club_cloud_client.rb` | Stateless HTTP transport for ClubCloud admin interface — GET, POST, multipart POST; session-aware; dry-run mode |
| `RegionCc::BranchSyncer` | `app/services/region_cc/branch_syncer.rb` | Syncs BranchCc records (disciplines) from CC API |
| `RegionCc::ClubSyncer` | `app/services/region_cc/club_syncer.rb` | Syncs Club records from CC API |
| `RegionCc::CompetitionSyncer` | `app/services/region_cc/competition_syncer.rb` | Syncs competition and season data; operation dispatch (:sync_competitions, :sync_seasons_in_competitions) |
| `RegionCc::GamePlanSyncer` | `app/services/region_cc/game_plan_syncer.rb` | Syncs GamePlanCc and GameDetailCc records including complex HTML table parsing; operation dispatch |
| `RegionCc::LeagueSyncer` | `app/services/region_cc/league_syncer.rb` | Dispatcher for league sync — operations: :sync_leagues, :sync_league_teams, :sync_league_teams_new, :sync_league_plan, :sync_team_players, :sync_team_players_structure |
| `RegionCc::MetadataSyncer` | `app/services/region_cc/metadata_syncer.rb` | Syncs metadata reference objects (categories, groups, disciplines); operation dispatch |
| `RegionCc::PartySyncer` | `app/services/region_cc/party_syncer.rb` | Syncs PartyCc records and match data; operations: :sync_parties, :sync_party_games |
| `RegionCc::RegistrationSyncer` | `app/services/region_cc/registration_syncer.rb` | Syncs registration list records; operations: :sync_registration_list_ccs, :sync_registration_list_ccs_detail |
| `RegionCc::TournamentSyncer` | `app/services/region_cc/tournament_syncer.rb` | Syncs tournament, tournament series, and championship type data; multiple operations |

**ClubCloudClient public interface:**
```ruby
client = RegionCc::ClubCloudClient.new(base_url:, username:, userpw:)
res, doc = client.get("showLeagueList", {fedId: 20}, {session_id: "abc"})
res, doc = client.post("createLeagueSave", params, opts)
```

**Syncer pattern (all syncer services follow this):**
```ruby
RegionCc::BranchSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array of synced Branch objects (raises ArgumentError on unknown branch name)

RegionCc::ClubSyncer.call(region_cc: rc, client: cc_client, **opts)
  # → Array of synced Club objects

RegionCc::CompetitionSyncer.call(region_cc: rc, client: cc_client, operation: :sync_competitions, **opts)
RegionCc::LeagueSyncer.call(region_cc: rc, client: cc_client, operation: :sync_leagues, **opts)
RegionCc::TournamentSyncer.call(region_cc: rc, client: cc_client, operation: :sync_tournaments, **opts)
```

**Architecture notes:**
- `ClubCloudClient` has no ORM coupling — no model calls, pure HTTP
- Dry-run mode: `opts[:armed].blank?` means dry run; write actions are skipped
- Session management: `opts[:session_id]` is sent as PHPSESSID cookie
- PATH_MAP constant maps action names to URL paths + read_only boolean

---

### Tournament:: (3 services)

**Namespace role:** Services for the local tournament lifecycle — scraping public ClubCloud pages, computing player rankings, and creating Google Calendar table reservations. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `Tournament::PublicCcScraper` | `app/services/tournament/public_cc_scraper.rb` | Scrapes tournament data from public CC URL — processes registration lists, participants, results, rankings |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | Calculates and caches effective player rankings; reorders seedings post-competition |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | Creates Google Calendar events for table reservations with guard-condition validation |

**Public interfaces:**
```ruby
Tournament::PublicCcScraper.call(tournament: tournament, opts: {})
  # → nil (side effects: creates/updates Seeding, Game, GameParticipation)
  # Guard: returns early if tournament.organizer_type != "Region"
  # Guard: returns early if Carambus.config.carambus_api_url.present?

calculator = Tournament::RankingCalculator.new(tournament)
calculator.calculate_and_cache_rankings  # → nil (updates data hash)
calculator.reorder_seedings              # → nil (renumbers seedings)
# Note: PORO, not ApplicationService

Tournament::TableReservationService.call(tournament: tournament)
  # → nil (no tables/date/discipline) or Google Calendar event object
  # Guard: requires location, discipline, date, required_tables_count > 0, available tables
```

**Architecture notes:**
- `PublicCcScraper` and `TableReservationService` are `ApplicationService`
- `RankingCalculator` is a PORO (explicit per D-02 in extraction plan)
- `required_tables_count` and `available_tables_with_heaters` remain on the Tournament model (D-07 per extraction plan)

---

### TournamentMonitor:: (4 services)

**Namespace role:** Services for managing a live tournament — distributing players to groups, resolving placement rules, processing match results, and populating tables. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | Pure PORO — distributes players to groups via zig-zag or round-robin per NBV rules |
| `TournamentMonitor::RankingResolver` | `app/services/tournament_monitor/ranking_resolver.rb` | Pure PORO — resolves player IDs from ranking rule strings (group ranks, KO bracket references) |
| `TournamentMonitor::ResultProcessor` | `app/services/tournament_monitor/result_processor.rb` | Processes match results with pessimistic DB lock — coordinates ClubCloud upload and GameParticipation updates |
| `TournamentMonitor::TablePopulator` | `app/services/tournament_monitor/table_populator.rb` | Assigns games to tournament tables — initialises TableMonitor records and runs placement algorithm |

**Public interfaces:**
```ruby
# PlayerGroupDistributor — class methods, no instantiation needed
TournamentMonitor::PlayerGroupDistributor.distribute_to_group(players, ngroups)
  # → Hash { group_no => [player_ids] }

TournamentMonitor::PlayerGroupDistributor.distribute_with_sizes(players, ngroups, sizes)
  # → Hash { group_no => [player_ids] }

# RankingResolver
resolver = TournamentMonitor::RankingResolver.new(tournament_monitor)
resolver.player_id_from_ranking(rule_str, opts = {})
  # rule_str examples: "g1.2", "(g1.rk4 + g2.rk4).rk2", "fin.w", "sl.rk1"
  # → Integer (player_id) or nil

# ResultProcessor
TournamentMonitor::ResultProcessor.new(tournament_monitor).report_result(table_monitor)
  # → side effects: writes game result, triggers finish_match!, CC upload

TournamentMonitor::ResultProcessor.new(tournament_monitor).accumulate_results
  # PUBLIC — also used by TablePopulator

TournamentMonitor::ResultProcessor.new(tournament_monitor).update_ranking
TournamentMonitor::ResultProcessor.new(tournament_monitor).update_game_participations

# TablePopulator
TournamentMonitor::TablePopulator.new(tournament_monitor).do_reset_tournament_monitor
  # → AASM after_enter callback entry point for full reset

TournamentMonitor::TablePopulator.new(tournament_monitor).populate_tables
TournamentMonitor::TablePopulator.new(tournament_monitor).initialize_table_monitors
```

**Architecture notes:**
- `PlayerGroupDistributor` and `RankingResolver` are POROs (no DB side effects)
- `ResultProcessor` and `TablePopulator` are POROs with DB side effects (multiple public entry points — not `ApplicationService`)
- DB lock scope for `ResultProcessor`: `game.with_lock` covers exactly `write_game_result_data + finish_match!`
- AASM events fired on `@tournament_monitor`, not on the service
- `cattr_accessor` `allow_change_tables` accessed as `TournamentMonitor.allow_change_tables` (class-level)
- Cross-dependency: `RankingResolver#group_rank` calls `PlayerGroupDistributor.distribute_to_group` directly

---

### League:: (4 services)

**Namespace role:** Services for league operations — scraping external league data (ClubCloud and BBV), reconstructing game plans from existing data, and calculating standings tables. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `League::BbvScraper` | `app/services/league/bbv_scraper.rb` | Scrapes BBV-specific league data (teams and results) from bbv-billard.liga.nu |
| `League::ClubCloudScraper` | `app/services/league/club_cloud_scraper.rb` | Scrapes league data from ClubCloud — teams, parties, game plans |
| `League::GamePlanReconstructor` | `app/services/league/game_plan_reconstructor.rb` | Reconstructs GamePlan from existing Parties and PartyGames; multiple operation modes |
| `League::StandingsCalculator` | `app/services/league/standings_calculator.rb` | Calculates standings tables for Karambol, Snooker, and Pool leagues |

**Public interfaces:**
```ruby
League::BbvScraper.call(league: league, region: region)
  # → side effects: creates/updates League, LeagueTeam, Party records

League::BbvScraper.scrape_all(region: region, season: season, opts: {})
  # → Array of records_to_tag (for RegionTaggable)

League::ClubCloudScraper.call(league: league, league_details: true)
  # → nil (side effects: creates LeagueTeam, Party, PartyGame records)

League::GamePlanReconstructor.call(league: league, operation: :reconstruct)
League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season)
League::GamePlanReconstructor.call(league: league, season: season, operation: :delete_for_season)
  # → nil (side effects: creates/deletes GamePlan records)

calculator = League::StandingsCalculator.new(league)
calculator.karambol         # → Array of team stat hashes
calculator.snooker          # → Array of team stat hashes
calculator.pool             # → Array of team stat hashes
calculator.schedule_by_rounds  # → schedule data
# Note: PORO, not ApplicationService
```

**Architecture notes:**
- `BbvScraper` and `ClubCloudScraper` and `GamePlanReconstructor` are `ApplicationService`
- `StandingsCalculator` is a PORO (no DB writes — reads and computes)
- `BBV_BASE_URL = "https://bbv-billard.liga.nu"` — hardcoded external endpoint

---

### PartyMonitor:: (2 services)

**Namespace role:** Services for managing a live Ligaspieltag (league match day, called a "Party" in domain terms). Parallel to `TournamentMonitor::` but scoped to party (league day) context. [VERIFIED: source file read]

| Class | File | Description |
|-------|------|-------------|
| `PartyMonitor::ResultProcessor` | `app/services/party_monitor/result_processor.rb` | Processes match results in PartyMonitor context with pessimistic DB lock |
| `PartyMonitor::TablePopulator` | `app/services/party_monitor/table_populator.rb` | Resets PartyMonitor and assigns TableMonitor records to party tables |

**Public interfaces:**
```ruby
PartyMonitor::ResultProcessor.new(party_monitor).report_result(table_monitor)
  # → side effects: writes game result, triggers finish_match!, finalizes round

PartyMonitor::ResultProcessor.new(party_monitor).accumulate_results
PartyMonitor::ResultProcessor.new(party_monitor).finalize_round
PartyMonitor::ResultProcessor.new(party_monitor).update_game_participations

PartyMonitor::TablePopulator.new(party_monitor).reset_party_monitor
  # → nil (resets sets_to_play, sets_to_win, team_size; destroys local games/seedings)

PartyMonitor::TablePopulator.new(party_monitor).initialize_table_monitors
  # → nil (assigns TableMonitors to party tables)

PartyMonitor::TablePopulator.new(party_monitor).do_placement(game, r_no, t_no)
  # → places a single game on a table
```

**Architecture notes:**
- Both are POROs with DB side effects (multiple public entry points)
- `TournamentMonitor.transaction` scope is intentionally preserved in `ResultProcessor` — do NOT change to `PartyMonitor.transaction` (Pitfall 5 in source)
- DB lock scope: `game.with_lock` covers `write_game_result_data + finish_match!`
- AASM events fired on `@party_monitor`, not on the service
- `cattr_accessor` accessed as `PartyMonitor.allow_change_tables`

---

### Umb:: (10 services) — Summary page

**Namespace role:** Scrapes international tournament data from the UMB (Union Mondiale de Billard) website and parses PDF documents containing match results, player lists, and rankings. [VERIFIED: source file read + Phase 30 docs read]

Per decision D-03, the Umb:: page is a brief summary linking to the detailed Phase 30 docs. It does NOT reproduce content from `umb-scraping-implementation.de.md` or `umb-scraping-methods.de.md`.

**What the summary page covers:**
1. One-paragraph namespace role
2. Service list table (same as developer-guide.de.md lines 133–144)
3. Cross-links to: `umb-scraping-implementation.md` and `umb-scraping-methods.md`
4. Note that `Umb::DetailsScraper::GAME_TYPE_MAPPINGS` is shared with `Video::MetadataExtractor`

---

### Video:: Cross-referencing (not a service namespace — models in `app/models/video/`)

**Namespace role:** Links Video records to InternationalTournament or InternationalGame records. Uses confidence-scored matching (TournamentMatcher) and metadata extraction (MetadataExtractor) for UMB/Kozoom videos, and direct replay_no linking (SoopliveBilliardsClient) for SoopLive videos. [VERIFIED: source file read]

This page is the most specified (D-04, SC-2). It covers exactly three classes:

#### Video::TournamentMatcher

**Location:** `app/models/video/tournament_matcher.rb`
**Type:** `ApplicationService`

```ruby
Video::TournamentMatcher.call
  # → { assigned_count: Integer, skipped_count: Integer, results: Array }
  # Default scope: Video.unassigned (all unassigned videos)

Video::TournamentMatcher.call(video_scope: Video.where(id: [1,2,3]))
  # → Same return shape, restricted scope
```

**Confidence scoring — three weighted signals:**

| Signal | Weight | Method | Details |
|--------|--------|--------|---------|
| Date overlap | 0.40 | `date_overlap_score` | Returns 1.0 if `video.published_at` falls within tournament date range + 3-day grace. `nil` end_date defaults to `date + 7 days`. |
| Player intersection | 0.35 | `player_intersection_score` | Jaccard similarity between video's detected player tags and tournament seedings |
| Title similarity | 0.25 | `title_similarity_score` | Normalized Levenshtein: `1.0 - (distance / max_length)` |

**Threshold:** `CONFIDENCE_THRESHOLD = 0.75` — videos scoring >= 0.75 are auto-assigned. No review tier (D-02 per source comment).

**`confidence_score` is public** — callable directly in tests:
```ruby
matcher = Video::TournamentMatcher.new
score = matcher.confidence_score(video, tournament, metadata)
  # → Float 0.0..1.0
```

**Two operational modes:**
- **Backfill:** `Video::TournamentMatcher.call` — processes all `Video.unassigned`
- **Incremental:** `Video::TournamentMatcher.call(video_scope: Video.where(...))` — processes a specific scope

#### Video::MetadataExtractor

**Location:** `app/models/video/metadata_extractor.rb`
**Type:** Pure PORO

```ruby
extractor = Video::MetadataExtractor.new(video)

extractor.extract_all
  # → { players: Array<String>, round: String|nil, tournament_type: String|nil, year: Integer|nil }

extractor.extract_players    # → Array (delegates to video.detect_player_tags)
extractor.extract_round      # → String|nil (from GAME_TYPE_MAPPINGS keys)
extractor.extract_tournament_type  # → String|nil (one of: world_cup, world_championship, european_championship, masters, grand_prix)
extractor.extract_year       # → Integer|nil (4-digit year 2010–2029)

extractor.extract_with_ai_fallback(ai_extraction_enabled: false)
  # → { players:, round:, tournament_type:, year: }
  # AI fallback only fires when ALL regex values are blank AND ai_extraction_enabled: true
```

**Regex-first strategy (D-09):**
- `ROUND_PATTERNS` — keys of `Umb::DetailsScraper::GAME_TYPE_MAPPINGS` (shared constant)
- `TOURNAMENT_TYPE_PATTERNS` — named regexes for tournament type keywords
- Year: `/\b(20[12]\d)\b/`

**AI fallback (D-10):**
- Model: `gpt-4o-mini` with `response_format: { type: "json_object" }`
- Default: disabled (`ai_extraction_enabled: false`) — prevents unexpected OpenAI calls in batch contexts
- Rescue guard: failures return empty hash, not exception

#### SoopliveBilliardsClient

**Location:** `app/services/sooplive_billiards_client.rb`
**Type:** Plain Ruby class (not ApplicationService, not PORO)

```ruby
client = SoopliveBilliardsClient.new

client.fetch_games
  # GET https://billiards.sooplive.com/api/games
  # → Array of tournament hashes (or nil on error)

client.fetch_matches(game_no)
  # GET https://billiards.sooplive.com/api/game/{game_no}/matches
  # → Array of match hashes: { "replay_no" => Integer, "record_yn" => "Y"|"N", ... }

client.fetch_results(game_no)
  # GET https://billiards.sooplive.com/api/game/{game_no}/results
  # → Array of ranking hashes

SoopliveBilliardsClient.vod_url(replay_no)
  # → "https://vod.sooplive.com/player/{replay_no}"
  # IMPORTANT: caller must check replay_no != 0 before using (replay_no == 0 means no VOD)

client.link_match_vods(game_no, international_game: game)
  # → Array of { video_id:, replay_no: } for each video linked
  # Skips: replay_no == 0, record_yn != "Y", already-assigned videos
  # Does NOT create new Video records — links pre-existing ones only

SoopliveBilliardsClient.cross_reference_kozoom_videos
  # → { assigned_count: Integer }
  # Matches Kozoom Video records via json_data["eventId"] to InternationalTournament.external_id
```

**Operational workflow:**
1. **Incremental (new tournament):** Call `fetch_matches(game_no)` → call `link_match_vods(game_no, international_game:)` for each game → VOD URLs assigned
2. **Backfill (existing videos):** `Video::TournamentMatcher.call` runs over `Video.unassigned` — processes SoopLive + Kozoom + other source videos
3. **Kozoom cross-reference:** `SoopliveBilliardsClient.cross_reference_kozoom_videos` — separate batch operation, class method

---

## Common Pitfalls

### Pitfall 1: `docs/developers/services/` does not exist yet
**What goes wrong:** mkdocs build fails if nav references files that don't exist.
**How to avoid:** Create the directory as part of Wave 0 (or first task). All 16 files must exist before the nav entry is added.

### Pitfall 2: mkdocs.yml nav entry placement
**What goes wrong:** Inserting the new `Services:` section in the wrong location in mkdocs.yml causes nav to render out of order or break the `Developers:` nesting.
**How to avoid:** Insert after the `UMB Scraping:` block (lines ~208-211 of current mkdocs.yml), keeping it inside `Developers:`. Verify with `mkdocs build --strict`.

### Pitfall 3: English pages must not be stubs
**What goes wrong:** SC-3 ("EN is not a stub") means a `.en.md` that contains only "Translation pending" fails the requirement.
**How to avoid:** AI-translate the full German page before committing. D-08 requires the bilingual pair in one commit.

### Pitfall 4: Video:: is in `app/models/`, not `app/services/`
**What goes wrong:** A writer might say "Video:: service namespace" — incorrect. It is a model namespace.
**How to avoid:** The `video-crossref.de.md` page explicitly notes the location difference. Do not add `Video::` to the services namespace overview.

### Pitfall 5: `replay_no == 0` means no VOD
**What goes wrong:** Generating a VOD URL for replay_no == 0 produces an invalid link.
**How to avoid:** Document the guard explicitly — `link_match_vods` skips replay_no == 0; callers of `vod_url` must check.

### Pitfall 6: Umb:: page scope creep
**What goes wrong:** Writing a full architecture page for Umb:: when D-03 says summary + links only.
**How to avoid:** The Umb:: page should be ~50-80 lines: role paragraph, service list table, two cross-links.

---

## Code Examples

All examples below are extracted verbatim from source files. [VERIFIED: source file read]

### TableMonitor:: — Starting a game
```ruby
# Source: app/services/table_monitor/game_setup.rb
TableMonitor::GameSetup.call(table_monitor: tm, options: params)
TableMonitor::GameSetup.assign(table_monitor: tm, game_participation: gp)
TableMonitor::GameSetup.initialize_game(table_monitor: tm)
```

### Video::TournamentMatcher — Confidence weights
```ruby
# Source: app/models/video/tournament_matcher.rb
CONFIDENCE_THRESHOLD = 0.75
DATE_WEIGHT   = 0.40
PLAYER_WEIGHT = 0.35
TITLE_WEIGHT  = 0.25
```

### Video::MetadataExtractor — Extract all
```ruby
# Source: app/models/video/metadata_extractor.rb
extractor = Video::MetadataExtractor.new(video)
metadata = extractor.extract_all
# => { players: ["jaspers", "blomdahl"], round: "Final", tournament_type: "world_cup", year: 2024 }
```

### SoopliveBilliardsClient — VOD URL
```ruby
# Source: app/services/sooplive_billiards_client.rb
# Per Pitfall 4: caller must ensure replay_no != 0
SoopliveBilliardsClient.vod_url(replay_no)
# => "https://vod.sooplive.com/player/12345"
```

---

## Environment Availability

Step 2.6: SKIPPED — this phase is documentation-only. No external tools, databases, or runtime services are required beyond the existing mkdocs setup.

---

## mkdocs.yml Nav Changes

The current nav has this structure under `Developers:` (verified from file read):

```yaml
  - Developers:
      - ...
      - UMB Scraping:
          - UMB Scraping Implementation: developers/umb-scraping-implementation.md
          - UMB Scraping Methods: developers/umb-scraping-methods.md
      - Frontend STI Migration: developers/frontend-sti-migration.md
      ...
```

The new block inserts after `UMB Scraping:`:

```yaml
      - Services:
          - TableMonitor: developers/services/table-monitor.md
          - RegionCc: developers/services/region-cc.md
          - Tournament: developers/services/tournament.md
          - TournamentMonitor: developers/services/tournament-monitor.md
          - League: developers/services/league.md
          - PartyMonitor: developers/services/party-monitor.md
          - Umb: developers/services/umb.md
          - Video Cross-Referencing: developers/services/video-crossref.md
```

Nav translation keys for the new section need to be added to mkdocs.yml `nav_translations` block. Suggested German translations:

| English | German |
|---------|--------|
| Services | Services |
| TableMonitor | TableMonitor |
| RegionCc | RegionCc |
| Tournament | Tournament |
| TournamentMonitor | TournamentMonitor |
| League | Liga |
| PartyMonitor | PartyMonitor |
| Umb | Umb |
| Video Cross-Referencing | Video-Querverweis |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `Video::` is in `app/models/video/`, not in a services namespace | Namespace Content Reference | Low — verified by file listing |
| A2 | The `mkdocs-static-i18n` plugin processes `.de.md`/`.en.md` suffix without front matter | Standard Stack | Low — existing docs all follow this pattern |

Both assumptions are corroborated by direct file inspection. Risk is low.

---

## Open Questions

1. **Services/ index page**
   - What we know: D-06 specifies individual namespace file names; Claude's Discretion covers whether to add an index page.
   - What's unclear: Adding `developers/services/index.md` would allow `developers/services/` to be a nav section with a landing page.
   - Recommendation: Skip the index page — rely on mkdocs nav. Keeps scope tight.

2. **nav_translations for new entries**
   - What we know: The existing `nav_translations` block in mkdocs.yml maps English nav labels to German.
   - What's unclear: Whether the planner should add translations entries in the same commit as mkdocs.yml nav or as a separate step.
   - Recommendation: Add nav_translations in the same task that updates mkdocs.yml nav.

---

## Sources

### Primary (HIGH confidence)
- Direct source file read: `app/services/table_monitor/game_setup.rb`
- Direct source file read: `app/services/table_monitor/result_recorder.rb`
- Direct source file read: `app/services/region_cc/*.rb` (10 files)
- Direct source file read: `app/services/tournament/*.rb` (3 files)
- Direct source file read: `app/services/tournament_monitor/*.rb` (4 files)
- Direct source file read: `app/services/league/*.rb` (4 files)
- Direct source file read: `app/services/party_monitor/*.rb` (2 files)
- Direct source file read: `app/services/umb/*.rb` and `app/services/umb/pdf_parser/*.rb` (7+3 files)
- Direct source file read: `app/models/video/tournament_matcher.rb`
- Direct source file read: `app/models/video/metadata_extractor.rb`
- Direct source file read: `app/services/sooplive_billiards_client.rb`
- Direct file read: `mkdocs.yml` (full nav structure)
- Direct file read: `docs/developers/umb-scraping-implementation.de.md` (pattern reference)
- Direct file read: `docs/developers/developer-guide.de.md` (services tables)
- Direct file read: `.planning/phases/31-new-documentation/31-CONTEXT.md`

---

## Metadata

**Confidence breakdown:**
- Namespace content (public interfaces, data contracts): HIGH — all source files read in this session
- mkdocs.yml nav changes: HIGH — current nav structure verified by file read
- Document pattern/structure: HIGH — Phase 30 reference docs read
- Video:: confidence weights and thresholds: HIGH — extracted verbatim from source

**Research date:** 2026-04-13
**Valid until:** Stable — this is documentation for existing code; only invalidated by further refactoring of the service classes
