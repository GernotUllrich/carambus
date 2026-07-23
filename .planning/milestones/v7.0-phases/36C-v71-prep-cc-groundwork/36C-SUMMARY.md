# Phase 36c Summary: v7.1 Preparation / ClubCloud Integration Groundwork

**Completed:** 2026-04-14
**Phase type:** Planning (no code changes)
**Execution mode:** Inline (no PLAN.md files; authored directly in a single session)

## Requirement coverage

| Req | Deliverable | File(s) |
|-----|-------------|---------|
| **PREP-01** | v7.1-ClubCloud-Integration milestone skeleton covering Endrangliste automatic calculation, Teilnehmerliste finalization via CC API, and credentials delegation for Club-Sportwart rights | `.planning/milestones/v7.1-REQUIREMENTS.md`, `.planning/milestones/v7.1-ROADMAP.md` |
| **PREP-02** | Shootout/Stechen support skeleton as its own v7.2 milestone (AASM changes, tournament plan modifications, scoreboard UI) | `.planning/milestones/v7.2-REQUIREMENTS.md`, `.planning/milestones/v7.2-ROADMAP.md` |
| **PREP-03** | Backlog/seed entries for Match-Abbruch / Freilos handling and UI consolidation of historically grown screens | `.planning/seeds/match-abbruch-freilos-handling.md`, `.planning/seeds/ui-consolidation-historically-grown-screens.md` |
| **PREP-04** | ClubCloud admin-side handling appendix (draft, referenced by Phase 36a DOC-ACC-04) — SME-confirm items clearly marked | `.planning/clubcloud-admin-appendix-DRAFT.md` |

All four success criteria from ROADMAP.md Phase 36c are met.

## Key decisions

1. **Shootout split into v7.2, not merged into v7.1.** The roadmap
   allowed either "part of v7.1" or "own milestone v7.2". Chose
   separate milestone because the two efforts have independent SMEs,
   independent risk profiles, and the v7.1 ClubCloud work gates the
   Endrangliste calculation that Shootout feeds into — coupling them
   would add risk with no benefit. v7.1 CCI-01 and v7.2 Phase C must
   coordinate at the design level; this is called out explicitly in
   both roadmaps.

2. **Backlog items landed in `.planning/seeds/`, not `.planning/todos/`.**
   Seeds are long-lived, medium-to-large scopes that need their own
   planning cycle when promoted. Todos are small, actionable items
   that fit in a single PR. The v7.0 scope-evolution doc already used
   the term "seed" for these items; preserved that convention.

3. **PREP-04 appendix written as a DRAFT with explicit [SME-CONFIRM]
   markers, not promoted to `docs/managers/`.** The appendix needs
   SME interview for ~6 factual items (CC role names, error message
   wording, delegation practice). Promoting a half-correct doc would
   have been worse than keeping an honest draft. v7.1 Phase F owns
   the SME interview and the promotion.

4. **v7.1 phase numbering is provisional.** v7.0 may grow further
   before v7.1 starts (Phase 37 is still pending; retroactive 36x
   work may appear). The skeletons use letters (A..F) for v7.1
   phases and (A..E) for v7.2 phases to avoid committing to numbers.

## Scope adherence

Phase 36c's success criterion was explicitly "scoping, not execution".
Nothing in this phase implements a feature. The CC API integration,
Shootout support, and UI consolidation all wait for v7.1+.

The only operational change in this session is **unrelated**: during
the phase intent-setting, the user found a severe UI regression in
the tournament_monitor start flow (tracked in
`.planning/debug/tournament-monitor-start-silent-fail.md`) and the
debug session resolved it in four commits (8a948c93, 23d65963,
5ef81ab0, 306cb2ed). Those commits are NOT part of Phase 36c — they
are operational fixes to shipped 36b work.

## Follow-up todos captured during this session

Three todos were captured in `.planning/todos/pending/` during the
debug excursion, all related to 36b bugs:

- Recalibrate `Discipline#parameter_ranges` for Dreiband klein
- Refactor 36B-06 verification gate to PRG-redirect pattern
- Tighten 36B-05 reset confirmation system test skip paths

None of these are v7.1/v7.2 blockers — they are v7.0 tech debt.

## Next step

v7.0 Phase 37 (In-App Doc Links). Phase 36c is the last planning
phase of v7.0; Phase 37 is the last execution phase before v7.0 can
ship.

Then v7.0 milestone closure → v7.1 discuss-phase, where the skeletons
in `.planning/milestones/v7.1-*.md` feed into a real ROADMAP.md +
REQUIREMENTS.md refresh.
