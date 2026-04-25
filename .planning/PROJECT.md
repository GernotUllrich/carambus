# Carambus API — Quality & Manager Experience

## What This Is

A Rails tournament management system for carom billiards that Sports Managers (volunteer club officers) use to run regional tournaments. v1.0–v5.0 rebuilt the model/service layer for maintainability; v6.0 made the documentation match the refactored codebase. v7.0 onward focuses on making the product usable for the volunteer club officer persona through task-first docs and a UX that respects their 2-3x/year usage pattern.

## Core Value

Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.

## Current Milestone: v7.1 UX Polish & i18n Debt

**Goal:** Close the 5 Phase 36B UAT follow-up gaps (G-01, G-03, G-04, G-05, G-06) before they rot into larger debt. All 5 surfaced during the 2026-04-15 human UAT session but were non-regressions against v7.0's functional acceptance criteria, so they were captured as a seed instead of blocking v7.0 completion.

**Target features:**
- **G-01 Dark-mode contrast fix**: wizard `<details>` help block + inline-styled info banners use Tailwind `dark:*` classes so the help text is readable in dark mode
- **G-03 Tooltip affordance**: 16 tooltipped labels on `tournament_monitor.html.erb` get a visible affordance (dashed underline + `cursor: help`) via a single CSS attribute-selector rule
- **G-04 DE-only hardcoded strings audit**: pre-existing hardcoded German strings outside `t('...')` calls on `tournament_monitor` surroundings get i18n coverage so EN-locale admins don't see German
- **G-05 Warmup EN translation fix**: `config/locales/en.yml:844-846` changes "Training" → "Warmup" for the 3 warm-up state keys (distinct from `training: Training` at line 387 which is a different concept)
- **G-06 `Discipline#parameter_ranges` widening**: first-pass hardcoded ranges from Phase 36B D-17 get widened to cover youth/handicap/pool/snooker outliers; decision on short-term widen vs medium-term DB-backed table deferred to discuss-phase
- **Phase 36B Test 1 retest**: the wizard header + 6-chips + no-"Schritt-N-von-6" criteria need explicit reconfirmation (original Test 1 was marked `issue` because G-01 was flagged mid-test)

Scope is deliberately small — a warm-up milestone after the long overcommit-hook debugging session, before larger feature work resumes.

**Deferred to a future milestone:**
- v7.2 ClubCloud Integration (Endrangliste auto-calculation, CC API finalization, credentials delegation) — skeleton at `.planning/milestones/v7.2-{REQUIREMENTS,ROADMAP}.md` (retaining the old v7.1 skeleton content under a renamed target version)
- v7.3 Shootout / Stechen Support — skeleton at `.planning/milestones/v7.2-*` (also retained; the milestone number assignment will be decided at next kickoff)
- CI guard replacement for public/docs/ drift (the overcommit hook attempt from quick task 260415-26d failed and rolled back; a GitHub Actions-based guard is the proposed replacement, separate milestone)
- G-06 medium-term DB-backed `discipline_parameter_ranges` table — in scope only if discuss-phase decides the short-term widen isn't enough

## Completed: v7.0 Manager Experience (shipped 2026-04-15)

A volunteer club officer running 2-3 tournaments per year can now manage one end-to-end with task-first documentation and a happy-path UX. Delivered in 7 phases (33→34→35→36a→36b→36c→37): wizard partial consolidated and audited (Phase 33), tournament-management walkthrough rewritten task-first in DE and EN with glossary and troubleshooting (Phase 34), printable A4 quick-reference card with laminate-ready print CSS (Phase 35), 58-finding doc-accuracy review applied (Phase 36a), wizard header redesign with dominant AASM state badge + 6 bucket chips + 16 parameter tooltips + reset/parameter confirmation modals + admin_controlled auto-advance (Phase 36b), v7.1/v7.2 milestone skeletons + backlog seeds planted (Phase 36c), and in-app wizard-to-doc links with locale-aware `mkdocs_link` helper + 4 stable anchor IDs + 4 form-help info boxes (Phase 37). Human UAT confirmed all 7 functional criteria on 2026-04-15; 5 non-regression follow-up gaps (G-01..G-06, minus G-02 fixed inline) captured in seed `v71-ux-polish-i18n-debt.md` for next milestone. 37/37 requirements complete, 36 shipped + 1 closed as no-op.

## Completed: v6.0 Documentation Quality (shipped 2026-04-13)

Audited, repaired, and documented the entire mkdocs site: zero broken links, zero stale code refs, 8 namespace overview pages, Video:: cross-referencing docs, 35-service developer guide index, 17 bilingual gaps closed, mkdocs build --strict passes with zero warnings.


## Requirements

### Validated

- ✓ Existing TableMonitor functionality preserved — v1.0
- ✓ Existing RegionCc functionality preserved — v1.0
- ✓ Existing test suite passes — v1.0
- ✓ Characterization tests for TableMonitor critical paths — v1.0 (58 tests)
- ✓ Characterization tests for RegionCc critical paths — v1.0 (56 tests)
- ✓ Extract service classes from TableMonitor — v1.0 (ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder)
- ✓ Extract service classes from RegionCc — v1.0 (ClubCloudClient + 9 syncers)
- ✓ Tests for all extracted service classes — v1.0 (140 tests total)
- ✓ RegionCc reduced to 491 lines — v1.0
- ✓ TableMonitor reduced to 1611 lines — v1.0
- ✓ Reek quality improvement measured — v1.0 (TableMonitor 781→306, RegionCc 460→54)
- ✓ Every test file reviewed for quality issues — v2.0 (72 files audited, STANDARDS.md + AUDIT-REPORT.md)
- ✓ All skipped/pending tests resolved — v2.0 (VCR cassettes recorded, skips justified or fixed)
- ✓ Consistent patterns established — v2.0 (frozen_string_literal, fixtures-first, test naming)
- ✓ Dead/redundant tests removed — v2.0 (10 empty stubs + 1 non-test script deleted)
- ✓ All tests green after improvements — v2.0 (475 runs, 0 failures, 0 errors, 11 justified skips)
- ✓ Tournament characterization tests (AASM, scraping, attributes, PaperTrail, calendar) — v2.1 (85 tests)
- ✓ TournamentMonitor characterization tests (T04, T06, KO) — v2.1 (47 tests)
- ✓ Tournament reduced to 575 lines — v2.1 (3 services: RankingCalculator, TableReservationService, PublicCcScraper)
- ✓ TournamentMonitor reduced to 181 lines — v2.1 (4 services: PlayerGroupDistributor, RankingResolver, ResultProcessor, TablePopulator)
- ✓ lib/tournament_monitor_support.rb deleted — v2.1 (all methods extracted to services)
- ✓ Controller/channel/job test coverage — v2.1 (74 tests: TournamentsController, TournamentMonitorsController, channels, jobs)
- ✓ All tests green — v2.1 (751 runs, 0 failures, 0 errors)
- ✓ PaperTrail version baselines unchanged — v2.1 (sync contract preserved)
- ✓ Capybara/Selenium system test infrastructure — v3.0 (async adapter, local_server? override, multi-session helpers, smoke test)
- ✓ Multi-scoreboard broadcast isolation tests — v3.0 (morph path, score:update dispatch, table_scores overview, console.warn filter proof)
- ✓ Concurrent/load broadcast isolation — v3.0 (rapid-fire 6-iteration loop, 3-session all-pairs, 0 failures)
- ✓ Broadcast gap report — v3.0 (all 11 requirements PASS, FIX-01/FIX-02 deferred)
- ✓ Characterization tests for League critical paths — v4.0 (25 tests: standings, game plan, scraping)
- ✓ Characterization tests for PartyMonitor critical paths — v4.0 (40 tests: AASM, placement, result pipeline)
- ✓ Extract service classes from League — v4.0 (4 services: StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper; 2221→663 lines, 70.2% reduction)
- ✓ Extract service classes from PartyMonitor — v4.0 (2 services: TablePopulator, ResultProcessor; 605→217 lines, 64% reduction)
- ✓ Controller/channel/job test coverage for League/Party/PartyMonitor — v4.0 (30 controller + 10 reflex tests, COV-02 documented, 901 runs green)
- ✓ Alternative UMB data sources investigated — v5.0 (SoopLive JSON API GO, umbevents/Cuesco NO-GO)
- ✓ UmbScraper reduced to 175 lines — v5.0 (10 Umb:: services: HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser, GroupResultParser, RankingParser, FutureScraper, ArchiveScraper, DetailsScraper)
- ✓ UmbScraperV2 deleted — v5.0 (585 lines absorbed into Umb::PdfParser::* services)
- ✓ 3 pre-existing bugs fixed — v5.0 (TournamentDiscoveryService column, ScrapeUmbArchiveJob kwargs, SSL inconsistency)
- ✓ UMB ranking PDF parsing implemented — v5.0 (RANK-01: weekly + final rankings via Umb::PdfParser::RankingParser)
- ✓ Video cross-referencing system — v5.0 (Video::TournamentMatcher + Video::MetadataExtractor + SoopliveBilliardsClient)
- ✓ SoopLive VOD linking via replay_no — v5.0 (VIDEO-02)
- ✓ Kozoom event cross-referencing via eventId — v5.0 (VIDEO-03)
- ✓ DailyInternationalScrapeJob Steps 3a/3b/3c wired — v5.0 (incremental matching + backfill rake task)

- ✓ Audit docs against codebase — v6.0 (133-finding staleness inventory, 3 audit scripts)
- ✓ Update/remove references to deleted or refactored code — v6.0 (75 broken links fixed, 6 stale refs updated)
- ✓ Document new features and services from v1.0–v5.0 — v6.0 (8 namespace pages, Video:: cross-ref, 35-service developer guide)
- ✓ Verify multilingual consistency (de/en) — v6.0 (17 bilingual gaps closed, zero warnings)

- ✓ UX review of TournamentsController wizard happy path — v7.0 Phase 33 (UX-01..04: canonical partial identified, transient AASM state documented, 14 findings classified by impact tier)
- ✓ Task-first rewrite of tournament-management.{de,en}.md — v7.0 Phase 34 (DOC-01..05: both languages rewritten with walkthrough, glossary, troubleshooting, corrected Quick Start)
- ✓ Printable one-page quick reference card — v7.0 Phase 35 (QREF-01..03: A4 Before/During/After card + print.css + scoreboard shortcut cheat sheet, DE + EN)
- ✓ Phase 36a Turnierverwaltung doc accuracy — v7.0 (DOC-ACC-01..06: 58 findings applied, Begriffshierarchie consistent, glossary expanded, appendix sections for special flows, "Mehr zur Technik" removed)
- ✓ Phase 36b UI cleanup + safety features — v7.0 (FIX-01/03/04 + UI-01..07: wizard header with dominant AASM badge + 6 bucket chips, active-help auto-open, 16 parameter tooltips, full i18n of parameter labels, admin_controlled removed + auto-advance gate, dead-code manual input removed, unused partial deleted, reset confirmation modal, parameter verification modal with Discipline#parameter_ranges)
- ✓ Phase 36c v7.1 preparation — v7.0 (PREP-01..04: v7.1 ClubCloud Integration skeleton, v7.2 Shootout skeleton, Match-Abbruch/Freilos + UI-consolidation backlog seeds, CC admin-side appendix content for DOC-ACC-04)
- ✓ In-app wizard-to-doc links — v7.0 Phase 37 (LINK-01..04: locale-aware mkdocs_link helper, 4 stable `{#id}` anchors in both DE/EN doc files, all 6 wizard steps + 4 form-help info boxes wired, Minitest + controller integration tests)

### Active

<!-- v7.1 UX Polish & i18n Debt — requirement IDs will land after /gsd-new-milestone REQUIREMENTS step -->
- [ ] **G-01**: Wizard `<details>` help block and inline-styled info banners are readable in dark mode
- [ ] **G-03**: Tooltip-decorated labels have a visible affordance (dashed underline + `cursor: help`)
- [ ] **G-04**: Pre-existing DE-only hardcoded strings on `tournament_monitor` surroundings are covered by i18n
- [ ] **G-05**: EN locale shows "Warmup" (not "Training") for the warm-up state on `table_monitor.status.*`
- [ ] **G-06**: `Discipline#parameter_ranges` is wide enough for youth/handicap/pool/snooker outliers without false warnings
- [ ] **Phase 36B Test 1 retest**: badge dominance, 6 chips, no "Schritt N von 6", no numeric prefixes — explicitly reconfirmed after G-01 fix ships

### Out of Scope

- Full TournamentsController redesign — targeted fixes only this milestone
- Edge-case wizard branches (reset, manual overrides, partial retries) — happy path first
- New test coverage for remaining untested models, controllers, services — separate milestone
- Architecture or stack changes — not in scope for current project

## Context

- Brownfield Rails 7.2 app for carom billiard tournament management
- Ruby 3.2.1, PostgreSQL, Redis, ActionCable, StimulusReflex
- **v1.0 shipped 2026-04-10:** TableMonitor 3903→1611 lines (4 services), RegionCc 2728→491 lines (10 services)
- **v2.0 shipped 2026-04-10:** 72 test files audited, 475 runs green, 1121 assertions, ApiProtectorTestOverride added
- **v2.1 shipped 2026-04-11:** Tournament 1775→575 lines (3 services), TournamentMonitor 499→181 lines (4 services), lib/tournament_monitor_support.rb deleted
- **v4.0 shipped 2026-04-12:** League 2221→663 lines (4 services), PartyMonitor 605→217 lines (2 services), 30 controller + 10 reflex tests
- **v5.0 shipped 2026-04-12:** UmbScraper 2133→175 lines (10 services), UmbScraperV2 deleted (585 lines absorbed), SoopLive JSON API integrated, video cross-referencing built
- **v6.0 shipped 2026-04-13:** Documentation audit + repair — 75 broken links fixed, 8 namespace pages, Video:: docs, 35-service guide, 17 bilingual pairs, zero mkdocs warnings
- **v7.0 shipped 2026-04-15:** Manager Experience — 7 phases (33-37), 37/37 requirements, 31 plans, Turnierverwaltung walkthrough rewritten task-first in DE/EN, 58-finding doc accuracy review applied, wizard header redesign with dominant AASM state badge, 16 parameter tooltips, reset/parameter confirmation modals, `admin_controlled` removed with auto-advance gate, printable A4 Quick-Reference Card, in-app wizard-to-doc links with 4 stable anchors, `mkdocs_link` helper locale bug fixed. 145 test runs + 41 new assertions for Phase 37 helper contract. Human UAT (2026-04-15) confirmed all functional criteria; 5 follow-up gaps captured in `v71-ux-polish-i18n-debt.md` seed.
- Test suite: 1145+ runs, 0 failures, 0 errors
- Sync: PaperTrail + RegionTaggable filtering, local servers pull via Version.update_from_carambus_api
- ApiProtector + LocalProtector both have test overrides in test_helper.rb
- Extracted services (37 total): ScoreEngine, GameSetup, OptionsPresenter, ResultRecorder, ClubCloudClient + 9 syncers (v1.0), RankingCalculator, TableReservationService, PublicCcScraper, PlayerGroupDistributor, RankingResolver, ResultProcessor, TablePopulator (v2.1), League::StandingsCalculator, League::GamePlanReconstructor, League::ClubCloudScraper, League::BbvScraper, PartyMonitor::TablePopulator, PartyMonitor::ResultProcessor (v4.0), Umb::HttpClient, Umb::DisciplineDetector, Umb::DateHelpers, Umb::PlayerResolver, Umb::PdfParser::PlayerListParser, Umb::PdfParser::GroupResultParser, Umb::PdfParser::RankingParser, Umb::FutureScraper, Umb::ArchiveScraper, Umb::DetailsScraper (v5.0)
- Video services (v5.0): Video::MetadataExtractor, Video::TournamentMatcher, SoopliveBilliardsClient
- Codebase map available at `.planning/codebase/`
- **v3.0 shipped 2026-04-11:** Capybara/Selenium system test infrastructure, 5 broadcast isolation tests (morph, score:update, table_scores, rapid-fire, 3-session), BROADCAST-GAP-REPORT.md documenting all results + deferred FIX-01/FIX-02
- Broadcast isolation: client-side JS filtering on global `table-monitor-stream` verified correct; server-side targeted broadcasts deferred (FIX-01/FIX-02)

## Constraints

- **Behavior preservation (scoped)**: Unchanged flows must continue to work identically. New features may extend behavior. Phases marked `cleanup` enforce absolute preservation; phases marked `feature` or `mixed` are allowed to add behavior that didn't exist before.
- **Incremental**: Each change must be independently deployable
- **Test-first**: Tests before any refactoring or feature addition
- **Volunteer persona filter**: UX and doc decisions are judged against "would a volunteer club officer who uses this 2-3x/year understand this?"

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Start with TableMonitor and RegionCc only | Worst offenders by line count (3900 and 2700 lines) | ✓ Good — both reduced significantly |
| Write characterization tests before extracting | Ensures refactoring doesn't break existing behavior | ✓ Good — 58 char tests caught every regression |
| Extract to service classes, not concerns | Services are more testable and explicit than concerns | ✓ Good — 14 services extracted with clear boundaries |
| ScoreEngine as PORO, not ApplicationService | Stateful hash wrapper called many times per game | ✓ Good — lazy accessor pattern reused by OptionsPresenter |
| Fine-grained RegionCc syncers (9 classes) | User chose focused services over 3 large ones | ✓ Good — each syncer independently testable |
| suppress_broadcast replacing skip_update_callbacks | Explicit flag with no leaked state | ✓ Good — 79 call sites migrated cleanly |
| Fixtures primary, not FactoryBot | Already dominant, no factory definitions existed | ✓ Good — zero FactoryBot usage confirmed by audit |
| Delete empty test stubs rather than backfill | False confidence worse than no test file | ✓ Good — 10 stubs removed cleanly |
| Fix sole-assertion cases only | Precondition checks (followed by stronger assertions) are acceptable | ✓ Good — targeted fixes, no over-correction |
| ApiProtectorTestOverride in test_helper.rb | Prevents silent save rollbacks in API server context tests | ✓ Good — resolved hidden test failures |
| Production fixture plans for T04/T06 tests | Real executor_params JSON, not programmatic generation | ✓ Good — pins real-world plan structure |
| Test files by plan type (T04/T06/KO) not by concern | Each file covers all paths for one tournament format | ✓ Good — focused, readable test files |
| PORO for pure algorithms, ApplicationService for side effects | PlayerGroupDistributor/RankingResolver/RankingCalculator as POROs, PublicCcScraper/TableReservationService as ApplicationService | ✓ Good — consistent pattern |
| Services in app/services/tournament/ and tournament_monitor/ | Follows existing table_monitor/ pattern from v1.0 | ✓ Good — clean namespace separation |
| DB lock stays inside ResultProcessor service | Pessimistic lock is result processing logic, not model infrastructure | ✓ Good — lock behavior preserved exactly |
| AASM events fired on @tournament_monitor from services | After_enter callbacks execute correctly through model reference | ✓ Good — no AASM coupling leaks |
| Delete lib/tournament_monitor_support.rb after extraction | File empty after all methods moved to services | ✓ Good — eliminated 1078-line legacy module |
| Global async cable adapter for system tests | Simpler than per-test override; ActionCable::TestHelper swaps adapter for channel unit tests | ✓ Good — zero channel test regressions |
| local_server? via ApplicationSystemTestCase setup/teardown | Global carambus.yml change would break 50+ tests; scoped override safer | ✓ Good — established pattern, zero regressions |
| DOM marker for console.warn capture (not Selenium logs API) | More portable across ChromeDriver versions | ✓ Good — reliable filter proof |
| Verify-only milestone (no broadcast fix) | Document gaps, defer FIX-01/FIX-02 to future milestone | ✓ Good — clean separation of concerns |
| League:: namespace for extracted services | Matches Tournament::, TournamentMonitor::, TableMonitor:: patterns | ✓ Good — consistent namespace hierarchy |
| PORO for standings, ApplicationService for scraping | Pure calculation vs side-effect-heavy operations | ✓ Good — StandingsCalculator PORO, scrapers as ApplicationService |
| PartyMonitor PORO matching TournamentMonitor | Direct analog — same AASM-driven extraction pattern | ✓ Good — TablePopulator + ResultProcessor mirror TournamentMonitor services |
| Pessimistic lock stays in model for PartyMonitor | Lock boundary and AASM events are model responsibilities | ✓ Good — services do data work only, model owns state |
| Thin delegation wrappers (permanent API) | Zero caller changes, wrappers are permanent not transitional | ✓ Good — all controllers/reflexes/jobs unmodified |
| Fix fixtures before controller tests | Party fixture chain broken (party_id → nonexistent party) | ✓ Good — unblocked 4 skipped tests immediately |
| Research-first for UMB data sources | Complexity may be inherent to data source, not just code | ✓ Good — discovered SoopLive JSON API, avoided wasted effort on umbevents/Cuesco |
| Umb:: namespace for all extracted services | Consistent with League::, Tournament::, etc. | ✓ Good — 10 services in clean namespace |
| Delete UmbScraperV2 entirely (not facade) | Zero production callers; only PDF parsing was valuable | ✓ Good — clean break, PDF logic in first-class Umb::PdfParser::* POROs |
| Pull Umb::HttpClient into Phase 25 (early) | SSL fix needed before extraction; reused in Phase 26 | ✓ Good — single SSL config point from the start |
| Split PdfParser by type (3 classes) | Player lists, group results, rankings have distinct formats | ✓ Good — independently testable, clean D-08 output contracts |
| Merge Phase 27 (V2 Resolution) into Phase 26 | V2 unused; PDF parsing is V2's only value | ✓ Good — eliminated unnecessary phase, tighter milestone |
| SoopLive replay_no over data-seq HTML | JSON API provides same data structured; no HTML scraping needed | ✓ Good — higher precision, simpler implementation |
| Regex-first + AI fallback for MetadataExtractor | Most titles have known patterns; AI only for outliers | ✓ Good — avoids API cost for majority of videos |
| Confidence scoring with 0.75 threshold | Auto-assign above threshold; below requires review | ✓ Good — measurable, tunable |
| Both backfill + incremental for video matching | Rake task for existing backlog, daily job for new videos | ✓ Good — enables measuring match rate before automation |
| Split Phase 36 into 36a/36b/36c | 58-finding doc review exposed scope was 17 requirements too narrow; splitting preserved momentum | ✓ Good (v7.0) — each sub-phase shipped with tight scope, 36a landed doc accuracy while 36b did UI in parallel |
| Bucket chips replace "Schritt N von 6" progress text | Linear framing overstates manager activity during passive phases (F-36-30) | ✓ Good (v7.0) — 6 chips with active highlight matches the actual 6 AASM bucket states |
| Dominant AASM state badge as primary orientation | 2-3x/year volunteers need "where am I" at a glance more than "how far" | ✓ Good (v7.0) — colored 2xl badge with per-state mapping, Phase 36B UAT confirmed |
| Shared Stimulus confirmation modal for UI-06 + UI-07 | Both are safety confirmations, same pattern cuts implementation work in half | ✓ Good (v7.0) — single controller + partial reused by reset and parameter-verification flows |
| admin_controlled column kept, gate flipped to always-true | Preserves read-compatibility with global records; zero migration | ✓ Good (v7.0) — automatic round advance works, no schema churn |
| Phase 37 doc deep-links via explicit `{#anchor}` attrs in both .de.md and .en.md | Locale-neutral stable anchors; Ruby helper stays locale-agnostic for fragments | ✓ Good (v7.0) — 4 anchors (seeding-list, participants, mode-selection, start-parameters) |
| `mkdocs_link` helper follows `docs_page.html.erb:18-22` (DE root, EN prefix) | REQUIREMENTS wording said `/docs/de/` but actual mkdocs build has no DE prefix | ✓ Good (v7.0) — code is authoritative over requirements prose; zero mkdocs.yml changes |
| `mkdocs_link` callers must pass `text:` explicitly (no humanize fallback) | Auto-humanize produces English text in DE views, which is wrong | ✓ Good (v7.0) — i18n keys under `tournaments.docs.*` keep link text localized |
| Phase 36B human UAT gaps captured as seed, not todos | 5 non-regression items that belong together; seed surfaces at next milestone kickoff | ✓ Good (v7.0) — `v71-ux-polish-i18n-debt.md` planted with concrete fix sketches |
| `bin/rails mkdocs:build` run at milestone-completion time as part of UAT | G-02 discovered `public/docs/` stale since Mar 18; inline fix closed the gap | ✓ Good (v7.0, but flagged as deployment-hardening debt) — structural fix deferred to v7.1 or later |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-25 after Phase 38.4 (BK2-Kombi post-dry-run gaps) — closed all 8 deferred issues (I1-I5, I7, I8, I9), hard-renamed `Bk2Kombi::*` → `Bk2::*`, generalized scoring across the 5 BK-* family disciplines (BK-2kombi, BK-2plus, BK-2, BK50, BK100), restructured Discipline data model with `data[:free_game_form]` + `data[:ballziel_choices]`, replaced legacy `set_target_points` with `balls_goal`, added `Version.safe_parse` to unblock central Discipline propagation. 4 browser-test items remain open in `38.4-HUMAN-UAT.md` (Delete escape-hatch, balls_goal end-to-end, Alpine conditional inputs, shootout 4-btn) — testable on 2026-05-02 BCW dry-run tournament. 7 advisory findings (1 Critical pre-existing typo, 6 Warnings) deferred to next phase via `38.4-VERIFICATION.md` `advisory_deferred:`.*
