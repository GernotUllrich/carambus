# Codebase Concerns

**Analysis Date:** 2026-04-09

## Tech Debt

**Oversized Model Classes:**
- Issue: Multiple model classes exceed 2000+ lines, containing both business logic and relationships in monolithic files
- Files: 
  - `app/models/table_monitor.rb` (3903 lines, 96 methods)
  - `app/models/region_cc.rb` (2728 lines)
  - `app/models/league.rb` (2219 lines)
  - `app/models/tournament.rb` (1775 lines)
- Impact: Difficult to maintain, test, and modify. Complex state management in TableMonitor affects reflex interactions. Risk of unintended side effects when changing behavior.
- Fix approach: Extract service classes for specific domains (e.g., `TableMonitorStateManager`, `TournamentStatusUpdater`), use composition over inheritance, split models into smaller concerns

**Duplicate Scraper Implementations:**
- Issue: Multiple scraper versions exist for same data sources (UmbScraper vs UmbScraperV2)
- Files:
  - `app/services/umb_scraper.rb` (2133 lines)
  - `app/services/umb_scraper_v2.rb` (585 lines)
- Impact: Code duplication, maintenance burden, inconsistent behavior, version confusion when integrating
- Fix approach: Consolidate into single UmbScraper using strategy pattern for different parsing approaches, version internal implementation only

**Hardcoded Configuration:**
- Issue: Configuration values scattered through code (constants, magic numbers, environment-dependent logic)
- Files: Multiple models and services contain hardcoded IDs, timeouts, and business rules
- Example: `League.rb` line 68: `DBU_ID = Region.find_by_shortname("DBU").id.freeze` - runs at class load time
- Impact: Difficult to manage multiple environments, environment-specific behavior scattered throughout codebase, risky modifications
- Fix approach: Centralize all configuration in `config/carambus.yml.erb`, load at boot time, avoid database queries during class definition

**Serialized YAML Columns:**
- Issue: Use of serialized YAML for complex data storage in `game_parameters` and other fields
- Files: `app/models/league.rb`, `app/models/table_monitor.rb`, many others
- Impact: Type safety problems, migrations difficult, no schema validation, data integrity risks, hard to query
- Fix approach: Migrate to structured JSON columns with schema validation, create separate tables for complex nested data

**Rails Version at Beta:**
- Issue: Application uses Rails 7.2.0.beta2 (beta, not stable)
- File: `Gemfile` line 10
- Impact: Risk of breaking changes, incompatible gem updates, unsupported in production, security vulnerabilities may not be patched
- Fix approach: Upgrade to stable Rails 7.2.x release once available, test thoroughly before production deployment

**Disabled SSL Verification in Development:**
- Issue: SSL verification disabled in development environment for external API calls
- File: `app/services/umb_scraper_v2.rb` line 65: `http.verify_mode = OpenSSL::SSL::VERIFY_NONE if Rails.env.development?`
- Impact: Masked SSL errors, potential for MITM attacks in development, inconsistent behavior between environments
- Fix approach: Use proper certificate management or self-signed certificate handling, avoid disabling verification

## Known Bugs

**Database Configuration Syntax Error:**
- Symptoms: Database configuration file contains duplicate `test:` blocks and malformed YAML
- Files: `config/database.yml` lines 14-18
- Trigger: Database initialization or migration attempts
- Impact: Potential connection pool initialization failure, migrations may not run properly
- Fix: Remove duplicate test configuration block, ensure valid YAML syntax

**HTTP Timeout Not Properly Handled:**
- Issue: External API calls use 30-second timeout but missing timeout exception handling in some cases
- Files: `app/services/umb_scraper.rb`, `app/services/umb_scraper_v2.rb`
- Trigger: When external APIs are slow or unresponsive
- Workaround: Retry logic in job queues, but timeout errors not consistently caught in all scraper methods
- Fix: Add proper timeout rescue blocks, implement exponential backoff retry strategy

## Security Considerations

**ActionCable Forgery Protection Disabled:**
- Risk: WebSocket connections can bypass CSRF protection
- Files: `config/application.rb` line 119: `config.action_cable.disable_request_forgery_protection = true`
- Current mitigation: Allowed request origins regex allows both http and https
- Recommendations: 
  - Re-enable CSRF protection for ActionCable if scoreboards authenticate via session
  - Document why this was disabled (appears to be for scoreboard connections)
  - Consider implementing origin validation for public scoreboards
  - Ensure WebSocket connections authenticate users properly before trusting them

**Broad ActionCable Origin Validation:**
- Risk: Regex `/http:\/\/.*/ and /https:\/\/.*/` allows any origin
- Files: `config/application.rb` line 118
- Current mitigation: None visible
- Recommendations:
  - Restrict to known domains/IPs
  - Use specific hostname validation instead of catch-all regex
  - Implement origin header validation for scoreboards

**Credentials File Modified Recently:**
- Issue: Production credentials file (`config/credentials/production.yml.enc`) modified 2 days ago (Feb 27)
- Files: `config/credentials/production.yml.enc`
- Risk: Possible credential rotation or secret exposure
- Recommendations:
  - Review what changed in production credentials
  - Verify no secrets were leaked
  - Implement credential rotation policy if secrets were exposed

**Unencrypted Local File Storage:**
- Risk: Active Storage configured to use local filesystem
- Files: `config/environments/production-carambus-de.rb` line 40: `config.active_storage.service = :local`
- Impact: Uploaded files stored on single server, no redundancy, backup required for disaster recovery
- Recommendations:
  - Use cloud storage (S3, GCS) for production
  - Implement file access controls
  - Add virus scanning for uploaded files

**Excessive Debug Logging in Production:**
- Issue: DEBUG constants and debug logging throughout critical code paths
- Files: 
  - `app/models/table_monitor.rb` line 39: `DEBUG = Rails.env != "production"`
  - `app/reflexes/table_monitor_reflex.rb` line 25: `DEBUG = true` (always enabled)
  - Many logging statements with emoji indicators
- Impact: Production logs bloated with unnecessary output, potential PII leakage, performance impact
- Recommendations:
  - Remove or conditionally disable DEBUG=true in reflexes
  - Use Rails.logger levels (info, debug, warn) appropriately
  - Review logs for sensitive data (player names, match results)

**No Input Validation on External API Data:**
- Issue: Data scraped from external sources (UMB, ClubCloud) not validated before storage
- Files: `app/services/umb_scraper.rb`, `app/services/umb_scraper_v2.rb`, `app/services/seeding_list_extractor.rb`
- Impact: Invalid data corrupts database, no protection against malformed HTML/PDF
- Recommendations:
  - Add schema validation for scraped data
  - Implement data sanitization before database insert
  - Add try/catch around HTML/PDF parsing with error logging

## Performance Bottlenecks

**Synchronous External API Calls in Request/Response Cycle:**
- Problem: Scraping operations called from controllers/jobs synchronously
- Files: Multiple scraper services called from `Region` controller actions
- Cause: UMB and ClubCloud API calls can take 10-30+ seconds
- Impact: Request timeout risk, poor user experience, database pool exhaustion
- Improvement path: 
  - Move all scraping to background jobs with Sidekiq
  - Implement async status polling UI
  - Add webhook support for completion notifications
  - Cache scraping results with TTL

**N+1 Query Risk in Views:**
- Problem: Complex object graphs (tournaments → games → seedings → players) may cause N+1 queries
- Files: Model relationships defined but includes/eager loading not consistently used
- Impact: Page load performance degrades with data volume
- Improvement path:
  - Audit queries in high-traffic views
  - Add eager loading with `.includes()` in controllers
  - Add query analyzer middleware in development
  - Cache frequently accessed relationships

**Unscoped Database Queries:**
- Problem: Some models load global context data without filtering by region/location
- Files: `app/models/club.rb` and others have `global_context` flag but usage unclear
- Impact: Data pollution from multiple tournaments/regions shown simultaneously
- Improvement path:
  - Document scope requirements per model
  - Add default_scope when appropriate (with caution)
  - Audit all select/where queries for missing filters

**Reflex Callback Bloat in TableMonitor:**
- Problem: Complex `after_update_commit` callbacks with conditional logic and multiple broadcasts
- Files: `app/models/table_monitor.rb` lines 75-100+
- Impact: Slow save operations, potential race conditions, difficult to debug
- Improvement path:
  - Extract callback logic into service classes
  - Use transaction callbacks sparingly
  - Batch similar operations together
  - Consider event sourcing for complex state transitions

**PDF Processing Without Streaming:**
- Problem: PDF files loaded entirely into memory for parsing
- Files: `app/services/umb_scraper.rb`, tournament invitation parsing
- Impact: Memory spikes during tournament parsing, OOM crashes with large PDFs
- Improvement path:
  - Stream PDF processing
  - Implement pagination for large documents
  - Add memory limits with graceful degradation

## Fragile Areas

**Table Monitor State Machine:**
- Files: `app/models/table_monitor.rb` (3903 lines, AASM state machine)
- Why fragile: 
  - 96 methods in single class
  - Complex callback dependencies
  - Reflex interactions not well isolated
  - State transitions not visually documented
  - `skip_update_callbacks` flag is dangerous workaround
- Safe modification:
  - Use state machine diagram before changes
  - Add integration tests for state transitions
  - Extract reflex logic into separate service
  - Document callback order and dependencies
- Test coverage: Gaps in edge cases (game cancellation, timer interruption)

**Region and ClubCloud Integration (RegionCc):**
- Files: `app/models/region_cc.rb` (2728 lines), `app/models/club.rb`, `app/models/league.rb`
- Why fragile:
  - Deeply nested synchronization with external ClubCloud system
  - Complex data transformation (leagues, teams, players)
  - Manual HTTP requests with raw response parsing
  - Many "check" and "fix" endpoints suggesting data inconsistencies
  - Routes suggest patching data issues (line 119-137 in routes.rb)
- Safe modification:
  - Never modify scraping logic without end-to-end test against test ClubCloud instance
  - Document ClubCloud API format changes
  - Implement data validation before sync
  - Version sync procedures
- Test coverage: ClubCloud sync tests use VCR snapshots (good), but actual API changes could break

**Seeding and Tournament Organization:**
- Files: `app/models/tournament.rb`, `app/models/tournament_plan.rb`, seeding services
- Why fragile:
  - 1775-line Tournament model with complex game plan generation
  - Multiple tournament types with different rules
  - Seeding calculation affects all downstream games
  - No validation that seeding matches game count
- Safe modification:
  - Create comprehensive fixture with different tournament types
  - Test seeding generation before deployment
  - Validate game count after seeding changes
- Test coverage: Tournament-specific tests exist but coverage incomplete for edge cases

**PDF/Image Processing for Invitations:**
- Files: `app/services/seeding_list_extractor.rb` (534 lines), PDF parsing via rtesseract
- Why fragile:
  - Relies on OCR for image-based documents (error-prone)
  - PDF parsing uses multiple libraries (pdf-reader, Nokogiri, rtesseract)
  - No validation that extracted data matches document intent
  - File upload handling vulnerable to large files
- Safe modification:
  - Implement sample file testing framework
  - Add validation that extracted player count matches tournament format
  - Implement file size limits
  - Add user confirmation step before applying extracted data
- Test coverage: No visible tests for extraction

**International Tournament Integration:**
- Files: Multiple scrapers for external data (UMB, Cuesco, YouTube, OpenAI search)
- Why fragile:
  - Depends on external API formats staying stable
  - No fallback when external services unavailable
  - AI search uses OpenAI API (cost, rate limits)
  - Video metadata scraping fragile to HTML changes
- Safe modification:
  - Implement feature flags for each scraper
  - Add circuit breaker pattern for external APIs
  - Cache external data aggressively
  - Monitor external API health
- Test coverage: Uses VCR snapshots (good), but real API changes not caught until production

## Scaling Limits

**Database Pool Size:**
- Current capacity: Pool size 5 (config/database.yml)
- Limit: With 364+ model classes and frequent associations, pool exhaustion possible during high concurrency
- Scaling path:
  - Increase pool size per load testing results
  - Implement connection pooling middleware
  - Use read replicas for read-heavy operations
  - Migrate to connection pooling service (PgBouncer)

**ActionCable Broadcast Inefficiency:**
- Current capacity: Broadcasts triggered for every table monitor update
- Limit: Large tournaments with many simultaneous tables can saturate ActionCable
- Scaling path:
  - Implement broadcast batching (collect changes over 100ms window)
  - Use room-scoped subscriptions instead of individual broadcasts
  - Implement message compression
  - Consider separate ActionCable server process

**Active Storage Attachment Handling:**
- Current capacity: Files stored locally, no sharding
- Limit: Single server storage capacity reached
- Scaling path:
  - Migrate to S3 or cloud storage
  - Implement CDN for static files
  - Implement file cleanup/archival for old tournaments

**Gemfile Dependencies Count:**
- Current capacity: 50+ gems loaded
- Limit: Boot time, memory usage, security vulnerabilities
- Scaling path:
  - Audit unused gems
  - Lazy-load optional gems
  - Consider lighter alternatives (e.g., replace andand with safe navigation)

## Dependencies at Risk

**Commented Out `debug` Gem:**
- Risk: Standard Rails debugging disabled
- Files: `Gemfile` lines 55-57 (commented out, incompatible with debase)
- Impact: Developers resort to console debugging, productivity impact
- Migration plan: Implement proper debugging setup for RubyMine with debase, or use alternative debugger (pry-byebug)

**Custom i18n YAML Sort Library:**
- Risk: Uses GitHub custom fork
- Files: `Gemfile` line 97: `gem "i18n_yaml_sort", git: "https://github.com/GovTechSG/i18n_yaml_sort.git"`
- Impact: No version guarantee, maintenance risk if fork abandoned
- Migration plan: Monitor fork for updates, consider vendoring if active development stops

**Ruby Version Lock:**
- Risk: .ruby-version file not inspected
- Impact: Version skew between development and production possible
- Recommendation: Pin exact Ruby version, document upgrade procedure

**OpenAI Dependency:**
- Risk: API key required, rate limits, costs
- Files: `Gemfile` line 169: `gem 'ruby-openai', '~> 7.3'`
- Impact: If OpenAI API changes or service unavailable, AI features break
- Recommendation: Implement fallback search mechanism, cache AI responses, monitor API health

**rtesseract OCR Library:**
- Risk: Requires system tesseract installation
- Files: `Gemfile` line 178
- Impact: Docker builds fail if tesseract not included, deployment risk
- Recommendation: Document tesseract system package requirement, add to deployment scripts

**Andand Gem:**
- Risk: Provides `&.` safe navigation syntax, deprecated in modern Ruby
- Files: `Gemfile` line 14: `gem "andand"`
- Impact: Safe navigation now built-in to Ruby (`.&.`), gem unnecessary and adds dependency
- Recommendation: Remove gem, refactor to use Ruby 2.3+ safe navigation operator

## Missing Critical Features

**Error Tracking/Alerting:**
- Problem: No visible error tracking integration (Sentry, Rollbar, etc.)
- Blocks: Difficult to debug production issues, no automated alerting for crashes
- Recommendation: Implement error tracking service, add error monitoring dashboard

**Database Backup Strategy:**
- Problem: No documented backup strategy
- Blocks: Data loss risk, disaster recovery impossible
- Recommendation: Implement automated PostgreSQL backups, test restore procedure

**Request Tracing/Observability:**
- Problem: Request IDs logged but no distributed tracing across services
- Blocks: Difficult to trace request flow through multiple jobs/services
- Recommendation: Implement X-Request-ID propagation, consider OpenTelemetry

**Rate Limiting:**
- Problem: No visible rate limiting on public endpoints
- Blocks: API abuse possible, DOS vulnerability
- Recommendation: Implement rate limiting middleware, especially for scraping endpoints

**Audit Logging:**
- Problem: Paper Trail configured for versioning but no audit logging
- Blocks: Cannot track who changed what in admin actions
- Recommendation: Implement comprehensive audit logging for admin actions

## Test Coverage Gaps

**Table Monitor Integration Tests:**
- What's not tested: State transitions during live game, reflex interactions with multiple simultaneous updates, callback firing order
- Files: `app/models/table_monitor.rb`, `app/reflexes/table_monitor_reflex.rb`
- Risk: Regressions in scoreboard functionality go undetected until production
- Priority: **High**

**ClubCloud Synchronization Edge Cases:**
- What's not tested: Sync recovery after API failure, data inconsistency resolution, large league synchronization
- Files: `app/models/region_cc.rb`, related league/team sync
- Risk: Data corruption during sync failures, orphaned records
- Priority: **High**

**PDF/Image Extraction Accuracy:**
- What's not tested: OCR accuracy with different document formats, PDF parsing with complex layouts, error handling for corrupted files
- Files: `app/services/seeding_list_extractor.rb`
- Risk: Incorrect tournament setup from misread invitations
- Priority: **High**

**External Scraper Resilience:**
- What's not tested: Behavior when external APIs return invalid data, partial data, or no data
- Files: `app/services/umb_scraper.rb`, other scrapers
- Risk: Incomplete or corrupted tournament data silently stored
- Priority: **Medium**

**Reflex Concurrent Update Handling:**
- What's not tested: Multiple simultaneous reflex calls, race conditions between reflex and job updates
- Files: `app/reflexes/*_reflex.rb`
- Risk: Inconsistent state in UI, data conflicts
- Priority: **Medium**

**API Parameter Validation:**
- What's not tested: Invalid parameters, missing required fields, type mismatches
- Files: `app/controllers/api/*_controller.rb`
- Risk: Unexpected behavior, potential injection attacks
- Priority: **Medium**

**Translation System Edge Cases:**
- What's not tested: Missing translations, circular references, language fallback behavior
- Files: `config/locales/**/*.yml`
- Risk: UI broken for specific languages, untranslated content visible
- Priority: **Low**

---

*Concerns audit: 2026-04-09*
