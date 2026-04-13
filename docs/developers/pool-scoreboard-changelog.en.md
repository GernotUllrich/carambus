# Changelog: Pool Scoreboard & League Match Management

## Version 2025-12-03

### Overview

This version brings extensive improvements for the Pool Scoreboard and League Match Management (PartyMonitor). The changes include bug fixes, new features, and optimizations.

---

## New Features

### 1. Pool Quickstart Buttons

**Files:**
- `config/carambus.yml.erb`
- `app/views/locations/_quick_game_buttons.html.erb`
- `app/controllers/table_monitors_controller.rb`

**Description:**
Pool tables now have configurable quickstart buttons similar to carom tables:

```yaml
pool:
  8-Ball:
    - { sets: 5, discipline: "8-Ball", kickoff_switches_with: "set", label: "Best of 5" }
    - { sets: 6, discipline: "8-Ball", kickoff_switches_with: "set", label: "Best of 6" }
  9-Ball:
    - { sets: 7, discipline: "9-Ball", kickoff_switches_with: "set", label: "Best of 7" }
    - { sets: 9, discipline: "9-Ball", kickoff_switches_with: "set", label: "Best of 9" }
  10-Ball:
    - { sets: 7, discipline: "10-Ball", kickoff_switches_with: "set", label: "Best of 7" }
  14.1 endlos:
    - { balls: 50, innings: 0, discipline: "14.1 endlos", label: "50 Points" }
    - { balls: 75, innings: 0, discipline: "14.1 endlos", label: "75 Points" }
    - { balls: 100, innings: 0, discipline: "14.1 endlos", label: "100 Points" }
```

### 2. Pool Scoreboard User Manual

**File:** `docs/pool_scoreboard_benutzerhandbuch.de.md`

Complete German user manual for pool players with:
- Instructions for all pool disciplines (8-Ball, 9-Ball, 10-Ball, 14.1 endlos)
- Scoreboard layout diagrams
- Key bindings and touch operation
- Screenshots of the most important views
- Troubleshooting

---

## Bug Fixes

### 1. 14.1 endlos Rerack Logic

**File:** `app/models/table_monitor.rb`

**Problem:**
With 14.1 endlos, the rerack (re-racking to 15 balls) was not correctly displayed. The ball display and the counter stack were not properly updated during partial updates.

**Solution:**
- `ultra_fast_score_update?` and `simple_score_update?` now always return `false` for "14.1 endlos"
- This causes a full re-render on every update
- The `recompute_result` method now also takes into account the `innings_redo_list` of both players

```ruby
def ultra_fast_score_update?
  return false if data.dig("playera", "discipline") == "14.1 endlos"
  # ... rest of method
end

def simple_score_update?
  return false if data.dig("playera", "discipline") == "14.1 endlos"
  # ... rest of method
end
```

### 2. Pool Scoreboard Syntax Error

**File:** `app/views/table_monitors/_pool_scoreboard.html.erb`

**Problem:**
ERB syntax error due to multiple assignment with condition and missing `end` tag.

**Solution:**
```erb
# Before (broken):
<%- time_counter, ... = options[:timer_data] if fullscreen && options[:timer_data].present? %>

# After (correct):
<%- if fullscreen && options[:timer_data].present? %>
  <%- time_counter, ... = options[:timer_data] %>
<%- end %>
```

### 3. PartyMonitor Game Association

**File:** `app/models/table_monitor.rb`

**Problem:**
When starting league matches through the PartyMonitor, new games were created instead of using the existing Party games. As a result, game results were not correctly displayed in the PartyMonitor.

**Solution:**
The `start_game()` method now checks whether an existing Party/Tournament game is present:

```ruby
def start_game(options_ = {})
  # Check if we have an existing Party/Tournament game that should be preserved
  existing_party_game = game if game.present? && game.tournament_type.present?
  
  if existing_party_game.present?
    # Use the existing Party/Tournament game - don't create a new one
    @game = existing_party_game
    # Update game participations instead of creating new ones
    # ...
  else
    # Create a new game for free games
    # ...
  end
end
```

### 4. PartyMonitor Result Storage

**File:** `app/models/table_monitor.rb`

**Problem:**
The `ba_results` were only saved to the game for free games, not for Party/Tournament games.

**Solution:**
```ruby
def prepare_final_game_result
  # ...
  # Save results to the game for both free games and tournament/party games
  if final_set_score? && game.present?
    game.deep_merge_data!("ba_results" => data["ba_results"])
    game.save!
  end
end
```

### 5. PartyMonitor Reset Button

**File:** `app/reflexes/party_monitor_reflex.rb`

**Problem:**
The "Reset match day monitor completely" button did not work when `table_monitor.game` was `nil`.

**Solution:**
```ruby
def reset_party_monitor
  # 1. Delete games from TableMonitors (only if present)
  @party_monitor.table_monitors.each do |table_monitor|
    table_monitor.game&.destroy  # Safe navigation operator
  end
  # 2. Delete all TableMonitors
  @party_monitor.table_monitors.destroy_all
  # 3. Delete all Party games
  @party_monitor.party.games.destroy_all
  # 4. Delete test seedings
  @party_monitor.party.seedings.where("id > 5000000").destroy_all
  # 5. Reset the PartyMonitor
  @party_monitor.reset_party_monitor
  flash[:notice] = "Party Monitor completely reset"
rescue StandardError => e
  flash[:alert] = "Error during reset: #{e.message}"
end
```

### 6. League Match Parameters Editable

**Files:**
- `app/views/party_monitors/_party_monitor.html.erb`
- `app/reflexes/party_monitor_reflex.rb`
- `app/models/discipline.rb`

**Problem:**
The match parameters (e.g., target score 80 for 14.1 endlos) could not be edited before the match started.

**Solution:**
- Parameter buttons are now editable in the `seeding_mode`, `table_definition_mode`, and `next_round_seeding_mode` states
- `Discipline::GAME_PARAMETERS` for "14/1e" was extended with additional target scores (60, 70, 80) and inning limits
- The `start_round` method now correctly parses score values from strings like "Hauptrunde 80"

---

## JavaScript Changes

### balls_left Method

**File:** `app/javascript/controllers/table_monitor_controller.js`

**Problem:**
Clicking on balls in the control bar had no effect.

**Solution:**
Added the missing JavaScript method:

```javascript
balls_left () {
  console.log('TableMonitor balls_left called')
  this.stimulate('TableMonitor#balls_left', this.element)
}
```

---

## Removed Features

### Duplicate Undo Button

**File:** `app/views/table_monitors/_pool_scoreboard.html.erb`

The undo button below the table name was removed, as there is already an undo/redo in the top menu.

---

## Tested Scenarios

1. **Pool Quickstart**: All disciplines (8-Ball, 9-Ball, 10-Ball, 14.1 endlos) with various parameters
2. **14.1 endlos Rerack**: Correct re-racking with 1 or 0 remaining balls
3. **League match management**: Complete workflow from seeding to match completion
4. **PartyMonitor Reset**: Reset via UI button and Rails console
5. **Result display**: Correct display of match results in PartyMonitor

---

## Commits

1. `feature/pool-scoreboard-quickstart` → `master` (Merge)
2. Fix PartyMonitor game results display
3. Fix PartyMonitor reset button

---

## Affected Models

- `TableMonitor`
- `PartyMonitor`
- `Game`
- `GameParticipation`
- `Discipline`

## Affected Views

- `_pool_scoreboard.html.erb`
- `_quick_game_buttons.html.erb`
- `_party_monitor.html.erb`
- `_game_row.html.erb`

## Affected Controllers/Reflexes

- `table_monitors_controller.rb`
- `party_monitor_reflex.rb`
- `table_monitor_reflex.rb`

## Affected JavaScript

- `table_monitor_controller.js`

---

## Documentation

- `docs/pool_scoreboard_benutzerhandbuch.de.md` - New user manual
- `docs/CHANGELOG_POOL_SCOREBOARD.md` - This file
