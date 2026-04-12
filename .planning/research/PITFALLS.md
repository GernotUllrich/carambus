# Pitfalls Research

**Domain:** UMB scraper overhaul — data source investigation, 2718-line scraper refactoring, video cross-referencing
**Researched:** 2026-04-12
**Confidence:** HIGH (primary source: direct codebase inspection of umb_scraper.rb, umb_scraper_v2.rb, tournament_discovery_service.rb, video.rb, international_tournament.rb, daily_international_scrape_job.rb, schedule.rb, lib/tasks/umb_*.rake, and schema.rb)

---

## Critical Pitfalls

### Pitfall 1: TournamentDiscoveryService References a Non-Existent Column

**What goes wrong:**
`TournamentDiscoveryService#assign_videos_to_tournament` calls `video.international_tournament_id` and `video.update(international_tournament_id: tournament.id)`. The `videos` table has no `international_tournament_id` column. The Video model uses a polymorphic association (`videoable_id` / `videoable_type`). This call raises `ActiveRecord::UnknownAttributeError` or silently fails with a NoMethodError the first time `DailyInternationalScrapeJob` reaches Step 3. Because the job wraps the call in `if defined?(TournamentDiscoveryService)` with no rescue, the error propagates and aborts Steps 4 and 5 of the daily scrape.

**Why it happens:**
`TournamentDiscoveryService` was written referencing a column that was either never added or was removed when the video association was redesigned to use polymorphic `videoable`. No test covers this code path (the job guard `if defined?(...)` is not tested), so the bug has not been caught.

**How to avoid:**
Before writing any cross-referencing logic, verify the actual association API from `video.rb`. The correct assignment is `video.update(videoable: tournament)` which sets both `videoable_id` and `videoable_type`. Add a failing test for `TournamentDiscoveryService#assign_videos_to_tournament` that confirms the association is set via the polymorphic column pair, not a direct FK column.

**Warning signs:**
- `bin/rails test` passes (the service has no tests), but `DailyInternationalScrapeJob.perform_now` in a Rails console raises `NoMethodError: undefined method 'international_tournament_id='`.
- Video records remain with `videoable_id: nil` after the job runs.
- Logs show "Discovered N tournaments" but no videos are linked.

**Phase to address:**
Phase for video cross-referencing — fix this before implementing any matching logic, not after. It is a pre-existing bug that will mask all cross-referencing work.

---

### Pitfall 2: `ScrapeUmbArchiveJob` Passes Arguments That Don't Match `UmbScraper#scrape_tournament_archive`

**What goes wrong:**
`ScrapeUmbArchiveJob#perform` calls `scraper.scrape_tournament_archive(discipline:, year:, event_type:)`. `UmbScraper#scrape_tournament_archive` is defined as `def scrape_tournament_archive(start_id: 1, end_id: 500, batch_size: 50)`. The `discipline:`, `year:`, and `event_type:` keyword arguments are silently ignored in Ruby — no error is raised. The job always scrapes IDs 1–500 regardless of what arguments are passed to the job. Any cron invocation or admin trigger expecting to scope the archive scan by discipline or year gets the full scan instead.

**Why it happens:**
Ruby does not raise on unknown keyword arguments unless the method uses `**kwargs` with explicit error handling. The mismatch was introduced when one file was edited without updating the other. No test exercises the job-to-scraper argument chain end-to-end.

**How to avoid:**
During refactoring, explicitly align the job's `perform` signature with the extracted service's call interface. Add a characterization test that calls the job and asserts the scraper received the correct arguments (use a mock or a method-call spy). Add a smoke test for the job that verifies it does not raise with typical arguments.

**Warning signs:**
- Adding `discipline: '3-Cushion'` to a cron job invocation has no effect on what is scraped.
- Archive scans always process the same IDs regardless of configuration.
- `VERIFY_NONE` SSL flag in scraper inconsistency: `UmbScraperV2` only disables SSL verification in development, but `KozoomScraper` disables it unconditionally in all environments — shows configuration discipline has drifted across scrapers.

**Phase to address:**
Phase for scraper refactoring — fix the argument mismatch before splitting into sub-services, or you will propagate the wrong interface into multiple files.

---

### Pitfall 3: Cutting Over the Daily Production Scrape While Old and New Code Coexist

**What goes wrong:**
The cron schedule runs `rake umb:update` at 3:00 AM daily, which calls `UmbScraper.new.scrape_future_tournaments`. During an incremental refactoring where `UmbScraper` is split into sub-services, the rake task continues calling the monolith until all callers are updated. If a refactoring phase deletes or renames methods on `UmbScraper` before updating the rake task and jobs, the production cron job silently fails with a `NoMethodError` on the first post-deploy run. The failure is silent unless the cron log (`log/cron.log`) is monitored.

Three callers of `UmbScraper` exist: `ScrapeUmbJob`, `ScrapeUmbArchiveJob`, and `Admin::IncompleteRecordsController`. A fourth implicit caller is the `umb:update` rake task. Any of these can be broken by renaming or extracting a public method.

**Why it happens:**
Rake tasks and background jobs are not covered by the test suite for `UmbScraper`. The scraper has no characterization tests at all — unlike all previous refactoring phases (TableMonitor, RegionCc, Tournament), which established characterization tests before any extraction. Skipping this step here means refactoring blind.

**How to avoid:**
Write characterization tests for every public method of `UmbScraper` before changing a single line. Use VCR cassettes (the infrastructure is already established in `test/snapshots/vcr/`) to record real UMB responses. Add smoke tests for `ScrapeUmbJob` and `ScrapeUmbArchiveJob` matching the pattern in `test/scraping/scraping_smoke_test.rb`. Keep the `UmbScraper` class and its public interface intact as a delegation wrapper until all callers have been migrated to the new sub-services — this is the same pattern used successfully for TableMonitor and RegionCc (thin delegation wrappers as permanent API).

**Warning signs:**
- No test failures after deleting a method — means no test covered it.
- `bin/rails test:critical` passes but `bin/rails test` fails — scraper tests may live outside the critical subset.
- No VCR cassettes exist for UMB in `test/snapshots/vcr/` — characterization tests have never been written.

**Phase to address:**
Phase 1 of scraper work — characterization tests come first, before any extraction. Non-negotiable given the 901-test green suite that must stay green.

---

### Pitfall 4: Duplicate Tournament Records Created by Fuzzy Matching During Data Source Switch

**What goes wrong:**
`UmbScraper#save_tournaments` uses a fuzzy match to prevent duplicates: it looks for an existing `InternationalTournament` with the same `title` and `location_text`, within 30 days of the start date. If a new data source returns slightly different names (e.g., "World Cup Antalya 2025" vs "3C World Cup Antalya 2025"), or different location strings (e.g., "Antalya" vs "Antalya, Turkey"), the fuzzy match fails and a duplicate record is created. When both old and new sources run during a transition, both upsert paths can fire on the same real tournament, creating two records with overlapping data.

This is a harder problem than it appears because `InternationalTournament` has an `external_id` uniqueness constraint scoped to `international_source_id`. If a new source assigns a different `external_id` for the same physical tournament, the uniqueness constraint does not protect against duplicates.

**Why it happens:**
Switching data sources mid-flight means the same tournament can arrive from two sources simultaneously (old HTML scraper still running, new API also running). The fuzzy match is the only protection and it breaks on minor name/location variations, which are common across sources.

**How to avoid:**
Before enabling any new data source in production, perform a one-time audit of existing `InternationalTournament` records to establish canonical title and location formats. Add a database-level unique index on `(title, date)` for `InternationalTournament` as a safety net (requires a migration). During the switchover window, disable the old source by commenting it out of the cron schedule rather than running both in parallel. After successful validation, remove the old source calls. Document the cutover plan explicitly in the phase spec.

**Warning signs:**
- `InternationalTournament.count` increases abnormally after the first run with a new source.
- Tournament records appear twice in admin views with slightly different titles.
- `external_id` is `nil` or varies between otherwise-identical tournaments.

**Phase to address:**
Phase for data source investigation — design the cutover plan before writing integration code. The phase that integrates a new source must explicitly address duplicate prevention.

---

### Pitfall 5: PaperTrail Version Bloat During Bulk Scrape Operations

**What goes wrong:**
`InternationalTournament` inherits `has_paper_trail` from `LocalProtector`. Every `tournament.save` or `tournament.update` during a bulk archive scrape creates a PaperTrail `Version` record. Scraping 200 tournaments in an archive scan creates 200+ version records. If each tournament is re-scraped daily (to update state from `planned` to `finished`), the version table grows at 200+ rows/day. In production this quietly degrades the `Version.update_from_carambus_api` sync that local servers use — it must process all versions in order.

**Why it happens:**
The scraper calls `tournament.save` in a loop without suppressing versioning. Previous service extractions (e.g., `GameSetup`) explicitly set `suppress_broadcast = true` to avoid broadcast side effects during batch operations. The same discipline has not been applied to versioning in the scraper.

**How to avoid:**
Wrap bulk save operations in `PaperTrail.request(enabled: false) { ... }` for scraping runs where the version record has no value (no human operator is making the change). For genuine data updates (state change from `planned` to `finished`) PaperTrail should remain active. Distinguish between "first-time import" (suppress) and "status update" (keep versioning). Check that the `LocalProtector` skip lambda (which skips versions when only `updated_at` changes) is working as intended for idempotent re-scrapes.

**Warning signs:**
- `PaperTrail::Version.count` grows by several hundred per daily cron run.
- `Version.update_from_carambus_api` on local servers is slow and falls behind.
- Scraping 500 tournament IDs creates 500 version rows for what are essentially identical records being re-saved.

**Phase to address:**
Phase for scraper refactoring — address before the first bulk import run, not after observing database bloat.

---

### Pitfall 6: Video-to-Tournament Matching Is Brittle When Tournament Names Vary Across Sources

**What goes wrong:**
The video cross-referencing approach must match a video title like "2025 World Cup Antalya - Final - Caudron vs Merckx" to an `InternationalTournament` record titled "3C World Cup Antalya 2025". The `TournamentDiscoveryService` (once the column bug is fixed) groups videos by `data['tournament_type']` and `data['year']`, then fuzzy-matches by name. This approach fails when:
- The tournament type string in video metadata ("World Cup") does not map to the exact value in `InternationalTournament#tournament_type` ("world_cup").
- A tournament appears in two different seasons (e.g., European Championship held in December is sometimes attributed to the next year by different sources).
- Kozoom and YouTube use different title conventions for the same event.

A failed match leaves `videoable_id: nil` on the video — it is never associated with a tournament. There is no alerting when this happens, so the failure is invisible.

**Why it happens:**
Free-text matching between sources with different naming conventions is inherently fragile. The current `TournamentDiscoveryService` hardcodes type mappings in `map_tournament_type` using case/when with regex. Any new tournament type not in the list falls into `'other'`, which creates a new tournament record rather than matching the existing one.

**How to avoid:**
Add a `data['umb_external_id']` field to the video metadata when it can be extracted from descriptions or structured API data. A direct ID match is order-of-magnitude more reliable than name matching. For name-based matching, normalize both sides to a canonical form before comparing (strip year, strip discipline prefix, lowercase, remove punctuation). Instrument the matching: log how many videos have `videoable_id: nil` after each daily job run so failures are visible. Add a rake task to show unmatched videos as a monitoring tool.

**Warning signs:**
- `Video.unassigned.count` does not decrease after cross-referencing runs.
- `Video.for_tournaments.count` is much lower than expected given the number of scraped tournaments.
- All cross-referenced videos cluster on only 2-3 tournaments, leaving dozens of tournaments with zero videos.

**Phase to address:**
Phase for video cross-referencing — design the matching strategy before implementing it. Use ID-based matching where possible; name-based matching requires a normalization layer.

---

### Pitfall 7: `OpenSSL::SSL::VERIFY_NONE` in Production via Kozoom Scraper

**What goes wrong:**
`KozoomScraper` sets `http.verify_mode = OpenSSL::SSL::VERIFY_NONE` unconditionally — not guarded by `Rails.env.development?` as `UmbScraper` and `UmbScraperV2` do. This means Kozoom API calls in production skip certificate verification, opening a man-in-the-middle attack surface and masking SSL configuration problems. During a refactoring that extracts a shared `HttpClient` or `FetchUrl` helper, this inconsistency must not be silently preserved.

**Why it happens:**
The scrapers were written independently without a shared HTTP abstraction. Each scraper made its own SSL decision; Kozoom chose `VERIFY_NONE` without environment guard, possibly because the original developer was testing against a self-signed cert and forgot to add the guard.

**How to avoid:**
Create a single `UmbHttp` (or `ScraperHttp`) helper module as part of the extraction. Define `VERIFY_NONE` behavior once, guarded by `Rails.env.development?`. All extracted sub-services use this helper. During the refactoring phase, document the Kozoom inconsistency and fix it explicitly in the shared helper.

**Warning signs:**
- New extracted services copy `fetch_url` from `UmbScraper` (correct, environment-guarded) but a developer accidentally copies from `KozoomScraper` (unguarded).
- Brakeman does not flag `VERIFY_NONE` in development-only guards but will flag unconditional usage — run `bundle exec brakeman --no-pager` after each extraction.

**Phase to address:**
Phase for scraper refactoring — address during extraction of the shared HTTP helper.

---

### Pitfall 8: Incremental ID Scanning Is Rate-Limiting Hostile and Slow

**What goes wrong:**
`UmbScraper#scrape_tournament_archive` scans IDs sequentially from 1 to 500, with a 1-second sleep every 10 IDs. A full scan takes at minimum 50 seconds, and a scan of IDs 1–2000 takes over 3 minutes before accounting for actual HTTP response times. If the UMB server rate-limits or blocks sequential scanning (many sites do), the scraper receives 429 or 503 responses, which the current code handles only via the 50-consecutive-404 stop heuristic — it does not detect 429s as distinct from 404s. A blocked IP means the daily cron job fails silently with 0 results.

**Why it happens:**
Sequential ID scanning is a naive discovery strategy. The UMB site uses ASP.NET with sequential IDs (`TournametDetails.aspx?ID=N`) which makes this tempting, but it is also the pattern most aggressively rate-limited by web servers and CDNs.

**How to avoid:**
During data source investigation, determine the maximum known tournament ID first (currently stored in `InternationalTournament.maximum(:external_id)` per the rake task). Only scan IDs beyond the current maximum, not from 1 every time. Add explicit handling for HTTP 429 (rate limit) and 503 (server error) — these should trigger an exponential backoff, not increment the consecutive-404 counter. Consider a minimum delay between every request, not just every 10.

**Warning signs:**
- Archive scans that previously worked start returning 0 results.
- Server logs show repeated responses with status 429 or 503.
- The consecutive-404 counter hits 50 very quickly (all "404s" are actually rate-limit responses).

**Phase to address:**
Phase for data source investigation — before writing any new scraping code, understand the site's rate-limiting behavior and adjust the scan strategy accordingly.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Leaving `UmbScraper` as a delegation wrapper indefinitely | Zero caller changes | 2718-line file remains; cognitive load unchanged | Acceptable during transition only — plan a removal milestone |
| Fuzzy name matching without normalization | Quick to implement | Silent duplicate records accumulate over months | Never for production data; only for one-time exploratory scripts |
| Skipping characterization tests and refactoring directly | Faster initial delivery | No regression safety net; 901 green tests can break silently on a method rename | Never — the project convention is test-first |
| Running both old and new data source in parallel indefinitely | Gradual validation | Duplicate records, version bloat, confusing data provenance | Acceptable only for a bounded validation window (1-2 weeks max) |
| Using `sleep N` in sequential ID scans | Prevents obvious rate-limiting | Masks real rate-limit responses (429); inflexible delay logic | Replace with proper backoff before any bulk production run |
| Copying `fetch_url` from each scraper into extracted services | No shared abstraction needed immediately | SSL inconsistencies propagated; duplicate HTTP error handling | Acceptable for first extraction only if a shared helper is planned in the same phase |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| UMB files.umb-carom.org HTML | Assuming page structure is stable — it is an ASPX app with inconsistent HTML | Wrap all Nokogiri selectors in defensive nil checks; test with VCR cassettes that record actual responses |
| YouTube Data API v3 | Assuming videos scraped today include all recent content | API search results are not exhaustive for live/premiering content; `publishedAfter` parameter has a ~10 min lag |
| Kozoom API | Using saved credentials that rotate without notice | Always check `authenticate` return value before API calls; credentials live in Rails encrypted credentials |
| SoopLive VOD | Assuming the embed URL format is stable | SoopLive has changed between `play.sooplive.co.kr` and `vod.sooplive.co.kr` — verify both live and VOD URL patterns |
| PaperTrail during bulk import | Not suppressing versioning = massive `versions` table growth | `PaperTrail.request(enabled: false) { bulk_save_loop }` for first-time imports |
| Video polymorphic association | Using `video.international_tournament_id = id` | Use `video.update(videoable: tournament)` — sets both `videoable_id` and `videoable_type` correctly |
| `InternationalTournament` STI | Querying `Tournament.where(...)` and missing international records | Use `InternationalTournament.where(...)` or `Tournament.international.where(...)` to scope correctly |
| `external_id` uniqueness | The uniqueness constraint is scoped to `international_source_id` | Two sources can create the same tournament under different external IDs — explicit dedup check required during source switchover |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| `InternationalTournament.by_type` and `.official_umb_only` filter in Ruby (all.select) | N+1 equivalent: loads all InternationalTournaments into memory | Add a PostgreSQL JSONB index on `data->>'tournament_type'`; use `.where("data->>'umb_official' = 'true'")` | At ~500+ international tournaments |
| `Video.find_each` in `TournamentDiscoveryService` without scope | Iterates all videos, not just international ones | Add `.supported_platforms` scope (already exists on Video model) | At ~10,000 videos |
| Sequential archive scan without upper-bound check | Scans 500+ IDs per run even if only 5 new ones exist | `start_id: current_max + 1` pattern already in `umb_update.rake` — replicate in extracted service | Every daily run after initial import |
| `LocalProtector#disallow_saving_global_records` after each bulk save | 200 saves × hook overhead = slow bulk import | No workaround — this is a design constraint; batch with `insert_all` for read-only import records | At 200+ tournament records per job run |
| Kozoom authentication token expiry mid-batch | Halfway through scraping, all API calls return 401 | Check token expiry before each batch; re-authenticate proactively; KozoomScraper already supports this but callers don't always call `authenticate` first | On any run longer than token TTL (~1 hour) |

---

## "Looks Done But Isn't" Checklist

- [ ] **UmbScraper characterization tests exist:** At least one test per public method using VCR cassettes before any extraction begins — verify with `bin/rails test test/services/umb/`
- [ ] **TournamentDiscoveryService column bug fixed:** `video.videoable_id` not `nil` after running `discover_from_videos` — query `Video.for_tournaments.count` before and after
- [ ] **ScrapeUmbArchiveJob argument alignment:** Calling the job with `discipline: '3-Cushion'` produces a different scope than without — verify by adding a test or stepping through in console
- [ ] **No new duplicate InternationalTournament records:** Run `InternationalTournament.group(:title, :date).having("count(*) > 1").count` after each new source is enabled
- [ ] **PaperTrail version count is not growing unbounded:** `PaperTrail::Version.where(item_type: 'Tournament').where('created_at > ?', 1.day.ago).count` after a daily cron run — should be proportional to actual changes, not total tournaments scraped
- [ ] **Video cross-referencing actually assigns videoable:** `Video.unassigned.count` decreases after the cross-referencing step runs — not merely that the step completes without error
- [ ] **Backward compatibility: all 901 existing tests still pass:** Run `bin/rails test` (not just `bin/rails test:critical`) after each extraction step

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| `TournamentDiscoveryService` column bug breaks daily job | LOW | Replace `international_tournament_id` with `videoable` polymorphic assignment; add test; redeploy |
| Duplicate tournament records from parallel source run | MEDIUM | Write a dedup rake task that merges duplicates using `external_id` as canonical key; run once; add unique index to prevent recurrence |
| PaperTrail version bloat | MEDIUM | `PaperTrail::Version.where(item_type: 'Tournament', created_at: ...).delete_all` for import-generated versions; add versioning suppression to scraper going forward |
| 901 tests fail after extraction | HIGH | Revert extraction; re-add characterization tests; extract one method at a time with a passing test before each step |
| Production cron silent failure after method rename | MEDIUM | Restore public method as delegation wrapper; update rake task; add smoke test for rake task |
| Rate-limited by UMB during archive scan | LOW | Add 429 detection and exponential backoff; reduce scan batch size; add IP rotation awareness |
| Video-to-tournament matching returns zero matches | MEDIUM | Instrument matching with logging; introduce canonical name normalization; fall back to ID-based matching if UMB external_id is available in video metadata |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| `TournamentDiscoveryService` column bug | Phase: video cross-referencing (fix before implementing) | `Video.for_tournaments.count > 0` after discovery job runs |
| Job-to-scraper argument mismatch | Phase: scraper refactoring (fix before extraction) | Smoke test calls job with non-default args and asserts correct scope |
| Production cron cutover safety | Phase: scraper refactoring (characterization tests first) | `bin/rails test` green after each extraction step |
| Duplicate records during source switch | Phase: data source integration (design cutover plan) | No records in `InternationalTournament.group(:title,:date).having("count(*) > 1")` |
| PaperTrail version bloat | Phase: scraper refactoring (add suppression to bulk paths) | `Version.where(item_type:'Tournament').count` grows only on genuine updates |
| Video-to-tournament name matching brittleness | Phase: video cross-referencing (design matching strategy) | `Video.unassigned.count` decreases after each cross-referencing run |
| `VERIFY_NONE` SSL in shared HTTP helper | Phase: scraper refactoring (shared HTTP abstraction) | Brakeman reports no unconditional `VERIFY_NONE` usage |
| Sequential ID scan rate-limiting | Phase: data source investigation (scan strategy design) | Archive scan handles 429 responses with backoff, not 404 counting |

---

## Sources

- `app/services/umb_scraper.rb` (2133 lines, direct inspection) — method inventory, argument signatures, duplicate detection logic, rate limiting, fetch_url SSL handling
- `app/services/umb_scraper_v2.rb` (585 lines, direct inspection) — alternate scraper path, SSL guard pattern
- `app/services/tournament_discovery_service.rb` (direct inspection) — `international_tournament_id` bug confirmed against schema
- `app/models/video.rb` (direct inspection) — polymorphic `videoable` association, no `international_tournament_id` column
- `db/schema.rb` (direct inspection) — `videos` table schema confirms absence of `international_tournament_id`
- `app/jobs/scrape_umb_archive_job.rb` (direct inspection) — argument mismatch with `UmbScraper#scrape_tournament_archive`
- `app/jobs/daily_international_scrape_job.rb` (direct inspection) — Step 3 calls `TournamentDiscoveryService` with no error rescue
- `config/schedule.rb` (direct inspection) — `rake umb:update` runs at 3:00 AM daily
- `lib/tasks/umb_update.rake` (direct inspection) — 413-line rake task, calls `UmbScraper.new` directly
- `app/models/local_protector.rb` (direct inspection) — `has_paper_trail` with skip lambda, after_save hook
- `app/models/international_tournament.rb` (direct inspection) — STI structure, `external_id` uniqueness constraint
- `app/services/kozoom_scraper.rb` (direct inspection) — unconditional `VERIFY_NONE` without environment guard
- `test/scraping/scraping_smoke_test.rb` (direct inspection) — existing smoke test pattern available for UMB

---
*Pitfalls research for: UMB scraper overhaul (data source investigation, refactoring, video cross-referencing)*
*Researched: 2026-04-12*
