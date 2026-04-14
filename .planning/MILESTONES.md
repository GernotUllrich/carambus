# Milestones

## v7.0 Manager Experience (Shipped: 2026-04-15)

**Phases completed:** 7 phases (33, 34, 35, 36a, 36b, 36c, 37), 31 plans, 37/37 requirements
**Theme:** Make Carambus usable for the 2-3x/year volunteer club officer persona
**Delivered:** Task-first walkthrough + happy-path UX polish + safety confirmations + in-app wizard-to-doc links

**Key accomplishments by phase:**

**Phase 33 — UX Review & Wizard Audit:**
- Canonical wizard partial identified (`_wizard_steps_v2.html.erb`); non-canonical partial retired
- 24 tournament wizard findings tier-classified (14 Tier 1 view, 7 Tier 2 controller, 1 Tier 3 AASM); UX-FINDINGS.md authored as spec for downstream phases
- Transient `tournament_started_waiting_for_monitors` AASM state observed and documented

**Phase 34 — Task-First Doc Rewrite:**
- Both `tournament-management.{de,en}.md` rewritten as volunteer-friendly 14-step walkthrough (NDM Freie Partie scenario) with glossary, troubleshooting, and matching bilingual skeleton
- `docs/managers/index.{de,en}.md` "Quick Start: 10 Steps" corrected to reflect the actual ClubCloud-sourced workflow
- 3 Phase 33 screenshots embedded at walkthrough steps 2, 6, 10 in both languages
- 18-term grouped glossary + 4-case Problem/Cause/Fix troubleshooting

**Phase 35 — Printable Quick-Reference Card:**
- A4 printable `tournament-quick-reference.{de,en}.md` with Before/During/After checklist (21 items per language) + scoreboard keyboard shortcut cheat sheet (14 rows + ASCII keycap strip)
- Shared `@media print` stylesheet stripping mkdocs-material chrome; laminate-ready layout; mkdocs nav + DE label `Turnier-Schnellreferenz` wired in one atomic commit
- 13 deep-links to Phase 34 walkthrough anchors; zero new strict warnings

**Phase 36a — Turnierverwaltung Doc Accuracy:**
- 57 of 58 F-36-NN findings applied across both language files (F-36-55 deferred to 36b UI-07)
- Begriffshierarchie (Setzliste / Meldeliste / Teilnehmerliste) enforced consistently; Ballziel vs. Aufnahmebegrenzung disambiguated; Default{n} plan framing; logical vs. physical table mapping
- Fictional UI elements removed ("Modus ändern" button, "Ergebnisse nach ClubCloud übertragen" Schaltfläche, DB-Admin recovery myth)
- New glossary entries (Meldeliste, Teilnehmerliste, Logischer Tisch, Physikalischer Tisch, TableMonitor, Turnier-Monitor, Trainingsmodus, Freilos, T-Plan vs. Default-Plan)
- 10 troubleshooting recipes (6 new + 4 rewritten)
- New Anhang/Appendix with 6 special-flow sub-sections (no-invitation, missing-player, late-registration, CC 2-path upload, CC CSV detail, manual final-ranking)
- Walkthrough restructured to honestly distinguish manager-action phases from passive phases

**Phase 36b — UI Cleanup & Kleine Features:**
- Wizard header redesign: dominant colored AASM state badge + 6 bucket chips (replacing "Schritt N von 6" progress bar), active step's help auto-opens via `<details open>`
- Full i18n conversion of 16 parameter labels in `tournament_monitor.html.erb` + new Stimulus `tooltip_controller` rendering dark Tailwind hover cards
- `admin_controlled` checkbox removed + reflex handler deleted + `Tournament#player_controlled?` gate flipped to always-true (column kept for global-record read compatibility)
- Dead-code manual input removed from "Aktuelle Spiele" table (read-only table); unused `_wizard_steps.html.erb` partial deleted
- Shared Stimulus confirmation modal infrastructure: reset modal (always shown regardless of AASM state) + parameter-verification modal triggered by `Discipline#parameter_ranges` out-of-range values before `start_tournament!`
- Human UAT confirmed (2026-04-15) all 8 visual criteria; 5 non-regression follow-up gaps captured in seed

**Phase 36c — v7.1 Preparation / ClubCloud Integration Groundwork:**
- v7.1 ClubCloud Integration milestone skeleton (Endrangliste automatic calculation, Teilnehmerliste finalization via CC API, credentials delegation)
- v7.2 Shootout/Stechen support milestone skeleton (AASM + TournamentPlan + scoreboard UI)
- Backlog seeds planted: Match-Abbruch/Freilos handling (medium), UI consolidation of historically grown screens (large)
- ClubCloud admin-side handling appendix content authored and supplied to Phase 36a DOC-ACC-04

**Phase 37 — In-App Doc Links:**
- `mkdocs_link` helper fixed for locale-aware URL generation (DE root `/docs/#{path}/`, EN `/docs/en/#{path}/`) matching `docs_page.html.erb:18-22` exactly; new `anchor:` kwarg; text-required guard (no humanize fallback); `target="_blank" rel="noopener"` preserved
- 3 new i18n keys under `tournaments.docs.*` namespace in DE + EN (walkthrough_link, form_help_link, form_help_prefix)
- 4 stable `{#anchor}` attrs added to both `.de.md` and `.en.md` (`#seeding-list`, `#participants`, `#mode-selection`, `#start-parameters`) — language-neutral kebab-case IDs, `attr_list` markdown extension already enabled
- `_wizard_step.html.erb` partial extended with optional `docs_path:` + `docs_anchor:` locals; all 6 happy-path wizard steps wired (steps 3/4/5 via partial, steps 1/2/6 inline); 5 of 6 deep-linked, 1 page-top
- 4 form-help info boxes added (`parse_invitation`, `define_participants`, `finalize_modus`, `tournament_monitor`) reusing Begriffserklärung Tailwind classes; Phase 36b tooltips on `tournament_monitor.html.erb` remain byte-identical (16 → 16)
- Minitest helper tests (13 runs / 27 assertions) + controller integration test (2 runs / 14 assertions) for DE + EN wizard doc-link rendering; all green

**Cross-cutting fix discovered during UAT:**
- **G-02 inline fix**: `public/docs/` rebuilt via `bin/rails mkdocs:build` — `public/docs/` had been stale since 2026-03-18, so all Phase 34/35/36a/37 doc source changes were bypassed by the Rails server. Commit `7cf16114` regenerated 257 files (+70,891 / −14,984 lines). Structural deployment hardening (pre-commit hook / CI guard) deferred to a future milestone.

**Follow-up debt (captured in seed `.planning/seeds/v71-ux-polish-i18n-debt.md`):**
- G-01 (medium): Dark-mode contrast in wizard `<details>` help block + inline-styled info banners
- G-03 (low): Tooltip labels lack visual affordance (dashed underline + cursor: help)
- G-04 (low): Pre-existing DE-only hardcoded strings outside parameter form (NOT a v7.0 regression)
- G-05 (low): EN "Training" should be "Warmup" at `config/locales/en.yml:844-846` (pre-existing bug)
- G-06 (medium): `Discipline#parameter_ranges` derived from one specific scenario, needs widening
- All 5 are candidates for a v7.1 "UX polish & i18n debt" micro-phase (1-3 plans, ~2h-1d total)

**Stats:**
- 7 phases, 31 plans, 37/37 requirements (36 shipped + 1 closed as no-op FIX-02)
- Phase 37 added 41 new Minitest assertions
- Phase 36a applied 57/58 doc findings (1 deferred to 36b)
- Zero mkdocs `--strict` warnings (baseline 191 → 0 since Phase 36c groundwork tightening)
- Test suite: 1145+ runs, 0 failures, 0 errors

---

## v6.0 Documentation Quality (Shipped: 2026-04-13)

**Phases completed:** 5 phases, 12 plans, 20 tasks

**Key accomplishments:**

- Three audit tools created: translation gap checker, stale code reference detector, and CI-ready mkdocs strict-build task — plus archive exclusion from search indexing
- 133-finding staleness inventory in docs/audit.json + docs/DOCS-AUDIT-REPORT.md: 75 broken links, 6 stale refs, 9 coverage gaps, 43 bilingual gaps — all classified and phase-assigned to gate Phases 29-32
- 44 broken links cleared in one pass: 32 missing screenshot image refs replaced with text placeholders and 12 template example links encoded with HTML entities to prevent checker false positives
- 31 remaining broken links de-linked across 17 files and 3 stale code references updated to current names — both checker scripts report zero findings, completing Phase 29 FIX-01 and FIX-02
- Stale UmbScraperV2 planning docs replaced with accurate bilingual Umb:: namespace documentation — 4 files covering 10 services, 3 entry points, and 3 PDF parser output contracts
- Added 35-service inventory across 7 namespace tables to both German and English developer guides, with file paths and one-liner descriptions for every extracted service.
- TableMonitor::
- league.de.md / league.en.md
- Bilingual DE+EN documentation for the Video:: cross-referencing system: TournamentMatcher confidence scoring (0.75 threshold, 3 weighted signals), MetadataExtractor regex+gpt-4o-mini AI fallback, and SoopliveBilliardsClient replay_no linking with operational workflow
- Services nav block with 8 Phase 31 pages wired into mkdocs.yml, exclude_docs expanded to eliminate 24 orphan warnings, and 7 broken cross-doc links fixed — reducing strict build warnings from 62 to 5
- 5 monolingual plain .md files renamed to language-suffixed pairs and full AI-assisted translations created — 10 doc files total, 5 git commits (one per pair per D-08)
- 3 remaining monolingual files renamed to language-suffixed pairs, full AI-assisted translations created, table-reservation.de.md created — all 17 bilingual gaps resolved, v6.0 Documentation Quality milestone final gate PASSED with zero issues across all four verification scripts

---

## v5.0 UMB Scraper Überarbeitung (Shipped: 2026-04-12)

**Phases completed:** 4 phases, 12 plans
**Timeline:** 2026-04-12 (single day)
**Git stats:** 71 commits, 129 files changed, +16144/-9355 lines

**Key accomplishments:**

- Discovered undocumented SoopLive JSON API (`/api/games`, `/api/game/{id}/matches`, `/api/game/{id}/results`) — `replay_no` enables direct VOD linking; umbevents and Cuesco confirmed NO-GO (HTML only)
- UmbScraper reduced from 2133 to 175 lines (91.8% reduction) via 10 extracted `Umb::` services: HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser, GroupResultParser, RankingParser, FutureScraper, ArchiveScraper, DetailsScraper
- UmbScraperV2 (585 lines) fully absorbed into Umb:: services and deleted; PDF parsing promoted to first-class `Umb::PdfParser::*` POROs
- Fixed 3 pre-existing bugs: TournamentDiscoveryService column reference, ScrapeUmbArchiveJob kwargs mismatch, SSL verification inconsistency
- Implemented RANK-01: UMB ranking PDF parsing for both weekly and final tournament rankings
- Built video cross-referencing system: `Video::TournamentMatcher` (confidence scoring), `Video::MetadataExtractor` (regex-first + AI fallback), `SoopliveBilliardsClient` (full adapter), Kozoom eventId cross-ref
- Wired `DailyInternationalScrapeJob` Steps 3a/3b/3c for incremental matching; `rake videos:match_tournaments` for backfill

---

## v4.0 League & PartyMonitor Refactoring (Shipped: 2026-04-12)

**Phases completed:** 4 phases, 9 plans, 13 tasks

**Key accomplishments:**

- 18 characterization tests pinning LeagueTeam (associations, cc_id_link, scrape stub) and Party (associations, name/intermediate_result/party_nr, boolean flags, data) with fixture infrastructure for dependent plans
- Created `test/models/league_standings_test.rb`
- One-liner:
- League::StandingsCalculator PORO and League::GamePlanReconstructor ApplicationService extracted from league.rb, reducing model by 618 lines (2221 -> 1603) while preserving all 25 Phase 20 characterization tests unchanged
- 1. [Rule 1 - Bug] Fixed undefined `records_to_tag` variable in scrape_bbv_leagues
- One-liner:
- PartyMonitor::ResultProcessor PORO extracts 5-method result pipeline + 2 private helpers from 489-line model, reducing it to 217 lines with thin delegation wrappers
- Fixed party_monitors fixture chain, resolved Phase 22 behavioral regression in placement test, and added 13 integration tests for LeaguesController and LeagueTeamsController.
- Fixed PartyMonitorsController tests (0 skips), created PartiesController integration tests, added PartyMonitorReflex unit tests for 5 critical paths, and documented COV-02 (no channels/jobs to test). Full suite green.

---

## v3.0 Broadcast Isolation Testing (Shipped: 2026-04-11)

**Phases completed:** 3 phases, 6 plans, 10 tasks

**Key accomplishments:**

- ActionCable async adapter + scoped local_server? override in ApplicationSystemTestCase enabling Phase 18 Selenium broadcast isolation tests
- Passing Capybara/Selenium smoke test proving AASM state change -> TableMonitorJob.perform_now -> CableReady inner_html -> browser DOM update via ActionCable async adapter
- One-liner:
- One-liner:
- Six rapid-fire alternating broadcasts and three simultaneous browser sessions all prove zero broadcast bleed via JS filter counter verification
- Comprehensive gap report documenting all 11 v1 broadcast isolation requirements as PASS, architectural risk of global stream with client-side filtering, 4 Phase 18 development findings, and FIX-01/FIX-02 deferred v2 fix references.

---

## v2.1 Tournament & TournamentMonitor Refactoring (Shipped: 2026-04-11)

**Phases completed:** 6 phases, 15 plans, 21 tasks

**Key accomplishments:**

- 23 Minitest characterization tests pinning TournamentMonitor T04 round-robin behavior: AASM transitions, GROUP_RULES-based player distribution, game creation sequencing, and ApiProtectorTestOverride verification — backed by production-exported fixture plans
- 24 Minitest characterization tests pinning TournamentMonitor T06 with-finals behavior: AASM full lifecycle through group and finals phases, group game creation, result pipeline (update_game_participations, write_game_result_data, accumulate_results), and group phase detection — plus pre-extraction size baseline
- 53 characterization tests pinning Tournament AASM state machine (8 events, 2 guards, 2 callbacks) and all 13 dynamic define_method getter/setter paths before extraction work begins
- PaperTrail version baselines and Google Calendar guard conditions pinned for Tournament — 21 characterization tests establish exact counts for all state-changing operations and verify the full create_table_reservation -> GoogleCalendarService wiring.
- One-liner:
- Pure distribution algorithm (DIST_RULES, GROUP_RULES, GROUP_SIZES + distribute_to_group/distribute_with_sizes) extracted from TournamentMonitor into a PORO service class with delegation wrappers preserving all callers
- Tournament::RankingCalculator PORO extracted from tournament.rb — calculate_and_cache_rankings and reorder_seedings delegated, 50 lines removed
- One-liner:
- RankingResolver PORO extracted from TournamentMonitor with 5 methods, cross-service call to PlayerGroupDistributor (D-05), and delegation wrapper reducing TournamentMonitor by ~168 lines
- One-liner:
- 500+ line table population algorithm extracted from lib modules into TournamentMonitor::TablePopulator PORO service, with lib/tournament_monitor_support.rb fully deleted and tournament_monitor_state.rb reduced to 5 query methods
- 55 Minitest integration tests covering all 20+ TournamentsController actions, verifying ensure_local_server guard, public access behavior, CRUD, state transitions, and data manipulation actions
- 19 new tests covering TournamentMonitorsController (10), TournamentChannel (2), TournamentMonitorChannel (2), TournamentStatusUpdateJob (3), and TournamentMonitorUpdateResultsJob (2) — all passing
- v2.1 milestone final quality gates confirmed: Tournament model at 575 lines, 751-run test suite green with 0 failures, and all 12 PaperTrail baseline assertions passing

---

## v2.0 Test Suite Audit & Improvement (Shipped: 2026-04-10)

**Phases completed:** 5 phases, 11 plans, 14 tasks

**Key accomplishments:**

- STANDARDS.md created with 6-section conventions rubric covering fixtures-first setup, MiniTest assertion style, test naming, 4 support file analysis with usage data, file structure template, and 7 issue category codes for the Phase 7-9 audit.
- Per-file issue catalogue for all 72 test files — 10 empty scaffold stubs, 26 files with weak assertions, 2 skipped tests, 40 files missing frozen_string_literal, zero naming or FactoryBot violations.
- 10 empty scaffold test stubs deleted from test/models/ and frozen_string_literal: true added to 2 clean model test files
- Sole assert_nothing_raised and assert_not_nil weak assertions fixed in 5 test files; 6 pre-existing bugs auto-fixed including ko_ranking nil guard and test helper attribute errors
- One-liner:
- 3 presence-only and sole-assertion weak spots fixed in GameSetup and ResultRecorder tests — game_id now verified by value; evaluate_result path confirmed via state and panel_state assertions
- 6 targeted test quality fixes: deleted non-test script, removed always-passing assertion, rewrote phantom-method tests against actual helper, strengthened sync_date assertion, replaced brittle CSRF regex, removed hardcoded sleep
- ApiProtectorTestOverride added and 5 fixture files fixed, reducing errors from 75 to 66 and revealing 82 pre-existing failures previously masked by setup errors
- 1. [Rule 1 - Bug] League::DBU_ID crashes in test env without safe navigation
- 7 VCR cassettes created for RegionCcCharTest — all 17 tests now green (0 failures, 0 errors, 0 skips), QUAL-04 resolved

---

## v1.0 Model Refactoring (Shipped: 2026-04-10)

**Phases completed:** 5 phases, 18 plans, 28 tasks

**Key accomplishments:**

- 39-test characterization suite pins TableMonitor AASM state machine, after_enter callbacks, and all after_update_commit routing branches before extraction work begins
- 56-test RegionCc characterization suite with VCR cassette wrappers, plus Reek smell baselines documenting 781 TableMonitor and 460 RegionCc warnings before extraction begins
- Two end-to-end tests close the VERIFICATION.md SC-1 gap: ultra_fast ("score_data") and simple ("player_score_panel") after_update_commit branches are now pinned through the full before_save -> log_state_change -> @collected_data_changes -> routing pipeline
- Extracted get_cc/post_cc/post_cc_with_formdata/get_cc_with_url from RegionCc model into standalone RegionCc::ClubCloudClient with PATH_MAP constant and zero ActiveRecord coupling
- Extracted sync_leagues, sync_league_teams, sync_league_teams_new, sync_league_plan, sync_team_players, sync_team_players_structure into LeagueSyncer; sync_clubs into ClubSyncer; sync_branches into BranchSyncer — all using injected ClubCloudClient
- RegionCc::TournamentSyncer
- One-liner:
- 1. sync_team_players_structure delegation
- One-liner:
- One-liner:
- One-liner:
- TableMonitor::GameSetup extracts start_game/assign_game from the 3900-line model into a testable ApplicationService with dual entry points, ensure-guaranteed broadcast cleanup, and single job enqueue
- 1. [Rule 1 - Bug] Kept initialize_game in model
- get_options! extracted from ~193-line inline body to TableMonitor::OptionsPresenter PORO + 23-line delegation wrapper, with 11 unit tests — 121 total tests pass
- Mechanical rename of 79 skip_update_callbacks occurrences to suppress_broadcast across 7 files, removing transitional alias shims from TableMonitor to close SC #2 verification gap
- TableMonitor::ResultRecorder ApplicationService extracted with 5 entry points (save_result, save_current_set, get_max_number_of_wins, switch_to_next_set, evaluate_result), removing ~300 lines from TableMonitor via thin delegation wrappers
- Part A: initialize_game → GameSetup
- All 4 extracted TableMonitor services verified with 140 passing tests; Reek warnings reduced from 781 to 306 (61% reduction), confirming measurable quality improvement from Phase 1 baseline

---
