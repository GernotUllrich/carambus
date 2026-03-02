# Video Tagging Frontend - Complete Implementation ✅

## Übersicht

Frontend-Integration des Video-Tagging-Systems mit hierarchischen Filtern und interaktiven Tag-Badges.

---

## Implementierte Features

### 1. Controller: `International::VideosController`

#### Tag-Filterung

```ruby
# Single tag filter
GET /international/videos?tag=full_game

# Multiple tags (OR logic)
GET /international/videos?tags[]=jaspers&tags[]=zanetti

# Tag group filter (e.g., all Korean players)
GET /international/videos?tag_group=player_country&tag_group_value=KR
```

#### Neue Methoden

```ruby
def index
  # Tag filtering
  @videos = @videos.with_tag(params[:tag]) if params[:tag].present?
  @videos = @videos.with_any_tag(params[:tags]) if params[:tags].present?
  
  # Tag statistics for filter UI
  @tag_counts = calculate_tag_counts
end

private

def calculate_tag_counts
  # Returns: { content_types: {...}, players: {...}, quality: {...} }
end
```

---

### 2. Views

#### A) Index View (`app/views/international/videos/index.html.erb`)

**Hinzugefügt:**
- Tag-Filter unter den Standard-Filtern
- Tag-Badges auf Video-Karten
- Tag-Count-Badges für aktive Filter

**Struktur:**
```erb
<!-- Search & Basic Filters -->
<div class="filters">...</div>

<!-- NEW: Tag Filter -->
<%= render 'tag_filter' %>

<!-- Video Grid with Tags -->
<% @videos.each do |video| %>
  <%= render 'video_tags', video: video, limit: 3 %>
<% end %>
```

#### B) Show View (`app/views/international/videos/show.html.erb`)

**Hinzugefügt:**
- Tag-Badge-Sektion oben
- Suggested Tags Sektion (Auto-Detection-Vorschläge)

**Features:**
```erb
<!-- Video Tags -->
<%= render 'video_tags', video: @video, limit: 10, show_icon: true %>

<!-- Suggested Tags (Auto-Detected) -->
<% if @video.suggested_tags.any? %>
  <div class="suggested-tags">...</div>
<% end %>
```

---

### 3. Partials

#### A) Tag Filter (`_tag_filter.html.erb`)

**Features:**
- ✅ Hierarchische Tag-Gruppen (Content Type, Players, Quality)
- ✅ Tag-Counts mit Badge-Anzeige
- ✅ Active Filter Display mit "Clear All" Button
- ✅ Player-Filter nach Ländern gruppiert
- ✅ "Show more" Button für > 20 Spieler
- ✅ Hover-Tooltips mit Player-Details (Name, Land, Rang)

**Struktur:**
```
┌─────────────────────────────────────┐
│ 🔖 Filter by Tags                   │
├─────────────────────────────────────┤
│ Active: [full_game ×] [jaspers ×]   │
├─────────────────────────────────────┤
│ 🎬 Content Type                     │
│   [Full Game (23)] [Shot Day (45)]  │
├─────────────────────────────────────┤
│ ⭐ Top Players                      │
│   By Country: [KR(6)] [NL(3)]...    │
│   [#1 CHO (5)] [#2 JASPERS (12)]... │
├─────────────────────────────────────┤
│ 🎥 Quality                          │
│   [HD (89)] [4K (12)]               │
└─────────────────────────────────────┘
```

**CSS Classes:**
- Active Tags: `ring-2 ring-offset-2 ring-blue-500`
- Counts: `bg-white bg-opacity-30` (on active) or `bg-gray-200`
- Hover: `hover:bg-gray-200`, `hover:opacity-80`

#### B) Video Tags (`_video_tags.html.erb`)

**Usage:**
```erb
<%= render 'international/videos/video_tags', 
    video: video,
    limit: 5,        # Max tags to show
    size: 'sm',      # 'xs', 'sm', 'md'
    show_icon: true, # Show emoji icons
    spacing: true    # Add top margin
%>
```

**Features:**
- Clickable tags (link to filtered view)
- "+N more" indicator when > limit
- Tooltip with all tags on "+N more"
- Emoji icons für Tag-Kategorien

**Output:**
```html
<div class="flex flex-wrap gap-1">
  <a href="/international/videos?tag=full_game" 
     class="badge bg-blue-100 text-blue-800">
    🎬 Full Game
  </a>
  <a href="/international/videos?tag=jaspers" 
     class="badge bg-gray-100 text-gray-800">
    ⭐ Jaspers
  </a>
  <span class="badge bg-gray-100" title="hd, training">
    +2 more
  </span>
</div>
```

---

## UI/UX Details

### Badge Colors (via `video_tag_badge_class` helper)

| Tag Type | CSS Classes |
|----------|-------------|
| `full_game` | `bg-blue-100 text-blue-800` |
| `shot_of_the_day` | `bg-yellow-100 text-yellow-800` |
| `high_run` | `bg-red-100 text-red-800` |
| `training` | `bg-green-100 text-green-800` |
| `highlights` | `bg-purple-100 text-purple-800` |
| `hd`, `4k` | `bg-indigo-100 text-indigo-800` |
| Default | `bg-gray-100 text-gray-800` |

### Active State Indicator

**Active Tags:**
```css
ring-2 ring-offset-2 ring-{color}-500
```

**Visual:**
```
┌─────────────────┐
│  [Full Game]  ◄─── Normal
└─────────────────┘

┌─────────────────┐
│║ [Full Game] ║   ◄─── Active (with ring)
└─────────────────┘
```

### Responsive Behavior

**Mobile (< 768px):**
- Tag filter collapsible
- Show top 10 players only (initially)
- Country filter horizontal scroll

**Desktop:**
- Tag filter always visible
- Show top 20 players
- Grid layout for player tags

---

## Filter URLs & Query Params

### Single Tag Filter

```
/international/videos?tag=full_game
```

### Multiple Tags (OR)

```
/international/videos?tags[]=jaspers&tags[]=zanetti
# Shows videos tagged with jaspers OR zanetti
```

### Combined Filters

```
/international/videos?discipline_id=3&tag=full_game&search=world+cup
# Shows: 3-Cushion + Full Game + Contains "world cup"
```

### Tag Group Filter

```
# All Korean players
/international/videos?tag_group=player_country&tag_group_value=KR

# Shows videos with any Korean player tag (cho, kim, heo, etc.)
```

---

## Performance Optimizations

### Tag Count Calculation

**Optimized Query:**
```ruby
Video.youtube
     .where("data->'tags' IS NOT NULL")
     .pluck(Arel.sql("jsonb_array_elements_text(data->'tags')"))
```

**Caching (Future Enhancement):**
```ruby
# Cache tag counts for 5 minutes
Rails.cache.fetch('video_tag_counts', expires_in: 5.minutes) do
  calculate_tag_counts
end
```

### JSONB Index

**Migration (recommended for > 1000 videos):**
```ruby
add_index :videos, :data, 
          using: :gin, 
          opclass: :jsonb_path_ops,
          algorithm: :concurrently
```

---

## Testing

### Manual Testing Checklist

- [ ] Tag-Filter zeigt Counts korrekt an
- [ ] Single Tag Filter funktioniert
- [ ] Multiple Tag Filter (OR) funktioniert
- [ ] Active Tag wird mit Ring markiert
- [ ] "Clear All" entfernt alle Tag-Filter
- [ ] Tag-Badges sind klickbar
- [ ] "+N more" Tooltip zeigt alle Tags
- [ ] Player-Filter nach Land funktioniert
- [ ] "Show more players" Button funktioniert
- [ ] Suggested Tags werden auf Show-Seite angezeigt
- [ ] Kombinierte Filter (Discipline + Tag) funktionieren

### Browser Testing

- [ ] Chrome/Edge (Desktop)
- [ ] Firefox (Desktop)
- [ ] Safari (Desktop & Mobile)
- [ ] Chrome Mobile (Android)

---

## Zukünftige Erweiterungen

### 1. Multi-Select Filter (AND-Logic)

**UI:**
```
☑️ Full Game
☑️ HD
☐ Jaspers
──────────────
[Apply Filters]
```

**Query:**
```ruby
Video.with_all_tags(['full_game', 'hd'])
# Shows only videos with BOTH tags
```

### 2. Tag Auto-Complete in Search

```html
<input type="text" 
       placeholder="Search or select tags..."
       data-autocomplete="tags">
```

### 3. Tag Cloud Visualization

```
             JASPERS
    full_game        ZANETTI
       HD    high_run    CHO
    training  4K    HORN
```

Size = Häufigkeit

### 4. Saved Filter Presets

```
My Filters:
- ⭐ Favorite Players: jaspers, zanetti, horn
- 🎬 Full HD Games: full_game, hd
- 🔥 Best Shots: shot_of_the_day, high_run
```

### 5. Admin: Bulk Tag Management

```
Select Videos: [ ] All on page
Tags to Add: [________________]
Tags to Remove: [________________]
[Apply to Selection]
```

---

## Troubleshooting

### Tags werden nicht angezeigt

**Check:**
1. Video hat Tags in `data` JSONB: `video.tags`
2. Helper `video_tag_badge_class` ist verfügbar
3. Partial `_video_tags.html.erb` existiert

### Tag-Counts sind falsch

**Fix:**
```ruby
# Controller
@tag_counts = calculate_tag_counts

# Verify in console
Video.youtube.where("data->'tags' IS NOT NULL").count
```

### Filter funktioniert nicht

**Check:**
1. Scope `with_tag` ist im Video Model definiert
2. JSONB Operator `@>` funktioniert (Postgres ≥ 9.4)
3. Query Params korrekt: `params[:tag]` oder `params[:tags]`

### Performance-Probleme bei vielen Videos

**Optimize:**
```ruby
# 1. Add GIN index (see above)
# 2. Cache tag counts
# 3. Limit player list to top 20
# 4. Paginate aggressively (items: 24)
```

---

## Zusammenfassung

✅ **Phase 2 Complete**: Frontend-Integration mit hierarchischem Tag-Filter

**Implementiert:**
- ✅ Controller mit Tag-Filterung und Statistics
- ✅ Tag-Filter Partial mit hierarchischer Struktur
- ✅ Video-Tags Partial für Badge-Anzeige
- ✅ Integration in Index & Show Views
- ✅ Active State Indicators
- ✅ Tag Counts mit Badges
- ✅ Player-Filter nach Ländern
- ✅ Suggested Tags Anzeige

**Verwendung:**
```
# Filter by tag
/international/videos?tag=full_game

# Show video with tags
@video.tags => ["full_game", "jaspers", "hd"]
```

**Next Steps:**
- Phase 3: Admin Interface für manuelles Tagging
- Phase 4: Bulk Auto-Tagging Job
