# Tournament Duplicate Handling System

## Overview

This system addresses the issue of duplicate tournaments with different `cc_id` values during scraping. When the source contains multiple tournaments with the same name, date, and discipline but different `cc_id` values, this system automatically detects and handles them to prevent flip-flopping between different versions.

## How It Works

### 1. Duplicate Detection
- During scraping, tournaments are grouped by name
- If multiple tournaments have the same name, they are identified as duplicates
- The system analyzes each duplicate to determine which one to keep

### 2. Selection Logic
The system prioritizes tournaments in this order:
1. **Has games** - This is the definitive version, tournament is active and being used
2. **Has seedings** - Tournament managers have started working on this version (pre-tournament setup)
3. **No seedings and no games** - Clean slate tournaments (lowest priority)
4. **Highest cc_id** - If all have the same data status, the highest cc_id is usually the correct one

### 3. Abandonment Tracking
- Abandoned `cc_id` values are stored in the `abandoned_tournament_ccs` table
- Future scraping runs will skip these abandoned `cc_id` values
- This prevents the flip-flopping behavior you were experiencing

## Database Schema

### AbandonedTournamentCc Model
```ruby
# Fields:
- cc_id: The abandoned tournament cc_id
- context: The region context (e.g., 'dbu', 'nbv')
- region_shortname: The region shortname
- season_name: The season name
- tournament_name: The tournament name
- abandoned_at: When it was marked as abandoned
- reason: Why it was abandoned
- replaced_by_cc_id: Which cc_id replaced it
- replaced_by_tournament_id: Which tournament replaced it
```

## Usage

### Automatic Handling
The system works automatically when you run:
```bash
rake scrape:tournaments_optimized
```

### Manual Management

#### Analyze Duplicates
```bash
rake scrape:analyze_duplicates REGION=NBV SEASON=2023/2024
```

#### List Abandoned Tournaments
```bash
rake scrape:list_abandoned_tournaments REGION=NBV SEASON=2023/2024
```

#### Manually Mark as Abandoned
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

#### Cleanup Old Records
```bash
# Clean up records older than 365 days (default)
rake scrape:cleanup_abandoned_tournaments

# Clean up records older than 180 days
rake scrape:cleanup_abandoned_tournaments DAYS=180
```

## Implementation Details

### Modified Methods

#### Region#scrape_tournaments_optimized
- Now groups tournaments by name before processing
- Detects duplicates and applies selection logic
- Marks abandoned cc_ids for future runs

#### New Private Methods
- `process_single_tournament`: Handles individual tournaments
- `process_duplicate_tournaments`: Handles duplicate groups

### AbandonedTournamentCc Model
- `is_abandoned?`: Check if a cc_id is abandoned
- `mark_abandoned!`: Mark a cc_id as abandoned
- `analyze_duplicates`: Analyze duplicates for a region/season
- `cleanup_old_records`: Remove old abandoned records

## Migration

Run the migration to create the new table:
```bash
rails db:migrate
```

## Benefits

1. **Eliminates Flip-flopping**: Once a cc_id is abandoned, it won't be processed again
2. **Automatic Detection**: No manual intervention required for most cases
3. **Audit Trail**: Full history of abandoned tournaments with reasons
4. **Manual Override**: Ability to manually mark tournaments as abandoned
5. **Cleanup**: Automatic cleanup of old abandoned records

## Example Output

When duplicates are found:
```
===== scrape ===== Found 3 duplicates for tournament 'NDM 9-Ball'
===== scrape ===== Marked cc_id 123 as abandoned for tournament 'NDM 9-Ball' (keeping 456)
===== scrape ===== Marked cc_id 789 as abandoned for tournament 'NDM 9-Ball' (keeping 456)
===== scrape ===== Region NBV: Processed 15 tournaments, skipped 5 tournaments, abandoned 2 duplicates
```

## Troubleshooting

### If a tournament is incorrectly abandoned:
1. Use `rake scrape:list_abandoned_tournaments` to find it
2. Delete the record from the database or mark it as replaced by the correct cc_id
3. Re-run the scraping

### If duplicates are not being detected:
1. Use `rake scrape:analyze_duplicates` to check for duplicates
2. Verify the tournament names match exactly (including whitespace)
3. Check that the region and season are correct 