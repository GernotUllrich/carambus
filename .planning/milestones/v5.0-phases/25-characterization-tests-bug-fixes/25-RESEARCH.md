# Phase 25: Characterization Tests & Bug Fixes - Research

**Researched:** 2026-04-12
**Domain:** UmbScraper / UmbScraperV2 characterization tests + three pre-existing bugs
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Claude's discretion on file organization — may use one file per scraper or split by concern depending on method count and complexity. Follow the pattern that best fits the UMB scraper's public API surface.
- **D-02:** Hybrid approach — record VCR cassettes against live UMB site where endpoints work (tournament details pages, future tournaments list), use crafted fixture HTML files for endpoints that returned HTTP 500 during Phase 24 probing (e.g., `/Reports/` paths).
- **D-03:** Cassette directory: `test/snapshots/vcr/umb/` following the established `test/snapshots/vcr/region_cc_*.yml` pattern.
- **D-04:** Interleave bugs and tests — write characterization tests for UmbScraper, fix bugs that block test setup as they arise, then write remaining tests. Don't force all bugs first or all tests first.
- **D-05:** The three bugs to fix are:
  1. `TournamentDiscoveryService` references non-existent `video.international_tournament_id` column — should use `video.update(videoable: tournament)` via polymorphic association
  2. `ScrapeUmbArchiveJob` passes `discipline:, year:, event_type:` but `scrape_tournament_archive` expects `start_id:, end_id:, batch_size:` — kwargs mismatch
  3. SSL verification inconsistency across scrapers — resolved via Umb::HttpClient (D-06)
- **D-06:** Extract `Umb::HttpClient` early (pulled forward from Phase 26 plan) as the single place for SSL configuration. Environment-guarded: `VERIFY_NONE` only in development/test, proper verification in production. Other scrapers (Kozoom, SoopLive) adopt the shared helper in their own refactoring phases — do NOT modify them in Phase 25.
- **D-07:** `Umb::HttpClient` is a PORO (not ApplicationService) — stateless HTTP helper with `fetch_url` method, matching the Phase 26 architecture plan.

### Claude's Discretion

- Test file naming and organization within the established conventions
- Which UmbScraper methods are "critical paths" worth characterizing vs low-value
- VCR cassette recording strategy per endpoint (live vs fixture)
- Order of interleaving between tests and bug fixes

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SCRP-01 | Characterization tests for UmbScraper critical paths (future tournaments, archive scan, detail page, PDF parsing) with VCR cassettes | Public method inventory below; VCR infrastructure fully mapped |
| SCRP-02 | Characterization tests for UmbScraperV2 critical paths with VCR cassettes | UmbScraperV2 has exactly one public method: `scrape_tournament` |
| SCRP-03 | Fix TournamentDiscoveryService `video.international_tournament_id` column reference | Bug confirmed: videos table has no such column; correct fix is `video.update(videoable: tournament)` |
| SCRP-04 | Fix ScrapeUmbArchiveJob keyword argument mismatch | Bug confirmed: job passes `discipline:/year:/event_type:`, method expects `start_id:/end_id:/batch_size:` |
| SCRP-05 | Fix SSL verification inconsistency across scrapers | Pattern mapped; `Umb::HttpClient` PORO resolves it for UMB scrapers only |
</phase_requirements>

---

## Summary

Phase 25 has two distinct workstreams: (1) writing VCR-backed characterization tests that pin existing behavior before Phase 26 extraction, and (2) fixing three silent bugs that already break production code paths. All three bugs are confirmed from direct code and schema inspection — no assumptions required.

UmbScraper (`app/services/umb_scraper.rb`, 2133 lines) has six public methods. Of those, `scrape_rankings` is a stub (always logs "not yet implemented" and returns 0), leaving five real critical paths to characterize. UmbScraperV2 (`app/services/umb_scraper_v2.rb`, 585 lines) has exactly one public method: `scrape_tournament`. All private methods in both files are test targets only indirectly through the public interface.

The established characterization test pattern from `test/characterization/region_cc_char_test.rb` is the direct template — same `with_vcr_cassette` guard, same `RECORD_VCR` env var, same skip behavior when cassettes are missing. The VCR infrastructure (WebMock + VCR gem) is already wired in `test/support/vcr_setup.rb` and loaded by `test_helper.rb`.

**Primary recommendation:** Follow the `region_cc_char_test.rb` pattern exactly. Create `test/characterization/umb_scraper_char_test.rb` and `test/characterization/umb_scraper_v2_char_test.rb`. Use `test/snapshots/vcr/umb/` for cassettes. Fix bugs as they arise during test writing.

---

## Standard Stack

No new dependencies for this phase. All required infrastructure is already present. [VERIFIED: codebase]

| Tool | Already Present | Purpose |
|------|----------------|---------|
| minitest | Yes | Test framework (CLAUDE.md mandates Minitest, not RSpec) |
| vcr gem (line 78 Gemfile) | Yes | VCR cassette recording/replay |
| webmock/minitest | Yes (test_helper.rb:31) | HTTP interception |
| pdf-reader | Yes (umb_scraper.rb requires it) | PDF text extraction |
| net/http + nokogiri + openssl | Yes | HTTP and HTML parsing already in scrapers |

**No `npm install` or `bundle install` needed.**

---

## Architecture Patterns

### Established Characterization Test Pattern [VERIFIED: test/characterization/region_cc_char_test.rb]

```ruby
# frozen_string_literal: true
require "test_helper"

class UmbScraperCharTest < ActiveSupport::TestCase
  VCR_RECORD_MODE = ENV["RECORD_VCR"] ? :new_episodes : :none

  def cassette_exists?(name)
    File.exist?(Rails.root.join("test", "snapshots", "vcr", "#{name}.yml"))
  end

  def with_vcr_cassette(name, &block)
    if VCR_RECORD_MODE == :none && !cassette_exists?(name)
      skip "VCR cassette '#{name}.yml' missing. Record with: RECORD_VCR=true bin/rails test test/characterization/umb_scraper_char_test.rb"
    end
    VCR.use_cassette(name, record: VCR_RECORD_MODE, &block)
  end

  setup do
    # UmbScraper#initialize calls InternationalSource.find_or_create_by!
    # Need international_source fixture OR database setup
    @scraper = UmbScraper.new
  end
end
```

### Cassette Directory Convention [VERIFIED: D-03, region_cc cassette names]

- Existing cassettes use flat names: `region_cc_http_get.yml`, `region_cc_sync_tournaments.yml`
- Phase 25 cassettes go in `test/snapshots/vcr/umb/` subdirectory per D-03
- Naming pattern: `umb/scraper_future_tournaments.yml`, `umb/scraper_detail_page_NNN.yml`, `umb/scraper_archive_scan.yml`

### Fixture HTML for Broken Endpoints [VERIFIED: test/fixtures/html/ exists with club_cloud fixtures]

The project already uses `test/fixtures/html/` for HTML fixture files (confirmed: `tournament_details_nbv_870.html`, `tournament_list_nbv_2025_2026.html`). For UMB endpoints that return HTTP 500 in production (the `/Reports/` paths per Phase 24 findings), craft minimal fixture HTML matching the real page structure and use `WebMock` to stub those URLs with the fixture content.

```ruby
# Pattern for fixture-backed test (when VCR recording is not viable)
test "scrape_tournament_details handles missing PDF links" do
  fixture_html = File.read(Rails.root.join("test", "fixtures", "html", "umb_tournament_detail_123.html"))
  stub_request(:get, /TournametDetails\.aspx/)
    .to_return(status: 200, body: fixture_html, headers: { "Content-Type" => "text/html" })
  # ...assert behavior...
end
```

### Umb::HttpClient PORO Pattern [VERIFIED: D-07, RegionCc::ClubCloudClient as model]

The `RegionCc::ClubCloudClient` in `app/services/region_cc/club_cloud_client.rb` is the exact structural model:
- Namespace matches service directory: `app/services/umb/http_client.rb` -> `Umb::HttpClient`
- PORO: no `< ApplicationService` inheritance
- Stateless: single `fetch_url` entry point
- Environment-guarded SSL: `VERIFY_NONE` only in `development? || test?`

Current SSL inconsistency across UMB scrapers [VERIFIED: grep]:
- `umb_scraper.rb:489` — `VERIFY_NONE if Rails.env.development?` (also line 1567)
- `umb_scraper_v2.rb:65` — `VERIFY_NONE if Rails.env.development?`
- `kozoom_scraper.rb:27,129` — unconditional `VERIFY_NONE` (do NOT touch in Phase 25)
- `sooplive_scraper.rb:137` — unconditional `VERIFY_NONE` (do NOT touch in Phase 25)

```ruby
# app/services/umb/http_client.rb
# frozen_string_literal: true

# Stateless HTTP transport for UMB scrapers.
# SSL verification is environment-guarded: VERIFY_NONE only in development/test.
class Umb::HttpClient
  TIMEOUT = 30

  def fetch_url(url, follow_redirects: true, max_redirects: 5)
    # ... extract from UmbScraperV2#fetch_url (lines 57-91)
    # ssl_verify = Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end
end
```

---

## Public Method Inventory

### UmbScraper — Public Methods [VERIFIED: umb_scraper.rb line 478 = `private` boundary]

All methods defined before `private` at line 478 are public:

| Method | Signature | Critical Path? | Test Strategy |
|--------|-----------|----------------|---------------|
| `initialize` | no args | YES (side effect: finds/creates InternationalSource) | Unit — assert `@umb_source` set |
| `detect_discipline_from_name` | `tournament_name` | MEDIUM | Unit — no HTTP, test discipline ID mapping |
| `scrape_future_tournaments` | no args | YES | VCR cassette — `umb/scraper_future_tournaments.yml` |
| `scrape_rankings` | `discipline_name:, year:` | NO (stub — always returns 0 with warn log) | Single test: assert returns 0 |
| `scrape_tournament_archive` | `start_id:, end_id:, batch_size:` | YES | VCR cassette — small range e.g. `start_id: 1, end_id: 3` |
| `fetch_tournament_basic_data` | `external_id` | YES | VCR cassette — `umb/scraper_basic_data_NNN.yml` |
| `save_tournament_from_details` | `data` (hash) | MEDIUM | Unit — no HTTP, test DB record creation |
| `scrape_tournament_details` | `tournament_id_or_record, create_games:, parse_pdfs:` | YES | VCR cassette — `umb/scraper_detail_page_NNN.yml` |

**5 real critical paths** (excluding the stub `scrape_rankings`): `scrape_future_tournaments`, `scrape_tournament_archive`, `fetch_tournament_basic_data`, `scrape_tournament_details`, and `initialize`.

### UmbScraperV2 — Public Methods [VERIFIED: umb_scraper_v2.rb line 54 = `private` boundary]

| Method | Signature | Critical Path? | Test Strategy |
|--------|-----------|----------------|---------------|
| `initialize` | no args | YES (same InternationalSource side effect) | Unit — shared with UmbScraper setup |
| `scrape_tournament` | `external_id` | YES | VCR cassette — `umb/scraper_v2_tournament_NNN.yml` |

**UmbScraperV2 has exactly one non-constructor public method.** All other methods (parse_tournament_details, save_tournament, scrape_pdfs_for_tournament, etc.) are private.

---

## Bug Analysis

### SCRP-03: TournamentDiscoveryService — Non-existent Column

**Location:** `app/services/tournament_discovery_service.rb`, line 216 [VERIFIED: direct inspection]

```ruby
# CURRENT (BROKEN):
def assign_videos_to_tournament(tournament, candidate)
  candidate[:videos].each do |video|
    if video.international_tournament_id != tournament.id  # NoMethodError or column missing
      video.update(international_tournament_id: tournament.id)  # ArgumentError: unknown attribute
      @videos_assigned += 1
    end
  end
end
```

**Root cause:** `videos` table has NO `international_tournament_id` column [VERIFIED: db/schema.rb lines 1507-1535]. The column only exists on the `tournaments` table (line 1350 in schema, a self-referencing `belongs_to :international_tournament` for some legacy purpose).

**Correct fix:** [VERIFIED: Video model line 46, CONTEXT.md D-05]
```ruby
def assign_videos_to_tournament(tournament, candidate)
  candidate[:videos].each do |video|
    unless video.videoable == tournament
      video.update(videoable: tournament)
      @videos_assigned += 1
    end
  end
end
```

**Note on `videoable_type`:** The `videoable` polymorphic association in the Video model accepts any model. `InternationalTournament` is a subclass of `Tournament` (STI), so `video.update(videoable: tournament)` will set `videoable_type = "InternationalTournament"` and `videoable_id = tournament.id`.

**Impact:** `DailyInternationalScrapeJob` calls `TournamentDiscoveryService#discover_from_videos` (line 61-63 in the job). Every call raises or silently fails at `assign_videos_to_tournament`, meaning Steps 4-5 of the daily job never complete. [VERIFIED: daily_international_scrape_job.rb lines 61-63]

### SCRP-04: ScrapeUmbArchiveJob — Kwargs Mismatch

**Location:** `app/jobs/scrape_umb_archive_job.rb`, lines 7-15 [VERIFIED: direct inspection]

```ruby
# CURRENT (BROKEN) — job signature:
def perform(discipline: '3-Cushion', year: nil, event_type: nil)
  scraper.scrape_tournament_archive(
    discipline: discipline,   # <- WRONG: method doesn't accept this kwarg
    year: year,               # <- WRONG: method doesn't accept this kwarg
    event_type: event_type    # <- WRONG: method doesn't accept this kwarg
  )
end

# METHOD SIGNATURE (correct):
def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)
```

**Exact fix:** The job's `perform` signature must change, and the call must use the correct kwargs. The job will raise `ArgumentError: unknown keyword: discipline` at runtime.

```ruby
# FIXED:
def perform(start_id: 1, end_id: 500, batch_size: 50)
  scraper.scrape_tournament_archive(
    start_id: start_id,
    end_id: end_id,
    batch_size: batch_size
  )
end
```

**Note on callers:** `lib/tasks/umb_update.rake` does NOT call `ScrapeUmbArchiveJob` — it uses `UmbScraper.new` directly. [VERIFIED: read of full umb_update.rake, 413 lines; grep confirms `ScrapeUmbArchiveJob` only appears in its own job file]. No rake task callers need updating.

### SCRP-05: SSL Verification via Umb::HttpClient

**UMB scraper SSL status** [VERIFIED: grep across all scraper files]:

| File | Location | Current SSL Guard | Status |
|------|----------|------------------|--------|
| `umb_scraper.rb` | line 489 (`fetch_url`) | `VERIFY_NONE if Rails.env.development?` | PARTIAL — misses test env |
| `umb_scraper.rb` | line 1567 (`download_pdf`) | `VERIFY_NONE if Rails.env.development?` | PARTIAL — misses test env; also duplicated logic |
| `umb_scraper_v2.rb` | line 65 (`fetch_url`) | `VERIFY_NONE if Rails.env.development?` | PARTIAL — misses test env |
| `kozoom_scraper.rb` | lines 27, 129 | unconditional `VERIFY_NONE` | OUT OF SCOPE for Phase 25 |
| `sooplive_scraper.rb` | line 137 | unconditional `VERIFY_NONE` | OUT OF SCOPE for Phase 25 |

The Phase 25 fix: create `Umb::HttpClient` with `Rails.env.development? || Rails.env.test?` guard, then update both `UmbScraper#fetch_url`, `UmbScraper#download_pdf`, and `UmbScraperV2#fetch_url` to delegate to it.

**Brakeman:** `brakeman` will flag unconditional `VERIFY_NONE` as a security warning. Environment-guarding resolves this for UMB scrapers.

---

## Test Infrastructure Map

### VCR Configuration [VERIFIED: test/support/vcr_setup.rb]

- Cassette library: `test/snapshots/vcr/` (relative to Rails.root)
- Adapter: webmock
- Default record mode: `:once` (record once, replay after)
- Localhost ignored
- Credential filtering for ClubCloud (password/username filtered); UMB has no credentials to filter
- `allow_playback_repeats: true` — safe for tests that call the same URL multiple times

**Phase 25 cassette path:** `test/snapshots/vcr/umb/` — requires creating the subdirectory.

### WebMock Configuration [VERIFIED: test_helper.rb lines 110-118]

```ruby
WebMock.disable_net_connect!({
  allow_localhost: true,
  allow: ["chromedriver.storage.googleapis.com", "api.stripe.com", "rails-app", "selenium"]
})
```

All UMB URLs (`files.umb-carom.org`, `www.umb-carom.org`) are blocked by WebMock. VCR cassettes satisfy WebMock by replaying recorded responses. Without cassettes, any test that triggers HTTP will raise `WebMock::NetConnectNotAllowedError`.

### Fixture Setup Requirement

`UmbScraper#initialize` calls `InternationalSource.find_or_create_by!(name: 'Union Mondiale de Billard', source_type: 'umb')`. No `international_sources` fixture file exists yet [VERIFIED: test/fixtures/ file list].

**Two options:**
1. Create `test/fixtures/international_sources.yml` with a UMB record
2. In `setup` block, use `InternationalSource.find_or_create_by!` directly (no fixture needed)

Recommendation: option 2 (setup block) avoids adding a fixture file when test_helper already loads `fixtures :all` — adding an `international_sources.yml` fixture would affect all tests, but `InternationalSource` may not have the required columns in a minimal fixture. Better to create the record in `setup` and destroy in `teardown`.

However, `UmbScraper#initialize` will also call `InternationalSource.find_or_create_by!` with `source.base_url = BASE_URL` and `source.metadata = {...}`. This requires the `international_sources` table to have `base_url` and `metadata` columns.

[VERIFIED: db/schema.rb lines 364-376] `international_sources` table columns:
```
id, name, source_type, base_url, active, metadata (jsonb), created_at, updated_at
```
All required columns exist.

### ScrapingHelpers and SnapshotHelpers [VERIFIED: test/support/]

Both are included in `ActiveSupport::TestCase` (test_helper.rb lines 99-100). Available:
- `read_html_fixture(filename)` — reads from `test/fixtures/html/`
- `mock_clubcloud_html(url, html_content)` — WebMock stub helper (ClubCloud-specific but pattern is reusable)
- `assert_nothing_raised` — used in region_cc_char_test for smoke-style tests
- `with_vcr_cassette` is NOT in these helpers — it's defined inline in each char test class

---

## Common Pitfalls

### Pitfall 1: InternationalTournament Column Aliases

**What goes wrong:** `InternationalTournament` defines `def name; title; end` and `def start_date; date&.to_date; end`. Tests that create `InternationalTournament` records must use `title:` and `date:`, not `name:` or `start_date:`. TournamentDiscoveryService incorrectly uses `InternationalTournament.new(name: ...)` and `start_date:` on lines 107-109.

**Why it happens:** `InternationalTournament < Tournament` inherits Tournament's schema but the service uses the alias methods as column names.

**How to avoid:** Creating test InternationalTournament records: use `title:` and `date:` as column names.

### Pitfall 2: WebMock Blocks VCR Recording

**What goes wrong:** `WebMock.disable_net_connect!` in `test_helper.rb` blocks real HTTP even when `RECORD_VCR=true`. Running `RECORD_VCR=true` alone won't record new cassettes.

**How to avoid:** When recording cassettes for the first time, VCR+WebMock work together — VCR temporarily enables the real connection for recording. This should work with the existing setup because VCR hooks into WebMock. Verify: cassettes appear after `RECORD_VCR=true bin/rails test`.

### Pitfall 3: `scrape_tournament_archive` Sleeps

**What goes wrong:** `UmbScraper#scrape_tournament_archive` (line 192) calls `sleep 1 if id % 10 == 0`. A test range of `start_id: 1, end_id: 3` won't hit this, but `start_id: 1, end_id: 500` would sleep 50 times.

**How to avoid:** Always characterize with a small ID range (`start_id: 1, end_id: 3`). VCR cassette records only the fetched IDs.

### Pitfall 4: Missing `organize_id` / Validation Bypass

**What goes wrong:** `UmbScraper#scrape_tournament_details` calls `tournament.save(validate: false)`. Tests that assert `tournament.valid?` will pass even with a missing organizer. The test should assert on the saved record, not validity.

**How to avoid:** In characterization tests, assert on the database outcome: `assert InternationalTournament.find_by(external_id: "123")`.

### Pitfall 5: TournamentDiscoveryService Uses Wrong Column Names

**What goes wrong:** `TournamentDiscoveryService#find_or_create_tournament` (lines 100-109) uses `.where('LOWER(name) = ?', ...)` and `InternationalTournament.new(name: ..., start_date: ...)`. These are alias methods, not column names — the WHERE clause will fail because there's no `name` column, and `new(name: ...)` will raise `ActiveModel::UnknownAttributeError` because no `name=` writer is defined. [VERIFIED: `grep -n "def name=\|attr_writer.*name\|alias_attribute.*name" app/models/` returns zero matches across all model files.]

**Impact on SCRP-03:** After fixing `assign_videos_to_tournament`, the `find_or_create_tournament` method has additional bugs. These should be characterized (document current behavior) without fixing them in Phase 25 — they are out of scope. Scope: fix only `assign_videos_to_tournament`.

### Pitfall 6: ScrapeUmbArchiveJob Callers — RESOLVED

**Original concern:** Fixing `ScrapeUmbArchiveJob#perform` signature without checking its callers will leave rake tasks passing wrong arguments at runtime.

**Resolution:** [VERIFIED: read of full `lib/tasks/umb_update.rake`, 413 lines] The rake file does NOT call `ScrapeUmbArchiveJob`. It defines tasks `umb:update`, `umb:check_new`, `umb:fix_organizers`, `umb:fix_locations`, and `umb:status` — all use `UmbScraper.new` directly and call instance methods. `grep -rn "ScrapeUmbArchiveJob" app/ lib/` confirms the job class only appears in its own file (`app/jobs/scrape_umb_archive_job.rb`). No callers need updating beyond the job itself.

---

## Code Examples

### Characterization Test with VCR Cassette [VERIFIED: region_cc_char_test.rb pattern]

```ruby
test "scrape_future_tournaments returns count of saved tournaments" do
  with_vcr_cassette("umb/scraper_future_tournaments") do
    count = @scraper.scrape_future_tournaments
    # Characterize: returns an integer
    assert_kind_of Integer, count
    # Characterize: non-negative
    assert count >= 0, "scrape_future_tournaments returned #{count}"
  end
end
```

### Characterization Test with Fixture HTML (no VCR)

```ruby
test "scrape_future_tournaments returns empty array for empty HTML" do
  stub_request(:get, UmbScraper::FUTURE_TOURNAMENTS_URL)
    .to_return(status: 200, body: "<html><body></body></html>", headers: { "Content-Type" => "text/html" })
  count = @scraper.scrape_future_tournaments
  assert_equal 0, count
end
```

### SCRP-03 Fix [VERIFIED: Video model polymorphic association]

```ruby
# app/services/tournament_discovery_service.rb
def assign_videos_to_tournament(tournament, candidate)
  candidate[:videos].each do |video|
    unless video.videoable == tournament
      video.update(videoable: tournament)
      @videos_assigned += 1
    end
  end
end
```

### SCRP-04 Fix [VERIFIED: UmbScraper#scrape_tournament_archive signature]

```ruby
# app/jobs/scrape_umb_archive_job.rb
def perform(start_id: 1, end_id: 500, batch_size: 50)
  Rails.logger.info "[ScrapeUmbArchiveJob] Starting with start_id=#{start_id}, end_id=#{end_id}"
  scraper = UmbScraper.new
  count = scraper.scrape_tournament_archive(
    start_id: start_id,
    end_id: end_id,
    batch_size: batch_size
  )
  Rails.logger.info "[ScrapeUmbArchiveJob] Completed. Saved #{count} tournaments."
  count
rescue StandardError => e
  Rails.logger.error "[ScrapeUmbArchiveJob] Failed: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
  raise
end
```

### SCRP-05 Umb::HttpClient Skeleton [VERIFIED: RegionCc::ClubCloudClient as pattern, UmbScraperV2#fetch_url lines 57-91]

```ruby
# app/services/umb/http_client.rb
# frozen_string_literal: true

require "net/http"
require "openssl"

# Stateless HTTP transport for UMB scrapers.
# Kapselt alle HTTP-Verbindungen zu files.umb-carom.org.
# SSL-Verifikation: VERIFY_NONE nur in development/test; VERIFY_PEER in production.
class Umb::HttpClient
  TIMEOUT = 30

  # Fetch a URL, following up to max_redirects redirects.
  # Returns response body string or nil on failure.
  def fetch_url(url, follow_redirects: true, max_redirects: 5)
    uri = URI(url)
    redirects = 0

    loop do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = ssl_verify_mode
      http.open_timeout = TIMEOUT
      http.read_timeout = TIMEOUT

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Carambus International Bot/1.0"
      response = http.request(request)

      case response
      when Net::HTTPSuccess
        return response.body
      when Net::HTTPRedirection
        redirects += 1
        return nil if redirects >= max_redirects
        location = response["location"]
        uri = location.start_with?("http") ? URI(location) : URI.join(uri, location)
      else
        return nil
      end
    end
  rescue StandardError => e
    Rails.logger.error "[Umb::HttpClient] Error fetching #{url}: #{e.message}"
    nil
  end

  # Public class method for use by scrapers that manage their own Net::HTTP
  # but want centralized SSL mode. Used by UmbScraper#fetch_url, #download_pdf,
  # and UmbScraperV2#fetch_url.
  def self.ssl_verify_mode
    Rails.env.production? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
  end

  private

  def ssl_verify_mode
    self.class.ssl_verify_mode
  end
end
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP cassette recording | Custom request/response capture | VCR gem (already installed) | VCR handles redirect recording, body compression, header filtering |
| HTML fixture serving | Custom WebMock wrapper | Direct `stub_request(:get, url).to_return(...)` | WebMock already in stack; ScrapingHelpers has `mock_clubcloud_html` pattern |
| SSL context creation | Manual OpenSSL context | `http.verify_mode = OpenSSL::SSL::VERIFY_NONE/PEER` | Rails standard; Net::HTTP handles context internally |
| Cassette skip guard | Custom skip helper | Copy `with_vcr_cassette` from `region_cc_char_test.rb` | Not a shared helper — define inline in each char test class, same as established pattern |

---

## State of the Art

| Old Approach | Current Approach | Phase | Impact |
|--------------|------------------|-------|--------|
| No characterization tests | VCR-backed char tests | Phase 25 | Enables safe extraction in Phase 26 |
| Separate `fetch_url` in each scraper | Shared `Umb::HttpClient` | Phase 25 (early) | Single SSL configuration, no duplication |
| `VERIFY_NONE` unconditional (Kozoom, SoopLive) | `VERIFY_NONE` env-guarded | Phase 25 (UMB only) | brakeman clean for UMB scrapers |
| Per-class `download_pdf` | Extracted to `Umb::HttpClient` | Phase 25 | Shared PDF download in Phase 26 reuse |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong | Status |
|---|-------|---------|---------------|--------|
| A1 | `InternationalTournament.new(name: ...)` in TournamentDiscoveryService will raise at runtime because `name=` is not defined as a writer | Common Pitfalls / Pitfall 5 | If there is a `name=` writer alias, the bug is silent rather than raising — either way, the record won't be found by `.where('LOWER(name) = ?', ...)` | CONFIRMED: `grep -n "def name=\|attr_writer.*name\|alias_attribute.*name" app/models/` returns zero matches. No `name=` writer exists. `new(name: ...)` will raise `ActiveModel::UnknownAttributeError`. |
| A2 | The `umb:scan_archive` rake task calls `ScrapeUmbArchiveJob.perform_later(discipline: ...)` | Common Pitfalls / Pitfall 6 | If the rake task calls `scrape_tournament_archive` directly (not through the job), only the job needs updating | DISPROVEN: `lib/tasks/umb_update.rake` does NOT call `ScrapeUmbArchiveJob` at all. No `umb:scan_archive` task exists. The rake file uses `UmbScraper.new` directly. Only the job file itself needs updating. |

---

## Open Questions — RESOLVED

1. **Does `InternationalTournament` define `name=`?** — RESOLVED (2026-04-12)
   - **Answer:** No. `grep -n "def name=\|attr_writer.*name\|alias_attribute.*name" app/models/` across all model files returns zero matches. `InternationalTournament` defines only `def name; title; end` (reader, line 57). Neither `Tournament` nor any parent defines a `name=` writer. Calling `InternationalTournament.new(name: ...)` will raise `ActiveModel::UnknownAttributeError`.
   - **Impact on Phase 25:** None — SCRP-03 scope is only `assign_videos_to_tournament`, which does not use `name=`. The `find_or_create_tournament` method (lines 100-109) has this separate bug but is out of scope.

2. **Does the rake task `umb:scan_archive` pass kwargs to ScrapeUmbArchiveJob?** — RESOLVED (2026-04-12)
   - **Answer:** No. `lib/tasks/umb_update.rake` does NOT call `ScrapeUmbArchiveJob` at all. The rake file (413 lines) defines tasks `umb:update`, `umb:check_new`, `umb:fix_organizers`, `umb:fix_locations`, and `umb:status`. All tasks use `UmbScraper.new` directly and call instance methods (`scrape_future_tournaments`, `fetch_tournament_basic_data`, `scrape_tournament_details`). The original grep match was a false positive — `ScrapeUmbArchiveJob` only appears in its own job file (`app/jobs/scrape_umb_archive_job.rb`).
   - **Impact on Phase 25:** Simplifies SCRP-04 — only the job's `perform` signature needs updating, no rake task callers to fix.

---

## Environment Availability

Step 2.6: SKIPPED — this phase is code/test changes only. The UMB live site availability matters only for initial VCR cassette recording, which is documented in the test recording instructions (same as region_cc_char_test.rb pattern). No new services or CLIs required.

---

## Validation Architecture

Step 4: SKIPPED — `workflow.nyquist_validation` is explicitly `false` in `.planning/config.json`.

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | No authentication in UMB scrapers |
| V3 Session Management | No | Stateless HTTP only |
| V4 Access Control | No | Admin controller already has Pundit/CanCanCan |
| V5 Input Validation | No | Scraper only reads HTML, doesn't accept user input |
| V6 Cryptography | Yes | SSL verification via `Umb::HttpClient` — `VERIFY_PEER` in production |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| `VERIFY_NONE` in production | Tampering (MITM) | Environment guard — `VERIFY_PEER` in production via `Umb::HttpClient` |

**Brakeman gate:** After SCRP-05, run `bundle exec brakeman --no-pager` and confirm no SSL verification warnings for UMB files. Kozoom/SoopLive warnings will remain (out of scope).

---

## Sources

### Primary (HIGH confidence)
- `app/services/umb_scraper.rb` — direct inspection, all public methods enumerated, `private` boundary at line 478
- `app/services/umb_scraper_v2.rb` — direct inspection, `private` at line 54, one public method
- `app/services/tournament_discovery_service.rb` — direct inspection, bug at line 216
- `app/jobs/scrape_umb_archive_job.rb` — direct inspection, kwargs mismatch confirmed
- `db/schema.rb` lines 1507-1535 — confirmed `videos` table has no `international_tournament_id`
- `app/models/video.rb` lines 19-59 — `videoable` polymorphic association confirmed
- `app/models/international_tournament.rb` — confirmed no `name=` writer, only `def name; title; end` reader
- `lib/tasks/umb_update.rake` — confirmed does NOT call `ScrapeUmbArchiveJob`; uses `UmbScraper.new` directly
- `test/characterization/region_cc_char_test.rb` — established char test pattern
- `test/support/vcr_setup.rb` — VCR configuration confirmed
- `test/test_helper.rb` — WebMock, VCR, fixture setup confirmed
- `.planning/phases/24-data-source-investigation/24-FINDINGS.md` — Phase 24 architecture impact

### Secondary (MEDIUM confidence)
- `app/services/region_cc/club_cloud_client.rb` — PORO pattern reference for `Umb::HttpClient`

---

## Metadata

**Confidence breakdown:**
- Public method inventory: HIGH — verified from source files with `private` boundary markers
- Bug analysis (SCRP-03): HIGH — schema confirmation, model inspection, service code inspection
- Bug analysis (SCRP-04): HIGH — direct comparison of job signature vs method signature; all callers verified
- Bug analysis (SCRP-05): HIGH — grep confirmed all SSL usages
- Test infrastructure: HIGH — VCR setup, WebMock config, helper inclusion all verified
- Umb::HttpClient design: HIGH — exact pattern from RegionCc::ClubCloudClient exists
- Open questions: HIGH — both resolved via direct code inspection (2026-04-12)

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (UMB site HTML structure may change, but code-internal findings are stable)
