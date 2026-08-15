# Codebase Structure

**Analysis Date:** 2026-04-09

## Directory Layout

```
carambus_api/
├── app/                                  # Main application code
│   ├── assets/                           # CSS, images, manifest
│   ├── channels/                         # ActionCable WebSocket channels
│   ├── controllers/                      # HTTP request handlers
│   │   ├── concerns/                     # Shared controller behavior
│   │   ├── admin/                        # Admin interface actions
│   │   ├── api/                          # API endpoint handlers
│   │   └── international/                # International data views
│   ├── dashboards/                       # Administrate admin dashboards
│   ├── fields/                           # Custom Administrate field types
│   ├── helpers/                          # View helpers (named by controller)
│   ├── javascript/                       # Client-side JavaScript/Stimulus
│   │   ├── channels/                     # ActionCable client subscriptions
│   │   ├── controllers/                  # Stimulus JS controllers
│   │   ├── packs/                        # Webpack entry points
│   │   └── utils/                        # Shared JS utilities
│   ├── jobs/                             # Background job classes
│   ├── lib/                              # Custom Administrate fields (non-autoloaded)
│   ├── mailers/                          # Action Mailer classes
│   ├── mailboxes/                        # Action Mailbox classes
│   ├── models/                           # ActiveRecord models
│   │   ├── concerns/                     # Shared model behavior
│   │   └── user/                         # User model related classes
│   ├── reflexes/                         # StimulusReflex server-side handlers
│   ├── services/                         # Business logic & external integrations
│   ├── static/                           # Static files/documentation
│   ├── validators/                       # Custom ActiveModel validators
│   ├── views/                            # ERB templates (named by controller)
│   └── viewsstatic/                      # Static view templates
│
├── config/                               # Application configuration
│   ├── initializers/                     # Auto-loaded initialization scripts
│   ├── locales/                          # i18n translation files
│   ├── environments/                     # Environment-specific config
│   ├── deploy/                           # Capistrano deployment config
│   ├── credentials/                      # Encrypted credentials
│   ├── routes.rb                         # Route definitions
│   ├── database.yml                      # Database configuration
│   ├── cable.yml                         # ActionCable configuration
│   ├── storage.yml                       # Active Storage configuration
│   ├── carambus.yml                      # Custom app configuration
│   └── schedule.rb                       # Sidekiq Scheduler job schedule
│
├── db/                                   # Database
│   ├── migrate/                          # ActiveRecord migrations
│   ├── schema.rb                         # Database schema snapshot
│   └── seeds.rb                          # Database seeding script
│
├── lib/                                  # Non-autoloaded utility code
│   ├── tasks/                            # Rake tasks
│   ├── templates/                        # Code generation templates
│   ├── tournament_monitor_state.rb       # Tournament state machine logic
│   ├── tournament_monitor_support.rb     # Tournament monitoring helpers
│   └── carambus_env.rb                   # Environment variable handling
│
├── test/                                 # Test suites
│   ├── fixtures/                         # Test data factories
│   ├── models/                           # Model unit tests
│   ├── system/                           # End-to-end browser tests
│   ├── integration/                      # Request/response tests
│   ├── scraping/                         # Scraper mock tests with VCR
│   ├── support/                          # Test helpers/utilities
│   ├── snapshots/                        # VCR cassettes
│   ├── tasks/                            # Rake task tests
│   └── test_helper.rb                    # Test configuration
│
├── public/                               # Static files served directly
├── storage/                              # Active Storage uploads (local dev)
├── tmp/                                  # Temporary files
├── log/                                  # Application logs
├── ssl/                                  # SSL certificates
│
├── Gemfile                               # Ruby gem dependencies
├── config.ru                             # Rack application config
├── Rakefile                              # Rake tasks
├── .env*                                 # Environment variables
├── .ruby-version                         # Ruby 3.2.1
└── .gitignore                            # Ignored files/folders
```

## Directory Purposes

**app/assets/:**
- Purpose: Static CSS, JavaScript, image assets (sprockets pipeline)
- Contains: application.css, images, vendor files
- Key files: None auto-discovered; managed by Sprockets

**app/channels/:**
- Purpose: ActionCable WebSocket channels for real-time updates
- Contains: Channel classes defining subscriptions and broadcasts
- Key files: `application_cable/connection.rb` (authentication), `tournament_monitor_channel.rb`, `table_monitor_channel.rb`, `table_monitor_clock_channel.rb`, `tournament_channel.rb`, `location_channel.rb`

**app/controllers/:**
- Purpose: HTTP request handlers, determine action and response
- Contains: RESTful and custom actions, before/after filters
- Key files: `application_controller.rb` (authentication, authorization, search), nested controllers for admin, api, international sections

**app/dashboards/:**
- Purpose: Admin interface field definitions (Administrate gem)
- Contains: Dashboard classes defining layout, attributes, filters
- Key files: Examples - `discipline_dashboard.rb`, `user_dashboard.rb`, `player_duplicate_dashboard.rb`

**app/fields/:**
- Purpose: Custom form field types for admin dashboards
- Contains: Administrate field subclasses for specialized rendering
- Key files: Custom fields in `administrate/field/`

**app/helpers/:**
- Purpose: View helper methods for templates
- Contains: View-specific logic (formatting, conditional display)
- Key files: One helper per controller (party_monitor_helper.rb, table_monitor_helper.rb, etc.) + shared helpers

**app/javascript/:**
- Purpose: Client-side JavaScript, Stimulus controllers, ActionCable subscriptions
- Contains: Modern ES6 modules with Stimulus framework
- Key files: 
  - `controllers/` - Stimulus JS controllers for interactivity
  - `channels/` - ActionCable subscriptions (tournament_channel.js, table_monitor_channel.js)
  - `packs/` - Webpack entry points

**app/jobs/:**
- Purpose: Asynchronous background job processing (Sidekiq)
- Contains: ActiveJob subclasses, perform methods
- Key files: 
  - `daily_international_scrape_job.rb` - Daily tournament scraping
  - `table_monitor_job.rb` - Real-time table monitor updates
  - `tournament_monitor_update_results_job.rb` - Tournament result processing
  - `stream_control_job.rb`, `stream_health_job.rb` - Streaming monitoring

**app/lib/:**
- Purpose: Non-standard library code for Administrate fields
- Contains: Custom field implementations not auto-reloaded
- Key files: `administrate/field/` (custom Administrate field types)

**app/mailers/:**
- Purpose: Action Mailer email sending
- Contains: Email template logic and delivery
- Key files: `application_mailer.rb`, `upload_mailer.rb`, `account_invitations_mailer.rb`

**app/models/:**
- Purpose: Data models, validations, associations, business logic
- Contains: ActiveRecord subclasses with relationship definitions
- Key files:
  - `club.rb` - Club/organization data
  - `player.rb` - Player profiles
  - `tournament.rb` - Tournament management
  - `game.rb` - Individual game records
  - `party.rb` - Party/match groupings
  - `league.rb` - League season data (93KB - large, complex)
  - `party_monitor.rb` - Real-time monitoring state (22KB)
  - `international_tournament.rb` - International data syncing
  - `user.rb` - Authentication & authorization
  - `concerns/` - Shared behavior (Searchable, RegionTaggable, PlaceholderAware, Translatable)

**app/reflexes/:**
- Purpose: StimulusReflex server-side handlers
- Contains: Reflex classes handling client-side interactions
- Key files:
  - `application_reflex.rb` - Base reflex with current_user access
  - `party_monitor_reflex.rb` - Game update handling
  - `game_protocol_reflex.rb` - Game protocol editing
  - `tournament_reflex.rb` - Tournament admin actions
  - `search_reflex.rb` - Search form submissions
  - `table_monitor_reflex.rb` - Table monitoring updates
  - `location_reflex.rb` - Location filtering

**app/services/:**
- Purpose: Complex business logic, external API integrations
- Contains: Service classes with single responsibility
- Key files:
  - `umb_scraper.rb` - German UMB tournament scraping (78KB)
  - `umb_scraper_v2.rb` - Improved UMB scraper version
  - `youtube_scraper.rb` - YouTube video scraping
  - `sooplive_scraper.rb` - SoopLive streaming scraping
  - `kozoom_scraper.rb` - Kozoom tournament data
  - `ai_search_service.rb` - AI-powered search via external API
  - `deepl_translation_service.rb` - Language translation
  - `anthropic_translation_service.rb` - Alternative translation provider
  - `protocol_pdf.rb` - Game protocol PDF generation

**app/validators/:**
- Purpose: Custom ActiveModel validators
- Contains: Validator classes for specialized validation logic
- Key files: Custom validators used in model validations

**app/views/:**
- Purpose: ERB templates for rendering HTML
- Contains: One directory per controller resource
- Key files:
  - Directories per model: `tournaments/`, `players/`, `clubs/`, `games/`, `parties/`, etc.
  - Views: `index.html.erb`, `show.html.erb`, `edit.html.erb`, `_form.html.erb`
  - Layouts: `application.html.erb`, other specialized layouts

**config/credentials/:**
- Purpose: Encrypted credential storage per environment
- Contains: Encrypted YAML files (development.yml.enc, production.yml.enc)
- Key files: Environment-specific encrypted credentials

**config/initializers/:**
- Purpose: Auto-loaded initialization on Rails boot
- Contains: Gem configuration, middleware setup, app initialization
- Key files: ~22 initializer files for gems and custom setup

**config/locales/:**
- Purpose: Internationalization (i18n) translations
- Contains: German and English translation files
- Key files: Organized by feature (carambus.yml, errors.yml, activerecord.yml)

**db/migrate/:**
- Purpose: Database schema changes (version control)
- Contains: Timestamped migration files
- Key files: Latest schema versions numbered by timestamp

**lib/tasks/:**
- Purpose: Rake tasks for admin operations
- Contains: ~56 Rake task files for data management, scraping, cleanup
- Key files: Task organization by domain

**test/:**
- Purpose: Automated test suites
- Contains: Unit, integration, system, and snapshot tests
- Key files:
  - `test_helper.rb` - Test configuration
  - `models/` - Unit tests for models
  - `system/` - End-to-end browser tests (Capybara)
  - `scraping/` - VCR cassettes for scraper testing
  - `fixtures/` - Seed data for tests

## Key File Locations

**Entry Points:**
- `app/controllers/application_controller.rb`: Base controller with auth, locale, search, preferences
- `config/routes.rb`: Route definitions for all HTTP endpoints
- `config/cable.rb`: ActionCable/WebSocket configuration
- `lib/tournament_monitor_state.rb`: Tournament state machine implementation

**Configuration:**
- `config/application.rb`: Rails application setup, i18n, time zone
- `config/carambus.yml`: Custom app configuration (managed via admin)
- `config/database.yml`: Database connections
- `config/environments/`: Environment-specific settings

**Core Logic:**
- `app/models/club.rb`: Club entity and relationships
- `app/models/player.rb`: Player profiles
- `app/models/tournament.rb`: Tournament management
- `app/models/game.rb`: Game records and scoring
- `app/models/party.rb`: Party/match groupings
- `app/models/league.rb`: League seasons (complex, 93KB)

**Real-time:**
- `app/channels/application_cable/connection.rb`: WebSocket authentication
- `app/channels/tournament_monitor_channel.rb`: Tournament live updates
- `app/channels/table_monitor_channel.rb`: Table/game updates
- `app/reflexes/party_monitor_reflex.rb`: Game update handling

**Testing:**
- `test/test_helper.rb`: Test configuration and helpers
- `test/models/`: Model unit tests
- `test/system/`: Browser tests
- `test/scraping/`: VCR snapshot tests

## Naming Conventions

**Files:**
- `*.rb`: Ruby source files
- `*.html.erb`: ERB templates with full HTML
- `*_helper.rb`: View helpers by controller name
- `*_concern.rb`: Shared model/controller behavior
- `*_job.rb`: Background job classes
- `*_service.rb`: Service/business logic classes
- `*_scraper.rb`: External data integration services
- `*_dashboard.rb`: Administrate dashboards
- `*_channel.rb`: ActionCable channels
- `*_reflex.rb`: StimulusReflex handlers
- Snake_case for files: `party_monitor.rb`, `game_participation.rb`

**Directories:**
- Snake_case plural: `app/models/`, `app/services/`, `app/controllers/`
- One directory per resource in views: `app/views/parties/`, `app/views/tournaments/`
- Nested namespaces: `app/controllers/admin/`, `app/controllers/api/`, `app/models/user/`

**Classes:**
- PascalCase: `PartyMonitor`, `GameParticipation`, `ApplicationRecord`
- Suffixes match directory: `*Controller`, `*Service`, `*Scraper`, `*Reflex`
- Nested namespaces: `Admin::SomeResource`, `API::SearchController`

**Methods:**
- snake_case for public/private methods: `update_synonyms`, `text_search_sql`
- Trailing `?` for boolean methods: `user_signed_in?`, `local_ip?`
- Trailing `!` for dangerous/mutating methods: `save!`, `find_or_create!`

**Model Names:**
- Singular: `Club`, `Player`, `Tournament`, `Game`, `Party`
- With suffixes: `League` (season), `PartyGame` (association), `GameParticipation` (association)
- Scoped variants: `AbandonedTournamentCc`, `TournamentSeriesCc` (ClubCloud specific)

## Where to Add New Code

**New Feature (e.g., "Add player rankings"):**
- Primary code: 
  - Model: `app/models/player_ranking.rb`
  - Controller: `app/controllers/player_rankings_controller.rb` or reflex
  - Views: `app/views/player_rankings/`
  - Service: `app/services/player_ranking_service.rb` (if complex logic)
- Tests: `test/models/player_ranking_test.rb`, `test/system/player_rankings_test.rb`
- Translations: `config/locales/player_ranking.yml` (German/English)
- Routes: Add to `config/routes.rb`
- If admin dashboard: `app/dashboards/player_ranking_dashboard.rb`

**New Controller Action (REST endpoint):**
- Location: `app/controllers/{resource}_controller.rb`
- Method naming: Standard REST methods (index, show, new, create, edit, update, destroy)
- Non-REST actions: Custom method, register in `config/routes.rb` as member or collection route
- Views: `app/views/{resource}/{action}.html.erb`

**New Service/Integration:**
- Location: `app/services/{service_name}_service.rb`
- Inheritance: `class MyService < ApplicationService` (base in `app/services/application_service.rb`)
- Called from: Controllers, Jobs, other Services
- Example pattern: See `app/services/deepl_translation_service.rb`

**New Background Job:**
- Location: `app/jobs/{job_name}_job.rb`
- Inheritance: `class MyJob < ApplicationJob`
- Scheduling: Add to `config/schedule.rb` if recurring
- Example: `app/jobs/daily_international_scrape_job.rb`

**New Real-time Channel:**
- Location: `app/channels/{resource}_channel.rb`
- Subscription method: `subscribed`, required identifier
- Broadcasting: Models call `broadcast` via CableReady::Broadcaster
- Client: `app/javascript/channels/{resource}_channel.js`
- Example: `app/channels/tournament_monitor_channel.rb`

**New StimulusReflex Handler:**
- Location: `app/reflexes/{resource}_reflex.rb`
- Methods: Called from Stimulus controllers, have access to current_user
- Broadcasting: Use CableReady to update DOM
- Example: `app/reflexes/party_monitor_reflex.rb`

**Utilities & Helpers:**
- Shared model behavior: `app/models/concerns/{name}.rb`
- Shared controller behavior: `app/controllers/concerns/{name}.rb`
- View helpers: `app/helpers/{controller}_helper.rb`
- Library code: `lib/{name}.rb` (if needs reloading) or `lib/{name}.rb` (loaded by config/initializers)

**Tests:**
- Unit tests: `test/models/{model_name}_test.rb`
- System/integration: `test/system/{feature}_test.rb`
- Fixtures: `test/fixtures/{plural_name}.yml`
- Helper: `test/support/{helper_name}.rb`

## Special Directories

**storage_local/:**
- Purpose: Active Storage uploads for local development
- Generated: Yes (auto-created)
- Committed: No (.gitignore'd)

**tmp/:**
- Purpose: Temporary files, session storage, cache
- Generated: Yes (Rails)
- Committed: No (.gitignore'd)

**log/:**
- Purpose: Application logs (development, test, production)
- Generated: Yes (Rails logging)
- Committed: No (.gitignore'd)

**public/:**
- Purpose: Static files served directly (not via asset pipeline)
- Generated: Partially (robots.txt, etc.)
- Committed: Yes

**config/credentials/:**
- Purpose: Encrypted environment-specific credentials
- Generated: Via `rails credentials:edit`
- Committed: Yes (encrypted, safe)

**db/migrate/:**
- Purpose: Version-controlled database schema changes
- Generated: Via `rails generate migration`
- Committed: Yes (essential for reproducibility)

---

*Structure analysis: 2026-04-09*
