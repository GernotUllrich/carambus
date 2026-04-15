---
gsd_state_version: 1.0
milestone: v7.1
milestone_name: UX Polish & i18n Debt
status: executing
stopped_at: Completed 38-02 tournament views i18n audit
last_updated: "2026-04-15T13:14:18.222Z"
last_activity: 2026-04-15
progress:
  total_phases: 2
  completed_phases: 1
  total_plans: 2
  completed_plans: 2
  percent: 100
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.
**Current focus:** Phase 38 — UX Polish & i18n Debt

## Current Position

Phase: 38 (UX Polish & i18n Debt) — EXECUTING
Plan: 2 of 2
Status: Ready to execute
Last activity: 2026-04-15

Previous milestone archived at:

- `.planning/milestones/v7.0-ROADMAP.md`
- `.planning/milestones/v7.0-REQUIREMENTS.md`
- `.planning/milestones/v7.0-MILESTONE-AUDIT.md`
- `.planning/milestones/v7.0-phases/` (8 phase directories: 33, 34, 35, 36, 36A, 36B, 36C, 37)

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Full v7.0 cross-phase decisions recorded inline in the milestone archive and RETROSPECTIVE.md.

**v7.1 roadmap decisions:**

- **Single-phase shape (Phase 38, 3 plans)** chosen over 2-phase or 3-phase splits. Rationale: all 6 requirements are small polish/debt items sharing the same UX theme (volunteer-facing wizard + tournament_monitor), don't benefit from cross-phase sequencing, and shipping in one phase keeps the milestone focused with an atomic final commit. Granularity is `coarse` and the seed explicitly recommends 1-3 plans / single phase.
- **DATA-01 short-term widen only assumed** — the medium-term DB-backed `discipline_parameter_ranges` table is flagged as a discuss-phase open question, not in scope for the roadmap. If the discuss-phase decides medium-term is in scope, Plan 38-03 can split or a Phase 39 can be inserted.
- **UX-POL-03 (Test 1 retest) bundled into Plan 38-01** with the G-01 fix. Dependency satisfied by ordering: G-01 ships first inside the same plan, retest immediately follows. No risk of retesting before the fix lands.

### Pending Todos

None.

### Blockers/Concerns

None. All v7.0 blockers resolved.

**Open question for discuss-phase (Phase 38):**

- DATA-01 scope boundary — short-term widen only (current assumption, single plan), or short-term widen + medium-term DB-backed `discipline_parameter_ranges` table (would split DATA-01 into 2 plans or justify a Phase 39)?

**Known tech debt carried into next milestone:**

- **`public/docs/` manual-rebuild gap — STILL OPEN**. `public/docs/` is git-tracked and must be manually rebuilt via `bin/rails mkdocs:build` after any `docs/**/*.md` edit. G-02 found and fixed this inline during v7.0 UAT (commit `7cf16114`). Quick task `260415-26d` (2026-04-15) attempted structural hardening via overcommit pre-commit hook but **failed and was rolled back** — see `.planning/quick/260415-26d-public-docs-build-hardening-via-overcomm/260415-26d-POSTMORTEM.md` for the reproducible root-cause findings. Workflow discipline until a new approach is implemented: (1) run `bin/rails mkdocs:build` before every `git push` that touched `docs/**/*.md`; (2) `/gsd-complete-milestone` must include an explicit rebuild step; (3) a future quick task may implement a CI guard (GitHub Actions job that runs `mkdocs build` and fails on `public/docs/` drift) as the replacement.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260414-qb8 | Fix PG::UndefinedColumn result_a crash in tournaments show/finalize_modus views | 2026-04-14 | b787da5e | [260414-qb8-fix-pg-undefinedcolumn-result-a-crash-in](./quick/260414-qb8-fix-pg-undefinedcolumn-result-a-crash-in/) |
| 260415-26d | public/docs/ build hardening via overcommit pre-commit hook — **ROLLED BACK** (hook approach failed, see POSTMORTEM) | 2026-04-15 | 912bf72a → rollback | [260415-26d-public-docs-build-hardening-via-overcomm](./quick/260415-26d-public-docs-build-hardening-via-overcomm/) |

## Session Continuity

Last session: 2026-04-15T13:14:18.220Z
Stopped at: Completed 38-02 tournament views i18n audit
Resume: `/gsd-plan-phase 38` to break Phase 38 into 3 executable plans
