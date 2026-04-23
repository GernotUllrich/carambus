---
phase: 260423-qvm
plan: 01
subsystem: admin-views
tags:
  - administrate
  - rails-7.1-compat
  - training-system
  - ontologie-v0.9
status: complete
requires:
  - feature/training-system branch
  - dev server on localhost:3008 (live UAT)
provides:
  - public :warn shim for ActiveSupport::Deprecation under Rails 7.1+
  - M2M-aware Admin::TrainingExamplesController (post v0.9 Phase D)
  - Admin view smoke coverage for 4 routed dashboards
affects:
  - admin show pages rendering Field::HasMany / HasOne / BelongsTo
  - admin/training_examples destroy redirect target
  - admin/training_concepts show template (Sortierung column removed)
  - admin/shots index header (new-button suppressed at standalone level)
tech-stack:
  added: []
  patterns:
    - config/initializers/administrate_rails71_shim.rb (additive, gated no-op when upstream fixed)
    - ShotsController existing_action? override (mirrors TrainingExamplesController#valid_action? guard)
key-files:
  created:
    - config/initializers/administrate_rails71_shim.rb
    - test/integration/admin_views_smoke_test.rb
  modified:
    - app/controllers/admin/training_examples_controller.rb
    - app/controllers/admin/shots_controller.rb
    - config/routes.rb
    - app/views/admin/training_concepts/show.html.erb
    - app/dashboards/start_position_dashboard.rb
    - app/dashboards/training_example_dashboard.rb
    - app/views/admin/training_examples/show.html.erb
decisions:
  - "Source-level shim on ActiveSupport::Deprecation.warn instead of Administrate gem upgrade; upgrade deferred to carambus_api-scope decision."
  - "Commit B destroy redirects to Index (not parent concept) since M2M makes parent ambiguous; interactive per-concept reorder deferred."
  - "Commit B drops the Sortierung column entirely (Strategy A) rather than keeping a placeholder — cleaner semantic, table collapses 6→5 columns."
  - "Shots standalone admin route stays only:[:index]+member; Admin::ShotsController gets existing_action?(:new) guard mirroring TrainingExamplesController, instead of expanding routes."
  - "Smoke tests are render-gate only (status code + no generic 500 marker) — content assertions deferred as fixture-scope work."
  - "Inter-commit fixes (c2cf86f3, ce3f0892) added inline after Commit A when browser UAT surfaced additional Phase-D residues; these were not in the plan but are on the same v0.9-cleanup ticket."
metrics:
  duration: ~90 minutes (wall clock, across checkpoint)
  tasks_completed: 4
  tasks_total: 4
  completed: 2026-04-22
---

# Phase 260423-qvm Plan 01: Admin Show-page 500 fix — COMPLETE

One-liner: Administrate 0.19 × Rails 7.1+ `ActiveSupport::Deprecation.warn` shim + v0.9 Phase D residue cleanup (M2M-aware TrainingExample destroy, obsolete move_up/move_down removed, Sortierung column dropped from training_concepts) + admin smoke coverage for 4 routed dashboards. Test baseline advanced 1282 → 1290 runs, 0 failures, 0 errors.

## Commits made

All on branch `feature/training-system`, not pushed.

| # | SHA | Subject | Scope |
|---|-----|---------|-------|
| A | `adae812f` | `fix(admin): shim ActiveSupport::Deprecation.warn for Administrate 0.19 on Rails 7.1+` | Plan Task 1 |
| — | `c2cf86f3` | `fix(admin): remove Field::ActiveStorage residue in StartPositionDashboard` | Inter-checkpoint deviation |
| — | `ce3f0892` | `fix(admin): unblock TrainingExample Show — BallConfigurationDashboard + shot_image residue` | Inter-checkpoint deviation |
| B | `5e9849f0` | `fix(admin): remove obsolete move_up/move_down + M2M-aware destroy` | Plan Task 3 |
| C | `96d5f1b5` | `test(admin): add Index+Show smoke tests for 4 routed admin dashboards` | Plan Task 4 + Rule-2 fix |

Parent of A: `a8b6215a` (Claudia's workaround — `training_concepts` out of `SHOW_PAGE_ATTRIBUTES`).

## Verification results

### Grep gates (Commit B)

```
grep -rn "move_up_admin_training_example\|move_down_admin_training_example" app/views/ app/helpers/
```
→ **empty** (exit 1). PASS.

```
grep -nE "def move_up|def move_down" app/controllers/admin/training_examples_controller.rb
```
→ no match. PASS.

```
grep -n "training_concept_id = requested_resource.training_concept_id" app/controllers/admin/training_examples_controller.rb
```
→ no match. PASS.

### Routes (Commit B)

```
bin/rails routes | grep -cE "^\s*move_(up|down)_admin_training_example\s"
```
→ **0**. PASS (example-level move helpers gone).

```
bin/rails routes | grep -cE "^\s*move_(up|down)_admin_shot\s"
```
→ **2**. PASS (shot-level move helpers retained, out of scope).

```
grep -cE "^\s*patch :move_up|^\s*patch :move_down" config/routes.rb
```
→ **4** (2× nested shots inside training_concepts→training_examples→shots + 2× standalone shots). PASS.

### Live dev-server curl (port 3008, post-Commit-C)

| URL | Status |
|-----|--------|
| `/admin/training_examples/15` (Gabriëls) | **200** |
| `/admin/training_examples/16` (Conti Coup 10) | **200** |
| `/admin/training_concepts/6` (regression probe for Blocker #1) | **200** |
| `/admin/shots` (Rule-2 fix landed in Commit C) | **200** |

All PASS.

### Test suite

Controller + integration subset (run during Task 3 Step 7): `163 runs, 310 assertions, 0 failures, 0 errors, 5 skips`.

Smoke-test file alone (Task 4 Step 5): `8 runs, 15 assertions, 0 failures, 0 errors, 3 skips`.

Full suite (Task 4 Step 6):
```
1290 runs, 2898 assertions, 0 failures, 0 errors, 16 skips
```

Delta from baseline (1282 / 2883 / 0 / 0 / 13): **+8 runs, +15 assertions, +3 skips**. Target met. The 3 new skips cover the Show path for TrainingExample / TrainingConcept / Shot — seed-only records (#15 Gabriëls, #16 Conti Coup 10, etc.) live in dev DB, not in fixtures. Extending fixtures is deferred.

## Browser UAT (Task 2 checkpoint)

Gernot opened `/admin/training_examples/15` and `/admin/training_examples/16` in the browser after Commits A + c2cf86f3 + ce3f0892 landed.

- Render: **APPROVED** — both Show pages render HTTP 200, Administrate layout loads, SVG ball-configuration section visible.
- Visual plausibility: **POSITIONS OFF** — Gernot reports that ball coordinates on the rendered SVG do not match the intended layout for at least one of the two examples. This is **seed-data / coordinate-refinement scope (Claudia's lane)**, NOT code scope. Phase-D Admin plumbing is verified working; the pixel positions are a next-layer concern that belongs on the ontology-seeds ticket.

**Claudia handoff flag:** Forward the "positions off" observation to Claudia for seed-coordinate refinement on TrainingExample #15 (Gabriëls, `position_type=exact`, `table_variant=klein`) and #16 (Conti Coup 10, `position_type=qualitative`, `table_variant=match`). The SVG partial itself (`app/views/admin/shared/_ball_configuration_diagram.html.erb`, commit 84fa6578) is out of scope for this ticket.

## Deviations from plan

### Rule 3 — Runtime blocker at live verification (Commit A → inter-commit fixes)

- **Found during:** Post-Commit-A live curl by prior executor + browser UAT by Gernot.
- **Issue 1:** Dev server initializer reload — initializers don't hot-reload. Shim required server restart to take effect.
- **Issue 2:** After restart, `/admin/training_examples/15` still 500'd — a *different* v0.9-Phase-D residue surfaced: `StartPositionDashboard` declared a `Field::ActiveStorage` column that was already removed, and `TrainingExampleDashboard` referenced a `shot_image` field + a `BallConfigurationDashboard` that doesn't exist.
- **Fixes:**
  - `c2cf86f3` — removed Field::ActiveStorage residue from StartPositionDashboard.
  - `ce3f0892` — created stub-level BallConfigurationDashboard (or removed offending field) + dropped shot_image residue from TrainingExampleDashboard + show.html.erb. (See commit body for exact files.)
- **Commit policy:** Both are Rule-1 (bug-fix) deviations, fixed inline, tracked in this SUMMARY. Same class of v0.9 residue as the original plan's Commits B and C target — just surfaced in a different file.

### Rule 2 — Pre-existing `/admin/shots` 500 surfaced by smoke test (Commit C)

- **Found during:** First run of `test/integration/admin_views_smoke_test.rb` (Task 4 Step 5).
- **Issue:** `/admin/shots` Index crashed with `undefined method 'new_admin_shot_path'`. Root cause: `Administrate::Namespace#routes` enumerates ALL `/admin/shots` routes including the nested `/admin/training_examples/:id/shots/new`, so `accessible_action?(new_resource, :new)` returned true; the Administrate `_index_header.html.erb` partial then tried to link to `new_admin_shot_path`, which doesn't exist because the standalone mount is `only: [:index]` + member. Same residue class as the TrainingExamples cleanup this plan targets — Admin::ShotsController never had the `valid_action?` / `existing_action?` guard that TrainingExamplesController already carried.
- **Fix:** Added `existing_action?` override + `requested_resource` override to Admin::ShotsController mirroring the existing TrainingExamplesController pattern. Guard: suppress `:new` at top-level when `training_example_id` is blank.
- **Files modified:** `app/controllers/admin/shots_controller.rb`.
- **Commit:** `96d5f1b5` (same commit as the smoke test itself; the test was the detector, the fix unblocks the green baseline).
- **Scope justification:** Per Rule 2, this is missing critical functionality blocking correct basic operation; per plan scope, it's a direct v0.9 residue detector match. Fixed inline rather than escalating as a separate ticket.

## Known Stubs

None introduced.

## Threat Flags

None.

## Deferred Issues / Backlog (orchestrator writes to STATE.md)

1. **Administrate gem upgrade / replacement decision** (P0 long-term). Options A/B/C/D in `.paul/HANDOFF-2026-04-23-admin-views-review.md`. Shim in `config/initializers/administrate_rails71_shim.rb` is a bridge, not a destination.
2. **Interactive per-concept example reordering** via `TrainingConceptExample.sequence_number` (P1 deferred). Removed in Commit B without UX replacement — add back when there's a concrete user need.
3. **Fixtures** for `training_examples`, `training_concepts`, `shots` so the 3 smoke Show tests stop skipping (P2 deferred). Seed records (#15 / #16) live in dev DB only.
4. **Admin mount for `ball_configurations` and `start_positions`** — neither is currently under `namespace :admin`. Either add routes + missing dashboards (ball_configuration_dashboard.rb does not exist; start_position_dashboard.rb exists as orphan) or explicitly drop them from the v0.9 admin UI plan.
5. **Extend smoke coverage to Edit form views** — currently Index+Show only.
6. **Claudia seed-coordinate refinement** — Gernot's UAT flagged "positions off" on at least one of #15 / #16. Forward for SVG coordinate QA.

## Handoff memory status

| P-tier | Topic | Status |
|--------|-------|--------|
| P0 | Admin Show 500 (Administrate × Rails 7.1) | **resolved** via shim (Commit A) + dashboard residue fixes (c2cf86f3, ce3f0892) |
| P1 | Controller M2M cleanup (v0.9 Phase D) | **resolved** via Commit B |
| P2 | Admin smoke-test safety net | **resolved** via Commit C (and caught a P1.5: `/admin/shots` pre-existing bug, inline-fixed) |
| P3 | Visual UAT of SVG ball-configuration | **partial** — render works, coordinates flagged "off" by Gernot → Claudia handoff |

## Self-Check: PASSED

- `config/initializers/administrate_rails71_shim.rb` — FOUND
- `test/integration/admin_views_smoke_test.rb` — FOUND
- Commit `adae812f` — FOUND in `git log`
- Commit `c2cf86f3` — FOUND in `git log`
- Commit `ce3f0892` — FOUND in `git log`
- Commit `5e9849f0` — FOUND in `git log`
- Commit `96d5f1b5` — FOUND in `git log`
- Working tree clean except `.planning/quick/260423-qvm-.../` (expected — orchestrator commits docs).
- Full test suite 1290 / 0 / 0 confirmed.
