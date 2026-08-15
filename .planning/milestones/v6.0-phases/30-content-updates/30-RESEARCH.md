# Phase 30: Content Updates - Research

**Researched:** 2026-04-13
**Domain:** Technical documentation rewriting — Umb:: namespace architecture + services inventory
**Confidence:** HIGH

## Summary

Phase 30 is a documentation rewrite phase with no code changes. The two target docs (`umb-scraping-implementation.md` and `umb-scraping-methods.md`) describe a pre-refactoring architecture centered on a monolithic `UmbScraperV2` class that no longer exists. The current architecture consists of 10 focused services under the `Umb::` namespace. Both docs currently exist as single (German-only) files. Phase 30 must rename each to `.de.md` and create an `.en.md` translation, then update both language versions of the developer guide's services section.

The "37 services" count in the requirements is overstated. The actual verified count across all 7 extracted namespaces is **35 services**. The planner must not fabricate 2 extra services to reach 37; the documentation should reflect the real count. The existing single-file umb-scraping docs also require a nav update in `mkdocs.yml` when renamed to `.de.md`/`.en.md` pairs.

**Primary recommendation:** Read each source file for one-liner descriptions (already done in this research — see Service Inventory below), rewrite German first, translate to English, commit each doc pair together. Update mkdocs.yml nav in the same commit as the umb-scraping rename.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Structural rewrite — replace UmbScraperV2 content with current Umb:: namespace architecture. Include service list with one-liner descriptions, text-based data flow diagram, key entry points. No usage examples or deep implementation details.
- **D-02:** Two docs to rewrite: `umb-scraping-implementation.md` (architecture overview) and `umb-scraping-methods.md` (method inventory). Both currently German-only and reference the deleted UmbScraperV2 class.
- **D-03:** German is the primary language — write/rewrite German first, then translate to English.
- **D-04:** AI-assisted translation — executor handles both languages in one pass.
- **D-05:** The umb-scraping docs currently exist as single files (no `.de.md`/`.en.md` pairs). Phase 30 must create the bilingual pair structure: rename existing to `.de.md`, create `.en.md` translation.
- **D-06:** One table per namespace (7 tables total) in developer guide services section. Columns: Service class, file path, one-liner description.
- **D-07:** One-liner description per service — class name + file path + single sentence describing purpose.
- **D-08:** One commit per doc pair — each `.de.md` + `.en.md` pair committed together.

### Claude's Discretion

- Exact prose structure within each doc (headings, section order)
- How to describe data flow (ASCII diagram, bullet list, or narrative)
- Service one-liner wording
- Whether to include cross-references between the two umb docs

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPDATE-01 | Rewrite `developers/umb-scraping-implementation.md` and `developers/umb-scraping-methods.md` to reflect the Umb:: namespace with 10 services | Service inventory below covers all 10 services with class names, file paths, and purposes |
| UPDATE-02 | Update developer guide services sections to reflect all 37 extracted services across 7 namespaces | Verified count is 35 (not 37) — all services documented in inventory below |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

- `frozen_string_literal: true` in all Ruby files (not applicable — doc-only phase)
- German comments for business logic, English for technical terms
- Conventional commit messages
- Minitest, not RSpec (not applicable — doc-only phase)
- Default locale `:de` — German is the authoritative version
- Bilingual docs use `.de.md` / `.en.md` suffix convention with `mkdocs-static-i18n` plugin

---

## Verified Service Inventory

[VERIFIED: direct file reads of all service source files]

### Umb:: Namespace (10 services total)

The 10 Umb:: services verified by reading each `.rb` file:

| # | Class | File | Purpose |
|---|-------|------|---------|
| 1 | `Umb::HttpClient` | `app/services/umb/http_client.rb` | Stateless HTTP transport — fetches HTML and PDF content from UMB URLs, handles SSL, redirects, and timeout |
| 2 | `Umb::DisciplineDetector` | `app/services/umb/discipline_detector.rb` | Stateless PORO — maps tournament names to `Discipline` DB records via regex + DB-ILIKE fallback |
| 3 | `Umb::DateHelpers` | `app/services/umb/date_helpers.rb` | Module with `module_function` — parses UMB date range strings (same-month and cross-month formats) into `{start_date:, end_date:}` |
| 4 | `Umb::PlayerResolver` | `app/services/umb/player_resolver.rb` | Finds or creates `Player` records from UMB caps/mixed name pairs, with umb_player_id + nationality enrichment |
| 5 | `Umb::FutureScraper` | `app/services/umb/future_scraper.rb` | Scrapes `FutureTournaments.aspx`, parses HTML table including cross-month events, upserts `InternationalTournament` records |
| 6 | `Umb::ArchiveScraper` | `app/services/umb/archive_scraper.rb` | Sequential ID scan of `TournametDetails.aspx?ID=N`, discovers and saves historical tournament records |
| 7 | `Umb::DetailsScraper` | `app/services/umb/details_scraper.rb` | Scrapes a tournament detail page, extracts PDF links, creates `InternationalGame` records, and orchestrates the PDF pipeline |
| 8 | `Umb::PdfParser::PlayerListParser` | `app/services/umb/pdf_parser/player_list_parser.rb` | Pure PORO — parses player seeding list PDF text into `{caps_name:, mixed_name:, nationality:, position:}` hashes |
| 9 | `Umb::PdfParser::GroupResultParser` | `app/services/umb/pdf_parser/group_result_parser.rb` | Pure PORO — parses group result PDF text into match pairs using a pair-accumulator pattern |
| 10 | `Umb::PdfParser::RankingParser` | `app/services/umb/pdf_parser/ranking_parser.rb` | Pure PORO — parses final or weekly ranking PDF text; supports `:final` and `:weekly` type modes |

**Entry points:**
- `Umb::FutureScraper.new.call` — scrapes upcoming tournaments
- `Umb::ArchiveScraper.new.call(start_id:, end_id:)` — scans historical tournament IDs
- `Umb::DetailsScraper.new.call(tournament_id_or_record)` — enriches one tournament with games and PDF data

**Data flow (text diagram):**

```
UMB Website
  ├── FutureTournaments.aspx ──→ Umb::FutureScraper
  │                                    ├── Umb::HttpClient (fetch HTML)
  │                                    ├── Umb::DateHelpers (parse dates)
  │                                    └── Umb::DisciplineDetector (match discipline)
  │                                         → InternationalTournament (upsert)
  │
  ├── TournametDetails.aspx?ID=N ──→ Umb::ArchiveScraper
  │                                        ├── Umb::HttpClient (fetch HTML)
  │                                        ├── Umb::DateHelpers
  │                                        └── Umb::DisciplineDetector
  │                                             → InternationalTournament (create)
  │
  └── TournametDetails.aspx?ID=N ──→ Umb::DetailsScraper
           ├── Umb::HttpClient (fetch HTML + PDFs)
           ├── Umb::PlayerResolver (find/create Player)
           ├── PDF pipeline (optional, parse_pdfs: true):
           │     ├── PdfParser::PlayerListParser → Seeding records
           │     ├── PdfParser::GroupResultParser → InternationalGame + GameParticipation
           │     └── PdfParser::RankingParser → Seeding with final position
           └── InternationalGame records (HTML-based, create_games: true)
```

### All 7 Extracted Namespaces (35 services total)

[VERIFIED: direct file reads + directory listings]

**Actual count: 35** (CONTEXT.md and REQUIREMENTS.md say "37" — this is incorrect. Documented below is the real inventory. The documentation must reflect 35.)

#### TableMonitor:: (2 services)

| Class | File | Description |
|-------|------|-------------|
| `TableMonitor::GameSetup` | `app/services/table_monitor/game_setup.rb` | Encapsulates `start_game` logic — creates Game/GameParticipation records, builds result hash, queues TableMonitorJob |
| `TableMonitor::ResultRecorder` | `app/services/table_monitor/result_recorder.rb` | Encapsulates result persistence — saves set data, navigates sets, coordinates AASM state transitions |

#### RegionCc:: (10 services)

| Class | File | Description |
|-------|------|-------------|
| `RegionCc::BranchSyncer` | `app/services/region_cc/branch_syncer.rb` | Synchronizes BranchCc (discipline) records from ClubCloud API |
| `RegionCc::ClubCloudClient` | `app/services/region_cc/club_cloud_client.rb` | Stateless HTTP transport for ClubCloud admin interface — no ORM coupling, handles sessions and dry-run mode |
| `RegionCc::ClubSyncer` | `app/services/region_cc/club_syncer.rb` | Synchronizes Club records from ClubCloud API |
| `RegionCc::CompetitionSyncer` | `app/services/region_cc/competition_syncer.rb` | Synchronizes competition and season data from ClubCloud |
| `RegionCc::GamePlanSyncer` | `app/services/region_cc/game_plan_syncer.rb` | Synchronizes GamePlanCc and GameDetailCc records including complex HTML table parsing |
| `RegionCc::LeagueSyncer` | `app/services/region_cc/league_syncer.rb` | Dispatcher for league sync operations — coordinates leagues, teams, game plans, and player sync |
| `RegionCc::MetadataSyncer` | `app/services/region_cc/metadata_syncer.rb` | Synchronizes metadata reference objects (categories, groups, disciplines) from ClubCloud |
| `RegionCc::PartySyncer` | `app/services/region_cc/party_syncer.rb` | Synchronizes PartyCc records and match data from ClubCloud |
| `RegionCc::RegistrationSyncer` | `app/services/region_cc/registration_syncer.rb` | Synchronizes registration list records from ClubCloud |
| `RegionCc::TournamentSyncer` | `app/services/region_cc/tournament_syncer.rb` | Synchronizes tournament, tournament series, and championship type data from ClubCloud |

#### Tournament:: (3 services)

| Class | File | Description |
|-------|------|-------------|
| `Tournament::PublicCcScraper` | `app/services/tournament/public_cc_scraper.rb` | Scrapes tournament data from public ClubCloud URL — processes seedings, games, and rankings |
| `Tournament::RankingCalculator` | `app/services/tournament/ranking_calculator.rb` | Calculates and caches effective player rankings; reorders seedings after competition |
| `Tournament::TableReservationService` | `app/services/tournament/table_reservation_service.rb` | Creates Google Calendar events for table reservations with guard condition validation |

#### TournamentMonitor:: (4 services)

| Class | File | Description |
|-------|------|-------------|
| `TournamentMonitor::PlayerGroupDistributor` | `app/services/tournament_monitor/player_group_distributor.rb` | Pure PORO — distributes players across groups using zig-zag or round-robin per NBV rules |
| `TournamentMonitor::RankingResolver` | `app/services/tournament_monitor/ranking_resolver.rb` | Pure PORO — resolves player IDs from ranking rule strings (group ranks, KO bracket references) |
| `TournamentMonitor::ResultProcessor` | `app/services/tournament_monitor/result_processor.rb` | Processes game results with pessimistic DB lock — coordinates ClubCloud upload, GameParticipation updates |
| `TournamentMonitor::TablePopulator` | `app/services/tournament_monitor/table_populator.rb` | Assigns games to tournament tables — initializes TableMonitor records and runs placement algorithm |

#### League:: (4 services)

| Class | File | Description |
|-------|------|-------------|
| `League::BbvScraper` | `app/services/league/bbv_scraper.rb` | Scrapes BBV-specific league data (teams and results) |
| `League::ClubCloudScraper` | `app/services/league/club_cloud_scraper.rb` | Scrapes league data from ClubCloud — teams, parties, game plans |
| `League::GamePlanReconstructor` | `app/services/league/game_plan_reconstructor.rb` | Reconstructs GamePlan from existing Parties and PartyGames |
| `League::StandingsCalculator` | `app/services/league/standings_calculator.rb` | Calculates league standings tables for Karambol, Snooker, and Pool disciplines |

#### PartyMonitor:: (2 services)

| Class | File | Description |
|-------|------|-------------|
| `PartyMonitor::ResultProcessor` | `app/services/party_monitor/result_processor.rb` | Processes game results in PartyMonitor context with pessimistic DB lock |
| `PartyMonitor::TablePopulator` | `app/services/party_monitor/table_populator.rb` | Resets PartyMonitor, assigns TableMonitor records to Party tables |

---

## What the Existing Docs Contain (and Must Be Replaced)

[VERIFIED: direct file reads]

### `umb-scraping-implementation.md` — Current State

- An implementation planning document written in the future tense ("Phase 1: Schema-Erweiterungen")
- Describes `UmbScraper` (V1 monolith) with inline code using `def scrape_tournament_archive`, `def scrape_tournament_details`, etc.
- References deleted models (`InternationalParticipation`, `InternationalResult`)
- Contains architectural proposals (Option A/B for clubs), open questions, and "Nächste Schritte" — clearly a design draft, not a reference doc
- No mention of `Umb::` namespace whatsoever

**Entire content must be replaced.** Nothing is salvageable as factual description of current code.

### `umb-scraping-methods.md` — Current State

- A Rake task reference guide for `rake umb:update`, `rake umb:import_all`, etc.
- References `rake umb_v2:scrape` — "EXPERIMENTAL", describes `umb_v2` as still in development
- References the monolithic `UmbScraper` and `UmbScraperV2` classes explicitly
- Contains performance stats ("~311 Tournaments", "5-10 minutes") for the old architecture

**Entire content must be replaced.** The Rake task reference may partially survive as inspiration for the "entry points" section but the class references are all stale.

---

## Developer Guide Services Section — Current State

[VERIFIED: direct file read of developer-guide.de.md and developer-guide.en.md]

The current developer guide (`developer-guide.de.md` and `.en.md`) has **no services section**. It covers: Übersicht, Architektur, Erste Schritte, Datenbank-Setup, Datenbankdesign, Kern-Models, Hauptfunktionen, Entwicklungsworkflow, Deployment, Mitwirken.

There is a brief mention of `app/services/` in the Architektur section:
```
└── services/            # Geschäftslogik-Services
```

And a mention of scrapers and AI services in the CLAUDE.md overview — but **no table or list of individual services**.

**Implication:** The planner must decide where to insert the new services section. The logical location is after the Architektur section or after Kern-Models, as a new top-level section "Extrahierte Services" / "Extracted Services". This is within Claude's discretion (D-06 specifies format, not location).

---

## mkdocs.yml Nav Impact

[VERIFIED: grep of mkdocs.yml]

Current nav entries for the umb-scraping docs:
```yaml
- UMB Scraping Implementation: developers/umb-scraping-implementation.md
- UMB Scraping Methods: developers/umb-scraping-methods.md
```

When Phase 30 renames these to `.de.md`/`.en.md` pairs (per D-05), the nav entries must change to:
```yaml
- UMB Scraping Implementation: developers/umb-scraping-implementation.md
- UMB Scraping Methods: developers/umb-scraping-methods.md
```

The `mkdocs-static-i18n` plugin uses `docs_structure: suffix` — it resolves `developers/umb-scraping-implementation.md` from either the `.de.md` or `.en.md` file depending on locale. **The nav entries do NOT need to change** — the plugin handles suffix resolution automatically. The rename from `.md` → `.de.md` + new `.en.md` is transparent to the nav.

The developer guide is already bilingual (`developer-guide.de.md` / `developer-guide.en.md`) and the nav references `developers/developer-guide.md` — same pattern. No nav changes needed for any of the Phase 30 docs.

---

## Service Count Discrepancy

[VERIFIED: directory listings and file counts]

The requirements say "37 services across 7 namespaces." The actual count is:

| Namespace | Count |
|-----------|-------|
| Umb:: (including PdfParser::) | 10 |
| RegionCc:: | 10 |
| TournamentMonitor:: | 4 |
| League:: | 4 |
| Tournament:: | 3 |
| TableMonitor:: | 2 |
| PartyMonitor:: | 2 |
| **Total** | **35** |

The CONTEXT.md note under `<specifics>` says: "The '37 services' count needs verification against actual files — current count shows ~35 across 7 namespaces (may include sub-directory services)." This was correctly flagged as uncertain.

The docs should say **35 services across 7 namespaces** (with Umb::PdfParser:: counted as part of the Umb:: namespace group, not a separate 8th namespace).

---

## Architecture Patterns for the New Docs

[VERIFIED: source file comments and class docstrings]

Key architectural decisions that the new docs must convey accurately:

1. **PORO vs ApplicationService split:** Pure algorithms (DisciplineDetector, DateHelpers, PdfParser parsers) are POROs with no DB access. Services with DB side effects (FutureScraper, ArchiveScraper, DetailsScraper, PlayerResolver) are ApplicationService instances.

2. **Module vs Class:** `Umb::DateHelpers` is a `module` with `module_function`, called as `Umb::DateHelpers.parse_date_range(...)`. The other 9 are classes.

3. **Delegation pattern:** The three scraper classes (FutureScraper, ArchiveScraper, DetailsScraper) each delegate to HttpClient, DateHelpers, and DisciplineDetector — they do not do their own HTTP or date parsing.

4. **PDF pipeline is optional:** `DetailsScraper#call` has `parse_pdfs: false` by default. When enabled, it runs all three PdfParser sub-services independently (no short-circuit on first failure).

5. **InternationalGame STI requirement:** Games created by DetailsScraper must use `type: 'InternationalGame'` (STI). This is a known pitfall documented in the source code comments.

---

## Common Pitfalls for the Rewrite Task

### Pitfall 1: Claiming "37 services"
**What goes wrong:** Documentation states 37 but there are 35.
**How to avoid:** Use 35 in all documents.

### Pitfall 2: Treating Umb::PdfParser:: as a separate namespace
**What goes wrong:** Listing 8 namespaces instead of 7 (with PdfParser as its own group).
**How to avoid:** The 3 PdfParser services live under `app/services/umb/pdf_parser/` and belong to the Umb:: namespace group. Present them as a sub-group within the Umb:: table.

### Pitfall 3: Forgetting mkdocs nav update is NOT needed
**What goes wrong:** Changing nav entries to `.de.md` suffix when the i18n plugin handles this transparently.
**How to avoid:** Keep nav as `developers/umb-scraping-implementation.md` — the plugin resolves `.de.md`/`.en.md` automatically.

### Pitfall 4: Inserting old Rake task inventory verbatim
**What goes wrong:** The old `umb-scraping-methods.md` contains Rake task documentation (`rake umb:update`, `rake umb_v2:scrape`) referencing deleted classes. Copying any of this forward contaminates the new doc.
**How to avoid:** New `umb-scraping-methods.md` describes the entry points of the actual Umb:: service classes, not Rake tasks.

### Pitfall 5: Missing the services section location decision
**What goes wrong:** Inserting the services table in an awkward location in the developer guide.
**How to avoid:** Add a new "## Extrahierte Services / Extracted Services" section after the existing Architektur section (before Erste Schritte), or after Kern-Models. Either works — Claude's discretion.

---

## Verification Tools Available

[VERIFIED: bin/ directory]

- `bin/check-docs-coderef.rb` — Scans docs for stale class names (e.g., `UmbScraperV2`, `TournamentMonitorSupport`). Run after rewrite to confirm zero stale references.
- `bin/check-docs-translations.rb` — Reports missing `.de.md`/`.en.md` pairs. Run after creating new bilingual pairs to confirm coverage.

---

## Open Questions

1. **Exact "37" origin**
   - What we know: The requirements and CONTEXT.md both state 37, with an inline note acknowledging uncertainty.
   - What's unclear: Where 37 came from — possibly counting the 3 PdfParser services as a separate 8th namespace, or counting 2 extra files incorrectly.
   - Recommendation: Use the verified count of 35. Document the discrepancy with a note in the planning that requirements said 37 but the real count is 35.

2. **`umb-scraping-methods.md` scope**
   - What we know: The old doc was a Rake task reference. The decision (D-01) says the new docs should cover "key entry points" without deep implementation details.
   - What's unclear: Should the new `umb-scraping-methods.md` become a public method reference (listing `call`, `resolve`, `parse` signatures) or just a brief entry-point summary?
   - Recommendation: Keep it focused on the 3 scraper entry points (`FutureScraper#call`, `ArchiveScraper#call`, `DetailsScraper#call`) and the 3 PdfParser `#parse` methods. Consistent with D-01 "no deep implementation details."

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `mkdocs-static-i18n` plugin with `docs_structure: suffix` resolves `.de.md`/`.en.md` transparently — nav entries do not need updating when adding suffixes | mkdocs Nav Impact | If wrong, nav entries would need `.de.md`/`.en.md` variants and the plan would need a nav update task |

**All other claims in this research were verified by direct file reads.**

---

## Sources

### Primary (HIGH confidence)
- Direct reads of all 10 Umb:: service files in `app/services/umb/`
- Direct reads of all 25 other namespace service files
- Direct reads of `docs/developers/umb-scraping-implementation.md` and `umb-scraping-methods.md`
- Direct read of `docs/developers/developer-guide.de.md` and `.en.md`
- Direct read of `mkdocs.yml` for nav structure and i18n plugin config
- Direct read of `.planning/config.json` for `nyquist_validation` flag (= false, no test section needed)
- Direct read of `30-CONTEXT.md` for locked decisions

---

## Metadata

**Confidence breakdown:**
- Service inventory: HIGH — verified by reading every source file
- Existing doc content: HIGH — verified by reading both docs in full
- mkdocs nav behavior: MEDIUM — confirmed plugin config is `docs_structure: suffix`; one ASSUMED claim about transparent resolution
- Service count (35 vs 37): HIGH — counted every `.rb` file in every namespace directory

**Research date:** 2026-04-13
**Valid until:** Stable (doc-only phase, source files are not changing during this phase)
