# League:: — Architecture

The `League::` namespace contains services for league operations — scraping external league data (ClubCloud and BBV), reconstructing game plans from existing data, and calculating standings tables.

The namespace consists of **4 services** in `app/services/league/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `League::BbvScraper` | `app/services/league/bbv_scraper.rb` | Scrapes BBV-specific league data (teams and results) from bbv-billard.liga.nu |
| `League::ClubCloudScraper` | `app/services/league/club_cloud_scraper.rb` | Scrapes league data from ClubCloud — teams, match days, game plans |
| `League::GamePlanReconstructor` | `app/services/league/game_plan_reconstructor.rb` | Reconstructs `GamePlan` from existing `Party` and `PartyGame` records; multiple operation modes |
| `League::StandingsCalculator` | `app/services/league/standings_calculator.rb` | Calculates standings tables for Karambol, Snooker, and Pool leagues |

## Public Interface

### BbvScraper

**Entry points:**

```ruby
League::BbvScraper.call(league: league, region: region)
  # → side effects: creates/updates League, LeagueTeam, Party records

League::BbvScraper.scrape_all(region: region, season: season, opts: {})
  # → Array of records_to_tag (for RegionTaggable)
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `league` | `League` | ActiveRecord instance of the league to scrape |
| `region` | `Region` | Associated region for tagging |
| `season` | `Season` | Season for multi-league scraping |

**Constant:**

```ruby
League::BbvScraper::BBV_BASE_URL = "https://bbv-billard.liga.nu"
```

The endpoint is hardcoded — no configurable alternative is provided.

### ClubCloudScraper

**Entry points:**

```ruby
League::ClubCloudScraper.call(league: league, league_details: true)
  # → nil (side effects: creates LeagueTeam, Party, PartyGame records)
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `league` | `League` | ActiveRecord instance of the league to scrape |
| `league_details` | `Boolean` | Whether to fetch game plan details |

### GamePlanReconstructor

**Entry points — three operation modes:**

```ruby
League::GamePlanReconstructor.call(league: league, operation: :reconstruct)
  # → nil; creates GamePlan records from existing Party/PartyGame data

League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season)
  # → nil; reconstructs GamePlan for all leagues in a season

League::GamePlanReconstructor.call(league: league, season: season, operation: :delete_for_season)
  # → nil; deletes GamePlan records for all leagues in a season
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `league` | `League` | ActiveRecord instance (for `:reconstruct` and `:delete_for_season`) |
| `season` | `Season` | Season (for `:reconstruct_for_season` and `:delete_for_season`) |
| `operation` | `Symbol` | Operation mode: `:reconstruct`, `:reconstruct_for_season`, or `:delete_for_season` |

### StandingsCalculator

**Note:** `StandingsCalculator` is a PORO (not an `ApplicationService`). It is instantiated, not called via `.call`.

**Entry points:**

```ruby
calculator = League::StandingsCalculator.new(league)

calculator.karambol
  # → Array of team stat hashes (Karambol scoring system)

calculator.snooker
  # → Array of team stat hashes (Snooker scoring system)

calculator.pool
  # → Array of team stat hashes (Pool scoring system)

calculator.schedule_by_rounds
  # → Hash { round_name => Array<Party> } — game schedule grouped by rounds
```

**Return format of standings methods:**

```ruby
[
  {
    team:          LeagueTeam,  # ActiveRecord instance
    name:          String,      # Team name
    spiele:        Integer,     # Played matches
    gewonnen:      Integer,     # Won
    unentschieden: Integer,     # Drawn
    verloren:      Integer,     # Lost
    punkte:        Integer,     # 2 per win, 1 per draw
    diff:          Integer,     # Score differential (for minus against)
    platz:         Integer,     # Table rank (starting from 1)
    # Karambol/Pool:
    partien:       String,      # Format "scored:conceded"
    # Snooker:
    frames:        String       # Format "scored:conceded"
  },
  ...
]
```

Sorting: points descending, then differential descending.

## Architecture Decisions

### a. ApplicationService vs. PORO

`BbvScraper`, `ClubCloudScraper`, and `GamePlanReconstructor` inherit from `ApplicationService` because they perform database writes (side-effect operations). `StandingsCalculator` is a PORO — it only reads and computes, performing no DB writes.

### b. BBV_BASE_URL hardcoded

`BBV_BASE_URL = "https://bbv-billard.liga.nu"` is hardcoded as a constant in `BbvScraper`. There is no configurable alternative because BBV operates only a single public endpoint.

### c. Multiple operation modes in GamePlanReconstructor

`GamePlanReconstructor` supports three operation modes via the `:operation` parameter because the three use cases (single-league reconstruction, season-wide reconstruction, season-wide deletion) share the same core logic. A single `call` interface with an operation parameter is more compact than three separate service classes.

### d. No direct broadcast calls

None of the League services call CableReady or ActionCable directly. Broadcasts occur via model callbacks.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
