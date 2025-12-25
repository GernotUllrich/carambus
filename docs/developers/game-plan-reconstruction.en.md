# GamePlan Reconstruction

This document explains how to reconstruct GamePlans from existing data without re-scraping.

## Overview

After scraping leagues with `opts[:cleanup] == true`, the GamePlans may become inconsistent with the new data. This functionality allows you to reconstruct GamePlans from the existing parties and party_games data without performing a full re-scraping.

## Key Features

- **Efficient Structure Analysis**: Analyzes only one party per league to extract the game plan structure (since structure doesn't change within a season)
- **Shared GamePlans**: Leagues with the same region, discipline, and name but different seasons share the same GamePlan
- **Comprehensive Statistics**: Analyzes all parties to build accurate statistics for game points, sets, balls, innings, etc.

## Methods

### Instance Method

```ruby
league.reconstruct_game_plan_from_existing_data
```

Reconstructs the GamePlan for a single league from its existing parties and party_games data.

### Class Methods

```ruby
# Reconstruct GamePlans for all leagues in a season
League.reconstruct_game_plans_for_season(season, opts = {})

# Delete existing GamePlans for a season
League.delete_game_plans_for_season(season, opts = {})

# Find leagues that should share the same GamePlan
League.find_leagues_with_same_gameplan(league)

# Find existing shared GamePlan
League.find_or_create_shared_gameplan(league)
```

### Filtering Options

The class methods support filtering via the `opts` parameter:

```ruby
# Filter by region shortname
opts = { region_shortname: 'BBV' }

# Filter by discipline
opts = { discipline: 'Pool' }

# Filter by both
opts = { region_shortname: 'BBV', discipline: 'Pool' }

# Example usage
results = League.reconstruct_game_plans_for_season(season, opts)
```

## Rake Tasks

### Reconstruct GamePlans for a Season

```bash
# Reconstruct all GamePlans for a season
rake carambus:reconstruct_game_plans[2021/2022]

# Reconstruct GamePlans for a specific region
rake carambus:reconstruct_game_plans[2021/2022,BBV]

# Reconstruct GamePlans for a specific discipline
rake carambus:reconstruct_game_plans[2021/2022,,Pool]

# Reconstruct GamePlans for a specific region and discipline
rake carambus:reconstruct_game_plans[2021/2022,BBV,Pool]
```

### Reconstruct GamePlan for a Specific League

```bash
rake carambus:reconstruct_league_game_plan[123]
```

### Delete GamePlans for a Season

```bash
# Delete all GamePlans for a season
rake carambus:delete_game_plans[2021/2022]

# Delete GamePlans for a specific region
rake carambus:delete_game_plans[2021/2022,BBV]

# Delete GamePlans for a specific discipline
rake carambus:delete_game_plans[2021/2022,,Pool]

# Delete GamePlans for a specific region and discipline
rake carambus:delete_game_plans[2021/2022,BBV,Pool]
```

### Clean and Reconstruct GamePlans for a Season

This deletes existing GamePlans and then reconstructs them:

```bash
# Clean and reconstruct all GamePlans for a season
rake carambus:clean_reconstruct_game_plans[2021/2022]

# Clean and reconstruct GamePlans for a specific region
rake carambus:clean_reconstruct_game_plans[2021/2022,BBV]

# Clean and reconstruct GamePlans for a specific discipline
rake carambus:clean_reconstruct_game_plans[2021/2022,,Pool]

# Clean and reconstruct GamePlans for a specific region and discipline
rake carambus:clean_reconstruct_game_plans[2021/2022,BBV,Pool]
```

### Filtering Options

The rake tasks support filtering by:

- **Region Shortname**: Filter by specific regions (e.g., BBV, BVBW, DBU)
- **Discipline**: Filter by discipline type (Pool, Karambol, Snooker, Kegel)

Examples:
```bash
# Only Pool leagues in BBV region
rake carambus:reconstruct_game_plans[2021/2022,BBV,Pool]

# Only Karambol leagues (all regions)
rake carambus:reconstruct_game_plans[2021/2022,,Karambol]

# Only Snooker leagues in BVBW region
rake carambus:reconstruct_game_plans[2021/2022,BVBW,Snooker]
```

## How It Works

The reconstruction process:

1. **Structure Analysis**: Analyzes one party per league to extract the game plan structure (disciplines, rounds, etc.)

2. **Statistics Collection**: Iterates through all parties and their party_games to collect:
   - Game points (win, draw, lost)
   - Sets information
   - Balls/score for relevant disciplines
   - Innings for relevant disciplines
   - Partie points (Punkte)
   - Shootout vs non-shootout games

3. **Shared GamePlans**: 
   - GamePlans are identified by name: `"#{league.name} - #{branch.name} - #{organizer.shortname}"`
   - Leagues with the same name, discipline, and organizer share the same GamePlan across seasons
   - Only one league per group needs to reconstruct the GamePlan

4. **Data Processing**:
   - Removes statistics that appear less than 3 times (innings, sets)
   - Tracks shootout logic
   - Calculates match points from party results

5. **GamePlan Creation/Update**: Saves the reconstructed GamePlan and links it to all relevant leagues

## Efficiency Improvements

### Structure Analysis
- Only analyzes one party per league to determine the game plan structure
- Structure is assumed to be consistent within a season
- Much faster than analyzing every party for structure

### Shared GamePlans
- Groups leagues by their GamePlan name before processing
- Only reconstructs one GamePlan per group
- Links all leagues in the group to the same GamePlan
- Reduces processing time and ensures consistency across seasons

## Example Usage

```ruby
# Find a season
season = Season.find_by_name("2021/2022")

# Reconstruct all GamePlans for the season
results = League.reconstruct_game_plans_for_season(season)
puts "Success: #{results[:success]}, Failed: #{results[:failed]}"

# Reconstruct for a specific league
league = League.find(123)
game_plan = league.reconstruct_game_plan_from_existing_data
puts "Reconstructed GamePlan: #{game_plan.name}"

# Find leagues that share the same GamePlan
shared_leagues = League.find_leagues_with_same_gameplan(league)
puts "Found #{shared_leagues.count} leagues sharing the same GamePlan"

# Find existing shared GamePlan
existing_gameplan = League.find_or_create_shared_gameplan(league)
if existing_gameplan
  puts "Found existing GamePlan: #{existing_gameplan.name}"
end
```

## Error Handling

The methods include comprehensive error handling:

- Logs all operations to Rails.logger
- Returns detailed error information
- Continues processing even if individual leagues fail
- Provides summary statistics
- Groups errors by GamePlan name for shared GamePlans

## Notes

- **Structure Consistency**: The method assumes that game plan structure doesn't change within a season
- **Shared GamePlans**: GamePlans are shared across seasons for leagues with the same name, discipline, and organizer
- **Efficiency**: Much faster than re-scraping since it doesn't make HTTP requests and uses efficient grouping
- **Consistency**: Uses the same logic as the original scraping but works with existing data
- **Flexibility**: Can process individual leagues or entire seasons with shared GamePlan handling 