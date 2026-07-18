# Tournament Duplicate Handling System

## Overview

This system addresses the issue of duplicate tournaments with different `cc_id` values during scraping. The source (ClubCloud) sometimes exposes the same tournament (same name, season, organizer) under more than one `cc_id`. Without handling, repeated scraping runs would flip-flop between the different `cc_id` versions. This system marks the superseded `cc_id` as abandoned so future runs skip it.

## How It Works

### 1. Per-Row Incremental Deduplication (live scrape path)

Deduplication happens **incrementally, row by row**, inside
`Region#scrape_single_tournament_public(season, opts = {})`
(`app/models/region.rb`). There is **no up-front group-by-name pass** in the
live scrape; each tournament row from the ClubCloud listing is processed in
turn:

1. The current row's `cc_id` is read from the tournament link.
2. If that `cc_id` is already in the abandoned skip-list
   (`AbandonedTournamentCcSimple.is_abandoned?(cc_id, context)`), the row is
   skipped entirely.
3. Otherwise the scraper looks for an **existing** `TournamentCc` whose
   associated `Tournament` has the **same title, season, and organizer** but a
   **different `cc_id`**:

   ```ruby
   existing_tc_for_tournament = TournamentCc.joins(:tournament)
     .where(tournaments: { title: name, season: season, organizer: self })
     .where.not(cc_id: cc_id)
     .first
   ```

4. If such a record exists, it is treated as the stale duplicate: its
   `old_cc_id` is marked abandoned and the scraper proceeds with the
   **currently scraped `cc_id`**, creating/updating a `TournamentCc` for it.

### 2. Selection Behavior

The **implemented** behavior is simple: **keep the currently scraped `cc_id`
and abandon the prior one** found for the same tournament title. The "current
row wins" because the ClubCloud listing is the source of truth for what is
live right now.

> **Not yet implemented (design goal):** A richer selection ladder —
> *has games > has seedings > highest `cc_id`* — was sketched as a future
> improvement but is **not** part of the live scrape path. The partial
> seedings/games inspection that exists (`Region#check_tournament_status`) is
> only used by the diagnostic `analyze_duplicates` reporting task, not to
> drive automatic selection.

### 3. Abandonment Tracking

Abandoned `cc_id` values are recorded so future runs skip them. Two distinct
models are involved — see [Database Models](#database-models).

## Database Models

There are **two separate models**, with distinct roles:

### `AbandonedTournamentCcSimple` — live scrape skip-list

`app/models/abandoned_tournament_cc_simple.rb`, table
`abandoned_tournament_cc_simples`. This is the lean model the **live scraper
actually writes and reads**. It stores only what is needed to skip a `cc_id`
on subsequent runs:

| Column         | Description                                  |
|----------------|----------------------------------------------|
| `cc_id`        | The abandoned tournament `cc_id`             |
| `context`      | The region context (e.g. `dbu`, `nbv`)       |
| `abandoned_at` | When it was marked abandoned                 |

Class methods:
- `is_abandoned?(cc_id, context)` — check the skip-list.
- `mark_abandoned!(cc_id, context)` — add to the skip-list (no-op on duplicate).

### `AbandonedTournamentCc` — manual / diagnostic model

`app/models/abandoned_tournament_cc.rb`, table `abandoned_tournament_ccs`.
This is the **richer audit model** used by the manual/diagnostic rake tasks
(`analyze_duplicates`, `list_abandoned_tournaments`,
`mark_tournament_abandoned`, `cleanup_abandoned_tournaments`). The live scrape
path does **not** write to it.

```ruby
# Columns:
- cc_id: The abandoned tournament cc_id
- context: The region context (e.g. 'dbu', 'nbv')
- region_shortname: The region shortname
- season_name: The season name
- tournament_name: The tournament name
- abandoned_at: When it was marked as abandoned
- reason: Why it was abandoned
- replaced_by_cc_id: Which cc_id replaced it
- replaced_by_tournament_id: Which tournament replaced it
```

Class methods:
- `is_abandoned?(cc_id, context)` — check if a cc_id is abandoned.
- `mark_abandoned!(cc_id, context, region_shortname, season_name, tournament_name, reason:, replaced_by_cc_id:, replaced_by_tournament_id:)` — record/update a rich abandonment entry.
- `for_region_season(region_shortname, season_name)` — scope used by listing.
- `find_duplicate_tournaments(region_shortname, season_name, tournament_name)` — ordered duplicate lookup.
- `analyze_duplicates(region_shortname, season_name)` — group the live ClubCloud listing by name and report duplicate `cc_id`s with their seedings/games/abandoned status.
- `cleanup_old_records(days = 365)` — remove old records (positional `days`).

## Usage

### Automatic Handling

Incremental deduplication runs automatically as part of the public tournament
scrape (`Season#scrape_single_tournaments_public_cc` →
`Region#scrape_single_tournament_public`), which is invoked by the daily
`scrape:daily_update_monitored` task.

### Manual Management

#### Analyze Duplicates
```bash
rake scrape:analyze_duplicates REGION=NBV SEASON=2023/2024
```

#### List Abandoned Tournaments
```bash
rake scrape:list_abandoned_tournaments REGION=NBV SEASON=2023/2024
```

#### Manually Mark as Abandoned (rich model)
```bash
rake scrape:mark_tournament_abandoned \
  CC_ID=123 \
  CONTEXT=nbv \
  REGION=NBV \
  SEASON=2023/2024 \
  TOURNAMENT="Tournament Name" \
  REASON="Manual cleanup" \
  REPLACED_BY_CC_ID=456
```

#### Mark a cc_id as Abandoned (simple skip-list)
```bash
rake scrape:mark_abandoned_simple CC_ID=123 CONTEXT=nbv
```

#### Cleanup Old Records
```bash
# Clean up records older than 365 days (default)
rake scrape:cleanup_abandoned_tournaments

# Clean up records older than 180 days
rake scrape:cleanup_abandoned_tournaments DAYS=180
```

## Implementation Details

### Where the dedup lives

- **Entry (working path):** `Season#scrape_single_tournaments_public_cc(opts)`
  iterates all regions and calls
  `Region#scrape_single_tournament_public(season, opts)`.
- **Dedup logic:** inside `Region#scrape_single_tournament_public`
  (`app/models/region.rb`, around lines 505–545). It checks the abandoned
  skip-list, looks up an existing same-title `TournamentCc` with a different
  `cc_id`, abandons the old one via `AbandonedTournamentCcSimple`, and keeps
  the current `cc_id`.

There are **no** `process_single_tournament` or `process_duplicate_tournaments`
helper methods — the logic is inline in `scrape_single_tournament_public`.

## Migration

Run migrations to create the two tables
(`abandoned_tournament_cc_simples` and `abandoned_tournament_ccs`):
```bash
rails db:migrate
```

## Benefits

1. **Eliminates flip-flopping**: Once a `cc_id` is on the simple skip-list, it
   is skipped on future runs.
2. **Automatic detection**: No manual intervention required for the common case.
3. **Audit trail (manual model)**: The rich `AbandonedTournamentCc` model
   provides history, reasons, and replacement links for diagnostic/manual use.
4. **Manual override**: Ability to mark tournaments abandoned via rake tasks.
5. **Cleanup**: `cleanup_abandoned_tournaments` removes old rich records.

## Example Log Output

When a same-title duplicate with a different `cc_id` is encountered:
```
===== scrape ===== Found duplicate tournament 'NDM 9-Ball', marked old cc_id 123 as abandoned, keeping cc_id 456
===== scrape ===== Skipping abandoned cc_id 123 for tournament 'NDM 9-Ball'
```

## Troubleshooting

### If a tournament is incorrectly abandoned
1. For the live skip-list, remove the offending row from
   `abandoned_tournament_cc_simples` (e.g. via `rails console`:
   `AbandonedTournamentCcSimple.where(cc_id: 123, context: 'nbv').delete_all`).
2. For the rich model, use `rake scrape:list_abandoned_tournaments` to find it,
   then delete or update the record.
3. Re-run the scrape.

### If duplicates are not being handled
1. Use `rake scrape:analyze_duplicates` to confirm the listing actually
   contains multiple `cc_id`s for the same name.
2. Verify the tournament titles match exactly (including whitespace) — the
   dedup query matches on `tournaments.title`.
3. Check that the region and season are correct.
