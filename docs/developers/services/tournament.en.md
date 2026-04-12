# Tournament:: — Architecture

The `Tournament::` namespace provides services for the local tournament lifecycle — scraping public ClubCloud pages, computing player rankings, and creating Google Calendar table reservations.

The namespace consists of **3 services** in `app/services/tournament/`.

## Namespace Overview

| Class | File | Description |
|-------|------|-------------|
| `Tournament::PublicCcScraper` | `app/services/tournament/public_cc_scraper.rb` | Scrapes tournament data from the public CC URL — processes registration lists, participants, results, and rankings |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | Calculates and caches effective player rankings; reorders seedings post-competition |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | Creates Google Calendar events for table reservations with guard-condition validation |

## Public Interface

### PublicCcScraper

**Entry point:**

```ruby
Tournament::PublicCcScraper.call(tournament: tournament, opts: {})
  # → nil (side effects: creates/updates Seeding, Game, GameParticipation)
```

**Guard conditions:**

```ruby
# Early return when:
return unless tournament.organizer_type == "Region"
  # Scraping only for Region-type tournaments

return if Carambus.config.carambus_api_url.present?
  # Scraping only on local servers (not on the API server)
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament` | `Tournament` | ActiveRecord instance of the tournament |
| `opts` | `Hash` | Optional scraping options |

**Output:** `nil` — side effects: creates and updates `Seeding`, `Game`, and `GameParticipation` records.

### RankingCalculator

**Entry points:**

```ruby
calculator = Tournament::RankingCalculator.new(tournament)

calculator.calculate_and_cache_rankings
  # → nil (updates the tournament's data hash with calculated rankings)

calculator.reorder_seedings
  # → nil (renumbers seedings after competition)
```

**Input (constructor):**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament` | `Tournament` | ActiveRecord instance of the tournament |

### TableReservationService

**Entry point:**

```ruby
Tournament::TableReservationService.call(tournament: tournament)
  # → nil  (no tables / no date / no discipline)
  # → Google Calendar event object (on success)
```

**Guard conditions:**

```ruby
# Early return if any of the following is missing:
# - tournament.location present
# - tournament.discipline present
# - tournament.date present
# - tournament.required_tables_count > 0
# - tournament.available_tables_with_heaters present
```

**Input:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tournament` | `Tournament` | ActiveRecord instance with location, discipline, date, and table configuration |

**Output:** Google Calendar event object or `nil` (if guard conditions are not met).

## Architecture Decisions

### a. ApplicationService vs. PORO

Services are split by side effects:

- **ApplicationService** (DB side effects): `PublicCcScraper` and `TableReservationService` inherit from `ApplicationService`
- **PORO** (no DB writes): `RankingCalculator` is a plain Ruby object (explicit per D-02 in the extraction plan)

### b. Table configuration remains on the model

`required_tables_count` and `available_tables_with_heaters` remain on the `Tournament` model (D-07 per extraction plan). These are model attributes, not service logic — `TableReservationService` only reads them.

### c. Scraping only on local servers

`PublicCcScraper` checks `Carambus.config.carambus_api_url.present?` and returns early when running on the API server. Local servers scrape independently and synchronise back via PaperTrail versions.

## Cross-References

- Parent guide: [Developer Guide — Extracted Services](../developer-guide.en.md#extracted-services)
