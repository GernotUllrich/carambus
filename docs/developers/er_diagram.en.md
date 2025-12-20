# ER Diagram of the Carambus Database

This document shows the Entity-Relationship diagram of the Carambus database structure.

## Overview

The ER diagram shows the relationships between the main entities in the Carambus system:
- **Regions** organize clubs, tournaments and leagues
- **Clubs** have locations and organize tournaments
- **Tournaments** are held at locations and belong to leagues
- **Leagues** have match days (parties) and teams
- **Match days** consist of games between teams
- **Games** are played by players

## Important Change: Player-Club Relationship

**⚠️ IMPORTANT**: The relationship between players and clubs has changed:
- **Historically**: Players belonged directly to a club (`Player.club_id`)
- **Currently**: Players belong to clubs through `SeasonParticipation`
- **Advantage**: A player can play for different clubs in different seasons

## Complete ER Diagram

```mermaid
erDiagram
    Region ||--o{ Club : "has many"
    Region ||--o{ Tournament : "organizes"
    Region ||--o{ League : "organizes"
    
    Club ||--o{ Location : "has many through club_locations"
    Club ||--o{ LeagueTeam : "has many"
    Club ||--o{ Tournament : "organizes"
    Club ||--o{ SeasonParticipation : "has many"
    
    Tournament ||--o{ Game : "has many"
    Tournament ||--o{ Seeding : "has many"
    Tournament ||--o{ Team : "has many"
    Tournament ||--o{ Location : "uses"
    Tournament ||--o{ League : "belongs to"
    
    League ||--o{ LeagueTeam : "has many"
    League ||--o{ Party : "has many"
    League ||--o{ Tournament : "has many"
    
    Party ||--o{ Game : "has many"
    Party ||--o{ PartyGame : "has many"
    Party ||--o{ Seeding : "has many"
    Party ||--o{ Location : "uses"
    Party ||--o{ LeagueTeam : "has teams"
    
    Location ||--o{ Party : "hosts"
    Location ||--o{ Tournament : "hosts"
    Location ||--o{ Club : "belongs to many"
    
    LeagueTeam ||--o{ Party : "participates in"
    LeagueTeam ||--o{ Seeding : "has many"
    
    Game ||--o{ GameParticipation : "has many"
    Game ||--o{ PartyGame : "has many"
    
    %% IMPORTANT: Player has N:M relationship to Club through SeasonParticipation
    Player ||--o{ SeasonParticipation : "has many"
    Player ||--o{ GameParticipation : "has many"
    Player ||--o{ Seeding : "has many"
    Player ||--o{ PartyGame : "plays in"
    
    %% SeasonParticipation connects Player, Club and Season (N:M:N)
    SeasonParticipation ||--o{ Player : "belongs to"
    SeasonParticipation ||--o{ Club : "belongs to"
    SeasonParticipation ||--o{ Season : "belongs to"
    
    Seeding ||--o{ Player : "belongs to"
    Seeding ||--o{ Tournament : "belongs to"
    Seeding ||--o{ LeagueTeam : "belongs to"
    Seeding ||--o{ Discipline : "has"

    PartyGame ||--o{ Party : "belongs to"
    PartyGame ||--o{ Player : "has players"
    PartyGame ||--o{ Discipline : "has"
    PartyGame ||--o{ Game : "belongs to"

    GameParticipation ||--o{ Game : "belongs to"
    GameParticipation ||--o{ Player : "belongs to"

    %% Entity definitions with their key attributes
    Region {
        int id PK
        string name
        string shortname
    }

    Club {
        int id PK
        string name
        string shortname
        int region_id FK
    }

    Tournament {
        int id PK
        string title
        int organizer_id FK
        string organizer_type
        int location_id FK
        int league_id FK
    }

    League {
        int id PK
        string name
        int organizer_id FK
        string organizer_type
    }

    Party {
        int id PK
        int league_id FK
        int location_id FK
        int league_team_a_id FK
        int league_team_b_id FK
    }

    Location {
        int id PK
        string name
        int club_id FK
    }

    LeagueTeam {
        int id PK
        int league_id FK
        int club_id FK
        string name
    }

    PartyGame {
        int id PK
        int party_id FK
        int player_id FK
        int discipline_id FK
        int game_id FK
    }

    Game {
        int id PK
        int tournament_id FK
        int party_id FK
        string status
        datetime start_time
        datetime end_time
    }

    GameParticipation {
        int id PK
        int game_id FK
        int player_id FK
        string role
        int score
    }

    Player {
        int id PK
        string name
        string email
        %% HISTORICAL: club_id (no longer used)
        %% int club_id FK
        %% CURRENT: Relationship through SeasonParticipation
    }

    Seeding {
        int id PK
        int tournament_id FK
        int player_id FK
        int league_team_id FK
        int discipline_id FK
        int position
    }

    SeasonParticipation {
        int id PK
        int season_id FK
        int player_id FK
        int club_id FK
        string status
        %% Status: "active", "passive", "guest"
    }

    Discipline {
        int id PK
        string name
        string description
    }
```

## Relationship Types

### 1:1 (One-to-One)
- **One player** has **one email address**
- **One game** has **one status**

### 1:N (One-to-Many)
- **One region** has **many clubs**
- **One club** has **many locations**
- **One tournament** has **many games**

### N:M (Many-to-Many)
- **Clubs** have **many locations** through `club_locations`
- **Players** play in **many games** through `game_participations`
- **Games** belong to **many match days** through `party_games`
- **⚠️ NEW: Players belong to many clubs** through `season_participations`

## Important Changes in the Data Model

### Player.club_id (HISTORICAL)
```ruby
# This relationship is NO LONGER used
class Player < ApplicationRecord
  # belongs_to :club  # DEPRECATED
  has_many :season_participations, dependent: :destroy
  has_many :clubs, through: :season_participations
end
```

### SeasonParticipation (CURRENT)
```ruby
# This relationship is CURRENTLY used
class SeasonParticipation < ApplicationRecord
  belongs_to :season
  belongs_to :player
  belongs_to :club
  
  # Status: "active", "passive", "guest"
  validates :status, presence: true
end
```

### Advantages of the New Structure
1. **Flexibility**: Players can play for different clubs in different seasons
2. **Historical Data**: Complete history of club memberships
3. **Status Management**: Different statuses (active, passive, guest)
4. **Season-based Management**: Clear separation by seasons

## Key Attributes

### Primary Keys (PK)
- `id`: Unique identification of each entity
- Auto-increment integer values

### Foreign Keys (FK)
- `region_id`: Reference to the parent region
- `club_id`: Reference to the associated club (in SeasonParticipation)
- `tournament_id`: Reference to the tournament
- `league_id`: Reference to the league
- `location_id`: Reference to the location
- `player_id`: Reference to the player

## Data Integrity

### Referential Integrity
- All foreign keys reference valid primary keys
- CASCADE deletions for dependent records
- RESTRICT deletions for critical relationships

### Business Rules
- **⚠️ CHANGED**: A player can play for different clubs in different seasons
- A tournament can only take place at one location
- A match day belongs to exactly one league

## Migration from the Old Structure

### Old Structure (DEPRECATED)
```ruby
# This relationship is NO LONGER used
Player.find(1).club  # Direct club membership
```

### New Structure (CURRENT)
```ruby
# This relationship is CURRENTLY used
player = Player.find(1)

# Current club (last active SeasonParticipation)
player.club  # Method in Player model

# All club memberships
player.season_participations.includes(:club, :season)

# Club in specific season
player.season_participations.find_by(season: current_season)&.club
```

## Extended Relationships

### Polymorphic Relationships
```ruby
# Tournament can be organized by Region or Club
belongs_to :organizer, polymorphic: true

# Usage
tournament.organizer_type # "Region" or "Club"
tournament.organizer_id   # ID of the organizing entity
```

### Junction Tables
```ruby
# club_locations connects Clubs and Locations
class ClubLocation < ApplicationRecord
  belongs_to :club
  belongs_to :location
end

# season_participations connects Players, Clubs and Seasons
class SeasonParticipation < ApplicationRecord
  belongs_to :season
  belongs_to :player
  belongs_to :club
end
```

## Performance Optimizations

### Indexes
- All foreign keys are indexed
- Composite indexes for frequent queries
- Unique indexes for business rules
- **⚠️ NEW**: `index_season_participations_on_foreign_keys` for (player_id, club_id, season_id)

### Query Optimization
- Eager Loading to avoid N+1 problem
- Scopes for frequent filters
- Counter Caches for counts
- **⚠️ NEW**: Optimized queries through SeasonParticipation

## Data Model Changes

### Migrations
```bash
# Create new table
rails generate migration CreateNewTable

# Add column
rails generate migration AddColumnToTable

# Run migration
rails db:migrate
```

### Rollback
```bash
# Undo last migration
rails db:rollback

# Go back to specific version
rails db:migrate VERSION=20231201000000
```

## Monitoring and Maintenance

### Database Size
- Regular checking of table sizes
- Archiving old data
- Cleanup of deleted records

### Performance Monitoring
- Identify slow queries
- Optimize indexes
- Analyze query plans
- **⚠️ NEW**: Monitor SeasonParticipation queries

## Best Practices

### Modeling
- **Normalization**: Avoid redundancy
- **Denormalization**: For performance when needed
- **Consistency**: Uniform naming conventions
- **⚠️ NEW**: Use SeasonParticipation for Player-Club relationships

### Development
- **Migrations**: Always make them reversible
- **Validations**: At model and database level
- **Tests**: Test database logic
- **⚠️ NEW**: Test SeasonParticipation logic

### Maintenance
- **Backups**: Regular backups
- **Updates**: Plan database updates
- **Monitoring**: Continuously monitor performance
- **⚠️ NEW**: Monitor SeasonParticipation performance

## Summary of Changes

### What has changed?
1. **Player.club_id**: No longer used (historical)
2. **SeasonParticipation**: New N:M relationship between Player, Club and Season
3. **Flexibility**: Players can play for different clubs in different seasons
4. **Status Management**: Different statuses for club membership

### What remains the same?
1. **Basic Structure**: All other relationships remain unchanged
2. **API**: Existing API endpoints continue to work
3. **Views**: Existing views continue to work

### Recommendations
1. **Use SeasonParticipation** for all Player-Club relationships
2. **Avoid direct access** to Player.club_id
3. **Test all queries** with the new structure
4. **Document the changes** for the team 