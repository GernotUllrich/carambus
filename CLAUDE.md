# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Carambus is a Rails 7.2 application for carom billiard tournament management. It scrapes tournament data from external platforms (UMB, Cuesco/Five&Six, SoopLive, Ko-Zoom), provides real-time scoreboards, AI-powered search, and multi-language support. Ruby 3.2, PostgreSQL, Redis.

## Common Commands

```bash
# Run the app
foreman start -f Procfile.dev          # Full dev stack (server + CSS + JS + Sidekiq)
bin/rails server                       # Rails server only

# Tests (Minitest, not RSpec)
bin/rails test                         # All tests
bin/rails test:critical                # Concerns + scraping tests only
bin/rails test test/concerns/local_protector_test.rb       # Single file
bin/rails test test/concerns/local_protector_test.rb:23    # Single test by line
COVERAGE=true bin/rails test           # With SimpleCov coverage report

# Linting
bundle exec standardrb                 # Ruby style (Standard)
bundle exec erblint --lint-all         # ERB templates
bundle exec brakeman --no-pager        # Security scan

# Database
bin/rails db:migrate
SAFETY_ASSURED=true bin/rails db:test:prepare   # Prepare test DB (strong_migrations)
```

## Architecture

### Local vs Global Records

Records with `id < 50_000_000` (`MIN_ID`) are "global" records synced from the central API. Records with `id >= MIN_ID` are local. The `LocalProtector` concern prevents accidental modification of global records on local server instances. In tests, `LocalProtector` is disabled via `LocalProtectorTestOverride` in `test_helper.rb`.

### Key Concerns (app/models/concerns/)

- **LocalProtector** - Guards global records from local modification
- **RegionTaggable** - Region-based data tagging
- **SourceHandler** - Tracks external data synchronization origin
- **PlaceholderAware** - Handles placeholder/stub records
- **Translatable** - Multi-language content support
- **ScrapingMonitor** - Monitors scraping activity

### Services (app/services/)

- **Scrapers**: `UmbScraperV2`, `CuescoScraper`, `SoopliveScraper`, `KozoomScraper`, `YoutubeScraper` - External data collection
- **AI/Translation**: `AiTranslationService`, `DeeplTranslationService`, `OpenaiTranslationService`, `AiSearchService`
- **Other**: `ProtocolPdf` (PDF generation), `GoogleCalendarService`

### Real-time Stack

Action Cable + Redis + CableReady + StimulusReflex + Turbo. `ApplicationRecord` includes `CableReady::Updatable` and `CableReady::Broadcaster` by default.

### Frontend

Tailwind CSS, esbuild, Stimulus controllers, importmap-rails. SVG icons via `inline_svg`.

### App Configuration

Custom config in `config/carambus.yml` accessed via `Carambus.config` (OpenStruct). Environment-specific overrides merge on top of `default` section.

### Key Gems

- **Auth**: Devise + Pundit + CanCanCan
- **Models**: PaperTrail (versioning), AASM (state machines), acts_as_list
- **Pagination**: Pagy
- **Admin**: Administrate
- **Background Jobs**: Sidekiq
- **Search/AI**: ruby-openai
- **I18n**: Default locale `:de`, fallback `:en`

### Testing

Uses Minitest (not RSpec despite .cursorrules mentioning rspec). Fixtures + FactoryBot. WebMock disables external HTTP. VCR cassettes in `test/snapshots/vcr/` for scraping tests. Tests include `ScrapingHelpers` and `SnapshotHelpers` from `test/support/`.

### Code Conventions

- `frozen_string_literal: true` in all Ruby files
- German comments for business logic, English for technical terms
- Conventional commit messages
- `strong_migrations` enforced in dev/test

<!-- GSD:project-start source:PROJECT.md -->
## Project

**Carambus API — Model Refactoring & Test Coverage**

A focused improvement effort on the Carambus API codebase to break down the two largest model classes (TableMonitor at 3900 lines and RegionCc at 2700 lines) into smaller, well-tested components. This is a refactoring initiative — no new features, no architecture changes.

**Core Value:** Reduce the two worst god-object models into maintainable, testable units without changing external behavior.

### Constraints

- **Behavior preservation**: All existing functionality must continue to work identically
- **Incremental**: Each extraction must be independently deployable
- **Test-first**: Characterization tests before any refactoring
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Ruby 3.2.1 - Core application language for Rails backend
- ERB (Embedded Ruby) - Template language for views and dynamic configuration
- JavaScript/ES6 - Frontend interactivity (via Stimulus.js and Turbo)
## Runtime
- Ruby 3.2.1 (specified in `.ruby-version`)
- Bundler 2.7.2 - Ruby gem dependency management
- Lockfile: Present (`Gemfile.lock` - must be kept synchronized)
## Frameworks
- Rails 7.2.0.beta2 - Full-stack web framework with ORM, routing, and template engine
- Turbo Rails 2.0.11 - SPA-like page acceleration with WebSocket support
- Stimulus Rails 1.0.2+ - Lightweight JavaScript framework for interactivity
- StimulusReflex 3.5.3 - Real-time reactive updates via WebSocket
- Cable Ready 5.0.6 - Broadcast updates over Action Cable
- Puma 6.6 - Multi-threaded HTTP server for production and development
- ActiveRecord (included with Rails) - SQL query builder and ORM for PostgreSQL
- Strong Migrations 0.7.6 - Safety checks for database migrations in production
- Capybara 3.39+ - Integration testing with browser simulation
- Selenium WebDriver 4.20.1+ - Browser automation for system tests
- FactoryBot Rails - Test data factory library
- Shoulda Matchers - RSpec-style assertions
- WebMock - HTTP request mocking for tests
- VCR - Record/replay HTTP interactions for deterministic tests
- SimpleCov - Code coverage analysis (informational, not enforced)
- Sprockets Rails 3.4.1+ - Asset compilation and serving
- ImportMap Rails 1.1 - ES module import mapping without bundlers
- Jbuilder 2.12 - JSON template builder for API responses
## Key Dependencies
- pg (PostgreSQL) - Database adapter for ActiveRecord
- redis 5.1+ - In-memory data store for caching and real-time features
- redis-session-store 0.11.5 - Session persistence in Redis
- paper_trail 15.2 - Audit trail and versioning for model changes
- devise - User authentication framework (local and session-based)
- devise-i18n 1.10 - Internationalization for Devise views
- pundit 2.1 - Authorization framework for policy-based access control
- cancancan 3.5 - Role-based access control (CanCan)
- pretender 0.4 - Admin impersonation for testing user flows
- invisible_captcha 2.0 - Anti-spam honeypot CAPTCHA
- administrate 0.19.0 - Admin dashboard for model management
- pagy 9.3 - Pagination for large datasets (more efficient than Kaminari)
- google-apis-calendar_v3 0.5.0 - Google Calendar event creation/management
- google-apis-youtube_v3 0.40.0 - YouTube video metadata retrieval
- google-cloud-translate 3.7 - Google Cloud Translation API for multilingual content
- gcal-ruby 0.1.0 - Simplified Google Calendar interaction
- ruby-openai 7.3 - OpenAI API client for GPT-4 integration (search and translation)
- Note: Anthropic API support via direct HTTP calls in `AiTranslationService`
- i15r 0.5.1 - i18n key extraction tool
- i18n_yaml_sort (custom gem from GitHub) - YAML translation file organization
- rails-i18n - Internationalization locale data and defaults
- pdf-reader 2.12 - PDF text extraction for tournament invitation parsing
- prawn 2.4 - PDF generation for game protocols
- prawn-table 0.2 - Table support in Prawn-generated PDFs
- rtesseract 3.1 - OCR text extraction from images (requires tesseract-ocr system package)
- image_processing 1.14 - Image variants and transformations
- nokogiri 1.12.5+ - HTML/XML parsing (security update)
- aasm 5.5.2 - State machine implementation for model workflows
- aasm-diagram - FSM visualization generator
- acts_as_list 1.2.6 - Ordered list behavior for models
- andand 1.3.3 - Try-safe method chaining
- text - Text manipulation utilities
- redcarpet 3.5 - Markdown parser
- rouge 3.26 - Syntax highlighting for code blocks
- inline_svg 1.6 - Embedded SVG support with CSS manipulation
- multipart-post - Multipart form data handling
- net-ping - Network connectivity checks
- kamal - Docker container deployment tool
- capistrano 3.19.2 - Server provisioning and deployment
- capistrano-bundler - Bundler integration for deployments
- capistrano-rails - Rails-specific deployment tasks
- capistrano-rbenv - Ruby version management during deployment
- capistrano-secrets-yml - Encrypted credential file management
- capistrano3-puma - Puma process management via Capistrano
- standard - Ruby style guide enforcement (like RuboCop Omakase)
- rubocop-rails-omakase - Rails-specific code style linting
- brakeman - Security vulnerability scanner for Rails
- annotate 3.2.0+ - Database column annotations on models
- letter_opener_web 3.0 - Email preview in development
- stackprof - Profiling and performance analysis
- rack-mini-profiler - HTTP request profiling
- web-console 4.1.0+ - Interactive Ruby console in browser on errors
- overcommit - Git hook manager for pre-commit checks
- listen 3.9 - File change detection for development
- erb_lint - ERB template linting
- flay - Code duplication analyzer
- whenever - Cron job management and scheduling (note: config uses async queue adapter in development)
- Sidekiq configuration available (`config/sidekiq.yml`) but queue adapter set to `:async` by default in development
## Configuration
- Configuration via `config/carambus.yml` (YAML with ERB templating)
- Environment-specific settings in `config/environments/`
- Encrypted credentials per environment: `config/credentials/{environment}.yml.enc`
- Session storage via Redis with fallback error handling
- Credentials encryption keys: `config/credentials/{environment}.key`
- `REDIS_URL` - Redis connection (defaults to `redis://localhost:6379/{port}`)
- `DEEPL_API_KEY` - DeepL translation API key (env var or Rails credentials)
- `OPENAI_API_KEY` - OpenAI API key (via Rails credentials)
- `SMTP_USERNAME` - Gmail SMTP username (production email delivery)
- `SMTP_PASSWORD` - Gmail SMTP password (production email delivery)
- Google service account credentials (JSON format in Rails credentials)
- Anthropic API key (optional, via Rails credentials)
- `database.yml` - ActiveRecord database configuration (PostgreSQL)
- `cable.yml` - Action Cable adapter configuration (Redis in production)
- `storage.yml` - Active Storage service configuration (local disk by default)
- `config/routes.rb` - Rails routing configuration with ActionCable mount
- `sidekiq.yml` - Sidekiq job queue configuration (concurrency, queues, timeout)
## Platform Requirements
- Ruby 3.2.1 (exact version via rbenv or similar)
- PostgreSQL (local or remote via DATABASE_URL)
- Redis server (for Action Cable, caching, session storage)
- Node.js 18+ (for yarn package management)
- Tesseract OCR system package (optional, for image text extraction)
- Google Chrome/Chromium (for table monitoring feature)
- Git for version control
- Deployment target: Self-hosted (via Capistrano) or Docker containers
- External services: PostgreSQL, Redis, Google Cloud APIs, OpenAI API, DeepL API
- Email delivery: Gmail SMTP
- Static file serving: Local filesystem via NGINX or similar reverse proxy
- Reverse proxy: NGINX (for SSL termination, static asset serving)
- Process management: Puma + Capistrano/Docker
- Scheduled job execution: cron (via whenever) or Sidekiq background processor
## Important Notes
- **Rails Version**: Using 7.2.0.beta2 (beta release - not production-ready without careful testing)
- **Asset Pipeline**: Using modern import maps rather than Webpack/Esbuild
- **Real-Time Features**: Action Cable + Turbo + StimulusReflex for reactive UI updates
- **Deployment**: Supports Docker containerization and traditional Capistrano deployments
- **Background Jobs**: Async queue adapter in development; Sidekiq available for production
- **Session Storage**: Redis-based with fallback handling on Redis failures
- **Email**: Gmail SMTP in production; letter_opener_web for development preview
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Models: singular, snake_case (e.g., `player.rb`, `tournament.rb`)
- Controllers: plural, snake_case with `_controller` suffix (e.g., `tournaments_controller.rb`)
- Services: descriptive name, snake_case with `_service` suffix (e.g., `search_service.rb`, `google_calendar_service.rb`)
- Concerns (mixins): descriptive name, snake_case (e.g., `local_protector.rb`, `source_handler.rb`, `searchable.rb`)
- Reflexes (StimulusReflex): `_reflex` suffix (e.g., `tournament_reflex.rb`, `table_monitor_reflex.rb`)
- Mailers: `_mailer` suffix (e.g., `upload_mailer.rb`, `notifier_mailer.rb`)
- Tests: match model/class name with `_test` suffix in corresponding directory (e.g., `test/models/player_test.rb`)
- snake_case for all method names: `def search_joins`, `def default_guest`
- Predicate methods end with `?`: `search_distinct?`, `local_server?`
- Boolean-returning private helpers often end with `?`: `disallow_saving_global_records`
- Class methods for factory/builder patterns: `def self.team_from_players`, `def self.default_guest`
- snake_case for local variables and instance variables: `@tournament`, `@players`, `date_time`
- Constants: SCREAMING_SNAKE_CASE, typically frozen: `COLUMN_NAMES = {...}.freeze`, `REFLECTION_KEYS = [...].freeze`
- Private instance variables: `@` prefix, snake_case (standard Rails)
- Classes: PascalCase (standard Ruby)
- Error classes: PascalCase with `Error` suffix if custom (not common in this project)
- Enum-like constants (hashes, arrays): SCREAMING_SNAKE_CASE, frozen
## Code Style
- Standard: Rubocop with `standard` gem
- String quotes: double quotes enforced (`Style/StringLiterals: double_quotes`)
- No magic comments for hash syntax (`:` prefix disabled)
- Frozen string literals at top of file: `# frozen_string_literal: true` (common, ~106 occurrences)
- Schema annotations: `# == Schema Information` blocks auto-generated by `annotate` gem
- Tool: `standard` gem (RuboCop wrapper)
- Config: `.standard.yml` with minimal overrides
- Custom Rubocop config: `.rubocop.yml` with permissive thresholds:
- ERB linting: `.erb-lint.yml` minimal config
- Security: `brakeman` gem for vulnerability scanning (development/test)
- Models: schema info comment → includes → associations → validations → serializers → constants → class methods → instance methods
- No hard line length enforcement (very permissive linting)
- Consistent indentation with 2 spaces (Rails standard)
## Import Organization
- Standard Rails conventions used, no custom path aliases detected
- All imports use relative paths from `app/` root
- Custom concerns mixed in consistently:
## Error Handling
- Broad rescues common: `rescue StandardError => e` throughout codebase
- Logging errors to dedicated debug log: `DEBUG_LOGGER.error(e)` pattern in `Tournament` model
- Web request errors (Net::HTTP, timeout) rescued generically
- Graceful degradation: tests document that scraping should continue on individual failures
- No custom exception classes defined; uses Rails/Ruby standard errors
- Early returns used for nil-checking: `return if` pattern common
- Smoke tests verify code doesn't crash with bad input (see `test/scraping/scraping_smoke_test.rb`)
- Uses `assert_nothing_raised` to verify error handling
- Tests HTTP errors, timeouts, malformed data, network errors
- Expects `.to_timeout`, `.to_raise`, `.to_return(status: 500)` stubs
## Logging
- `Rails.logger` available everywhere
- Logs to `log/` directory
- Development logs in `log/development.log`
- Dedicated `DEBUG_LOGGER` in models needing detailed tracing
- Example: `Tournament` model has `DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")`
- Pattern: `DEBUG_LOGGER.error("Message: #{e.message}")`
- Errors logged with context on scraping failures
- No extensive info/debug logging visible (logs errors primarily)
- Log level management: `Sidekiq.logger.level = Logger::WARN`, `SolidQueue.logger.level = Logger::WARN` in tests
## Comments
- Class/model docstrings at top: comprehensive description of purpose and responsibilities
- Complex business logic: inline comments explaining "why" not "what"
- Inline comments for non-obvious code patterns (e.g., data structure layouts)
- TODO/FIXME comments sparse but present in codebase (search shows ~50 occurrences)
- Not used (Ruby project, no TypeScript)
- YARD documentation style possible but not enforced
- Schema annotations via `# == Schema Information` (auto-generated by `annotate` gem)
- Model class docstrings provide high-level explanation
## Function Design
- No hard limit enforced (Rubocop max 150 lines, but very permissive)
- Typical service methods: 10-30 lines
- Complex methods may reach 50-100+ lines without complaint
- Long models (Tournament) approach 500 line limit
- Keyword arguments used in services: `SearchService.new(model: @model, sort: @sort, ...)`
- Hash unpacking common in ApplicationService: `def self.call(kwargs = {})`
- Optional parameters with defaults: `belongs_to :region, optional: true`
- Method signatures may have many parameters (limit raised to 15 by Rubocop)
- Implicit return (last expression) is standard
- Explicit `return` used for early exits
- Nil returns acceptable for optional/failure cases
- Rails patterns: `first_or_create`, `where(...).first || create!(...)`
## Module Design
- Standard Rails: models export via class definition, services via `.call` class method
- Concerns include via `include ConcernName` in model/controller
- No explicit export declarations (implicit via public methods)
- Not used in this project
- Each model/service is individual file
- Concerns kept separate and included as needed
- Located in `app/models/concerns/`, `app/controllers/concerns/`
- Mixins follow naming convention: `LocalProtector`, `SourceHandler`, `Searchable`, etc.
- Applied consistently to related models (e.g., `LocalProtector`, `SourceHandler` on both `Player` and `Tournament`)
- All services inherit from `ApplicationService`
- Single public method: `def call`
- Invoked via: `ServiceName.call(params_hash)` or `ServiceName.new(params).call`
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- Traditional Rails layered architecture with services layer
- Real-time updates using ActionCable for synchronous WebSocket communication
- StimulusReflex for client-side interactivity without full page reloads
- Background job processing via ActiveJob with Sidekiq
- Multi-domain support (tournament management, player profiles, scoring, streaming)
- Internationalization support (German/English)
## Layers
- Purpose: HTTP request handling and view rendering
- Location: `app/views/`, `app/controllers/`
- Contains: ERB templates, controller action handlers
- Depends on: Models, Services, Concerns
- Used by: HTTP/WebSocket clients (browsers)
- Purpose: Bidirectional WebSocket communication for live updates
- Location: `app/channels/`, `app/javascript/channels/`
- Contains: Channel subscriptions, streaming updates via CableReady
- Depends on: Models, Services
- Used by: Browser clients for real-time scoreboard, tournament, table monitor data
- Purpose: Server-side handling of client interactions without full page reload
- Location: `app/reflexes/`
- Contains: Reflex classes (ApplicationReflex, SearchReflex, PartyMonitorReflex, etc.)
- Depends on: Models, Services
- Used by: Stimulus.js controllers on client side
- Purpose: Complex multi-step operations and external integrations
- Location: `app/services/`
- Contains: Scrapers (UMB, Kozoom, SoopLive, YouTube), Translation services (DeepL, OpenAI, Anthropic), PDF generation, Search
- Depends on: Models, external APIs
- Used by: Controllers, Jobs, Mailers, other services
- Purpose: ActiveRecord models representing domain entities and relationships
- Location: `app/models/`
- Contains: Core models (Club, Player, Tournament, Game, League, Party), association definitions, validations
- Depends on: Database, Concerns
- Used by: Controllers, Services, Jobs
- Purpose: Admin interface for managing application data
- Location: `app/dashboards/`
- Contains: Administrate field definitions for CRUD operations
- Depends on: Models, Administrate gem
- Used by: Admin controllers (via Administrate)
- Purpose: Asynchronous background processing
- Location: `app/jobs/`
- Contains: Scheduled jobs (daily scrapes), event-driven jobs (table monitor, streaming)
- Depends on: Models, Services
- Used by: Rails scheduler (Sidekiq-scheduler), event triggers
## Data Flow
- Models are source of truth stored in PostgreSQL
- Redis caches ActionCable subscriptions and CableReady broadcasts
- User preferences stored in User.preferences (JSON column)
- Application config from `config/carambus.yml` (managed via admin interface)
## Key Abstractions
- Purpose: Provides unified search interface across domain models
- Examples: `app/models/concerns/searchable.rb`
- Pattern: Models define text_search_sql, search_joins, field_examples; ApplicationController uses parse_search_string
- Purpose: Push DOM updates from server to connected clients
- Examples: Included in ApplicationRecord, ApplicationJob, ApplicationController
- Pattern: Models broadcast changes; views subscribe to channels
- Purpose: Handle client interactions server-side with DOM diffing
- Examples: `app/reflexes/party_monitor_reflex.rb`, `app/reflexes/game_protocol_reflex.rb`
- Pattern: Reflexes inherit ApplicationReflex, access current_user, manipulate models, CableReady renders
- Purpose: Prevent modification of global records on local development server
- Examples: Used in Club, Player, Game models
- Pattern: before_save hook blocks saves with id < MIN_ID on local server unless unprotected flag
- Purpose: Support multilingual content
- Examples: `app/models/concerns/translatable.rb`
- Pattern: Models can have translated fields stored in JSON or separate columns
- Purpose: Track geographical regions for resource filtering
- Examples: Club, Game, League models
- Pattern: Associates models with Region, used for search filtering
## Entry Points
- Location: `config/routes.rb`
- Triggers: HTTP requests to `/`
- Responsibilities: Route requests to controllers, define namespaces (admin, api, international)
- Location: Rails/Administrate auto-routing
- Triggers: `/admin/` route requests
- Responsibilities: CRUD operations on resources via dashboards
- Location: `app/channels/application_cable/connection.rb`
- Triggers: WebSocket connection establishment
- Responsibilities: Authenticate user, assign connection_token, identify by current_user
- Location: `config/schedule.rb`
- Triggers: Cron schedule or manual queuing
- Responsibilities: Scheduled scraping, monitoring, status updates
- Location: `app/controllers/api/`
- Triggers: `/api/` route requests
- Responsibilities: Autocomplete endpoints (players, locations), AI search, documentation search
## Error Handling
- Model validations raise ActiveRecord::RecordInvalid
- Controllers catch exceptions, redirect with flash messages
- Mailers catch errors, log instead of raising
- Jobs implement retry logic via ActiveJob retry_on directive
- Search failures fall back to empty results
- Scraper failures logged but don't block job execution
- `ErrorsController` (app/controllers/errors_controller.rb) handles 404/500
- Routes configured: `config.exceptions_app = routes`
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

| Skill | Description | Path |
|-------|-------------|------|
| scenario-management | Manages multi-tenant deployment workflow for Carambus project with multiple git checkouts. Use when working with carambus_master, carambus_bcw, carambus_phat, or carambus_api directories, when modifying code, committing changes, or when user mentions scenarios, deployments, or debugging mode. | `.agents/skills/scenario-management/SKILL.md` |
| extend-before-build | When adding a feature/addon to an existing codebase, prefer extending existing structures (legacy paths, predicates, lifecycles) with small guards over building parallel state machines. Refactoring for quality can come later. Use whenever introducing discipline-specific behavior, scoring rules, multiset variants, or any feature that overlaps with the legacy karambol path. | `.agents/skills/extend-before-build/SKILL.md` |
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->

<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
