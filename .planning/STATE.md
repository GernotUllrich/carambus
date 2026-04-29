---
gsd_state_version: 1.0
milestone: v7.1
milestone_name: UX Polish & i18n Debt
status: verifying
stopped_at: Completed 38.6-04-preserve-loser-synonyms-PLAN.md
last_updated: "2026-04-29T21:15:52.592Z"
last_activity: 2026-04-29
progress:
  total_phases: 8
  completed_phases: 6
  total_plans: 48
  completed_plans: 47
  percent: 98
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-15)

**Core value:** Code and docs stay in sync — every documented feature works, every working feature is documented, and a volunteer user should never need to read the architecture to run a tournament.
**Current focus:** Phase 38.6 — discipline-master-data-cleanup

## Current Position

Phase: 38.6 (discipline-master-data-cleanup) — EXECUTING
Plan: 3 of 3
Status: Phase complete — ready for verification
Last activity: 2026-04-29

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
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 13: BK_FAMILY_BALLZIEL_FALLBACK constant + balls_goal_a/b fallback chain in clamp_bk_family_params! — defense-in-depth against carambus_api → local-server Discipline sync gap; closes P1 (BK100) and P3 (BK-2kombi 2/5/70+NS) round-4 UAT gaps
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 15: BK-Variante grid-cols-5 (supersedes Plan 10's grid-cols-8) + Aufnahmebegrenzung BK-* cols=4 + MEHRSATZ col-span-6 h-4 spacer; T-O6 renamed to -v2 per I-15-02; T-P2 ERB-compilation render replaces Capybara DOM (visit table_monitor_path doesn't render BK-* detail view) per I-15-01 — closes round-4 UAT P2 layout regression
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16: P5 narrowed via interpretation (b) flag-only — nachstoss_allowed scoped to BK-2kombi (id 107) only; BK50/BK100/BK-2/BK-2plus retain Discipline records but lose flag.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16 round-4 iteration-2 BLOCKER 2: explicit pre-check (Option (i)) replaces unreachable rescue ActiveRecord::RecordInvalid — LocalProtector raises Rollback (transaction control flow), silently swallowed by AR transactions; rescue NEVER fired on local servers.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 16 I-16-02: residual sync-race accepted (not blocked-on); production deployment sequence (master seed FIRST, then local-server migrations) makes window small + idempotent re-run recovers; tracked T-38.4-16-07 in STATE deferred follow-ups.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 17: CR-01 closed via 1-char fix at version.rb:434 (local_server → local_server?); 3 T-CR-01 tests lock the predicate-naming convention. INFO-01 closed via git mv todos/pending/sync-version-yaml-...md → todos/done/ + closure marker. INFO-02 closed via 3 ROADMAP checkbox flips on plans 38.4-10/11/12. WR-01..06 stay deferred.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 17 I-17-01 attestation: inline English comment above the local_server? fix is per CLAUDE.md line 23 technical-terms exception (NameError + predicate naming + line numbers are technical, not business). Documented in 38.4-17-SUMMARY.md for auditability.
- [Phase 38.4-bk2-kombi-post-dry-run-gaps]: Plan 14: Option B implemented — TableMonitor#discipline String contract preserved; bk_family_with_nachstoss? + route_goal_reached_through_bk2_commit_inning private helpers route :goal_reached through Bk2::CommitInning when name-looked-up Discipline has nachstoss_allowed? Bk2::CommitInning + Bk2::AdvanceMatchState hardened to handle String discipline (Rule 1 fix); incidentally clears 4 deferred T8-T11 errors. Closes round-4 P4 gap.
- [Phase 38.5]: Plan 01: RED-tests seed post-resolver state directly in data hash to decouple Plan 01 from Plan 02 — Plan 01 ships independently in Wave 1; tests turn GREEN automatically once Plan 04 rewrites predicates
- [Phase 38.5]: Plan 01: GSD verification contract — test/integration/bk_param_latent_bugs_test.rb is locked against edits in Plan 06; turning all 4 tests GREEN without editing this file proves Plans 04+05 fix the latent bugs correctly
- [Phase 38.5]: Plan 02: BkParamResolver as top-level service (orthogonal to Bk2:: namespace) — also services non-BK default-false path so karambol/snooker/pool stay correct without resolver-aware code.
- [Phase 38.5]: Plan 02: TournamentPlan level (Level 3) silently skipped — schema has no data column on tournament_plans (db/schema.rb:1255–1268). Honors D-14 'keine Migrationen'. Test D1 is the regression guard (assert_nothing_raised on Tournament+TournamentPlan reference).
- [Phase 38.5]: Plan 02: Levels 5 (Quickstart-Preset) + 6 (Detail-Form) collapse into Level 7 (TableMonitor) — D-16 defers UI toggles, so preset/form values already land in tm.data via controller params.
- [Phase 38.5]: Plan 02: bake! does NOT save (caller is responsible) and is idempotent — verified by F3 reloading from DB and asserting effective_discipline absent on persisted row. AASM initial-state callback persists TableMonitor.new implicitly, so tm.persisted? cannot be used for the contract test.
- [Phase 38.5]: Plan 02: D-06 sparse-override regression guard — test C1 explicitly asserts data.key? gate (NOT data[].present?) so an explicit false at any level overrides true at lower levels. Failure message names the bug class for self-diagnostic regressions.
- [Phase 38.5]: Plan 03: BK2-Kombi (Discipline 107) explicitly does NOT carry allow_negative_score_input or negative_credits_opponent — resolver looks up effective_discipline (bk_2plus or bk_2) per set and reads THAT Discipline's params (D-08). Seed script's idempotency guard deletes those keys if accidentally written by a prior run.
- [Phase 38.5]: Plan 03: Test fixture mirrors seed output verbatim — decouples Plan 02/04 unit tests from Version-sync timing. test/fixtures/disciplines.yml carries the same data shape that local servers receive via Version#update_from_carambus_api after the seed runs on carambus_api.
- [Phase 38.5]: Plan 04: Two-line predicate body swap in score_engine.rb (data["free_game_form"]=="..." → !!data["..."]) closes both latent BK-* bugs (D-11 BK-2kombi DZ, D-12 BK-2/BK50/BK100); three consumer call-sites (lines 84, 148, 706) UNCHANGED, automatically pick up new contract via D-10 (call-by-name).
- [Phase 38.5]: Plan 04: All 4 of Plan 01's RED tests turn GREEN from Plan 04 alone (NOT only Tests 2/3/4 as plan author predicted). Plan 01 seeded post-bake state directly in test data per its D-13 decoupling, so Test 1 (BK-2kombi DZ) doesn't need Plan 05's set-boundary bake. Plan 05 still required for the live add_n_balls path (system tests verify that surface).
- [Phase 38.5]: Plan 05: rebake_at_set_open! lives on Bk2::AdvanceMatchState (D-03 mental model) — thin one-line delegate to BkParamResolver.bake!; called from ResultRecorder#perform_switch_to_next_set (research finding 3 actual file path); BK-2kombi guard at consumer site (not inside delegate)
- [Phase 38.5]: Plan 05: stub-and-restore test pattern — save original via .method(:name), restore via define_singleton_method(name, original) in ensure. Avoids remove_method clobbering real module methods between sibling tests; load-bearing for testing module-level delegate methods
- [Phase 38.5]: Plan 06: 2 E2E system tests in bk2_scoreboard_test.rb prove BkParamResolver.bake! -> ScoreEngine integration end-to-end at the live data path; service-level dispatch (tm.score_engine.add_n_balls) over real DOM clicks matches existing 35-test convention
- [Phase 38.5]: Plan 06: No-lazy-bake decision recorded in 38.5-DEPLOYMENT-RUNBOOK.md (closes Open Question 2 from RESEARCH.md). Rationale: D-15 forbids migration code; ScoreEngine refactor for lazy-bake is out of scope (only Hash + Discipline AR ref, no TM ref); in-flight pre-38.5 BK-* matches fall back to false/false per D-04 (identical to today's behaviour, no regression); next start_game bakes correctly
- [Phase 38.6]: All 6 D-13 phases implemented in merge_bk_disciplines.rb — per-loser transaction isolation, PaperTrail-aware AR-API only, interactive CC-conflict halt
- [Phase 38.6]: Seed-replay carve-out: discipline_test.rb lines 190-247 keep 'BK2-Kombi' strings synchronized with un-touched seed file; follow-up phase required to align seed + test data after production merge runs
- [Phase 38.6]: Rule 1 auto-fix: table_monitors_controller_test.rb updated (not in plan's 4-file list) — 3 tests failed as direct cascade of BK2_DISCIPLINE_MAP rename; CLAMP target updated from BK2-Kombi to BK-2kombi
- [Phase 38.6]: Dry-run transaction wrapper added (Rule 3): merge_bk_disciplines_dry_run.rb wraps script in ActiveRecord::Rollback so dev DB stays untouched after path-B full-merge dry-run
- [Phase 38.6]: No CC-Konflikt-Scan conflicts found in dry-run: D-08 interactive halt never triggered — production merge is safest possible path
- [Phase 38.6]: PlayerRanking recompute list empty: all 24 loser-95 rankings FK-updated without unique-constraint conflict — no post-merge recompute job needed (D-03 scope cleared)
- [Phase 38.6]: Synonyms block inserted inside existing Discipline.transaction so dry-run rollback also undoes synonym change; winner.save! (not update_columns) preserves PaperTrail compliance (D-04)

### Roadmap Evolution

- Phase 38.1 inserted after Phase 38: BK2-Kombi minimum viable support (URGENT — 2026-05-02 tournament deadline)
- Phase 38.4 inserted after Phase 38: BK2-Kombi post-dry-run gaps (URGENT) — covers G1 delete, G2 Ballziel, I8, I9 deferred from Phase 38.3

### Pending Todos

- **Sync bug — `sync-version-yaml-load-json-collision`** (2026-04-23). `Version#update_from_carambus_api` fallback (version.rb:330/338) calls `YAML.load` on JSON-encoded text columns and returns a Hash → `update_columns` fails for text columns. See `.planning/todos/pending/2026-04-23-sync-version-yaml-load-json-collision.md`. Until fixed, **every local server** (carambus_phat, carambus_master, additional BCW instances) needs a manual Path B `unprotected=true` write for `Discipline.find(107).data = { "free_game_form" => "bk2_kombi" }.to_json` before the 2026-05-02 tournament.
- **Production API disk — `api-server-disk-cleanup`** (2026-04-23). PostgreSQL 14 cluster on the API server went down 2026-04-22 23:02 UTC due to disk-full. Freed 8 GB; now at 89% (8.1 GB free). Worth a deeper pass on old Capistrano releases and rotated Rails logs before the next crisis.

### Deferred follow-ups

- **T-38.4-16-07 — Residual sync-race for nachstoss_allowed cleanup (Phase 38.4-16):**
  The migration `db/migrate/20260425090000_clear_nachstoss_allowed_for_non_bk2_kombi.rb`
  removes the `nachstoss_allowed` key from BK50/BK100/BK-2/BK-2plus on each server.
  If a stale Plan-11 payload arrives via Version sync AFTER the migration runs on a
  given server (sync race), the flag reappears until the seed re-runs on master AND
  the new flag-less payload propagates. Mitigation in production deployment sequence
  (master seed re-run FIRST, then local-server migrations); residual risk documented
  in migration's `up` method comments. If observed in the wild, re-run the migration
  after the next sync — idempotent. Future hardening: a self-healing periodic check
  that re-applies the cleanup if drift detected.

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

Last session: 2026-04-29T21:15:52.589Z
Stopped at: Completed 38.6-04-preserve-loser-synonyms-PLAN.md
Resume: `/gsd-plan-phase 38` to break Phase 38 into 3 executable plans
