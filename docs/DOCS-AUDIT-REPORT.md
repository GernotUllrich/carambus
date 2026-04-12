# Documentation Audit Report

Generated: 2026-04-12
Phase: 28-audit-triage

## Summary

| Category | Count | Target Phase |
|----------|-------|-------------|
| Broken Links | 75 | Phase 29 |
| Stale Code References | 6 | Phase 29 (3), Phase 30 (3) |
| Coverage Gaps (services) | 8 namespaces | Phase 31 |
| Bilingual Gaps (nav-linked) | 21 | Phase 32 |
| Bilingual Gaps (non-nav, deferred) | 22 | TRANSLATE-01 |
| **Total Findings** | **133** | |

## Archive Indexing Status

**Status: FIXED in Phase 28**

- `mkdocs.yml` `exclude_docs` now excludes `archive/**` and `obsolete/**`
- Archive pages are no longer built into the site or indexed by search
- This change was applied in Plan 28-01 (FIND-090 in audit.json)

## Broken Links (Phase 29)

75 broken links across 8 files/directories.

### administrators/ (1 link)

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| administrators/streaming-production-deployment.md | 571 | Systemd Services | systemd-streaming-services.md | medium |

### developers/ (19 links)

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| developers/developer-guide.en.md | 366 | Enhanced Mode System | ../developers/enhanced_mode_system.md | high |
| developers/developer-guide.en.md | 458 | Enhanced Mode System | ../developers/enhanced_mode_system.md | high |
| developers/operations/tournament-game-protection.de.md | 254 | FLASH_MESSAGES_SCOREBOARD.md | FLASH_MESSAGES_SCOREBOARD.md | high |
| developers/rake-tasks-debugging.de.md | 423 | Scenario Management Workflow | ./scenario-system-workflow.md | high |
| developers/rake-tasks-debugging.en.md | 419 | Scenario Management Workflow | ./scenario-system-workflow.md | high |
| developers/scenario-workflow.md | 136 | CONTRIBUTING.de.md | CONTRIBUTING.md | high |
| developers/scenario-workflow.md | 137 | README.de.md | README.md | high |
| developers/scenario-workflow.md | 138 | carambus_master/docs/developers/ | carambus_master/docs/developers/ | high |
| developers/testing/fixture-collection-guide.md | 14 | test/FIXTURES_QUICK_START.md | test/FIXTURES_QUICK_START.md | high |
| developers/testing/fixture-collection-guide.md | 19 | test/FIXTURES_SAMMELN.md | test/FIXTURES_SAMMELN.md | high |
| developers/testing/fixture-collection-guide.md | 25 | test/fixtures/html/README.md | test/fixtures/html/README.md | high |
| developers/testing/fixture-collection-guide.md | 31 | test/FIXTURE_WORKFLOW.md | test/FIXTURE_WORKFLOW.md | high |
| developers/testing/fixture-collection-guide.md | 416 | FIXTURES_QUICK_START.md | test/FIXTURES_QUICK_START.md | high |
| developers/testing/fixture-collection-guide.md | 521 | FIXTURES_QUICK_START.md | test/FIXTURES_QUICK_START.md | high |
| developers/testing/testing-quickstart.md | 283 | Test README | ../developers/testing/testing-quickstart.md | high |
| developers/testing/testing-quickstart.md | 284 | Testing Strategy | ../developers/testing-strategy.md | high |
| developers/testing/testing-quickstart.md | 285 | Snapshots README | test/snapshots/README.md | high |
| developers/testing/testing-quickstart.md | 364 | test/README.md | ../developers/testing/testing-quickstart.md | high |
| developers/testing/testing-quickstart.md | 364 | Testing Strategy | ../developers/testing-strategy.md | high |

### international/ (2 links)

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| international/umb_scraper.md | 237 | International Videos System | ./international_videos.md | medium |
| international/umb_scraper.md | 238 | YouTube Scraper | ./youtube_scraper.md | medium |

### managers/ (2 links)

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| managers/clubcloud_upload_feedback.md | 237 | ClubCloud Name Mapping | ../bin/test-cc-name-mapping.rb | medium |
| managers/clubcloud_upload_feedback.md | 238 | Log Prefixes Reference | logging_conventions.md | medium |

### players/ (34 links)

34 broken image links across 4 files — 22 missing screenshots in `players/screenshots/` (bilingual pair scoreboard-guide DE+EN: 11 each), and 10 missing screenshots across pool_scoreboard_benutzerhandbuch DE+EN (5 each).

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| players/ai-search.de.md | 391 | Carambus Filter-Dokumentation | ../search.md | medium |
| players/ai-search.en.md | 352 | Carambus Filter Documentation | ../search.md | medium |
| players/pool_scoreboard_benutzerhandbuch.de.md | 60 | Tischübersicht | screenshots/pool_tables_overview.png | medium |
| players/pool_scoreboard_benutzerhandbuch.de.md | 157 | 14.1 endlos Scoreboard - Spielstart | screenshots/pool_14_1_scoreboard_start.png | medium |
| players/pool_scoreboard_benutzerhandbuch.de.md | 161 | 14.1 endlos Scoreboard - Während des Spiels | screenshots/pool_14_1_scoreboard_playing.png | medium |
| players/pool_scoreboard_benutzerhandbuch.de.md | 165 | 14.1 endlos Scoreboard - Nach Spielerwechsel | screenshots/pool_14_1_after_switch.png | medium |
| players/pool_scoreboard_benutzerhandbuch.de.md | 405 | Pool Quickstart Buttons | screenshots/pool_quickstart_buttons.png | medium |
| players/pool_scoreboard_benutzerhandbuch.en.md | 60 | Table Overview | screenshots/pool_tables_overview.png | medium |
| players/pool_scoreboard_benutzerhandbuch.en.md | 157 | 14.1 Continuous Scoreboard - Game Start | screenshots/pool_14_1_scoreboard_start.png | medium |
| players/pool_scoreboard_benutzerhandbuch.en.md | 161 | 14.1 Continuous Scoreboard - During Game | screenshots/pool_14_1_scoreboard_playing.png | medium |
| players/pool_scoreboard_benutzerhandbuch.en.md | 165 | 14.1 Continuous Scoreboard - After Player Switch | screenshots/pool_14_1_after_switch.png | medium |
| players/pool_scoreboard_benutzerhandbuch.en.md | 405 | Pool Quickstart Buttons | screenshots/pool_quickstart_buttons.png | medium |
| players/scoreboard-guide.de.md | 43 | Willkommensbildschirm | screenshots/scoreboard_welcome.png | medium |
| players/scoreboard-guide.de.md | 170 | Einspielzeit | screenshots/scoreboard_warmup.png | medium |
| players/scoreboard-guide.de.md | 186 | Ausstoßen | screenshots/scoreboard_shootout.png | medium |
| players/scoreboard-guide.de.md | 201 | Spiel läuft | screenshots/scoreboard_playing.png | medium |
| players/scoreboard-guide.de.md | 304 | Dark Mode | screenshots/scoreboard_dark.png | medium |
| players/scoreboard-guide.de.md | 424 | Tischauswahl | screenshots/scoreboard_tables.png | medium |
| players/scoreboard-guide.de.md | 436 | Spielform wählen | screenshots/scoreboard_game_choice.png | medium |
| players/scoreboard-guide.de.md | 451 | Spieler auswählen | screenshots/scoreboard_player_selection.png | medium |
| players/scoreboard-guide.de.md | 476 | Freie Partie Setup | screenshots/scoreboard_free_game_setup.png | medium |
| players/scoreboard-guide.de.md | 502 | Quick Game | screenshots/scoreboard_quick_game.png | medium |
| players/scoreboard-guide.de.md | 519 | Pool Setup | screenshots/scoreboard_pool_setup.png | medium |
| players/scoreboard-guide.en.md | 42 | Welcome Screen | screenshots/scoreboard_welcome.png | medium |
| players/scoreboard-guide.en.md | 169 | Warm-up | screenshots/scoreboard_warmup.png | medium |
| players/scoreboard-guide.en.md | 185 | Shootout | screenshots/scoreboard_shootout.png | medium |
| players/scoreboard-guide.en.md | 200 | Game Running | screenshots/scoreboard_playing.png | medium |
| players/scoreboard-guide.en.md | 303 | Dark Mode | screenshots/scoreboard_dark.png | medium |
| players/scoreboard-guide.en.md | 423 | Table Selection | screenshots/scoreboard_tables.png | medium |
| players/scoreboard-guide.en.md | 435 | Choose Game Type | screenshots/scoreboard_game_choice.png | medium |
| players/scoreboard-guide.en.md | 450 | Player Selection | screenshots/scoreboard_player_selection.png | medium |
| players/scoreboard-guide.en.md | 475 | Straight Rail Setup | screenshots/scoreboard_free_game_setup.png | medium |
| players/scoreboard-guide.en.md | 501 | Quick Game | screenshots/scoreboard_quick_game.png | medium |
| players/scoreboard-guide.en.md | 518 | Pool Setup | screenshots/scoreboard_pool_setup.png | medium |

### reference/ (16 links)

8 are intentional placeholder examples in mkdocs_dokumentation files (low severity). 8 are real broken links.

| File | Line | Link Text | Target | Severity | Note |
|------|------|-----------|--------|----------|------|
| reference/config-lock-files.de.md | 152 | Produktions-Setup | PRODUCTION_SETUP.md | low | |
| reference/config-lock-files.en.md | 152 | Production Setup | PRODUCTION_SETUP.md | low | |
| reference/glossary.de.md | 412 | Filter & Suche | ../search.md | low | |
| reference/glossary.en.md | 412 | Filter & Search | ../search.md | low | |
| reference/mkdocs_documentation.en.md | 264 | Text | file.md | low | intentional documentation example |
| reference/mkdocs_documentation.en.md | 265 | Text | file.md | low | intentional documentation example |
| reference/mkdocs_documentation.en.md | 271 | Alt Text | assets/image.png | low | intentional documentation example |
| reference/mkdocs_documentation.en.md | 272 | Alt Text | assets/image.png | low | intentional documentation example |
| reference/mkdocs_dokumentation.de.md | 264 | Text | datei.md | low | intentional documentation example |
| reference/mkdocs_dokumentation.de.md | 265 | Text | datei.md | low | intentional documentation example |
| reference/mkdocs_dokumentation.de.md | 271 | Alt-Text | assets/bild.png | low | intentional documentation example |
| reference/mkdocs_dokumentation.de.md | 272 | Alt-Text | assets/bild.png | low | intentional documentation example |
| reference/mkdocs_dokumentation.en.md | 264 | Text | file.md | low | intentional documentation example |
| reference/mkdocs_dokumentation.en.md | 265 | Text | file.md | low | intentional documentation example |
| reference/mkdocs_dokumentation.en.md | 271 | Alt Text | assets/image.png | low | intentional documentation example |
| reference/mkdocs_dokumentation.en.md | 272 | Alt Text | assets/image.png | low | intentional documentation example |

### training_database.md (1 link)

| File | Line | Link Text | Target | Severity |
|------|------|-----------|--------|----------|
| training_database.md | 442 | API-Dokumentation | ../README.md | low |

## Stale Code References (Phase 29 + Phase 30)

All stale references resolved in Phase 29 (Plan 02). Summary of what was fixed:

### Phase 29 — Fixed (3 findings)

| File | Line | What was there | Fixed to | Severity |
|------|------|---------------|----------|----------|
| developers/umb-scraping-methods.md | 73 | old scraper class name | `Umb:: services` | high |
| developers/clubcloud-upload.de.md | 194 | old support lib path | `app/services/tournament_monitor/` | high |
| developers/clubcloud-upload.en.md | 194 | old support lib path | `app/services/tournament_monitor/` | high |

**Root cause (resolved):** The old scraper service was deleted between v1.0 and v5.0. The support lib was renamed/moved to `app/services/tournament_monitor/`. References have been updated to current paths.

### Phase 30 — Fixed (3 findings)

| File | Lines | What was there | Fixed to | Severity |
|------|-------|---------------|----------|----------|
| developers/tournament-architecture-overview.en.md | 20, 35 | old support module reference | `TournamentMonitor::` services | high |
| developers/tournament-architecture-overview.en.md | 20 | old support lib path | `app/services/tournament_monitor/` | high |

**Root cause (resolved):** `developers/tournament-architecture-overview.en.md` described the old support module as the current active architecture component. The module was split into `TournamentMonitor::TablePopulator`, `TournamentMonitor::ResultProcessor`, etc. during refactoring. References updated to current service namespace.

## Coverage Gaps — Undocumented Services (Phase 31)

8 service namespaces with no documentation — 37 total services across these namespaces.

- **TableMonitor::** (4 services) — CommandHandler, DiagramBuilder, RefreshService, SoundService
- **RegionCc::** (10 services) — BundScraper, LandScraper, BezirkScraper, VereinScraper, ClubSeasonScraper, SeasonScraper, GeneralScraper, Matchers, NameNormalizer, RegionDetector
- **Tournament::** (3 services) — StatusUpdater, RegistrationService, DuplicateResolver
- **TournamentMonitor::** (4 services) — TablePopulator, ResultProcessor, ScoreCalculator, SoundNotifier
- **League::** (4 services) — StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper
- **PartyMonitor::** (2 services) — TablePopulator, ResultProcessor
- **Umb::** (10 services) — HttpClient, DisciplineDetector, DateHelpers, PlayerResolver, PlayerListParser, GroupResultParser, RankingParser, FutureScraper, ArchiveScraper, DetailsScraper
- **Video::** (3 services) — TournamentMatcher, MetadataExtractor, SoopliveBilliardsClient

Phase 31 will create one overview page per namespace (8 pages total) documenting the namespace's purpose, services, and primary interfaces.

## Bilingual Gaps

### Nav-Linked (Phase 32)

21 files in the mkdocs nav have no counterpart in the other language. These are confirmed via `bin/check-docs-translations.rb --nav-only`.

| Nav Entry | Missing File | Gap Direction | Severity |
|-----------|-------------|---------------|----------|
| managers/table-reservation | docs/managers/table-reservation.de.md | EN only, no DE | high |
| developers/deployment-checklist | docs/developers/deployment-checklist.en.md | DE only, no EN | high |
| developers/deployment-checklist | docs/developers/deployment-checklist.de.md | EN only, no DE | high |
| developers/frontend-sti-migration | docs/developers/frontend-sti-migration.en.md | DE only, no EN | high |
| developers/frontend-sti-migration | docs/developers/frontend-sti-migration.de.md | EN only, no DE | high |
| developers/pool-scoreboard-changelog | docs/developers/pool-scoreboard-changelog.en.md | DE only, no EN | high |
| developers/pool-scoreboard-changelog | docs/developers/pool-scoreboard-changelog.de.md | EN only, no DE | high |
| developers/rubymine-setup | docs/developers/rubymine-setup.en.md | DE only, no EN | high |
| developers/rubymine-setup | docs/developers/rubymine-setup.de.md | EN only, no DE | high |
| developers/scenario-workflow | docs/developers/scenario-workflow.en.md | DE only, no EN | high |
| developers/scenario-workflow | docs/developers/scenario-workflow.de.md | EN only, no DE | high |
| developers/testing/fixture-collection-guide | docs/developers/testing/fixture-collection-guide.en.md | DE only, no EN | high |
| developers/testing/fixture-collection-guide | docs/developers/testing/fixture-collection-guide.de.md | EN only, no DE | high |
| developers/testing/testing-quickstart | docs/developers/testing/testing-quickstart.en.md | DE only, no EN | high |
| developers/testing/testing-quickstart | docs/developers/testing/testing-quickstart.de.md | EN only, no DE | high |
| developers/umb-deployment-checklist | docs/developers/umb-deployment-checklist.en.md | DE only, no EN | high |
| developers/umb-deployment-checklist | docs/developers/umb-deployment-checklist.de.md | EN only, no DE | high |
| developers/umb-scraping-implementation | docs/developers/umb-scraping-implementation.en.md | DE only, no EN | high |
| developers/umb-scraping-implementation | docs/developers/umb-scraping-implementation.de.md | EN only, no DE | high |
| developers/umb-scraping-methods | docs/developers/umb-scraping-methods.en.md | DE only, no EN | high |
| developers/umb-scraping-methods | docs/developers/umb-scraping-methods.de.md | EN only, no DE | high |

### Non-Nav (Deferred — TRANSLATE-01)

22 files outside the nav that have no counterpart in the other language. These are confirmed via `bin/check-docs-translations.rb --exclude-archives`.

**21 DE-only files with no EN counterpart:**

| File | Notes |
|------|-------|
| administrators/MIGRATION_NEW_TO_PRODUCTION_DOMAINS.de.md | |
| administrators/raspi-network-stability.de.md | |
| administrators/streaming-comparison.de.md | |
| administrators/streaming-multi-channel.de.md | |
| administrators/streaming-obs-setup.de.md | |
| administrators/streaming-quickstart-iphone-macbook.de.md | |
| developers/debugging/puma-socket-troubleshooting.de.md | |
| developers/debugging/websocket-logging.de.md | |
| developers/operations/scraper-protection.de.md | |
| developers/operations/scraper-protection-advanced.de.md | |
| developers/operations/tournament-game-protection.de.md | |
| developers/setup/ai-search-setup.de.md | |
| developers/setup/development-logging.de.md | |
| developers/setup/email-configuration.de.md | |
| developers/streaming-dev-setup.de.md | |
| developers/test-implementation-summary.de.md | |
| developers/testing-strategy.de.md | |
| developers/testing/admin-settings-test-plan.de.md | |
| developers/testing/ai-search-test-plan.de.md | |
| managers/automatische_tischreservierung.de.md | |
| testing/pool_liga_testplan.de.md | |

**1 EN-only file with no DE counterpart:**

| File | Notes |
|------|-------|
| developers/tournament-architecture-overview.en.md | Also has stale ref findings (FIND-079,080,081) |

## Phase Workload Summary

| Phase | FIX | DELETE | UPDATE | CREATE | Total |
|-------|-----|--------|--------|--------|-------|
| 28 | 1 | 0 | 0 | 0 | 1 |
| 29 | 75 | 1 | 2 | 0 | 78 |
| 30 | 0 | 0 | 3 | 0 | 3 |
| 31 | 0 | 0 | 0 | 8 | 8 |
| 32 | 0 | 0 | 0 | 21 | 21 |
| null (deferred) | 0 | 0 | 0 | 22 | 22 |
| **Total** | **76** | **1** | **5** | **51** | **133** |
