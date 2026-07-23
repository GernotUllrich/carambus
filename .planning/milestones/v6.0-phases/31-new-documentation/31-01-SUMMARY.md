---
phase: 31-new-documentation
plan: "01"
subsystem: documentation
tags: [docs, services, bilingual, namespaces]
dependency_graph:
  requires: []
  provides: [TableMonitor-namespace-docs, RegionCc-namespace-docs, Tournament-namespace-docs, TournamentMonitor-namespace-docs]
  affects: [docs/developers/services/]
tech_stack:
  added: []
  patterns: [bilingual-de-en-docs, namespace-overview-page]
key_files:
  created:
    - docs/developers/services/table-monitor.de.md
    - docs/developers/services/table-monitor.en.md
    - docs/developers/services/region-cc.de.md
    - docs/developers/services/region-cc.en.md
    - docs/developers/services/tournament.de.md
    - docs/developers/services/tournament.en.md
    - docs/developers/services/tournament-monitor.de.md
    - docs/developers/services/tournament-monitor.en.md
  modified: []
decisions:
  - "German primary, English translation — no stubs, full content in both languages"
  - "One commit per bilingual pair (4 commits for 4 namespace pairs)"
  - "Public interfaces only — no private method documentation (D-01)"
metrics:
  duration_minutes: 25
  completed_date: "2026-04-13"
  tasks_completed: 2
  files_created: 8
  files_modified: 0
---

# Phase 31 Plan 01: Service Namespace Overview Pages Summary

Bilingual DE+EN namespace overview pages for 4 extracted service namespaces (TableMonitor::, RegionCc::, Tournament::, TournamentMonitor::) covering 19 of 37 extracted services.

## What Was Built

8 markdown files in the new `docs/developers/services/` subdirectory — 4 German primary pages and 4 full English translations. Each page documents the namespace role, service list, public interfaces with method signatures and data contracts, architecture decisions, and cross-reference links to the developer guide.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1a | TableMonitor:: DE+EN | c27ac884 | table-monitor.de.md, table-monitor.en.md |
| 1b | RegionCc:: DE+EN | eba1264b | region-cc.de.md, region-cc.en.md |
| 2a | Tournament:: DE+EN | 30c6100a | tournament.de.md, tournament.en.md |
| 2b | TournamentMonitor:: DE+EN | 395a7e42 | tournament-monitor.de.md, tournament-monitor.en.md |

## Key Content Documented

**TableMonitor::** (2 services)
- `GameSetup.call`, `.assign`, `.initialize_game` signatures
- `ResultRecorder.save_result` return hash data contract (all 13 German-keyed fields)
- AASM events fired on model, not service; no direct broadcasts

**RegionCc::** (10 services)
- `ClubCloudClient` constructor + get/post interface
- Syncer pattern documented once with all operation variants listed
- PATH_MAP, dry-run mode, PHPSESSID session management

**Tournament::** (3 services)
- `PublicCcScraper` guard conditions (organizer_type + carambus_api_url checks)
- `RankingCalculator` as PORO (D-02 explicit decision)
- `TableReservationService` Google Calendar return type

**TournamentMonitor::** (4 services)
- `PlayerGroupDistributor` class methods (no instantiation)
- `RankingResolver` rule_str DSL: group refs, composite rules, KO bracket refs
- `ResultProcessor` DB lock scope (exactly `write_game_result_data + finish_match!`)
- Cross-dependency: `RankingResolver` → `PlayerGroupDistributor`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all files contain full content in both languages.

## Threat Flags

None — documentation files only, no new network endpoints or security surface.

## Self-Check: PASSED

Files exist:
- FOUND: docs/developers/services/table-monitor.de.md
- FOUND: docs/developers/services/table-monitor.en.md
- FOUND: docs/developers/services/region-cc.de.md
- FOUND: docs/developers/services/region-cc.en.md
- FOUND: docs/developers/services/tournament.de.md
- FOUND: docs/developers/services/tournament.en.md
- FOUND: docs/developers/services/tournament-monitor.de.md
- FOUND: docs/developers/services/tournament-monitor.en.md

Commits exist:
- FOUND: c27ac884 (TableMonitor DE+EN)
- FOUND: eba1264b (RegionCc DE+EN)
- FOUND: 30c6100a (Tournament DE+EN)
- FOUND: 395a7e42 (TournamentMonitor DE+EN)
