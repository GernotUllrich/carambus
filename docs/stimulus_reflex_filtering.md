# Stimulus Reflex Dynamic Filtering

## Overview

The filter popup now uses Stimulus Reflex for dynamic filtering, providing a tight binding between server database and UI representation. This approach minimizes JavaScript and leverages server-side logic for complex queries.

## How It Works

### 1. User Interaction Flow

1. **User selects a region** from the Region dropdown
2. **Stimulus Reflex triggers** automatically via `change->FilterPopupReflex#filter_clubs_by_region`
3. **Server-side query** fetches clubs for the selected region
4. **UI updates** via morphing the club dropdown with new options
5. **User can select** from the filtered club list

### 2. Technical Implementation

#### Stimulus Reflex Class
```ruby
class FilterPopupReflex < ApplicationReflex
  def filter_clubs_by_region
    region_shortname = element.value
    
    if region_shortname.present?
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .where(regions: { shortname: region_shortname })
                  .order(:shortname)
                  .limit(100)
      # ... process clubs and morph UI
    end
  end
end
```

#### Data Attributes
The region field includes:
- `data-action="change->filter-popup#saveRecentSelection"` - Save selection
- `data-reflex="change->FilterPopupReflex#filter_clubs_by_region"` - Trigger reflex

The club field includes:
- `id="club-dropdown"` - Target for morphing
- `data-action="change->filter-popup#saveRecentSelection"` - Save selection

### 3. Benefits

✅ **Server-side logic** - Complex queries handled on server  
✅ **Tight database binding** - Direct database queries  
✅ **Minimal JavaScript** - Leverages existing Stimulus Reflex patterns  
✅ **Consistent with app** - Uses same patterns as other parts of app  
✅ **Easy to maintain** - Ruby logic instead of JavaScript  

### 4. Example Usage

1. **Open filter popup** on clubs page
2. **Select "NBV"** from Region dropdown
3. **Reflex triggers automatically** and fetches NBV clubs
4. **Club dropdown updates** to show only NBV clubs
5. **Select desired club** from filtered list

### 5. Code Structure

#### Files
- `app/reflexes/filter_popup_reflex.rb` - Reflex logic
- `app/views/shared/_club_dropdown_options.html.erb` - Partial for morphing
- `app/helpers/application_helper.rb` - Data attributes setup
- `app/javascript/controllers/filter_popup_controller.js` - Minimal JS

#### Key Methods
- `FilterPopupReflex#filter_clubs_by_region` - Main filtering logic
- `FilterPopupReflex#save_recent_selection` - Recent selections
- `render_select_input` - Helper for data attributes

### 6. Extensibility

This approach can be easily extended for other models:

```ruby
# Example for Players model
def filter_players_by_club
  club_id = element.value
  players = Player.where(club_id: club_id).order(:lastname)
  morph '#player-dropdown', render(partial: 'shared/player_dropdown_options', locals: { players: players })
end
```

### 7. Configuration via COLUMN_NAMES

The system can be made more generic by extending the `COLUMN_NAMES` specification:

```ruby
COLUMN_NAMES = {
  "Region" => "regions.shortname",
  "Club" => "clubs.shortname",
  "Player" => "players.lastname"
}.freeze

# Could be extended to:
COLUMN_NAMES = {
  "Region" => { column: "regions.shortname", filter_type: "region" },
  "Club" => { column: "clubs.shortname", filter_type: "club", depends_on: "region" },
  "Player" => { column: "players.lastname", filter_type: "player", depends_on: "club" }
}.freeze
```

This would allow automatic generation of dynamic filtering for any model based on the COLUMN_NAMES specification.

## Testing

### Manual Testing
1. Visit `/clubs` page
2. Click filter button
3. Select different regions and verify club dropdown updates
4. Check browser network tab to see reflex calls

### Server Logs
Look for reflex calls in the logs:
```
FilterPopupReflex#filter_clubs_by_region
```

This approach provides a much more robust and maintainable solution for dynamic filtering while keeping the tight binding between server and UI that you prefer. 