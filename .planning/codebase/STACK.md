# Technology Stack

**Analysis Date:** 2026-04-09

## Languages

**Primary:**
- Ruby 3.2.1 - Core application language for Rails backend

**Secondary:**
- ERB (Embedded Ruby) - Template language for views and dynamic configuration
- JavaScript/ES6 - Frontend interactivity (via Stimulus.js and Turbo)

## Runtime

**Environment:**
- Ruby 3.2.1 (specified in `.ruby-version`)

**Package Manager:**
- Bundler 2.7.2 - Ruby gem dependency management
- Lockfile: Present (`Gemfile.lock` - must be kept synchronized)

## Frameworks

**Core:**
- Rails 7.2.0.beta2 - Full-stack web framework with ORM, routing, and template engine
- Turbo Rails 2.0.11 - SPA-like page acceleration with WebSocket support
- Stimulus Rails 1.0.2+ - Lightweight JavaScript framework for interactivity
- StimulusReflex 3.5.3 - Real-time reactive updates via WebSocket
- Cable Ready 5.0.6 - Broadcast updates over Action Cable

**Web Server:**
- Puma 6.6 - Multi-threaded HTTP server for production and development

**Database ORM:**
- ActiveRecord (included with Rails) - SQL query builder and ORM for PostgreSQL
- Strong Migrations 0.7.6 - Safety checks for database migrations in production

**Testing:**
- Capybara 3.39+ - Integration testing with browser simulation
- Selenium WebDriver 4.20.1+ - Browser automation for system tests
- FactoryBot Rails - Test data factory library
- Shoulda Matchers - RSpec-style assertions
- WebMock - HTTP request mocking for tests
- VCR - Record/replay HTTP interactions for deterministic tests
- SimpleCov - Code coverage analysis (informational, not enforced)

**Build & Asset Pipeline:**
- Sprockets Rails 3.4.1+ - Asset compilation and serving
- ImportMap Rails 1.1 - ES module import mapping without bundlers
- Jbuilder 2.12 - JSON template builder for API responses

## Key Dependencies

**Critical:**
- pg (PostgreSQL) - Database adapter for ActiveRecord
- redis 5.1+ - In-memory data store for caching and real-time features
- redis-session-store 0.11.5 - Session persistence in Redis
- paper_trail 15.2 - Audit trail and versioning for model changes

**Authentication & Authorization:**
- devise - User authentication framework (local and session-based)
- devise-i18n 1.10 - Internationalization for Devise views
- pundit 2.1 - Authorization framework for policy-based access control
- cancancan 3.5 - Role-based access control (CanCan)
- pretender 0.4 - Admin impersonation for testing user flows
- invisible_captcha 2.0 - Anti-spam honeypot CAPTCHA

**Admin & Content Management:**
- administrate 0.19.0 - Admin dashboard for model management
- pagy 9.3 - Pagination for large datasets (more efficient than Kaminari)

**Google APIs:**
- google-apis-calendar_v3 0.5.0 - Google Calendar event creation/management
- google-apis-youtube_v3 0.40.0 - YouTube video metadata retrieval
- google-cloud-translate 3.7 - Google Cloud Translation API for multilingual content
- gcal-ruby 0.1.0 - Simplified Google Calendar interaction

**AI & NLP:**
- ruby-openai 7.3 - OpenAI API client for GPT-4 integration (search and translation)
- Note: Anthropic API support via direct HTTP calls in `AiTranslationService`

**Translation:**
- i15r 0.5.1 - i18n key extraction tool
- i18n_yaml_sort (custom gem from GitHub) - YAML translation file organization
- rails-i18n - Internationalization locale data and defaults

**PDF & Document Processing:**
- pdf-reader 2.12 - PDF text extraction for tournament invitation parsing
- prawn 2.4 - PDF generation for game protocols
- prawn-table 0.2 - Table support in Prawn-generated PDFs
- rtesseract 3.1 - OCR text extraction from images (requires tesseract-ocr system package)
- image_processing 1.14 - Image variants and transformations
- nokogiri 1.12.5+ - HTML/XML parsing (security update)

**Utilities:**
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

**Development Tools:**
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

**Scheduled Jobs:**
- whenever - Cron job management and scheduling (note: config uses async queue adapter in development)
- Sidekiq configuration available (`config/sidekiq.yml`) but queue adapter set to `:async` by default in development

## Configuration

**Environment:**
- Configuration via `config/carambus.yml` (YAML with ERB templating)
- Environment-specific settings in `config/environments/`
- Encrypted credentials per environment: `config/credentials/{environment}.yml.enc`
- Session storage via Redis with fallback error handling
- Credentials encryption keys: `config/credentials/{environment}.key`

**Key Configurations Required:**
- `REDIS_URL` - Redis connection (defaults to `redis://localhost:6379/{port}`)
- `DEEPL_API_KEY` - DeepL translation API key (env var or Rails credentials)
- `OPENAI_API_KEY` - OpenAI API key (via Rails credentials)
- `SMTP_USERNAME` - Gmail SMTP username (production email delivery)
- `SMTP_PASSWORD` - Gmail SMTP password (production email delivery)
- Google service account credentials (JSON format in Rails credentials)
- Anthropic API key (optional, via Rails credentials)

**Build:**
- `database.yml` - ActiveRecord database configuration (PostgreSQL)
- `cable.yml` - Action Cable adapter configuration (Redis in production)
- `storage.yml` - Active Storage service configuration (local disk by default)
- `config/routes.rb` - Rails routing configuration with ActionCable mount
- `sidekiq.yml` - Sidekiq job queue configuration (concurrency, queues, timeout)

## Platform Requirements

**Development:**
- Ruby 3.2.1 (exact version via rbenv or similar)
- PostgreSQL (local or remote via DATABASE_URL)
- Redis server (for Action Cable, caching, session storage)
- Node.js 18+ (for yarn package management)
- Tesseract OCR system package (optional, for image text extraction)
- Google Chrome/Chromium (for table monitoring feature)
- Git for version control

**Production:**
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

---

*Stack analysis: 2026-04-09*
