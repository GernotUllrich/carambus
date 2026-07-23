# Architecture

**Analysis Date:** 2026-04-09

## Pattern Overview

**Overall:** Monolithic Rails 7.2 MVC application with real-time capabilities via ActionCable/StimulusReflex

**Key Characteristics:**
- Traditional Rails layered architecture with services layer
- Real-time updates using ActionCable for synchronous WebSocket communication
- StimulusReflex for client-side interactivity without full page reloads
- Background job processing via ActiveJob with Sidekiq
- Multi-domain support (tournament management, player profiles, scoring, streaming)
- Internationalization support (German/English)

## Layers

**Presentation Layer (Views & Controllers):**
- Purpose: HTTP request handling and view rendering
- Location: `app/views/`, `app/controllers/`
- Contains: ERB templates, controller action handlers
- Depends on: Models, Services, Concerns
- Used by: HTTP/WebSocket clients (browsers)

**ActionCable Real-time Layer:**
- Purpose: Bidirectional WebSocket communication for live updates
- Location: `app/channels/`, `app/javascript/channels/`
- Contains: Channel subscriptions, streaming updates via CableReady
- Depends on: Models, Services
- Used by: Browser clients for real-time scoreboard, tournament, table monitor data

**StimulusReflex Layer:**
- Purpose: Server-side handling of client interactions without full page reload
- Location: `app/reflexes/`
- Contains: Reflex classes (ApplicationReflex, SearchReflex, PartyMonitorReflex, etc.)
- Depends on: Models, Services
- Used by: Stimulus.js controllers on client side

**Business Logic Layer (Services):**
- Purpose: Complex multi-step operations and external integrations
- Location: `app/services/`
- Contains: Scrapers (UMB, Kozoom, SoopLive, YouTube), Translation services (DeepL, OpenAI, Anthropic), PDF generation, Search
- Depends on: Models, external APIs
- Used by: Controllers, Jobs, Mailers, other services

**Data Layer (Models):**
- Purpose: ActiveRecord models representing domain entities and relationships
- Location: `app/models/`
- Contains: Core models (Club, Player, Tournament, Game, League, Party), association definitions, validations
- Depends on: Database, Concerns
- Used by: Controllers, Services, Jobs

**Admin Dashboard Layer:**
- Purpose: Admin interface for managing application data
- Location: `app/dashboards/`
- Contains: Administrate field definitions for CRUD operations
- Depends on: Models, Administrate gem
- Used by: Admin controllers (via Administrate)

**Job/Queue Layer:**
- Purpose: Asynchronous background processing
- Location: `app/jobs/`
- Contains: Scheduled jobs (daily scrapes), event-driven jobs (table monitor, streaming)
- Depends on: Models, Services
- Used by: Rails scheduler (Sidekiq-scheduler), event triggers

## Data Flow

**Real-time Tournament Scoring:**

1. TableMonitor (referee console) submits game update via Reflex
2. PartyMonitorReflex processes update → invokes Party/Game model changes
3. Model saves to database and broadcasts via CableReady
4. TournamentMonitorChannel/TableMonitorChannel receive broadcast
5. Connected clients (scoreboards, tournament displays) update DOM in real-time

**Web Scraping Integration:**

1. Schedule triggers (daily_international_scrape_job, scrape_umb_job)
2. Job calls Scraper service (UmbScraper, YoutubeeScraper, SoopliveeScraper)
3. Scraper fetches external data, parses structure
4. Creates/updates Tournament, Party, InternationalGame records
5. Broadcasts updates to relevant channels
6. Optional: Triggers translation jobs for player names/descriptions

**Search Flow:**

1. Client submits search query via SearchReflex
2. Reflex calls SearchService or AISearchService
3. Service queries models using Searchable concern
4. Results returned, rendered in view
5. Page updates without full reload

**State Management:**

- Models are source of truth stored in PostgreSQL
- Redis caches ActionCable subscriptions and CableReady broadcasts
- User preferences stored in User.preferences (JSON column)
- Application config from `config/carambus.yml` (managed via admin interface)

## Key Abstractions

**Searchable Concern:**
- Purpose: Provides unified search interface across domain models
- Examples: `app/models/concerns/searchable.rb`
- Pattern: Models define text_search_sql, search_joins, field_examples; ApplicationController uses parse_search_string

**CableReady Broadcaster:**
- Purpose: Push DOM updates from server to connected clients
- Examples: Included in ApplicationRecord, ApplicationJob, ApplicationController
- Pattern: Models broadcast changes; views subscribe to channels

**StimulusReflex Integration:**
- Purpose: Handle client interactions server-side with DOM diffing
- Examples: `app/reflexes/party_monitor_reflex.rb`, `app/reflexes/game_protocol_reflex.rb`
- Pattern: Reflexes inherit ApplicationReflex, access current_user, manipulate models, CableReady renders

**LocalProtector Concern:**
- Purpose: Prevent modification of global records on local development server
- Examples: Used in Club, Player, Game models
- Pattern: before_save hook blocks saves with id < MIN_ID on local server unless unprotected flag

**Translatable Concern:**
- Purpose: Support multilingual content
- Examples: `app/models/concerns/translatable.rb`
- Pattern: Models can have translated fields stored in JSON or separate columns

**RegionTaggable Concern:**
- Purpose: Track geographical regions for resource filtering
- Examples: Club, Game, League models
- Pattern: Associates models with Region, used for search filtering

## Entry Points

**Web Application:**
- Location: `config/routes.rb`
- Triggers: HTTP requests to `/`
- Responsibilities: Route requests to controllers, define namespaces (admin, api, international)

**Admin Dashboard:**
- Location: Rails/Administrate auto-routing
- Triggers: `/admin/` route requests
- Responsibilities: CRUD operations on resources via dashboards

**ActionCable:**
- Location: `app/channels/application_cable/connection.rb`
- Triggers: WebSocket connection establishment
- Responsibilities: Authenticate user, assign connection_token, identify by current_user

**Background Jobs:**
- Location: `config/schedule.rb`
- Triggers: Cron schedule or manual queuing
- Responsibilities: Scheduled scraping, monitoring, status updates

**API Endpoints:**
- Location: `app/controllers/api/`
- Triggers: `/api/` route requests
- Responsibilities: Autocomplete endpoints (players, locations), AI search, documentation search

## Error Handling

**Strategy:** Exception handling via ApplicationController, custom error controller for HTTP errors

**Patterns:**
- Model validations raise ActiveRecord::RecordInvalid
- Controllers catch exceptions, redirect with flash messages
- Mailers catch errors, log instead of raising
- Jobs implement retry logic via ActiveJob retry_on directive
- Search failures fall back to empty results
- Scraper failures logged but don't block job execution

**Custom Error Handling:**
- `ErrorsController` (app/controllers/errors_controller.rb) handles 404/500
- Routes configured: `config.exceptions_app = routes`

## Cross-Cutting Concerns

**Logging:** Rails default logger with request context tags (ActionCable), request tracking via SetCurrentRequestDetails concern

**Validation:** Active Record model validations, custom validators in `app/validators/`, Devise validators for User authentication

**Authentication:** Devise gem (app/models/user.rb), configured with custom registrations controller, supports impersonation via ActionCable, current_user accessible in all contexts

**Authorization:** CanCanCan gem with Ability model (`app/models/ability.rb`), checked in ApplicationController via current_ability method

**Internationalization:** Rails i18n with config files in `config/locales/`, locale determined by params → user preferences → Accept-Language header, default: German

**Paper Trail Versioning:** Tracks all model changes, auditable via version history, set via set_paper_trail_whodunnit in ApplicationRecord/ApplicationCable::Connection

---

*Architecture analysis: 2026-04-09*
