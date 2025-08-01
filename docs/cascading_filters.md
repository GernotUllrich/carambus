# Cascading Filters for Locations

## Overview

The Location index page now features cascading filters that provide a hierarchical filtering experience:

**Region → Club → Location Name**

## How It Works

### 1. User Interaction Flow

1. **User selects a region** from the Region dropdown
2. **Club dropdown updates** to show only clubs from that region
3. **User selects a club** from the filtered club list
4. **Location dropdown updates** to show only locations for that club
5. **User can select** from the filtered location list

### 2. Technical Implementation

#### Stimulus Reflex Methods
```ruby
class FilterPopupReflex < ApplicationReflex
  def filter_clubs_by_region_for_locations
    # Filters clubs based on selected region
    # Morphs #club-dropdown-locations
  end

  def filter_locations_by_club
    # Filters locations based on selected club
    # Morphs #location-dropdown
  end
end
```

#### Data Attributes
- **Region field**: `data-reflex="change->FilterPopupReflex#filter_clubs_by_region_for_locations"`
- **Club field**: `data-reflex="change->FilterPopupReflex#filter_locations_by_club"`
- **Location field**: Autocomplete with `/api/locations/autocomplete`

#### HTML IDs
- **Club dropdown (locations page)**: `#club-dropdown-locations`
- **Location dropdown**: `#location-dropdown`

### 3. Database Relationships

```
Region (1) ←→ (many) Club (many) ←→ (many) Location
```

- **Region → Club**: Direct relationship via `clubs.region_id`
- **Club → Location**: Many-to-many via `club_locations` join table

### 4. Benefits

✅ **Hierarchical filtering** - Logical progression from region to specific location  
✅ **Performance optimized** - Only loads relevant data at each step  
✅ **User-friendly** - Reduces overwhelming choice lists  
✅ **Consistent UX** - Same pattern as clubs page  
✅ **Server-side logic** - Tight database binding  

### 5. Example Usage

1. **Visit `/locations` page**
2. **Click filter button** to open popup
3. **Select "NBV"** from Region dropdown
4. **Club dropdown updates** to show only NBV clubs
5. **Select "Dessauer PBC"** from Club dropdown
6. **Location dropdown updates** to show only Dessauer PBC locations
7. **Select desired location** from filtered list

### 6. Code Structure

#### Files
- `app/reflexes/filter_popup_reflex.rb` - Cascading filter logic
- `app/views/shared/_location_dropdown_options.html.erb` - Location options partial
- `app/controllers/api/locations_controller.rb` - Location autocomplete API
- `app/helpers/application_helper.rb` - Field detection and rendering
- `app/models/location.rb` - Updated COLUMN_NAMES

#### Key Methods
- `FilterPopupReflex#filter_clubs_by_region_for_locations` - Region → Club filtering
- `FilterPopupReflex#filter_locations_by_club` - Club → Location filtering
- `detect_field_type_and_options` - Enhanced field detection
- `get_select_id` - Dynamic ID assignment

### 7. Extensibility

This pattern can be easily extended to other models with similar hierarchical relationships:

```ruby
# Example for Tournaments
Region → Club → Tournament

# Example for Players  
Region → Club → Player
```

### 8. Testing

#### Manual Testing
1. Visit `/locations` page
2. Test each step of the cascade
3. Verify dropdowns update correctly
4. Check browser network tab for reflex calls

#### Server Logs
Look for reflex calls:
```
FilterPopupReflex#filter_clubs_by_region_for_locations
FilterPopupReflex#filter_locations_by_club
```

This cascading filter system provides an intuitive and efficient way to navigate complex data relationships while maintaining the tight server-side binding you prefer. 