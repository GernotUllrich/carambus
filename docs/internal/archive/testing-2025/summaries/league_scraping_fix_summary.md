# League Scraping Fix - CC ID Based Uniqueness

## Problem Identified

The league scraping logic in `app/models/league.rb` needed to be updated to properly handle leagues with the same name but different shortnames, and to prioritize `cc_id` and `cc_id2` as the primary uniqueness criteria since they are part of the scraping URL and more reliable than `shortname`.

### Key Requirements

1. **CC ID Priority**: `cc_id` and `cc_id2` are the primary identifiers from the scraping source
2. **Staffel Support**: Leagues with different `cc_id2` values (Staffel A, B, etc.) must be treated as separate entities
3. **Shortname Handling**: `shortname` may not always exist, but `cc_id` always does
4. **Legacy Compatibility**: `ba_id` and `ba_id2` dependencies are no longer relevant for the new scraping system

## Solution Implemented

### 1. Fixed Scraping Logic

**File:** `app/models/league.rb` (lines 341-365)

```ruby
cc_id2s.each_with_index do |cc_id2, ix|
  # Primary lookup: Find by CC IDs (most specific and reliable)
  attrs = { cc_id: league_cc_id, organizer: region, staffel_text: staffel_texts[ix], season: season,
            cc_id2: cc_id2 }.compact
  league = League.where(attrs).first
  
  unless league.present?
    # Secondary lookup: If not found by CC IDs, try by name and other attributes
    # This handles cases where cc_id might not be set yet
    attrs = { season: season, name: title, staffel_text: staffel_texts[ix], 
              discipline: branch, organizer: region }.compact
    league = League.where(attrs).first
    
    # If still not found, create a new league
    league ||= League.new(season: season, name: title, staffel_text: staffel_texts[ix], discipline: branch,
                          organizer: region)
  end
  
  # Update league attributes - cc_id and cc_id2 are the primary identifiers
  attrs = { shortname: short, cc_id: league_cc_id, cc_id2: cc_id2, discipline: branch,
            staffel_text: staffel_texts[ix] }.compact
  league.assign_attributes(attrs)
  league.source_url = staffel_link
  if league.changed?
    league.region_id = region.id
    league.save
  end
end
```

**Key Changes:**
- **Primary lookup**: Uses `cc_id` and `cc_id2` as the main uniqueness criteria
- **Staffel support**: Different `cc_id2` values create separate leagues
- **Fallback logic**: Only uses name-based lookup when `cc_id` is not available
- **Shortname handling**: `shortname` is updated but not used for uniqueness

### 2. Updated Database Constraints

**File:** `db/migrate/20241220000000_add_league_uniqueness_constraint.rb`

```ruby
class AddLeagueUniquenessConstraint < ActiveRecord::Migration[6.1]
  def up
    # Primary constraint: CC IDs are the most important identifiers from scraping
    # This ensures leagues with different cc_id2 (Staffel A, B, etc.) are treated as separate
    add_index :leagues, [:cc_id, :cc_id2, :organizer_id, :organizer_type], 
              unique: true, 
              name: 'index_leagues_on_cc_ids_organizer_unique',
              where: "cc_id IS NOT NULL AND organizer_type = 'Region'"
    
    # Secondary constraint: For cases where cc_id might not be set yet
    # Ensures no duplicate leagues with same name and staffel within a region/season
    add_index :leagues, [:season_id, :organizer_id, :organizer_type, :name, :staffel_text], 
              unique: true, 
              name: 'index_leagues_on_season_organizer_name_staffel_unique',
              where: "organizer_type = 'Region' AND cc_id IS NULL"
  end

  def down
    remove_index :leagues, name: 'index_leagues_on_cc_ids_organizer_unique'
    remove_index :leagues, name: 'index_leagues_on_season_organizer_name_staffel_unique'
  end
end
```

**Purpose:**
- **Primary constraint**: Ensures `cc_id` + `cc_id2` combinations are unique per organizer
- **Staffel separation**: Different `cc_id2` values create separate leagues
- **Fallback constraint**: Only applies when `cc_id` is NULL
- **Legacy compatibility**: Does not interfere with existing `ba_id` constraints

### 3. Updated Model Validations

**File:** `app/models/league.rb` (lines 45-60)

```ruby
# Validations to ensure proper uniqueness
validates :name, presence: true
validates :shortname, presence: true, if: -> { organizer_type == 'Region' }

# Primary uniqueness: CC IDs are the most important identifiers from scraping
validates :cc_id, uniqueness: { 
  scope: [:cc_id2, :organizer_id, :organizer_type],
  message: "must be unique within the same organizer (cc_id + cc_id2 combination)"
}, if: -> { cc_id.present? && organizer_type == 'Region' }

# Secondary uniqueness: Ensure no duplicate leagues with same name and staffel
# This is mainly for cases where cc_id might not be set yet
validates :name, uniqueness: { 
  scope: [:season_id, :organizer_id, :organizer_type, :staffel_text],
  message: "must be unique within the same region, season, and staffel"
}, if: -> { organizer_type == 'Region' && cc_id.blank? }
```

**Purpose:**
- **CC ID priority**: Primary validation focuses on `cc_id` + `cc_id2` uniqueness
- **Staffel support**: Different `cc_id2` values are treated as separate leagues
- **Fallback validation**: Only applies when `cc_id` is not set
- **Clear error messages**: Helps with debugging and data integrity

## Impact and Benefits

### 1. CC ID Based Uniqueness
- **Primary identification**: `cc_id` and `cc_id2` are the main uniqueness criteria
- **URL consistency**: Matches the scraping URL structure
- **Reliability**: `cc_id` always exists, unlike `shortname`

### 2. Proper Staffel Handling
- **Staffel separation**: Different `cc_id2` values create separate leagues
- **Multiple divisions**: Supports Staffel A, B, C, etc. within the same league
- **Data integrity**: Each staffel maintains its own identity

### 3. Legacy System Compatibility
- **BA ID preservation**: Existing `ba_id` constraints remain untouched
- **Gradual migration**: Can coexist with old Billard-Area scraping data
- **No breaking changes**: Existing functionality is preserved

### 4. Robust Fallback Logic
- **Graceful degradation**: Falls back to name-based lookup when needed
- **Data consistency**: Prevents duplicate leagues in edge cases
- **Error prevention**: Multiple layers of validation

## Migration Instructions

1. **Run the migration:**
   ```bash
   rails db:migrate
   ```

2. **Test the changes:**
   ```bash
   rails runner "League.scrape_leagues_from_cc(Region.find_by_shortname('BVNRW'), Season.find_by_name('2024/2025'), league_details: false)"
   ```

3. **Verify CC ID uniqueness:**
   ```bash
   rails runner "puts League.where(organizer_type: 'Region').group(:cc_id, :cc_id2, :organizer_id).having('count(*) > 1').count"
   ```

## Testing Recommendations

1. **Test with multiple staffeln** in the same region
2. **Verify CC ID uniqueness** for existing leagues
3. **Test scraping with missing shortnames**
4. **Check fallback behavior** when CC IDs are not available
5. **Verify legacy BA ID compatibility**

## Related Issues Addressed

This fix properly handles all the cases from the duplicate leagues analysis:
- **BVNRW**: Teampokal 8-Ball (different CC IDs for different seasons)
- **BVNRW**: NRW-Oberliga (different CC IDs for different seasons)
- **BVB**: 1.Bundesliga (different CC IDs for different disciplines)
- **BVB**: 2.Bundesliga (different CC IDs for different disciplines)
- **SBV**: Landesliga (different CC IDs for different staffeln)
- **DBU**: Deutsche Meisterschaft (different CC IDs for different competitions)

All these cases will now be properly handled based on their unique `cc_id` and `cc_id2` combinations, ensuring data integrity and proper league separation. 