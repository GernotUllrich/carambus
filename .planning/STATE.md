---
gsd_state_version: 1.0
milestone: v7.1
milestone_name: UX Polish & i18n Debt
status: executing
stopped_at: Completed 38.4-12-PLAN.md
last_updated: "2026-04-25T15:50:57.428Z"
last_activity: 2026-04-25
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 33
  completed_plans: 32
  percent: 97
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.
**Current focus:** Phase 38.4 — bk2-kombi-post-dry-run-gaps

## Current Position

Phase: 38.4 (bk2-kombi-post-dry-run-gaps) — EXECUTING
Plan: 4 of 12
Status: Ready to execute
Last activity: 2026-04-25

**Deferred to Wave 4 / later session:**

- Plan 38.1-05 Task 1 (scaffold UAT + fallback-drill templates) — agent-runnable, not yet executed
- Plan 38.1-05 Task 2 (dry-run BK2-Kombi match at real BCW club table with volunteer scorer) — **human-only, tournament-gating**
- Plan 38.1-05 Task 3 (karambol fallback drill rehearsal) — human-only
- Plan 38.1-05 Task 4 (final artifact commit) — agent-runnable after Tasks 2+3
- Phase goal verification (`/gsd-verify-phase 38.1` or via `execute-phase` resume) — waits until all plans are complete
- Code review gate (`/gsd-code-review 38.1`) — not yet run

**To resume Phase 38.1:**

```
/gsd-verify-work 38.1            # manual UI testing on BCW dev
/gsd-code-review 38.1            # optional advisory review of scoring code
/gsd-execute-phase 38.1          # resumes at Wave 4 (skips completed waves)
```

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
- [Phase 38.4]: I2 closed via i18n-values-only rename: direkter_zweikampf→BK-2plus, serienspiel→BK-2. Internal keys and YAML paths unchanged per D-08/D-09.
- [Phase 38.4]: D-06: balls_goal replaces set_target_points as per-set Ballziel target on tournament_monitor.balls_goal
- [Phase 38.4]: D-07: ballziel_choices array in discipline.data drives server-side CLAMP; clamp_bk_family_params! helper DRYs both quick-game and detail-form paths
- [Phase 38.4]: D-04: BK2_DISCIPLINE_MAP extended to 5 BK-* disciplines sharing one scoring family (Bk2::CommitInning)
- [Phase 38.4]: D-10/D-13: Hard rename Bk2Kombi→Bk2 with no runtime aliases; Open Q 2 resolved — result_recorder.rb keeps Bk2::AdvanceMatchState (not CommitInning)
- [Phase 38.4]: D-16/D-07: Alpine-driven 5-radio BK-family selector + Ballziel dropdown + conditional DZ/SP inputs in detail view; bk_selected_form drives all hidden inputs for 5 BK-* forms
- [Phase 38.4]: is_bk2_kombi semantic split: phase-chip + CSS hook narrowed to single-value BK-2kombi check; Plan 05 5-family is_bk2 predicate preserved for GD/HS hide and score display
- [Phase 38.4]: D-03: Wave 5 closure — renamed bk2_kombi_scoreboard_test.rb to bk2_scoreboard_test.rb; all 8 deferred issues (I1-I9 except I6) covered by explicit regression tests in 35-method Bk2ScoreboardTest suite
- [Phase 38.4]: Plan 08: Two-layer fix for start_game UnfilteredParameters — controller .to_h (load-bearing for production path + 4 existing tests) + GameSetup .to_unsafe_h defensive guard (closes I9b unit test)
- [Phase 38.4]: Plan 09: BK-* detail view converted to 4 touch-button rows (BK-Variante / Punkt-Ziel / DZ-max / SP-max) — outer col-span-6/space-y-3 wrapper REMOVED, rows plug into parent grid-cols-6 as 8 sibling divs. Bespoke template-x-for chosen over reusing _radio_select partial for Alpine-reactive value lists.
- [Phase 38.4]: Two _radio_select partial calls (not one with dynamic values) for O7 Aufnahmebegrenzung — partial has no Alpine-template x-for escape hatch
- [Phase 38.4]: x-effect approach chosen for innings→bk2_sp_max_innings mirror; runs reactively on Alpine state change without @change wiring on partial calls
- [Phase 38.4]: Provisional Nachstoß equal rule: trailing player wins (not Verlängerungssatz). Landessportwart sign-off pending before 2026-05-02 tournament.
- [Phase 38.4]: define_singleton_method used for discipline wiring in advance_match_state_test.rb unit tests — acceptable shortcut; fixture-based approach preferred for future system tests.
- [Phase 38.4]: carambus.yml (compiled/ignored) must be kept in sync with carambus.yml.erb manually — Carambus.config reads the local .yml, not the .erb template
- [Phase 38.4]: button_id disambiguation via label_suffix in _quick_game_buttons partial is preventive — added proactively for same-discipline+balls_goal entries (BK2-Kombi 70)

### Roadmap Evolution

- Phase 38.1 inserted after Phase 38: BK2-Kombi minimum viable support (URGENT — 2026-05-02 tournament deadline)
- Phase 38.4 inserted after Phase 38: BK2-Kombi post-dry-run gaps (URGENT) — covers G1 delete, G2 Ballziel, I8, I9 deferred from Phase 38.3

### Pending Todos

- **Sync bug — `sync-version-yaml-load-json-collision`** (2026-04-23). `Version#update_from_carambus_api` fallback (version.rb:330/338) calls `YAML.load` on JSON-encoded text columns and returns a Hash → `update_columns` fails for text columns. See `.planning/todos/pending/2026-04-23-sync-version-yaml-load-json-collision.md`. Until fixed, **every local server** (carambus_phat, carambus_master, additional BCW instances) needs a manual Path B `unprotected=true` write for `Discipline.find(107).data = { "free_game_form" => "bk2_kombi" }.to_json` before the 2026-05-02 tournament.
- **Production API disk — `api-server-disk-cleanup`** (2026-04-23). PostgreSQL 14 cluster on the API server went down 2026-04-22 23:02 UTC due to disk-full. Freed 8 GB; now at 89% (8.1 GB free). Worth a deeper pass on old Capistrano releases and rotated Rails logs before the next crisis.

### Blockers/Concerns

None blocking Phase 38.1 execution. Reconciliation debt above is tracked but not blocking — name-match fallback keeps the tournament working on any server that's missing the `discipline.data` write.

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

Last session: 2026-04-25T15:50:57.425Z
Stopped at: Completed 38.4-12-PLAN.md
Resume: `/gsd-plan-phase 38` to break Phase 38 into 3 executable plans
