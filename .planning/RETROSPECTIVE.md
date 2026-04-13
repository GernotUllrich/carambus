# Retrospective

Living document tracking what worked, what didn't, and patterns across milestones.

---

## Milestone: v4.0 — League & PartyMonitor Refactoring

**Shipped:** 2026-04-12
**Phases:** 4 | **Plans:** 9

### What Was Built
- 65 characterization tests pinning League (standings, game plan, scraping) and PartyMonitor (8 AASM states, placement, result pipeline)
- League 2221→663 lines via 4 extracted services (StandingsCalculator, GamePlanReconstructor, ClubCloudScraper, BbvScraper)
- PartyMonitor 605→217 lines via 2 extracted services (TablePopulator, ResultProcessor)
- 30 controller integration tests + 10 reflex unit tests covering League/Party/PartyMonitor ecosystem
- 6 code review warnings fixed (SQL parameterization, timezone, error handling, lock semantics)
- Final suite: 901 runs, 0 failures, 0 errors

### What Worked
- Characterization-first extraction pattern proven again (v1.0/v2.1 precedent). Zero behavior regressions caught by Phase 20 tests.
- Thin delegation wrappers — zero caller changes across all extractions. Controllers, reflexes, jobs unmodified.
- Wave-based execution with worktree isolation — both plans in each phase ran cleanly.
- Code review → fix cycle caught real bugs (SQL injection, timezone, silent exception swallowing).
- Discuss → Research → Plan → Execute pipeline was smooth — research caught undeclared method calls (next_seqno, write_game_result_data, add_result_to) that would have caused runtime failures.

### What Was Inefficient
- Phase 20 characterization plans could have been 2 plans instead of 3 — LeagueTeam and Party were small enough to combine.
- Some SUMMARY.md one-liners were empty ("One-liner:") — executor agents didn't always fill the template field.
- Open Questions in RESEARCH.md needed manual `(RESOLVED)` marker fixes after planning — could be automated.

### Patterns Established
- `{Model}::` namespace under `app/services/{model}/` — consistent across League, PartyMonitor, Tournament, TournamentMonitor, TableMonitor
- PORO for pure algorithms, ApplicationService for side-effect-heavy operations
- Pessimistic locks stay in model (or move to service depending on TournamentMonitor precedent), AASM events never fired from services
- Fixture-first testing with `LocalProtectorTestOverride` and `ApiProtectorTestOverride`
- Code review fix cycle as standard post-execution step

### Key Lessons
- Pre-existing bugs should be documented but preserved during extraction — the accumulate_results data mutation was correctly preserved verbatim
- Fixture chains matter — broken party_monitors.yml caused 4 test skips that persisted across multiple milestones until Phase 23 fixed them
- Research phase catches coupling issues that discuss-phase can't — always research before planning extraction phases

### Cost Observations
- Model mix: Opus for planning, Sonnet for research/execution/review/verification
- 4 phases completed in approximately 2 sessions
- Notable: Worktree isolation enabled parallel execution within waves — no merge conflicts

---

## Cross-Milestone Trends

| Metric | v1.0 | v2.0 | v2.1 | v3.0 | v4.0 |
|--------|------|------|------|------|------|
| Phases | 5 | 5 | 6 | 3 | 4 |
| Test suite | 475 | 475 | 751 | 751 | 901 |
| Services extracted | 14 | 0 | 7 | 0 | 6 |
| Models refactored | 2 | 0 | 2 | 0 | 2 |

**Recurring pattern:** Characterization → Extraction → Coverage is the proven 3-phase template for god-object breakdown. Used in v1.0, v2.1, and v4.0.

**All original god-object models now addressed:**
- TableMonitor: 3903→1611 (v1.0)
- RegionCc: 2728→491 (v1.0)
- Tournament: 1775→575 (v2.1)
- TournamentMonitor: 499→181 (v2.1)
- League: 2221→663 (v4.0)
- PartyMonitor: 605→217 (v4.0)
