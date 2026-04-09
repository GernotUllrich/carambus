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
