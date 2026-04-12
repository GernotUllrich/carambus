# Phase 21: League Extraction - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-11
**Phase:** 21-league-extraction
**Areas discussed:** Extraction scope & ordering, Service naming & location, Scraping mega-method strategy, Delegation pattern

---

## Extraction Scope & Ordering

| Option | Description | Selected |
|--------|-------------|----------|
| All three clusters | Standings (~197 LOC) + Game Plan Reconstruction (~373 LOC) + ClubCloud Scraping (~506 LOC) + BBV Scraping (~119 LOC). Target ~1100 line reduction (50%). Ordered easiest-first. | ✓ |
| Standings + Game Plan only | ~570 LOC reduction (26%). Defer scraping to a separate phase. | |
| Scraping only | ~625 LOC reduction (28%). Tackle the hardest part first. | |

**User's choice:** All three clusters (Recommended)
**Notes:** None

### BBV Scraping Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Together | BBV is only 119 lines and structurally similar. Extract both in same plan. | ✓ |
| Separately | Keep BBV in League model for now. | |

**User's choice:** Together (Recommended)

---

## Service Naming & Location

| Option | Description | Selected |
|--------|-------------|----------|
| League:: namespace | app/services/league/ — matches Tournament::, TournamentMonitor::, TableMonitor:: patterns | ✓ |
| Flat in app/services/ | league_standings_calculator.rb etc. — simpler but diverges from pattern | |
| Under RegionCc:: | Move scraping into RegionCc::. Mixed namespacing. | |

**User's choice:** League:: namespace (Recommended)

### Standings Style Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| PORO | Plain Ruby object. Pure calculation, no side effects. | ✓ |
| ApplicationService for all | Uniform .call(kwargs) pattern for consistency. | |

**User's choice:** PORO (Recommended)

---

## Scraping Mega-Method Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| One service, internal split | League::ClubCloudScraper as single service. Break 821-line method into private methods internally. | ✓ |
| Split into sub-services now | Orchestrator + TeamScraper + GameScraper. More files but each focused. | |
| Extract as-is, refactor later | Move 821-line method unchanged. Focus on getting it out of model. | |

**User's choice:** One service, internal split (Recommended)

### BBV Scope Sub-question

| Option | Description | Selected |
|--------|-------------|----------|
| Separate: League::BbvScraper | Different data source, different HTML structure. Own service class. | ✓ |
| Method in ClubCloudScraper | Add scrape_bbv_* methods to ClubCloudScraper. Fewer files. | |

**User's choice:** Separate: League::BbvScraper (Recommended)

---

## Delegation Pattern

| Option | Description | Selected |
|--------|-------------|----------|
| Thin wrappers | League keeps one-liner methods that delegate. No caller changes required. | ✓ |
| Direct service calls | Remove methods from League. Update all callers to call services directly. | |
| Deprecation wrappers | Keep wrappers with deprecation warnings. Callers migrate over time. | |

**User's choice:** Thin wrappers (Recommended)
**Notes:** Wrappers are permanent public API, not transitional.

---

## Claude's Discretion

- Internal method decomposition within ClubCloudScraper
- Test file organization for new service classes
- GamePlanReconstructor dispatch pattern
- GamePlan utility method placement

## Deferred Ideas

None — discussion stayed within phase scope.
