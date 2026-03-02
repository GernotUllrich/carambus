# Video Tagging - AND/OR Logic Implementation

## Overview

Erweiterte Tag-Filterung mit AND/OR-Logik für die Suche nach Videos mit mehreren Tags.

---

## Features

### 1. **OR-Logik (Standard)**
Videos mit **mindestens einem** der ausgewählten Tags werden angezeigt.

**Beispiel:**
```
Tags: jaspers, caudron
Mode: OR
Ergebnis: Videos mit jaspers ODER caudron (oder beide)
```

**URL:**
```
/international/videos?tags[]=jaspers&tags[]=caudron
/international/videos?tags[]=jaspers&tags[]=caudron&tag_mode=or
```

### 2. **AND-Logik (Neu)**
Nur Videos mit **allen** ausgewählten Tags werden angezeigt.

**Beispiel:**
```
Tags: jaspers, caudron
Mode: AND
Ergebnis: Nur Videos mit jaspers UND caudron gleichzeitig
```

**URL:**
```
/international/videos?tags[]=jaspers&tags[]=caudron&tag_mode=and
```

---

## Implementation

### Controller (`app/controllers/international/videos_controller.rb`)

```ruby
# Tag Filtering with OR/AND logic
if params[:tags].present?
  tags = params[:tags].is_a?(Array) ? params[:tags] : [params[:tags]]
  tags = tags.compact.reject(&:blank?)
  
  if tags.any?
    if params[:tag_mode] == 'and'
      @videos = @videos.with_all_tags(tags)  # AND
    else
      @videos = @videos.with_any_tag(tags)   # OR (default)
    end
  end
end
```

### Scopes (`app/models/video.rb`)

```ruby
# Already implemented:
scope :with_any_tag, ->(tags) { 
  where("videos.data->'tags' ?| ARRAY[:tags]::text[]", tags: tags) 
}

scope :with_all_tags, ->(tags) { 
  where("videos.data->'tags' ?& ARRAY[:tags]::text[]", tags: tags) 
}
```

### View Components

**1. Advanced Tag Filter** (`_advanced_tag_filter.html.erb`)
- Collapsible advanced filter section
- Radio buttons for AND/OR mode selection
- Checkboxes for multi-select tags
- Country filter for players
- Visual feedback for selected tags

**2. Tag Filter** (`_tag_filter.html.erb`)
- Simple click-based filter (existing)
- Quick filtering for single tags

---

## UI/UX

### Advanced Filter Section

```
┌─────────────────────────────────────────────┐
│ ⚙️ Advanced Tag Filter            [Show ▼] │
├─────────────────────────────────────────────┤
│ Match: ○ ANY selected tags (OR)             │
│        ● ALL selected tags (AND)             │
├─────────────────────────────────────────────┤
│ Selected Tags (2): [jaspers ×] [caudron ×]  │
├─────────────────────────────────────────────┤
│ 🎬 Content Type                             │
│   □ Full Game  □ Shot of Day  □ High Run   │
├─────────────────────────────────────────────┤
│ ⭐ Top Players                              │
│   Filter: [All] [KR] [NL] [TR] [BE]...      │
│   □ #1 CHO  ☑ #2 JASPERS  ☑ #18 CAUDRON    │
├─────────────────────────────────────────────┤
│ 🎥 Quality                                   │
│   □ HD  □ 4K  □ Slow Motion                │
├─────────────────────────────────────────────┤
│ Will show videos with ALL 2 selected tags   │
│                             [Apply Filter]   │
└─────────────────────────────────────────────┘
```

---

## Use Cases

### Use Case 1: Find specific player matchup
**Goal:** Videos with BOTH Jaspers AND Caudron

**Steps:**
1. Click "Show" on Advanced Tag Filter
2. Select "ALL selected tags (AND)"
3. Check "JASPERS"
4. Check "CAUDRON"
5. Click "Apply Filter"

**Result:** Only videos featuring both players (e.g., Jaspers vs Caudron matches)

### Use Case 2: Find videos with any top player
**Goal:** Videos with Jaspers OR Zanetti OR Merckx

**Steps:**
1. Click "Show" on Advanced Tag Filter
2. Select "ANY selected tags (OR)" (default)
3. Check "JASPERS", "ZANETTI", "MERCKX"
4. Click "Apply Filter"

**Result:** All videos featuring at least one of these players

### Use Case 3: Find HD full games with specific player
**Goal:** Full Game videos in HD featuring Jaspers

**Steps:**
1. Select "ALL selected tags (AND)"
2. Check "Full Game"
3. Check "HD"
4. Check "JASPERS"
5. Click "Apply Filter"

**Result:** Only HD full game videos featuring Jaspers

---

## Query Examples

### Example 1: Jaspers OR Caudron
```
GET /international/videos?tags[]=jaspers&tags[]=caudron&tag_mode=or
```

**SQL (simplified):**
```sql
WHERE videos.data->'tags' ?| ARRAY['jaspers', 'caudron']
-- Returns videos with jaspers OR caudron
```

### Example 2: Jaspers AND Caudron
```
GET /international/videos?tags[]=jaspers&tags[]=caudron&tag_mode=and
```

**SQL (simplified):**
```sql
WHERE videos.data->'tags' ?& ARRAY['jaspers', 'caudron']
-- Returns videos with BOTH jaspers AND caudron
```

### Example 3: Full Game AND HD AND Jaspers
```
GET /international/videos?tags[]=full_game&tags[]=hd&tags[]=jaspers&tag_mode=and
```

**SQL (simplified):**
```sql
WHERE videos.data->'tags' ?& ARRAY['full_game', 'hd', 'jaspers']
-- Returns videos with ALL three tags
```

---

## Statistics

Based on current data:

```ruby
# Videos with multiple player tags
Video.where("jsonb_array_length(videos.data->'tags') >= 2").count
# => ~604 videos

# Example: Videos with BOTH Jaspers AND Caudron
Video.with_all_tags(['jaspers', 'caudron']).count
# => ~XX videos

# Example: Videos with Jaspers OR Caudron
Video.with_any_tag(['jaspers', 'caudron']).count
# => ~XXX videos
```

---

## Testing

### Manual Testing

1. **Test OR-Logic:**
   - URL: `/international/videos?tags[]=jaspers&tags[]=caudron`
   - Expected: Videos with jaspers OR caudron
   - Verify: Results include videos with only jaspers, only caudron, or both

2. **Test AND-Logic:**
   - URL: `/international/videos?tags[]=jaspers&tags[]=caudron&tag_mode=and`
   - Expected: Videos with BOTH jaspers AND caudron
   - Verify: All results have both tags

3. **Test Multiple Tags (3+):**
   - URL: `/international/videos?tags[]=full_game&tags[]=jaspers&tags[]=hd&tag_mode=and`
   - Expected: HD full games with Jaspers
   - Verify: All results have all 3 tags

### Console Testing

```ruby
# Test AND logic
jaspers_and_caudron = Video.with_all_tags(['jaspers', 'caudron'])
puts "Videos with BOTH: #{jaspers_and_caudron.count}"

# Test OR logic
jaspers_or_caudron = Video.with_any_tag(['jaspers', 'caudron'])
puts "Videos with ANY: #{jaspers_or_caudron.count}"

# Verify results
jaspers_and_caudron.first(5).each do |video|
  puts "#{video.title} - Tags: #{video.tags.join(', ')}"
end
```

---

## Future Enhancements

### 1. Save Filter Presets
Allow users to save common filter combinations:
```ruby
# Example preset
{
  name: "Jaspers vs Caudron Full Games",
  tags: ['jaspers', 'caudron', 'full_game'],
  tag_mode: 'and'
}
```

### 2. Tag Suggestions
Show related tags based on current selection:
```
Selected: jaspers
Suggestions: caudron (often together), merckx (often together)
```

### 3. Tag Statistics in UI
Show video counts for each tag combination:
```
☑ JASPERS (245 videos)
☑ CAUDRON (198 videos)
→ Both together: 23 videos
```

### 4. Quick Filters
Pre-defined filter buttons:
```
[Jaspers vs Caudron] [Merckx Games] [Belgian Final]
```

---

## Summary

✅ **Implemented:**
- AND/OR logic for tag filtering
- Advanced multi-select UI
- Country-based player filtering
- Visual feedback for selected tags

✅ **URLs:**
- OR: `/international/videos?tags[]=a&tags[]=b`
- AND: `/international/videos?tags[]=a&tags[]=b&tag_mode=and`

✅ **Scopes:**
- `with_any_tag(tags)` - OR logic
- `with_all_tags(tags)` - AND logic

🎯 **Result:** Users can now find videos with specific player matchups (e.g., Jaspers vs Caudron) using AND-logic!
