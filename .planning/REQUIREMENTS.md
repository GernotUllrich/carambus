# Requirements: Carambus API — Model Refactoring & Test Coverage

**Defined:** 2026-04-09
**Core Value:** Reduce the two worst god-object models into maintainable, testable units without changing external behavior.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Characterization Testing

- [ ] **TEST-01**: Characterization tests for TableMonitor critical paths (state transitions, callbacks, broadcasts)
- [ ] **TEST-02**: Characterization tests for RegionCc sync operations (HTTP calls, data transformation)

### TableMonitor Extraction

- [ ] **TMON-01**: Extract ScoreEngine service (pure hash mutation logic)
- [ ] **TMON-02**: Extract GameSetup service (game/participation creation, replace skip_update_callbacks)
- [ ] **TMON-03**: Extract ResultRecorder service (result persistence + AASM event dispatch)
- [ ] **TMON-04**: Extract OptionsPresenter service (view-preparation logic)
- [ ] **TMON-05**: Remove DEBUG constants, use Rails.logger levels
- [ ] **TMON-06**: Full test coverage for all extracted TableMonitor services

### RegionCc Extraction

- [ ] **RGCC-01**: Extract ClubCloudClient (HTTP transport layer, zero AR coupling)
- [ ] **RGCC-02**: Extract LeagueSyncer service
- [ ] **RGCC-03**: Extract TournamentSyncer service
- [ ] **RGCC-04**: Extract PartySyncer service
- [ ] **RGCC-05**: Re-record VCR cassettes after HTTP layer extraction
- [ ] **RGCC-06**: Full test coverage for all extracted RegionCc services

### Quality Metrics

- [ ] **QUAL-01**: Reek baseline measurement before and after extraction

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Additional Model Refactoring

- **LEAK-01**: Extract service classes from League model (2219 lines)
- **TOUR-01**: Extract service classes from Tournament model (1775 lines)

### Additional Improvements

- **SCRP-01**: Consolidate UmbScraper v1/v2 into single implementation
- **SECU-01**: Re-enable ActionCable CSRF protection with proper origin validation
- **PERF-01**: Add circuit breaker pattern for external API calls

## Out of Scope

| Feature | Reason |
|---------|--------|
| Architecture changes | Explicitly excluded — refactoring only |
| Stack/framework changes | Explicitly excluded — no new frameworks |
| New features | This is purely refactoring and test coverage |
| League model refactoring | Deferred to v2 — tackle after TableMonitor and RegionCc |
| Tournament model refactoring | Deferred to v2 — tackle after TableMonitor and RegionCc |
| Replace Net::HTTP with Faraday in ClubCloudClient | Crosses the line from refactoring into rewrite |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| TEST-01 | Pending | Pending |
| TEST-02 | Pending | Pending |
| TMON-01 | Pending | Pending |
| TMON-02 | Pending | Pending |
| TMON-03 | Pending | Pending |
| TMON-04 | Pending | Pending |
| TMON-05 | Pending | Pending |
| TMON-06 | Pending | Pending |
| RGCC-01 | Pending | Pending |
| RGCC-02 | Pending | Pending |
| RGCC-03 | Pending | Pending |
| RGCC-04 | Pending | Pending |
| RGCC-05 | Pending | Pending |
| RGCC-06 | Pending | Pending |
| QUAL-01 | Pending | Pending |

**Coverage:**
- v1 requirements: 15 total
- Mapped to phases: 0
- Unmapped: 15 ⚠️

---
*Requirements defined: 2026-04-09*
*Last updated: 2026-04-09 after initial definition*
