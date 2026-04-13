# Carambus Developer Guide

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Extracted Services](#extracted-services)
4. [Getting Started](#getting-started)
5. [Database Setup](#database-setup)
6. [Database Design](#database-design)
7. [Core Models](#core-models)
8. [Key Features](#key-features)
9. [Development Workflow](#development-workflow)
10. [Deployment](#deployment)
11. [Contributing](#contributing)

## Overview

Carambus is a comprehensive billiards tournament management system built with Ruby on Rails. It provides complete automation of billiards operations from tournament planning to data collection and result transmission.

### Key Features
- **Tournament Management**: Complete tournament lifecycle management
- **Real-time Scoreboards**: Live scoreboard displays with WebSocket support
- **League Management**: Team-based league organization
- **Data Synchronization**: Integration with external billiards databases (BA/CC)
- **Multi-language Support**: German and English interfaces
- **Responsive Design**: Works on desktop and mobile devices

### Technology Stack
- **Backend**: Ruby on Rails 7.2
- **Database**: PostgreSQL
- **Frontend**: Hotwire (Turbo + Stimulus) + Stimulus Reflex
- **Real-time**: Action Cable with Redis
- **Authentication**: Devise
- **Authorization**: Pundit + CanCanCan
- **Admin Interface**: Administrate
- **Deployment**: Capistrano + Puma

## Architecture

### Rails Structure
Carambus follows standard Rails conventions with some customizations:

```
app/
├── controllers/          # RESTful controllers
├── models/              # ActiveRecord models with concerns
├── views/               # ERB templates
├── javascript/          # Stimulus controllers and utilities
├── channels/            # Action Cable channels
├── jobs/                # Background jobs
├── services/            # Business logic services
└── helpers/             # View helpers
```

### Key Architectural Patterns

#### Concerns
The application uses Rails concerns to share functionality:

- `LocalProtector`: Protects local data from external modifications
- `SourceHandler`: Manages external data synchronization
- `RegionTaggable`: Handles region-based data organization

#### Real-time Features
- **Action Cable**: WebSocket connections for live updates
- **Stimulus Reflex**: Server-side reflexes for reactive UI
- **Cable Ready**: Client-side DOM manipulation

## Extracted Services

35 services have been extracted from the original god-objects into 7 namespaces. Each service has a single, clearly bounded responsibility.

### TableMonitor:: (2 Services)

| Service Class | File | Description |
|---|---|---|
| `TableMonitor::GameSetup` | `app/services/table_monitor/game_setup.rb` | Encapsulates start_game logic — creates Game/GameParticipation records, builds result hash, and queues TableMonitorJob |
| `TableMonitor::ResultRecorder` | `app/services/table_monitor/result_recorder.rb` | Encapsulates result persistence — saves set data, navigates between sets, and coordinates AASM state transitions |

### RegionCc:: (10 Services)

| Service Class | File | Description |
|---|---|---|
| `RegionCc::BranchSyncer` | `app/services/region_cc/branch_syncer.rb` | Synchronizes BranchCc (discipline) records from the ClubCloud API |
| `RegionCc::ClubCloudClient` | `app/services/region_cc/club_cloud_client.rb` | Stateless HTTP transport for the ClubCloud admin interface — no ORM coupling, supports sessions and dry-run mode |
| `RegionCc::ClubSyncer` | `app/services/region_cc/club_syncer.rb` | Synchronizes Club records from the ClubCloud API |
| `RegionCc::CompetitionSyncer` | `app/services/region_cc/competition_syncer.rb` | Synchronizes competition and season data from ClubCloud |
| `RegionCc::GamePlanSyncer` | `app/services/region_cc/game_plan_syncer.rb` | Synchronizes GamePlanCc and GameDetailCc records including complex HTML table parsing |
| `RegionCc::LeagueSyncer` | `app/services/region_cc/league_syncer.rb` | Dispatcher for league sync — coordinates leagues, teams, game plans, and player synchronization |
| `RegionCc::MetadataSyncer` | `app/services/region_cc/metadata_syncer.rb` | Synchronizes metadata reference objects (categories, groups, disciplines) from ClubCloud |
| `RegionCc::PartySyncer` | `app/services/region_cc/party_syncer.rb` | Synchronizes PartyCc records and match data from ClubCloud |
| `RegionCc::RegistrationSyncer` | `app/services/region_cc/registration_syncer.rb` | Synchronizes registration list records from ClubCloud |
| `RegionCc::TournamentSyncer` | `app/services/region_cc/tournament_syncer.rb` | Synchronizes tournament, tournament series, and championship type data from ClubCloud |

### Tournament:: (3 Services)

| Service Class | File | Description |
|---|---|---|
| `Tournament::PublicCcScraper` | `app/services/tournament/public_cc_scraper.rb` | Scrapes tournament data from the public ClubCloud URL — processes seedings, games, and rankings |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | Calculates and caches effective player rankings; reorders seedings after competition |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | Creates Google Calendar events for table reservations with guard condition validation |

### TournamentMonitor:: (4 Services)

| Service Class | File | Description |
|---|---|---|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | Pure PORO — distributes players across groups using zig-zag or round-robin per NBV rules |
| `TournamentMonitor::RankingResolver` | `app/services/tournament_monitor/ranking_resolver.rb` | Pure PORO — resolves player IDs from ranking rule strings (group ranks, KO bracket references) |
| `TournamentMonitor::ResultProcessor` | `app/services/tournament_monitor/result_processor.rb` | Processes game results with pessimistic DB lock — coordinates ClubCloud upload and GameParticipation updates |
| `TournamentMonitor::TablePopulator` | `app/services/tournament_monitor/table_populator.rb` | Assigns games to tournament tables — initializes TableMonitor records and runs the placement algorithm |

### League:: (4 Services)

| Service Class | File | Description |
|---|---|---|
| `League::BbvScraper` | `app/services/league/bbv_scraper.rb` | Scrapes BBV-specific league data (teams and results) |
| `League::ClubCloudScraper` | `app/services/league/club_cloud_scraper.rb` | Scrapes league data from ClubCloud — teams, parties, and game plans |
| `League::GamePlanReconstructor` | `app/services/league/game_plan_reconstructor.rb` | Reconstructs GamePlan from existing Parties and PartyGames |
| `League::StandingsCalculator` | `app/services/league/standings_calculator.rb` | Calculates league standings tables for Karambol, Snooker, and Pool disciplines |

### PartyMonitor:: (2 Services)

| Service Class | File | Description |
|---|---|---|
| `PartyMonitor::ResultProcessor` | `app/services/party_monitor/result_processor.rb` | Processes game results in the PartyMonitor context with pessimistic DB lock |
| `PartyMonitor::TablePopulator` | `app/services/party_monitor/table_populator.rb` | Resets PartyMonitor and assigns TableMonitor records to Party tables |

### Umb:: (10 Services)

Detailed architecture documentation: [UMB Scraping — Architecture](umb-scraping-implementation.md) and [UMB Scraping — Method Reference](umb-scraping-methods.md).

| Service Class | File | Description |
|---|---|---|
| `Umb::HttpClient` | `app/services/umb/http_client.rb` | Stateless HTTP transport — fetches HTML and PDF content from UMB URLs, handles SSL, redirects, and timeouts |
| `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Stateless PORO — maps tournament names to `Discipline` DB records via regex and DB-ILIKE fallback |
| `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Module with `module_function` — parses UMB date range strings (same-month and cross-month formats) into `{start_date:, end_date:}` |
| `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Finds or creates `Player` records from UMB caps/mixed name pairs with umb_player_id and nationality enrichment |
| `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapes `FutureTournaments.aspx`, parses HTML table including cross-month events, and upserts `InternationalTournament` records |
| `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequential ID scan of `TournametDetails.aspx?ID=N` — discovers and saves historical tournament records |
| `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapes a tournament detail page, extracts PDF links, creates `InternationalGame` records, and orchestrates the PDF pipeline |
| `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Pure PORO — parses player seeding list PDF text into `{caps_name:, mixed_name:, nationality:, position:}` hashes |
| `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Pure PORO — parses group result PDF text into match pairs using a pair-accumulator pattern |
| `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Pure PORO — parses final or weekly ranking PDF text; supports `:final` and `:weekly` type modes |

## Getting Started

### Prerequisites
- Ruby 3.2+ (see `.ruby-version`)
- PostgreSQL 11+
- Redis 5+
- Node.js 14+ (for asset compilation)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd carambus
   ```

2. **Install dependencies**
   ```bash
   bundle install
   yarn install
   ```

3. **Database setup**
   ```bash
   cp config/database.yml.example config/database.yml
   # Edit database.yml with your PostgreSQL credentials
   
   # Option 1: Import existing database dump (recommended)
   # Ensure you have a database dump file (e.g., carambus_api_development_YYYYMMDD_HHMMSS.sql)
   # Create database and import dump:
   createdb carambus_development
   psql -d carambus_development -f /path/to/your/dump.sql
   
   # Option 2: Create fresh database (if no dump available)
   rails db:create
   rails db:migrate
   rails db:seed
   ```

4. **Environment configuration**
   ```bash
   cp config/application.yml.example config/application.yml
   # Edit application.yml with your configuration
   ```

5. **Start the application**
   ```bash
   rails server
   ```

### Development Tools

#### Code Quality
- **RuboCop**: Code style enforcement
- **Standard**: Ruby code formatting
- **Brakeman**: Security vulnerability scanning
- **Overcommit**: Git hooks for code quality

#### Testing
- **RSpec**: Unit and integration tests
- **Capybara**: System tests
- **Factory Bot**: Test data factories

## Database Setup {#database-setup}

For setting up a new development database, it is recommended to import an existing database dump. Detailed instructions can be found in the separate documentation:

**[🗄️ Database Setup Guide](../administrators/database-setup.md)**

### Quick Start
```bash
# Create database
createdb carambus_development

# Import dump
psql -d carambus_development -f /path/to/your/dump.sql
```

### Expected Errors
During import, the following errors may occur and can be ignored:
- `relation "table_name" already exists` - Table already exists
- `multiple primary keys for table "table_name" are not allowed` - Primary key already defined
- `relation "index_name" already exists` - Index already exists
- `constraint "constraint_name" for relation "table_name" already exists` - Constraint already defined

These errors are normal if the database has already been partially initialized.

## Database Design

### Core Models

#### Seeding Model (Dual Purpose)
The `Seeding` model serves two distinct purposes:

1. **Team Roster Management**
   - Connected to `LeagueTeam` via `league_team_id`
   - Maintains full roster of players for a league team
   - Created during initial league/team setup

2. **Match Participation Tracking**
   - Connected to `Party` via polymorphic `tournament_id`
   - Tracks which players participate in specific matches
   - Created when setting up individual matches

```ruby
class Seeding < ApplicationRecord
  belongs_to :player, optional: true
  belongs_to :tournament, polymorphic: true, optional: true
  belongs_to :league_team, optional: true
  include LocalProtector
  include SourceHandler
  include RegionTaggable
end
```

#### Party and LeagueTeam Relationship
```ruby
class Party < ApplicationRecord
  belongs_to :league_team_a, class_name: "LeagueTeam"
  belongs_to :league_team_b, class_name: "LeagueTeam"
  belongs_to :host_league_team, class_name: "LeagueTeam"
  has_many :seedings, as: :tournament
  include LocalProtector
  include SourceHandler
end
```

### Data Storage Patterns

#### Flexible Data Storage
Several models use serialized columns for flexible data storage:

```ruby
# JSON Serialization
serialize :data, coder: JSON, type: Hash
# Used in: Party, Seeding, LeagueTeam

# YAML Serialization  
serialize :remarks, coder: YAML, type: Hash
# Used in: Party
```

#### Region Tagging System
The `RegionTaggable` concern provides intelligent region handling:

```ruby
# Automatic region tagging based on context
when Seeding
  if tournament_id.present?
    # Tournament-based region tagging
    tournament ? [
      tournament.region_id,
      (tournament.organizer_type == "Region" ? tournament.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  elsif league_team_id.present?
    # League team-based region tagging
    league_team&.league ? [
      (league_team.league.organizer_type == "Region" ? league_team.league.organizer_id : nil),
      find_dbu_region_id_if_global
    ].compact : []
  end
```

## Core Models

### Tournament Management
- **Tournament**: Main tournament entity
- **Discipline**: Game types (e.g., 3-cushion, 1-cushion)
- **Player**: Individual players
- **Seeding**: Tournament participation and rankings

### League Management
- **League**: League organization
- **LeagueTeam**: Teams within leagues
- **Party**: Individual matches between teams
- **Season**: League seasons

### Location Management
- **Location**: Billiards clubs/locations
- **Table**: Individual billiards tables
- **TableMonitor**: Real-time table monitoring
- **TableLocal**: Local table configurations

### User Management
- **User**: System users with Devise authentication
- **Role**: User roles and permissions
- **Admin**: Administrative interface via Administrate

## Key Features

### Real-time Scoreboards
The scoreboard system provides live updates for tournament displays:

#### Components
- **Table Monitor**: Real-time game tracking
- **Scoreboard Display**: Public scoreboard views
- **WebSocket Integration**: Live updates via Action Cable

#### Setup
See [Scoreboard Autostart Setup](../administrators/../administrators/scoreboard-autostart.md) for detailed configuration.

### Data Synchronization
Integration with external billiards databases:

#### External Sources
- **BA (Billiards Association)**: Official player and tournament data
- **CC (Competition Center)**: Competition management system

#### Synchronization Process
1. External data is fetched via API
2. Local data is protected from external modifications
3. Region tagging is automatically applied
4. Conflicts are resolved based on source priority

### Tournament Workflows

#### Tournament Creation
1. Create tournament with discipline and settings
2. Define participants (players/teams)
3. Generate game plans
4. Start tournament with real-time monitoring

#### Match Management
1. Schedule matches (Parties)
2. Track live game progress
3. Record results and rankings
4. Generate reports and statistics

## Development Workflow

### Code Style
The project uses Standard Ruby for code formatting:

```bash
# Format code
bundle exec standardrb --fix

# Check for issues
bundle exec standardrb
```

### Git Workflow
1. Create feature branch from main
2. Make changes with tests
3. Run code quality checks
4. Submit pull request

### Testing
```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/tournament_test.rb

# Run system tests
rails test:system
```

### Database Migrations
```bash
# Generate migration
rails generate migration AddFieldToModel

# Run migrations
rails db:migrate

# Rollback
rails db:rollback
```

## Deployment

### Enhanced Mode System
Carambus uses an **Enhanced Mode System** with Ruby/Rake Named Parameters for easy switching between different deployment configurations:

#### Key Features
- ✅ **19 Parameters** for complete configuration control
- ✅ **Socket-based architecture** with Unix sockets for efficient NGINX-Puma communication
- ✅ **Automatic template generation** (NGINX, Puma, Service)
- ✅ **RubyMine integration** with complete debugging support
- ✅ **Multi-environment deployment** with automatic repo pull

#### Quick Start

> ⚠️ **OBSOLETE:** The Mode System has been replaced by Scenario Management.

```bash
# Use Scenario Management instead
rake scenario:deploy[scenario_name,target_environment]

# Example:
rake scenario:deploy[carambus_location_5101,production]
```

**[🚀 Current: Scenario Management Documentation](scenario-management.md)**  
~~**Old (Obsolete): Enhanced Mode System**~~

### Production Setup
The application is designed for deployment on Raspberry Pi or similar hardware:

#### System Requirements
- **Hardware**: Raspberry Pi 4 (4GB RAM recommended)
- **OS**: Raspberry Pi OS (32-bit)
- **Database**: PostgreSQL 11+
- **Web Server**: Nginx + Puma

#### Deployment Process
1. **Server Setup**: See [Runbook](../developers/developer-guide.md#operations) for detailed server configuration
2. **Enhanced Mode Configuration**: Use the Enhanced Mode System for deployment configuration
3. **Application Deployment**: Capistrano-based deployment
4. **Service Management**: Systemd services for autostart
5. **Scoreboard Setup**: Automated scoreboard startup

### Configuration Files

#### Database Configuration
```yaml
# config/database.yml
production:
  adapter: postgresql
  database: carambus_production
  host: localhost
  username: www_data
  password: <%= ENV['DATABASE_PASSWORD'] %>
```

#### Application Configuration
```yaml
# config/application.yml
defaults: &defaults
  database_url: postgresql://www_data:password@localhost/carambus_production
  redis_url: redis://localhost:6379/0
  secret_key_base: <%= ENV['SECRET_KEY_BASE'] %>
```

### Service Management
```bash
# Start application
sudo systemctl start carambus

# Enable autostart
sudo systemctl enable carambus

# Check status
sudo systemctl status carambus
```

## Contributing

### Development Environment
1. Follow the [Getting Started](#getting-started) guide
2. Set up pre-commit hooks: `bundle exec overcommit --install`
3. Familiarize yourself with the [Database Design](#database-design)

### Code Contributions
1. **Fork the repository**
2. **Create a feature branch**
3. **Make your changes**
4. **Add tests for new functionality**
5. **Ensure all tests pass**
6. **Submit a pull request**

### Documentation
- Update relevant documentation when adding features
- Include code examples for new APIs
- Document configuration changes

### Testing Guidelines
- Write tests for all new functionality
- Maintain test coverage above 80%
- Include integration tests for complex workflows
- Test both German and English locales

### Code Review Process
1. All changes require code review
2. Automated checks must pass
3. Manual testing on staging environment
4. Documentation updates as needed

## Additional Resources

### Documentation
- [Database Design](database-design.md): Detailed database schema
- [Scoreboard Setup](../administrators/scoreboard-autostart.md): Scoreboard configuration
- [Tournament Management](../managers/tournament-management.md): Tournament workflows
- [Installation Overview](../administrators/installation-overview.md): Installation overview
- [Scenario Management](scenario-management.md): Deployment configuration and multi-environment support
- ~~Enhanced Mode System~~ - **OBSOLETE** (replaced by Scenario Management)

### External Links
- [Ruby on Rails Guides](https://guides.rubyonrails.org/)
- [Hotwire Documentation](https://hotwired.dev/)
- [Stimulus Reflex](https://docs.stimulusreflex.com/)
- [Action Cable](https://guides.rubyonrails.org/action_cable_overview.html)

### Support
- **Issues**: Use GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for questions and ideas
- **Documentation**: Keep documentation up to date with changes

---

*This documentation is maintained by the Carambus development team. For questions or contributions, please see the [Contributing](#contributing) section.* 