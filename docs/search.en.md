# Search and Filters in Carambus

## Overview

The search and filter function in Carambus enables quick and precise data discovery on all index pages. The system combines:
- **Free-text search** for quick finding
- **Structured filters** for precise queries
- **AND logic** for combined searches
- **Info tooltips** for easy operation

## Main Search Field

### Free-text Search with AND Logic
Enter one or more terms in the main search field. All terms are connected with **AND**.

**Examples:**
```
"Manfred Meyer" → finds entries containing BOTH terms
"Meyer Berlin" → finds all Meyers in Berlin
"Hamburg 2024" → finds Hamburg-related entries from 2024
```

**Important:** The **order doesn't matter!**
- "Manfred Meyer" = "Meyer Manfred" (same result)

### Search Areas (context-dependent)

#### Player Search
Searches in:
- Full name (first and last name combined)
- First name
- Last name
- Nickname
- CC-ID (numeric)

#### Club Search
Searches in:
- Club name (full and short name)
- Address
- Email
- Homepage
- Region (via relationship)
- CC-ID, BA-ID (numeric)

#### Tournament Search
Searches in:
- Tournament title
- Short name
- Season
- Region/Organizer

### Intelligent Relationships
The search automatically uses relationships between tables:
- **Players** → finds via Club → Region
- **Locations** → finds via Club → Region
- **Tournaments** → finds via Season, Region, Discipline

## Filter Form

### Opening the Filter Icon
Click the **filter icon** (⚙️) to the right of the search field to open the filter form.

### Structure of the Filter Form

#### 1. General Search
Free-text search across all relevant fields (like the main search field).

#### 2. Field-specific Filters
Each field has its own filter with:
- **Info icon** (ℹ️) - Shows description and examples on hover
- **Appropriate input type:**
  - **Dropdowns** for references (Region, Club, Season, etc.)
  - **Number fields** for IDs and numeric values
  - **Text fields** for names, addresses, etc.
  - **Date picker** for date fields (touch-optimized)

### Understanding Info Tooltips

Hover over an **info icon** (ℹ️) to see:
- **Description** of the field
- **Example values** for input

**Example tooltip:**
```
Numeric ID | Examples: 12345, 67890
```

### Combined Search

#### Combining Free-text + Field Filters
You can use **both search types simultaneously**:

**Enter in main search field:**
```
Meyer region_id:1
```
Finds: All "Meyer" in Region 1

**Or in filter form:**
- General search: `Meyer`
- Region: Select `NBV`
- Click "Apply"

Both ways lead to the same result!

### Condition Linking
All conditions are **AND-linked**:
- Free-text terms with each other (AND)
- Field filters with each other (AND)
- Free-text + field filters (AND)

## Field-specific Filter Syntax

### Syntax in Main Search Field
Format: `fieldname:value`

**Examples:**
```
region_id:1           → Region with ID 1
cc_id:12345          → CC-ID 12345
firstname:Hans       → First name "Hans"
date:>2024-01-01     → Date after January 1, 2024
```

### Combining Multiple Filters
Separate filters with **spaces**:
```
Meyer region_id:1 season_id:5
```
Finds: All "Meyer" in Region 1 AND Season 5

### Operators

#### Date Filters
```
date:2024-01-15      → Exactly this date
date:>2024-01-01     → After this date
date:>=2024-01-01    → From this date (incl.)
date:<2024-12-31     → Before this date
date:<=2024-12-31    → Until this date (incl.)
date:heute           → Today (converted to current date)
```

#### Number Filters
```
cc_id:12345          → Exactly this ID
points:>100          → More than 100 points
innings:<=50         → Up to 50 innings
```

#### Text Filters
```
firstname:Hans       → First name contains "Hans"
club:Berlin          → Club contains "Berlin"
```

### Field Name Reference

The most important field names for filters:

**General:**
- `id` - Record ID
- `region_id` - Region ID
- `season_id` - Season ID
- `club_id` - Club ID

**IDs:**
- `cc_id` - ClubCloud ID
- `ba_id` - Billard-Amateure ID
- `dbu_id` - DBU number

**Names:**
- `firstname` - First name
- `lastname` - Last name
- `nickname` - Nickname
- `name` - Name (general)

**Date:**
- `date` - Date (tournament, party, etc.)

## Practical Examples

### Player Search

**Simple search:**
```
Müller               → All players with "Müller" in name
Manfred Meyer        → Players with "Manfred" AND "Meyer" (AND logic)
Meyer Manfred        → Same result (order doesn't matter!)
```

**With field filters:**
```
Meyer region_id:1    → All Meyers in Region 1 (NBV)
Hans club_id:347     → All Hans in Club 347
cc_id:12345         → Player with CC-ID 12345
```

**Using filter form:**
1. Click filter icon
2. Region: Select "NBV"
3. Firstname: Enter "Hans"
4. Click "Apply"

### Club Search

**Simple search:**
```
Hamburg              → All clubs in/with "Hamburg"
Berlin Billard       → Clubs with "Berlin" AND "Billard"
```

**With field filters:**
```
region_id:1          → All clubs in Region 1
Hamburg region_id:1  → Hamburg clubs in Region 1
homepage:billard     → Clubs with "billard" in homepage URL
```

### Tournament Search

**Simple search:**
```
Stadtmeisterschaft   → All city championships
Pokal 2024          → Cup tournaments from 2024
```

**With field filters:**
```
season_id:5          → Tournaments of Season 5
Pokal region_id:1    → Cup tournaments in Region 1
date:>2024-01-01    → Tournaments after January 1, 2024
```

**In filter form:**
1. Click filter icon
2. Season: Select
3. Discipline: Select
4. Date: Use date picker
5. Click "Apply"

### Party (Match Days) Search

**With cascading filters:**
```
region_id:1          → Match days in Region 1
Liga region_id:1     → League match days in Region 1
```

**In filter form (cascading):**
1. Select Region → Season list is filtered
2. Select Season → League list is filtered
3. Select League → Party list is filtered

### PartyGame (Match Day Games) Search

**Complex search:**
```
Meyer                → All games with player "Meyer"
Meyer region_id:1    → Meyer games in Region 1
Liga 1 Meyer         → Meyer in League 1
```

## Search Tips & Best Practices

### Effective Search
1. **Start simple** - One term is often enough
   ```
   Meyer    → finds all Meyers
   ```

2. **Refine with AND** - Add more terms
   ```
   Meyer Hans    → only Hans Meyers
   ```

3. **Use field filters** - For precise queries
   ```
   Meyer region_id:1    → Meyers in specific region
   ```

4. **Combine everything** - Free-text + multiple filters
   ```
   Hans Berlin region_id:1 club_id:347
   ```

5. **Use info icons** - Hover over ℹ️ for help and examples

### Touch Operation

#### On Tablets/Smartphones:
1. **Dropdowns** - Large touch targets for references
2. **Date picker** - Native OS picker (iOS/Android)
3. **Filter form** - Scrollable with many fields
4. **Without keyboard** - Most filters operable by touch

### Avoiding Common Mistakes

❌ **Wrong:** Too many filters at once
```
Meyer Hans Berlin NBV 2024 Club
```
→ Probably finds nothing

✅ **Right:** Refine step by step
```
Step 1: Meyer        → 500 results
Step 2: Meyer Hans   → 50 results  
Step 3: Meyer Hans region_id:1  → 5 results
```

❌ **Wrong:** Searching exact phrase (no longer works)
```
"Hans Meyer"    (with quotes)
```

✅ **Right:** Simply enter terms
```
Hans Meyer      (without quotes, AND logic)
```

## Advanced Search Functions

### Automatic Partial Match Search
The search **automatically finds partial matches** - you don't need to enter the complete term.

**Examples:**
```
Ham      → finds "Hamburg", "Hamm", "Hamborn"
Mey      → finds "Meyer", "Meyerhofer", "Meyers"
```

### Case Sensitivity
The search is **case-insensitive**:
```
hamburg = Hamburg = HAMBURG    (same results)
meyer = Meyer = MEYER          (same results)
```

### Umlauts and Special Characters
Umlauts and special characters are handled correctly:
```
Müller = Müller    (exact search)
Straße = Straße    (ß is treated as ß)
```

### Cascading Filters (Dependent Filters)

Some filters automatically affect others:

#### Players, Locations, SeasonParticipation
```
Select Region → Club list shows only clubs of this region
```

#### Party, PartyGame
```
Select Region → Season list filtered
Select Season → League list filtered
Select League → Party list filtered
```

**Tip:** Use the filter form for cascading - dropdowns update automatically!

## Field Types in Filter Form

### Hidden Fields
Some technical fields (e.g., internal IDs) are **not displayed in the filter form**, 
but still work in the main search field:

**Examples of hidden fields:**
- `id` - Record ID (internal)
- `region_id` - Region ID (internal, use Region dropdown instead)
- `club_id` - Club ID (internal, use Club dropdown instead)

**Why hidden?**
- Simplifies UI (fewer fields)
- Only relevant fields visible
- Still works in main search field with `fieldname:value` syntax

### Visible Field Types

#### 1. Reference Fields (Dropdowns)
**Examples:** Region, Club, Season, League, Discipline

**Usage:**
- In filter form: Dropdown list for selection
- In main search field: Use ID variant (`region_id:1`)

#### 2. Number Fields
**Examples:** CC_ID, BA_ID, DBU_ID, Points, Result, Innings

**Usage:**
- In filter form: Operator dropdown + number input
- In main search field: `cc_id:12345` or `points:>100`

#### 3. Text Fields
**Examples:** Firstname, Lastname, Name, Address, Email

**Usage:**
- In filter form: Text input
- In main search field: `firstname:Hans` or simply `Hans`

#### 4. Date Fields
**Examples:** Date, Created At, Updated At

**Usage:**
- In filter form: Native date picker (touch-optimized)
- In main search field: `date:2024-01-15` or `date:>2024-01-01`

## Technical Details

### Search Algorithm
- **AND logic** for multiple terms (all must match)
- **ILIKE** for case-insensitive partial match search
- **LEFT JOIN** for relationships between tables
- **DISTINCT** where needed (prevents duplicates)

### Performance
- **Database indexes** for fast ID searches
- **Eager loading** of associations (avoids N+1 queries)
- **Pagination** for large result sets
- **Optimized JOINs** for complex queries

## Troubleshooting

### No Results Found

**Possible causes:**

1. **Too restrictive filters**
   ```
   Problem: Meyer Hans Berlin region_id:1 club_id:347
   Solution: Remove some filters
   ```

2. **Typo**
   ```
   Problem: Mayer (wrong)
   Solution: Meyer (correct)
   ```

3. **Wrong Region/Season selected**
   - Solution: Reset filters and start fresh

4. **Cascading filter not updated**
   - Solution: Reload page (browser refresh)

### Unexpected Results

**Problem:** Too many hits
```
Example: Search "Meyer" finds 500 players
Solution: Refine with region_id:1 or firstname:Hans
```

**Problem:** Field filter doesn't work
```
Check: Is the field name correct? (see field name reference)
Tip: Use info icons (ℹ️) for correct syntax
```

### Resetting Filters

**In filter form:**
- Click the **"Reset"** button

**In main search field:**
- Manually delete the text
- Or: `Cmd+A` (select all) → `Delete`

## Keyboard Shortcuts

### Quick Access
- **Tab** - Switch between fields
- **Enter** - Apply filters / start search
- **Esc** - Close filter popup

### In Main Search Field
- **Enter** - Execute search
- **Cmd+A / Ctrl+A** - Select all
- **Backspace** - Delete search

## FAQ - Frequently Asked Questions

### Why can't I find "Manfred Meyer"?
✅ **Solution:** Make sure AND logic is enabled (standard since October 2024).
The search now finds entries containing BOTH terms.

### How does "Meyer region_id:1" work?
✅ This is **mixed search**: Free-text ("Meyer") + field filter ("region_id:1").
Both conditions are AND-linked.

### Why do I see fewer fields in the filter?
✅ **This is intentional!** Technical ID fields are now hidden to simplify the UI.
They still work in the main search field though.

### What do the info icons (ℹ️) mean?
✅ Hover over them to see description and examples.
Helps understand what values can be entered.

### How does cascading work?
✅ **Cascading filters** automatically filter dependent lists:
- Select Region → Club list shows only clubs of this region
- Select Season → League list shows only leagues of this season

## Model-specific Features

### Players (Player)
- Also searches combined names (`fl_name`)
- Region → Club cascading active
- CC_ID and DBU_ID as number fields

### Match Day Games (PartyGame)
- **Most complex cascading:** Region → Season → League → Party
- Player A and Player B separately searchable
- Many hidden ID fields (6 hidden, 8 visible)

### Tournament Participations (Seeding)
- Supports tournaments AND leagues (polymorphic)
- Complex JOINs for Season/Region
- Position and status filterable

### Games (GameParticipation)
- Many numeric filters (Points, Result, GD, HS, Innings)
- Operators for comparisons (>, <, =, >=, <=)
- Role filterable (home, guest, playera, playerb)

## Future Enhancements

Planned improvements:
- **Quick filter chips** above table ("My Region", "Current Season")
- **Saved filters** for frequently used combinations
- **Filter presets** ("Last 30 days", "My Players")
- **Export** of filtered results
- **Filter history** (recently used filters)

## Support

For search problems:
1. Check this documentation
2. Use info icons (ℹ️) in filter form
3. Contact the administrator

---

**Last update:** October 2024 (new filter architecture)
