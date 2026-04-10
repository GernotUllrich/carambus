# Requirements: Carambus API — Test Suite Audit & Improvement

**Defined:** 2026-04-10
**Core Value:** Every existing test file is reviewed, consistent, and trustworthy — no dead tests, no skipped tests without justification, no brittle patterns.

## v2.0 Requirements

Requirements for test suite audit milestone. Each maps to roadmap phases.

### Quality Audit

- [ ] **QUAL-01**: Every test file reviewed for weak/missing assertions (tests that pass without actually testing anything)
- [ ] **QUAL-02**: Brittle tests identified and fixed (time-dependent, order-dependent, external-state-dependent)
- [ ] **QUAL-03**: Dead/redundant tests removed (duplicate assertions, unreachable code, tests for deleted features)
- [ ] **QUAL-04**: All 8 files with skipped/pending tests resolved (fixed or removed with documented justification)

### Consistency

- [ ] **CONS-01**: Consistent setup patterns across test files (fixtures vs factories usage clarified and standardized)
- [ ] **CONS-02**: Consistent assertion style across test files (no mixing of assert/refute styles unnecessarily)
- [ ] **CONS-03**: Consistent test naming conventions (method naming, describe/test block usage)
- [ ] **CONS-04**: Test helper and support file usage reviewed and standardized

### Model Tests

- [ ] **MODL-01**: All 22 model test files reviewed and improved
- [ ] **MODL-02**: Large test files assessed for structure (score_engine 703L, table_heater 824L, tournament_auto_reserve 586L)

### Service Tests

- [ ] **SRVC-01**: All 12 service test files reviewed and improved (10 RegionCc syncers + 2 TableMonitor services)

### Controller Tests

- [ ] **CTRL-01**: All 11 controller test files reviewed and improved

### System & Other Tests

- [ ] **SYST-01**: All 13 system test files reviewed and improved
- [ ] **OTHR-01**: Characterization (2), scraping (3), concerns (2), helpers (2), integration (1), tasks (1), optimistic_updates (1) reviewed and improved

### Green Suite

- [ ] **PASS-01**: Full test suite passes after all improvements (`bin/rails test`)

## Future Requirements

### Test Coverage Expansion

- **COVR-01**: New tests for 78 untested models
- **COVR-02**: New tests for 60 untested controllers
- **COVR-03**: New tests for 24 untested services

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
| Writing new tests for untested code | Separate milestone — this one improves existing tests only |
| Refactoring application code | Test-only changes; app code stays as-is |
| CI/CD pipeline changes | Infrastructure concern, not test quality |
| Coverage enforcement (SimpleCov thresholds) | Premature without coverage expansion milestone |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| QUAL-01 | Phase 6 | Pending |
| QUAL-02 | Phase 10 | Pending |
| QUAL-03 | Phase 10 | Pending |
| QUAL-04 | Phase 10 | Pending |
| CONS-01 | Phase 6 | Pending |
| CONS-02 | Phase 6 | Pending |
| CONS-03 | Phase 6 | Pending |
| CONS-04 | Phase 6 | Pending |
| MODL-01 | Phase 7 | Pending |
| MODL-02 | Phase 7 | Pending |
| SRVC-01 | Phase 8 | Pending |
| CTRL-01 | Phase 9 | Pending |
| SYST-01 | Phase 9 | Pending |
| OTHR-01 | Phase 9 | Pending |
| PASS-01 | Phase 10 | Pending |

**Coverage:**
- v2.0 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0 ✓

---
*Requirements defined: 2026-04-10*
*Last updated: 2026-04-10 after roadmap creation*
