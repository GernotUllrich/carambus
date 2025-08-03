# Cascading Filters Developer Guide

## Overview

This guide explains how to implement cascading reference filters in advanced search popups for Rails index pages. Cascading filters allow users to select a parent entity (e.g., Region) and then see only related child entities (e.g., Clubs) in the dropdown.

## Architecture

The system uses:
- **StimulusReflex** for dynamic dropdown updates
- **ID-based filtering** instead of text-based searches
- **`data-id` attributes** on select options for exact matching
- **State restoration** when reopening the filter popup

## Step-by-Step Implementation

### 1. Define Model Search Hash

First, define the `search_hash` method in your model with proper column mappings:

```ruby
# app/models/your_model.rb
class YourModel < ApplicationRecord
  COLUMN_NAMES = {
    "ID" => "your_models.id",
    "Region" => "regions.shortname",           # Parent reference
    "Club" => "clubs.shortname",               # Child reference
    "Name" => "your_models.name",
    # ... other fields
  }.freeze

  def self.search_hash(params)
    {
      model: YourModel,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: YourModel::COLUMN_NAMES.merge({
        "region_id" => "regions.id",           # ID field for parent
        "club_id" => "clubs.id"                # ID field for child
      }),
      raw_sql: "(regions.shortname ilike :search) or (clubs.shortname ilike :search) or (your_models.name ilike :search)",
      joins: [:region, :club],                 # Include necessary joins
      distinct: true                           # Prevent duplicates if needed
    }
  end
end
```

### 2. Update Application Helper

The helper automatically detects reference fields and generates proper field keys:

```ruby
# app/helpers/application_helper.rb
# This is already implemented - no changes needed
# The helper automatically:
# - Detects 'regions.shortname' → field_key: 'region_shortname'
# - Detects 'clubs.shortname' → field_key: 'club_shortname'
# - Detects 'regions.id' → field_key: 'region_id'
# - Detects 'clubs.id' → field_key: 'club_id'
```

### 3. Create StimulusReflex Method

Add a dedicated reflex method for your model:

```ruby
# app/reflexes/filter_popup_reflex.rb
def filter_clubs_by_region_for_your_model
  region_shortname = element.value
  
  if region_shortname.present?
    clubs = Club.joins(:region)
                .where(regions: { shortname: region_shortname })
                .where.not(shortname: [nil, ''])
                .order(:shortname)
                .limit(50)
                .pluck(:id, :shortname, :name, 'regions.shortname')
    
    club_options = clubs.map do |id, shortname, name, region|
      next if shortname.blank?
      display_name = name.present? ? "#{shortname} (#{name})" : shortname
      region_info = region.present? ? " - #{region}" : ""
      { value: shortname, label: "#{display_name}#{region_info}", id: id }
    end.compact
    
    club_options.sort_by! { |option| option[:label].downcase }
  else
    club_options = []
  end
  
  morph '#club-dropdown-your-model', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
end
```

### 4. Update Application Helper for Your Model

Add the reflex mapping for your model:

```ruby
# app/helpers/application_helper.rb
# In the render_select_input method, add:

# If this is a region field for your_model page, add data attributes for triggering club filtering
if field[:field_key] == 'region_shortname' && field[:model_class] == YourModel
  data_attributes[:action] = "change->filter-popup#saveRecentSelection"
  data_attributes[:reflex] = 'change->FilterPopupReflex#filter_clubs_by_region_for_your_model'
end
```

### 5. Update Select ID Helper

Add your model to the `get_select_id` method:

```ruby
# app/helpers/application_helper.rb
def get_select_id(field)
  case field[:field_key]
  when 'region_shortname'
    if field[:model_class] == YourModel
      'region-dropdown-your-model'
    # ... existing cases
    end
  when 'club_shortname'
    if field[:model_class] == YourModel
      'club-dropdown-your-model'
    # ... existing cases
    end
  # ... rest of method
  end
end
```

### 6. Update JavaScript Restoration

Add your model to the restoration logic:

```javascript
// app/javascript/controllers/filter_popup_controller.js
// In the restoreCurrentSearchState method, update the reflex name detection:

const currentPath = window.location.pathname
let reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_players'

if (currentPath.includes('/your_model')) {
  reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_your_model'
} else if (currentPath.includes('/locations')) {
  reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_locations'
} else if (currentPath.includes('/clubs')) {
  reflexName = 'change->FilterPopupReflex#filter_clubs_by_region_for_clubs'
}
```

## Testing Checklist

### Backend Testing

1. **Model Search Hash**:
   ```ruby
   # Test in Rails console
   YourModel.search_hash({})[:column_names]
   # Should include "region_id" => "regions.id" and "club_id" => "clubs.id"
   ```

2. **Reflex Method**:
   ```ruby
   # Test in Rails console
   clubs = Club.joins(:region).where(regions: { shortname: 'NBV' }).pluck(:id, :shortname)
   # Should return array of [id, shortname] pairs
   ```

### Frontend Testing

1. **Filter Popup Opens**: Click filter button, popup should appear
2. **Region Selection**: Select a region, club dropdown should update
3. **Club Selection**: Select a club, both should be selected
4. **Search Application**: Click "Anwenden", search should work
5. **State Restoration**: Close and reopen popup, selections should be restored
6. **URL Persistence**: Search string should appear in URL

### Debug Commands

```bash
# Check if server is running on correct port
ps aux | grep puma

# Clear browser cache
# Ctrl+Shift+R (hard refresh)

# Check Rails logs for errors
tail -f log/development.log
```

## Common Issues and Solutions

### Issue: "No current search, returning early"
**Solution**: Check if search string is being saved to URL properly

### Issue: "Reflex failed due to mismatched URL"
**Solution**: Ensure only one Rails server is running on the correct port

### Issue: Club options don't have `data-id` attributes
**Solution**: Check that reflex method uses `.pluck(:id, :shortname, ...)` and includes `id: id` in options

### Issue: Region not restored on popup reopen
**Solution**: Check that `restoreCurrentSearchState` method is called in `toggle()` method

### Issue: Club dropdown shows all clubs instead of filtered ones
**Solution**: Check that reflex method is correctly filtering by region

### Issue: Party field detected as number input instead of select
**Solution**: Ensure Party field detection happens before numeric field detection in `detect_field_type_and_options`

### Issue: Party dropdown shows duplicate values
**Solution**: Use party ID as value instead of `day_seqno` to ensure unique values

### Issue: Party filtering not working
**Solution**: Add `"party_id" => "parties.id"` to the column_names mapping

## Best Practices

1. **Always use ID-based filtering** for reference fields
2. **Include `data-id` attributes** on all select options
3. **Use dedicated reflex methods** for each model to avoid conflicts
4. **Test state restoration** thoroughly
5. **Clear browser cache** when testing
6. **Use descriptive field names** (e.g., "Club" instead of "Shortname")
7. **Check field detection order** - reference fields must be detected before numeric fields
8. **Use meaningful display names** for better user experience

## Example: PartyGame Cascading Filters Implementation

This is the actual implementation we completed for PartyGame with the relationship:
`party_game.party.league.season.organizer` (where organizer is the Region)

### 1. PartyGame Model

```ruby
# app/models/party_game.rb
class PartyGame < ApplicationRecord
  belongs_to :party
  has_one :league, through: :party
  has_one :season, through: :league
  has_one :organizer, through: :league, source: :region

  COLUMN_NAMES = {
    "Region" => "regions.shortname",
    "Season" => "seasons.name",
    "League" => "leagues.shortname", 
    "Party" => "parties.id",                    # Use ID for unique values
    "Name" => "party_games.name",
    "Seqno" => "party_games.seqno",
    "Discipline" => "disciplines.name",
    "Player A" => "player_a.name",
    "Player B" => "player_b.name",
    "Tournament" => "tournaments.name"
  }.freeze

  def self.search_hash(params)
    {
      model: PartyGame,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: PartyGame::COLUMN_NAMES.merge({
        "region_id" => "regions.id",
        "season_id" => "seasons.id",
        "league_id" => "leagues.id",
        "party_id" => "parties.id"              # Required for filtering
      }),
      raw_sql: "(leagues.shortname ilike :search) or (parties.id = :isearch) or (party_games.name ilike :search) or (disciplines.name ilike :search) or (regions.shortname ilike :search) or (seasons.name ilike :search)",
      joins: "INNER JOIN parties ON parties.id = party_games.party_id INNER JOIN leagues ON leagues.id = parties.league_id INNER JOIN seasons ON seasons.id = leagues.season_id INNER JOIN regions ON regions.id = leagues.organizer_id AND leagues.organizer_type = 'Region'",
      distinct: true
    }
  end
end
```

### 2. Application Helper Updates

```ruby
# app/helpers/application_helper.rb
# In detect_field_type_and_options method, add Party field detection BEFORE numeric fields:

# Party fields (for PartyGame model) - must be checked before numeric fields
if column_def.include?('parties.id') && model_class == PartyGame
  # For cascading filters, start with empty options
  # The options will be populated by StimulusReflex when a league is selected
  return 'select', 'select', []
end

# Numeric fields (must come after specific field detections)
if column_def =~ /_id$/ || column_def =~ /\.id$/ || column_def =~ /\.balls$/ || column_def =~ /\.innings$/
  return 'number', 'number', nil
end

# In render_select_input method, add reflex mappings:

# If this is a region field for party_games page
if field[:field_key] == 'region_shortname' && field[:model_class] == PartyGame
  data_attributes[:action] = "change->filter-popup#saveRecentSelection"
  data_attributes[:reflex] = 'change->FilterPopupReflex#filter_seasons_by_region_for_party_games'
end

# If this is a season field for party_games page
if field[:field_key] == 'season_name' && field[:model_class] == PartyGame
  data_attributes[:action] = "change->filter-popup#saveRecentSelection"
  data_attributes[:reflex] = 'change->FilterPopupReflex#filter_leagues_by_season_for_party_games'
end

# If this is a league field for party_games page
if field[:field_key] == 'league_shortname' && field[:model_class] == PartyGame
  data_attributes[:action] = "change->filter-popup#saveRecentSelection"
  data_attributes[:reflex] = 'change->FilterPopupReflex#filter_parties_by_league_for_party_games'
end

# If this is a party field for party_games page
if field[:field_key] == 'party_shortname' && field[:model_class] == PartyGame
  data_attributes[:action] = "change->filter-popup#saveRecentSelection"
end

# Update get_select_id method:
def get_select_id(field)
  case field[:field_key]
  when 'region_shortname'
    if field[:model_class] == PartyGame
      'region-dropdown-party-games'
    # ... existing cases
    end
  when 'season_name'
    if field[:model_class] == PartyGame
      'season-dropdown-party-games'
    else
      'season-dropdown'
    end
  when 'league_shortname'
    if field[:model_class] == PartyGame
      'league-dropdown-party-games'
    else
      'league-dropdown'
    end
  when 'party_shortname'
    if field[:model_class] == PartyGame
      'party-dropdown-party-games'
    else
      'party-dropdown'
    end
  # ... rest of method
  end
end
```

### 3. Reflex Methods

```ruby
# app/reflexes/filter_popup_reflex.rb
def filter_seasons_by_region_for_party_games
  region_shortname = element.value
  
  if region_shortname.present?
    seasons = Season.where.not(name: [nil, ''])
                     .order(id: :desc)
                     .limit(50)
    
    season_options = seasons.map do |season|
      next if season.name.blank?
      { value: season.name, label: season.name, id: season.id }
    end.compact
    
    season_options.sort_by! { |option| option[:label].downcase }
  else
    season_options = []
  end
  
  morph '#season-dropdown-party-games', render(partial: 'shared/season_dropdown_options', locals: { seasons: season_options })
end

def filter_leagues_by_season_for_party_games
  season_name = element.value
  
  if season_name.present?
    season = Season.find_by(name: season_name)
    if season
      leagues = League.where(season: season)
                     .where.not(shortname: [nil, ''])
                     .order(:shortname)
                     .limit(50)
                     .includes(:organizer)
      
      league_options = leagues.map do |league|
        next if league.shortname.blank?
        display_name = league.name.present? ? "#{league.shortname} (#{league.name})" : league.shortname
        season_info = league.season&.name.present? ? " - #{league.season.name}" : ""
        { value: league.shortname, label: "#{display_name}#{season_info}", id: league.id }
      end.compact
      
      league_options.sort_by! { |option| option[:label].downcase }
    else
      league_options = []
    end
  else
    league_options = []
  end
  
  morph '#league-dropdown-party-games', render(partial: 'shared/league_dropdown_options', locals: { leagues: league_options })
end

def filter_parties_by_league_for_party_games
  league_shortname = element.value
  
  if league_shortname.present?
    league = League.find_by(shortname: league_shortname)
    if league
      parties = Party.where(league: league)
                    .where.not(day_seqno: nil)
                    .order(:day_seqno)
                    .limit(50)
                    .includes(:league)
      
      party_options = parties.map do |party|
        next if party.day_seqno.nil?
        # Use the party name which shows league team names
        display_name = party.name.present? ? party.name : "Party #{party.day_seqno}"
        league_info = party.league&.shortname.present? ? " (#{party.league.shortname})" : ""
        { value: party.id, label: "#{display_name}#{league_info}", id: party.id }
      end.compact
      
      party_options.sort_by! { |option| option[:label].downcase }
    else
      party_options = []
    end
  else
    party_options = []
  end
  
  morph '#party-dropdown-party-games', render(partial: 'shared/party_dropdown_options', locals: { parties: party_options })
end
```

### 4. JavaScript Updates

```javascript
// app/javascript/controllers/filter_popup_controller.js
// Update the reference field detection:

const isReferenceField = ['region_shortname', 'season_name', 'club_shortname', 'league_shortname', 'party_shortname'].includes(name)

// Update the ID field mapping:
let idFieldName
if (name === 'region_shortname') {
  idFieldName = 'region_id'
} else if (name === 'club_shortname') {
  idFieldName = 'club_id'
} else if (name === 'season_name') {
  idFieldName = 'season_id'
} else if (name === 'league_shortname') {
  idFieldName = 'league_id'
} else if (name === 'party_shortname') {
  idFieldName = 'party_id'
} else {
  idFieldName = name
}

// Update restoration logic:
if (currentPath.includes('/party_games')) {
  reflexName = 'change->FilterPopupReflex#filter_seasons_by_region_for_party_games'
}

// Add cascading restoration for PartyGame:
if (seasonId) {
  console.log('Restoring season selection')
  this.restoreSelectValue('season_name', seasonId, 'season_id')
  
  // Wait for season to trigger league update, then restore league
  setTimeout(() => {
    if (leagueId) {
      console.log('Restoring league selection')
      this.restoreSelectValue('league_shortname', leagueId, 'league_id')
      
      // Wait for league to trigger party update, then restore party
      setTimeout(() => {
        if (partyId) {
          console.log('Restoring party selection')
          this.restoreSelectValue('party_shortname', partyId, 'party_id')
        }
      }, 300)
    }
  }, 300)
}
```

### 5. Required Partials

```erb
<!-- app/views/shared/_season_dropdown_options.html.erb -->
<option value="">Select Season</option>
<% seasons.each do |season| %>
  <option value="<%= season[:value] %>" <%= "data-id=\"#{season[:id]}\"".html_safe if season[:id].present? %>><%= season[:label] %></option>
<% end %>

<!-- app/views/shared/_party_dropdown_options.html.erb -->
<option value="">Select Party</option>
<% parties.each do |party| %>
  <option value="<%= party[:value] %>" <%= "data-id=\"#{party[:id]}\"".html_safe if party[:id].present? %>><%= party[:label] %></option>
<% end %>
```

## Key Implementation Notes

1. **Party Field Detection**: Must be detected as `select` before numeric field detection
2. **Party Value Mapping**: Use `party.id` as value instead of `day_seqno` to avoid duplicates
3. **Party Display Names**: Use `party.name` which shows league team names like "BC GT Buer 1 - BC Elversberg 1"
4. **ID Field Mapping**: Include `"party_id" => "parties.id"` in column_names for filtering
5. **Cascading Restoration**: Use `setTimeout` delays to ensure child dropdowns are populated before restoration
6. **Season Addition**: Season is the first dropdown after Region, populated with all seasons initially

This implementation provides a complete working example of cascading filters with meaningful display names and proper state restoration. 