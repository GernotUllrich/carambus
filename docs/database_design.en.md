# Carambus API Database Design Documentation

## Core Models and Their Relationships

### Seeding Model - Dual Purpose Design
The `Seeding` model serves two distinct purposes in the system:

1. **Team Roster Management**
   - Connected to `LeagueTeam` via `league_team_id`
   - Used to maintain the full roster of players for a league team
   - Created during initial league/team setup and scraping
   - Example: `Seeding.where(league_team: league_team, player: player)`

2. **Match Participation Tracking**
   - Connected to `Party` via polymorphic `tournament_id` and `tournament_type`
   - Tracks which players participate in specific matches
   - Created when setting up individual matches
   - Example: `party.seedings.where("id > #{Game::MIN_ID}")`

```ruby
class Seeding < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :league_team, optional: true
  # ...
end
```

### Party and LeagueTeam Relationship
The relationship between `Party` and `LeagueTeam` is designed to handle match scheduling and team participation:

```ruby
class Party < ApplicationRecord
  belongs_to :league_team_a, class_name: "LeagueTeam"
  belongs_to :league_team_b, class_name: "LeagueTeam"
  belongs_to :host_league_team, class_name: "LeagueTeam"
  belongs_to :no_show_team, class_name: "LeagueTeam"
  has_many :seedings, as: :tournament
  # ...
end

class LeagueTeam < ApplicationRecord
  has_many :parties_a, class_name: "Party", foreign_key: :league_team_a_id
  has_many :parties_b, class_name: "Party", foreign_key: :league_team_b_id
  has_many :parties_as_host, class_name: "Party", foreign_key: :host_league_team_id
  has_many :no_show_parties, class_name: "Party", foreign_key: :no_show_team_id
  has_many :seedings
  # ...
end
```

## Data Storage Patterns

### Flexible Data Storage
Several models use serialized columns for flexible data storage:

1. **JSON Serialization**
   ```ruby
   serialize :data, coder: JSON, type: Hash
   ```
   Used in:
   - `Party` - Stores match-specific data
   - `Seeding` - Stores player results and rankings
   - `LeagueTeam` - Stores team-specific metadata

2. **YAML Serialization**
   ```ruby
   serialize :remarks, coder: YAML, type: Hash
   ```
   Used in:
   - `Party` - Stores match remarks and notes

### Region Tagging System
The `RegionTaggable` concern provides intelligent region handling:

```ruby
# Example from RegionTaggable
when Seeding
  if tournament_id.present?
    # Handle tournament-based region tagging
    tournament ? [
      tournament.region_id,
      (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  elsif league_team_id.present?
    # Handle league team-based region tagging
    league_team&.league ? [
      (league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  end
```

## Data Protection and Synchronization

### Local Protection
The `LocalProtector` concern is used to protect local data from external modifications:

```ruby
class Party < ApplicationRecord
  include LocalProtector
  # ...
end

class LeagueTeam < ApplicationRecord
  include LocalProtector
  # ...
end

class Seeding < ApplicationRecord
  include LocalProtector
  # ...
end
```

### Source Handling
The `SourceHandler` concern manages external data synchronization:

```ruby
class Party < ApplicationRecord
  include SourceHandler
  # ...
end

class LeagueTeam < ApplicationRecord
  include SourceHandler
  # ...
end
```

## Key Workflows

### Team Setup and Match Creation
1. League teams are created with their base roster (seedings with `league_team_id`)
2. When a match is created:
   - A new `Party` is created linking two `LeagueTeam`s
   - Specific seedings are created for the match (with `tournament_id`)
   - These seedings track which players from the team roster participate in this match

### Data Synchronization
1. External data (from BA/CC) is synchronized through the `SourceHandler`
2. Local data is protected from external modifications via `LocalProtector`
3. Region tagging is automatically handled based on the context (tournament or league team)

## Important Notes for Developers

1. **Seeding Creation**
   - Always consider whether you're creating a team roster entry or a match participation entry
   - Use appropriate associations (`league_team_id` vs `tournament_id`)

2. **Data Protection**
   - Be aware of the `LocalProtector` when modifying records
   - Use `unprotected = true` when necessary for local modifications

3. **Region Handling**
   - Region tagging is automatic but context-dependent
   - Different logic applies for tournament-based vs league team-based seedings

4. **Data Storage**
   - Use the appropriate serialization (JSON vs YAML) for different types of data
   - Be aware of the structure of stored data in serialized columns

## Database Schema Highlights

### Seeding Model
```ruby
create_table "seedings" do |t|
  t.string "ba_state"
  t.integer "balls_goal"
  t.text "data"
  t.integer "position"
  t.integer "rank"
  t.string "role"
  t.string "state"
  t.string "tournament_type"
  t.integer "league_team_id"
  t.integer "player_id"
  t.integer "playing_discipline_id"
  t.integer "tournament_id"
  # ...
end
```

### Party Model
```ruby
create_table "parties" do |t|
  t.datetime "date"
  t.integer "league_id"
  t.text "remarks"
  t.integer "league_team_a_id"
  t.integer "league_team_b_id"
  t.integer "host_league_team_id"
  t.integer "no_show_team_id"
  t.text "data"
  # ... other fields ...
end
```

### LeagueTeam Model
```ruby
create_table "league_teams" do |t|
  t.string "name"
  t.string "shortname"
  t.integer "league_id"
  t.integer "ba_id"
  t.integer "cc_id"
  t.integer "club_id"
  t.text "data"
  # ... other fields ...
end
``` 