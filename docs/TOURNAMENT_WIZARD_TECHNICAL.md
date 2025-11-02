# Tournament Wizard System - Technical Documentation

## Overview

The Tournament Wizard System provides a step-by-step guided interface for tournament setup, making it easier for non-technical tournament directors to manage tournaments. This document describes the technical implementation and features.

## Architecture

### Wizard Steps

The wizard consists of 6 main steps, each mapped to a tournament state:

1. **Load Registration List** (`new_tournament` state)
2. **Import Seeding List** (wizard step, no state change)
3. **Edit Participant List** (`accreditation_finished` state)
4. **Finalize Participant List** (`tournament_seeding_finished` state)
5. **Select Tournament Mode** (`tournament_seeding_finished` state)
6. **Start Tournament** (creates `tournament_monitor`)

### Components

#### Views
- `app/views/tournaments/_wizard_steps_v2.html.erb`: Main wizard UI
- `app/views/tournaments/_wizard_step.html.erb`: Individual step rendering
- `app/views/tournaments/compare_seedings.html.erb`: Upload interface
- `app/views/tournaments/parse_invitation.html.erb`: Extraction results
- `app/views/tournaments/define_participants.html.erb`: Participant editing
- `app/views/tournaments/finalize_modus.html.erb`: Mode selection

#### Controllers
- `app/controllers/tournaments_controller.rb`: Main controller with wizard actions
- `app/controllers/regions_controller.rb`: Quick-load functionality

#### Services
- `app/services/seeding_list_extractor.rb`: OCR and PDF extraction

#### Models
- `app/models/tournament.rb`: Tournament model with scraping logic
- `app/models/tournament_monitor.rb`: Group distribution algorithms
- `app/models/tournament_plan.rb`: Tournament plan with group sizes

#### Helpers
- `app/helpers/tournament_wizard_helper.rb`: Wizard status logic

## Key Features

### 1. Automatic Seeding List Extraction

**Technology:**
- PDF text extraction: `pdf-reader` gem
- OCR for images: `rtesseract` gem with Tesseract-OCR
- Pattern matching: Regex-based extraction

**Extracted Data:**
- Player names and positions
- Handicap points (for handicap tournaments)
- Group assignments (if present)
- Tournament mode suggestions

**Supported Formats:**
- PDF files (with text)
- Screenshots (PNG, JPG)
- Single and two-column tables
- Tables with handicap columns

### 2. NBV-Compliant Group Assignment

**Algorithms:**
- **2 Groups:** Zig-Zag/Serpentine pattern
- **3+ Groups:** Round-Robin pattern
- **Unequal Group Sizes:** Special algorithm (e.g., T21: 3+4+4)

**Implementation:**
```ruby
# app/models/tournament_monitor.rb
def self.distribute_to_group(players, ngroups, group_sizes = nil)
  # Uses group_sizes from executor_params if available
  # Falls back to standard algorithms otherwise
end
```

**Group Sizes:**
Extracted from `TournamentPlan#executor_params`:
```ruby
# app/models/tournament_plan.rb
def group_sizes
  # Extracts [3, 4, 4] from executor_params JSON
end
```

### 3. Synchronization Modes

**Setup Phase** (`reload_games: false`):
- Only local seedings (ID >= 50M) are destroyed
- ClubCloud seedings (ID < 50M) are preserved
- New seedings are fetched from API server

**Archiving Phase** (`reload_games: true`):
- All seedings are destroyed
- Tournament is reset
- Game results are loaded from ClubCloud

**Implementation:**
```ruby
# app/controllers/tournaments_controller.rb
def reload_from_cc
  reload_games = params[:reload_games] == 'true'
  
  if reload_games
    @tournament.reset_tournament
    Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id)
  else
    @tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
    Version.update_from_carambus_api(update_tournament_from_cc: @tournament.id, reload_games: false)
  end
end
```

### 4. Quick-Load for Upcoming Tournaments

**Feature:**
- Loads only tournaments for the next N days (default: 30)
- Faster than full synchronization
- Available on regional association page

**Implementation:**
```ruby
# app/models/region.rb
def scrape_upcoming_tournaments(days_ahead: 30)
  # Only runs on API server
  # Fetches tournament list from ClubCloud
  # Creates/updates tournaments
  # Automatically detects handicap tournaments
end
```

### 5. Tournament Plan Validation

**Validation:**
- TournamentPlan must match participant count
- Group sizes must match executor_params
- Table assignments must be conflict-free

**Rake Tasks:**
```bash
# Validate executor_params for all plans
rake tournament_plans:validate_executor_params

# Auto-fix table conflicts
rake tournament_plans:fix_executor_params[PLAN_NAMES]

# Check seeding version records
rake tournament:check_seeding_versions[TOURNAMENT_ID]

# Clean up problematic version records
rake tournament:cleanup_seeding_versions[TOURNAMENT_ID]
```

## Database Schema

### Seedings
- `id < 50M`: ClubCloud seedings (from API server)
- `id >= 50M`: Local seedings (created on location server)
- `position`: Position in seeding list
- `balls_goal`: Handicap points (for handicap tournaments)
- `state`: "no_show" if player doesn't appear

### Tournament Data
- `data['extracted_group_assignment']`: Group assignments from invitation
- `data['extracted_plan_info']`: Tournament mode info from invitation
- `data['table_ids']`: Table assignments

## API Endpoints

### Local Server → API Server
- `GET /versions/get_updates?update_tournament_from_cc=ID&reload_games=false`
- `GET /versions/get_updates?scrape_upcoming_tournaments=REGION_ID&days_ahead=30`

### API Server → ClubCloud
- Tournament list: `sb_einzelergebnisse.php`
- Tournament details: `sb_meisterschaft.php`
- Results: `sb_einzelergebnisse.php`

## Error Handling

### Tournament Monitor Initialization
- Validates participant count matches TournamentPlan
- Validates executor_params consistency
- Checks for table conflicts
- Stores errors in `TournamentMonitor.data['error']`

### Seeding Synchronization
- Prevents deletion of ClubCloud seedings during setup
- Handles version record conflicts
- Provides cleanup rake tasks

## Known Issues and Solutions

### Problem: Seedings Deleted After Sync
**Cause:** Old "destroy" version records on API server
**Solution:** Use `rake tournament:cleanup_seeding_versions[TOURNAMENT_ID]`

### Problem: Incorrect Group Assignment
**Cause:** Group sizes not extracted correctly from executor_params
**Solution:** Validate TournamentPlan with `tournament_plans:validate_executor_params`

### Problem: Table Conflicts
**Cause:** Multiple groups assigned to same table in same round
**Solution:** Use `tournament_plans:fix_executor_params[PLAN_NAMES]`

## Testing

### Manual Testing
1. Create a test tournament
2. Upload an invitation (PDF or screenshot)
3. Verify extraction accuracy
4. Test group assignment algorithms
5. Verify synchronization modes

### Rake Tasks for Testing
```bash
# Test grouping algorithm for a plan
rake tournament_plans:test_grouping[T21]

# Analyze all plans
rake tournament_plans:analyze

# Validate executor_params
rake tournament_plans:validate_executor_params
```

## Future Enhancements

1. **Manual Group Assignment:** Drag-and-drop interface for group assignment
2. **Bulk Operations:** Add multiple players at once
3. **Import/Export:** Export seeding lists to CSV/PDF
4. **Automated Validation:** Real-time validation of tournament setup
5. **Mobile App:** Native mobile app for tournament management

## References

- [NBV Tournament Plan Analysis](../carambus_data/NBV_TOURNAMENT_PLAN_ANALYSIS.md)
- [Seeding List Extraction](SEEDING_LIST_AUTO_EXTRACTION.md)
- [Tournament Monitor Groups Fix](TOURNAMENT_MONITOR_GROUPS_FIX.md)

