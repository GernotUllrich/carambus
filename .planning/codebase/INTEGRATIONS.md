# External Integrations

**Analysis Date:** 2026-04-09

## APIs & External Services

**Google Cloud:**
- Google Calendar API (v3)
  - What: Create and manage tournament calendar events
  - SDK/Client: `google-apis-calendar_v3` gem
  - Implementation: `app/services/google_calendar_service.rb`
  - Auth: Service account JSON credentials in Rails credentials
  - Scopes: `calendar`, `calendar.events`
  - Credentials location: `Rails.application.credentials[:google_service]`

- Google Translate API (Cloud Translation)
  - What: Multilingual content translation (video titles, documents)
  - SDK/Client: `google-cloud-translate` gem v3.7
  - Fallback: DeepL API with glossaries (primary for production)
  - Implementation: `app/services/ai_translation_service.rb` (Anthropic provider)

- YouTube Data API (v3)
  - What: Video metadata and channel information retrieval
  - SDK/Client: `google-apis-youtube_v3` gem
  - Use case: Scraping billard video content from YouTube channels
  - Job: `app/jobs/scrape_youtube_job.rb`

**AI & LLM Services:**
- OpenAI API (GPT-4o-mini)
  - What: Natural language search query processing, AI-powered search assistant
  - SDK/Client: `ruby-openai` gem v7.3
  - Implementation: `app/services/ai_search_service.rb`
  - Auth: API key via `Rails.application.credentials[:openai][:api_key]`
  - Model: `gpt-4o-mini` with JSON response format
  - Usage: Convert German natural language queries to structured filter syntax
  - Logging: Search queries and responses stored in `AiSearchLog` model
  - Location: `app/services/ai_search_service.rb`

- Anthropic Claude API (Claude 3 Sonnet)
  - What: Alternative LLM provider for translation and content generation
  - SDK/Client: Direct HTTP calls (Net::HTTP) - no official Ruby gem used
  - Implementation: `app/services/ai_translation_service.rb`
  - Auth: API key via `Rails.application.credentials[:anthropic_key]`
  - Endpoint: `https://api.anthropic.com/v1/messages`
  - Model: `claude-3-sonnet-20240229`
  - Usage: Billard-context-aware text translation with specialized terminology

**Translation Services:**
- DeepL API
  - What: Machine translation with billiard-specific glossaries
  - Auth: API key via `ENV['DEEPL_API_KEY']` or `Rails.application.credentials[:deepl_key]`
  - Implementation: `app/services/deepl_translation_service.rb`
  - Glossary Management: `app/services/deepl_glossary_service.rb`
  - Supported language pairs: DE↔EN, DE↔NL, DE↔FR, EN↔NL, EN↔FR
  - Features: Custom glossaries for billiard terminology, HTML entity decoding
  - Use cases: Tournament documents, training materials, web content

## Data Storage

**Databases:**
- PostgreSQL (primary)
  - Connection: Via `config/database.yml` or `DATABASE_URL`
  - Client: ActiveRecord (Rails ORM)
  - Databases: `carambus_api_development`, `carambus_api_test`
  - Features: ACID compliance, JSON support, full-text search
  - Setup: Adapter type `postgresql`, connection pool size 5

**File Storage:**
- Local filesystem (primary)
  - Service: `Disk` with paths defined in `config/storage.yml`
  - Locations:
    - General uploads: `Rails.root/storage/`
    - Training source files: `Rails.root/storage_local/` (local-only, not synced)
    - Test files: `Rails.root/tmp/storage/`
  - Via: Active Storage (Rails built-in)
  - Attachment types: PDFs, images, training materials

**Caching & Session Storage:**
- Redis
  - Purpose: Action Cable adapter, session storage, cache store (optional)
  - Connection: Via `REDIS_URL` env var or hardcoded defaults
  - Default URL: `redis://localhost:6379/{port}` (ports: 2=ActionCable, 3=sessions, 1=cache optional)
  - Client: `redis` gem v5.1+
  - Session storage: `redis-session-store` gem with error fallback handling
  - Configuration: `config/cable.yml`, `config/environments/development.rb`
  - Sidekiq: Background job queue (optional, configured in `config/sidekiq.yml`)

## Authentication & Identity

**Auth Provider:**
- Custom with Devise
  - Framework: Devise gem - local user authentication
  - Features: User registration, password reset, session management
  - Configuration: `config/initializers/devise.rb`
  - Routes: `devise_for :users` in `config/routes.rb`
  - Internationalization: `devise-i18n` gem (German, English)
  - Storage: User model with encrypted passwords (bcrypt)

**Authorization:**
- Pundit (policy-based)
  - What: Fine-grained resource authorization
  - Implementation: Policy classes in `app/policies/`
  - Scope-based access control per user role

- CanCanCan (role-based)
  - What: Capability-based authorization system
  - Gem: `cancancan` v3.5
  - Alternative to Pundit for simpler role scenarios

**User Impersonation:**
- Pretender gem v0.4
  - What: Admin ability to impersonate users for testing
  - Use case: Debug user-specific issues without sharing passwords

## Monitoring & Observability

**Error Tracking:**
- Not detected - No Sentry, Rollbar, or similar service
- Standard Rails logging to STDOUT in production
- Tagged logging with `request_id` for request tracing

**Logs:**
- STDOUT logging in production
- Log level: ENV `RAILS_LOG_LEVEL` (defaults to `info`)
- Development: File logging in `log/development.log`
- Structured: Request ID tagging for correlation

**Performance Monitoring:**
- Development tools available:
  - `rack-mini-profiler` - HTTP request profiling
  - `stackprof` - CPU and memory profiling
  - Neither enabled by default in production

## CI/CD & Deployment

**Hosting:**
- Self-hosted deployment (no Platform-as-a-Service)
- Docker containerization available via Dockerfile
- Base image: `ruby:3.2.1-slim` for minimal footprint

**Deployment Tool:**
- Capistrano 3.19.2 (traditional SSH-based deployment)
  - Capistrano plugins: bundler, rails, rbenv, puma, secrets-yml
  - Deployment command: Runs bundler, migrations, asset compilation

- Kamal (modern Docker container orchestration)
  - Alternative deployment method via Docker containers
  - Configuration: `config/deploy.yml` (exists)

**Scheduled Jobs:**
- Whenever gem (cron job management)
  - Configuration: `config/schedule.rb`
  - Deploy: `whenever --update-crontab` (install), `whenever --clear-crontab` (remove)
  - Jobs include: Video processing, tournament scraping, health checks, daily syncs

## Environment Configuration

**Required Environment Variables:**
- `REDIS_URL` - Redis connection string (e.g., `redis://localhost:6379/2`)
- `DEEPL_API_KEY` - DeepL translation API authentication
- `OPENAI_API_KEY` - OpenAI API authentication (via Rails credentials)
- `SMTP_USERNAME` - Gmail address for email delivery
- `SMTP_PASSWORD` - Gmail app-specific password for SMTP
- `RAILS_MASTER_KEY` - Master decryption key for credentials files
- `RAILS_LOG_LEVEL` - Log verbosity (default: `info`)

**Encrypted Credentials:**
- Per-environment encrypted files in `config/credentials/`
  - Development: `development.yml.enc` + `development.key`
  - Test: `test.yml.enc` + `test.key`
  - Production: `production.yml.enc` + `production.key`
- Contents (examples):
  - `google_service:` (service account JSON)
  - `openai:` (API key)
  - `anthropic_key:` (API key)
  - `deepl_key:` (API key)
  - `location_calendar_id:` (Google Calendar ID)
  - SMTP credentials (fallback location)

**Secrets Location:**
- `.env` file symlinked to Docker compose env file (development)
- `.env.carambus_local` - Local overrides (not committed)
- `config/credentials/` - Encrypted Rails credentials (committed)
- Environment variables - For runtime secrets in production

## Webhooks & Callbacks

**Incoming Webhooks:**
- Not detected in codebase
- ActionMailbox configured but not actively used for inbound emails

**Outgoing Integrations:**
- Google Calendar: Event creation and updates (outbound API calls)
- Email delivery: SMTP to Gmail (asynchronous via Active Job)
- Tournament scraping: HTTP requests to external tournament platforms
  - Services: `app/services/kozoom_scraper.rb`, `cuesco_scraper.rb`, `sooplive_scraper.rb`
  - Pattern: Net::HTTP direct calls with SSL bypass option in development
- YouTube: Video metadata retrieval (outbound API)

## External Data Sources

**Tournament Data Sources:**
- Kozoom (platform scraping)
  - Implementation: `app/services/kozoom_scraper.rb`
  - Method: HTTP GET requests with HTML parsing

- CUESCO (tournament platform)
  - Implementation: `app/services/cuesco_scraper.rb`
  - Method: HTTP scraping

- SoopLive (live tournament streaming)
  - Implementation: `app/services/sooplive_scraper.rb`
  - Method: HTTP scraping

- UMB Archive (German tournament federation data)
  - Tasks: `lib/tasks/scrape_umb_job.rb`, `scrape_umb_archive_job.rb`

**Video Content:**
- YouTube channels (billard tutorial and competition videos)
- Metadata extraction: `app/jobs/scrape_youtube_job.rb`
- Translation: Video titles translated to German via Google/Claude
- OCR for images: Tesseract-based text extraction

## Data Formats & Serialization

**API Response Format:**
- JSON (via Jbuilder templates)
- HTML (traditional Rails views)

**Interchange:**
- PDF: Generation and parsing
- CSV/Excel: Potentially for data export (not detected in core code)
- YAML: Configuration files and translation files

---

*Integration audit: 2026-04-09*
