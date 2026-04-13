# Frontend Migration to STI - TODO

## Issues from STI Migration

### 1. Controller Changes Required

**`app/controllers/international_controller.rb`:**
```ruby
# OLD:
@upcoming_tournaments = InternationalTournament.upcoming
@recent_videos = Video.recent.limit(12)  # ❌ Table deleted!
@recent_results = InternationalResult.includes(...)   # ❌ Table deleted!

# NEW:
@upcoming_tournaments = InternationalTournament.where('date >= ?', Date.today)
# Videos: TODO - needs clarification
# Results: Use GameParticipations instead of InternationalResult
```

**`app/controllers/international/tournaments_controller.rb`:**
```ruby
# OLD:
@tournaments = InternationalTournament.by_type(params[:type])  # ❌ Scope does not exist
@results = @tournament.international_results                   # ❌ Association deleted
@videos = @tournament.international_videos                     # ❌ Association deleted

# NEW:
@tournaments = InternationalTournament.where("data->>'tournament_type' = ?", params[:type])
@results = GameParticipation.joins(:game).where(games: { tournament_id: @tournament.id })
# Videos: TODO
```

### 2. View Changes Required

**All views in `app/views/international/`:**

| Old                                        | New                                       | Status |
|--------------------------------------------|-------------------------------------------|--------|
| `tournament.name`                          | `tournament.title`                        | ❌     |
| `tournament.location`                      | `tournament.location_text`                | ❌     |
| `tournament.start_date`                    | `tournament.date`                         | ❌     |
| `tournament.videos`                        | TBD                                       | ❌     |
| `tournament.international_results`         | `tournament.game_participations`          | ❌     |
| `tournament.international_participations`  | `tournament.seedings`                     | ❌     |

### 3. Model Helper Methods

**`InternationalTournament` needs:**
```ruby
# For view compatibility
def name
  title  # Alias
end

def location
  location_text  # Alias
end

def start_date
  date&.to_date  # Alias
end

def date_range
  return date.to_s unless end_date
  "#{date.strftime('%d %b')} - #{end_date.strftime('%d %b %Y')}"
end

def official_umb?
  json_data['umb_official'] == true
end

# Scopes for controller
scope :upcoming, -> { where('date >= ?', Date.today) }
scope :by_type, ->(type) { where("data->>'tournament_type' = ?", type) }
scope :official_umb, -> { where("data->>'umb_official' = ?", 'true') }
scope :in_year, ->(year) { where('EXTRACT(YEAR FROM date) = ?', year) }
```

### 4. Videos

**Problem:** The `international_videos` table was dropped!

**Options:**
a) Remove videos feature (for now)
b) Store videos in `data` JSONB
c) Separate `videos` table for all tournaments (international + national)

**Recommendation:** Option A - remove for now, rebuild better later

### 5. Results/Rankings

**OLD:** `InternationalResult` (separate table)
**NEW:** `GameParticipation` (like regular tournaments)

Views need to be updated to calculate rankings from GameParticipations.

## Migration Plan

### Phase 1: Extend InternationalTournament Model ✅
- Helper methods for view compatibility
- Scopes for controller

### Phase 2: Update Controllers
- `international_controller.rb`
- `international/tournaments_controller.rb`
- Temporarily remove videos features

### Phase 3: Update Views
- `tournament.name` → `tournament.title`
- `tournament.location` → `tournament.location_text`
- Comment out video sections
- Results from GameParticipations

### Phase 4: Check Routes
- Ensure routes are working

## Priority

1. **HIGH**: Model helper methods (view compatibility)
2. **MEDIUM**: Update controllers
3. **MEDIUM**: Update views (remove videos)
4. **LOW**: Re-implement videos (later)
